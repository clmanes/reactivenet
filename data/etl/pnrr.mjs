// Ingestione dei progetti del PNRR (ReGiS, via il catalogo open data di Italia
// Domani) → una tabella in DuckDB + una riga nel `catalog`:
//   pnrr_progetti  (~291k)  un progetto per riga: missione, componente, misura,
//                           importi, soggetto attuatore, stato, date — e il COMUNE
//
// Chiude la catena del denaro pubblico che il warehouse già teneva a metà:
// `anac_cig` (chi ha vinto la gara) → `anac_aggiudicatari` → `opencoesione` (i fondi
// di coesione) → `opencup` (l'investimento pubblico in generale) → e ora il PNRR, che
// era l'unico dei quattro a mancare.
//
// FONTE — la prima di questo gruppo con una licenza DICHIARATA, CC-BY-4.0:
//   https://www.italiadomani.gov.it/content/sogei-ng/it/it/catalogo-open-data/Progetti_del_PNRR.html
//   ~300 MB di CSV, una versione ogni pochi mesi.
//
// L'URL NON VA CABLATO, per la stessa ragione della classificazione sismica: la
// versione corrente sta sotto /content/dam/sogei-ng/opendata/, le passate sotto
// opendata_<mese><anno>/, e a ogni pubblicazione quella corrente diventa un archivio.
// Un link scritto qui continuerebbe a funzionare servendo per sempre la versione di
// oggi, che è il modo peggiore di rompersi: nessun errore, dati fermi. Si legge la
// pagina e si prende il PRIMO link al CSV, che è la versione corrente.
//
// IL COMUNE NON È NEL DATASET, ed è la cosa più importante da sapere qui. Le 63
// colonne di ReGiS descrivono il progetto e il suo finanziamento e non dicono DOVE
// sia: la localizzazione sta in OpenCUP, che il warehouse ha già, e si raggiunge per
// CUP. Misurato su questa edizione: il 99,9% dei CUP del PNRR è in `opencup`, e
// l'88,6% ne ricava un codice ISTAT. Il restante 11% ha un CUP noto ma nessuna
// localizzazione comunale — sono gli interventi nazionali e regionali, che un CUP non
// colloca in un municipio perché davvero non stanno in uno.
//
// **Quindi una vista filtrata per comune NON vede tutto il piano**, e la differenza
// non è un errore da correggere: è la forma del PNRR. La percentuale è stampata a
// fine ETL apposta, perché se un giorno crolla si vede subito.
//
// Questo rende l'ETL DIPENDENTE da opencup: senza, la tabella si costruisce lo stesso
// ma senza territorio, e lo script lo dice invece di produrre in silenzio una tabella
// che non si può mappare.
//
// TRAPPOLE:
//  - **HEAD risponde 404 su questo host mentre GET funziona**: sondare l'URL con una
//    HEAD prima di scaricarlo fa concludere che il file non esiste;
//  - il CSV è separato da **punto e virgola**, con **BOM** in testa (la prima colonna
//    si chiamerebbe "﻿Programma") e gli importi con la **virgola decimale**:
//    `TRY_CAST` diretto darebbe NULL su ogni cifra con decimali, cioè proprio sulle
//    più grandi;
//  - le date sono **DD/MM/YYYY**, che `TRY_CAST` legge al contrario o non legge: si
//    convertono con `strptime`;
//  - **il CUP non è una chiave**: 291.398 righe per 285.994 CUP distinti, perché un
//    progetto può stare sotto più misure. Chi conta i progetti per CUP conta meno del
//    vero, chi somma gli importi per CUP li conta più volte;
//  - `read_csv` con `all_varchar = true` e conversione a valle: l'inferenza su un file
//    da 300 MB campiona le prime righe e sbaglia tipo su colonne che si popolano più
//    avanti.
//
// Uso:  bun etl/pnrr.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/pnrr/";
const DB = ROOT + "warehouse.duckdb";
const PAGINA =
  "https://www.italiadomani.gov.it/content/sogei-ng/it/it/catalogo-open-data/Progetti_del_PNRR.html";
const ORIGINE = "https://www.italiadomani.gov.it";

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

mkdirSync(RAW, { recursive: true });
console.log("▸ progetti del PNRR (ReGiS, Italia Domani)");

const locale = RAW + "PNRR_Progetti.csv";
if (refresh || !(await Bun.file(locale).exists())) {
  const pagina = await fetch(PAGINA, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
  if (!pagina.ok) throw new Error(`pagina Italia Domani: HTTP ${pagina.status}`);
  const html = await pagina.text();
  // Il PRIMO CSV della pagina è la versione corrente; quelli sotto sono l'archivio,
  // in cartelle datate. Prendere l'ultimo, o uno per nome, significa ingerire per
  // sempre una versione vecchia senza che nulla lo segnali.
  const trovato = html.match(/\/content\/dam\/sogei-ng\/[^"'\s]*PNRR_Progetti[^"'\s]*\.csv/i);
  if (!trovato)
    throw new Error(
      `link al CSV non trovato nella pagina di Italia Domani. Ha cambiato forma: aprila ` +
        `e verifica dove sta ora il file (${PAGINA}).`,
    );
  const url = ORIGINE + trovato[0];
  console.log(`  ${trovato[0]}`);
  // Niente HEAD di controllo: questo host risponde 404 alle HEAD e 200 alle GET.
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(900_000) });
  if (!res.ok) throw new Error(`CSV: HTTP ${res.status}`);
  const testo = await res.text();
  if (testo.trimStart().startsWith("<")) throw new Error("il CSV è arrivato come pagina HTML");
  // Il BOM va via prima che DuckDB legga l'intestazione, o la prima colonna prende un
  // nome che non si può scrivere in una query.
  await Bun.write(locale, testo.charCodeAt(0) === 0xfeff ? testo.slice(1) : testo);
} else {
  console.log("  dalla cache in raw/");
}

// Anche il file in cache: un CSV messo lì a mano, o scaricato da una versione
// precedente di questo script, porta ancora il BOM — e allora la prima colonna si
// chiama "﻿Programma", che nessuna query può nominare.
{
  const primi = new Uint8Array(await Bun.file(locale).slice(0, 3).arrayBuffer());
  if (primi[0] === 0xef && primi[1] === 0xbb && primi[2] === 0xbf) {
    const testo = await Bun.file(locale).text();
    await Bun.write(locale, testo.slice(1));
    console.log("  BOM rimosso dal file in cache");
  }
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// vss perché il CHECKPOINT finale tocca tutto il database e le tabelle con indice
// HNSW non si ricostruiscono senza l'estensione.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo AS
  SELECT * FROM read_csv('${esc(locale)}', delim = ';', header = true,
    all_varchar = true, ignore_errors = true)`);

const colonne = (
  await con.runAndReadAll(`SELECT column_name FROM (DESCRIBE _grezzo)`)
).getRowObjects().map(r => r.column_name);
for (const attesa of ["CUP", "Missione", "Finanziamento PNRR", "Stato Avanzamento Progetto"])
  if (!colonne.includes(attesa))
    throw new Error(`colonna "${attesa}" assente: il tracciato è cambiato`);

// Importi con la virgola decimale, date all'italiana. Entrambi silenziosi se sbagliati
// — un NULL non si vede in una somma.
const euro = c => `TRY_CAST(replace(replace("${c}", '.', ''), ',', '.') AS DOUBLE)`;
const giorno = c => `TRY_CAST(strptime("${c}", '%d/%m/%Y') AS DATE)`;

// La localizzazione arriva da OpenCUP per CUP. Se quella tabella non c'è, si va avanti
// senza territorio dicendolo: una tabella senza comune resta utile per gli aggregati
// nazionali, una tabella assente non serve a nessuno.
const conOpencup = (
  await con.runAndReadAll(
    `SELECT count(*) n FROM information_schema.tables WHERE table_name = 'opencup'`,
  )
).getRowObjects()[0].n;
if (!Number(conOpencup))
  console.warn(
    `  ⚠ opencup non è nel warehouse: i progetti entrano SENZA comune, provincia e\n` +
      `    regione. Esegui prima 'bun run etl:opencup' e poi questo.`,
  );

const territorio = Number(conOpencup)
  ? `LEFT JOIN opencup o ON o.cup = g."CUP"`
  : `LEFT JOIN (SELECT NULL::VARCHAR cup, NULL::VARCHAR codice_istat, NULL::VARCHAR comune,
       NULL::VARCHAR provincia, NULL::VARCHAR regione) o ON false`;

await con.run(`CREATE OR REPLACE TABLE pnrr_progetti AS
  SELECT g."CUP" AS cup,
    g."Codice Locale Progetto" AS codice_locale_progetto,
    g."Missione" AS missione,
    g."Descrizione Missione" AS missione_descrizione,
    g."Componente" AS componente,
    g."Descrizione Componente" AS componente_descrizione,
    g."Codice Univoco Misura" AS misura,
    g."Descrizione Misura" AS misura_descrizione,
    g."Codice Univoco Submisura" AS submisura,
    g."Amministrazione Titolare" AS amministrazione_titolare,
    g."Titolo Progetto" AS titolo,
    g."Sintesi Progetto" AS sintesi,
    g."Stato Avanzamento Progetto" AS stato_avanzamento,
    g."CUP Descrizione Settore" AS settore,
    g."CUP Descrizione Natura" AS natura,
    ${euro("Finanziamento PNRR")} AS finanziamento_pnrr,
    ${euro("Finanziamento PNC")} AS finanziamento_pnc,
    ${euro("Finanziamento Totale")} AS finanziamento_totale,
    ${euro("Finanziamento Totale Pubblico")} AS finanziamento_totale_pubblico,
    g."Soggetto Attuatore" AS soggetto_attuatore,
    g."Codice Fiscale Soggetto Attuatore" AS cf_soggetto_attuatore,
    ${giorno("Data Inizio Progetto Prevista")} AS data_inizio_prevista,
    ${giorno("Data Inizio Progetto Effettiva")} AS data_inizio_effettiva,
    ${giorno("Data Fine Progetto Prevista")} AS data_fine_prevista,
    ${giorno("Data Fine Progetto Effettiva")} AS data_fine_effettiva,
    -- dal join a opencup: il dataset di ReGiS non dice dove sta il progetto
    o.codice_istat, o.comune, o.provincia, o.regione
  FROM _grezzo g
  ${territorio}
  WHERE g."CUP" IS NOT NULL AND g."CUP" <> ''
  ORDER BY g."Missione", g."CUP"`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  count(*) progetti,
  count(DISTINCT cup) cup_distinti,
  count(codice_istat) con_comune,
  count(DISTINCT codice_istat) comuni,
  round(sum(finanziamento_pnrr) / 1e9, 2) miliardi_pnrr,
  round(sum(finanziamento_totale) / 1e9, 2) miliardi_totali
  FROM pnrr_progetti`);
const pctTerr = Number(st.progetti) ? Number(st.con_comune) / Number(st.progetti) : 0;
console.log(`  progetti:          ${st.progetti} (${st.cup_distinti} CUP distinti)`);
console.log(`  con comune:        ${st.con_comune} (${(pctTerr * 100).toFixed(1)}%), in ${st.comuni} comuni`);
console.log(`  finanziamento:     ${st.miliardi_pnrr} mld PNRR, ${st.miliardi_totali} mld totali`);
const perMissione = (
  await con.runAndReadAll(
    `SELECT missione, count(*) n, round(sum(finanziamento_pnrr) / 1e9, 1) mld
     FROM pnrr_progetti GROUP BY 1 ORDER BY 1`,
  )
).getRowObjects();
for (const m of perMissione) console.log(`    ${m.missione}: ${m.n} progetti, ${m.mld} mld`);
// I codici comunali arrivano da OpenCUP, che porta la storia: un progetto del 2021 è
// registrato sotto il comune che esisteva allora, e la Sardegna nel 2026 ha rinumerato
// le sue province. Perciò i codici distinti sono PIÙ dei comuni di oggi, e una manciata
// non si aggancia ai confini correnti. È un fatto del dato, non un errore — ma va
// contato, perché una mappa costruita con una JOIN semplice perde silenziosamente
// quelle righe.
if (Number(conOpencup)) {
  const terr = await q(`SELECT
    count(DISTINCT p.codice_istat) codici,
    count(DISTINCT p.codice_istat) FILTER (WHERE g.codice_istat IS NULL) storici
    FROM pnrr_progetti p LEFT JOIN istat_confini_comuni g USING (codice_istat)
    WHERE p.codice_istat IS NOT NULL`);
  console.log(
    `  codici comunali:   ${terr.codici}, di cui ${terr.storici} non nei confini correnti ` +
      `(comuni fusi, province sarde rinumerate)`,
  );
}
if (Number(conOpencup) && pctTerr < 0.8)
  console.warn(
    `  ⚠ meno dell'80% dei progetti ha un comune: di norma è l'88%. O opencup è vecchio\n` +
      `    rispetto a questa edizione del PNRR, o i CUP hanno cambiato forma.`,
  );

async function catalog(tbl, source, dataflow, titleIt, titleEn, descIt, descEn, url, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', '${esc(source)}', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      '${esc(url)}', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

await catalog(
  "pnrr_progetti",
  "italiadomani.gov.it",
  "regis/progetti-pnrr",
  "Progetti del PNRR (ReGiS)",
  "Recovery plan projects (ReGiS)",
  `Tutti i progetti finanziati dal PNRR come li registra ReGiS: missione, componente e misura, titolo e sintesi, importi (PNRR, PNC, totale), soggetto attuatore, stato di avanzamento e date previste ed effettive. Licenza CC-BY-4.0. Il comune arriva da opencup attraverso il CUP e c'è per circa l'88% dei progetti: il resto sono interventi nazionali e regionali, che non stanno in un municipio — quindi una vista filtrata per comune non mostra tutto il piano, ed è corretto così. ATTENZIONE: il CUP non è una chiave, un progetto può comparire sotto più misure, quindi sommare gli importi raggruppando per CUP li conta più volte.`,
  `Every project funded by the Italian recovery plan as recorded in ReGiS: mission, component and measure, title and abstract, amounts (PNRR, PNC, total), implementing body, progress status and planned and actual dates. CC-BY-4.0. The municipality is joined from opencup through the CUP and is present for about 88% of projects: the rest are national and regional interventions, which do not sit in one municipality — so a view filtered by municipality does not show the whole plan, and that is correct. MIND: the CUP is not a key, a project can appear under several measures, so summing amounts grouped by CUP counts them more than once.`,
  PAGINA,
  Number(st.progetti),
);

console.log(`\npnrr_progetti: ${st.progetti} progetti, ${st.miliardi_pnrr} mld di finanziamento PNRR`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
