// Ingestione dei metadati degli atti normativi statali da dati.normattiva.it
// (API Open Data del Poligrafico) → tabella `lex_atti` in DuckDB + riga nel
// `catalog`. Si ingeriscono i soli METADATI (estremi, titolo, GU, link): il
// testo integrale resta su Normattiva/Gazzetta, raggiunto dai link per riga.
//
// Fonte: POST /ricerca/avanzata paginata per ANNO di pubblicazione in GU
// (finestre piccole: il deep-paging su 200k atti è fragile, per anno sono
// al massimo ~25 pagine). Le pagine grezze sono cachate per anno in
// raw/normattiva/<anno>.ndjson; l'anno corrente viene sempre riscaricato.
//
// Embeddings (ricerca semantica per riga): colonna embedding FLOAT[1024]
// valorizzata via Ollama SOLO per la legislazione primaria della Repubblica
// (LEGGE, DECRETO-LEGGE, DECRETO LEGISLATIVO, … dal 1946) — è il perimetro
// utile per "cerco la norma su X" e tiene il warehouse leggero. I vettori
// già calcolati vengono RIPORTATI dalla tabella precedente (chiave: codice
// redazionale), quindi i run successivi embeddano solo i nuovi atti.
//
// Uso:  bun etl/normattiva.mjs [--from A] [--to B] [--refresh] [--skip-embed]
//   --from/--to   intervallo di anni GU da (ri)scaricare (default 1861..oggi)
//   --refresh     ignora la cache in raw/normattiva/ e riscarica
//   --skip-embed  salta il calcolo degli embeddings (solo caricamento)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/normattiva/";
const DB = ROOT + "warehouse.duckdb";
const API = "https://api.normattiva.it/t/normattiva.api/bff-opendata/v1/api/v1";
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const PAGE = 200;
const BATCH = 16;
const THIS_YEAR = new Date().getFullYear();

// legislazione primaria: il perimetro degli embeddings (con anno >= 1946)
const PRIMARY = [
  "COSTITUZIONE",
  "LEGGE",
  "LEGGE COSTITUZIONALE",
  "DECRETO-LEGGE",
  "DECRETO LEGISLATIVO",
  "DECRETO LEGISLATIVO DEL CAPO PROVVISORIO DELLO STATO",
];

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const skipEmbed = args.includes("--skip-embed");
const fromYear = argOf("--from") ?? 1861;
const toYear = argOf("--to") ?? THIS_YEAR;

const esc = s => String(s).replaceAll("'", "''");

// il WAF del Poligrafico blocca i client non-browser: header da SPA
const HEADERS = {
  accept: "application/json, text/plain, */*",
  "content-type": "application/json",
  origin: "https://dati.normattiva.it",
  referer: "https://dati.normattiva.it/",
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// retry paziente: su run lunghi il WAF ogni tanto chiude la connessione o
// risponde 409 — un backoff generoso basta a farlo passare
async function post(path, body, { tries = 5, timeoutMs = 60_000 } = {}) {
  let lastErr;
  for (let i = 1; i <= tries; i++) {
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), timeoutMs);
    try {
      const res = await fetch(`${API}${path}`, {
        method: "POST",
        headers: HEADERS,
        body: JSON.stringify(body),
        signal: ctl.signal,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      lastErr = e;
      if (i < tries) await new Promise(r => setTimeout(r, 4000 * i));
    } finally {
      clearTimeout(t);
    }
  }
  throw new Error(`${path}: ${lastErr?.message ?? lastErr}`);
}

// --- 1. download per anno (cache NDJSON in raw/) --------------------------------

async function fetchYear(year) {
  const atti = [];
  const body = page => ({
    dataInizioPubProvvedimento: `${year}-01-01`,
    dataFinePubProvvedimento: `${year}-12-31`,
    orderType: "vecchio",
    paginazione: { paginaCorrente: page, numeroElementiPerPagina: PAGE },
  });
  let expected = null;
  for (let page = 1; ; page++) {
    const res = await post("/ricerca/avanzata", body(page));
    expected ??= res.numeroAttiTrovati ?? 0;
    atti.push(...(res.listaAtti ?? []));
    if (atti.length >= expected || (res.listaAtti ?? []).length === 0) break;
    await new Promise(r => setTimeout(r, 150)); // cortesia
  }
  if (expected != null && atti.length < expected)
    throw new Error(`anno ${year}: ${atti.length} atti su ${expected} attesi`);
  return atti;
}

mkdirSync(RAW, { recursive: true });
console.log(`▸ atti normativi da dati.normattiva.it (${fromYear}–${toYear})`);
let downloaded = 0;
for (let year = fromYear; year <= toYear; year++) {
  const path = `${RAW}${year}.ndjson`;
  // l'anno corrente è vivo: sempre riscaricato
  if (!refresh && year !== THIS_YEAR && (await Bun.file(path).exists())) continue;
  const atti = await fetchYear(year);
  await Bun.write(path, atti.map(a => JSON.stringify(a)).join("\n"));
  downloaded++;
  console.log(`  ${year}: ${atti.length} atti`);
  await new Promise(r => setTimeout(r, 250)); // cortesia tra gli anni
}
console.log(`  scaricati ${downloaded} anni (gli altri da cache)`);

// --- 2. normalizzazione → lex_atti ----------------------------------------------
// Tutta la trasformazione avviene in SQL su read_json_auto (tutti gli anni in
// cache, non solo quelli appena scaricati): ogni run ricostruisce la tabella
// intera. Ogni campo passa da CAST(... AS VARCHAR): read_json_auto può
// inferire tipi diversi da file a file e qui vogliamo il controllo esplicito.
//
// Link per riga:
//  - url_normattiva: URN NIR del testo vigente — slug = denominazione
//    minuscola con "." al posto di spazi/trattini (verificato per i tipi
//    principali: legge, decreto.legge, regio.decreto, …)
//  - url_gu: pagina ELI della pubblicazione in Gazzetta Ufficiale

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO in ogni ETL che apre il warehouse in SCRITTURA: le tabelle con
// indice HNSW non possono essere ricostruite dal CHECKPOINT senza l'estensione,
// e il CHECKPOINT tocca tutto il database. Serve anche per creare l'indice al
// passo 3-bis; la persistenza su file è ancora sperimentale.
await con.run("INSTALL vss");
await con.run("LOAD vss");
await con.run("SET hnsw_enable_experimental_persistence = true");

await con.run(`CREATE OR REPLACE TABLE lex_atti_new AS
WITH raw AS (
  SELECT
    NULLIF(CAST(codiceRedazionale AS VARCHAR), '') AS codice_redazionale,
    NULLIF(CAST(denominazioneAtto AS VARCHAR), '') AS tipo,
    NULLIF(COALESCE(CAST(numeroAttoAlfanumerico AS VARCHAR), CAST(numeroAtto AS VARCHAR)), '') AS numero,
    TRY_CAST(annoProvvedimento AS INTEGER) AS anno,
    TRY_CAST(substr(CAST(dataEmanazione AS VARCHAR), 1, 10) AS DATE) AS data_atto,
    NULLIF(trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
      CAST(titoloAtto AS VARCHAR),
      '^\\s*\\[', ''), '\\]\\s*$', ''), '\\(\\w{7,9}\\)\\s*$', ''), '\\s+', ' ', 'g')), '') AS titolo,
    NULLIF(CAST(descrizioneAtto AS VARCHAR), '') AS descrizione,
    TRY_CAST(CAST(dataGU AS VARCHAR) AS DATE) AS data_gu,
    NULLIF(CAST(numeroGU AS VARCHAR), '') AS numero_gu,
    NULLIF(trim(regexp_replace(CAST(tipoSupplementoIt AS VARCHAR), '^\\s*-\\s*', '')), '') AS supplemento,
    TRY_CAST(substr(CAST(dataUltimaModifica AS VARCHAR), 1, 10) AS DATE) AS data_ultima_modifica
  FROM read_json_auto('${RAW}*.ndjson', format = 'newline_delimited', union_by_name = true)
)
SELECT
  *,
  CASE WHEN tipo IS NOT NULL AND data_atto IS NOT NULL AND numero IS NOT NULL AND numero != '0'
    THEN 'https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:'
      || regexp_replace(lower(tipo), '[^a-z0-9]+', '.', 'g') || ':'
      || strftime(data_atto, '%Y-%m-%d') || ';' || numero
  END AS url_normattiva,
  CASE WHEN data_gu IS NOT NULL AND codice_redazionale IS NOT NULL
    THEN 'https://www.gazzettaufficiale.it/eli/id/'
      || strftime(data_gu, '%Y/%m/%d') || '/' || codice_redazionale || '/sg'
  END AS url_gu,
  CAST(NULL AS FLOAT[1024]) AS embedding
FROM raw
QUALIFY row_number() OVER (
  PARTITION BY COALESCE(codice_redazionale, tipo || '|' || CAST(data_atto AS VARCHAR) || '|' || numero || '|' || CAST(data_gu AS VARCHAR))
  ORDER BY data_gu
) = 1`);

const rows = (await con.runAndReadAll("SELECT count(*) AS n FROM lex_atti_new")).getRowObjects()[0].n;
console.log(`  ${rows} atti normalizzati`);

// riporta gli embeddings già calcolati dalla tabella precedente
const hasOld = (await con.runAndReadAll(
  "SELECT count(*) AS n FROM information_schema.tables WHERE table_name = 'lex_atti'",
)).getRowObjects()[0].n;
if (Number(hasOld) > 0) {
  await con.run(`UPDATE lex_atti_new n SET embedding = o.embedding
    FROM lex_atti o
    WHERE o.codice_redazionale = n.codice_redazionale AND o.embedding IS NOT NULL`);
  const kept = (await con.runAndReadAll("SELECT count(*) AS n FROM lex_atti_new WHERE embedding IS NOT NULL"))
    .getRowObjects()[0].n;
  console.log(`  embeddings riportati dalla tabella precedente: ${kept}`);
}
await con.run("DROP TABLE IF EXISTS lex_atti");
await con.run("ALTER TABLE lex_atti_new RENAME TO lex_atti");

// --- 3. embeddings della legislazione primaria (Repubblica) ---------------------

const primaryList = PRIMARY.map(t => `'${esc(t)}'`).join(",");
if (!skipEmbed) {
  const todo = (
    await con.runAndReadAll(`SELECT codice_redazionale, descrizione, titolo FROM lex_atti
      WHERE embedding IS NULL AND anno >= 1946 AND tipo IN (${primaryList})
      ORDER BY data_gu`)
  ).getRowObjects();
  console.log(`▸ embeddings: ${todo.length} atti da calcolare (${EMBED_MODEL})`);
  // testo indicizzato = estremi + titolo; nessun prefisso (convenzione RagIndex:
  // solo la query porta l'istruzione)
  const textOf = r => [r.descrizione, r.titolo].filter(Boolean).join("\n");
  let done = 0;
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const res = await fetch(`${OLLAMA}/api/embed`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model: EMBED_MODEL, input: batch.map(textOf) }),
    });
    if (!res.ok)
      throw new Error(`Ollama HTTP ${res.status} — serve Ollama attivo con ${EMBED_MODEL} (ollama pull ${EMBED_MODEL})`);
    const vecs = (await res.json()).embeddings;
    if (!Array.isArray(vecs) || vecs.length !== batch.length) throw new Error("risposta embed incompleta");
    for (let j = 0; j < batch.length; j++) {
      if (vecs[j].length !== 1024) throw new Error(`dimensione inattesa: ${vecs[j].length}`);
      await con.run(`UPDATE lex_atti SET embedding = [${vecs[j].join(",")}]::FLOAT[1024] WHERE codice_redazionale = ?`, [
        batch[j].codice_redazionale,
      ]);
    }
    done += batch.length;
    if (done % (BATCH * 25) === 0 || done === todo.length) console.log(`  ${done}/${todo.length}`);
  }
}

// --- 3-bis. indice ANN (HNSW) sugli embeddings -----------------------------------
// Senza indice /search scansiona ogni riga con il cosine. L'indice appartiene
// alla TABELLA: il DROP/RENAME del passo 2 lo porta via, va ricreato a ogni run.
const embN = Number((await con.runAndReadAll("SELECT count(embedding) AS n FROM lex_atti")).getRowObjects()[0].n);
if (embN > 0) {
  // tetto di memoria per la build (vss alloca il grafo fuori dalla memoria
  // tracciata: a ~24k vettori è innocuo, ma la regola vale per quando cresce —
  // vedi la nota estesa in anac.mjs, dove a 2,67M vettori senza limite era OOM)
  await con.run("SET memory_limit = '40GB'");
  await con.run(`SET temp_directory = '${ROOT}duckdb_spill'`);
  const t0 = Date.now();
  await con.run("CREATE INDEX idx_lex_atti_emb ON lex_atti USING HNSW (embedding) WITH (metric = 'cosine')");
  console.log(`  indice HNSW su ${embN} vettori: ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}

// --- 4. riga di catalogo ---------------------------------------------------------

const n = (await con.runAndReadAll("SELECT count(*) AS n FROM lex_atti")).getRowObjects()[0].n;
const emb = (await con.runAndReadAll("SELECT count(*) AS n FROM lex_atti WHERE embedding IS NOT NULL")).getRowObjects()[0].n;
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'lex_atti' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Atti normativi statali (Normattiva)";
const titleEn = "Italian state legislation (Normattiva)";
const descIt =
  "Estremi di tutti gli atti normativi statali pubblicati in Gazzetta Ufficiale dal 1861 a oggi (leggi, decreti-legge, decreti legislativi, DPR, regi decreti, …): tipo, numero, data, titolo, riferimenti GU e link al testo vigente su Normattiva e alla pubblicazione in Gazzetta. La ricerca semantica copre la legislazione primaria della Repubblica (dal 1946).";
const descEn =
  "Reference data for every Italian state legislative act published in the Official Journal since 1861 (laws, decree-laws, legislative decrees, presidential decrees, royal decrees, …): type, number, date, title, OJ references and links to the consolidated text on Normattiva and to the OJ publication. Semantic search covers primary legislation of the Republic (from 1946).";
await con.run(`DELETE FROM catalog WHERE table_name = 'lex_atti'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('lex_atti', 'dati.normattiva.it', 'normattiva/atti-statali',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.normattiva.it', now(), ${n}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nlex_atti: ${n} atti, ${emb} con embedding`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
