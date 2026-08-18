// Ingestione dei disegni di legge (DDL) del Senato → tabella `senato_ddl` in
// DuckDB + riga nel `catalog`. Il gemello di `camera_atti` per il Senato:
// stesso iter legislativo bicamerale, fonte diversa — quando un DDL diventa
// legge, il dump porta anche numero e data della legge risultante.
//
// Fonte (nessuna chiave): repository GitHub open data del Senato
// (SenatoDellaRepubblica/OpenData, CC BY 3.0), un file RDF/XML per
// legislatura (`Leg{N}/dump-ddl-{N}.zip`): si scaricano le ultime 4
// legislature (16-19, dal 2008 a oggi — le legislature 1-12 hanno solo dati
// di composizione, non i DDL).
//
// TRAPPOLE:
//  - RDF/XML "piatto" (non annidato): ogni DDL è un blocco
//    `<rdf:Description rdf:about="http://dati.senato.it/ddl/{id}">…
//    </rdf:Description>` con proprietà come FIGLI DIRETTI senza namespace
//    prefix (`<titoloBreve xmlns="…" rdf:datatype="…">valore</titoloBreve>`)
//    — abbastanza semplice da estrarre con una regex per blocco, senza una
//    libreria XML (nessuna nel progetto);
//  - un DDL ha PIÙ blocchi `rdf:Description` con lo stesso `rdf:about`
//    quando cambia stato durante l'iter (uno per fase): si tiene per ogni
//    DDL solo l'ULTIMA fase vista nel file (il file è ordinato per fase
//    crescente — `progressivoIter` conferma l'ordine), cioè lo stato più
//    recente noto, non lo storico completo;
//  - `numeroLegge`/`dataLegge` sono valorizzati SOLO se il DDL è diventato
//    legge: è il modo per agganciare (a mano, non un JOIN diretto) un DDL
//    alla legge corrispondente in lex_atti.
//
// Uso:  bun etl/senato.mjs [--refresh]
//   --refresh  ignora la cache in raw/senato/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/senato/";
const DB = ROOT + "warehouse.duckdb";
const LEGISLATURE = [16, 17, 18, 19];
const HEADERS = { "user-agent": "Mozilla/5.0 (X11; Linux x86_64) reactive-etl/1.0" };

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ disegni di legge del Senato (SenatoDellaRepubblica/OpenData)");

async function fetchLegXml(leg) {
  const dest = `${RAW}ddl-${leg}.xml`;
  if (!refresh && (await Bun.file(dest).exists())) return Bun.file(dest).text();
  console.log(`  scarico legislatura ${leg}…`);
  const url = `https://github.com/SenatoDellaRepubblica/OpenData/raw/main/Leg${leg}/dump-ddl-${leg}.zip`;
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
  if (!res.ok) throw new Error(`Leg${leg}: HTTP ${res.status}`);
  const entries = unzipSync(new Uint8Array(await res.arrayBuffer()));
  const inner = Object.keys(entries)[0];
  const text = Buffer.from(entries[inner]).toString("utf8");
  await Bun.write(dest, text);
  return text;
}

// --- parser RDF/XML minimale: blocchi <rdf:Description rdf:about="…ddl/ID">
// …</rdf:Description> con proprietà FIGLIE dirette, non annidate ---------------

const BLOCK_RE = /<rdf:Description rdf:about="http:\/\/dati\.senato\.it\/ddl\/(\d+)">([\s\S]*?)<\/rdf:Description>/g;
const FIELD_RE = /<([a-zA-Z]+)(?:\s[^>]*)?>([^<]*)<\/\1>/g;

function parseLegXml(xml, onDdl) {
  let bm;
  while ((bm = BLOCK_RE.exec(xml))) {
    const [, id, body] = bm;
    const fields = {};
    let fm;
    FIELD_RE.lastIndex = 0;
    while ((fm = FIELD_RE.exec(body))) fields[fm[1]] = fm[2];
    onDdl(id, fields);
  }
}

// --- carica tutte le legislature, tenendo l'ultima fase vista per DDL ----------

const ddlById = new Map();
for (const leg of LEGISLATURE) {
  const xml = await fetchLegXml(leg);
  let n = 0;
  parseLegXml(xml, (id, f) => {
    if (!f.legislatura && !f.titoloBreve && !f.titolo) return; // blocco senza dati utili (solo rdf:type)
    ddlById.set(id, { id, ...f }); // l'ultimo blocco visto per id SOVRASCRIVE — file ordinato per fase
    n++;
  });
  console.log(`  legislatura ${leg}: ${n} blocchi con dati`);
}

const rows = [...ddlById.values()].filter(d => d.legislatura).map(d => ({
  id: d.id,
  legislatura: Number(d.legislatura) || null,
  titolo: d.titolo ?? d.titoloBreve ?? null,
  titolo_breve: d.titoloBreve ?? null,
  natura: d.natura ?? null,
  iniziativa: d.iniziativa ?? null,
  ramo: d.ramo ?? null,
  fase: d.fase ?? null,
  stato: d.statoDdl ?? null,
  data_stato: d.dataStatoDdl ?? null,
  data_presentazione: d.dataPresentazione ?? null,
  relatore: d.relatore ?? null,
  numero_legge: d.numeroLegge ?? null,
  data_legge: d.dataLegge ?? null,
  url: `https://www.senato.it/leg/${Number(d.legislatura)}/BGT/Schede/Ddliter/${d.id}.htm`,
}));
await Bun.write(`${RAW}ddl.ndjson`, rows.map(r => JSON.stringify(r)).join("\n"));
console.log(`  ${rows.length} DDL normalizzati (${ddlById.size} id visti, ${ddlById.size - rows.length} senza legislatura)`);

// --- carica in DuckDB -----------------------------------------------------------

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TABLE senato_ddl AS
  SELECT id, legislatura, titolo, titolo_breve, natura, iniziativa, ramo, fase, stato,
    TRY_CAST(data_stato AS DATE) AS data_stato, TRY_CAST(data_presentazione AS DATE) AS data_presentazione,
    relatore, numero_legge, TRY_CAST(data_legge AS DATE) AS data_legge, url
  FROM read_json('${RAW}ddl.ndjson', format = 'newline_delimited', columns = {
    id: 'VARCHAR', legislatura: 'BIGINT', titolo: 'VARCHAR', titolo_breve: 'VARCHAR',
    natura: 'VARCHAR', iniziativa: 'VARCHAR', ramo: 'VARCHAR', fase: 'VARCHAR', stato: 'VARCHAR',
    data_stato: 'VARCHAR', data_presentazione: 'VARCHAR', relatore: 'VARCHAR',
    numero_legge: 'VARCHAR', data_legge: 'VARCHAR', url: 'VARCHAR'})`);

const stat = (
  await con.runAndReadAll(
    "SELECT count(*) AS n, min(legislatura) AS da, max(legislatura) AS a, count(numero_legge) AS diventati_legge FROM senato_ddl",
  )
).getRowObjects()[0];
console.log(`  senato_ddl: ${stat.n} righe (legislature ${stat.da}–${stat.a}, ${stat.diventati_legge} diventati legge)`);

// --- riga di catalogo --------------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'senato_ddl' ORDER BY ordinal_position",
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Disegni di legge del Senato";
const titleEn = "Senate bills";
const descIt = `Disegni di legge (DDL) presentati al Senato, legislature ${stat.da}-${stat.a} (fonte: SenatoDellaRepubblica/OpenData su GitHub, dati aperti CC BY 3.0). Una riga per DDL, con l'ULTIMA fase nota dell'iter: titolo, natura, tipo di iniziativa, ramo, stato e data dello stato, relatore, e — quando approvato — numero e data della legge risultante (agganciabile a lex_atti). Il gemello di camera_atti per il Senato.`;
const descEn = `Bills (DDL) presented to the Italian Senate, legislatures ${stat.da}-${stat.a} (source: SenatoDellaRepubblica/OpenData on GitHub, CC BY 3.0 open data). One row per bill, with the LATEST known stage of its process: title, nature, type of initiative, chamber of origin, status and status date, rapporteur, and — once passed — the number and date of the resulting law (linkable to lex_atti). The Senate twin of camera_atti.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'senato_ddl'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('senato_ddl', 'github.com/SenatoDellaRepubblica/OpenData', 'senato/ddl',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.senato.it', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nsenato_ddl: ${stat.n} righe (legislature ${stat.da}–${stat.a})`);
await con.run("CHECKPOINT");
con.closeSync();
