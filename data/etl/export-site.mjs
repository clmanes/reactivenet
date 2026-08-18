// Esporta il catalogo del warehouse in JSON per il sito
// (site/src/data/opendata.json): la pagina "Dati open" è così generata
// dai dati veri e resta allineata a ogni run dell'ETL.
//
// Uso:  bun etl/export-site.mjs

import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const OUT = new URL("../../site/src/data/opendata.json", import.meta.url).pathname;

const con = await (await DuckDBInstance.create(ROOT + "warehouse.duckdb", { access_mode: "READ_ONLY" })).connect();
const rows = (
  await con.runAndReadAll(`
    SELECT table_name, source, dataflow, title_it, title_en, description_it, description_en,
           url, strftime(updated, '%Y-%m-%d') AS updated, row_count, columns
    FROM catalog ORDER BY table_name`)
).getRowObjectsJson();

// columns è già JSON (stringa): si parsa per non doppio-serializzare
const datasets = rows.map(r => ({ ...r, row_count: Number(r.row_count), columns: JSON.parse(r.columns) }));
await Bun.write(OUT, JSON.stringify({ generated: new Date().toISOString().slice(0, 10), datasets }, null, 1));
console.log(`${datasets.length} dataset → ${OUT}`);
con.closeSync();
