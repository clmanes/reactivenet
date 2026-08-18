// Ingestione delle PRONUNCE della Corte Costituzionale (sentenze e ordinanze,
// 1956-oggi) → tabella `corte_costituzionale` in DuckDB + riga nel `catalog`.
// È il gemello naturale di `lex_atti` sul lato giurisprudenza: stessa idea
// (metadati + testo integrale, ricerca semantica sulla legislazione
// primaria), fonte diversa.
//
// Fonte (nessuna chiave): portale open data della Corte Costituzionale
// (CC BY-SA 3.0), tre archivi ZIP annidati (uno zip per fascia di anni, che
// contiene uno zip per anno, che contiene un CSV):
//   https://dati.cortecostituzionale.it/opendata/distribuzione/pronunce/
//     P_csv1956_1980.zip · P_csv1981_2000.zip · P_csv2001_oggi.zip
//
// Embeddings (ricerca semantica per riga): colonna embedding FLOAT[1024]
// valorizzata via Ollama sul testo dell'EPIGRAFE (la formula che riassume la
// questione di legittimità costituzionale) — non sul `testo`/`dispositivo`
// integrali, troppo lunghi per ~25.000 righe. I vettori già calcolati
// vengono riportati dalla tabella precedente (chiave: ecli), quindi i run
// successivi embeddano solo le pronunce nuove.
//
// TRAPPOLE:
//  - il CSV è pipe-separated (`|`) e l'INTESTAZIONE ha una colonna in MENO
//    delle righe dati: manca il nome della colonna ECLI (che sta subito
//    dopo numero_pronuncia) — si salta l'intestazione (skip=1) e si passano
//    i 13 nomi espliciti nell'ordine reale;
//  - encoding ISO-8859-1 (Latin-1), non UTF-8 — e NON un latin-1 "puro"
//    (DuckDB rifiuta `encoding = 'latin-1'` su alcuni byte estesi). Peggio:
//    con `ignore_errors = true` su un file non-UTF-8 il resync del parser si
//    perde dentro i campi di testo lunghi (epigrafe/testo/dispositivo, anche
//    decine di KB), scartando la quasi totalità delle righe silenziosamente
//    (bug osservato: da 212 righe/anno a 0-3). Si converte quindi latin-1→
//    UTF-8 in Node PRIMA di scrivere i CSV su disco (`Buffer.toString
//    ("latin1")` non fallisce mai, a differenza del parser DuckDB): il CSV
//    che arriva a DuckDB è UTF-8 valido e si legge in modalità stretta;
//  - tipologia_pronuncia è una sigla di una lettera: S = sentenza,
//    O = ordinanza;
//  - le date sono `DD/MM/YYYY`: un TRY_CAST diretto a DATE le scarta TUTTE
//    silenziosamente (DuckDB si aspetta ISO) — serve try_strptime con il
//    formato esplicito.
//
// Uso:  bun etl/corte-costituzionale.mjs [--refresh] [--skip-embed]
//   --refresh     ignora la cache in raw/corte-costituzionale/ e riscarica
//   --skip-embed  salta il calcolo degli embeddings (solo caricamento)

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/corte-costituzionale/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://dati.cortecostituzionale.it/opendata/distribuzione/pronunce/";
const ARCHIVI = ["P_csv1956_1980.zip", "P_csv1981_2000.zip", "P_csv2001_oggi.zip"];
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const BATCH = 16;

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const skipEmbed = process.argv.includes("--skip-embed");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ pronunce della Corte Costituzionale (dati.cortecostituzionale.it)");

// --- 1. scarica i 3 archivi e ne estrae i CSV per anno (doppio zip annidato) -----

let extracted = 0;
for (const archivio of ARCHIVI) {
  const marker = `${RAW}.${archivio}.done`;
  if (!refresh && (await Bun.file(marker).exists())) continue;
  console.log(`  scarico ${archivio}…`);
  const res = await fetch(BASE + archivio, { headers: HEADERS, signal: AbortSignal.timeout(180_000) });
  if (!res.ok) throw new Error(`${archivio}: HTTP ${res.status}`);
  const outer = unzipSync(new Uint8Array(await res.arrayBuffer()), { filter: f => f.name.endsWith(".zip") });
  for (const [name, bytes] of Object.entries(outer)) {
    const inner = unzipSync(bytes, { filter: f => f.name.toLowerCase().endsWith(".csv") });
    const csvName = Object.keys(inner)[0];
    if (!csvName) continue;
    const anno = name.match(/(\d{4})/)?.[1];
    if (!anno) continue;
    // latin-1 → UTF-8: converte PRIMA di scrivere (vedi nota TRAPPOLE sopra)
    const utf8 = Buffer.from(inner[csvName]).toString("latin1");
    await Bun.write(`${RAW}pronunce-${anno}.csv`, utf8);
    extracted++;
  }
  await Bun.write(marker, "ok");
}
console.log(extracted ? `  estratti ${extracted} file annuali` : "  tutti gli anni da cache");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// --- 2. carica e normalizza -------------------------------------------------------

await con.run(`CREATE OR REPLACE TABLE corte_costituzionale_new AS
WITH raw AS (
  SELECT * FROM read_csv('${RAW}pronunce-*.csv', delim = '|', header = false, skip = 1,
    all_varchar = true,
    names = ['anno', 'numero', 'ecli', 'tipo', 'presidente', 'relatore', 'redattore',
      'data_decisione', 'data_deposito', 'collegio', 'epigrafe', 'testo', 'dispositivo'])
)
SELECT
  TRY_CAST(anno AS INTEGER) AS anno,
  TRY_CAST(numero AS INTEGER) AS numero,
  NULLIF(trim(ecli), '') AS ecli,
  CASE trim(tipo) WHEN 'S' THEN 'sentenza' WHEN 'O' THEN 'ordinanza' ELSE lower(NULLIF(trim(tipo), '')) END AS tipo,
  NULLIF(trim(presidente), '') AS presidente,
  NULLIF(trim(relatore), '') AS relatore,
  NULLIF(trim(redattore), '') AS redattore,
  TRY_CAST(try_strptime(data_decisione, '%d/%m/%Y') AS DATE) AS data_decisione,
  TRY_CAST(try_strptime(data_deposito, '%d/%m/%Y') AS DATE) AS data_deposito,
  NULLIF(trim(epigrafe), '') AS epigrafe,
  NULLIF(trim(testo), '') AS testo,
  NULLIF(trim(dispositivo), '') AS dispositivo,
  'https://www.cortecostituzionale.it/actionSchedaPronuncia.do?anno=' || CAST(TRY_CAST(anno AS INTEGER) AS VARCHAR)
    || '&numero=' || CAST(TRY_CAST(numero AS INTEGER) AS VARCHAR) AS url,
  CAST(NULL AS FLOAT[1024]) AS embedding
FROM raw
WHERE anno IS NOT NULL AND numero IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY anno, numero, tipo ORDER BY data_deposito) = 1`);

const rows = (await con.runAndReadAll("SELECT count(*) AS n FROM corte_costituzionale_new")).getRowObjects()[0].n;
console.log(`  ${rows} pronunce normalizzate`);

// riporta gli embeddings già calcolati dalla tabella precedente
const hasOld = (
  await con.runAndReadAll("SELECT count(*) AS n FROM information_schema.tables WHERE table_name = 'corte_costituzionale'")
).getRowObjects()[0].n;
if (Number(hasOld) > 0) {
  await con.run(`UPDATE corte_costituzionale_new n SET embedding = o.embedding
    FROM corte_costituzionale o
    WHERE o.ecli = n.ecli AND o.embedding IS NOT NULL`);
  const kept = (await con.runAndReadAll("SELECT count(*) AS n FROM corte_costituzionale_new WHERE embedding IS NOT NULL"))
    .getRowObjects()[0].n;
  console.log(`  embeddings riportati dalla tabella precedente: ${kept}`);
}
await con.run("DROP TABLE IF EXISTS corte_costituzionale");
await con.run("ALTER TABLE corte_costituzionale_new RENAME TO corte_costituzionale");

// --- 3. embeddings sull'epigrafe ---------------------------------------------------

if (!skipEmbed) {
  const todo = (
    await con.runAndReadAll(`SELECT ecli, epigrafe FROM corte_costituzionale
      WHERE embedding IS NULL AND epigrafe IS NOT NULL ORDER BY data_deposito`)
  ).getRowObjects();
  console.log(`▸ embeddings: ${todo.length} pronunce da calcolare (${EMBED_MODEL})`);
  let done = 0;
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const res = await fetch(`${OLLAMA}/api/embed`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model: EMBED_MODEL, input: batch.map(r => r.epigrafe) }),
    });
    if (!res.ok)
      throw new Error(`Ollama HTTP ${res.status} — serve Ollama attivo con ${EMBED_MODEL} (ollama pull ${EMBED_MODEL})`);
    const vecs = (await res.json()).embeddings;
    if (!Array.isArray(vecs) || vecs.length !== batch.length) throw new Error("risposta embed incompleta");
    for (let j = 0; j < batch.length; j++) {
      if (vecs[j].length !== 1024) throw new Error(`dimensione inattesa: ${vecs[j].length}`);
      await con.run(`UPDATE corte_costituzionale SET embedding = [${vecs[j].join(",")}]::FLOAT[1024] WHERE ecli = ?`, [
        batch[j].ecli,
      ]);
    }
    done += batch.length;
    if (done % (BATCH * 25) === 0 || done === todo.length) console.log(`  ${done}/${todo.length}`);
  }
} else {
  console.log("  embeddings saltati (--skip-embed)");
}

// --- 3-bis. indice ANN (HNSW) sugli embeddings -------------------------------------
const embN = Number(
  (await con.runAndReadAll("SELECT count(embedding) AS n FROM corte_costituzionale")).getRowObjects()[0].n,
);
if (embN > 0) {
  // Senza questa riga il CREATE INDEX fallisce con «HNSW indexes can only be created
  // in in-memory databases» — e fallisce ALL'ULTIMO passo, dopo aver scaricato tre
  // zip, normalizzato ventiduemila pronunce e riportato i loro embeddings: tutto il
  // lavoro fatto e niente scritto. La persistenza su file è ancora sperimentale in
  // DuckDB e va abilitata per sessione; normattiva, anac, opencoesione e opencup la
  // impostano già, questo ETL era l'unico dei cinque a non farlo.
  await con.run("SET hnsw_enable_experimental_persistence = true");
  await con.run("SET memory_limit = '40GB'");
  await con.run(`SET temp_directory = '${ROOT}duckdb_spill'`);
  const t0 = Date.now();
  await con.run("CREATE INDEX idx_corte_costituzionale_emb ON corte_costituzionale USING HNSW (embedding) WITH (metric = 'cosine')");
  console.log(`  indice HNSW su ${embN} vettori: ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}

// --- 4. riga di catalogo -----------------------------------------------------------

const stat = (
  await con.runAndReadAll(
    "SELECT count(*) AS n, count(embedding) AS emb, min(anno) AS da, max(anno) AS a FROM corte_costituzionale",
  )
).getRowObjects()[0];
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'corte_costituzionale' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Sentenze e ordinanze della Corte Costituzionale";
const titleEn = "Constitutional Court rulings and orders";
const descIt = `Tutte le pronunce della Corte Costituzionale, sentenze e ordinanze, anni ${stat.da}–${stat.a} (fonte: dati.cortecostituzionale.it, dati aperti CC BY-SA 3.0). Una riga per pronuncia: estremi (anno, numero, ECLI, tipo), collegio giudicante, epigrafe (la questione di legittimità costituzionale), testo e dispositivo integrali, link alla scheda ufficiale. La ricerca semantica copre l'epigrafe di ogni pronuncia — il gemello di lex_atti sul lato giurisprudenza costituzionale.`;
const descEn = `Every ruling of the Italian Constitutional Court, judgments and orders, years ${stat.da}–${stat.a} (source: dati.cortecostituzionale.it, CC BY-SA 3.0 open data). One row per ruling: reference data (year, number, ECLI, type), judging panel, the heading (the constitutional question at stake), full reasoning and operative part, link to the official record. Semantic search covers each ruling's heading — the case-law twin of lex_atti.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'corte_costituzionale'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('corte_costituzionale', 'dati.cortecostituzionale.it', 'cortecostituzionale/pronunce',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.cortecostituzionale.it', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\ncorte_costituzionale: ${stat.n} pronunce (${stat.emb} con embedding), anni ${stat.da}–${stat.a}`);
await con.run("CHECKPOINT");
con.closeSync();
