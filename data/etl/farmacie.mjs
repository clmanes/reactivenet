// Ingestione dell'elenco delle farmacie aperte al pubblico (Ministero della
// Salute, Open Data) → tabella `farmacie` in DuckDB + riga nel `catalog`. Una
// riga per farmacia ATTIVA, con nome, indirizzo, comune (codice ISTAT) e
// COORDINATE: è un layer di PUNTI, direttamente a marker su `:::map`, e si
// aggancia a popolazione/confini per il "farmacie per abitante".
//
// Fonte (licenza IODL 2.0, nessuna chiave):
//   https://www.dati.salute.gov.it/it/dataset/farmacie/
// Il file CSV ha la DATA di pubblicazione nel nome
// (`FRM_FARMA_5_<AAAAMMGG>.csv`), quindi l'URL non è fisso: si legge il link
// corrente dalla pagina del dataset invece di cablarlo (così un nuovo rilascio
// non rompe l'ETL). Aggiornato spesso.
//
// TRAPPOLE:
//  - il file contiene ANCHE le farmacie CHIUSE (storico): le attive hanno
//    `data_fine_validita = '-'` (NON vuoto né 9999) → filtro obbligatorio;
//  - le coordinate usano la VIRGOLA decimale (`45,06`) e i mancanti sono `-`:
//    si sostituisce `,`→`.` e si valida il range (una riga senza coordinata
//    valida non ha marker, come per ::geo);
//  - `cod_comune` è il codice ISTAT a 6 cifre (join a confini/popolazione); i
//    nomi comune sono maiuscoli → si preferisce l'etichetta di voc_istat_cities;
//  - `descrizione_farmacia` contiene entità HTML (`&amp;`) da ripulire.
//
// Uso:  bun etl/farmacie.mjs [--refresh]
//   --refresh  ignora la cache in raw/farmacie/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/farmacie/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://www.dati.salute.gov.it";
const DATASET_PAGE = `${HOST}/it/dataset/farmacie/`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// risolve l'URL del CSV corrente dalla pagina del dataset (il nome ha la data)
async function resolveCsvUrl() {
  const res = await fetch(DATASET_PAGE, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`pagina dataset: HTTP ${res.status}`);
  const html = await res.text();
  const m = html.match(/\/sites\/default\/files\/opendata\/FRM_FARMA[^"']*\.csv/i);
  if (!m) throw new Error("link CSV Farmacie non trovato nella pagina del dataset");
  return HOST + m[0];
}

mkdirSync(RAW, { recursive: true });
console.log("▸ farmacie aperte al pubblico (Ministero della Salute, Open Data)");

const csv = `${RAW}farmacie.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const url = await resolveCsvUrl();
  console.log(`  scarico ${url.split("/").pop()}`);
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(180_000) });
  if (!res.ok) throw new Error(`CSV: HTTP ${res.status}`);
  await Bun.write(csv, await res.arrayBuffer());
} else {
  console.log("  da cache");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca tutto
// il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const lat = "replace(r.latitudine, ',', '.')";
const lon = "replace(r.longitudine, ',', '.')";
await con.run(`CREATE OR REPLACE TABLE farmacie AS
WITH comuni AS (
  SELECT DISTINCT CODICE_COMUNE AS cod, LABEL_COMUNE_IT AS nome
  FROM voc_istat_cities WHERE DATA_FINE_VALIDITA = '31-12-9999'
),
raw AS (
  SELECT * FROM read_csv('${csv}', delim = ';', header = true, all_varchar = true)
  WHERE data_fine_validita = '-'  -- solo le farmacie ATTIVE (il file tiene anche le chiuse)
)
SELECT
  r.cod_comune AS codice_istat,
  coalesce(c.nome, NULLIF(trim(r.comune), '')) AS comune,
  NULLIF(trim(r.sigla_provincia), '') AS sigla,
  NULLIF(trim(r.provincia), '') AS provincia,
  NULLIF(trim(r.regione), '') AS regione,
  -- ripulitura dell'entità HTML più comune nei nomi (&amp; → &)
  replace(trim(r.descrizione_farmacia), '&amp;', '&') AS nome,
  NULLIF(trim(r.indirizzo), '') AS indirizzo,
  NULLIF(trim(r.cap), '') AS cap,
  NULLIF(NULLIF(trim(r.frazione), '-'), '') AS frazione,
  NULLIF(trim(r.descrizione_tipologia), '') AS tipologia,
  CASE WHEN TRY_CAST(${lat} AS DOUBLE) BETWEEN -90 AND 90 THEN TRY_CAST(${lat} AS DOUBLE) END AS lat,
  CASE WHEN TRY_CAST(${lon} AS DOUBLE) BETWEEN -180 AND 180 THEN TRY_CAST(${lon} AS DOUBLE) END AS lon
FROM raw r
LEFT JOIN comuni c ON c.cod = r.cod_comune`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(lat) AS con_geo, count(DISTINCT codice_istat) AS comuni FROM farmacie`)
).getRowObjects()[0];
console.log(
  `  farmacie: ${Number(stat.n).toLocaleString("it-IT")} attive — ${Number(stat.con_geo).toLocaleString("it-IT")} geolocalizzate ` +
    `(${((Number(stat.con_geo) / Number(stat.n)) * 100).toFixed(0)}%), in ${stat.comuni} comuni`,
);

// farmacie per 100.000 abitanti (informativo). Si conta PRIMA per comune, poi
// si divide per la popolazione DISTINTA del comune: un join diretto
// moltiplicherebbe la popolazione per il numero di farmacie (fan-out).
const perCapita = (
  await con.runAndReadAll(`SELECT round(100000.0 * sum(x.nf) / sum(p.popolazione), 1) AS per100k
    FROM (SELECT codice_istat, count(*) AS nf FROM farmacie GROUP BY 1) x
    JOIN (SELECT codice_istat, popolazione FROM istat_popolazione) p ON p.codice_istat = x.codice_istat`)
).getRowObjects()[0].per100k;
if (perCapita != null) console.log(`  densità: ${perCapita} farmacie ogni 100.000 abitanti (comuni agganciati)`);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'farmacie' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Farmacie aperte al pubblico (Ministero della Salute)";
const titleEn = "Public pharmacies (Ministry of Health)";
const descIt = `Elenco delle farmacie aperte al pubblico in Italia (fonte Ministero della Salute, Open Data IODL 2.0): per ogni farmacia attiva il nome, l'indirizzo, il comune con codice ISTAT, provincia e regione, la tipologia e le COORDINATE (latitudine/longitudine). È un layer di punti: si mette in mappa direttamente con :::map (marker) e si aggancia a popolazione e confini tramite codice_istat per la densità di farmacie per abitante.`;
const descEn = `List of public pharmacies in Italy (source Ministry of Health, Open Data IODL 2.0): for each active pharmacy the name, address, municipality with ISTAT code, province and region, the type and the COORDINATES (latitude/longitude). A point layer: put it on a map directly with :::map (markers) and join it to population and boundaries via codice_istat for pharmacy density per capita.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'farmacie'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('farmacie', 'dati.salute.gov.it', 'salute/farmacie',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://www.dati.salute.gov.it/it/dataset/farmacie/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nfarmacie: ${Number(stat.n).toLocaleString("it-IT")} attive`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
