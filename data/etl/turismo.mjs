// Ingestione del movimento turistico (arrivi e presenze) per provincia
// (ISTAT — IstatData/SDMX) → tabella `turismo` in DuckDB + riga nel
// `catalog`. Una riga per provincia/anno: arrivi, presenze (notti) e la
// quota di turismo straniero — l'economia turistica del territorio,
// incrociabile con redditi e demografia.
//
// Fonte (nessuna chiave), endpoint SDMX REST (dataflow "Movimento clienti
// negli esercizi ricettivi", ECON_ACTIVITY=551_553 = alloggio, ADJUSTMENT=N
// = dato grezzo, COUNTRY_RES_GUESTS=WORLD/WRL_X_ITA = totale / solo
// stranieri):
//   https://esploradati.istat.it/SDMXWS/rest/data/IT1,122_54_DF_DCSC_TUR_3,1.0/
//     A..AR+NI.N.ALL.551_553.WORLD+WRL_X_ITA.ALL.ALL.ALL.TOT?startPeriod=<anno>&endPeriod=<anno>
//
// NOTA: il dataflow "esplicitamente comunale" (DF_BULK_DCSC_OCCUPCOLLE)
// risulta scollegato dal motore SDMX ("doesn't contain a mapping set");
// questo dataflow alternativo (mensile aggregato ad annuale) HA invece dati
// reali a livello PROVINCIA, coerente con la soglia di riservatezza
// statistica ISTAT sui comuni con poche strutture ricettive.
//
// TRAPPOLE:
//  - ISTAT applica un RATE LIMIT aggressivo (poche richieste/minuto, ban di
//    1-2 giorni se superato): UNA sola richiesta per l'intera serie/i tipi
//    (combinati con '+' nella chiave), mai un loop per anno;
//  - DATA_TYPE=AR (arrivi) / NI (notti = presenze); COUNTRY_RES_GUESTS=WORLD
//    è il TOTALE (italiani+stranieri), WRL_X_ITA è il sottoinsieme
//    stranieri — si pivotano entrambi per calcolare la quota estera;
//  - REF_AREA usa la codelist CL_ITTER107 (NUTS-simile), come delitti.mjs:
//    stesso crosswalk condiviso (lib/istat-nuts.mjs), risolto per NOME
//    provincia;
//  - senza filtro REF_AREA la risposta porta anche nazione/ripartizioni/
//    regioni: si tiene solo il crosswalk provincia.
//
// Uso:  bun etl/turismo.mjs [--refresh]
//   --refresh  ignora la cache in raw/turismo/ e riscarica (ATTENZIONE al
//              rate limit ISTAT: non abusare)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";
import { loadItter107Province } from "./lib/istat-nuts.mjs";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/turismo/";
const RAW_GEO = ROOT + "raw/istat-geo/";
const DB = ROOT + "warehouse.duckdb";
const THIS_YEAR = new Date().getFullYear();
const FROM_YEAR = THIS_YEAR - 5;
const SDMX_URL =
  "https://esploradati.istat.it/SDMXWS/rest/data/IT1,122_54_DF_DCSC_TUR_3,1.0/" +
  `A..AR+NI.N.ALL.551_553.WORLD+WRL_X_ITA.ALL.ALL.ALL.TOT?startPeriod=${FROM_YEAR}&endPeriod=${THIS_YEAR}`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

mkdirSync(RAW, { recursive: true });
mkdirSync(RAW_GEO, { recursive: true });
console.log("▸ movimento turistico per provincia (ISTAT — IstatData SDMX)");

const csv = `${RAW}dati.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const res = await fetch(SDMX_URL, {
    headers: { accept: "application/vnd.sdmx.data+csv;version=1.0.0" },
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`SDMX turismo: HTTP ${res.status}`);
  await Bun.write(csv, await res.text());
} else {
  console.log("  da cache");
}

const nuts = await loadItter107Province(RAW_GEO, { refresh });
console.log(`  crosswalk province (CL_ITTER107): ${nuts.size} codici`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const crosswalkValues = [...nuts.entries()].map(([c, n]) => `('${esc(c)}', '${esc(n)}')`).join(", ");
await con.run(`CREATE OR REPLACE TEMP TABLE nuts_crosswalk AS
  SELECT * FROM (VALUES ${crosswalkValues}) AS t(code, nome)`);

await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
  SELECT REF_AREA, DATA_TYPE, COUNTRY_RES_GUESTS, TRY_CAST(TIME_PERIOD AS INTEGER) AS anno, TRY_CAST(OBS_VALUE AS DOUBLE) AS v
  FROM read_csv('${csv}', header = true, all_varchar = true)
  WHERE REF_AREA != 'IT'`);

await con.run(`CREATE OR REPLACE TABLE turismo AS
WITH prov AS (
  SELECT p.sigla, p.provincia, reg.regione, p.cod_reg, ${N("p.provincia")} AS pn
  FROM istat_confini_province p
  LEFT JOIN istat_confini_regioni reg ON reg.cod_reg = p.cod_reg
),
xw AS (
  SELECT code, ${N("nome")} AS pn FROM nuts_crosswalk
),
piv AS (
  SELECT REF_AREA, anno,
    max(v) FILTER (WHERE DATA_TYPE = 'AR' AND COUNTRY_RES_GUESTS = 'WORLD') AS arrivi,
    max(v) FILTER (WHERE DATA_TYPE = 'NI' AND COUNTRY_RES_GUESTS = 'WORLD') AS presenze,
    max(v) FILTER (WHERE DATA_TYPE = 'AR' AND COUNTRY_RES_GUESTS = 'WRL_X_ITA') AS arrivi_stranieri,
    max(v) FILTER (WHERE DATA_TYPE = 'NI' AND COUNTRY_RES_GUESTS = 'WRL_X_ITA') AS presenze_straniere
  FROM raw GROUP BY REF_AREA, anno
),
matched AS (
  SELECT pi.*, p.sigla, p.provincia, p.regione, p.cod_reg
  FROM piv pi
  JOIN xw x ON x.code = pi.REF_AREA
  JOIN prov p ON p.pn = x.pn
)
SELECT
  sigla, provincia, regione, cod_reg, anno,
  arrivi::BIGINT AS arrivi, presenze::BIGINT AS presenze,
  arrivi_stranieri::BIGINT AS arrivi_stranieri, presenze_straniere::BIGINT AS presenze_straniere,
  CASE WHEN arrivi > 0 THEN round(100.0 * arrivi_stranieri / arrivi, 1) END AS quota_straniera,
  CASE WHEN arrivi > 0 THEN round(presenze / arrivi, 1) END AS permanenza_media
FROM matched`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT sigla) AS province,
    min(anno) AS da, max(anno) AS a FROM turismo`)
).getRowObjects()[0];
console.log(`  turismo: ${stat.n} righe — ${stat.province} province, anni ${stat.da}–${stat.a}`);
if (Number(stat.province) < 90) console.warn("  ATTENZIONE: poche province agganciate, verificare il crosswalk NUTS");

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'turismo' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Movimento turistico per provincia (ISTAT)";
const titleEn = "Tourist flows by province (ISTAT)";
const descIt = `Arrivi e presenze negli esercizi ricettivi per provincia, anni ${stat.da}–${stat.a} (fonte ISTAT — IstatData, dati aperti): arrivi, presenze (notti), arrivi/presenze STRANIERI, quota di turismo straniero e permanenza media (notti per arrivo). Una riga per provincia/anno, agganciata ai confini tramite la sigla provincia (risoluzione per nome dalla codelist ISTAT CL_ITTER107): l'economia turistica del territorio incrociabile con redditi e demografia.`;
const descEn = `Arrivals and overnight stays in accommodation establishments by province, years ${stat.da}–${stat.a} (source ISTAT — IstatData, open data): arrivals, overnight stays (nights), FOREIGN arrivals/nights, foreign-tourism share and average length of stay (nights per arrival). One row per province/year, joined to boundaries via the province code (resolved by name from the ISTAT CL_ITTER107 codelist): the territory's tourism economy, cross-referenceable with income and demographics.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'turismo'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('turismo', 'esploradati.istat.it', 'istat/movimento-turistico-provincia',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://esploradati.istat.it/databrowser/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nturismo: ${stat.n} righe (${stat.province} province, anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
