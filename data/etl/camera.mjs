// Ingestione degli atti e delle votazioni della Camera dei Deputati →
// tabelle `camera_atti` e `camera_votazioni` in DuckDB + righe nel
// `catalog`. È il lato "iter legislativo e voti nominali" che Normattiva
// non copre (Normattiva ha solo le leggi già approvate, come testo finale):
// qui si vede il percorso e chi ha votato cosa, aula per aula.
//
// Fonte (nessuna chiave): dump RDF dell'Open Data della Camera
// (dati.camera.it, ontologia OCD, CC BY-SA 4.0), in formato N-TRIPLES (una
// tripla per riga, non RDF/XML — nonostante l'estensione ".rdf"):
//   https://dati.camera.it/ocd/dump/atto.rdf.zip       (atti/progetti di legge)
//   https://dati.camera.it/ocd/dump/votazione.rdf.zip  (votazioni nominali elettroniche)
// Coprono le legislature dalla XIII alla XIX (in corso) — aggiornati
// quotidianamente dalla Camera.
//
// TRAPPOLE:
//  - il portale (dati.camera.it/it/download) mostra una pagina CAPTCHA ai
//    client senza JS, ma i file di dump RESTANO scaricabili direttamente
//    (stesso dominio, nessuna sfida sul path /ocd/dump/): non serve un
//    browser, basta uno User-Agent plausibile;
//  - formato N-Triples, non XML: `<soggetto>\t<predicato>\t(oggetto) .`,
//    un file di 20-30MB con ~2-400k righe — si fa un parsing manuale
//    riga-per-riga (nessuna libreria RDF nel progetto), si raggruppa per
//    soggetto e si scrive un NDJSON temporaneo caricato con read_json_auto;
//  - la stessa relazione "atto votato" compare con casing diverso a seconda
//    della riga (`rif_attocamera` E `rif_attoCamera`): il confronto dei nomi
//    predicato è case-insensitive;
//  - `dc:contributor` (i cofirmatari oltre al primo) è MULTIVALORE — una
//    tripla per firmatario aggiuntivo: si CONTA, non si elencano (riga
//    piatta, un cofirmatario per riga sarebbe una tabella diversa);
//  - le date (`dc:date`) sono stringhe `YYYYMMDD` senza separatori.
//
// Uso:  bun etl/camera.mjs [--refresh]
//   --refresh  ignora la cache in raw/camera/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/camera/";
const DB = ROOT + "warehouse.duckdb";
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ atti e votazioni della Camera dei Deputati (dati.camera.it — OCD)");

async function fetchZipText(name) {
  const dest = `${RAW}${name}.ntriples`;
  if (!refresh && (await Bun.file(dest).exists())) return Bun.file(dest).text();
  const res = await fetch(`https://dati.camera.it/ocd/dump/${name}.rdf.zip`, {
    headers: HEADERS,
    signal: AbortSignal.timeout(180_000),
  });
  if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
  const entries = unzipSync(new Uint8Array(await res.arrayBuffer()));
  const inner = Object.keys(entries)[0];
  const text = Buffer.from(entries[inner]).toString("utf8");
  await Bun.write(dest, text);
  return text;
}

// --- parser N-Triples minimale: una tripla per riga, nessun blank node utile ----

const localId = uri => uri.slice(Math.max(uri.lastIndexOf("/"), uri.lastIndexOf("#")) + 1);
const UNESCAPE = { n: "\n", t: "\t", r: "\r", "\\": "\\", '"': '"' };
const LINE_RE = /^<([^>]+)>\t<([^>]+)>\t(.+) \.$/;
const LIT_RE = /^"((?:[^"\\]|\\.)*)"/;

// raggruppa le triple per soggetto, chiamando onField(row, campo, valore, isUri)
// per ogni tripla — riusato sia per atti che per votazioni con mappe campo diverse
function groupBySubject(text, onField) {
  const rows = new Map();
  for (const line of text.split("\n")) {
    if (!line) continue;
    const m = LINE_RE.exec(line);
    if (!m) continue;
    const [, subj, pred, objRaw] = m;
    const id = localId(subj);
    let row = rows.get(id);
    if (!row) rows.set(id, (row = { id }));
    const field = localId(pred).toLowerCase();
    if (objRaw[0] === "<") {
      onField(row, field, localId(objRaw.slice(1, -1)), true);
    } else if (objRaw[0] === '"') {
      const lm = LIT_RE.exec(objRaw);
      if (!lm) continue;
      const value = lm[1].replace(/\\(.)/g, (_, c) => UNESCAPE[c] ?? c);
      onField(row, field, value, false);
    }
  }
  return rows;
}

const ymd = s => (s && /^\d{8}$/.test(s) ? `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}` : null);
// rif_leg punta a legislatura.rdf/{regno_XX|repubblica_XX|costituente}: la
// numerazione riparte da I sia per il Regno che per la Repubblica, un
// "legislatura=17" nudo confonderebbe le due epoche — si tiene SOLO la
// Repubblica (dal 1948), il perimetro editoriale di queste tabelle.
const legNum = uri => Number(uri?.match(/^repubblica_(\d+)$/)?.[1]) || null;

// --- 1. atti (progetti di legge) --------------------------------------------------

const attoText = await fetchZipText("atto");
const attiRows = groupBySubject(attoText, (row, field, value, isUri) => {
  switch (field) {
    case "title": row.titolo = value; break;
    case "date": row.data = ymd(value); break;
    case "creator": row.primo_firmatario = value; break;
    case "contributor": row._cofirmatari = (row._cofirmatari ?? 0) + 1; break;
    case "iniziativa": row.iniziativa = value; break;
    case "rif_leg": row.legislatura = legNum(value); break;
  }
});
const atti = [...attiRows.values()]
  .filter(r => r.titolo && r.legislatura)
  .map(r => ({
    id: r.id,
    legislatura: r.legislatura,
    titolo: r.titolo,
    data: r.data,
    primo_firmatario: r.primo_firmatario ?? null,
    iniziativa: r.iniziativa ?? null,
    numero_cofirmatari: r._cofirmatari ?? 0,
    url: `https://www.camera.it/leg${r.legislatura}/126?leg=${r.legislatura}&idDocumento=${r.id.replace(/^ac\d+_/, "")}`,
  }));
await Bun.write(`${RAW}atti.ndjson`, atti.map(r => JSON.stringify(r)).join("\n"));
console.log(`  atti: ${atti.length} righe normalizzate`);

// --- 2. votazioni ------------------------------------------------------------------

const votoText = await fetchZipText("votazione");
const votiRows = groupBySubject(votoText, (row, field, value, isUri) => {
  switch (field) {
    case "title": row.titolo = value; break;
    case "description": row.descrizione = value; break;
    case "date": row.data = ymd(value); break;
    case "favorevoli": row.favorevoli = Number(value); break;
    case "contrari": row.contrari = Number(value); break;
    case "astenuti": row.astenuti = Number(value); break;
    case "votanti": row.votanti = Number(value); break;
    case "presenti": row.presenti = Number(value); break;
    case "approvato": row.approvato = value === "1"; break;
    case "richiestafiducia": row.richiesta_fiducia = value === "1"; break;
    case "votazionesegreta": row.segreta = value === "1"; break;
    case "votazionefinale": row.finale = value === "1"; break;
    case "rif_leg": row.legislatura = legNum(value); break;
    case "rif_attocamera": row.rif_atto = value; break;
  }
});
const voti = [...votiRows.values()]
  .filter(r => r.legislatura && r.data)
  .map(r => ({
    id: r.id,
    legislatura: r.legislatura,
    data: r.data,
    titolo: r.titolo ?? null,
    descrizione: r.descrizione ?? null,
    esito: r.approvato === true ? "approvata" : r.approvato === false ? "respinta" : null,
    favorevoli: r.favorevoli ?? null,
    contrari: r.contrari ?? null,
    astenuti: r.astenuti ?? null,
    votanti: r.votanti ?? null,
    presenti: r.presenti ?? null,
    richiesta_fiducia: r.richiesta_fiducia ?? false,
    segreta: r.segreta ?? false,
    finale: r.finale ?? false,
    rif_atto: r.rif_atto ?? null,
  }));
await Bun.write(`${RAW}votazioni.ndjson`, voti.map(r => JSON.stringify(r)).join("\n"));
console.log(`  votazioni: ${voti.length} righe normalizzate`);

// --- 3. carica in DuckDB -----------------------------------------------------------

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// colonne dichiarate esplicitamente (VARCHAR per data): alcune date sorgente
// sono malformate (es. "1861-12-00", giorno 00) e l'inferenza automatica di
// read_json_auto le classifica DATE, poi fallisce sulla riga imperfetta —
// TRY_CAST in SELECT gestisce i valori non validi restituendo NULL.
await con.run(`CREATE OR REPLACE TABLE camera_atti AS
  SELECT id, legislatura, titolo, TRY_CAST(data AS DATE) AS data, primo_firmatario,
    iniziativa, numero_cofirmatari, url
  FROM read_json('${RAW}atti.ndjson', format = 'newline_delimited', columns = {
    id: 'VARCHAR', legislatura: 'BIGINT', titolo: 'VARCHAR', data: 'VARCHAR',
    primo_firmatario: 'VARCHAR', iniziativa: 'VARCHAR', numero_cofirmatari: 'BIGINT', url: 'VARCHAR'})`);

await con.run(`CREATE OR REPLACE TABLE camera_votazioni AS
  SELECT id, legislatura, TRY_CAST(data AS DATE) AS data, titolo, descrizione, esito,
    favorevoli, contrari, astenuti, votanti, presenti, richiesta_fiducia, segreta, finale, rif_atto
  FROM read_json('${RAW}votazioni.ndjson', format = 'newline_delimited', columns = {
    id: 'VARCHAR', legislatura: 'BIGINT', data: 'VARCHAR', titolo: 'VARCHAR', descrizione: 'VARCHAR',
    esito: 'VARCHAR', favorevoli: 'BIGINT', contrari: 'BIGINT', astenuti: 'BIGINT', votanti: 'BIGINT',
    presenti: 'BIGINT', richiesta_fiducia: 'BOOLEAN', segreta: 'BOOLEAN', finale: 'BOOLEAN', rif_atto: 'VARCHAR'})`);

const statAtti = (
  await con.runAndReadAll("SELECT count(*) AS n, min(legislatura) AS da, max(legislatura) AS a FROM camera_atti")
).getRowObjects()[0];
const statVoti = (
  await con.runAndReadAll("SELECT count(*) AS n, min(data) AS da, max(data) AS a FROM camera_votazioni")
).getRowObjects()[0];
console.log(`  camera_atti: ${statAtti.n} righe (legislature ${statAtti.da}–${statAtti.a})`);
console.log(`  camera_votazioni: ${statVoti.n} righe (${statVoti.da}–${statVoti.a})`);

// --- 4. righe di catalogo -----------------------------------------------------------

async function catalogRow(table, titleIt, titleEn, descIt, descEn, rowCount) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${table}' ORDER BY ordinal_position`,
    )
  ).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${table}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${table}', 'dati.camera.it', 'camera/${table}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      'https://dati.camera.it', now(), ${rowCount}, '${esc(JSON.stringify(cols))}')`);
}

await catalogRow(
  "camera_atti",
  "Progetti di legge della Camera dei Deputati",
  "Chamber of Deputies bills",
  "Atti presentati alla Camera dei Deputati (proposte e disegni di legge), le legislature della Repubblica (dal 1948) (fonte: dati.camera.it, ontologia OCD, CC BY-SA 4.0). Una riga per atto: titolo, data di presentazione, primo firmatario, tipo di iniziativa (parlamentare/governativa/…), numero di cofirmatari, link alla scheda ufficiale. Si aggancia a camera_votazioni tramite l'id dell'atto.",
  "Bills presented to the Italian Chamber of Deputies, every Republic legislature (since 1948) (source: dati.camera.it, OCD ontology, CC BY-SA 4.0). One row per bill: title, filing date, first signer, type of initiative (parliamentary/governmental/…), number of co-signers, link to the official record. Joins to camera_votazioni via the bill id.",
  Number(statAtti.n),
);
await catalogRow(
  "camera_votazioni",
  "Votazioni nominali elettroniche della Camera dei Deputati",
  "Chamber of Deputies electronic roll-call votes",
  "Ogni votazione nominale elettronica in Aula alla Camera dei Deputati, le legislature della Repubblica (dal 1948) (fonte: dati.camera.it, ontologia OCD, CC BY-SA 4.0). Una riga per votazione: titolo, descrizione, esito, conteggio favorevoli/contrari/astenuti/votanti/presenti, se a scrutinio segreto o su richiesta di fiducia. Il quadro completo di chi vince e chi perde in Aula.",
  "Every electronic roll-call vote in the Chamber of Deputies' Assembly, every Republic legislature (since 1948) (source: dati.camera.it, OCD ontology, CC BY-SA 4.0). One row per vote: title, description, outcome, tally of votes for/against/abstained/voting/present, whether it was a secret ballot or a confidence vote. The full picture of who wins and loses on the floor.",
  Number(statVoti.n),
);

console.log(`\ncamera_atti: ${statAtti.n} righe · camera_votazioni: ${statVoti.n} righe`);
await con.run("CHECKPOINT");
con.closeSync();
