// Ingestione di indicatori socio-demografici per comune (ISTAT, demo.istat.it)
// → tabella `istat_indicatori` in DuckDB + riga nel `catalog`. Una riga per
// comune con struttura per età e incidenza straniera, da cui gli indicatori
// più usati per confrontare i territori: età media, % under 15, % over 65,
// indice di vecchiaia, % di residenti stranieri. Tutti mappabili in coropletica
// su istat_confini_comuni.
//
// Fonti (licenza CC-BY 4.0, nessuna chiave) — stesso portale del bilancio
// demografico (istat_popolazione):
//   POSAS  https://demo.istat.it/data/posas/POSAS_<anno>_it_Comuni.zip
//     (popolazione residente per età, sesso e stato civile — la STRUTTURA per età)
//   STRASA https://demo.istat.it/data/strasa/STRASA_<anno>_it_Comuni.zip
//     (popolazione STRANIERA residente per età e sesso)
// Un file per anno (al 1° gennaio); l'ETL parte dall'anno corrente e scende
// finché ENTRAMBI esistono.
//
// TRAPPOLE (come per il bilancio P2):
//  - CSV `;`-separated, UTF-8 con BOM, con una RIGA DI TITOLO prima dell'header
//    → skip=1;
//  - `Codice comune` a 6 cifre zero-padded e quotato → VARCHAR;
//  - il campo `Età` arriva a "100 e più": si fa TRY_CAST e il bucket alto vale
//    100 (peso trascurabile sull'età media);
//  - POSAS ha la colonna `Totale` (residenti di quell'età); STRASA ha `Maschi`
//    e `Femmine` (stranieri = somma).
//
// Uso:  bun etl/istat-indicatori.mjs [--year N] [--refresh]
//   --year     forza l'anno (default: il più recente con POSAS e STRASA)
//   --refresh  ignora la cache in raw/istat-indicatori/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/istat-indicatori/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://demo.istat.it/data/";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const forcedYear = argOf("--year");
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// scarica ed estrae il CSV di una serie (POSAS/STRASA) per un anno; null se manca
async function fetchCsv(series, year) {
  const csv = `${RAW}${series}_${year}.csv`;
  if (!refresh && (await Bun.file(csv).exists())) return csv;
  const url = `${BASE}${series.toLowerCase()}/${series}_${year}_it_Comuni.zip`;
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(180_000) });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`${series} ${year}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) return null; // "PK"
  const entries = unzipSync(buf, { filter: f => f.name.toLowerCase().endsWith(".csv") });
  const name = Object.keys(entries)[0];
  if (!name) throw new Error(`${series} ${year}: nessun csv`);
  await Bun.write(csv, entries[name]);
  return csv;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ indicatori socio-demografici per comune (ISTAT, demo.istat.it)");

// anno: quello forzato, oppure il più recente in cui esistono ENTRAMBE le serie
let year = null, posasCsv = null, strasaCsv = null;
const years = forcedYear ? [forcedYear] : Array.from({ length: 5 }, (_, k) => THIS_YEAR - k);
for (const y of years) {
  const p = await fetchCsv("POSAS", y);
  const s = p ? await fetchCsv("STRASA", y) : null;
  if (p && s) { year = y; posasCsv = p; strasaCsv = s; break; }
}
if (year == null) throw new Error("nessun anno con POSAS e STRASA disponibili");
console.log(`  anno: ${year}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: vss per il CHECKPOINT (indici HNSW su lex_atti/anac_cig).
await con.run("INSTALL vss");
await con.run("LOAD vss");

// ignore_errors: in coda c'è una riga di NOTE con una sola colonna (come nel P2)
// che manda in tilt lo sniffer; il filtro sul codice comune a 6 cifre la scarta.
const rd = f => `read_csv('${f}', delim=';', header=true, skip=1, all_varchar=true, ignore_errors=true)`;
// bucket età: "100 e più" → 100. NB: i file hanno anche una RIGA TOTALE per
// comune con Età=999 (o non numerica) → va ESCLUSA o raddoppierebbe i conteggi
// (e 999×popolazione va in overflow INT32). Si tiene solo 0..100 e si casta a
// BIGINT per sicurezza.
const eta = `CASE WHEN trim("Età") = '100 e più' THEN 100 ELSE TRY_CAST("Età" AS INTEGER) END`;
const tot = `TRY_CAST("Totale" AS BIGINT)`;
const realAge = `(${eta}) BETWEEN 0 AND 100`;

await con.run(`CREATE OR REPLACE TABLE istat_indicatori AS
WITH comuni AS (
  SELECT DISTINCT CODICE_COMUNE AS cod, LABEL_COMUNE_IT AS nome, SIGLA_AUTOMOBILISTICA AS sigla
  FROM voc_istat_cities WHERE DATA_FINE_VALIDITA = '31-12-9999'
),
pos AS (
  SELECT "Codice comune" AS cod,
    sum(${tot}) AS popolazione,
    round(sum(${eta} * ${tot})::DOUBLE / nullif(sum(${tot}), 0), 1) AS eta_media,
    round(100.0 * sum(${tot}) FILTER (WHERE ${eta} <= 14) / nullif(sum(${tot}), 0), 1) AS perc_0_14,
    round(100.0 * sum(${tot}) FILTER (WHERE ${eta} >= 65) / nullif(sum(${tot}), 0), 1) AS perc_65_piu,
    round(100.0 * sum(${tot}) FILTER (WHERE ${eta} >= 65) / nullif(sum(${tot}) FILTER (WHERE ${eta} <= 14), 0), 1) AS indice_vecchiaia
  FROM ${rd(posasCsv)}
  WHERE regexp_matches("Codice comune", '^[0-9]{6}$') AND ${realAge}
  GROUP BY 1
),
str AS (
  SELECT "Codice comune" AS cod,
    sum(TRY_CAST("Maschi" AS BIGINT) + TRY_CAST("Femmine" AS BIGINT)) AS stranieri
  FROM ${rd(strasaCsv)}
  WHERE regexp_matches("Codice comune", '^[0-9]{6}$') AND ${realAge}
  GROUP BY 1
)
SELECT
  p.cod AS codice_istat,
  c.nome AS comune,
  c.sigla,
  g.regione,
  ${year} AS anno,
  p.popolazione,
  p.eta_media,
  p.perc_0_14,
  p.perc_65_piu,
  p.indice_vecchiaia,
  coalesce(s.stranieri, 0) AS stranieri,
  round(100.0 * coalesce(s.stranieri, 0) / nullif(p.popolazione, 0), 1) AS perc_stranieri
FROM pos p
LEFT JOIN str s ON s.cod = p.cod
LEFT JOIN comuni c ON c.cod = p.cod
LEFT JOIN istat_confini_comuni g ON g.codice_istat = p.cod`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, round(median(eta_media), 1) AS eta, round(median(perc_stranieri), 1) AS str,
    round(median(indice_vecchiaia)) AS iv FROM istat_indicatori`)
).getRowObjects()[0];
console.log(
  `  istat_indicatori: ${stat.n} comuni — età media mediana ${stat.eta} anni, ` +
    `indice vecchiaia mediano ${stat.iv}, stranieri mediano ${stat.str}%`,
);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'istat_indicatori' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Indicatori socio-demografici per comune (ISTAT)";
const titleEn = "Socio-demographic indicators by municipality (ISTAT)";
const descIt = `Indicatori socio-demografici per comune al 1° gennaio ${year} (fonte ISTAT, demo.istat.it, CC BY 4.0), derivati dalla struttura per età (POSAS) e dalla popolazione straniera residente (STRASA): popolazione, età media, quota di under 15 e over 65, indice di vecchiaia e percentuale di residenti stranieri. Una riga per comune, tutti gli indicatori mappabili in coropletica su istat_confini_comuni tramite codice_istat.`;
const descEn = `Socio-demographic indicators by municipality as of 1 January ${year} (source ISTAT, demo.istat.it, CC BY 4.0), derived from the age structure (POSAS) and the resident foreign population (STRASA): population, average age, share of under-15 and over-65, old-age index and percentage of foreign residents. One row per municipality, all indicators mappable as a choropleth on istat_confini_comuni via codice_istat.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'istat_indicatori'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('istat_indicatori', 'demo.istat.it', 'istat/indicatori-comunali',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://demo.istat.it', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nistat_indicatori: ${stat.n} comuni (${year})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
