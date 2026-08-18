// Ingestione del parco veicolare circolante (ACI — Autoritratto) → tre tabelle
// in DuckDB + righe nel `catalog`:
//   aci_veicoli               una riga per COMUNE: veicoli circolanti per
//                              categoria (autovetture, motocicli, autocarri, …)
//   aci_veicoli_euro          una riga per COMUNE: autovetture per CLASSE EURO,
//                              da Euro 0 a Euro 6E, più le classi 0-3 già sommate
//   aci_veicoli_alimentazione una riga per PROVINCIA: autovetture per
//                              alimentazione (benzina / gasolio / altre —
//                              GPL, metano, ibride, elettriche insieme)
// Granularità DIVERSE perché è quello che la fonte offre davvero, e non si inventa
// un incrocio che non ha: l'alimentazione (e cilindrata, età, kw, …) è tabulata
// SOLO per provincia, e resta lì.
//
// Le classi Euro per comune, invece, ci sono — ma in un ALTRO workbook dello stesso
// zip. `Circolante_Copert_<anno>.xlsx` è il tabulato costruito per il modello
// europeo delle emissioni, e il suo foglio "AV per Comune" si intitola "Autovetture
// distinte per Provincia, Comune e EURO". Per un paio d'anni questo script ha aperto
// solo Parco_veicolare e concluso che il dettaglio comunale non esistesse: esisteva,
// in un file accanto. Il controllo che lo conferma è il totale — 41.777.694
// autovetture da entrambi i workbook, che sono due tabulati diversi della stessa
// fonte.
//
// Fonte (licenza CC BY 4.0, nessuna chiave): ACI — Autoritratto, sezione
// "Parco veicolare":
//   https://aci.gov.it/attivita-e-progetti/studi-e-ricerche/autoritratto/
// Uno ZIP per ANNO (consistenza al 31/12), col link nel nome del file: si
// RISOLVE l'anno più recente dalla pagina indice invece di cablarlo (pattern
// farmacie/scuole). Dentro lo zip, tre file Excel; qui si usa solo
// `Parco_veicolare_<anno>.xlsx`, un workbook a QUARANTASEI fogli pivot
// preaggregati (non righe raw) — si leggono i tre fogli utili per nome; il quarto
// tabulato, le classi Euro, viene da Circolante_Copert.
//
// TRAPPOLE:
//  - il foglio "Comune categoria" è un pivot con CELLE UNITE (Area
//    Geografica/Regione/Provincia compaiono solo sulla prima riga di ogni
//    gruppo): serve un forward-fill riga per riga, non lo fa DuckDB da un
//    export CSV — si fa qui in JS leggendo il workbook con SheetJS;
//  - NESSUN codice ISTAT nel file: comune e provincia sono solo NOME, in
//    MAIUSCOLO. Il nome provincia si mappa alla sigla con una tabella
//    EDITORIALE qui sotto (107 voci, verificate contro
//    istat_confini_province — niente join fuzzy sui nomi provincia, che
//    variano: "REGGIO CALABRIA" vs "Reggio di Calabria", "MASSA CARRARA" vs
//    "Massa-Carrara", "FORLI'-CESENA" con apostrofo per l'accento, …); il
//    comune si aggancia poi per (nome normalizzato, sigla) su
//    voc_istat_cities — sigla scarta le omonimie tra province;
//  - righe da SCARTARE nei pivot: i totali di riepilogo intermedi (comune o
//    provincia = "Totale"), la sezione "NON DEFINITO" (veicoli senza comune
//    di residenza noto, "DATI DI RESIDENZA ESTERI" compresi) e — nei fogli
//    per provincia — la sezione "Riepilogo NAZIONALE" in coda (macroaree,
//    non più province): ci si ferma appena compare;
//  - l'alimentazione è spezzata in TRE fogli distinti per provincia
//    (AVBenz/AVGasolio/AVAltre "Provincia cilindrata"), non un unico
//    incrocio provincia×alimentazione: si somma la colonna "Totale
//    complessivo" di ciascuno;
//  - il dato è la PRA (dove il veicolo è REGISTRATO), non dove risiede il
//    proprietario: i grandi noleggiatori/leasing registrano flotte intere su
//    indirizzi amministrativi concentrati — il comune di Trento risulta così
//    con ~544k autovetture (più di Napoli) a fronte di ~118k abitanti. Non è
//    un bug dell'ETL, è già così nella fonte (stesso disclaimer degli
//    importi in anac_cig: affidabile per riga, non per classifiche ingenue).
//
// Uso:  bun etl/aci-veicoli.mjs [--refresh]
//   --refresh  ignora la cache in raw/aci-veicoli/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import XLSX from "xlsx";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/aci-veicoli/";
const DB = ROOT + "warehouse.duckdb";
const INDEX_PAGE = "https://aci.gov.it/attivita-e-progetti/studi-e-ricerche/autoritratto/";
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

// mappa EDITORIALE nome provincia (ACI, maiuscolo) → sigla automobilistica,
// verificata 1:1 contro istat_confini_province (107 voci)
const PROVINCIA_SIGLA = {
  AGRIGENTO: "AG", ALESSANDRIA: "AL", ANCONA: "AN", AOSTA: "AO", AREZZO: "AR",
  "ASCOLI PICENO": "AP", ASTI: "AT", AVELLINO: "AV", BARI: "BA", "BARLETTA TRANI": "BT",
  BELLUNO: "BL", BENEVENTO: "BN", BERGAMO: "BG", BIELLA: "BI", BOLOGNA: "BO",
  BOLZANO: "BZ", BRESCIA: "BS", BRINDISI: "BR", CAGLIARI: "CA", CALTANISSETTA: "CL",
  CAMPOBASSO: "CB", CASERTA: "CE", CATANIA: "CT", CATANZARO: "CZ", CHIETI: "CH",
  COMO: "CO", COSENZA: "CS", CREMONA: "CR", CROTONE: "KR", CUNEO: "CN", ENNA: "EN",
  FERMO: "FM", FERRARA: "FE", FIRENZE: "FI", FOGGIA: "FG", "FORLI'-CESENA": "FC",
  FROSINONE: "FR", GENOVA: "GE", GORIZIA: "GO", GROSSETO: "GR", IMPERIA: "IM",
  ISERNIA: "IS", "L'AQUILA": "AQ", "LA SPEZIA": "SP", LATINA: "LT", LECCE: "LE",
  LECCO: "LC", LIVORNO: "LI", LODI: "LO", LUCCA: "LU", MACERATA: "MC", MANTOVA: "MN",
  "MASSA CARRARA": "MS", MATERA: "MT", MESSINA: "ME", MILANO: "MI", MODENA: "MO",
  "MONZA BRIANZA": "MB", NAPOLI: "NA", NOVARA: "NO", NUORO: "NU", ORISTANO: "OR",
  PADOVA: "PD", PALERMO: "PA", PARMA: "PR", PAVIA: "PV", PERUGIA: "PG",
  "PESARO E URBINO": "PU", PESCARA: "PE", PIACENZA: "PC", PISA: "PI", PISTOIA: "PT",
  PORDENONE: "PN", POTENZA: "PZ", PRATO: "PO", RAGUSA: "RG", RAVENNA: "RA",
  "REGGIO CALABRIA": "RC", "REGGIO EMILIA": "RE", RIETI: "RI", RIMINI: "RN",
  ROMA: "RM", ROVIGO: "RO", SALERNO: "SA", SASSARI: "SS", SAVONA: "SV", SIENA: "SI",
  SIRACUSA: "SR", SONDRIO: "SO", "SUD SARDEGNA": "SU", TARANTO: "TA", TERAMO: "TE",
  TERNI: "TR", TORINO: "TO", TRAPANI: "TP", TRENTO: "TN", TREVISO: "TV",
  TRIESTE: "TS", UDINE: "UD", VARESE: "VA", VENEZIA: "VE",
  "VERBANO CUSIO OSSOLA": "VB", VERCELLI: "VC", VERONA: "VR", "VIBO VALENTIA": "VV",
  VICENZA: "VI", VITERBO: "VT",
};

// nomi da scartare nei pivot: totali, sezioni non geografiche, celle vuote
const isAggregate = name => {
  const t = String(name ?? "").trim().toUpperCase();
  return t === "" || t === "TOTALE" || t === "NON DEFINITO" || t === "DATI DI RESIDENZA ESTERI";
};

mkdirSync(RAW, { recursive: true });
console.log("▸ parco veicolare circolante (ACI — Autoritratto)");

// --- 1. risolve l'anno più recente dalla pagina indice --------------------------

const idxRes = await fetch(INDEX_PAGE, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
if (!idxRes.ok) throw new Error(`pagina Autoritratto: HTTP ${idxRes.status}`);
const idxHtml = await idxRes.text();
const found = [...idxHtml.matchAll(/(https:\/\/aci\.gov\.it\/+app\/uploads\/\d{4}\/\d{2}\/Autoritratto[-_]?(\d{4})[-_]Parco[-_][Vv]eicolare\.zip)/g)]
  .map(m => ({ url: m[1], anno: Number(m[2]) }));
if (!found.length) throw new Error("nessun link Autoritratto-<anno>-Parco-Veicolare.zip trovato nella pagina indice");
const { url: zipUrl, anno } = found.reduce((a, b) => (b.anno > a.anno ? b : a));
console.log(`  anno più recente: ${anno}`);

// --- 2. scarica lo zip (cache in raw/aci-veicoli/) -------------------------------

const zipPath = `${RAW}parco_veicolare_${anno}.zip`;
if (refresh || !(await Bun.file(zipPath).exists())) {
  const res = await fetch(zipUrl, { headers: HEADERS, signal: AbortSignal.timeout(300_000) });
  if (!res.ok) throw new Error(`${zipUrl}: HTTP ${res.status}`);
  await Bun.write(zipPath, await res.arrayBuffer());
  console.log(`  scaricato ${zipUrl.split("/").pop()}`);
} else {
  console.log("  zip da cache");
}

const zipBuf = new Uint8Array(await Bun.file(zipPath).arrayBuffer());
// Due dei tre workbook dello zip. Parco_veicolare porta le categorie e le
// alimentazioni; Circolante_Copert porta le CLASSI EURO — è il tabulato costruito per
// il modello europeo delle emissioni, e per una volta il dettaglio comunale c'è.
const entries = unzipSync(zipBuf, {
  filter: f => /^(parco_veicolare|circolante_copert)_\d{4}\.xlsx$/i.test(f.name.split("/").pop()),
});
const nomeDi = re => Object.keys(entries).find(n => re.test(n.split("/").pop()));
const entryName = nomeDi(/^parco_veicolare_\d{4}\.xlsx$/i);
if (!entryName) throw new Error(`nessun Parco_veicolare_${anno}.xlsx nello zip`);
const wb = XLSX.read(entries[entryName], { type: "buffer" });

// I nomi dei fogli ACI portano a volte uno spazio in coda ("4 AV per Comune "), che
// un endsWith non perdona: si confronta sul trim.
const sheetEnding = suffix =>
  wb.SheetNames.find(n => n.trim().endsWith(suffix)) ?? wb.SheetNames.find(n => n.endsWith(suffix));
const rowsOf = name => XLSX.utils.sheet_to_json(wb.Sheets[name], { header: 1, defval: null });

// --- 3. foglio "Comune categoria": forward-fill + scarti ------------------------

const comuneSheet = sheetEnding("Comune categoria");
if (!comuneSheet) throw new Error("foglio 'Comune categoria' non trovato nel workbook");
const comuneRows = rowsOf(comuneSheet);
const CAT_COLS = [
  "autobus", "autocarri_trasporto_merci", "autoveicoli_speciali", "autovetture",
  "motocarri_quadricicli_trasporto_merci", "motocicli", "motoveicoli_speciali",
  "rimorchi_semirimorchi_speciali", "rimorchi_semirimorchi_trasporto_merci",
  "trattori_stradali", "non_definito", "totale",
];
let area = null, regione = null, provincia = null;
const comuneOut = [];
let scartiComune = 0;
for (let i = 3; i < comuneRows.length; i++) {
  const r = comuneRows[i];
  if (r[0] != null) area = r[0];
  if (r[1] != null) regione = r[1];
  if (r[2] != null) provincia = r[2];
  const comune = r[3];
  if (isAggregate(comune) || isAggregate(provincia)) {
    scartiComune++;
    continue;
  }
  comuneOut.push({
    area, regione, provincia, comune,
    vals: CAT_COLS.map((_, j) => Number(r[4 + j] ?? 0)),
  });
}
console.log(`  Comune categoria: ${comuneOut.length} comuni (${scartiComune} righe di aggregato/scarto ignorate)`);

// --- 4. i tre fogli "Provincia cilindrata" per l'alimentazione -------------------

function provinceTotals(sheetSuffix) {
  const name = sheetEnding(sheetSuffix);
  if (!name) throw new Error(`foglio '${sheetSuffix}' non trovato nel workbook`);
  const rows = rowsOf(name);
  // la colonna del totale si individua dall'INTESTAZIONE (riga 2, "Totale "):
  // non è sempre l'ultima cella della riga — almeno un foglio ha una colonna
  // vuota in più dopo il totale, che farebbe leggere `null` prendendo r[r.length-1].
  const totalCol = rows[2].findIndex(h => String(h ?? "").trim().startsWith("Totale"));
  if (totalCol < 0) throw new Error(`colonna 'Totale' non trovata nell'intestazione di '${name}'`);
  const out = new Map(); // sigla -> totale
  for (let i = 3; i < rows.length; i++) {
    const r = rows[i];
    if (r[0] === "Riepilogo NAZIONALE") break; // fine della sezione per provincia
    const prov = r[1];
    if (isAggregate(prov)) continue;
    const sigla = PROVINCIA_SIGLA[String(prov).trim().toUpperCase()];
    if (!sigla) {
      console.warn(`  ⚠ provincia sconosciuta in '${name}': "${prov}" — riga scartata`);
      continue;
    }
    out.set(sigla, Number(r[totalCol] ?? 0));
  }
  return out;
}

const benzina = provinceTotals("AVBenz Provincia cilindrata");
const gasolio = provinceTotals("AVGasolio Prov cilindrata");
const altre = provinceTotals("AVAltre Provincia cilindrata");
const sigle = new Set([...benzina.keys(), ...gasolio.keys(), ...altre.keys()]);
console.log(`  alimentazione autovetture: ${sigle.size} province (benzina/gasolio/altre)`);

// --- 4b. classi EURO per comune, dal workbook Circolante_Copert -------------------
//
// Questo file lo zip lo ha sempre avuto e nessuno lo apriva: il foglio "AV per
// Comune" è intitolato "Autovetture distinte per Provincia, Comune e EURO", cioè
// esattamente il dettaglio che la nota in testa a questo script dava per assente —
// ed è vero per Parco_veicolare, dove tutte le alimentazioni si fermano alla
// provincia, ma non per Copert.
//
// Stessa forma pivot del foglio "Comune categoria": REGIONE e PROVINCIA compaiono
// solo sulla prima riga di ogni gruppo, quindi forward-fill; l'intestazione è alla
// terza riga; e le righe di totale vanno scartate con lo stesso `isAggregate`.
const EURO_COLS = [
  "euro_0", "euro_1", "euro_2", "euro_3", "euro_4", "euro_5", "euro_5b",
  "euro_6", "euro_6a", "euro_6b", "euro_6c", "euro_6d", "euro_6e",
  "non_contemplato", "non_definito", "totale",
];
const euroOut = [];
let scartiEuro = 0;
const copertName = nomeDi(/^circolante_copert_\d{4}\.xlsx$/i);
if (!copertName) {
  console.warn(`  ⚠ Circolante_Copert_${anno}.xlsx assente dallo zip: niente classi Euro`);
} else {
  const wbEuro = XLSX.read(entries[copertName], { type: "buffer" });
  const nome = wbEuro.SheetNames.find(n => n.trim().endsWith("AV per Comune"));
  if (!nome) throw new Error(`foglio 'AV per Comune' non trovato in ${copertName}`);
  const righe = XLSX.utils.sheet_to_json(wbEuro.Sheets[nome], { header: 1, defval: null });
  // L'intestazione dice quali classi ci sono, e cambiano: EURO 6E è comparsa da poco
  // e prima o poi arriverà EURO 7. Si legge da lì invece di fidarsi dell'ordine.
  const intestazione = (righe[2] ?? []).map(h => String(h ?? "").trim().toUpperCase());
  const colDi = etichetta => intestazione.indexOf(etichetta);
  const mappa = [
    ["EURO 0", "euro_0"], ["EURO 1", "euro_1"], ["EURO 2", "euro_2"], ["EURO 3", "euro_3"],
    ["EURO 4", "euro_4"], ["EURO 5", "euro_5"], ["EURO 5B", "euro_5b"], ["EURO 6", "euro_6"],
    ["EURO 6A", "euro_6a"], ["EURO 6B", "euro_6b"], ["EURO 6C", "euro_6c"],
    ["EURO 6D", "euro_6d"], ["EURO 6E", "euro_6e"],
    ["NON CONTEMPLATO", "non_contemplato"], ["NON DEFINITO", "non_definito"],
    ["TOTALE", "totale"],
  ];
  const mancanti = mappa.filter(([e]) => colDi(e) === -1).map(([e]) => e);
  if (mancanti.length > 4)
    throw new Error(`intestazione EURO irriconoscibile in ${copertName}: mancano ${mancanti.join(", ")}`);
  let reg = null, prov = null;
  for (let i = 3; i < righe.length; i++) {
    const r = righe[i];
    if (!r) continue;
    if (r[0] != null) reg = r[0];
    if (r[1] != null) prov = r[1];
    const comune = r[2];
    if (comune == null || isAggregate(comune) || isAggregate(prov)) {
      scartiEuro++;
      continue;
    }
    euroOut.push({
      regione: reg, provincia: prov, comune,
      // una classe assente da questa edizione vale 0, non NULL: la somma delle classi
      // deve restare confrontabile col totale che il foglio stesso pubblica
      vals: mappa.map(([e]) => (colDi(e) === -1 ? 0 : Number(r[colDi(e)] ?? 0))),
    });
  }
  console.log(
    `  AV per Comune (Euro): ${euroOut.length} comuni (${scartiEuro} righe di aggregato ignorate)` +
      (mancanti.length ? ` — classi assenti in questa edizione: ${mancanti.join(", ")}` : ""),
  );
}

// --- 5. carica in DuckDB via CSV intermedio (join per nome+sigla) ---------------

const csvEsc = v => (v == null ? "" : `"${String(v).replaceAll('"', '""')}"`);
const comuneCsv =
  ["area", "regione", "provincia", "comune", ...CAT_COLS].join(",") + "\n" +
  comuneOut.map(r => [r.area, r.regione, r.provincia, r.comune, ...r.vals].map(csvEsc).join(",")).join("\n");
await Bun.write(`${RAW}comune_${anno}.csv`, comuneCsv);

const alimCsv =
  "sigla,benzina,gasolio,altre_alimentazioni\n" +
  [...sigle].map(s => [s, benzina.get(s) ?? 0, gasolio.get(s) ?? 0, altre.get(s) ?? 0].join(",")).join("\n");
await Bun.write(`${RAW}alimentazione_${anno}.csv`, alimCsv);

const euroCsv =
  ["regione", "provincia", "comune", ...EURO_COLS].join(",") + "\n" +
  euroOut.map(r => [r.regione, r.provincia, r.comune, ...r.vals].map(csvEsc).join(",")).join("\n");
await Bun.write(`${RAW}euro_${anno}.csv`, euroCsv);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione) non
// si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database anche scrivendo su un'altra tabella.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TABLE aci_veicoli AS
WITH raw AS (
  SELECT * FROM read_csv('${RAW}comune_${anno}.csv', header = true)
),
comuni AS (
  SELECT DISTINCT CODICE_COMUNE AS cod, LABEL_COMUNE_IT AS nome, SIGLA_AUTOMOBILISTICA AS sigla
  FROM voc_istat_cities WHERE DATA_FINE_VALIDITA = '31-12-9999'
)
SELECT
  c.cod AS codice_istat,
  coalesce(c.nome, r.comune) AS comune,
  r.sigla,
  r.provincia,
  r.regione,
  ${anno} AS anno,
  r.autobus, r.autocarri_trasporto_merci, r.autoveicoli_speciali, r.autovetture,
  r.motocarri_quadricicli_trasporto_merci, r.motocicli, r.motoveicoli_speciali,
  r.rimorchi_semirimorchi_speciali, r.rimorchi_semirimorchi_trasporto_merci,
  r.trattori_stradali, r.totale
FROM (
  SELECT *, ${(() => {
    // sigla ricavata dalla provincia via la mappa editoriale, portata a colonna SQL
    const entries = Object.entries(PROVINCIA_SIGLA)
      .map(([k, v]) => `WHEN upper(trim(provincia)) = '${esc(k)}' THEN '${v}'`)
      .join(" ");
    return `CASE ${entries} END`;
  })()} AS sigla
  FROM raw
) r
LEFT JOIN comuni c ON c.sigla = r.sigla AND ${N("c.nome")} = ${N("r.comune")}`);

await con.run(`CREATE OR REPLACE TABLE aci_veicoli_alimentazione AS
SELECT
  a.sigla,
  p.provincia,
  a.benzina, a.gasolio, a.altre_alimentazioni,
  a.benzina + a.gasolio + a.altre_alimentazioni AS totale,
  ${anno} AS anno
FROM read_csv('${RAW}alimentazione_${anno}.csv', header = true) a
LEFT JOIN istat_confini_province p ON p.sigla = a.sigla`);

if (euroOut.length) {
  const siglaDaProvincia = (() => {
    const entries = Object.entries(PROVINCIA_SIGLA)
      .map(([k, v]) => `WHEN upper(trim(provincia)) = '${esc(k)}' THEN '${v}'`)
      .join(" ");
    return `CASE ${entries} END`;
  })();
  await con.run(`CREATE OR REPLACE TABLE aci_veicoli_euro AS
  WITH raw AS (SELECT * FROM read_csv('${RAW}euro_${anno}.csv', header = true)),
  comuni AS (
    SELECT DISTINCT CODICE_COMUNE AS cod, LABEL_COMUNE_IT AS nome, SIGLA_AUTOMOBILISTICA AS sigla
    FROM voc_istat_cities WHERE DATA_FINE_VALIDITA = '31-12-9999'
  )
  SELECT c.cod AS codice_istat,
    coalesce(c.nome, r.comune) AS comune,
    r.sigla, r.provincia, r.regione,
    ${anno} AS anno,
    ${EURO_COLS.map(c => "r." + c).join(", ")},
    -- Le classi fino a Euro 3 sono quelle che ogni zona a traffico limitato nomina per
    -- prime: averle già sommate è la differenza fra una domanda e una formula da
    -- riscrivere ogni volta.
    r.euro_0 + r.euro_1 + r.euro_2 + r.euro_3 AS euro_0_3,
    round(100.0 * (r.euro_0 + r.euro_1 + r.euro_2 + r.euro_3) / nullif(r.totale, 0), 2) AS euro_0_3_pct
  FROM (SELECT *, ${siglaDaProvincia} AS sigla FROM raw) r
  LEFT JOIN comuni c ON c.sigla = r.sigla AND ${N("c.nome")} = ${N("r.comune")}`);

  const se = (
    await con.runAndReadAll(`SELECT count(*) n, count(codice_istat) con_istat,
      sum(totale) av, round(100.0 * sum(euro_0_3) / nullif(sum(totale), 0), 1) pct03
      FROM aci_veicoli_euro`)
  ).getRowObjects()[0];
  console.log(
    `  aci_veicoli_euro: ${se.n} comuni — ${((Number(se.con_istat) / Number(se.n)) * 100).toFixed(1)}% agganciati, ` +
      `${se.av} autovetture, ${se.pct03}% fino a Euro 3`,
  );
}

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat,
    count(DISTINCT codice_istat) AS comuni, sum(autovetture) AS av, sum(totale) AS tot
    FROM aci_veicoli`)
).getRowObjects()[0];
console.log(
  `  aci_veicoli: ${stat.n} comuni — ${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% agganciati ` +
    `al codice ISTAT, ${Number(stat.av).toLocaleString("it-IT")} autovetture, ${Number(stat.tot).toLocaleString("it-IT")} veicoli totali`,
);
const statAlim = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(provincia) AS con_prov FROM aci_veicoli_alimentazione`)
).getRowObjects()[0];
console.log(`  aci_veicoli_alimentazione: ${statAlim.n} province — ${statAlim.con_prov} agganciate a istat_confini_province`);

// --- 6. righe di catalogo ----------------------------------------------------------

async function registra(tbl, source, dataflow, titleIt, titleEn, descIt, descEn, url, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' ORDER BY ordinal_position`,
    )
  ).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', '${esc(source)}', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      '${esc(url)}', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

await registra(
  "aci_veicoli", "aci.gov.it", "aci/autoritratto-parco-veicolare",
  "Parco veicolare circolante per comune (ACI)",
  "Registered vehicle fleet by municipality (ACI)",
  `Veicoli circolanti per comune, anno ${anno} (fonte ACI — Autoritratto, CC BY 4.0): una riga per comune con il numero di veicoli per categoria (autovetture, motocicli, autocarri, autobus, rimorchi, trattori stradali, …) e il totale. Agganciato al codice ISTAT tramite nome comune + sigla provincia. Il dettaglio per alimentazione/età/cilindrata è solo a livello provincia (vedi aci_veicoli_alimentazione); le classi Euro invece ci sono per comune, in aci_veicoli_euro.`,
  `Registered vehicles by municipality, year ${anno} (source ACI — Autoritratto, CC BY 4.0): one row per municipality with vehicle counts by category (cars, motorcycles, trucks, buses, trailers, road tractors, …) and the total. Joined to the ISTAT code via municipality name + province code. Fuel type/age/engine size breakdowns exist only at province level (see aci_veicoli_alimentazione); Euro emission classes, however, are available per municipality in aci_veicoli_euro.`,
  "https://aci.gov.it/attivita-e-progetti/studi-e-ricerche/autoritratto/",
  stat.n,
);
await registra(
  "aci_veicoli_alimentazione", "aci.gov.it", "aci/autoritratto-parco-veicolare",
  "Autovetture per alimentazione e provincia (ACI)",
  "Cars by fuel type and province (ACI)",
  `Autovetture circolanti per provincia e alimentazione, anno ${anno} (fonte ACI — Autoritratto, CC BY 4.0): benzina, gasolio, e "altre alimentazioni" (GPL, metano, ibride ed elettriche insieme — la fonte non le scorpora a livello provinciale). Una riga per provincia, agganciata a istat_confini_province via sigla.`,
  `Registered cars by province and fuel type, year ${anno} (source ACI — Autoritratto, CC BY 4.0): petrol, diesel, and "other fuels" (LPG, methane, hybrid and electric combined — the source does not split them further at province level). One row per province, joined to istat_confini_province via its sigla.`,
  "https://aci.gov.it/attivita-e-progetti/studi-e-ricerche/autoritratto/",
  statAlim.n,
);
if (euroOut.length) {
  const n = (
    await con.runAndReadAll("SELECT count(*) n FROM aci_veicoli_euro")
  ).getRowObjects()[0].n;
  await registra(
    "aci_veicoli_euro", "aci.gov.it", "aci/autoritratto-parco-veicolare",
    "Autovetture per classe Euro e comune (ACI)",
    "Cars by Euro emission class and municipality (ACI)",
    `Autovetture circolanti per comune e classe di emissione Euro, anno ${anno} (fonte ACI — Autoritratto, tabulato Copert, CC BY 4.0): una colonna per classe da Euro 0 a Euro 6E, più i veicoli non contemplati e non definiti, il totale, e già sommate le classi fino a Euro 3 (euro_0_3 e euro_0_3_pct) — che sono quelle che ogni zona a traffico limitato nomina per prime. Una riga per comune, agganciata al codice ISTAT via nome comune + sigla provincia. Il totale coincide con le autovetture di aci_veicoli, che viene da un altro tabulato della stessa fonte.`,
    `Registered cars by municipality and Euro emission class, year ${anno} (source ACI — Autoritratto, Copert tabulation, CC BY 4.0): one column per class from Euro 0 to Euro 6E, plus vehicles not covered and not stated, the total, and the classes up to Euro 3 pre-summed (euro_0_3 and euro_0_3_pct) — the ones every low-emission zone names first. One row per municipality, joined to the ISTAT code via municipality name + province code. The total matches the car count in aci_veicoli, which comes from a different tabulation of the same source.`,
    "https://aci.gov.it/attivita-e-progetti/studi-e-ricerche/autoritratto/",
    Number(n),
  );
}

console.log(`\naci_veicoli: ${stat.n} comuni, aci_veicoli_alimentazione: ${statAlim.n} province (anno ${anno})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
