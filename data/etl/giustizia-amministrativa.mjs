// Ingestione delle SENTENZE della giustizia amministrativa (TAR + Consiglio di
// Stato + CGA Sicilia) → tabella `giustizia_amministrativa` in DuckDB + riga
// nel `catalog`. Una riga per sentenza: sede, sezione, tipo provvedimento,
// esito, oggetto del ricorso — il contenzioso pubblico (appalti, concorsi,
// urbanistica, …) incrociabile con `anac_cig`/`indicepa` sul lato PA.
//
// Fonte (nessuna chiave): portale CKAN "OpenGA" della Giustizia
// Amministrativa (dati aperti, CC BY 4.0), attivato nel 2024 con fondi PNRR:
//   https://openga.giustizia-amministrativa.it/api/3/action/package_list
//   https://openga.giustizia-amministrativa.it/api/3/action/package_show?id=<pacchetto>
// Un "pacchetto" CKAN per SEDE giudiziaria (31: Consiglio di Stato, CGA
// Sicilia, i TAR regionali e le loro sotto-sedi), ciascuno con una risorsa
// CSV per anno di pubblicazione.
//
// TRAPPOLE:
//  - il delimitatore NON è uniforme tra sedi: quasi tutte usano `;`, ma
//    almeno una (TAR Sicilia - Catania) usa `,` — niente `delim` forzato,
//    si lascia lo sniffer di DuckDB rilevarlo file per file;
//  - il CSV ha un campo in più di quanto ci si aspetti dal solo "sentenze":
//    FLG_DEFINISCE (D/N) indica se il provvedimento chiude il giudizio —
//    utile per non contare due volte ordinanze interlocutorie;
//  - le sedi NON sono 1:1 con le province (alcuni TAR coprono l'intera
//    regione, altri hanno più sotto-sedi nella stessa regione): la REGIONE
//    è quindi una mappa editoriale fissa qui sotto (31 voci), non un join
//    contro istat_confini_province;
//  - `package_list` include anche pacchetti "ordinanze"/"decreti"/"pareri"/
//    "ricorsi-*" per sede: si prende solo il suffisso "-sentenze" (il
//    perimetro editoriale di questo file — il provvedimento che decide nel
//    merito).
//
// Uso:  bun etl/giustizia-amministrativa.mjs [--refresh]
//   --refresh  ignora la cache in raw/giustizia-amministrativa/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/giustizia-amministrativa/";
const DB = ROOT + "warehouse.duckdb";
const API = "https://openga.giustizia-amministrativa.it/api/3/action";
const HEADERS = { "user-agent": "Mozilla/5.0 (X11; Linux x86_64) reactive-etl/1.0" };

// sede (nome pacchetto CKAN) → regione, editoriale (i pacchetti CKAN non
// portano un codice regione riusabile)
const REGIONE = {
  "cds-sentenze": null, // Consiglio di Stato: giurisdizione nazionale, non una regione
  "cga-sicilia-sentenze": "Sicilia",
  "tar-abruzzo-l-aquila-sentenze": "Abruzzo",
  "tar-abruzzo-pescara-sentenze": "Abruzzo",
  "tar-basilicata-sentenze": "Basilicata",
  "tar-calabria-catanzaro-sentenze": "Calabria",
  "tar-calabria-reggio-calabria-sentenze": "Calabria",
  "tar-campania-napoli-sentenze": "Campania",
  "tar-campania-salerno-sentenze": "Campania",
  "tar-emilia-romagna-bologna-sentenze": "Emilia-Romagna",
  "tar-emilia-romagna-parma-sentenze": "Emilia-Romagna",
  "tar-friuli-venezia-giulia-sentenze": "Friuli-Venezia Giulia",
  "tar-lazio-latina-sentenze": "Lazio",
  "tar-lazio-roma-sentenze": "Lazio",
  "tar-liguria-sentenze": "Liguria",
  "tar-lombardia-brescia-sentenze": "Lombardia",
  "tar-lombardia-milano-sentenze": "Lombardia",
  "tar-marche-sentenze": "Marche",
  "tar-molise-sentenze": "Molise",
  "tar-piemonte-sentenze": "Piemonte",
  "tar-puglia-bari-sentenze": "Puglia",
  "tar-puglia-lecce-sentenze": "Puglia",
  "tar-sardegna-sentenze": "Sardegna",
  "tar-sicilia-catania-sentenze": "Sicilia",
  "tar-sicilia-palermo-sentenze": "Sicilia",
  "tar-toscana-sentenze": "Toscana",
  "tar-umbria-sentenze": "Umbria",
  "tar-valle-d-aosta-sentenze": "Valle d'Aosta",
  "tar-veneto-sentenze": "Veneto",
  "trga-bolzano-sentenze": "Trentino-Alto Adige",
  "trga-trento-sentenze": "Trentino-Alto Adige",
};
const PACCHETTI = Object.keys(REGIONE);

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ sentenze giustizia amministrativa (OpenGA — TAR + Consiglio di Stato)");

async function getJson(url) {
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return res.json();
}

// --- 1. scopre le risorse CSV per sede/anno (cache locale del solo indice) ------

const indexPath = `${RAW}_index.json`;
let index;
if (!refresh && (await Bun.file(indexPath).exists())) {
  index = JSON.parse(await Bun.file(indexPath).text());
} else {
  index = [];
  for (const pkg of PACCHETTI) {
    const { result } = await getJson(`${API}/package_show?id=${pkg}`);
    for (const r of result.resources) {
      if (r.format !== "CSV") continue;
      const m = r.name.match(/(\d{4})$/);
      if (!m) continue;
      index.push({ pkg, anno: Number(m[1]), url: r.url });
    }
  }
  await Bun.write(indexPath, JSON.stringify(index));
}
console.log(`  ${index.length} risorse CSV su ${PACCHETTI.length} sedi`);

// --- 2. scarica ogni CSV (cache per sede/anno) -----------------------------------

let downloaded = 0;
for (const { pkg, anno, url } of index) {
  const dest = `${RAW}${pkg}-${anno}.csv`;
  if (!refresh && (await Bun.file(dest).exists())) continue;
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`${pkg} ${anno}: HTTP ${res.status}`);
  await Bun.write(dest, await res.bytes());
  downloaded++;
  if (downloaded % 20 === 0) console.log(`  scaricati ${downloaded}/${index.length}`);
}
if (downloaded) console.log(`  scaricati ${downloaded} file nuovi`);
else console.log("  tutti i file da cache");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const seatValues = Object.entries(REGIONE)
  .map(([pkg, reg]) => `('${esc(pkg)}', ${reg ? `'${esc(reg)}'` : "NULL"})`)
  .join(", ");
await con.run(`CREATE OR REPLACE TEMP TABLE seat_regione AS SELECT * FROM (VALUES ${seatValues}) AS t(pkg, regione)`);

await con.run(`CREATE OR REPLACE TABLE giustizia_amministrativa AS
WITH raw AS (
  SELECT
    regexp_extract(filename, '([a-z0-9-]+)-\\d{4}\\.csv$', 1) AS pkg,
    NULLIF(trim(TIPO_PROVVEDIMENTO), '') AS tipo_provvedimento,
    NULLIF(trim(NOME_SEDE), '') AS sede,
    NULLIF(trim(NOME_SEZIONE), '') AS sezione,
    NULLIF(trim(NUMERO_PROVVEDIMENTO), '') AS numero_provvedimento,
    NULLIF(trim(NUMERO_RICORSO), '') AS numero_ricorso,
    TRY_CAST(ANNO_PUBBLICAZIONE AS INTEGER) AS anno,
    TRY_CAST(DATA_PUBBLICAZIONE AS DATE) AS data_pubblicazione,
    NULLIF(trim(TIPO_UDIENZA), '') AS tipo_udienza,
    NULLIF(trim(ESITO_PROVVEDIMENTO), '') AS esito,
    FLG_DEFINISCE = 'D' AS definisce,
    TRY_CAST(DATA_DEPOSITO_RICORSO AS DATE) AS data_deposito_ricorso,
    NULLIF(trim(OGGETTO_RICORSO), '') AS oggetto,
    NULLIF(trim(TIPO_RICORSO), '') AS tipo_ricorso,
    TRY_CAST(NUM_MEMBRI_COLLEGIO AS INTEGER) AS membri_collegio
  FROM read_csv('${RAW}*-*.csv', header = true, all_varchar = true,
    ignore_errors = true, strict_mode = false, filename = true, union_by_name = true)
)
SELECT r.sede, sr.regione, r.sezione, r.tipo_provvedimento, r.numero_provvedimento,
  r.numero_ricorso, r.anno, r.data_pubblicazione, r.tipo_udienza, r.esito, r.definisce,
  r.data_deposito_ricorso, r.oggetto, r.tipo_ricorso, r.membri_collegio
FROM raw r
LEFT JOIN seat_regione sr ON sr.pkg = r.pkg
WHERE r.anno IS NOT NULL`);

const stat = (
  await con.runAndReadAll(
    `SELECT count(*) AS n, count(DISTINCT sede) AS sedi, min(anno) AS da, max(anno) AS a FROM giustizia_amministrativa`,
  )
).getRowObjects()[0];
console.log(`  giustizia_amministrativa: ${stat.n} righe — ${stat.sedi} sedi, anni ${stat.da}–${stat.a}`);
if (Number(stat.sedi) < 25) console.warn("  ATTENZIONE: poche sedi presenti, verificare l'indice CKAN");

// --- 3. riga di catalogo ----------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'giustizia_amministrativa' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Sentenze della giustizia amministrativa (TAR e Consiglio di Stato)";
const titleEn = "Administrative justice rulings (regional courts and Council of State)";
const descIt = `Sentenze pubblicate da tutti i Tribunali Amministrativi Regionali, dal Consiglio di Stato e dal CGA Sicilia, anni ${stat.da}–${stat.a} (fonte: portale OpenGA della Giustizia Amministrativa, dati aperti CC BY 4.0). Una riga per provvedimento: sede e sezione giudicante, tipo (sentenza/sentenza breve), esito, oggetto del ricorso in chiaro (appalti, concorsi, urbanistica, accesso agli atti, …), date di deposito. Il contenzioso pubblico, lato giudiziario.`;
const descEn = `Rulings published by every Regional Administrative Court (TAR), the Council of State and the CGA Sicilia, years ${stat.da}–${stat.a} (source: OpenGA portal of Italian administrative justice, CC BY 4.0 open data). One row per ruling: judging seat and section, type (ruling/short ruling), outcome, plain-text subject of the appeal (public tenders, competitions, urban planning, access to documents, …), filing dates. Public litigation, the judicial side.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'giustizia_amministrativa'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('giustizia_amministrativa', 'openga.giustizia-amministrativa.it', 'openga/sentenze',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://openga.giustizia-amministrativa.it', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\ngiustizia_amministrativa: ${stat.n} righe (${stat.sedi} sedi, anni ${stat.da}–${stat.a})`);
await con.run("CHECKPOINT");
con.closeSync();
