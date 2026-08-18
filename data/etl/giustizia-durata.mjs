// Ingestione della DURATA dei procedimenti civili → tabella `giustizia_durata`
// in DuckDB + riga nel `catalog`. Una riga per (ufficio giudiziario, materia,
// anno): procedimenti definiti, durata media in giorni e in anni. Completa
// `giustizia_amministrativa` (TAR/Consiglio di Stato) e `corte_costituzionale`
// con la giustizia ORDINARIA — il dato più citato sulla lentezza della
// giustizia civile italiana, qui per singolo tribunale/corte d'appello.
//
// Fonte (licenza CC BY 4.0, nessuna chiave): il portale statistico DGSTAT
// (Direzione Generale di Statistica, Ministero della Giustizia) pubblica due
// export xlsx separati, uno per registro:
//   https://datiestatistiche.giustizia.it/page/it/durata-dei-procedimenti-civili
//   → Durata_SICID_<intervallo>.xlsx  (cognizione ordinaria: civile
//     ordinario, lavoro, previdenza, procedimenti speciali, volontaria
//     giurisdizione — sia Tribunali che Corti d'appello)
//   → Durata_SIECIC_<intervallo>.xlsx (esecuzioni mobiliari/immobiliari,
//     liquidazione giudiziale — ex fallimenti — solo Tribunali)
// Il nome porta l'intervallo di anni coperto (`20142025`): si RISOLVE il link
// corrente dalla pagina invece di cablarlo (pattern farmacie/scuole).
//
// SOLO CIVILE: la pagina gemella "durata-dei-procedimenti-penali" non ha
// nessun link xlsx/csv, solo una dashboard interattiva (report-viewer che
// risponde 500 senza sessione browser) — non esiste un bulk download
// automatizzabile per il penale. Non si inventa un URL: la tabella copre
// solo il civile, onestamente.
//
// TRAPPOLE:
//  - i due file hanno un LIVELLO DI AGGREGAZIONE misto nella stessa colonna
//    (Circondariale = singolo ufficio, Distrettuale = distretto aggregato,
//    Nazionale = Italia): si tiene SOLO il livello per singolo ufficio
//    (Circondariale per i Tribunali, Distrettuale per le Corti d'appello —
//    la Corte d'appello non ha un livello "circondariale" proprio, la sua
//    riga distrettuale È il singolo ufficio), altrimenti i Tribunali di uno
//    stesso distretto si sommerebbero più volte;
//  - SIECIC non ha una colonna "Tipo ufficio" (sono sempre Tribunali) né
//    "Ripartizione" (macroarea): si allinea allo schema di SICID con un
//    letterale 'Tribunale' e si lascia perdere la macroarea (non essenziale,
//    ridondante con la regione);
//  - nessun codice ISTAT/provincia nel file, solo nomi: `Distretto` (la
//    circoscrizione della corte d'appello, 29 sedi) si mappa alla REGIONE
//    con una tabella EDITORIALE qui sotto (stesso pattern di
//    giustizia-amministrativa.mjs per i TAR) — i distretti non sono 1:1 con
//    le regioni (Sicilia ne ha 4, la Sardegna 2, la Puglia 3, …).
//
// Uso:  bun etl/giustizia-durata.mjs [--refresh]
//   --refresh  ignora la cache in raw/giustizia-durata/ e riscarica

import { mkdirSync } from "node:fs";
import XLSX from "xlsx";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/giustizia-durata/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://datiestatistiche.giustizia.it";
const PAGE = `${HOST}/page/it/durata-dei-procedimenti-civili`;
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

// mappa EDITORIALE distretto di corte d'appello (29 sedi) → regione: i
// distretti non coincidono con le regioni (stesso motivo di
// giustizia-amministrativa.mjs per i TAR).
const DISTRETTO_REGIONE = {
  Ancona: "Marche", Bari: "Puglia", Bologna: "Emilia-Romagna", Brescia: "Lombardia",
  Cagliari: "Sardegna", Sassari: "Sardegna", Caltanissetta: "Sicilia", Campobasso: "Molise",
  Catania: "Sicilia", Catanzaro: "Calabria", Firenze: "Toscana", Genova: "Liguria",
  "L'Aquila": "Abruzzo", Lecce: "Puglia", Taranto: "Puglia", Messina: "Sicilia",
  Milano: "Lombardia", Napoli: "Campania", Palermo: "Sicilia", Perugia: "Umbria",
  Potenza: "Basilicata", "Reggio Calabria": "Calabria", Roma: "Lazio", Salerno: "Campania",
  Torino: "Piemonte", Trento: "Trentino-Alto Adige", Bolzano: "Trentino-Alto Adige",
  Trieste: "Friuli-Venezia Giulia", Venezia: "Veneto",
};

mkdirSync(RAW, { recursive: true });
console.log("▸ durata dei procedimenti civili (DGSTAT — Ministero della Giustizia)");

// --- 1. risolve i link correnti dalla pagina -------------------------------------

const pageRes = await fetch(PAGE, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
if (!pageRes.ok) throw new Error(`pagina durata-dei-procedimenti-civili: HTTP ${pageRes.status}`);
const pageHtml = await pageRes.text();
function resolveLink(prefix) {
  const m = pageHtml.match(new RegExp(`/cmsresources/cms/documents/${prefix}_\\d+\\.xlsx`, "i"));
  if (!m) throw new Error(`link ${prefix} non trovato nella pagina`);
  return HOST + m[0];
}
const sources = [
  { key: "SICID", url: resolveLink("Durata_SICID") },
  { key: "SIECIC", url: resolveLink("Durata_SIECIC") },
];

// --- 2. scarica (cache in raw/giustizia-durata/) ---------------------------------

for (const s of sources) {
  s.name = s.url.split("/").pop();
  s.path = `${RAW}${s.name}`;
  if (refresh || !(await Bun.file(s.path).exists())) {
    const res = await fetch(s.url, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
    if (!res.ok) throw new Error(`${s.name}: HTTP ${res.status}`);
    await Bun.write(s.path, await res.arrayBuffer());
    console.log(`  scaricato ${s.name}`);
  } else {
    console.log(`  ${s.name} da cache`);
  }
}

// --- 3. parsing: entrambi i fogli sono tabellari puliti (niente celle unite) ----

function readRows(path, sheetName) {
  const wb = XLSX.readFile(path);
  const sheet = wb.SheetNames.find(n => n.toLowerCase() === sheetName.toLowerCase());
  if (!sheet) throw new Error(`${path}: foglio '${sheetName}' non trovato (fogli: ${wb.SheetNames.join(", ")})`);
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[sheet], { header: 1, defval: null });
  const header = rows[0];
  const idx = c => header.indexOf(c);
  return { rows: rows.slice(1), idx };
}

// SICID: righe per singolo ufficio (Tribunale|Circondariale, o Corte
// d'appello|Distrettuale — quest'ultima È il singolo ufficio, non
// un'aggregazione: le Corti d'appello non hanno un livello circondariale).
const sicid = readRows(`${RAW}${sources[0].name}`, "data");
const sicidOut = [];
for (const r of sicid.rows) {
  const tipo = r[sicid.idx("Tipo ufficio")];
  const livello = r[sicid.idx("Livello di aggregazione")];
  const singolo = (tipo === "Tribunale" && livello === "Circondariale") || (tipo === "Corte d'appello" && livello === "Distrettuale");
  if (!singolo) continue;
  sicidOut.push({
    registro: "SICID",
    distretto: r[sicid.idx("Distretto")],
    tipo_ufficio: tipo,
    sede: r[sicid.idx("Sede")],
    materia: r[sicid.idx("Materia")],
    anno: r[sicid.idx("Anno")],
    definiti: r[sicid.idx("Definiti")],
    durata_media_giorni: r[sicid.idx("Durata media in giorni")],
    durata_media_anni: r[sicid.idx("Durata media in anni")],
  });
}
console.log(`  SICID: ${sicidOut.length} righe (tribunali + corti d'appello, per ufficio)`);

// SIECIC: sempre Tribunali, niente colonna "Tipo ufficio" — si allinea allo
// schema con un letterale.
const siecic = readRows(`${RAW}${sources[1].name}`, "Data");
const siecicOut = [];
for (const r of siecic.rows) {
  if (r[siecic.idx("Livello di aggregazione")] !== "Circondariale") continue;
  siecicOut.push({
    registro: "SIECIC",
    distretto: r[siecic.idx("Distretto")],
    tipo_ufficio: "Tribunale",
    sede: r[siecic.idx("Tribunale")],
    materia: r[siecic.idx("Materia")],
    anno: r[siecic.idx("Anno")],
    definiti: r[siecic.idx("Definiti")],
    durata_media_giorni: r[siecic.idx("Durata media (giorni)")],
    durata_media_anni: r[siecic.idx("Durata media (anni)")],
  });
}
console.log(`  SIECIC: ${siecicOut.length} righe (esecuzioni e liquidazioni giudiziali, per tribunale)`);

// --- 4. CSV intermedio + caricamento in DuckDB -----------------------------------

const csvEsc = v => (v == null ? "" : `"${String(v).replaceAll('"', '""')}"`);
const allRows = [...sicidOut, ...siecicOut];
const cols = ["registro", "distretto", "tipo_ufficio", "sede", "materia", "anno", "definiti", "durata_media_giorni", "durata_media_anni"];
const csv = cols.join(",") + "\n" + allRows.map(r => cols.map(c => csvEsc(r[c])).join(",")).join("\n");
await Bun.write(`${RAW}durata_civile.csv`, csv);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const distrettoValues = Object.entries(DISTRETTO_REGIONE)
  .map(([d, reg]) => `('${esc(d)}', '${esc(reg)}')`)
  .join(", ");
await con.run(`CREATE OR REPLACE TEMP TABLE distretto_regione AS SELECT * FROM (VALUES ${distrettoValues}) AS t(distretto, regione)`);

await con.run(`CREATE OR REPLACE TABLE giustizia_durata AS
SELECT
  r.registro,
  r.distretto,
  dr.regione,
  r.tipo_ufficio,
  r.sede,
  r.materia,
  r.anno::INTEGER AS anno,
  r.definiti::BIGINT AS definiti,
  round(r.durata_media_giorni::DOUBLE, 1) AS durata_media_giorni,
  round(r.durata_media_anni::DOUBLE, 2) AS durata_media_anni
FROM read_csv('${RAW}durata_civile.csv', header = true, all_varchar = true) r
LEFT JOIN distretto_regione dr ON dr.distretto = r.distretto`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT sede) AS uffici, count(regione) AS con_regione,
    min(anno) AS da, max(anno) AS a, round(avg(durata_media_giorni)) AS media_giorni
    FROM giustizia_durata`)
).getRowObjects()[0];
console.log(
  `  giustizia_durata: ${stat.n} righe — ${stat.uffici} uffici, anni ${stat.da}–${stat.a}, ` +
    `${stat.con_regione}/${stat.n} con regione, durata media ${stat.media_giorni} giorni`,
);
if (Number(stat.con_regione) < Number(stat.n)) console.warn("  ATTENZIONE: distretti non agganciati alla mappa regione — verificare DISTRETTO_REGIONE");

// --- 5. riga di catalogo ----------------------------------------------------------

const colsOut = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'giustizia_durata' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Durata dei procedimenti civili (Ministero della Giustizia)";
const titleEn = "Length of civil court proceedings (Ministry of Justice)";
const descIt = `Durata media dei procedimenti civili per ufficio giudiziario, anni ${stat.da}–${stat.a} (fonte DGSTAT — Ministero della Giustizia, CC BY 4.0). Una riga per (ufficio, materia, anno): procedimenti definiti, durata media in giorni e in anni. Copre la cognizione ordinaria — civile ordinario, lavoro, previdenza, procedimenti speciali, volontaria giurisdizione (registro SICID, tribunali e corti d'appello) — e le esecuzioni/liquidazioni giudiziali ex fallimenti (registro SIECIC, solo tribunali). Solo civile: per il penale la fonte non pubblica un export bulk. Il complemento, lato giustizia ordinaria, di giustizia_amministrativa (TAR) e corte_costituzionale.`;
const descEn = `Average length of civil court proceedings by judicial office, years ${stat.da}–${stat.a} (source DGSTAT — Ministry of Justice, CC BY 4.0). One row per (office, subject matter, year): closed proceedings, average duration in days and years. Covers ordinary civil litigation — civil, labour, welfare, special proceedings, voluntary jurisdiction (SICID register, courts and courts of appeal) — and enforcement/insolvency proceedings, ex-bankruptcy (SIECIC register, courts only). Civil only: the source has no bulk export for criminal proceedings. The ordinary-justice complement to giustizia_amministrativa (administrative courts) and corte_costituzionale.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'giustizia_durata'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('giustizia_durata', 'datiestatistiche.giustizia.it', 'giustizia/durata-procedimenti-civili',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://datiestatistiche.giustizia.it/page/it/durata-dei-procedimenti-civili', now(), ${Number(stat.n)}, '${esc(JSON.stringify(colsOut))}')`);

console.log(`\ngiustizia_durata: ${stat.n} righe (${stat.uffici} uffici, anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
