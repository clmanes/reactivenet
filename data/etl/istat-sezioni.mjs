// Ingestione delle Basi Territoriali ISTAT — le SEZIONI DI CENSIMENTO — e delle
// variabili censuarie che vi si appoggiano → tre tabelle in DuckDB + righe nel
// `catalog`:
//   istat_sezioni                 (~400k)  una riga per sezione: geometria, centroide,
//                                          tipo di località, popolazione/famiglie/
//                                          abitazioni/edifici del censimento 2021
//   istat_censimento_sezioni      (~220k)  le 127 variabili censuarie 2023 per sezione,
//                                          in forma LARGA (una colonna per variabile)
//   istat_censimento_variabili    (127)    il dizionario: codice → definizione ISTAT
//
// È la SOLA dimensione sotto il comune che il warehouse abbia: tutto il resto si
// ferma al codice ISTAT a 6 cifre. Con questa, una coropletica smette di colorare
// 7896 poligoni e ne colora quattrocentomila — e le 127 variabili (età, cittadinanza,
// titolo di studio, occupazione, famiglie, abitazioni, automobili) diventano
// interrogabili per isolato invece che per municipio.
//
// FONTI (nessuna chiave, nessun WAF, licenza NON dichiarata in pagina — ISTAT
// rimanda al Contact Centre: verificarla prima di RIPUBBLICARE le geometrie,
// non serve per ingerirle):
//   geometrie   https://www.istat.it/storage/cartografia/basi_territoriali/2021/R<nn>_21.zip
//               20 file, uno per regione, 695 MB in totale (misurati)
//   variabili   https://esploradati.istat.it/databrowser/DWL/PERMPOP/SUBCOM/
//                 Dati_regionali_<anno>.zip — 249 MB, 20 xlsx + il TRACCIATO
//   Comuni_<anno>.zip è deliberatamente ignorato: contiene i soli 14 capoluoghi
//   metropolitani, cioè un sottoinsieme di Dati_regionali.
//
// LE DUE ANNATE NON COINCIDONO, E VA DETTO. La geometria è quella delle Basi
// Territoriali 2021; le variabili sono del 2023, che ISTAT pubblica SOPRA le basi
// del 2021 (è lo stesso accoppiamento che usa Cruscotto Italia). Il join per
// SEZ21_ID è quindi legittimo, ma `popolazione` in istat_sezioni e `P1` in
// istat_censimento_sezioni sono la STESSA grandezza a due anni di distanza e non
// saranno mai uguali: in Valle d'Aosta 123.360 contro 122.877. Chi le confronta
// senza sapere questo apre una segnalazione di bug su un dato corretto.
// `--anno-var 2021` allinea le due annate, se è la coerenza che serve.
//
// TRAPPOLE:
//  - SEZ21_ID NON HA LUNGHEZZA FISSA: 11 caratteri dove PRO_COM ha 4 cifre (Valle
//    d'Aosta, 70010000001), 12 dove ne ha 5 (Molise, 700010000001; Roma, Milano,
//    Torino...). Un lpad a 11 troncherebbe metà del Paese. Si casta a VARCHAR e
//    basta: le due fonti concordano già sulle cifre. La percentuale di aggancio
//    stampata a fine ETL è la guardia se un giorno smettessero;
//  - lo shapefile è in WGS84/UTM 32N (EPSG:32632, metri): va riproiettato a 4326
//    per il GeoJSON, e `always_xy := true` è OBBLIGATORIO perché DuckDB riproietta
//    con ordine assi lat/lon mentre il GeoJSON (RFC 7946) vuole [lon, lat] —
//    senza, ogni mappa esce con le coordinate scambiate. Stessa trappola di
//    istat-confini.mjs;
//  - la geometria PIENA pesa ~1,1 GB di testo GeoJSON su scala nazionale: si
//    semplifica prima di serializzarla. La tolleranza di default (0.00005°, ~5 m)
//    la porta a ~650 MB prima della compressione colonnare di DuckDB. È molto più
//    fine di quella dei confini comunali (0.0004) perché qui un poligono è un
//    isolato, non un comune. `--tol` la cambia, `--no-geometry` la salta del tutto
//    (tabella ~15× più piccola, se servono solo i numeri);
//  - lo zip regionale contiene ANCHE TAB/SEZ_R<nn>_21.csv con gli stessi attributi,
//    ma è in UTF-16 con separatore tab: si legge lo SHP, che ha i dati e la forma;
//  - ST_Read esige gli sidecar (.shx/.dbf/.prj) accanto all'.shp → si estrae TUTTO
//    lo zip su disco, non solo l'.shp;
//  - read_xlsx con all_varchar=true e TRY_CAST a valle: l'inferenza di tipo su una
//    colonna con celle vuote produce VARCHAR per alcune regioni e BIGINT per altre,
//    e l'INSERT nella tabella già creata fallirebbe a metà del Paese;
//  - circa il 45% delle sezioni NON ha variabili censuarie: sono le sezioni non
//    residenziali (aree industriali, parchi, acque). Non è un buco dei dati, è la
//    loro forma. Perciò le due tabelle sono separate e si uniscono con una LEFT
//    JOIN — mettere 127 colonne NULL su 180k righe sarebbe stato peggio;
//  - forma LARGA e non lunga: 400k sezioni × 127 variabili sono 50,8 milioni di
//    righe in forma lunga, cioè quattro volte opencup. DuckDB è colonnare, quindi
//    una query che chiede tre variabili ne legge tre — la tabella larga è insieme
//    la forma della fonte e quella che costa meno;
//  - il dizionario NON riporta i denominatori leciti per le percentuali. Non è una
//    dimenticanza: la base corretta di P86-P90 (titolo di studio) è P83
//    (popolazione 9 anni e più), non P1, e un registro sbagliato produce
//    percentuali plausibili. Va costruito verificando sui dati che la somma delle
//    parti faccia il totale, ed è un lavoro suo, non di questo ETL.
//
// Join: codice_istat (6 cifre) → tutto il resto del warehouse; sez_id fra le due
// tabelle nuove. La geometria si aggancia a istat_confini_comuni per sigla e
// regione, se servono.
//
// Uso:  bun etl/istat-sezioni.mjs [flag]
//   --refresh          ignora la cache in raw/istat-sezioni/ e riscarica
//   --only R01,R14     limita alle regioni elencate (per provare senza 950 MB)
//   --anno-var 2021    variabili del 2021 invece che del 2023
//   --tol 0.0001       tolleranza di semplificazione in gradi (default 0.00005)
//   --no-geometry      non serializza il GeoJSON (colonna a NULL)

import { mkdirSync, writeFileSync, readdirSync, existsSync } from "node:fs";
import { dirname } from "node:path";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/istat-sezioni/";
const DB = ROOT + "warehouse.duckdb";

const BT_YEAR = 2021; // Basi Territoriali: l'edizione corrente, legata al censimento
const BASE_SHP = `https://www.istat.it/storage/cartografia/basi_territoriali/${BT_YEAR}/`;
const BASE_VAR = "https://esploradati.istat.it/databrowser/DWL/PERMPOP/SUBCOM/";
const REGIONI = Array.from({ length: 20 }, (_, i) => "R" + String(i + 1).padStart(2, "0"));

const args = process.argv.slice(2);
const argOf = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const refresh = args.includes("--refresh");
const noGeom = args.includes("--no-geometry");
const TOL = Number(argOf("--tol", "0.00005"));
const VAR_YEAR = String(argOf("--anno-var", "2023"));
const only = argOf("--only", null)?.split(",").map(s => s.trim().toUpperCase()) ?? null;
const esc = s => String(s).replaceAll("'", "''");

if (!Number.isFinite(TOL) || TOL < 0) throw new Error(`--tol non valida: ${argOf("--tol")}`);
if (!/^\d{4}$/.test(VAR_YEAR)) throw new Error(`--anno-var non valida: ${VAR_YEAR}`);
if (only?.some(r => !REGIONI.includes(r))) throw new Error(`--only: regioni ignote (attese R01…R20)`);

// il portale non ha WAF sui download, ma un UA da browser non guasta
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// scarica su disco se manca (o se --refresh); ritorna il percorso
async function grab(url, outPath, label) {
  if (!refresh && (await Bun.file(outPath).exists())) return outPath;
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(900_000) });
  if (!res.ok) throw new Error(`${label}: HTTP ${res.status} su ${url}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) throw new Error(`${label}: la risposta non è uno zip`);
  await Bun.write(outPath, buf);
  return outPath;
}

// estrae TUTTO lo zip in dir (ST_Read esige i sidecar accanto all'.shp)
async function explode(zipPath, dir) {
  if (!refresh && existsSync(dir)) return dir;
  mkdirSync(dir, { recursive: true });
  const entries = unzipSync(new Uint8Array(await Bun.file(zipPath).arrayBuffer()));
  for (const [name, data] of Object.entries(entries)) {
    if (name.endsWith("/")) continue;
    const out = dir + name;
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, data);
  }
  return dir;
}

// primo file sotto dir che soddisfa re, ricorsivamente
function find(dir, re) {
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
  return walk(dir);
}

mkdirSync(RAW, { recursive: true });
console.log(`▸ basi territoriali ISTAT ${BT_YEAR} + variabili censuarie ${VAR_YEAR}`);

// --- le variabili: un solo zip per tutta Italia -----------------------------------
const varZip = await grab(
  `${BASE_VAR}Dati_regionali_${VAR_YEAR}.zip`,
  `${RAW}Dati_regionali_${VAR_YEAR}.zip`,
  `variabili ${VAR_YEAR}`,
);
const varDir = await explode(varZip, `${RAW}var${VAR_YEAR}/`);
const tracciato = find(varDir, /TRACCIATO.*\.xlsx$/i);
if (!tracciato) throw new Error(`TRACCIATO non trovato in ${varDir}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// spatial per leggere/riproiettare gli shapefile; excel per leggere gli xlsx senza
// passare da SheetJS (i file regionali arrivano a 38 MB compressi: farli transitare
// dallo heap di JS costa più della lettura); vss perché il CHECKPOINT finale tocca
// tutto il database e le tabelle con indice HNSW non si ricostruiscono senza.
for (const ext of ["spatial", "excel", "vss"]) {
  await con.run(`INSTALL ${ext}`);
  await con.run(`LOAD ${ext}`);
}

// --- il dizionario delle 127 variabili --------------------------------------------
// I primi 11 campi del tracciato sono le chiavi (territorio + id sezione); tutto il
// resto è una variabile censuaria.
const CHIAVI = new Set([
  "CODREG", "REGIONE", "CODPRO", "PROVINCIA", "CODCOM", "COMUNE",
  "PROCOM", "SEZ21_ID", "COM_ASC1", "COM_ASC2", "COM_ASC3",
]);
const tracRows = (
  await con.runAndReadAll(
    `SELECT NOME_CAMPO AS codice, DEFINIZIONE AS descrizione
     FROM read_xlsx('${esc(tracciato)}', all_varchar = true)
     WHERE NOME_CAMPO IS NOT NULL`,
  )
).getRowObjects();
const variabili = tracRows.filter(r => !CHIAVI.has(r.codice));
if (!variabili.length) throw new Error("tracciato letto ma nessuna variabile riconosciuta");
// I codici finiscono in una DDL: se ISTAT introducesse un nome non identificatore,
// meglio fermarsi che costruire SQL con dentro qualcosa di arbitrario.
for (const v of variabili)
  if (!/^[A-Z][A-Z0-9_]*$/.test(v.codice)) throw new Error(`codice variabile inatteso: ${v.codice}`);
console.log(`  variabili censuarie nel tracciato: ${variabili.length}`);

// il prefisso del codice è l'unico raggruppamento che ISTAT dà: lo si rende esplicito
const GRUPPI = {
  P: "popolazione",
  ST: "stranieri",
  IT: "italiani",
  EM: "cittadinanza e luogo di nascita",
  PF: "famiglie",
  A: "abitazioni",
  NA: "automobili",
};
const gruppoDi = c => GRUPPI[c.match(/^[A-Z]+/)[0]] ?? null;

await con.run(`CREATE OR REPLACE TABLE istat_censimento_variabili (
  codice VARCHAR, gruppo VARCHAR, descrizione VARCHAR, anno INTEGER)`);
await con.run(
  `INSERT INTO istat_censimento_variabili VALUES ` +
    variabili
      .map(
        v =>
          `('${esc(v.codice)}', ${gruppoDi(v.codice) ? `'${esc(gruppoDi(v.codice))}'` : "NULL"}, ` +
          `'${esc(v.descrizione ?? "")}', ${Number(VAR_YEAR)})`,
      )
      .join(", "),
);

// --- le due tabelle grandi, create vuote e riempite regione per regione ------------
// Create in DDL esplicita e non con CREATE AS: le 127 colonne devono avere lo stesso
// tipo per tutte e venti le regioni, e l'inferenza per file non lo garantisce.
await con.run(`CREATE OR REPLACE TABLE istat_sezioni (
  sez_id VARCHAR,
  codice_istat VARCHAR,
  comune VARCHAR,
  cod_pro VARCHAR,
  provincia VARCHAR,
  cod_reg VARCHAR,
  regione VARCHAR,
  sezione BIGINT,
  cod_tipo_localita INTEGER,
  tipo_localita VARCHAR,
  popolazione INTEGER,
  famiglie INTEGER,
  abitazioni INTEGER,
  edifici INTEGER,
  superficie_mq DOUBLE,
  lon DOUBLE,
  lat DOUBLE,
  geojson VARCHAR)`);

const colsVar = variabili.map(v => `"${v.codice}" INTEGER`).join(", ");
await con.run(`CREATE OR REPLACE TABLE istat_censimento_sezioni (
  sez_id VARCHAR, codice_istat VARCHAR, ${colsVar})`);

// la proiezione che serializza: NULL se --no-geometry
const geoExpr = noGeom ? "NULL" : `ST_AsGeoJSON(ST_SimplifyPreserveTopology(g.g4, ${TOL}))`;

const attese = only ?? REGIONI;
let nSez = 0;
let nVar = 0;

for (const R of attese) {
  // --- geometrie della regione ---
  const zip = await grab(
    `${BASE_SHP}${R}_${String(BT_YEAR).slice(2)}.zip`,
    `${RAW}${R}_${String(BT_YEAR).slice(2)}.zip`,
    `basi ${R}`,
  );
  const dir = await explode(zip, `${RAW}shp/${R}/`);
  const shp = find(dir, /_WGS84\.shp$/i);
  if (!shp) throw new Error(`shapefile non trovato per ${R} in ${dir}`);

  // --- xlsx delle variabili della stessa regione (il nome contiene la regione:
  //     si risolve per prefisso R<nn>_, mai cablando "Valle d'Aosta") ---
  const xlsx = find(varDir, new RegExp(`^${R}_.*_sezioni\\.xlsx$`, "i"));
  if (!xlsx) throw new Error(`xlsx variabili non trovato per ${R} in ${varDir}`);

  // nomi di comune/provincia/regione: si prendono dall'xlsx, che è dell'annata
  // giusta per queste sezioni. istat_confini_comuni ha l'annata corrente e i
  // comuni fusi dopo il 2021 non ci sarebbero.
  await con.run(`CREATE OR REPLACE TEMP TABLE _nomi AS
    SELECT DISTINCT PROCOM AS codice_istat, COMUNE AS comune,
      PROVINCIA AS provincia, REGIONE AS regione
    FROM read_xlsx('${esc(xlsx)}', all_varchar = true)`);

  await con.run(`CREATE OR REPLACE TEMP TABLE _geo AS
    SELECT * EXCLUDE geom,
      ST_Transform(geom, 'EPSG:32632', 'EPSG:4326', always_xy := true) AS g4
    FROM ST_Read('${esc(shp)}')`);

  await con.run(`INSERT INTO istat_sezioni
    SELECT g.SEZ21_ID::VARCHAR,
      lpad(g.PRO_COM::VARCHAR, 6, '0'),
      n.comune,
      lpad(g.COD_UTS::VARCHAR, 3, '0'),
      n.provincia,
      lpad(g.COD_REG::VARCHAR, 2, '0'),
      n.regione,
      g.SEZ21,
      g.TIPO_LOC,
      CASE g.TIPO_LOC
        WHEN 1 THEN 'centro abitato'
        WHEN 2 THEN 'nucleo abitato'
        WHEN 3 THEN 'località produttiva'
        WHEN 4 THEN 'case sparse'
      END,
      g.POP21, g.FAM21, g.ABI21, g.EDI21,
      round(g.SHAPE_Area, 1),
      ST_X(ST_Centroid(g.g4)), ST_Y(ST_Centroid(g.g4)),
      ${geoExpr}
    FROM _geo g
    LEFT JOIN _nomi n ON n.codice_istat = lpad(g.PRO_COM::VARCHAR, 6, '0')`);

  // le variabili: SEZ21_ID e PROCOM arrivano già come stringhe dall'xlsx
  const selVar = variabili.map(v => `TRY_CAST("${v.codice}" AS INTEGER)`).join(", ");
  await con.run(`INSERT INTO istat_censimento_sezioni
    SELECT SEZ21_ID, PROCOM, ${selVar}
    FROM read_xlsx('${esc(xlsx)}', all_varchar = true)`);

  const [a, b] = (
    await con.runAndReadAll(
      `SELECT (SELECT count(*) FROM istat_sezioni) s, (SELECT count(*) FROM istat_censimento_sezioni) v`,
    )
  ).getRowObjects().map(r => [Number(r.s), Number(r.v)])[0];
  console.log(`  ${R}: ${a - nSez} sezioni, ${b - nVar} con variabili`);
  nSez = a;
  nVar = b;
}

// --- controlli di coerenza ---------------------------------------------------------
// L'aggancio fra le due tabelle è l'unica cosa che può rompersi in silenzio: se un
// giorno SEZ21_ID cambiasse forma da una parte sola, tutto continuerebbe a girare e
// istat_censimento_sezioni diventerebbe una tabella che non si unisce a niente.
const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  (SELECT count(*) FROM istat_sezioni) sezioni,
  (SELECT count(DISTINCT codice_istat) FROM istat_sezioni) comuni,
  (SELECT count(*) FROM istat_sezioni WHERE comune IS NULL) senza_nome,
  (SELECT count(*) FROM istat_sezioni WHERE geojson IS NOT NULL) con_geo,
  (SELECT sum(popolazione) FROM istat_sezioni) pop,
  (SELECT count(*) FROM istat_censimento_sezioni) var_righe,
  (SELECT count(*) FROM istat_censimento_sezioni v
     WHERE NOT EXISTS (SELECT 1 FROM istat_sezioni s WHERE s.sez_id = v.sez_id)) var_orfane`);

const pctVar = Number(st.sezioni) ? Number(st.var_righe) / Number(st.sezioni) : 0;
console.log(`\n  sezioni:            ${st.sezioni} in ${st.comuni} comuni`);
console.log(`  con geometria:      ${st.con_geo}`);
console.log(`  con variabili:      ${st.var_righe} (${(pctVar * 100).toFixed(1)}% — il resto è non residenziale)`);
console.log(`  popolazione ${BT_YEAR}:   ${st.pop}`);
if (Number(st.var_orfane) > 0)
  console.warn(
    `  ⚠ ${st.var_orfane} righe di variabili senza sezione corrispondente: SEZ21_ID non combacia\n` +
      `    più fra geometrie ${BT_YEAR} e variabili ${VAR_YEAR}. Il join è rotto, non è un dettaglio.`,
  );
if (Number(st.senza_nome) > 0)
  console.log(
    `  ${st.senza_nome} sezioni in comuni FUSI fra ${BT_YEAR} e ${VAR_YEAR}: restano senza nome perché\n` +
      `    il loro codice non esiste più nell'edizione ${VAR_YEAR} (né in istat_confini_comuni). Le variabili\n` +
      `    ce le hanno, ma sotto il codice del comune che li ha assorbiti — atteso, non un join rotto.`,
  );

// --- righe di catalogo --------------------------------------------------------------
async function catalog(tbl, source, dataflow, titleIt, titleEn, descIt, descEn, url, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', '${esc(source)}', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      '${esc(url)}', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

const URL_BT = "https://www.istat.it/notizia/basi-territoriali-e-variabili-censuarie/";
const URL_VC = "https://www.istat.it/notizia/dati-per-sezioni-di-censimento/";

await catalog(
  "istat_sezioni",
  "istat.it",
  "istat/basi-territoriali",
  "Sezioni di censimento (ISTAT)",
  "Census enumeration areas (ISTAT)",
  `Le sezioni di censimento delle Basi Territoriali ISTAT ${BT_YEAR}: per ogni sezione il poligono come GeoJSON [lon, lat] (RFC 7946), già semplificato e pronto per Leaflet, il centroide, la superficie in metri quadri, il tipo di località (centro abitato, nucleo abitato, località produttiva, case sparse) e i quattro totali censuari — popolazione, famiglie, abitazioni, edifici. È l'unico livello sotto il comune del warehouse: si aggancia a qualunque dato comunale tramite codice_istat, e a istat_censimento_sezioni tramite sez_id per le 127 variabili censuarie. Circa il 45% delle sezioni è non residenziale e non ha variabili.`,
  `The census enumeration areas of the ISTAT ${BT_YEAR} Territorial Bases: for each area the polygon as GeoJSON [lon, lat] (RFC 7946), already simplified and ready for Leaflet, the centroid, the area in square metres, the locality type (built-up centre, built-up nucleus, productive locality, scattered houses) and the four census totals — population, households, dwellings, buildings. The only sub-municipal level in the warehouse: joins to any municipal figure via codice_istat, and to istat_censimento_sezioni via sez_id for the 127 census variables. About 45% of areas are non-residential and carry no variables.`,
  URL_BT,
  Number(st.sezioni),
);

await catalog(
  "istat_censimento_sezioni",
  "istat.it",
  "istat/variabili-censuarie",
  "Variabili censuarie per sezione di censimento (ISTAT)",
  "Census variables by enumeration area (ISTAT)",
  `Le ${variabili.length} variabili censuarie ${VAR_YEAR} per sezione di censimento, una colonna per variabile: popolazione per sesso e fasce d'età quinquennali, cittadinanza e luogo di nascita, titolo di studio, occupazione, stranieri per area di provenienza, famiglie per numero di componenti, abitazioni occupate e vuote, automobili di proprietà. Il significato di ogni codice è in istat_censimento_variabili; la geometria e il comune sono in istat_sezioni, con cui si unisce per sez_id. Attenzione ai denominatori: la base di P86-P90 (titolo di studio) è P83, la popolazione di 9 anni e più, non P1.`,
  `The ${variabili.length} ${VAR_YEAR} census variables per enumeration area, one column per variable: population by sex and five-year age band, citizenship and place of birth, educational attainment, employment, foreign residents by area of origin, households by size, occupied and vacant dwellings, cars owned. Each code is described in istat_censimento_variabili; geometry and municipality live in istat_sezioni, joined on sez_id. Mind the denominators: the base for P86-P90 (educational attainment) is P83, the population aged 9 and over, not P1.`,
  URL_VC,
  Number(st.var_righe),
);

await catalog(
  "istat_censimento_variabili",
  "istat.it",
  "istat/variabili-censuarie",
  "Dizionario delle variabili censuarie (ISTAT)",
  "Census variable dictionary (ISTAT)",
  `Il tracciato ufficiale ISTAT delle ${variabili.length} variabili censuarie ${VAR_YEAR}: per ogni codice la definizione testuale e il gruppo tematico (popolazione, stranieri, italiani, cittadinanza e luogo di nascita, famiglie, abitazioni, automobili). I codici ISTAT non sono parlanti — P83 è la popolazione di 9 anni e più, ST19 gli stranieri extra-UE — quindi questa tabella è il modo per cercarli per descrizione prima di scrivere una query su istat_censimento_sezioni.`,
  `The official ISTAT record layout of the ${variabili.length} ${VAR_YEAR} census variables: for each code the textual definition and the thematic group (population, foreign residents, Italian citizens, citizenship and place of birth, households, dwellings, cars). ISTAT codes are not self-explanatory — P83 is the population aged 9 and over, ST19 non-EU foreign residents — so this table is how to find them by description before writing a query against istat_censimento_sezioni.`,
  URL_VC,
  variabili.length,
);

console.log(
  `\nistat_sezioni: ${st.sezioni} sezioni (basi ${BT_YEAR}), ` +
    `${st.var_righe} con le ${variabili.length} variabili ${VAR_YEAR}`,
);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT");
con.closeSync();
