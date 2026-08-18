// Ingestione degli AGGIUDICATARI delle gare pubbliche (ANAC) → tabella
// `anac_aggiudicatari` in DuckDB + riga nel `catalog`. È il lato "chi VINCE"
// degli appalti: per ogni gara (CIG) l'impresa aggiudicataria (codice fiscale e
// denominazione), il suo ruolo (mandataria/mandante nei raggruppamenti) e
// l'importo aggiudicato. Chiude il cerchio con `anac_cig` (chi appalta e cosa)
// e con `indicepa` (la PA appaltante): amministrazione → gara → vincitore.
//
// Fonte: lo stesso CKAN di `anac.mjs` (licenza CC-BY-SA 4.0), due dataset
// distinti dal CIG:
//   aggiudicatari  https://dati.anticorruzione.it/opendata/download/dataset/
//     aggiudicatari/filesystem/aggiudicatari_csv.zip  (chi ha vinto: cig, ruolo,
//     codice_fiscale, denominazione, tipo_soggetto, id_aggiudicazione)
//   aggiudicazioni https://…/aggiudicazioni/filesystem/aggiudicazioni_csv.zip
//     (l'esito: cig, importo_aggiudicazione, data, esito, criterio, ribasso,
//     id_aggiudicazione)
// Si uniscono per `id_aggiudicazione`. Sono lo STORICO COMPLETO (~5,4M righe,
// ~800 MB CSV l'uno): si FILTRA al perimetro di `anac_cig` (CIG già nel
// warehouse) per restare coerenti e agganciabili.
//
// TRAPPOLE:
//  - CSV `;`-separated, tutto quotato, UTF-8; una riga di NOTE/anomalie può
//    rompere lo sniffer → ignore_errors;
//  - `id_aggiudicazione` NON è univoco in aggiudicazioni: si deduplica (una
//    riga per id) o il join moltiplica gli aggiudicatari;
//  - gli IMPORTI portano gli stessi errori-fonte di anac_cig (valori enormi):
//    ottimi per riga, inaffidabili se aggregati alla cieca — non corretti qui.
//
// Uso:  bun etl/anac-aggiudicatari.mjs [--refresh]
//   --refresh  ignora la cache in raw/anac-aggiud/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/anac-aggiud/";
const DB = ROOT + "warehouse.duckdb";
const DL = "https://dati.anticorruzione.it/opendata/download/dataset";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  accept: "application/zip, */*",
};

// scarica ed estrae il CSV di un dataset (aggiudicatari/aggiudicazioni)
async function fetchCsv(name) {
  const csv = `${RAW}${name}.csv`;
  if (!refresh && (await Bun.file(csv).exists())) return csv;
  const url = `${DL}/${name}/filesystem/${name}_csv.zip`;
  console.log(`  scarico ${name}…`);
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  const entries = unzipSync(buf, { filter: f => f.name.toLowerCase().endsWith(".csv") });
  const inner = Object.keys(entries)[0];
  if (!inner) throw new Error(`${name}: nessun csv nello zip`);
  await Bun.write(csv, entries[inner]);
  return csv;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ aggiudicatari delle gare pubbliche (ANAC) — chi vince gli appalti");

const catCsv = await fetchCsv("aggiudicatari");
const aggCsv = await fetchCsv("aggiudicazioni");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: vss per il CHECKPOINT (indici HNSW su lex_atti/anac_cig).
await con.run("INSTALL vss");
await con.run("LOAD vss");

const rd = f => `read_csv('${f}', delim=';', header=true, all_varchar=true, ignore_errors=true)`;

// aggiudicazioni DEDUPLICATE per id_aggiudicazione (una riga = un esito/importo),
// poi join agli aggiudicatari; solo i CIG già nel perimetro di anac_cig.
await con.run(`CREATE OR REPLACE TABLE anac_aggiudicatari AS
WITH agz AS (
  SELECT id_aggiudicazione, importo_aggiudicazione, data_aggiudicazione_definitiva, esito,
    criterio_aggiudicazione, ribasso_aggiudicazione, numero_offerte_ammesse
  FROM ${rd(aggCsv)}
  QUALIFY row_number() OVER (PARTITION BY id_aggiudicazione ORDER BY importo_aggiudicazione DESC) = 1
)
SELECT
  t.cig,
  NULLIF(trim(t.codice_fiscale), '') AS cf_aggiudicatario,
  NULLIF(trim(t.denominazione), '') AS denominazione,
  NULLIF(trim(t.ruolo), '') AS ruolo,
  NULLIF(trim(t.tipo_soggetto), '') AS tipo_soggetto,
  TRY_CAST(z.importo_aggiudicazione AS DOUBLE) AS importo_aggiudicazione,
  z.data_aggiudicazione_definitiva AS data_aggiudicazione,
  NULLIF(trim(z.esito), '') AS esito,
  NULLIF(trim(z.criterio_aggiudicazione), '') AS criterio,
  TRY_CAST(z.ribasso_aggiudicazione AS DOUBLE) AS ribasso,
  TRY_CAST(z.numero_offerte_ammesse AS INTEGER) AS offerte_ammesse
FROM ${rd(catCsv)} t
JOIN agz z ON z.id_aggiudicazione = t.id_aggiudicazione
WHERE t.cig IN (SELECT cig FROM anac_cig)`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT cig) AS cig, count(DISTINCT cf_aggiudicatario) AS imprese
    FROM anac_aggiudicatari`)
).getRowObjects()[0];
console.log(
  `  anac_aggiudicatari: ${Number(stat.n).toLocaleString("it-IT")} righe — ` +
    `${Number(stat.cig).toLocaleString("it-IT")} gare aggiudicate, ${Number(stat.imprese).toLocaleString("it-IT")} imprese vincitrici`,
);

// copertura del ponte verso anac_cig (informativo)
const bridge = (
  await con.runAndReadAll(`SELECT round(100.0 * count(DISTINCT a.cig) / count(DISTINCT g.cig), 1) AS pct
    FROM anac_cig g LEFT JOIN anac_aggiudicatari a ON a.cig = g.cig`)
).getRowObjects()[0].pct;
if (bridge != null) console.log(`  ponte a anac_cig: ${bridge}% delle gare ha un aggiudicatario registrato`);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'anac_aggiudicatari' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Aggiudicatari delle gare pubbliche (ANAC)";
const titleEn = "Public tender awardees (ANAC)";
const descIt = `Chi VINCE le gare pubbliche identificate dal CIG (fonte ANAC, CC BY-SA 4.0): per ogni gara del perimetro di anac_cig, l'impresa aggiudicataria (codice fiscale e denominazione), il ruolo (mandataria/mandante nei raggruppamenti), l'importo aggiudicato, la data, l'esito, il criterio e il ribasso. Si aggancia a anac_cig tramite cig (la gara: oggetto, amministrazione, luogo) chiudendo il cerchio amministrazione → gara → vincitore. NB: gli importi contengono errori della fonte, affidabili per riga ma non se aggregati alla cieca.`;
const descEn = `Who WINS the public tenders identified by the CIG (source ANAC, CC BY-SA 4.0): for each tender in the anac_cig perimeter, the awarded company (tax code and name), its role (lead/member in temporary groupings), the awarded amount, date, outcome, criterion and discount. Joins to anac_cig via cig (the tender: subject, authority, place), closing the loop authority → tender → winner. Note: amounts carry source errors, reliable per row but not when aggregated blindly.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'anac_aggiudicatari'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('anac_aggiudicatari', 'dati.anticorruzione.it', 'anac/aggiudicatari',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.anticorruzione.it/opendata/dataset/aggiudicatari', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nanac_aggiudicatari: ${Number(stat.n).toLocaleString("it-IT")} righe`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
