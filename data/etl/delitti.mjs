// Ingestione dei delitti denunciati dalle forze di polizia per provincia
// (ISTAT — IstatData/SDMX) → tabella `delitti` in DuckDB + riga nel
// `catalog`. Una riga per provincia/anno/tipo di reato, con il TASSO ogni
// 100.000 abitanti — sicurezza territoriale, stessa granularità di
// inail_infortuni, incrociabile con redditi e demografia.
//
// Fonte (nessuna chiave), endpoint SDMX REST (dataflow "Delitti denunciati
// dalle forze di polizia", DATA_TYPE=CRIMET = tasso per 100.000 abitanti,
// Y_KNOWN_OFFENDER_IDEN=9 = totale indipendentemente dall'autore, REFERENCE_
// PERIOD_CRIME=YRDUR = anno):
//   https://esploradati.istat.it/SDMXWS/rest/data/IT1,73_67_DF_DCCV_DELITTIPS_9,1.0/
//     A..CRIMET.<tipi>.9.YRDUR?startPeriod=<anno>&endPeriod=<anno>
//
// TRAPPOLE:
//  - ISTAT applica un RATE LIMIT aggressivo (poche richieste/minuto, ban di
//    1-2 giorni se superato): UNA sola richiesta per l'intera serie/i tipi di
//    reato (combinati con '+' nella chiave), mai un loop per anno o reato;
//  - la sola aggregazione TOTALE dei delitti (`TOT`) non basta a raccontare
//    la sicurezza territoriale: si aggiungono furti (THEFT), rapine
//    (ROBBER), omicidi volontari (INTENHOM) e reati da stupefacenti (DRUG),
//    fissi in questo file (non parametrizzabili da riga di comando: il
//    dataflow ISTAT ha 86 tipi di reato, un sottoinsieme editoriale);
//  - REF_AREA usa la codelist CL_ITTER107 (NUTS-simile, "ITC11"=Torino), NON
//    il codice ISTAT numerico usato altrove nel warehouse: si risolve per
//    NOME provincia via il crosswalk condiviso (lib/istat-nuts.mjs), unico
//    su istat_confini_province.provincia;
//  - la risposta con REF_AREA senza filtro porta TUTTI i livelli
//    territoriali (nazione, ripartizioni, regioni, PROVINCE): si tiene solo
//    il crosswalk provincia (5 caratteri "ITxxx").
//
// Uso:  bun etl/delitti.mjs [--refresh]
//   --refresh  ignora la cache in raw/delitti/ e riscarica (ATTENZIONE al
//              rate limit ISTAT: non abusare)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";
import { loadItter107Province } from "./lib/istat-nuts.mjs";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/delitti/";
const RAW_GEO = ROOT + "raw/istat-geo/";
const DB = ROOT + "warehouse.duckdb";
const THIS_YEAR = new Date().getFullYear();
const FROM_YEAR = THIS_YEAR - 5;
const TIPI = ["TOT", "THEFT", "ROBBER", "INTENHOM", "DRUG"];
const SDMX_URL =
  "https://esploradati.istat.it/SDMXWS/rest/data/IT1,73_67_DF_DCCV_DELITTIPS_9,1.0/" +
  `A..CRIMET.${TIPI.join("+")}.9.YRDUR?startPeriod=${FROM_YEAR}&endPeriod=${THIS_YEAR}`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

mkdirSync(RAW, { recursive: true });
mkdirSync(RAW_GEO, { recursive: true });
console.log("▸ delitti denunciati per provincia (ISTAT — IstatData SDMX)");

const csv = `${RAW}dati.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const res = await fetch(SDMX_URL, {
    headers: { accept: "application/vnd.sdmx.data+csv;version=1.0.0" },
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`SDMX delitti: HTTP ${res.status}`);
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
  SELECT REF_AREA, TYPE_CRIME, TRY_CAST(TIME_PERIOD AS INTEGER) AS anno, TRY_CAST(OBS_VALUE AS DOUBLE) AS tasso
  FROM read_csv('${csv}', header = true, all_varchar = true)`);

const REATO = `CASE TYPE_CRIME
  WHEN 'TOT' THEN 'totale' WHEN 'THEFT' THEN 'furti' WHEN 'ROBBER' THEN 'rapine'
  WHEN 'INTENHOM' THEN 'omicidi_volontari' WHEN 'DRUG' THEN 'stupefacenti' ELSE lower(TYPE_CRIME) END`;

await con.run(`CREATE OR REPLACE TABLE delitti AS
WITH prov AS (
  SELECT p.sigla, p.provincia, reg.regione, p.cod_reg, ${N("p.provincia")} AS pn
  FROM istat_confini_province p
  LEFT JOIN istat_confini_regioni reg ON reg.cod_reg = p.cod_reg
),
xw AS (
  SELECT code, ${N("nome")} AS pn FROM nuts_crosswalk
),
matched AS (
  SELECT r.*, p.sigla, p.provincia, p.regione, p.cod_reg
  FROM raw r
  JOIN xw x ON x.code = r.REF_AREA
  JOIN prov p ON p.pn = x.pn
)
SELECT sigla, provincia, regione, cod_reg, anno, ${REATO} AS tipo_reato, round(tasso, 1) AS tasso_per_100k
FROM matched`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT sigla) AS province,
    min(anno) AS da, max(anno) AS a FROM delitti`)
).getRowObjects()[0];
console.log(`  delitti: ${stat.n} righe — ${stat.province} province, anni ${stat.da}–${stat.a}`);
if (Number(stat.province) < 90) console.warn("  ATTENZIONE: poche province agganciate, verificare il crosswalk NUTS");

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'delitti' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Delitti denunciati per provincia (ISTAT)";
const titleEn = "Crimes reported to police by province (ISTAT)";
const descIt = `Delitti denunciati dalle forze di polizia all'autorità giudiziaria per provincia, anni ${stat.da}–${stat.a} (fonte ISTAT — IstatData, dati aperti): TASSO ogni 100.000 abitanti per tipo di reato (totale, furti, rapine, omicidi volontari, reati da stupefacenti). Una riga per provincia/anno/tipo, agganciata ai confini tramite la sigla provincia (risoluzione per nome dalla codelist ISTAT CL_ITTER107): la sicurezza territoriale, stessa granularità di inail_infortuni.`;
const descEn = `Crimes reported to the judicial authority by police, by province, years ${stat.da}–${stat.a} (source ISTAT — IstatData, open data): RATE per 100,000 inhabitants by crime type (total, theft, robbery, intentional homicide, drug offences). One row per province/year/type, joined to boundaries via the province code (resolved by name from the ISTAT CL_ITTER107 codelist): territorial safety, same granularity as inail_infortuni.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'delitti'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('delitti', 'esploradati.istat.it', 'istat/delitti-provincia',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'http://dati.istat.it/Index.aspx?DataSetCode=DCCV_DELITTIPS', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\ndelitti: ${stat.n} righe (${stat.province} province, anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
