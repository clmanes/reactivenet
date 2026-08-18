// Ingestione delle STRUTTURE DEL SERVIZIO SANITARIO NAZIONALE (Ministero della
// Salute — dati.salute.gov.it, Open Data IODL 2.0) → tre tabelle in DuckDB + righe
// nel `catalog`:
//
//   sanita_posti_letto   posti letto per struttura ospedaliera e disciplina,
//                        2010-2023 — con il CODICE ISTAT del comune e l'indirizzo
//   sanita_asl_comuni    quale ASL serve ogni comune, e quanta popolazione
//   sanita_strutture     ospedali pubblici e case di cura accreditate con
//                        personale, ricoveri e giornate di degenza
//
// **`sanita_asl_comuni` è la chiave di volta, e vale più di quanto sembri.** Quasi
// tutto quello che il SSN pubblica è per AZIENDA SANITARIA, non per comune: le
// ASL sono 110 e i comuni 7896, e senza questa corrispondenza ogni dato sanitario
// resta appeso a un'entità che nessun cittadino sa nominare. Questa tabella dice a
// ogni comune qual è la sua, con la popolazione che quella ASL vi serve — ed è
// pubblicata dal Ministero con il codice ISTAT già dentro, quindi non c'è nessun
// aggancio per nome da indovinare.
//
// TRAPPOLE:
//  - **IL CODICE ASL È UNICO SOLO DENTRO LA REGIONE, e contarlo da solo mente.**
//    Il codice `201` esiste in dieci regioni diverse, il `202` in otto: contando i
//    codici distinti le aziende sanitarie italiane risultano 52, mentre sono 110.
//    Non è un errore di bordo — è un conteggio plausibile, stampato con sicurezza e
//    sbagliato di più del doppio, cioè il tipo di numero che finisce in una slide.
//    La tabella porta perciò `asl_id` = codice regione + codice azienda, che è
//    l'unica colonna con cui si può raggruppare o fare un join senza fondere
//    aziende di regioni diverse;
//  - **gli URL dei file NON sono costruiti a mano.** Il portale è un Drupal e i
//    file stanno sotto `/sites/default/files/<anno-mese>/...`: quel segmento cambia
//    a ogni ripubblicazione, e un percorso indovinato oggi è un 404 domani. Ogni
//    file è preso leggendo la PAGINA del dataset e cavandone il primo link `.csv`,
//    che è la stessa disciplina di `zone-sismiche.mjs`;
//  - **i file sono in ISO-8859-1**, non UTF-8: letti come UTF-8 le denominazioni
//    con accento diventano illeggibili. Si convertono con `iconv` prima di darli a
//    DuckDB, come in `patrimonio-pa.mjs`;
//  - **il punto è il separatore delle MIGLIAIA**, non dei decimali: nelle colonne
//    dei ricoveri e delle giornate di degenza `7.035` vale settemilatrentacinque, e
//    letto come numero decimale diventerebbe sette. Non è un caso di bordo: sono
//    esattamente le colonne più grandi, cioè quelle in cui l'errore è più grosso e
//    meno visibile. I punti si tolgono prima del cast;
//  - **ogni campo di testo è riempito di spazi a destra** (i file nascono da un
//    tracciato a larghezza fissa): senza `trim` il nome del comune non aggancia
//    niente e le denominazioni si portano dietro venti spazi;
//  - la serie dei posti letto sta in **cinque file** — uno per il 2010-2019 e uno
//    per ciascun anno dal 2020 — con lo stesso identico tracciato di 19 colonne.
//    Sono uniti qui, e l'ETL VERIFICA che le intestazioni coincidano invece di
//    fidarsi: un tracciato cambiato in silenzio è il modo in cui una colonna finisce
//    sotto il nome di un'altra;
//  - `sanita_strutture` mette insieme due file — ospedali pubblici e case di cura
//    accreditate — perché hanno lo stesso tracciato e rispondono alla stessa
//    domanda; la colonna `natura` dice da quale dei due viene una riga, e sommare
//    senza guardarla mescola pubblico e privato accreditato;
//  - il comune in quei due file è un NOME in maiuscolo senza codice, e agganciarlo
//    costa due normalizzazioni che da sole valgono trentadue righe su 993. I
//    confini ISTAT portano il nome BILINGUE dei comuni altoatesini
//    («Bolzano/Bozen») mentre il Ministero scrive solo l'italiano: senza
//    confrontare anche la parte prima della barra, TUTTI gli ospedali dell'Alto
//    Adige risultano inesistenti — e a chi guarda da Bolzano l'app dice che nel suo
//    bacino non c'è nessuna struttura, che è la forma peggiore di errore perché
//    sembra una risposta. E il Ministero usa l'APOSTROFO al posto dell'accento
//    finale («FORLI'»), la trappola delle province in `aci-veicoli.mjs`. Con
//    entrambe le correzioni i senza-comune scendono da 37 a 5, e quei cinque sono
//    comuni rinominati dopo la rilevazione: restano tali invece di far nascere una
//    seconda tabella editoriale per cinque righe. La copertura è stampata.
//
// Uso:  bun etl/sanita-strutture.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/sanita/";
const DB = ROOT + "warehouse.duckdb";
const PORTALE = "https://www.dati.salute.gov.it";

// dataset del portale → nome locale. L'URL del file si legge dalla pagina.
const POSTI_LETTO = [
  ["posti-letto-struttura-ospedaliera-dal-2010-al-2019", "posti-letto-2010-2019.csv"],
  ["posti-letto-struttura-ospedaliera-2020", "posti-letto-2020.csv"],
  ["posti-letto-struttura-ospedaliera-2021", "posti-letto-2021.csv"],
  ["posti-letto-struttura-ospedaliera-2022", "posti-letto-2022.csv"],
  ["posti-letto-struttura-ospedaliera-2023", "posti-letto-2023.csv"],
];
const ALTRI = [
  ["corrispondenze-asl-comuni-e-popolazione-residente-anno-2024", "asl-comuni.csv"],
  ["strutture-di-ricovero-pubbliche-e-equiparate-presenti-nel-territorio-della-asl", "ricovero-pubbliche.csv"],
  ["case-di-cura-accreditate-presenti-nel-territorio-della-asl", "case-di-cura.csv"],
];

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ strutture del Servizio Sanitario Nazionale (Ministero della Salute)");

// Legge la pagina del dataset e ne cava il primo link a un CSV: gli URL dei file
// contengono un segmento con anno e mese che cambia a ogni ripubblicazione.
async function urlDelCsv(dataset) {
  const res = await fetch(`${PORTALE}/it/dataset/${dataset}/`, {
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`pagina del dataset ${dataset}: HTTP ${res.status}`);
  const html = await res.text();
  const m = html.match(/href="([^"]*\.csv)"/i);
  if (!m) throw new Error(`nessun CSV nella pagina del dataset ${dataset}`);
  return m[1].startsWith("http") ? m[1] : PORTALE + m[1];
}

// I file sono in ISO-8859-1: si convertono in UTF-8 prima di darli a DuckDB.
async function prendi(dataset, nome) {
  const dest = RAW + nome;
  if (!refresh && (await Bun.file(dest).exists())) return dest;
  const url = await urlDelCsv(dataset);
  const res = await fetch(url, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${nome}: HTTP ${res.status}`);
  const grezzo = RAW + nome + ".latin1";
  await Bun.write(grezzo, await res.arrayBuffer());
  const conv = Bun.spawnSync(["iconv", "-f", "ISO-8859-1", "-t", "UTF-8", grezzo]);
  if (conv.exitCode !== 0) throw new Error(`iconv su ${nome}: ${conv.stderr}`);
  await Bun.write(dest, conv.stdout);
  console.log(`  ${nome} — ${(conv.stdout.length / 1e6).toFixed(1)} MB`);
  return dest;
}

const filePostiLetto = [];
for (const [dataset, nome] of POSTI_LETTO) filePostiLetto.push(await prendi(dataset, nome));
const fAsl = await prendi(...ALTRI[0]);
const fRic = await prendi(...ALTRI[1]);
const fCdc = await prendi(...ALTRI[2]);

// Il tracciato dei cinque file dei posti letto deve coincidere: una colonna in più
// o in meno sposta tutte le altre e il dato finisce sotto il nome sbagliato.
const intestazioni = [];
for (const f of filePostiLetto) {
  const prima = (await Bun.file(f).text()).slice(0, 4000).split("\n")[0].trim();
  intestazioni.push(prima);
}
if (new Set(intestazioni).size !== 1) {
  console.log("  ⚠ i cinque file dei posti letto NON hanno lo stesso tracciato:");
  intestazioni.forEach((h, i) => console.log(`     ${POSTI_LETTO[i][1]}: ${h.slice(0, 120)}`));
  throw new Error("tracciato dei posti letto disallineato: verificare prima di caricare");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const leggi = f =>
  `read_csv('${esc(f)}', delim = ';', header = true, all_varchar = true, ignore_errors = true)`;

// Il punto separa le MIGLIAIA in questi file: va tolto prima del cast, o 7.035
// diventa sette.
const intero = c => `TRY_CAST(replace(trim(${c}), '.', '') AS BIGINT)`;

// ---------------------------------------------------------------- posti letto
await con.run(`CREATE OR REPLACE TABLE sanita_posti_letto AS
  SELECT TRY_CAST(trim("Anno") AS INTEGER) AS anno,
    trim("Codice struttura") AS codice_struttura,
    trim("Denominazione struttura") AS struttura,
    trim("Indirizzo") AS indirizzo,
    trim("Codice Comune") AS codice_istat,
    trim("Comune") AS comune_dichiarato,
    trim("Sigla provincia") AS sigla,
    trim("Descrizione Regione") AS regione,
    trim("Descrizione tipo struttura") AS tipo_struttura,
    trim("Tipo di Disciplina") AS disciplina,
    ${intero('"Posti letto degenza ordinaria"')} AS letti_ordinari,
    ${intero('"Posti letto degenza a pagamento"')} AS letti_a_pagamento,
    ${intero('"Posti letto Day Hospital"')} AS letti_day_hospital,
    ${intero('"Posti letto Day Surgery"')} AS letti_day_surgery,
    ${intero('"Totale posti letto"')} AS letti
  FROM (${filePostiLetto.map(f => `SELECT * FROM ${leggi(f)}`).join(" UNION ALL ")})
  WHERE trim("Anno") IS NOT NULL AND trim("Codice Comune") <> ''
  ORDER BY anno, codice_struttura`);

// --------------------------------------------------------------- ASL ↔ comuni
await con.run(`CREATE OR REPLACE TABLE sanita_asl_comuni AS
  SELECT TRY_CAST(trim("ANNO") AS INTEGER) AS anno,
    trim("CODICE COMUNE") AS codice_istat,
    trim("COMUNE") AS comune_dichiarato,
    trim("CODICE AZIENDA") AS codice_asl,
    -- il codice azienda si ripete fra regioni: questa è la sola chiave sicura
    trim("CODICE REGIONE") || '-' || trim("CODICE AZIENDA") AS asl_id,
    trim("DENOMINAZIONE AZIENDA") AS asl,
    trim("DENOMINAZIONE REGIONE") AS regione,
    ${intero('"MASCHI"')} AS maschi,
    ${intero('"FEMMINE"')} AS femmine,
    ${intero('"TOTALE"')} AS popolazione_servita
  FROM ${leggi(fAsl)}
  WHERE trim("CODICE COMUNE") <> ''
  ORDER BY codice_istat`);

// ----------------------------------------------- strutture con attività e personale
// I due file hanno lo stesso tracciato ma intestazioni scritte diversamente
// (maiuscole e spazi), quindi si leggono per POSIZIONE, non per nome.
const perPosizione = (f, natura) => `
  SELECT '${natura}' AS natura,
    TRY_CAST(trim(c[1]) AS INTEGER) AS anno,
    trim(c[2]) AS codice_struttura,
    trim(c[3]) AS struttura,
    trim(c[4]) AS comune_dichiarato,
    trim(c[5]) AS sigla,
    ${intero("c[6]")} AS letti_previsti,
    ${intero("c[7]")} AS letti_utilizzati,
    ${intero("c[10]")} AS personale,
    ${intero("c[13]")} AS medici,
    ${intero("c[16]")} AS infermieri,
    ${intero("c[17]")} AS ricoveri,
    ${intero("c[18]")} AS giornate_degenza,
    ${intero("c[19]")} AS giornate_disponibili
  FROM (SELECT string_split(line, ';') AS c
        FROM read_csv('${esc(f)}', delim = '\\x01', header = true,
                      columns = {'line': 'VARCHAR'}, ignore_errors = true))
  WHERE len(c) >= 19 AND TRY_CAST(trim(c[1]) AS INTEGER) IS NOT NULL`;

await con.run(`CREATE OR REPLACE TABLE _strutture AS
  ${perPosizione(fRic, "pubblica")}
  UNION ALL
  ${perPosizione(fCdc, "casa di cura accreditata")}`);

// Il comune è un nome in maiuscolo: si aggancia per (nome normalizzato, sigla).
// Due cose vanno normalizzate o l'Alto Adige e la Romagna restano fuori:
//  - i confini ISTAT portano il nome BILINGUE dei comuni altoatesini
//    («Bolzano/Bozen», «Merano/Meran») mentre il Ministero scrive solo l'italiano:
//    si confronta anche la parte prima della barra;
//  - il Ministero usa l'APOSTROFO al posto dell'accento finale («FORLI'» per
//    «Forlì»), la stessa trappola delle province in `aci-veicoli.mjs`: si toglie
//    l'apostrofo da una parte e l'accento dall'altra, e i due nomi si incontrano.
// Apostrofo per accento, nome bilingue altoatesino, e spaziatura che balla:
// togliendo apostrofi E spazi i tre casi si riducono a uno.
const nome = col =>
  `upper(strip_accents(replace(replace(${col}, '''', ''), ' ', '')))`;
await con.run(`CREATE OR REPLACE TABLE sanita_strutture AS
  SELECT s.natura, s.anno, s.codice_struttura, s.struttura,
    g.codice_istat,
    coalesce(g.comune, s.comune_dichiarato) AS comune,
    s.sigla, g.provincia, g.regione,
    s.letti_previsti, s.letti_utilizzati,
    s.personale, s.medici, s.infermieri,
    s.ricoveri, s.giornate_degenza, s.giornate_disponibili,
    round(s.giornate_degenza * 100.0 / nullif(s.giornate_disponibili, 0), 1) AS occupazione_pct,
    round(s.giornate_degenza * 1.0 / nullif(s.ricoveri, 0), 1) AS degenza_media
  FROM _strutture s
  LEFT JOIN istat_confini_comuni g
    ON g.sigla = s.sigla
   AND ${nome("split_part(g.comune, '/', 1)")} = ${nome("s.comune_dichiarato")}
  ORDER BY s.natura, comune, s.struttura`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

const pl = await q(`SELECT count(*) righe, count(DISTINCT codice_struttura) strutture,
  count(DISTINCT codice_istat) comuni, min(anno) dal, max(anno) al,
  sum(letti) FILTER (WHERE anno = (SELECT max(anno) FROM sanita_posti_letto)) letti_ultimo
  FROM sanita_posti_letto`);
console.log(
  `  posti letto:  ${pl.righe} righe · ${pl.strutture} strutture in ${pl.comuni} comuni · ` +
    `${pl.dal}-${pl.al} · ${pl.letti_ultimo} letti nell'ultimo anno`,
);

// Contate su asl_id, non sul codice: quello si ripete fra regioni (vedi trappole).
const asl = await q(`SELECT count(*) righe, count(DISTINCT asl_id) asl,
  count(DISTINCT codice_asl) asl_sbagliato, sum(popolazione_servita) pop
  FROM sanita_asl_comuni`);
console.log(
  `  ASL:          ${asl.righe} comuni serviti da ${asl.asl} aziende · ${asl.pop} abitanti ` +
    `(sul solo codice ne risulterebbero ${asl.asl_sbagliato}: si ripete fra regioni)`,
);

const st = await q(`SELECT count(*) righe,
  count(*) FILTER (WHERE codice_istat IS NULL) senza_comune,
  sum(ricoveri) ricoveri, sum(letti_utilizzati) letti
  FROM sanita_strutture`);
console.log(
  `  strutture:    ${st.righe} · ${st.ricoveri} ricoveri · ${st.letti} letti utilizzati` +
    (Number(st.senza_comune) > 0 ? ` · ${st.senza_comune} senza aggancio al comune` : ""),
);

// Controllo indipendente: la popolazione della corrispondenza ASL deve stare
// vicino a quella residente che il warehouse già conosce. Se diverge di molto, uno
// dei due non è quello che si crede.
const conf = await q(`SELECT
  (SELECT sum(popolazione_servita) FROM sanita_asl_comuni) asl,
  (SELECT sum(popolazione) FROM istat_popolazione) istat`);
const scarto = Math.abs(Number(conf.asl) - Number(conf.istat)) / Number(conf.istat);
console.log(
  `  ✓ popolazione: ${conf.asl} (ASL) contro ${conf.istat} (ISTAT), scarto ${(scarto * 100).toFixed(1)}%` +
    (scarto > 0.05 ? " — ⚠ oltre il 5%, verificare le annate" : ""),
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
  "sanita_posti_letto",
  "dati.salute.gov.it",
  "salute/posti-letto-struttura-ospedaliera",
  "Posti letto per struttura ospedaliera (Ministero della Salute)",
  "Hospital beds by facility (Ministry of Health)",
  `Quanti posti letto ha ogni struttura ospedaliera italiana, divisi per disciplina (ACUTI, riabilitazione, lungodegenza) e per regime (degenza ordinaria, day hospital, day surgery), ogni anno dal 2010. Una riga è una struttura in un anno per una disciplina, quindi i letti di un ospedale si ottengono sommando le sue righe. Porta il \`codice_istat\` del comune e l'indirizzo, quindi si aggancia direttamente a istat_confini_comuni e a istat_popolazione per il rapporto letti/abitanti — che è la misura che questa tabella esiste per rendere calcolabile, e va fatta sulla PROVINCIA o sulla ASL più che sul comune, perché un ospedale serve un bacino e non il paese in cui sta. Il tipo di struttura distingue l'ospedale a gestione diretta dall'azienda ospedaliera, dal policlinico universitario e dalla casa di cura accreditata.`,
  `How many beds each Italian hospital facility has, split by discipline (acute, rehabilitation, long-term care) and by regime (ordinary stay, day hospital, day surgery), each year since 2010. A row is one facility in one year for one discipline, so a hospital's beds are the sum of its rows. It carries the municipality \`codice_istat\` and the address, so it joins straight to istat_confini_comuni and istat_popolazione for the beds-per-resident ratio — the measure this table exists to make computable, and one to compute over the PROVINCE or the health authority rather than the municipality, because a hospital serves a catchment and not the town it stands in. The facility type separates directly-managed hospitals from hospital trusts, university polyclinics and accredited private clinics.`,
  "https://www.dati.salute.gov.it/",
  Number(pl.righe),
);

await catalog(
  "sanita_asl_comuni",
  "dati.salute.gov.it",
  "salute/corrispondenze-asl-comuni",
  "Quale ASL serve ogni comune (Ministero della Salute)",
  "Which health authority serves each municipality (Ministry of Health)",
  `La corrispondenza fra ogni comune italiano e l'azienda sanitaria locale che lo serve, con la popolazione residente per sesso. È LA CHIAVE per leggere qualunque dato sanitario a livello di territorio: quasi tutto quello che il Servizio Sanitario Nazionale pubblica è per AZIENDA — le ASL sono 110, i comuni 7896 — e senza questa tabella un dato sanitario resta appeso a un'entità che nessun cittadino sa nominare. Il codice ISTAT del comune è già nel file del Ministero, quindi l'aggancio non passa da nessun confronto per nome. Serve anche al contrario: dato un comune, dice quale bacino condivide con quali altri comuni, che è il modo giusto di leggere la dotazione di ospedali e posti letto. ATTENZIONE a raggruppare: \`codice_asl\` è unico solo DENTRO la regione — il codice 201 esiste in dieci regioni — quindi contare o unire su quello fonde aziende diverse e restituisce 52 aziende invece delle 110 vere. La colonna da usare è \`asl_id\`.`,
  `The correspondence between each Italian municipality and the local health authority that serves it, with resident population by sex. It is THE key for reading any health data territorially: nearly everything the National Health Service publishes is by AUTHORITY — there are 110 of them against 7,896 municipalities — and without this table a health figure hangs off an entity no citizen can name. The municipality's ISTAT code is already in the Ministry's file, so the join needs no name matching. It also works the other way: given a municipality it says which catchment it shares with which others, which is the right way to read hospital and bed provision. MIND the grouping: \`codice_asl\` is unique only WITHIN a region — code 201 exists in ten of them — so counting or joining on it merges distinct authorities and returns 52 instead of the real 110. The column to use is \`asl_id\`.`,
  "https://www.dati.salute.gov.it/",
  Number(asl.righe),
);

await catalog(
  "sanita_strutture",
  "dati.salute.gov.it",
  "salute/strutture-ricovero-e-case-di-cura",
  "Ospedali e case di cura: personale, ricoveri e degenza (Ministero della Salute)",
  "Hospitals and clinics: staff, admissions and length of stay (Ministry of Health)",
  `Gli ospedali pubblici e le case di cura accreditate d'Italia con quello che ci accade dentro: posti letto previsti e utilizzati, personale diviso fra medici e infermieri, ricoveri, giornate di degenza e giornate disponibili nell'anno. Da queste ultime due sono calcolati il tasso di OCCUPAZIONE dei letti e la DEGENZA MEDIA, che sono le due misure con cui si legge un ospedale: quanto è pieno e quanto ci si resta. \`natura\` dice se la riga è una struttura pubblica o una casa di cura privata accreditata, e sommare senza guardarla mescola due mondi che si finanziano in modo diverso. Il comune arriva come nome in maiuscolo e viene agganciato per (nome, sigla provincia) ai confini ISTAT.`,
  `Italy's public hospitals and accredited private clinics with what happens inside them: planned and used beds, staff split between doctors and nurses, admissions, inpatient days and available days in the year. From the last two are computed bed OCCUPANCY and average LENGTH OF STAY, the two measures a hospital is read by: how full it is and how long people stay. \`natura\` says whether a row is a public facility or an accredited private clinic, and summing without looking at it mixes two worlds funded differently. The municipality arrives as an uppercase name and is matched to ISTAT boundaries by (name, province code).`,
  "https://www.dati.salute.gov.it/",
  Number(st.righe),
);

console.log(
  `\nsanita_posti_letto: ${pl.righe} · sanita_asl_comuni: ${asl.righe} · sanita_strutture: ${st.righe}`,
);
await con.run("CHECKPOINT");
con.closeSync();
