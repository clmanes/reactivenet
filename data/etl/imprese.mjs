// Ingestione della demografia d'impresa per comune (ISTAT — ASIA, Archivio
// Statistico delle Imprese Attive, via IstatData/SDMX) → tabella `imprese` in
// DuckDB + riga nel `catalog`. Una riga per comune/anno: numero di unità
// locali attive e addetti medi annui (totale economia) — il tessuto
// economico locale, incrociabile con redditi IRPEF e infortuni INAIL.
//
// Fonte (nessuna chiave), endpoint SDMX REST:
//   https://esploradati.istat.it/SDMXWS/rest/data/IT1,183_1163_DF_DICA_ASIAULP_TERRIFDATA_3,1.0/
//     A...0010.TOTAL?startPeriod=<anno>&endPeriod=<anno>
//   (dataflow "Unità locali e addetti" — Ateco 3 cifre, livello comune;
//   chiave: FREQ=A, REF_AREA=* , DATA_TYPE=*, ECON_ACTIVITY=0010 (totale
//   economia), PERS_EMPL_SIZE_CLASS=TOTAL)
//
// TRAPPOLE:
//  - ISTAT applica un RATE LIMIT aggressivo (poche richieste/minuto, ban di
//    1-2 giorni se superato): UNA sola richiesta per l'intera serie storica
//    (startPeriod/endPeriod ampio), mai un loop per anno;
//  - senza filtro ECON_ACTIVITY/PERS_EMPL_SIZE_CLASS la risposta è enorme
//    (centinaia di MB, tutte le sottocategorie Ateco): si fissa
//    ECON_ACTIVITY=0010 (totale economia) e SIZE_CLASS=TOTAL;
//  - REF_AREA con dimensione vuota (wildcard) restituisce TUTTI i livelli
//    territoriali (nazione, regioni, ecc.), non solo i comuni: si filtra sul
//    pattern a 6 cifre, che qui COINCIDE col codice_istat standard (a
//    differenza di altri dataset ISTAT che usano NUTS/ITTER107);
//  - DATA_TYPE=LU (unità locali, intero) e LUEMPDAA (addetti medi annui,
//    decimale) arrivano nella stessa risposta long-format: si pivota.
//
// Uso:  bun etl/imprese.mjs [--refresh]
//   --refresh  ignora la cache in raw/imprese/ e riscarica (ATTENZIONE al
//              rate limit ISTAT: non abusare)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/imprese/";
const DB = ROOT + "warehouse.duckdb";
const THIS_YEAR = new Date().getFullYear();
const FROM_YEAR = THIS_YEAR - 5;
const SDMX_URL =
  "https://esploradati.istat.it/SDMXWS/rest/data/IT1,183_1163_DF_DICA_ASIAULP_TERRIFDATA_3,1.0/" +
  `A...0010.TOTAL?startPeriod=${FROM_YEAR}&endPeriod=${THIS_YEAR}`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ unità locali e addetti per comune (ISTAT — ASIA / IstatData SDMX)");

const csv = `${RAW}asia.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const res = await fetch(SDMX_URL, {
    headers: { accept: "application/vnd.sdmx.data+csv;version=1.0.0" },
    signal: AbortSignal.timeout(240_000),
  });
  if (!res.ok) throw new Error(`SDMX ASIA: HTTP ${res.status}`);
  await Bun.write(csv, await res.arrayBuffer());
} else {
  console.log("  da cache");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
  SELECT REF_AREA AS codice_istat, DATA_TYPE, TRY_CAST(TIME_PERIOD AS INTEGER) AS anno, TRY_CAST(OBS_VALUE AS DOUBLE) AS v
  FROM read_csv('${csv}', header = true, all_varchar = true)
  WHERE regexp_matches(REF_AREA, '^[0-9]{6}$')`);

await con.run(`CREATE OR REPLACE TABLE imprese AS
WITH piv AS (
  SELECT codice_istat, anno,
    max(v) FILTER (WHERE DATA_TYPE = 'LU') AS unita_locali,
    max(v) FILTER (WHERE DATA_TYPE = 'LUEMPDAA') AS addetti
  FROM raw GROUP BY codice_istat, anno
)
SELECT
  p.codice_istat, g.comune, g.sigla, g.provincia, g.regione, g.cod_reg,
  p.anno,
  p.unita_locali::BIGINT AS unita_locali,
  round(p.addetti, 1) AS addetti,
  CASE WHEN p.unita_locali > 0 THEN round(p.addetti / p.unita_locali, 1) END AS addetti_per_unita
FROM piv p
LEFT JOIN istat_confini_comuni g ON g.codice_istat = p.codice_istat`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT codice_istat) AS comuni,
    min(anno) AS da, max(anno) AS a, round(sum(addetti) FILTER (WHERE anno = (SELECT max(anno) FROM imprese)) / 1e6, 1) AS addetti_mln
    FROM imprese`)
).getRowObjects()[0];
console.log(
  `  imprese: ${stat.n} righe — ${stat.comuni} comuni, anni ${stat.da}–${stat.a}, ` +
    `~${stat.addetti_mln} mln addetti nell'ultimo anno`,
);

const bridge = (
  await con.runAndReadAll(`SELECT round(100.0 * count(*) FILTER (WHERE comune IS NOT NULL) / count(*), 1) AS pct FROM imprese`)
).getRowObjects()[0].pct;
console.log(`  aggancio a istat_confini_comuni: ${bridge}% delle righe`);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'imprese' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Imprese e addetti per comune (ISTAT ASIA)";
const titleEn = "Businesses and employees by municipality (ISTAT ASIA)";
const descIt = `Demografia d'impresa per comune, anni ${stat.da}–${stat.a} (fonte ISTAT — ASIA, Archivio Statistico delle Imprese Attive, via IstatData): numero di UNITÀ LOCALI attive (totale economia) e ADDETTI medi annui, con il rapporto addetti per unità locale. Una riga per comune/anno, agganciata a popolazione e confini tramite codice_istat: il tessuto economico locale incrociabile con redditi IRPEF e infortuni sul lavoro.`;
const descEn = `Business demography by municipality, years ${stat.da}–${stat.a} (source ISTAT — ASIA, Register of Active Enterprises, via IstatData): number of active LOCAL UNITS (whole economy) and average annual EMPLOYEES, with the employees-per-unit ratio. One row per municipality/year, joined to population and boundaries via codice_istat: the local economic fabric, cross-referenceable with income tax data and workplace injuries.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'imprese'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('imprese', 'esploradati.istat.it', 'istat/asia-unita-locali-comune',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://www.istat.it/it/archivio/archivio+asia', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nimprese: ${stat.n} righe (${stat.comuni} comuni, anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
