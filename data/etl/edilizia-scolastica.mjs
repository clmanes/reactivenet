// Ingestione dell'Anagrafe Nazionale dell'Edilizia Scolastica (MIUR — Portale
// Unico dei Dati della Scuola) → tabella `edilizia_scolastica` in DuckDB +
// riga nel `catalog`. Una riga per EDIFICIO scolastico: comune, epoca di
// costruzione, classificazione sismica e vincoli. Il lato "cemento" che
// completa `scuole` (anagrafica) e `iscrizioni_scolastiche` (numeri): quanto
// sono vecchi e quanto sono a rischio sismico gli edifici in cui si studia.
//
// Fonte (licenza IODL 2.0, nessuna chiave), area "Edilizia Scolastica":
//   https://dati.istruzione.it/opendata/opendata/catalogo/elements1/leaf/
//     ?datasetId=DS0101EDIANAGRAFESTA2021  (anagrafica: comune, indirizzo)
//     ?datasetId=DS0131EDIVINCOLISTA2021   (vincoli e classificazione sismica)
//     ?datasetId=DS0161EDIETAORIGINESTA2021 (epoca di costruzione)
// TRE file separati per anno scolastico, stesso suffisso data (stesso batch
// di pubblicazione): si risolve il suffisso dalla pagina DS0101 (l'UNICA
// delle tre che elenca staticamente i link — le pagine DS0131/DS0161
// verificate vuote lato server, un limite del CMS del portale, non della
// fonte: i file esistono comunque agli URL con lo STESSO suffisso) e lo si
// riusa per costruire gli URL degli altri due.
//
// TRAPPOLE:
//  - `CODICECOMUNE` qui è il vero codice ISTAT (6 cifre, es. "060010" per
//    Arpino) — A DIFFERENZA di `scuole`/`iscrizioni_scolastiche`, dove
//    `CODICECOMUNESCUOLA` è invece il codice catastale Belfiore. Verificato
//    per confronto diretto: NON serve il workaround per nome:
//  - chiave di join tra i tre file è (CODICESCUOLA, CODICEEDIFICIO): una
//    scuola può avere più edifici (plessi); i tre file hanno lo stesso
//    numero di righe nell'anno più recente, join 1:1 pulito;
//  - si tiene SOLO l'anno più recente (un edificio non si sposta e non
//    ringiovanisce: un registro, non una serie storica — stesso pattern di
//    `scuole`);
//  - `CLASSIFICAZIONESISMICANAZIONALE` è 1-4 (1 = rischio più alto); i campi
//    vincolo sono SI/NO/IN PARTE/NON DEFINITO, non booleani puri;
//  - `ANNOCOSTRUZIONE`/`ANNOADATTAMENTO` usano il letterale "-" per "non
//    disponibile" → NULL;
//  - una manciata di ANNOCOSTRUZIONE < 1000 (es. "5", "19", "50") sono
//    refusi di inserimento nella fonte (4 righe su 45.596 con anno valido):
//    NON filtrati, si tiene il dato grezzo come pubblicato — chi calcola un
//    minimo/una media filtra a query time. I valori "tondi" (1000, 1200,
//    1300…) NON sono un errore: sono edifici storici (ex conventi, palazzi)
//    con datazione approssimata al secolo, plausibili in Italia.
//
// Uso:  bun etl/edilizia-scolastica.mjs [--refresh]
//   --refresh  ignora la cache in raw/edilizia-scolastica/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/edilizia-scolastica/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://dati.istruzione.it";
const DATASET_PAGE = `${HOST}/opendata/opendata/catalogo/elements1/leaf/?datasetId=DS0101EDIANAGRAFESTA2021`;
const FILE_BASE = `${HOST}/opendata/opendata/catalogo/elements1/`;
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ edilizia scolastica (MIUR — Anagrafe Nazionale dell'Edilizia Scolastica)");

// --- 1. risolve il suffisso più recente dalla pagina EDIANAGRAFESTA2021 -------------

const pageRes = await fetch(DATASET_PAGE, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
if (!pageRes.ok) throw new Error(`pagina dataset: HTTP ${pageRes.status}`);
const pageHtml = await pageRes.text();
const names = [...new Set([...pageHtml.matchAll(/EDIANAGRAFESTA2021(\d+)\.csv/gi)].map(m => m[1]))].sort();
if (!names.length) throw new Error("nessun file EDIANAGRAFESTA2021 trovato nella pagina");
const suffix = names.at(-1); // ordina cronologicamente (anno scolastico + data)
console.log(`  suffisso più recente: ${suffix}`);

const FILES = [
  { key: "anagrafe", prefix: "EDIANAGRAFESTA2021" },
  { key: "vincoli", prefix: "EDIVINCOLISTA2021" },
  { key: "eta", prefix: "EDIETAORIGINESTA2021" },
];
for (const f of FILES) {
  f.name = `${f.prefix}${suffix}.csv`;
  f.path = `${RAW}${f.name}`;
  if (refresh || !(await Bun.file(f.path).exists())) {
    const res = await fetch(FILE_BASE + f.name, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
    if (!res.ok) throw new Error(`${f.name}: HTTP ${res.status}`);
    await Bun.write(f.path, await res.arrayBuffer());
    console.log(`  scaricato ${f.name}`);
  } else {
    console.log(`  ${f.name} da cache`);
  }
}

// --- 2. join dei tre file su (CODICESCUOLA, CODICEEDIFICIO) -------------------------

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const [anagrafe, vincoli, eta] = FILES;
await con.run(`CREATE OR REPLACE TABLE edilizia_scolastica AS
WITH a AS (SELECT * FROM read_csv('${anagrafe.path}', header = true, all_varchar = true)),
     v AS (SELECT * FROM read_csv('${vincoli.path}', header = true, all_varchar = true)),
     e AS (SELECT * FROM read_csv('${eta.path}', header = true, all_varchar = true))
SELECT
  a.ANNOSCOLASTICO AS anno_scolastico,
  a.CODICESCUOLA AS codice_scuola,
  a.CODICEEDIFICIO AS codice_edificio,
  a.CODICECOMUNE AS codice_istat,
  coalesce(g.comune, NULLIF(trim(a.DESCRIZIONECOMUNE), '')) AS comune,
  g.sigla,
  g.provincia,
  g.regione,
  NULLIF(trim(a.DENOMINAZIONEINDIRIZZO), '') AS indirizzo,
  NULLIF(trim(a.CAP), '') AS cap,
  NULLIF(e.ANNOCOSTRUZIONE, '-')::INTEGER AS anno_costruzione,
  NULLIF(trim(e.PERIODOCOSTRUZIONE), '-') AS periodo_costruzione,
  NULLIF(e.ANNOADATTAMENTO, '-')::INTEGER AS anno_adattamento,
  v.VINCOLOIDROGEOLOGICO AS vincolo_idrogeologico,
  v.VINCOLOPAESAGGISTICO AS vincolo_paesaggistico,
  v.EDIFICIOTUTELATO AS edificio_tutelato,
  v.VINCOLOINTERESSECULTURALE AS vincolo_interesse_culturale,
  TRY_CAST(v.CLASSIFICAZIONESISMICANAZIONALE AS TINYINT) AS classificazione_sismica
FROM a
LEFT JOIN v ON v.CODICESCUOLA = a.CODICESCUOLA AND v.CODICEEDIFICIO = a.CODICEEDIFICIO
LEFT JOIN e ON e.CODICESCUOLA = a.CODICESCUOLA AND e.CODICEEDIFICIO = a.CODICEEDIFICIO
LEFT JOIN istat_confini_comuni g ON g.codice_istat = a.CODICECOMUNE`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat, count(anno_costruzione) AS con_eta,
    count(classificazione_sismica) AS con_sismica, min(anno_costruzione) AS piu_vecchio
    FROM edilizia_scolastica`)
).getRowObjects()[0];
console.log(
  `  edilizia_scolastica: ${stat.n} edifici — ${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% agganciati al comune, ` +
    `${((Number(stat.con_eta) / Number(stat.n)) * 100).toFixed(1)}% con anno di costruzione (il più vecchio: ${stat.piu_vecchio}), ` +
    `${((Number(stat.con_sismica) / Number(stat.n)) * 100).toFixed(1)}% con classificazione sismica`,
);

// --- 3. riga di catalogo -----------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'edilizia_scolastica' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Edilizia scolastica: epoca di costruzione e rischio sismico (MIUR)";
const titleEn = "School buildings: construction period and seismic risk (MIUR)";
const descIt = `Anagrafe nazionale degli edifici scolastici, a.s. ${stat.anno_scolastico ?? ""} (fonte MIUR — Anagrafe Nazionale dell'Edilizia Scolastica, Open Data IODL 2.0): una riga per edificio con comune (codice ISTAT diretto), indirizzo, anno/periodo di costruzione, classificazione sismica nazionale (1-4, 1=rischio più alto) e vincoli (idrogeologico, paesaggistico, tutela, interesse culturale). Nessun importo di investimento nella fonte: per i finanziamenti si incrocia con \`opencoesione\` (tema "Istruzione e formazione").`;
const descEn = `National registry of school buildings, school year ${stat.anno_scolastico ?? ""} (source MIUR — National School Building Registry, Open Data IODL 2.0): one row per building with municipality (direct ISTAT code), address, construction year/period, national seismic classification (1-4, 1=highest risk) and constraints (hydrogeological, landscape, heritage protection, cultural interest). No investment figures in the source: for funding, cross-reference with \`opencoesione\` (theme "Education and training").`;
await con.run(`DELETE FROM catalog WHERE table_name = 'edilizia_scolastica'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('edilizia_scolastica', 'dati.istruzione.it', 'miur/anagrafe-edilizia-scolastica',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.istruzione.it/opendata/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nedilizia_scolastica: ${stat.n} edifici`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
