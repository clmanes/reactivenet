// DuckDB-wasm, statically imported here and nowhere else — reach this module
// only through the dynamic import() in SqlBinder. The engine itself (~10 MB
// compressed) comes from jsdelivr on first use and is cached by the browser;
// its worker is fetched and rewrapped as a blob URL, because worker-src allows
// 'self' and blob: and a cross-origin worker script is neither.

%%raw(`
import * as duckdb from "@duckdb/duckdb-wasm";

let opened = null;

async function open() {
  if (opened) return opened;
  opened = (async () => {
    const bundles = duckdb.getJsDelivrBundles();
    const bundle = await duckdb.selectBundle(bundles);
    const workerSource = await fetch(bundle.mainWorker).then((res) => res.text());
    const workerUrl = URL.createObjectURL(new Blob([workerSource], { type: "text/javascript" }));
    const worker = new Worker(workerUrl);
    const db = new duckdb.AsyncDuckDB(new duckdb.VoidLogger(), worker);
    await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
    URL.revokeObjectURL(workerUrl);
    return db;
  })();
  return opened;
}

// One SELECT over the app's collections. Tables are re-registered on every
// run — a collection is small by SQL's standards, and re-creating it is what
// keeps the table exactly the rows the app holds now. Types are inferred by
// read_json_auto, so numbers are numbers and dates are dates.
async function runQuery(tables, sql, params, limit) {
  const db = await open();
  const connection = await db.connect();
  try {
    for (const [name, rows] of Object.entries(tables)) {
      await db.registerFileText(name + ".json", JSON.stringify(rows));
      await connection.query('DROP TABLE IF EXISTS "' + name.replaceAll('"', '""') + '"');
      await connection.query(
        'CREATE TABLE "' + name.replaceAll('"', '""') +
        "\" AS SELECT * FROM read_json_auto('" + name + ".json')",
      );
    }
    const statement = await connection.prepare(sql);
    try {
      const table = await statement.query(...params);
      const rows = table.toArray().map((row) => {
        const plain = {};
        for (const [key, value] of Object.entries(row.toJSON())) {
          plain[key] = value === null || value === undefined ? "" : String(value);
        }
        return plain;
      });
      return rows.slice(0, limit);
    } finally {
      await statement.close();
    }
  } finally {
    await connection.close();
  }
}

globalThis.__rnDuckDb = { runQuery };
`)

/** Runs one prepared SELECT with the given collections registered as tables,
    answering at most `limit` rows of stringified cells. */
let run: ({..}, string, array<string>, int) => promise<array<{..}>> = %raw(`
function (tables, sql, params, limit) {
  return globalThis.__rnDuckDb.runQuery(tables, sql, params, limit);
}
`)
