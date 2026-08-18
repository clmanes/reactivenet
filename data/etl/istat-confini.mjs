// Ingestione dei confini amministrativi ISTAT (unità amministrative a fini
// statistici, versione GENERALIZZATA) → tre tabelle in DuckDB + righe nel
// `catalog`:
//   istat_confini_comuni    (7896)  una riga per comune, poligono + centroide
//   istat_confini_province  (107)   una riga per provincia/UTS
//   istat_confini_regioni   (20)    una riga per regione
// È il MOLTIPLICATORE geografico del warehouse: trasforma ogni dato per comune
// (popolazione, redditi, gare) in una mappa coropletica. Il poligono è servito
// come GeoJSON [lon, lat] pronto per Leaflet; il centroide (lon/lat) rende ogni
// livello mappabile a punti già con :::map, senza attendere una direttiva nuova.
//
// Fonte (licenza CC-BY 4.0, nessun WAF, nessuna chiave):
//   https://www.istat.it/storage/cartografia/confini_amministrativi/
//     generalizzati/<anno>/Limiti0101<anno>_g.zip
// Un file per anno (i confini al 1° gennaio), pubblicato a inizio anno. La
// versione "_g" (generalizzata) è quella giusta per il web: ~10 MB contro i
// ~100 MB della non generalizzata, dettaglio più che sufficiente a queste scale.
//
// ANNATA — sottigliezza che conta: i confini di gennaio applicano SUBITO le
// riorganizzazioni comunali dell'anno (es. la riforma delle province sarde del
// 2026 rinumera i comuni: Alghero 090003 → 112001), mentre il resto del
// warehouse (popolazione, IndicePA, vocabolari) segue con ~un anno di ritardo.
// Prendere l'anno corrente romperebbe il join per codice_istat proprio dove
// serve. Quindi lo scan parte da THIS_YEAR-1 (l'annata "assestata") e scende;
// la percentuale di aggancio a istat_popolazione stampata a fine ETL è la
// guardia contro uno slittamento futuro (--year forza un'annata specifica).
//
// TRAPPOLE:
//  - lo shapefile è in WGS84/UTM 32N (EPSG:32632, metri): va riproiettato a
//    EPSG:4326 per il GeoJSON. DuckDB riproietta con ordine assi lat/lon, ma il
//    GeoJSON (RFC 7946) vuole [lon, lat] → `always_xy := true` OBBLIGATORIO, o
//    tutte le mappe escono con le coordinate scambiate;
//  - il poligono pieno pesa ~30 MB in totale: si semplifica
//    (ST_SimplifyPreserveTopology) prima di serializzarlo, dimezzando i byte
//    senza intaccare la forma a queste scale;
//  - Shape_Area è nel CRS proiettato (metri²) → superficie_kmq = /1e6, comoda e
//    gratis per la densità (popolazione / superficie);
//  - i nomi di cartella/file dentro lo zip contengono l'anno: gli .shp si
//    risolvono per pattern (Com…/ProvCM…/Reg…_g_WGS84.shp), non cablati;
//  - ST_Read esige gli sidecar (.shx/.dbf/.prj) accanto all'.shp: si estrae
//    TUTTO lo zip su disco, non solo l'.shp.
//
// Join: codice_istat (PRO_COM_T, 6 cifre) → voc_istat_cities.CODICE_COMUNE /
// istat_popolazione.codice_istat (100%); province per sigla; regioni per cod_reg.
//
// Uso:  bun etl/istat-confini.mjs [--year N] [--refresh]
//   --year     forza l'anno dei confini (default: il più recente disponibile)
//   --refresh  ignora la cache in raw/istat-confini/ e riscarica

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { readdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/istat-confini/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://www.istat.it/storage/cartografia/confini_amministrativi/generalizzati/";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const forcedYear = argOf("--year");
const esc = s => String(s).replaceAll("'", "''");

// il portale non ha WAF sui download, ma un UA da browser non guasta
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// scarica lo zip di un anno; null se non esiste (404) o non è uno zip
async function fetchYear(year, outPath) {
  if (!refresh && (await Bun.file(outPath).exists())) return true;
  let res;
  try {
    res = await fetch(`${BASE}${year}/Limiti0101${year}_g.zip`, {
      headers: HEADERS,
      signal: AbortSignal.timeout(180_000),
    });
  } catch (e) {
    throw new Error(`Limiti${year}: ${e.message ?? e}`);
  }
  if (res.status === 404) return false;
  if (!res.ok) throw new Error(`Limiti${year}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) return false; // "PK" = zip
  await Bun.write(outPath, buf);
  return true;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ confini amministrativi ISTAT (istat.it, generalizzati)");

// anno: quello forzato, oppure il più recente che esiste (dall'anno corrente giù)
let year = null;
const zipPath = y => `${RAW}Limiti0101${y}_g.zip`;
if (forcedYear) {
  if (!(await fetchYear(forcedYear, zipPath(forcedYear)))) throw new Error(`Limiti${forcedYear} non disponibile`);
  year = forcedYear;
} else {
  // parte da THIS_YEAR-1 (annata assestata, allineata al resto del warehouse)
  for (let y = THIS_YEAR - 1; y >= THIS_YEAR - 4; y--) {
    if (await fetchYear(y, zipPath(y))) {
      year = y;
      break;
    }
  }
  if (year == null) throw new Error(`nessun file confini trovato tra ${THIS_YEAR - 4} e ${THIS_YEAR - 1}`);
}
console.log(`  anno dei confini: ${year}`);

// estrai TUTTO lo zip su disco (ST_Read esige gli sidecar accanto all'.shp)
const dir = `${RAW}${year}/`;
mkdirSync(dir, { recursive: true });
const entries = unzipSync(new Uint8Array(await Bun.file(zipPath(year)).arrayBuffer()));
for (const [name, data] of Object.entries(entries)) {
  if (name.endsWith("/")) continue;
  const out = dir + name;
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, data);
}

// risolve gli .shp per pattern (l'anno è nei nomi): scansione ricorsiva
function findShp(re) {
  const walk = d => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = d + e.name;
      if (e.isDirectory()) {
        const hit = walk(p + "/");
        if (hit) return hit;
      } else if (re.test(e.name)) return p;
    }
    return null;
  };
  const hit = walk(dir);
  if (!hit) throw new Error(`shapefile non trovato per ${re}`);
  return hit;
}
const shpComuni = findShp(/^Com\d+_g_WGS84\.shp$/i);
const shpProv = findShp(/^ProvCM\d+_g_WGS84\.shp$/i);
const shpReg = findShp(/^Reg\d+_g_WGS84\.shp$/i);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// spatial per leggere/riproiettare; vss perché il CHECKPOINT finale tocca tutto
// il database e le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono senza l'estensione.
await con.run("INSTALL spatial");
await con.run("LOAD spatial");
await con.run("INSTALL vss");
await con.run("LOAD vss");

// geometria riproiettata a 4326 con ordine assi [lon, lat], caricata una volta
// per layer in una TEMP; le proiezioni successive semplificano e serializzano.
async function loadLayer(name, shp) {
  await con.run(`CREATE OR REPLACE TEMP TABLE ${name} AS
    SELECT * EXCLUDE geom,
      ST_Transform(geom, 'EPSG:32632', 'EPSG:4326', always_xy := true) AS g4
    FROM ST_Read('${shp}')`);
}
await loadLayer("_reg", shpReg);
await loadLayer("_prov", shpProv);
await loadLayer("_com", shpComuni);

// helper SQL: GeoJSON semplificato, centroide, superficie in km²
const gj = tol => `ST_AsGeoJSON(ST_SimplifyPreserveTopology(g4, ${tol}))`;
const lon = "ST_X(ST_Centroid(g4))";
const lat = "ST_Y(ST_Centroid(g4))";
const kmq = "round(Shape_Area / 1e6, 3)";

// --- regioni --------------------------------------------------------------------
await con.run(`CREATE OR REPLACE TABLE istat_confini_regioni AS
  SELECT lpad(COD_REG::VARCHAR, 2, '0') AS cod_reg,
    DEN_REG AS regione,
    ${kmq} AS superficie_kmq,
    ${lon} AS lon, ${lat} AS lat,
    ${gj(0.0008)} AS geojson
  FROM _reg ORDER BY COD_REG`);

// --- province / UTS -------------------------------------------------------------
// DEN_UTS è il nome unificato (provincia o città metropolitana); SIGLA è la
// chiave pratica verso carburanti/indicepa.
await con.run(`CREATE OR REPLACE TABLE istat_confini_province AS
  SELECT SIGLA AS sigla,
    DEN_UTS AS provincia,
    NULLIF(trim(TIPO_UTS), '') AS tipo,
    lpad(COD_REG::VARCHAR, 2, '0') AS cod_reg,
    ${kmq} AS superficie_kmq,
    ${lon} AS lon, ${lat} AS lat,
    ${gj(0.0006)} AS geojson
  FROM _prov ORDER BY SIGLA`);

// --- comuni ---------------------------------------------------------------------
// si aggancia a province (per COD_UTS → sigla, provincia) e regioni (per COD_REG
// → nome) dello STESSO scarico: nessuna dipendenza da altri ETL.
await con.run(`CREATE OR REPLACE TABLE istat_confini_comuni AS
  SELECT c.PRO_COM_T AS codice_istat,
    c.COMUNE AS comune,
    p.SIGLA AS sigla,
    p.DEN_UTS AS provincia,
    lpad(c.COD_REG::VARCHAR, 2, '0') AS cod_reg,
    r.DEN_REG AS regione,
    round(c.Shape_Area / 1e6, 3) AS superficie_kmq,
    ST_X(ST_Centroid(c.g4)) AS lon,
    ST_Y(ST_Centroid(c.g4)) AS lat,
    ST_AsGeoJSON(ST_SimplifyPreserveTopology(c.g4, 0.0004)) AS geojson
  FROM _com c
  LEFT JOIN _prov p ON c.COD_UTS = p.COD_UTS
  LEFT JOIN _reg r ON c.COD_REG = r.COD_REG
  ORDER BY c.PRO_COM_T`);

// --- statistiche ----------------------------------------------------------------
const stat = tbl =>
  con.runAndReadAll(`SELECT count(*) n, count(geojson) g FROM ${tbl}`).then(r => r.getRowObjects()[0]);
const [sc, sp, sr] = await Promise.all([
  stat("istat_confini_comuni"),
  stat("istat_confini_province"),
  stat("istat_confini_regioni"),
]);
console.log(`  regioni:  ${sr.n}`);
console.log(`  province: ${sp.n}`);
console.log(`  comuni:   ${sc.n} (${sc.g} con geometria)`);
// controllo di coerenza col resto del warehouse (join a popolazione)
const match = (
  await con.runAndReadAll(`SELECT count(*) AS pop, count(g.codice_istat) AS con_geo
    FROM istat_popolazione p LEFT JOIN istat_confini_comuni g ON g.codice_istat = p.codice_istat`)
).getRowObjects()[0];
const matchPct = Number(match.pop) ? Number(match.con_geo) / Number(match.pop) : 1;
console.log(`  aggancio a istat_popolazione: ${match.con_geo}/${match.pop} comuni con confine (${(matchPct * 100).toFixed(1)}%)`);
if (Number(match.pop) > 0 && matchPct < 0.99)
  console.warn(
    `  ⚠ aggancio sotto il 99%: l'annata dei confini (${year}) probabilmente non combacia con quella\n` +
      `    del resto del warehouse (riorganizzazioni comunali). Prova un'altra annata con --year N.`,
  );

// --- righe di catalogo ----------------------------------------------------------
async function catalog(tbl, source, dataflow, titleIt, titleEn, descIt, descEn, url, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  ).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', '${esc(source)}', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      '${esc(url)}', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

const geoNote = (it) =>
  it
    ? "Il campo geojson è il poligono del confine come GeoJSON [lon, lat] (RFC 7946), già semplificato e pronto per Leaflet; lon/lat sono il centroide (mappabile a punti anche con :::map). superficie_kmq è l'area in chilometri quadrati."
    : "The geojson field is the boundary polygon as GeoJSON [lon, lat] (RFC 7946), already simplified and ready for Leaflet; lon/lat are the centroid (mappable as points with :::map too). superficie_kmq is the area in square kilometres.";

await catalog(
  "istat_confini_comuni",
  "istat.it",
  "istat/confini-generalizzati",
  "Confini dei comuni (ISTAT)",
  "Municipality boundaries (ISTAT)",
  `Confini amministrativi dei comuni italiani al 1° gennaio ${year} (versione generalizzata ISTAT): per ogni comune il poligono del confine, il centroide, la superficie, la sigla di provincia e il nome della regione. ${geoNote(true)} Si aggancia a popolazione, redditi e gare tramite codice_istat: è la geometria che rende coropletico qualunque dato per comune.`,
  `Administrative boundaries of Italian municipalities as of 1 January ${year} (ISTAT generalized version): for each municipality the boundary polygon, the centroid, the area, the province code and the region name. ${geoNote(false)} Joins to population, income and tenders via codice_istat: the geometry that turns any per-municipality figure into a choropleth.`,
  "https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici/",
  sc.n,
);
await catalog(
  "istat_confini_province",
  "istat.it",
  "istat/confini-generalizzati",
  "Confini delle province (ISTAT)",
  "Province boundaries (ISTAT)",
  `Confini amministrativi delle province e città metropolitane (unità territoriali sovracomunali) al 1° gennaio ${year} (versione generalizzata ISTAT): poligono, centroide, superficie, sigla, tipo e codice di regione. ${geoNote(true)} Chiave sigla verso carburanti e IndicePA; il livello giusto per la coropletica a scala nazionale.`,
  `Administrative boundaries of provinces and metropolitan cities (supra-municipal territorial units) as of 1 January ${year} (ISTAT generalized version): polygon, centroid, area, plate code, type and region code. ${geoNote(false)} The sigla key joins to fuel stations and IndicePA; the right level for a national-scale choropleth.`,
  "https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici/",
  sp.n,
);
await catalog(
  "istat_confini_regioni",
  "istat.it",
  "istat/confini-generalizzati",
  "Confini delle regioni (ISTAT)",
  "Region boundaries (ISTAT)",
  `Confini amministrativi delle regioni italiane al 1° gennaio ${year} (versione generalizzata ISTAT): poligono, centroide, superficie e codice di regione. ${geoNote(true)} Il livello più leggero (20 poligoni): ideale per una mappa nazionale che non deve caricare migliaia di comuni.`,
  `Administrative boundaries of Italian regions as of 1 January ${year} (ISTAT generalized version): polygon, centroid, area and region code. ${geoNote(false)} The lightest level (20 polygons): ideal for a national map that must not load thousands of municipalities.`,
  "https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici/",
  sr.n,
);

console.log(`\nistat_confini: ${sc.n} comuni, ${sp.n} province, ${sr.n} regioni (confini ${year})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
