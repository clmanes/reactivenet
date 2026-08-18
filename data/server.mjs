// Servizio dati di Reactive: espone il warehouse DuckDB alle app tramite
// le direttive od-* — sola lettura, niente stato, niente account (pattern
// relay: un processo Bun, zero framework). Endpoints:
//
//   GET  /            healthcheck: {ok, tables}
//   GET  /datasets    il catalogo (senza embeddings)
//   POST /query       {sql, params?, limit?} → {columns, rows}
//                     SOLO SELECT singole: la validazione usa il parser di
//                     DuckDB (json_serialize_sql), LIMIT forzato, timeout
//                     con interrupt, parametri preparati per i valori
//   POST /search      {q, k?, table?} → ricerca semantica: senza `table`
//                     cerca nel catalogo (i dataset), con `table` cerca tra
//                     le RIGHE di una tabella abilitata (lex_atti la
//                     legislazione, anac_cig le gare pubbliche). Embedding
//                     della query via Ollama locale
//                     (qwen3-embedding:0.6b, lo stesso motore del RAG
//                     in-app) o ONNX, cosine in SQL
//
// Il database è aperto READ_ONLY e senza accesso esterno: niente read_csv/
// httpfs dalle query (che sono SQL arbitrario di chiunque). Attenzione alla
// SEQUENZA, è delicata: enable_external_access=false messo nella CONFIG
// impedisce anche di CARICARE le estensioni ("Loading external extensions is
// disabled through configuration"), e senza l'estensione vss l'indice HNSW non
// verrebbe usato — /search tornerebbe a scansionare milioni di vettori. Si apre
// quindi SENZA il flag, si carica vss e si chiude la porta A RUNTIME: il SET è
// GLOBALE all'istanza (verificato: le connessioni successive nascono già con
// read_csv e httpfs bloccati) e l'indice continua a funzionare.
// CORS aperto: dati pubblici.
//
// Avvio:  bun server.mjs     (PORT, OLLAMA_URL, EMBED_MODEL via env)
// NOTA: l'ETL scrive sul file — va eseguito a servizio fermo.

import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL(".", import.meta.url).pathname; // data/
const DB = ROOT + "warehouse.duckdb";
const PORT = Number(process.env.PORT ?? 8788);
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const MAX_ROWS = 10000; // cap assoluto sulle righe restituite (10k: fa passare
// interi i 7896 comuni in una query — per il ML client-side su feature comunali)
const DEFAULT_ROWS = 1000;
const QUERY_TIMEOUT_MS = 10_000;

// NIENTE top-level await in questo modulo: PM2 (ProcessContainerForkBun) lo
// carica con require(), che non supporta i moduli async. L'istanza è una
// promise risolta al primo uso — e il bootstrap (vss + lockdown) fa parte
// della promise, così NESSUNA richiesta può essere servita prima che la porta
// sia chiusa.
let vssReady = false;
const instancePromise = DuckDBInstance.create(DB, { access_mode: "READ_ONLY" }).then(async instance => {
  const boot = await instance.connect();
  try {
    // 1. l'estensione dell'indice ANN, finché l'accesso esterno è concesso.
    //    Se manca si va avanti lo stesso: /search funziona comunque, solo con
    //    la scansione completa invece dell'indice.
    try {
      await boot.run("LOAD vss");
      vssReady = true;
    } catch (e) {
      console.warn(`vss non caricata (${e.message ?? e}) — /search userà la scansione completa`);
    }
    // 2. e SUBITO la porta si richiude. Questo non è best-effort: se fallisce
    //    il servizio NON deve partire, perché /query esegue SQL arbitrario.
    await boot.run("SET enable_external_access = false");
    const check = await boot.runAndReadAll("SELECT current_setting('enable_external_access') AS v");
    if (String(check.getRowObjectsJson()[0].v) !== "false")
      throw new Error("enable_external_access non è false dopo il SET");
  } finally {
    boot.closeSync();
  }
  return instance;
});
instancePromise.catch(e => {
  console.error(`bootstrap fallito: ${e.message ?? e}`);
  process.exit(1);
});
const connect = async () => (await instancePromise).connect();

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};
const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", ...CORS } });
const err = (status, code, message) => json({ error: code, message }, status);

// Valida col parser di DuckDB: deve essere UNO statement, di tipo SELECT.
// json_serialize_sql non lancia: riporta {error: true} per qualsiasi cosa
// non sia un SELECT valido (INSERT/DROP/PRAGMA/sintassi rotta).
async function validateSelect(con, sql) {
  // json_serialize_sql esige un literal costante: si passa l'SQL escapato
  const r = await con.runAndReadAll(`SELECT json_serialize_sql('${sql.replaceAll("'", "''")}') AS ast`);
  const ast = JSON.parse(r.getRowObjects()[0].ast);
  if (ast.error) return ast.error_message ?? "SQL non valido";
  if ((ast.statements ?? []).length !== 1) return "è ammesso un solo statement";
  if (ast.statements[0].node?.type !== "SELECT_NODE") return "sono ammesse solo SELECT";
  return null;
}

// Esegue con timeout: la connessione è per-richiesta, quindi interrupt()
// non disturba le altre query.
async function runQuery(sql, params, limit) {
  const con = await connect();
  const t = setTimeout(() => con.interrupt(), QUERY_TIMEOUT_MS);
  try {
    const invalid = await validateSelect(con, sql);
    if (invalid) return { status: 400, body: { error: "bad-sql", message: invalid } };
    const cap = Math.min(Math.max(1, limit ?? DEFAULT_ROWS), MAX_ROWS);
    const reader = await con.runAndReadAll(`SELECT * FROM (${sql}\n) __od LIMIT ${cap}`, params ?? []);
    const columns = reader.deduplicatedColumnNames().map((name, i) => ({ name, type: String(reader.columnTypes()[i]) }));
    return { status: 200, body: { columns, rows: reader.getRowObjectsJson(), truncated: reader.currentRowCount === cap } };
  } catch (e) {
    const msg = e.message ?? String(e);
    return /interrupt/i.test(msg)
      ? { status: 408, body: { error: "timeout", message: `query oltre ${QUERY_TIMEOUT_MS / 1000}s` } }
      : { status: 400, body: { error: "query-failed", message: msg } };
  } finally {
    clearTimeout(t);
    con.closeSync();
  }
}

// --- Embedding della query di ricerca ----------------------------------------
// SOLO la query porta il prefisso di istruzione (i passaggi indicizzati non ne
// hanno) e l'ISTRUZIONE è la stessa del RAG in-app (AiRuntime.js): così un
// vettore embeddato dal client è intercambiabile con uno del server.
const EMBED_INSTRUCTION = "Given a search query, retrieve relevant passages that answer the query";
const embedPrefix = q => `Instruct: ${EMBED_INSTRUCTION}\nQuery: ${q}`;

// Motore LOCALE: lo stesso export ONNX del RAG in-app (Transformers.js,
// dtype q8, pooling last_token, normalize) su CPU — il servizio è
// autosufficiente, nessun Ollama richiesto. Il modello (~600 MB) viene
// scaricato al primo uso e cachato in model-cache/.
const LOCAL_EMBED_MODEL = "onnx-community/Qwen3-Embedding-0.6B-ONNX";
let localPipe = null;
function getLocalPipe() {
  if (!localPipe) {
    localPipe = (async () => {
      const { pipeline, env } = await import("@huggingface/transformers");
      env.cacheDir = ROOT + "model-cache";
      return pipeline("feature-extraction", LOCAL_EMBED_MODEL, { dtype: "q8" });
    })().catch(e => {
      localPipe = null; // un fallimento (rete) non deve avvelenare i tentativi futuri
      throw e;
    });
  }
  return localPipe;
}

async function embedLocal(text) {
  const pipe = await getLocalPipe();
  const out = await pipe([text], { pooling: "last_token", normalize: true });
  return Array.from(out.data.slice(0, out.dims[1]));
}

// Ollama come ACCELERATORE opzionale (nativo, spesso GPU): timeout corto,
// al primo intoppo si passa al motore locale.
async function embedOllama(text) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 3_000);
  try {
    const res = await fetch(`${OLLAMA}/api/embed`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model: EMBED_MODEL, input: text }),
      signal: ctl.signal,
    });
    if (!res.ok) throw new Error(`Ollama HTTP ${res.status}`);
    const vec = (await res.json()).embeddings?.[0];
    if (!Array.isArray(vec)) throw new Error("risposta embed senza vettore");
    return vec;
  } finally {
    clearTimeout(t);
  }
}

async function embedQuery(q) {
  const text = embedPrefix(q);
  try {
    return await embedOllama(text);
  } catch {
    return embedLocal(text);
  }
}

// Vettore fornito dal client (browser con pipeline RAG già calda): dev'essere
// esattamente un FLOAT[1024] di numeri finiti — nient'altro entra nell'SQL.
const validVector = v =>
  Array.isArray(v) && v.length === 1024 && v.every(x => typeof x === "number" && Number.isFinite(x));

// Tabelle con ricerca semantica per RIGA (colonna embedding valorizzata
// dall'ETL): proiezione esplicita per tabella — nessun identificatore del
// client entra nell'SQL, `table` fa solo da chiave di questa mappa.
const ROW_SEARCH = {
  lex_atti: "codice_redazionale, tipo, numero, anno, data_atto, titolo, descrizione, url_normattiva, url_gu",
  anac_cig:
    "cig, oggetto_gara, oggetto_lotto, importo_lotto, amministrazione, luogo_istat, provincia, data_pubblicazione, tipo_scelta_contraente, descrizione_cpv, esito",
  corte_costituzionale: "ecli, anno, numero, tipo, presidente, relatore, data_decisione, data_deposito, epigrafe, url",
};

async function search(q, k, vector, table) {
  if (table != null && !ROW_SEARCH[table])
    return { status: 400, body: { error: "bad-request", message: `tabella non ricercabile: ${table}` } };
  let vec;
  if (vector != null) {
    if (!validVector(vector)) return { status: 400, body: { error: "bad-request", message: "vector deve essere FLOAT[1024]" } };
    vec = vector;
  } else {
    try {
      vec = await embedQuery(q);
    } catch (e) {
      return { status: 503, body: { error: "embed-unavailable", message: e.message ?? String(e) } };
    }
  }
  const con = await connect();
  try {
    // il vettore è fatto solo di numeri: il literal inline è sicuro
    const projection = table
      ? ROW_SEARCH[table]
      : "table_name, source, title_it, title_en, description_it, description_en, url, row_count, columns";
    // La forma della query non è indifferente: l'indice HNSW viene usato SOLO
    // con `ORDER BY array_cosine_distance(...) LIMIT n` (crescente). Con
    // array_cosine_similarity ... DESC il planner fa una scansione completa.
    // Lo score resta la SIMILARITÀ (1 - distanza) per non cambiare l'API.
    const lit = `[${vec.join(",")}]::FLOAT[1024]`;
    const reader = await con.runAndReadAll(`
      SELECT ${projection},
             1 - array_cosine_distance(embedding, ${lit}) AS score
      FROM ${table ?? "catalog"}
      WHERE embedding IS NOT NULL
      ORDER BY array_cosine_distance(embedding, ${lit})
      LIMIT ${Math.min(Math.max(1, k ?? 5), 20)}`);
    return { status: 200, body: { results: reader.getRowObjectsJson() } };
  } finally {
    con.closeSync();
  }
}

Bun.serve({
  port: PORT,
  idleTimeout: 30,
  async fetch(req) {
    const url = new URL(req.url);
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

    try {
      if (req.method === "GET" && url.pathname === "/") {
        const con = await connect();
        try {
          const r = await con.runAndReadAll("SELECT count(*) AS n, max(updated) AS updated FROM catalog");
          const { n, updated } = r.getRowObjectsJson()[0];
          return json({ ok: true, tables: Number(n), updated });
        } finally {
          con.closeSync();
        }
      }

      if (req.method === "GET" && url.pathname === "/datasets") {
        const con = await connect();
        try {
          const r = await con.runAndReadAll(
            "SELECT table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns FROM catalog ORDER BY table_name",
          );
          return json({ datasets: r.getRowObjectsJson() });
        } finally {
          con.closeSync();
        }
      }

      if (req.method === "POST" && url.pathname === "/query") {
        const body = await req.json().catch(() => null);
        if (!body?.sql || typeof body.sql !== "string") return err(400, "bad-request", "manca sql");
        if (body.params && !Array.isArray(body.params)) return err(400, "bad-request", "params deve essere un array");
        const r = await runQuery(body.sql, body.params, body.limit);
        return json(r.body, r.status);
      }

      if (req.method === "POST" && url.pathname === "/search") {
        const body = await req.json().catch(() => null);
        if (!body) return err(400, "bad-request", "body JSON mancante");
        if (body.vector == null && (!body.q || typeof body.q !== "string"))
          return err(400, "bad-request", "manca q (o vector)");
        if (body.table != null && typeof body.table !== "string")
          return err(400, "bad-request", "table deve essere una stringa");
        const r = await search(typeof body.q === "string" ? body.q.slice(0, 500) : "", body.k, body.vector, body.table);
        return json(r.body, r.status);
      }

      return err(404, "not-found", url.pathname);
    } catch (e) {
      return err(500, "internal", e.message ?? String(e));
    }
  },
});

console.log(`reactive-data su http://localhost:${PORT} (db: ${DB})`);

// Pre-carico del motore di embedding locale quando Ollama non c'è: il primo
// /search non deve pagare il download del modello. Best-effort, in background.
fetch(`${OLLAMA}/api/tags`, { signal: AbortSignal.timeout(2_000) })
  .then(r => {
    if (!r.ok) throw new Error();
    console.log(`embed: Ollama attivo (${EMBED_MODEL}) — ONNX locale caricato solo al bisogno`);
  })
  .catch(() => {
    console.log("embed: Ollama assente — pre-carico il motore ONNX locale…");
    getLocalPipe()
      .then(() => console.log("embed: motore ONNX locale pronto"))
      .catch(e => console.warn(`embed: pre-carico fallito (${e.message ?? e}) — ritenterò alla prima ricerca`));
  });
