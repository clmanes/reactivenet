// Ingestione dei risultati elettorali per comune (Ministero dell'Interno —
// Elezioni Camera dei Deputati 2022, dati aperti) → tabella `elezioni` in
// DuckDB + riga nel `catalog`. Una riga per comune: elettori, votanti,
// affluenza e la lista più votata — la lettura socio-politica del territorio
// incrociabile con reddito IRPEF e demografia.
//
// Fonte (nessuna chiave), due file CSV:
//   https://dait.interno.gov.it/documenti/opendata/catalogoagid/Camera_Italia_LivComune.csv
//     (voti per comune × lista × candidato, tutta Italia tranne Valle d'Aosta,
//     che nel sistema Camera ha un collegio uninominale unico e nessuna lista
//     proporzionale: schema incompatibile, esclusa)
//   https://dait.interno.gov.it/documenti/opendata/catalogoagid/elenco-collegi-comuni-camera.csv
//     (crosswalk comune → sigla provincia, il file dei risultati non porta né
//     provincia né codice ISTAT)
//
// TRAPPOLE:
//  - NESSUN codice ISTAT nel file: si risale per NOME comune, disambiguato
//    con la sigla provincia dal crosswalk (pattern di scuole.mjs), con
//    fallback su nome-comune-univoco-nazionale;
//  - un comune grande può essere spezzato su più collegi uninominali: si
//    dedup su (comune, collegio, valore) PRIMA di sommare, altrimenti le
//    righe per candidato duplicano elettori/votanti/voti-lista;
//  - CSV `;`-separated, campi stringa quotati, ELETTORITOT/VOTANTITOT/
//    VOTILISTA ripetuti identici su ogni riga di candidato dello stesso
//    comune/collegio/lista.
//
// Uso:  bun etl/elezioni.mjs [--refresh]
//   --refresh  ignora la cache in raw/elezioni/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/elezioni/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://dait.interno.gov.it/documenti/opendata/catalogoagid/";
const RISULTATI_URL = HOST + "Camera_Italia_LivComune.csv";
const CROSSWALK_URL = HOST + "elenco-collegi-comuni-camera.csv";
const ANNO = 2022;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
// normalizzazione dei nomi per il join: maiuscolo, senza accenti, solo A-Z0-9
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

async function fetchCached(url, out) {
  if (!refresh && (await Bun.file(out).exists())) return;
  const res = await fetch(url, { signal: AbortSignal.timeout(180_000) });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  await Bun.write(out, await res.arrayBuffer());
}

mkdirSync(RAW, { recursive: true });
console.log("▸ risultati elettorali per comune (Ministero dell'Interno — Camera 2022)");
await fetchCached(RISULTATI_URL, `${RAW}risultati.csv`);
await fetchCached(CROSSWALK_URL, `${RAW}crosswalk.csv`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
  SELECT COMUNE, COLLUNINOM, ELETTORITOT, VOTANTITOT, VOTILISTA, DESCRLISTA
  FROM read_csv('${RAW}risultati.csv', delim = ';', header = true, all_varchar = true, null_padding = true)`);

// crosswalk posizionale (header con spazi): colonna 3 = COMUNE, colonna 4 = SIGLA PROVINCIA
await con.run(`CREATE OR REPLACE TEMP TABLE crosswalk AS
  SELECT DISTINCT column3 AS comune_f, column4 AS sigla_f
  FROM read_csv('${RAW}crosswalk.csv', delim = ';', header = false, skip = 1, all_varchar = true, null_padding = true)`);

// elettori/votanti per comune: dedup su (comune, collegio) prima di sommare
// (un comune grande può essere spezzato su più collegi uninominali)
await con.run(`CREATE OR REPLACE TEMP TABLE affluenza AS
  SELECT COMUNE, sum(TRY_CAST(ELETTORITOT AS BIGINT)) AS elettori, sum(TRY_CAST(VOTANTITOT AS BIGINT)) AS votanti
  FROM (SELECT DISTINCT COMUNE, COLLUNINOM, ELETTORITOT, VOTANTITOT FROM raw)
  GROUP BY COMUNE`);

// voti per lista per comune: stesso dedup, poi somma tra collegi
await con.run(`CREATE OR REPLACE TEMP TABLE voti_lista AS
  SELECT COMUNE, DESCRLISTA, sum(TRY_CAST(VOTILISTA AS BIGINT)) AS voti
  FROM (SELECT DISTINCT COMUNE, COLLUNINOM, DESCRLISTA, VOTILISTA FROM raw)
  GROUP BY COMUNE, DESCRLISTA`);

await con.run(`CREATE OR REPLACE TEMP TABLE vincitore AS
  SELECT COMUNE, DESCRLISTA AS lista_vincente, voti AS voti_vincente
  FROM (SELECT *, row_number() OVER (PARTITION BY COMUNE ORDER BY voti DESC) AS rn FROM voti_lista)
  WHERE rn = 1`);

// codice ISTAT per nome: (comune, sigla dal crosswalk) sui confini, con
// fallback su nome-comune-univoco-nazionale.
await con.run(`CREATE OR REPLACE TABLE elezioni AS
WITH conf AS (
  SELECT codice_istat, comune, sigla, provincia, regione, ${N("comune")} AS cn, ${N("sigla")} AS sn
  FROM istat_confini_comuni
),
uni AS (  -- nomi comune univoci a livello nazionale
  SELECT cn, any_value(codice_istat) AS ci FROM conf GROUP BY cn HAVING count(*) = 1
),
xw AS (
  SELECT DISTINCT ${N("comune_f")} AS cn, ${N("sigla_f")} AS sn FROM crosswalk
),
matched AS (
  SELECT a.COMUNE, coalesce(cr.codice_istat, cu.ci) AS codice_istat
  FROM affluenza a
  LEFT JOIN xw x ON x.cn = ${N("a.COMUNE")}
  LEFT JOIN conf cr ON cr.cn = ${N("a.COMUNE")} AND cr.sn = x.sn
  LEFT JOIN uni cu ON cu.cn = ${N("a.COMUNE")}
)
SELECT
  m.codice_istat,
  coalesce(g.comune, NULLIF(trim(a.COMUNE), '')) AS comune,
  g.sigla, g.provincia, g.regione,
  ${ANNO} AS anno,
  a.elettori, a.votanti,
  CASE WHEN a.elettori > 0 THEN round(100.0 * a.votanti / a.elettori, 1) END AS affluenza,
  v.lista_vincente, v.voti_vincente,
  CASE WHEN a.votanti > 0 THEN round(100.0 * v.voti_vincente / a.votanti, 1) END AS percentuale_vincente
FROM affluenza a
JOIN matched m ON m.COMUNE = a.COMUNE
LEFT JOIN vincitore v ON v.COMUNE = a.COMUNE
LEFT JOIN istat_confini_comuni g ON g.codice_istat = m.codice_istat`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat,
    round(avg(affluenza), 1) AS aff_media FROM elezioni`)
).getRowObjects()[0];
console.log(
  `  elezioni: ${stat.n} comuni — ${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% ` +
    `agganciati al codice ISTAT, affluenza media ${stat.aff_media}%`,
);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'elezioni' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Elezioni politiche 2022 per comune (Ministero dell'Interno)";
const titleEn = "2022 general election results by municipality (Ministry of the Interior)";
const descIt = `Risultati delle elezioni per la Camera dei Deputati ${ANNO} per comune (fonte Ministero dell'Interno — DAIT, dati aperti, esclusa Valle d'Aosta per schema elettorale diverso): elettori, votanti, PERCENTUALE di affluenza, lista più votata (lista_vincente) con i relativi voti e percentuale sui votanti. Una riga per comune, agganciata a popolazione e confini tramite codice_istat (risoluzione per nome comune + provincia): la lettura socio-politica del territorio incrociabile con reddito IRPEF e demografia.`;
const descEn = `Results of the ${ANNO} general election (Chamber of Deputies) by municipality (source Ministry of the Interior — DAIT, open data, excluding Valle d'Aosta which uses a different electoral scheme): registered voters, actual voters, turnout RATE, top list (lista_vincente) with its votes and share of valid votes. One row per municipality, joined to population and boundaries via codice_istat (resolved by municipality + province name): a socio-political reading of the territory, cross-referenceable with income tax data and demographics.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'elezioni'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('elezioni', 'dait.interno.gov.it', 'interno/camera-2022-comune',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dait.interno.gov.it/elezioni/open-data', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nelezioni: ${stat.n} comuni (Camera ${ANNO})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
