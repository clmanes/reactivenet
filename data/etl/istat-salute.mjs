// Ingestione degli INDICATORI SANITARI TERRITORIALI di ISTAT (SDMX) → tabelle in
// DuckDB + righe nel `catalog`:
//
//   istat_mortalita_causa    tassi di mortalità per causa, per PROVINCIA
//   istat_mortalita_infantile  mortalità infantile, per provincia
//   istat_speranza_vita      tavole di mortalità: speranza di vita per età
//   istat_spesa_sanitaria    conti della sanità (SHA): spesa per funzione
//   istat_assistenza_base    medici di famiglia e assistenza di base
//   istat_aree               il ponte fra i codici territoriali SDMX e i confini:
//                            senza, questi dati non si disegnano su una mappa
//
// **È l'altra metà degli esiti.** `pne_esiti` misura come vanno le cure dentro un
// ospedale; questi misurano come va la salute di una popolazione — e sono le due
// cose che il resto del warehouse, fatto di dotazioni, non poteva dire.
//
// LA DIFFICOLTÀ, che è il motivo per cui questo ETL esiste separato:
//
//  - **il dataflow della mortalità ha TREDICI dimensioni** — età, sesso, stato
//    civile, titolo di studio, mese, anno di nascita, età del coniuge superstite,
//    anno di matrimonio, cittadinanza, causa — e chiederlo con la chiave aperta
//    (`all`) va in TIMEOUT dopo due minuti con zero byte ricevuti. Non è lentezza:
//    è un prodotto cartesiano che il server non finisce mai di comporre. La chiave
//    va STRETTA, fissando ogni dimensione demografica sul suo codice «totale» e
//    lasciando aperte solo quelle che interessano — il territorio e la causa;
//  - **i codici «totale» non si chiamano allo stesso modo in ogni dimensione**, e
//    indovinarli è stato l'errore della prima versione: nella mortalità il totale
//    è `TOTAL` per l'età, `9` per il sesso, `99` per lo stato civile, ma `YEAR`
//    per il mese di decesso, `ALL` per l'anno di nascita e **`WORLD`** per la
//    cittadinanza. Un `TOTAL` messo dove la codelist non ce l'ha non dà un errore
//    comprensibile: dà **404**, cioè «nessun dato», indistinguibile da un flusso
//    vuoto. Quindi non si indovina: si CHIEDE, con una sonda su una sola area
//    territoriale che costa poco e torna le chiavi vere;
//  - **ISTAT blocca l'indirizzo per uno o due giorni** se le richieste sono troppo
//    fitte, e il blocco non si negozia: si aspetta. Fra un dataset e l'altro c'è
//    quindi una pausa di DUE MINUTI, e non è una cautela decorativa — gli altri
//    ETL SDMX di questo repository (`delitti`, `turismo`, `incidenti-stradali`)
//    fanno UNA richiesta ciascuno proprio per non avvicinarsi a quel limite. Qui
//    ogni dataset ne fa due (la sonda e i dati), quindi la pausa è l'unico modo
//    di restare sotto. Si può accorciare con `--pausa`, ma è la manopola con cui
//    ci si fa bloccare;
//  - un dataset che fallisce **non ferma gli altri**: viene annotato e si prosegue.
//    Ripartire da capo per un timeout vorrebbe dire rifare venti minuti di attesa.
//
// Uso:  bun etl/istat-salute.mjs [--refresh] [--pausa 120]
//   La pausa è in secondi fra un dataset e l'altro (default 120 = due minuti).

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/istat-salute/";
const DB = ROOT + "warehouse.duckdb";
const SDMX = "https://esploradati.istat.it/SDMXWS/rest";

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const pausaSec = (() => {
  const i = args.indexOf("--pausa");
  if (i === -1) return 120;
  // `Number(x) || 120` è il bug dello zero falsy: `--pausa 0` — che serve quando
  // tutto è già in cache e non parte nessuna richiesta — tornava 120.
  const v = Number(args[i + 1]);
  return Number.isFinite(v) && v >= 0 ? v : 120;
})();

// I dataflow, in ordine di valore. `aperte` sono le dimensioni da lasciare libere:
// tutto il resto viene fissato sul codice «totale» della sua codelist.
const FONTI = [
  {
    flusso: "39_494_DF_DCIS_CMORTE1_RES_8",
    tabella: "istat_mortalita_causa",
    aperte: ["REF_AREA", "UNDERLY_DEATH_EUSL", "DATA_TYPE"],
    sonda: "ITC11",
    dal: 2019,
    titolo: ["Tassi di mortalità per causa, per provincia (ISTAT)", "Mortality rates by cause and province (ISTAT)"],
  },
  {
    flusso: "26_295_DF_DCIS_MORTALITA1_1",
    tabella: "istat_speranza_vita",
    aperte: ["REF_AREA", "DATA_TYPE", "AGE"],
    sonda: "ITC11",
    dal: 2019,
    titolo: ["Tavole di mortalità e speranza di vita (ISTAT)", "Life tables and life expectancy (ISTAT)"],
  },
  {
    flusso: "39_701_DF_DCIS_CMORTEINF2_RES_4",
    tabella: "istat_mortalita_infantile",
    aperte: ["REF_AREA", "DATA_TYPE"],
    sonda: "ITC11",
    dal: 2015,
    titolo: ["Mortalità infantile per provincia (ISTAT)", "Infant mortality by province (ISTAT)"],
  },
  {
    flusso: "1_963_DF_DCCN_SHA_B19_1",
    tabella: "istat_spesa_sanitaria",
    aperte: ["REF_AREA", "DATA_TYPE"],
    sonda: "ITC11",
    dal: 2015,
    titolo: ["Spesa sanitaria per funzione — conti SHA (ISTAT)", "Health expenditure by function — SHA accounts (ISTAT)"],
  },
  {
    flusso: "43_236_DF_DCIS_ASSBASE_1",
    tabella: "istat_assistenza_base",
    aperte: ["REF_AREA", "DATA_TYPE"],
    sonda: "ITC11",
    dal: 2015,
    titolo: ["Assistenza di base: medici di famiglia (ISTAT)", "Primary care: family doctors (ISTAT)"],
  },
];

const esc = s => String(s).replaceAll("'", "''");
mkdirSync(RAW, { recursive: true });
console.log(`▸ indicatori sanitari territoriali ISTAT — pausa ${pausaSec}s fra un dataset e l'altro`);

const dormi = ms => new Promise(r => setTimeout(r, ms));

async function chiedi(url, etichetta, timeout = 900_000) {
  const res = await fetch(url, {
    headers: { accept: "application/vnd.sdmx.data+csv;version=1.0.0" },
    signal: AbortSignal.timeout(timeout),
  });
  if (res.status === 429 || res.status === 403)
    throw new Error(
      `ISTAT ha risposto ${res.status}: rate limit. Il blocco dura 1-2 giorni — NON riprovare in ciclo.`,
    );
  if (!res.ok) throw new Error(`${etichetta}: HTTP ${res.status}`);
  return res.text();
}

// La struttura del dataflow: dimensioni in ordine e, per ciascuna, il codice che
// significa «totale». Si scarica una volta sola e si tiene: sono ~10 MB di XML.
async function struttura(flusso) {
  const dest = RAW + flusso + ".dsd.xml";
  let xml;
  if (!refresh && (await Bun.file(dest).exists())) {
    xml = await Bun.file(dest).text();
  } else {
    const res = await fetch(`${SDMX}/dataflow/IT1/${flusso}/1.0?references=all`, {
      signal: AbortSignal.timeout(600_000),
    });
    if (!res.ok) throw new Error(`struttura di ${flusso}: HTTP ${res.status}`);
    xml = await res.text();
    await Bun.write(dest, xml);
  }
  const dsd = xml.match(/<structure:DataStructure[^>]*id="([^"]+)"([\s\S]*?)<\/structure:DataStructure>/);
  if (!dsd) throw new Error(`nessun DSD in ${flusso}`);
  const dims = [];
  // La prima dimensione del blocco e' FREQ e nel XML porta l'id del descrittore:
  // si tiene l'ordine, che e' quello della chiave.
  for (const m of dsd[2].matchAll(
    /<structure:(?:Dimension|TimeDimension)[^>]*id="([^"]+)"[^>]*>([\s\S]*?)<\/structure:(?:Dimension|TimeDimension)>/g,
  )) {
    const id = m[1] === "DimensionDescriptor" ? "FREQ" : m[1];
    const cl = m[2].match(/<Ref[^>]*id="(CL_[^"]+)"/);
    dims.push({ id, codelist: cl ? cl[1] : null });
  }
  return { dims };
}

// I codici che significano «tutti» NON si chiamano allo stesso modo da una
// dimensione all'altra, e indovinarli e' esattamente l'errore che questo ETL ha
// fatto la prima volta: nel flusso della mortalita' il totale e' `TOTAL` per
// l'eta', `9` per il sesso, `99` per lo stato civile, ma `YEAR` per il mese di
// decesso, `ALL` per l'anno di nascita e **`WORLD`** per la cittadinanza. Un
// `TOTAL` messo dove la codelist non ce l'ha non da' un errore comprensibile:
// da' 404, cioe' «nessun dato», indistinguibile da un flusso vuoto.
//
// Quindi non si indovina: si CHIEDE. Una sonda su UNA sola area territoriale
// costa una richiesta piccola e torna le chiavi vere, da cui si legge quale
// codice usa ciascuna dimensione. Fra i codici osservati si preferisce il primo
// di questa scala, che e' l'ordine con cui SDMX scrive i totali.
const TOTALI = ["TOTAL", "ALL", "WORLD", "YEAR", "99", "9", "_T"];

async function codiciDaSonda(flusso, dims, aperte, area, dal) {
  const dest = RAW + flusso + ".sonda.csv";
  let csv;
  if (!refresh && (await Bun.file(dest).exists())) {
    csv = await Bun.file(dest).text();
  } else {
    const posizioni = dims.filter(d => d.id !== "TIME_PERIOD");
    const chiave = posizioni
      .map(d => (d.id === "FREQ" ? "A" : d.id === "REF_AREA" ? area : ""))
      .join(".");
    csv = await chiedi(
      `${SDMX}/data/IT1,${flusso},1.0/${chiave}?startPeriod=${dal}`,
      `sonda di ${flusso}`,
      600_000,
    );
    if (!csv.startsWith("DATAFLOW")) throw new Error("la sonda non e' il CSV SDMX atteso");
    await Bun.write(dest, csv);
  }
  const righe = csv.split(/\r?\n/).filter(Boolean);
  const testa = righe[0].split(",");
  const visti = new Map();
  for (const r of righe.slice(1, 4000)) {
    const c = r.split(",");
    testa.forEach((nome, i) => {
      if (!visti.has(nome)) visti.set(nome, new Set());
      if (c[i]) visti.get(nome).add(c[i]);
    });
  }
  const scelte = new Map();
  for (const d of dims) {
    if (d.id === "TIME_PERIOD" || d.id === "FREQ" || aperte.includes(d.id)) continue;
    const osservati = visti.get(d.id) ?? new Set();
    const scelto = TOTALI.find(t => osservati.has(t));
    if (scelto) scelte.set(d.id, scelto);
  }
  return scelte;
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");
const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

// La corrispondenza fra i codici territoriali SDMX e i nomi delle province, che
// `lib/istat-nuts.mjs` tiene in cache come file: qui diventa una TABELLA, perche'
// senza di essa un documento non puo' agganciare questi dati ai confini — il
// codice `ITC11` non e' il codice ISTAT a sei cifre e non somiglia a niente che
// il resto del warehouse conosca. I codici a CINQUE caratteri sono le province;
// piu' corti sono regioni e ripartizioni, e tenerli insieme alle province in una
// somma conterebbe l'Italia tre volte.
const tsv = ROOT + "raw/istat-geo/itter107.tsv";
if (await Bun.file(tsv).exists()) {
  await con.run(`CREATE OR REPLACE TABLE istat_aree AS
    SELECT a.codice, a.nome,
      -- Il livello si legge dalla FORMA del codice, non dalla sua lunghezza: il
      -- file contiene anche i 9380 comuni a sei cifre e quasi tremila codici di
      -- altri raggruppamenti, e una regola sulla lunghezza li chiamava tutti
      -- «ripartizione». ITC = ripartizione, ITC1 = regione, ITC11 = provincia.
      CASE WHEN a.codice = 'IT' THEN 'nazione'
           WHEN regexp_matches(a.codice, '^IT[A-Z][0-9][0-9]$') THEN 'provincia'
           WHEN regexp_matches(a.codice, '^IT[A-Z][0-9]$') THEN 'regione'
           WHEN regexp_matches(a.codice, '^IT[A-Z]$') THEN 'ripartizione'
           WHEN regexp_matches(a.codice, '^[0-9]{6}$') THEN 'comune'
           ELSE 'altro' END AS livello,
      p.sigla, p.geojson, p.lat, p.lon
    FROM read_csv('${esc(tsv)}', delim = '\t', header = false,
                  columns = {'codice': 'VARCHAR', 'nome': 'VARCHAR'}) a
    LEFT JOIN istat_confini_province p ON p.provincia = a.nome
    WHERE a.codice IS NOT NULL`);
  const ar = await q(`SELECT count(*) righe,
    count(*) FILTER (WHERE livello = 'provincia') province,
    count(*) FILTER (WHERE livello = 'provincia' AND geojson IS NOT NULL) con_confine
    FROM istat_aree`);
  console.log(
    `  istat_aree: ${ar.righe} codici · ${ar.province} province, ${ar.con_confine} con il confine`,
  );
}

const esiti = [];
for (const [i, f] of FONTI.entries()) {
  if (i > 0) {
    console.log(`  … pausa di ${pausaSec}s prima di ${f.flusso} (rate limit ISTAT)`);
    await dormi(pausaSec * 1000);
  }
  const dest = RAW + f.tabella + ".csv";
  try {
    let csv;
    if (!refresh && (await Bun.file(dest).exists())) {
      csv = await Bun.file(dest).text();
      console.log(`  ${f.tabella}: dalla cache`);
    } else {
      const { dims } = await struttura(f.flusso);
      const scelte = await codiciDaSonda(f.flusso, dims, f.aperte, f.sonda, f.dal);
      // La chiave: FREQ=A, le dimensioni aperte vuote, le altre sul codice che la
      // sonda ha visto usare per il totale.
      const chiave = dims
        .filter(d => d.id !== "TIME_PERIOD")
        .map(d => (d.id === "FREQ" ? "A" : f.aperte.includes(d.id) ? "" : (scelte.get(d.id) ?? "")))
        .join(".");
      const posizioni = dims.filter(d => d.id !== "TIME_PERIOD").length;
      console.log(
        `  ${f.tabella}: ${posizioni} dimensioni, ${scelte.size} fissate dalla sonda · ${chiave.slice(0, 70)}`,
      );
      csv = await chiedi(
        `${SDMX}/data/IT1,${f.flusso},1.0/${chiave}?startPeriod=${f.dal}`,
        f.tabella,
      );
      if (!csv.startsWith("DATAFLOW")) throw new Error("la risposta non è il CSV SDMX atteso");
      await Bun.write(dest, csv);
      console.log(`    ${(csv.length / 1e6).toFixed(1)} MB scaricati`);
    }

    await con.run(`CREATE OR REPLACE TABLE ${f.tabella} AS
      SELECT REF_AREA AS ref_area,
        DATA_TYPE AS tipo_dato,
        TIME_PERIOD AS periodo,
        TRY_CAST(OBS_VALUE AS DOUBLE) AS valore,
        * EXCLUDE (DATAFLOW, REF_AREA, DATA_TYPE, TIME_PERIOD, OBS_VALUE)
      FROM read_csv('${esc(dest)}', header = true, all_varchar = true)`);
    const st = await q(`SELECT count(*) righe, count(DISTINCT ref_area) aree,
      min(periodo) dal, max(periodo) al FROM ${f.tabella}`);
    console.log(
      `    ${st.righe} righe · ${st.aree} aree territoriali · ${st.dal}-${st.al}`,
    );
    esiti.push({ ...f, ...st });
  } catch (e) {
    // Un dataset che fallisce non ferma gli altri: ripartire da capo per un
    // timeout vorrebbe dire rifare tutte le pause.
    console.log(`  ✗ ${f.tabella}: ${String(e.message ?? e).slice(0, 120)}`);
  }
}

for (const f of esiti) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${f.tabella}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(c => ({ name: c.column_name, type: c.data_type }));
  const descIt = `${f.titolo[0]}, dal servizio SDMX di ISTAT. \`ref_area\` è il codice territoriale della codelist ISTAT CL_ITTER107 — NON il codice ISTAT a sei cifre del comune: qui sono province e regioni con codici tipo «ITC11», e si agganciano ai confini per NOME della provincia, come fanno gli altri ETL SDMX di questo warehouse. \`tipo_dato\` distingue le misure pubblicate nello stesso flusso e va SEMPRE filtrato prima di sommare: nello stesso dataset convivono conteggi, tassi e quozienti, e sommarli insieme non significa niente. Tutte le dimensioni demografiche (età, sesso, stato civile, titolo di studio, cittadinanza) sono fissate sul TOTALE: questo flusso ne ha tredici, e chiederlo aperto manda il servizio in timeout.`;
  const descEn = `${f.titolo[1]}, from ISTAT's SDMX service. \`ref_area\` is the territorial code from ISTAT's CL_ITTER107 codelist — NOT the six-digit municipality code: these are provinces and regions with codes like "ITC11", matched to boundaries by province NAME, as the other SDMX ETLs in this warehouse do. \`tipo_dato\` separates the measures published in the same flow and must ALWAYS be filtered before summing: counts, rates and ratios live in the same dataset, and adding them together means nothing. Every demographic dimension (age, sex, marital status, education, citizenship) is pinned to the TOTAL: this flow has thirteen of them, and asking it open times the service out.`;
  await con.run(`DELETE FROM catalog WHERE table_name = '${f.tabella}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${f.tabella}', 'esploradati.istat.it', '${esc("istat/" + f.flusso)}',
      '${esc(f.titolo[0])}', '${esc(f.titolo[1])}', '${esc(descIt)}', '${esc(descEn)}',
      'https://esploradati.istat.it/', now(), ${Number(f.righe)}, '${esc(JSON.stringify(cols))}')`);
}

console.log(`\n${esiti.length}/${FONTI.length} dataset ISTAT presi`);
await con.run("CHECKPOINT");
con.closeSync();
