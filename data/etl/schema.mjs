// Ingestione dei vocabolari controllati di schema.gov.it (NDC — Catalogo
// Nazionale della semantica dei dati) → DuckDB. Per ogni vocabolario
// pubblicato (~200: comuni, province, regioni, ATECO, titoli di studio, …)
// crea una tabella `voc_<ente>_<concetto>` e una riga nella tabella
// `catalog` (metadati per /datasets e per la ricerca semantica; embeddings
// calcolati in un passo separato).
//
// Fonte dati, in ordine di preferenza:
//   1. la distribuzione CSV ufficiale su GitHub (italia/dati-semantic-assets),
//      derivata dall'URL del Turtle nei metadati dell'asset — è COMPLETA;
//   2. l'API piatta dell'NDC (/api/vocabularies/<ente>/<concetto>), che per
//      alcuni vocabolari è tronca (es. istat/cities espone 21 comuni su ~8000)
//      e fa solo da ripiego.
//
// Uso:  bun etl/schema.mjs [--only <ente>/<concetto>] [--max N] [--refresh]
//   --only     elabora un solo vocabolario (es. istat/cities)
//   --max      elabora solo i primi N vocabolari (debug)
//   --refresh  ignora la cache in raw/schema/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/schema/";
const DB = ROOT + "warehouse.duckdb";
const API = "https://schema.gov.it/api";
const PAGE = 200; // massimo accettato dall'API piatta (oltre risponde 400)

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const only = args.includes("--only") ? args[args.indexOf("--only") + 1] : null;
const max = args.includes("--max") ? Number(args[args.indexOf("--max") + 1]) : Infinity;

const esc = s => String(s).replaceAll("'", "''");
const tableNameOf = (agency, concept) => `voc_${agency}_${concept}`.toLowerCase().replace(/[^a-z0-9]+/g, "_");

// fetch con timeout e retry: i portali pubblici ogni tanto rispondono 5xx
async function fetchRetry(url, { tries = 3, timeoutMs = 120_000 } = {}) {
  let lastErr;
  for (let i = 1; i <= tries; i++) {
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), timeoutMs);
    try {
      const res = await fetch(url, { signal: ctl.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res;
    } catch (e) {
      lastErr = e;
      if (i < tries) await new Promise(r => setTimeout(r, 1000 * i));
    } finally {
      clearTimeout(t);
    }
  }
  throw new Error(`HTTP fallito (${lastErr?.message ?? lastErr}) su ${url}`);
}
const getJson = async url => (await fetchRetry(url)).json();

// --- 1. elenco degli asset di tipo vocabolario ---------------------------------

console.log("▸ vocabolari controllati di schema.gov.it");
const assets = [];
for (let off = 0; ; off += 100) {
  const page = await getJson(`${API}/semantic-assets?limit=100&offset=${off}`);
  assets.push(...page.data);
  if (assets.length >= page.totalCount || page.data.length === 0) break;
}
const vocabAssets = assets.filter(a => a.type === "CONTROLLED_VOCABULARY");
console.log(`  ${assets.length} asset, di cui ${vocabAssets.length} vocabolari controllati`);

// --- 2. per ogni vocabolario: dettagli → dati (CSV GitHub o API) → DuckDB ------

mkdirSync(RAW, { recursive: true });
const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO in ogni ETL che apre il warehouse in SCRITTURA, anche se non
// tocca gli embeddings: le tabelle con indice HNSW (lex_atti, anac_cig) non
// possono essere ricostruite dal CHECKPOINT senza l'estensione, e il
// CHECKPOINT tocca tutto il database — anche scrivendo solo su un'altra
// tabella si muore in chiusura con "unknown index type 'HNSW'".
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE TABLE IF NOT EXISTS catalog (
  table_name VARCHAR PRIMARY KEY,
  source VARCHAR,
  dataflow VARCHAR,
  title_it VARCHAR,
  title_en VARCHAR,
  description_it VARCHAR,
  description_en VARCHAR,
  url VARCHAR,
  updated TIMESTAMP,
  row_count BIGINT,
  columns JSON,
  embedding FLOAT[1024]
)`);

// scarica la distribuzione CSV ufficiale (derivata dall'URL del .ttl);
// null se l'asset non ne ha una raggiungibile
async function fetchCsv(details, outPath) {
  // alcuni repo (es. istat/ndc-ontologie-vocabolari-controllati) dichiarano
  // downloadUrl in forma github.com/…/tree|blob/… — pagina HTML, non il file
  const toRaw = u =>
    u?.replace(/^https:\/\/github\.com\/([^/]+)\/([^/]+)\/(?:blob|tree)\//, "https://raw.githubusercontent.com/$1/$2/");
  const dls = (details.distributions ?? []).map(d => toRaw(d.downloadUrl));
  const urls = [
    ...dls.filter(u => u?.endsWith(".csv")),
    ...dls.map(u => u?.replace(/\.ttl$/, ".csv")).filter(u => u?.endsWith(".csv")),
  ];
  for (const u of urls) {
    try {
      const res = await fetchRetry(u, { tries: 1 });
      const text = await res.text();
      // alcuni portali rispondono 200 con una pagina HTML al posto del CSV
      if (text.trimStart().startsWith("<")) continue;
      await Bun.write(outPath, text);
      return u;
    } catch {
      /* prossimo candidato */
    }
  }
  return null;
}

// ripiego: API piatta dell'NDC, paginata (per alcuni vocabolari è tronca)
async function fetchFlat(agencyId, keyConcept, outPath) {
  const rows = [];
  while (true) {
    const page = await getJson(`${API}/vocabularies/${agencyId}/${keyConcept}?limit=${PAGE}&offset=${rows.length}`);
    // harvest NDC malformato: header ";"-separato finito in un'unica chiave
    if (page.data[0] && Object.keys(page.data[0]).some(k => k.includes(";"))) return null;
    rows.push(...page.data);
    if (rows.length >= page.totalResults || page.data.length === 0) break;
  }
  if (rows.length === 0) return null;
  await Bun.write(outPath, rows.map(r => JSON.stringify(r)).join("\n"));
  return rows.length;
}

// carica un CSV provando dialetti via via più permissivi: il parse rigoroso
// va bene per quasi tutti i file; alcuni sono "ragged" (righe con campi in
// più o in meno) e su altri lo sniffer non riconosce il ';' e produce
// un'unica colonna con il ';' nel nome — in entrambi i casi si ritenta
async function loadCsv(table, csvPath) {
  const attempts = [
    `read_csv('${csvPath}', all_varchar = true)`,
    `read_csv('${csvPath}', all_varchar = true, null_padding = true, strict_mode = false)`,
    `read_csv('${csvPath}', all_varchar = true, null_padding = true, strict_mode = false, ignore_errors = true)`,
  ];
  let lastErr;
  for (const reader of attempts) {
    try {
      await con.run(`CREATE OR REPLACE TABLE ${table} AS SELECT * FROM ${reader}`);
      const cols = (await con.runAndReadAll(`DESCRIBE ${table}`)).getRowObjects().map(c => c.column_name);
      if (cols.some(c => c.includes(";"))) {
        lastErr = new Error("dialetto CSV non riconosciuto (';' nei nomi colonna)");
        continue;
      }
      await sanitizeColumns(table, cols);
      await dropGhostColumns(table);
      return;
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr;
}

// Il parse permissivo dei CSV "ragged" (null_padding) può inventare colonne
// senza header e interamente NULL (column4, column5, …): via.
async function dropGhostColumns(table) {
  const cols = (await con.runAndReadAll(`DESCRIBE ${table}`)).getRowObjects().map(c => c.column_name);
  for (const c of cols.filter(c => /^column\d+$/.test(c))) {
    const n = (await con.runAndReadAll(`SELECT count(${c}) AS n FROM ${table}`)).getRowObjects()[0].n;
    if (Number(n) === 0) await con.run(`ALTER TABLE ${table} DROP COLUMN ${c}`);
  }
}

// Nomi colonna ostili all'SQL delle direttive od-* (spazi, trattini, BOM:
// es. "CODICE ATECO 2025") → identificatori semplici (CODICE_ATECO_2025),
// usabili senza virgolette nelle query degli autori.
async function sanitizeColumns(table, cols) {
  const seen = new Set(cols);
  for (const c of cols) {
    let clean = c.replace(/[^A-Za-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
    if (clean === "" ) clean = "col";
    if (clean === c) continue;
    while (seen.has(clean)) clean = `${clean}_`;
    seen.add(clean);
    await con.run(`ALTER TABLE ${table} RENAME COLUMN "${c.replaceAll('"', '""')}" TO ${clean}`);
  }
}

const errors = [];
let done = 0;
let processed = 0;
for (const a of vocabAssets) {
  if (processed >= max) break;
  let id = a.assetIri;
  try {
    const details = await getJson(`${API}/semantic-assets/by-iri?iri=${encodeURIComponent(a.assetIri)}`);
    id = `${details.agencyId}/${details.keyConcept}`;
    if (only && id !== only) continue;
    processed++;

    const table = tableNameOf(details.agencyId, details.keyConcept);
    const csvPath = `${RAW}${table}.csv`;
    const ndjsonPath = `${RAW}${table}.ndjson`;

    let from = null;
    if (!refresh && (await Bun.file(csvPath).exists())) from = "csv (cache)";
    else if (!refresh && (await Bun.file(ndjsonPath).exists())) from = "api (cache)";
    else if (await fetchCsv(details, csvPath)) from = "csv";
    else if (await fetchFlat(details.agencyId, details.keyConcept, ndjsonPath)) from = "api";
    else throw new Error("nessuna distribuzione CSV e API piatta vuota");

    if (from.startsWith("csv")) await loadCsv(table, csvPath);
    else {
      await con.run(`CREATE OR REPLACE TABLE ${table} AS
        SELECT * FROM read_json_auto('${ndjsonPath}', format = 'newline_delimited')`);
      await sanitizeColumns(
        table,
        (await con.runAndReadAll(`DESCRIBE ${table}`)).getRowObjects().map(c => c.column_name),
      );
    }

    const n = (await con.runAndReadAll(`SELECT count(*) AS n FROM ${table}`)).getRowObjects()[0].n;
    const cols = (await con.runAndReadAll(`SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '${esc(table)}' ORDER BY ordinal_position`))
      .getRowObjects()
      .map(c => ({ name: c.column_name, type: c.data_type }));

    await con.run(`DELETE FROM catalog WHERE table_name = '${esc(table)}'`);
    await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
      VALUES ('${esc(table)}', 'schema.gov.it', '${esc(id)}',
        '${esc(details.title ?? a.title ?? id)}', '',
        '${esc(details.description ?? a.description ?? "")}', '',
        '${esc(details.distributions?.[0]?.accessUrl ?? a.assetIri)}',
        now(), ${n}, '${esc(JSON.stringify(cols))}')`);

    done++;
    console.log(`  ✓ ${table}: ${n} righe [${from}]`);
    await new Promise(r => setTimeout(r, 100)); // cortesia verso i portali
  } catch (e) {
    errors.push({ id, error: e.message ?? String(e) });
    console.warn(`  ✗ ${id}: ${e.message ?? e}`);
  }
}

if (only && processed === 0) {
  console.error(`nessun vocabolario "${only}"`);
  process.exit(1);
}
console.log(`\n${done}/${processed} vocabolari caricati${errors.length ? `, ${errors.length} falliti` : ""}`);
const cat = (await con.runAndReadAll("SELECT count(*) AS tabelle, sum(row_count) AS righe FROM catalog WHERE source = 'schema.gov.it'")).getRowObjects()[0];
console.log(`catalogo: ${cat.tabelle} tabelle, ${cat.righe} righe totali`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
process.exit(errors.length > 0 && done === 0 ? 1 : 0);
