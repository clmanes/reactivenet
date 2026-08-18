// Ingestione dell'anagrafe delle scuole statali (MIUR — Portale Unico dei Dati
// della Scuola) → tabella `scuole` in DuckDB + riga nel `catalog`. Una riga per
// scuola statale, con denominazione, grado, indirizzo, comune (codice ISTAT) e
// sito. Per comune: "scuole per comune"/pro capite in coropletica su
// istat_confini_comuni, e listato delle scuole di un comune.
//
// Fonte (licenza IODL 2.0, nessuna chiave):
//   https://dati.istruzione.it/opendata/opendata/catalogo/elements1/leaf/
//     ?datasetId=DS0400SCUANAGRAFESTAT
// Un CSV per ANNO SCOLASTICO, con la data nel nome
// (`SCUANAGRAFESTAT<annoscol><data>.csv`): l'URL non è fisso, si prende il file
// più recente dalla pagina del dataset.
//
// TRAPPOLE:
//  - il file NON ha coordinate (a differenza delle farmacie): è un dataset PER
//    COMUNE, non un layer a marker;
//  - `CODICECOMUNESCUOLA` è il codice CATASTALE (Belfiore, `A478`), NON l'ISTAT,
//    e i vocabolari non hanno il catastale → il codice ISTAT si ricava per NOME:
//    (comune, regione) è univoco nei confini (verificato) e regge anche dove il
//    MIUR usa nomi provincia diversi (riforma sarda, "Reggio Calabria"); un
//    fallback su comune-nome-univoco-nazionale copre le regioni abbreviate dal
//    MIUR ("FRIULI-VENEZIA G."). Copertura ~99,9%;
//  - CSV comma-separated con campi quotati (virgolette doppie raddoppiate);
//  - "Non Disponibile" è un placeholder di vuoto.
//
// Uso:  bun etl/scuole.mjs [--refresh]
//   --refresh  ignora la cache in raw/scuole/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/scuole/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://dati.istruzione.it";
const DATASET_PAGE = `${HOST}/opendata/opendata/catalogo/elements1/leaf/?datasetId=DS0400SCUANAGRAFESTAT`;
const FILE_BASE = `${HOST}/opendata/opendata/catalogo/elements1/`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
// normalizzazione dei nomi per il join: maiuscolo, senza accenti, solo A-Z0-9
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// il file più recente dell'anagrafe dalla pagina del dataset (nome col la data)
async function resolveCsvUrl() {
  const res = await fetch(DATASET_PAGE, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`pagina dataset: HTTP ${res.status}`);
  const html = await res.text();
  const names = [...html.matchAll(/SCUANAGRAFESTAT\d+\.csv/gi)].map(m => m[0]);
  if (!names.length) throw new Error("nessun file SCUANAGRAFESTAT trovato nella pagina");
  const latest = names.sort().reverse()[0]; // il prefisso anno-scolastico ordina cronologicamente
  return { url: FILE_BASE + latest, name: latest };
}

mkdirSync(RAW, { recursive: true });
console.log("▸ anagrafe scuole statali (MIUR — Portale Unico dei Dati della Scuola)");

const csv = `${RAW}scuole.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const { url, name } = await resolveCsvUrl();
  console.log(`  scarico ${name}`);
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

// codice ISTAT per nome: (comune, regione) univoco nei confini, con fallback su
// comune-nome-univoco-nazionale (per le regioni abbreviate dal MIUR).
await con.run(`CREATE OR REPLACE TABLE scuole AS
WITH raw AS (
  SELECT * FROM read_csv('${csv}', header = true, all_varchar = true)
),
conf AS (
  SELECT codice_istat, comune, sigla, provincia, regione, ${N("comune")} AS cn, ${N("regione")} AS rn
  FROM istat_confini_comuni
),
uni AS (  -- nomi comune univoci a livello nazionale
  SELECT cn, any_value(codice_istat) AS ci FROM conf GROUP BY cn HAVING count(*) = 1
),
matched AS (
  SELECT r.*, coalesce(cr.codice_istat, cu.ci) AS codice_istat
  FROM raw r
  LEFT JOIN conf cr ON cr.cn = ${N("r.DESCRIZIONECOMUNE")} AND cr.rn = ${N("r.REGIONE")}
  LEFT JOIN uni cu ON cu.cn = ${N("r.DESCRIZIONECOMUNE")}
)
SELECT
  m.codice_istat,
  coalesce(g.comune, NULLIF(trim(m.DESCRIZIONECOMUNE), '')) AS comune,
  g.sigla,
  coalesce(g.provincia, NULLIF(trim(m.PROVINCIA), '')) AS provincia,
  coalesce(g.regione, NULLIF(trim(m.REGIONE), '')) AS regione,
  m.CODICESCUOLA AS codice_scuola,
  NULLIF(trim(m.DENOMINAZIONESCUOLA), '') AS nome,
  NULLIF(trim(m.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA), '') AS grado,
  NULLIF(trim(m.DENOMINAZIONEISTITUTORIFERIMENTO), '') AS istituto,
  NULLIF(trim(m.INDIRIZZOSCUOLA), '') AS indirizzo,
  NULLIF(trim(m.CAPSCUOLA), '') AS cap,
  NULLIF(NULLIF(trim(m.SITOWEBSCUOLA), ''), 'Non Disponibile') AS sito
FROM matched m
LEFT JOIN istat_confini_comuni g ON g.codice_istat = m.codice_istat`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat, count(DISTINCT codice_istat) AS comuni FROM scuole`)
).getRowObjects()[0];
console.log(
  `  scuole: ${Number(stat.n).toLocaleString("it-IT")} — ${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% ` +
    `agganciate al comune ISTAT, in ${stat.comuni} comuni`,
);

// scuole per 10.000 abitanti (informativo) — si conta per comune poi si divide
const perCapita = (
  await con.runAndReadAll(`SELECT round(10000.0 * sum(x.ns) / sum(p.popolazione), 1) AS per10k
    FROM (SELECT codice_istat, count(*) AS ns FROM scuole WHERE codice_istat IS NOT NULL GROUP BY 1) x
    JOIN (SELECT codice_istat, popolazione FROM istat_popolazione) p ON p.codice_istat = x.codice_istat`)
).getRowObjects()[0].per10k;
if (perCapita != null) console.log(`  densità: ${perCapita} scuole statali ogni 10.000 abitanti`);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'scuole' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Scuole statali (MIUR)";
const titleEn = "State schools (MIUR)";
const descIt = `Anagrafe delle scuole statali italiane (fonte MIUR — Portale Unico dei Dati della Scuola, Open Data IODL 2.0): una riga per scuola con denominazione, grado (infanzia, primaria, primo/secondo grado, licei, istituti tecnici e professionali), istituto di riferimento, indirizzo, comune con codice ISTAT, provincia, regione e sito web. Il codice ISTAT è ricavato per nome (comune, regione). Si aggancia a popolazione e confini tramite codice_istat: scuole per comune e per abitante.`;
const descEn = `Registry of Italian state schools (source MIUR — School Data Portal, Open Data IODL 2.0): one row per school with name, grade (kindergarten, primary, lower/upper secondary, high schools, technical and vocational institutes), parent institute, address, municipality with ISTAT code, province, region and website. The ISTAT code is derived by name (municipality, region). Joins to population and boundaries via codice_istat: schools by municipality and per capita.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'scuole'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('scuole', 'dati.istruzione.it', 'miur/anagrafe-scuole-statali',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.istruzione.it/opendata/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nscuole: ${Number(stat.n).toLocaleString("it-IT")} scuole statali`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
