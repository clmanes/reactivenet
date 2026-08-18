// Ingestione degli infortuni sul lavoro denunciati (INAIL, Open Data) →
// tabella `inail_infortuni` in DuckDB + riga nel `catalog`. La fonte è il
// microdato ELEMENTARE (una riga per infortunio denunciato, anonimizzato):
// milioni di righe che qui si AGGREGANO per provincia, anno, gestione e genere
// — così il warehouse tiene una tabella compatta (~poche migliaia di righe)
// invece dei milioni grezzi, e resta comunque una mappa "infortuni per
// provincia" incrociabile con popolazione (tasso per 1000 abitanti).
//
// Fonte (licenza CC BY 4.0, nessuna chiave): un file ZIP per REGIONE, cadenza
// SEMESTRALE (storico consolidato, ~5 anni):
//   https://dati.inail.it/opendata/downloads/daticoncadenzasemestraleinfortuni/
//     zip/DatiConCadenzaSemestraleInfortuni<Regione>_csv.zip
// Si scaricano le 20 REGIONI (TrentinoAltoAdige incluso: NON i file provinciali
// di Bolzano/Trento, che raddoppierebbero).
//
// TRAPPOLE:
//  - il tracciato è CODIFICATO: le colonne rimandano ai vocabolari `voc_inail_*`
//    (già nel warehouse). Qui servono `Gestione` (I/A/S) e poco altro;
//  - la geografia è `LuogoAccadimento` = codice PROVINCIA a 3 cifre (`015` =
//    Milano), NON il comune: si mappa alla `sigla` via
//    voc_istat_cities.CODICE_PROVINCIA, e la sigla aggancia istat_confini_province;
//  - le date sono `DD/MM/YYYY`: l'anno è `right(DataAccadimento, 4)`;
//  - un infortunio è MORTALE se `DataMorte` è valorizzata (celle vuote → NULL);
//  - CSV `;`-separated, tutte le colonne lette come testo.
//
// Uso:  bun etl/inail-infortuni.mjs [--refresh]
//   --refresh  ignora la cache in raw/inail-infortuni/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/inail-infortuni/";
const DB = ROOT + "warehouse.duckdb";
const BASE =
  "https://dati.inail.it/opendata/downloads/daticoncadenzasemestraleinfortuni/zip/DatiConCadenzaSemestraleInfortuni";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const REGIONI = [
  "Abruzzo", "Basilicata", "Calabria", "Campania", "EmiliaRomagna", "FriuliVeneziaGiulia",
  "Lazio", "Liguria", "Lombardia", "Marche", "Molise", "Piemonte", "Puglia", "Sardegna",
  "Sicilia", "Toscana", "TrentinoAltoAdige", "Umbria", "ValledAosta", "Veneto",
];

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// scarica ed estrae una regione (ritorna il path del CSV); usa la cache
async function fetchRegion(reg) {
  const csv = `${RAW}${reg}.csv`;
  if (!refresh && (await Bun.file(csv).exists())) return csv;
  const url = `${BASE}${reg}_csv.zip`;
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(180_000) });
  if (!res.ok) throw new Error(`${reg}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) throw new Error(`${reg}: non è uno zip`);
  const entries = unzipSync(buf, { filter: f => f.name.toLowerCase().endsWith(".csv") });
  const name = Object.keys(entries)[0];
  if (!name) throw new Error(`${reg}: nessun csv nello zip`);
  await Bun.write(csv, entries[name]);
  return csv;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ infortuni sul lavoro denunciati (INAIL, Open Data) — 20 regioni");

let done = 0;
for (const reg of REGIONI) {
  await fetchRegion(reg);
  done++;
  process.stdout.write(`\r  scaricate ${done}/${REGIONI.length}   `);
}
console.log("");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca tutto
// il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// Aggregazione: un GROUP BY su milioni di righe grezze (glob su tutte le regioni)
// → una tabella compatta per provincia/anno/gestione/genere.
await con.run(`CREATE OR REPLACE TABLE inail_infortuni AS
WITH prov AS (
  -- codice provincia (3 cifre) → sigla + codice regione, dai comuni ATTUALI
  SELECT DISTINCT CODICE_PROVINCIA AS cp, SIGLA_AUTOMOBILISTICA AS sigla, lpad(CODICE_REGIONE, 2, '0') AS cod_reg
  FROM voc_istat_cities WHERE DATA_FINE_VALIDITA = '31-12-9999'
),
raw AS (
  SELECT LuogoAccadimento AS cp, DataAccadimento, DataMorte, Genere, Gestione, GradoMenomazione, GiorniIndennizzati
  FROM read_csv('${RAW}*.csv', delim = ';', header = true, all_varchar = true, null_padding = true, union_by_name = true)
  WHERE regexp_matches(LuogoAccadimento, '^[0-9]{3}$')
    AND regexp_matches(DataAccadimento, '/[0-9]{4}$')
    AND right(DataAccadimento, 4) >= '2015'
)
SELECT
  p.cod_reg,
  reg.regione,
  p.sigla,
  pr.provincia,
  r.cp AS cod_prov,
  CAST(right(r.DataAccadimento, 4) AS INTEGER) AS anno,
  CASE r.Gestione WHEN 'I' THEN 'Industria e servizi' WHEN 'A' THEN 'Agricoltura' WHEN 'S' THEN 'Conto Stato' ELSE coalesce(r.Gestione, '?') END AS gestione,
  coalesce(r.Genere, '?') AS genere,
  count(*) AS infortuni,
  count(*) FILTER (WHERE r.DataMorte IS NOT NULL AND trim(r.DataMorte) <> '') AS mortali,
  count(*) FILTER (WHERE TRY_CAST(r.GradoMenomazione AS DOUBLE) > 0) AS con_menomazione,
  coalesce(sum(TRY_CAST(r.GiorniIndennizzati AS INTEGER)), 0) AS giorni_indennizzati
FROM raw r
LEFT JOIN prov p ON p.cp = r.cp
LEFT JOIN istat_confini_province pr ON pr.sigla = p.sigla
LEFT JOIN istat_confini_regioni reg ON reg.cod_reg = p.cod_reg
GROUP BY ALL`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS righe, sum(infortuni) AS inf, sum(mortali) AS morti,
    min(anno) AS da, max(anno) AS a, count(DISTINCT sigla) AS province FROM inail_infortuni`)
).getRowObjects()[0];
console.log(
  `  inail_infortuni: ${stat.righe} righe aggregate — ${Number(stat.inf).toLocaleString("it-IT")} infortuni, ` +
    `${Number(stat.morti).toLocaleString("it-IT")} mortali, ${stat.province} province, anni ${stat.da}–${stat.a}`,
);

// aggancio ai confini (informativo)
const bridge = (
  await con.runAndReadAll(`SELECT round(100.0 * count(*) FILTER (WHERE provincia IS NOT NULL) / count(*), 1) AS pct
    FROM inail_infortuni`)
).getRowObjects()[0].pct;
if (bridge != null) console.log(`  aggancio a istat_confini_province: ${bridge}% delle righe con provincia`);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'inail_infortuni' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Infortuni sul lavoro (INAIL)";
const titleEn = "Workplace injuries (INAIL)";
const descIt = `Infortuni sul lavoro denunciati all'INAIL, dato aggregato per provincia, anno, gestione (Industria e servizi, Agricoltura, Conto Stato) e genere (anni ${stat.da}–${stat.a}, fonte INAIL Open Data, CC BY 4.0): numero di infortuni, casi mortali, casi con menomazione permanente e giorni indennizzati. Deriva dal microdato elementare (una riga per infortunio) aggregato. Si mappa per provincia tramite la sigla (istat_confini_province) e si rapporta a istat_popolazione per il tasso di infortuni per abitante.`;
const descEn = `Workplace injuries reported to INAIL, aggregated by province, year, insurance sector (Industry & services, Agriculture, State account) and gender (years ${stat.da}–${stat.a}, source INAIL Open Data, CC BY 4.0): number of injuries, fatal cases, cases with permanent impairment and compensated days. Derived by aggregating the elementary micro-data (one row per injury). Maps by province via the plate code (istat_confini_province) and relates to istat_popolazione for the injury rate per capita.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'inail_infortuni'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('inail_infortuni', 'dati.inail.it', 'inail/infortuni-semestrale',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.inail.it/portale/it/dataset/infortuni-sul-lavoro.html', now(), ${Number(stat.righe)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\ninail_infortuni: ${stat.righe} righe (anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
