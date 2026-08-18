// Embeddings del catalogo → colonna catalog.embedding (FLOAT[1024]).
// Motore: Qwen3-Embedding-0.6B via Ollama locale — lo STESSO modello del
// RAG in-app, così query (embeddate dal servizio) e descrizioni vivono
// nello stesso spazio vettoriale. I testi indicizzati NON portano il
// prefisso di istruzione (solo la query lo ha — convenzione RagIndex).
//
// Uso:  bun etl/embed.mjs [--refresh]
//   --refresh  ricalcola anche gli embeddings già presenti

import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const DB = ROOT + "warehouse.duckdb";
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const BATCH = 16;

const refresh = process.argv.includes("--refresh");

// testo indicizzato: titolo + descrizioni bilingui + nomi colonna, tutto
// quello su cui una domanda in linguaggio naturale può agganciarsi
function textOf(row) {
  const cols = JSON.parse(row.columns ?? "[]");
  const colNames = cols.map(c => [c.name, c.label_it, c.label_en].filter(Boolean).join(" ")).join(", ");
  return [row.title_it, row.title_en, row.description_it, row.description_en, `Colonne: ${colNames}`]
    .filter(s => s && String(s).trim() !== "")
    .join("\n");
}

async function embed(texts) {
  const res = await fetch(`${OLLAMA}/api/embed`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: texts }),
  });
  if (!res.ok) throw new Error(`Ollama HTTP ${res.status} — serve Ollama attivo con ${EMBED_MODEL} (ollama pull ${EMBED_MODEL})`);
  const out = (await res.json()).embeddings;
  if (!Array.isArray(out) || out.length !== texts.length) throw new Error("risposta embed incompleta");
  return out;
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non possono
// essere ricostruite dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database — anche scrivendo solo sul catalog.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const rows = (
  await con.runAndReadAll(
    `SELECT table_name, title_it, title_en, description_it, description_en, columns
     FROM catalog ${refresh ? "" : "WHERE embedding IS NULL"} ORDER BY table_name`,
  )
).getRowObjects();
console.log(`▸ embeddings catalogo: ${rows.length} tabelle da calcolare (${EMBED_MODEL})`);

let done = 0;
for (let i = 0; i < rows.length; i += BATCH) {
  const batch = rows.slice(i, i + BATCH);
  const vecs = await embed(batch.map(textOf));
  for (let j = 0; j < batch.length; j++) {
    if (vecs[j].length !== 1024) throw new Error(`dimensione inattesa: ${vecs[j].length}`);
    await con.run(
      `UPDATE catalog SET embedding = [${vecs[j].join(",")}]::FLOAT[1024] WHERE table_name = ?`,
      [batch[j].table_name],
    );
  }
  done += batch.length;
  console.log(`  ${done}/${rows.length}`);
}

const n = (await con.runAndReadAll("SELECT count(*) AS n FROM catalog WHERE embedding IS NOT NULL")).getRowObjects()[0].n;
console.log(`catalogo: ${n} tabelle con embedding`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
