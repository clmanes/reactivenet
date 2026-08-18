// Ingestione della classificazione sismica dei comuni (Dipartimento della Protezione
// Civile) → una tabella in DuckDB + una riga nel `catalog`:
//   zone_sismiche  (7896)  una riga per comune: la zona sismica, da 1 (pericolosità
//                          più alta) a 4 (più bassa)
//
// Una colonna sola, ma è la colonna che manca a chiunque incroci scuole, edifici
// pubblici o popolazione con il rischio: `edilizia_scolastica` porta già l'epoca di
// costruzione e la verifica sismica dell'edificio, e questa dice in che zona sta.
//
// FONTE (nessuna chiave; licenza NON dichiarata in pagina):
//   https://rischi.protezionecivile.gov.it/it/sismico/attivita/classificazione-sismica/
//   Un CSV di ~330 kB, aggiornato quando una regione emana un nuovo decreto — la
//   classificazione è regionale, il DPC la raccoglie.
//
// L'URL NON VA CABLATO. Il file sta sotto /static/<hash>/…: l'hash cambia a ogni
// pubblicazione, e un link scritto qui diventerebbe un 404 silenzioso al primo
// aggiornamento — cioè esattamente quando il dato è cambiato e serve. Quindi si legge
// la pagina e si prende il link da lì. Se un giorno la pagina cambia forma, questo
// script si ferma dicendolo, che è il comportamento giusto: meglio nessun dato che il
// dato di tre anni fa.
//
// TRAPPOLE:
//  - il CSV è **separato da punto e virgola, in UTF-8 con BOM e con fine riga CRLF**.
//    Il BOM finisce dentro il nome della prima colonna se non lo si toglie, e
//    "REGIONE" diventa una colonna che non esiste;
//  - COD_ISTAT_COMUNE arriva SENZA zeri iniziali (Agliè è 1001, non 001001): va lpad
//    a 6, o il join manca in silenzio tutti i comuni delle prime nove province;
//  - la zona è un CODICE, non una quantità: 2 non è "il doppio" di 1, e l'ordine è
//    invertito rispetto all'intuizione — 1 è la zona PIÙ pericolosa. Resta un intero
//    perché ordinarlo ha senso, ma il verso va detto ovunque lo si mostri;
//  - alcune regioni usano sottozone (3A, 3B): se compaiono, la colonna di testo le
//    conserva e quella intera prende la cifra iniziale, invece di scartare la riga.
//
// Uso:  bun etl/zone-sismiche.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/zone-sismiche/";
const DB = ROOT + "warehouse.duckdb";
const PAGINA = "https://rischi.protezionecivile.gov.it/it/sismico/attivita/classificazione-sismica/";
const ORIGINE = "https://rischi.protezionecivile.gov.it";

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

mkdirSync(RAW, { recursive: true });
console.log("▸ classificazione sismica dei comuni (Protezione Civile)");

const locale = RAW + "classificazione-sismica.csv";
let testo = null;
if (!refresh && (await Bun.file(locale).exists())) {
  testo = await Bun.file(locale).text();
  console.log("  dalla cache in raw/");
} else {
  const pagina = await fetch(PAGINA, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
  if (!pagina.ok) throw new Error(`pagina DPC: HTTP ${pagina.status}`);
  const html = await pagina.text();
  // Il link al CSV, qualunque hash porti e comunque sia datato nel nome.
  const trovato = html.match(/\/static\/[a-f0-9]+\/[^"'\s]*classificazione-sismica[^"'\s]*\.csv/i);
  if (!trovato)
    throw new Error(
      `link al CSV non trovato nella pagina DPC. La pagina ha cambiato forma: aprila e ` +
        `verifica dove sta ora il file (${PAGINA}).`,
    );
  const url = ORIGINE + trovato[0];
  console.log(`  ${url.split("/").pop()}`);
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
  if (!res.ok) throw new Error(`CSV: HTTP ${res.status}`);
  testo = await res.text();
  if (testo.trimStart().startsWith("<")) throw new Error("il CSV è arrivato come pagina HTML");
  await Bun.write(locale, testo);
}

// Il BOM va via qui, prima che DuckDB legga l'intestazione: lasciarlo dentro
// significa una prima colonna che si chiama "﻿REGIONE" e non si può nominare.
if (testo.charCodeAt(0) === 0xfeff) {
  testo = testo.slice(1);
  await Bun.write(locale, testo);
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// vss perché il CHECKPOINT finale tocca tutto il database e le tabelle con indice
// HNSW non si ricostruiscono senza l'estensione.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo AS
  SELECT * FROM read_csv('${esc(locale)}', delim = ';', header = true, all_varchar = true)`);

const colonne = (
  await con.runAndReadAll(`SELECT column_name FROM (DESCRIBE _grezzo)`)
).getRowObjects().map(r => r.column_name);
for (const attesa of ["COD_ISTAT_COMUNE", "ZONA_SISMICA", "COMUNE"])
  if (!colonne.includes(attesa))
    throw new Error(`colonna ${attesa} assente. Il tracciato è cambiato: ${colonne.join(", ")}`);

await con.run(`CREATE OR REPLACE TABLE zone_sismiche AS
  SELECT lpad("COD_ISTAT_COMUNE", 6, '0') AS codice_istat,
    "COMUNE" AS comune,
    "SIGLA_PROV" AS sigla,
    "PROV_CITTA_METROPOLITANA" AS provincia,
    "REGIONE" AS regione,
    -- il testo così com'è pubblicato, che conserva le eventuali sottozone (3A, 3B)…
    trim("ZONA_SISMICA") AS zona,
    -- …e la cifra, che è ciò per cui si ordina e si colora
    TRY_CAST(regexp_extract(trim("ZONA_SISMICA"), '^[1-4]') AS INTEGER) AS zona_sismica
  FROM _grezzo
  WHERE "COD_ISTAT_COMUNE" IS NOT NULL
  ORDER BY 1`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  (SELECT count(*) FROM zone_sismiche) comuni,
  (SELECT count(*) FROM zone_sismiche WHERE zona_sismica IS NULL) senza_zona,
  (SELECT count(g.codice_istat) FROM zone_sismiche z
     LEFT JOIN istat_confini_comuni g ON g.codice_istat = z.codice_istat) agganciati`);
const distribuzione = (
  await con.runAndReadAll(`SELECT zona_sismica, count(*) n FROM zone_sismiche GROUP BY 1 ORDER BY 1`)
).getRowObjects();
const pct = Number(st.comuni) ? Number(st.agganciati) / Number(st.comuni) : 1;
console.log(`  comuni: ${st.comuni}`);
for (const r of distribuzione) console.log(`    zona ${r.zona_sismica ?? "—"}: ${r.n}`);
console.log(`  aggancio ai confini: ${st.agganciati}/${st.comuni} (${(pct * 100).toFixed(1)}%)`);
if (Number(st.comuni) > 0 && pct < 0.99)
  console.warn(
    `  ⚠ aggancio sotto il 99%: COD_ISTAT_COMUNE non combacia con codice_istat — la causa\n` +
      `    più probabile sono gli zeri iniziali, la seconda un'annata di confini diversa.`,
  );
if (Number(st.senza_zona) > 0)
  console.warn(`  ⚠ ${st.senza_zona} comuni con una zona che non inizia per 1-4: tracciato da rivedere`);

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
  "zone_sismiche",
  "protezionecivile.gov.it",
  "dpc/classificazione-sismica",
  "Classificazione sismica dei comuni (Protezione Civile)",
  "Seismic classification of municipalities (Civil Protection)",
  `La zona sismica di ogni comune italiano secondo la classificazione delle regioni raccolta dal Dipartimento della Protezione Civile. ATTENZIONE al verso: 1 è la zona a pericolosità PIÙ ALTA e 4 la più bassa, quindi una scala di colori va invertita rispetto all'ordine naturale del numero. zona_sismica è la cifra, per ordinare e colorare; zona è il testo pubblicato, che conserva le sottozone regionali (3A, 3B) dove esistono. Si aggancia per codice_istat a edilizia_scolastica — che porta epoca di costruzione e verifica sismica dell'edificio — e a popolazione e confini per una mappa del rischio.`,
  `The seismic zone of every Italian municipality, from the regional classifications collected by the Civil Protection Department. MIND the direction: 1 is the HIGHEST hazard zone and 4 the lowest, so a colour ramp must run against the natural order of the number. zona_sismica is the digit, for sorting and colouring; zona is the published text, which keeps the regional sub-zones (3A, 3B) where they exist. Joins on codice_istat to edilizia_scolastica — which carries each school building's construction era and seismic assessment — and to population and boundaries for a risk map.`,
  PAGINA,
  Number(st.comuni),
);

console.log(`\nzone_sismiche: ${st.comuni} comuni`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
