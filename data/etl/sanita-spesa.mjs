// Ingestione della SPESA e delle ENTRATE per cassa delle AZIENDE SANITARIE dai
// flussi SIOPE (MEF-RGS OpenBDAP, CC-BY) → tabella `sanita_spesa` in DuckDB + riga
// nel `catalog`.
//
// **Non scarica niente.** Legge i file che `siope.mjs` ha già in `raw/siope/`, che
// contengono TUTTI gli enti e non solo i comuni: quell'ETL tiene le righe con
// tipologia `CO` e butta il resto, e fra il resto ci sono le aziende sanitarie —
// 4488 righe nel solo Abruzzo del 2021. Per mesi il warehouse ha avuto la spesa
// sanitaria per azienda sul disco senza saperlo, mentre altrove si scriveva che
// «esiste per regione e a scendere si ferma». È il modo più economico di
// aggiungere una fonte: accorgersi di averla già.
//
// Che cosa risponde: **quanto spende l'azienda che ti cura, in che cosa, e come
// cambia.** Le categorie sono le voci del piano dei conti — redditi da lavoro
// dipendente, acquisto di beni e servizi, investimenti — quindi si vede la quota
// che va agli stipendi e quella che va in conto capitale, che sono le due domande
// che si fanno a un bilancio sanitario.
//
// TRAPPOLE:
//  - **le tipologie sanitarie sono QUATTRO e non una sola.** `AS` è l'ASL, `AG` le
//    gestioni ASL, `RS` la gestione sanitaria accentrata delle Regioni, `AR` le
//    agenzie regionali sanitarie. Sommarle tutte come «sanità» mette insieme
//    l'azienda che gestisce gli ospedali e la contabilità accentrata di una
//    Regione, che non sono la stessa cosa: la colonna `tipologia` le distingue e
//    la descrizione di catalogo dice di guardarla;
//  - **SIOPE non porta il codice dell'azienda**, solo il nome per esteso. Con
//    `sanita_asl_comuni` non si aggancia per codice, e per nome NON SI TENTA:
//    «AZIENDA SANITARIA LOCALE 1 DI AVEZZANO-SULMONA-L'AQUILA» contro «ASL 1
//    Avezzano» è il genere di confronto che aggancia il 60% delle righe e sbaglia
//    in silenzio sul resto. Quello che c'è è il **comune della sede** (codice ISTAT
//    nel file), che è geografia vera e non un indovinello;
//  - **gli importi sono CUMULATI da inizio anno**, come in `siope.mjs`: il valore
//    dell'anno è quello del mese più alto pubblicato, non la somma dei mesi.
//    Sommare i dodici mesi conta dodici volte gennaio;
//  - **l'anno corrente è parziale** e non va confrontato con gli anni chiusi: la
//    colonna `mese` dice fino a dove arriva, 12 = anno completo;
//  - **l'importo è un decimale con il PUNTO** — «8113577.85» — non un numero
//    all'italiana: trattare i punti da separatori di migliaia lo moltiplica per
//    cento, e il totale nazionale usciva a 8641 miliardi contro i 130 veri. È il
//    controllo sull'ordine di grandezza, a fine ETL, ad averlo preso;
//  - il **codice comune è a TRE cifre**, dentro la provincia: il codice ISTAT a sei
//    si compone con quello della provincia. Preso da solo non aggancia niente e
//    tutte le righe risultano senza sede;
//  - il campo del periodo è **`2021/09`, con la barra**: leggerlo a posizione fissa
//    dà «/0» come mese, cioè NULL, e il join sul mese più alto svuota la tabella
//    intera — zero righe, nessun errore, e sembra che la fonte non abbia sanità;
//  - le **partite di giro** vanno escluse dai totali (titoli 7 in spesa e 9 in
//    entrata), come nei comuni: sono soldi che entrano ed escono per conto terzi e
//    gonfiano i totali senza essere spesa.
//
// Uso:  bun etl/sanita-spesa.mjs

import { DuckDBInstance } from "@duckdb/node-api";
import { readdirSync } from "node:fs";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/siope/";
const DB = ROOT + "warehouse.duckdb";

// AS = ASL, AG = gestioni ASL, RS = regioni gestione sanitaria,
// AR = agenzie regionali sanitarie.
const TIPOLOGIE = ["AS", "AG", "RS", "AR"];

const esc = s => String(s).replaceAll("'", "''");
console.log("▸ spesa delle aziende sanitarie (SIOPE, dai file già scaricati)");

const file = readdirSync(RAW).filter(f => f.endsWith(".csv"));
if (file.length === 0)
  throw new Error(`nessun file in ${RAW}: lanciare prima \`bun etl/siope.mjs\``);
const spese = file.filter(f => !f.includes("_entrate"));
const entrate = file.filter(f => f.includes("_entrate"));
console.log(`  ${file.length} file in cache: ${spese.length} di spesa, ${entrate.length} di entrata`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

// Il glob evita di elencare 240 percorsi in una query; `filename` è quello che
// distingue i due movimenti, perché il file di entrata si chiama `_entrate.csv` e
// il contenuto non porta la differenza.
const leggi = `read_csv('${esc(RAW)}*.csv', delim = ';', header = true, all_varchar = true,
            ignore_errors = true, union_by_name = true, filename = true)`;

// L'importo e' un decimale ordinario con il PUNTO — «8113577.85» — non un numero
// all'italiana: togliere i punti come separatori di migliaia lo moltiplica per
// cento, e il totale nazionale usciva a 8641 miliardi contro i 130 veri. Il
// controllo sull'ordine di grandezza a fine ETL esiste per questo.
const numero = c => `TRY_CAST(trim(${c}) AS DOUBLE)`;
const tipi = TIPOLOGIE.map(t => `'${t}'`).join(", ");

// Una riga per ente/anno/categoria, con l'importo del MESE PIÙ ALTO pubblicato:
// gli importi sono cumulati da inizio anno, quindi sommare i mesi conterebbe
// dodici volte gennaio.
await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo AS
  SELECT CASE WHEN filename LIKE '%_entrate.csv' THEN 'entrata' ELSE 'spesa' END AS movimento,
    trim("Descrizione Ente BDAP") AS ente,
    trim("Codice Tipologia Ente BDAP") AS tipologia,
    trim("Descrizione Tipo Ente BDAP") AS tipologia_nome,
    -- Il codice comune e' a TRE cifre, dentro la provincia: il codice ISTAT a sei
    -- si compone con quello della provincia, come fa siope.mjs. Preso da solo non
    -- aggancia niente, e tutte le righe risultavano senza sede.
    lpad(trim("Codice istat provincia"), 3, '0') || lpad(trim("Codice istat comune"), 3, '0')
      AS codice_istat_sede,
    trim("Sigla Provincia BDAP") AS sigla,
    -- Il campo e' «2021/09», con la barra: preso a posizione fissa il mese
    -- diventava «/0», cioe' NULL, e il join sul mese piu' alto svuotava la
    -- tabella intera senza un errore. Si divide sul separatore.
    TRY_CAST(split_part(trim("Anno/Mese calendario"), '/', 1) AS INTEGER) AS anno,
    TRY_CAST(split_part(trim("Anno/Mese calendario"), '/', 2) AS INTEGER) AS mese,
    trim("Codice Titolo CG") AS titolo,
    trim("Descrizione CG") AS categoria,
    ${numero('"Importo cumulato"')} AS importo
  FROM ${leggi}
  WHERE trim("Codice Tipologia Ente BDAP") IN (${tipi})`);

await con.run(`CREATE OR REPLACE TEMP TABLE _ultimo AS
  SELECT movimento, ente, anno, max(mese) AS mese FROM _grezzo
  WHERE anno IS NOT NULL AND mese IS NOT NULL GROUP BY 1, 2, 3`);

await con.run(`CREATE OR REPLACE TABLE sanita_spesa AS
  SELECT g.movimento, g.ente, g.tipologia, g.tipologia_nome,
    g.codice_istat_sede,
    coalesce(c.comune, '') AS comune_sede,
    g.sigla, c.provincia, c.regione,
    g.anno, g.mese, g.titolo, g.categoria,
    round(sum(g.importo), 2) AS importo
  FROM _grezzo g
  JOIN _ultimo u USING (movimento, ente, anno, mese)
  LEFT JOIN istat_confini_comuni c ON c.codice_istat = g.codice_istat_sede
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
  HAVING sum(g.importo) IS NOT NULL AND sum(g.importo) <> 0
  ORDER BY g.anno, g.ente, g.movimento, g.categoria`);

const st = await q(`SELECT count(*) righe, count(DISTINCT ente) enti,
  min(anno) dal, max(anno) al,
  count(*) FILTER (WHERE comune_sede = '') senza_sede
  FROM sanita_spesa`);
console.log(
  `  righe: ${st.righe} · ${st.enti} enti · ${st.dal}-${st.al}` +
    (Number(st.senza_sede) > 0 ? ` · ${st.senza_sede} righe senza comune di sede` : ""),
);

const perTipo = (await con.runAndReadAll(`SELECT tipologia, tipologia_nome,
  count(DISTINCT ente) enti FROM sanita_spesa GROUP BY 1, 2 ORDER BY 3 DESC`)).getRowObjects();
for (const t of perTipo) console.log(`    ${t.tipologia}  ${t.enti} enti — ${t.tipologia_nome}`);

// Il controllo indipendente: la spesa sanitaria pubblica italiana è nota, circa
// 130 miliardi l'anno. Qui si guarda l'ultimo anno CHIUSO (mese 12) e le sole
// ASL, senza partite di giro.
const totale = await q(`SELECT anno, round(sum(importo) / 1e9, 1) miliardi
  FROM sanita_spesa
  WHERE movimento = 'spesa' AND tipologia = 'AS' AND mese = 12
    AND titolo NOT IN ('7', '0')
    AND anno = (SELECT max(anno) FROM sanita_spesa WHERE mese = 12)
  GROUP BY 1`);
if (totale) {
  const miliardi = Number(totale.miliardi);
  console.log(
    `  ✓ ${totale.anno}: ${miliardi} miliardi pagati dalle ASL` +
      (miliardi > 60 && miliardi < 200
        ? " — nell'ordine di grandezza della spesa sanitaria pubblica"
        : " — ⚠ fuori dall'ordine di grandezza atteso, verificare i filtri"),
  );
}

const voci = (await con.runAndReadAll(`SELECT categoria, round(sum(importo) / 1e9, 1) miliardi
  FROM sanita_spesa WHERE movimento = 'spesa' AND tipologia = 'AS' AND mese = 12
    AND anno = (SELECT max(anno) FROM sanita_spesa WHERE mese = 12) AND titolo NOT IN ('7', '0')
  GROUP BY 1 ORDER BY 2 DESC LIMIT 4`)).getRowObjects();
for (const v of voci) console.log(`    ${String(v.miliardi).padStart(6)} mld — ${v.categoria}`);

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'sanita_spesa' ORDER BY ordinal_position`,
  )
)
  .getRowObjects()
  .map(c => ({ name: c.column_name, type: c.data_type }));
await con.run(`DELETE FROM catalog WHERE table_name = 'sanita_spesa'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('sanita_spesa', 'openbdap.mef.gov.it', 'siope/aziende-sanitarie',
    '${esc("Spesa ed entrate delle aziende sanitarie (SIOPE)")}',
    '${esc("Health authority spending and revenue (SIOPE)")}',
    '${esc(`Quanto paga e quanto incassa per CASSA ogni azienda sanitaria italiana, per anno e categoria del piano dei conti — redditi da lavoro dipendente, acquisto di beni e servizi, investimenti fissi — dai flussi SIOPE del MEF. \`movimento\` distingue spesa da entrata. QUATTRO TIPOLOGIE, e non vanno sommate alla cieca: AS sono le ASL, AG le gestioni ASL, RS la gestione sanitaria accentrata delle Regioni, AR le agenzie regionali; la colonna \`tipologia\` le separa. Gli importi sono CUMULATI da inizio anno e qui è già tenuto il mese più alto pubblicato: \`mese\` = 12 è l'anno chiuso, un valore minore è un anno parziale che non si confronta con quelli interi. Escludere le partite di giro (titolo 7 in spesa, 9 in entrata) dai totali. SIOPE non porta il codice dell'azienda ma solo il nome, quindi NON si aggancia a sanita_asl_comuni: quello che c'è è \`codice_istat_sede\`, il comune dove l'azienda ha sede, che è geografia vera e non un aggancio per nome fatto a indovinare.`)}',
    '${esc(`How much each Italian health authority pays and collects on a CASH basis, by year and chart-of-accounts category — staff costs, goods and services, fixed investment — from the Treasury's SIOPE flows. \`movimento\` separates spending from revenue. FOUR ENTITY TYPES, not to be summed blindly: AS are local health authorities, AG their managed accounts, RS regions' centralised health accounting, AR regional health agencies; the \`tipologia\` column separates them. Amounts are CUMULATIVE from the start of the year and the highest published month is already the one kept: \`mese\` = 12 is a closed year, anything less is a partial year that must not be compared with whole ones. Exclude suspense items (title 7 in spending, 9 in revenue) from totals. SIOPE carries no authority code, only the full name, so it does NOT join sanita_asl_comuni: what it has is \`codice_istat_sede\`, the municipality where the authority is seated — real geography rather than a guessed name match.`)}',
    'https://openbdap.mef.gov.it/', now(), ${Number(st.righe)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nsanita_spesa: ${st.righe} righe, ${st.enti} enti`);
await con.run("CHECKPOINT");
con.closeSync();
