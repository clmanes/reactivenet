// Ingestione delle ultime tre anagrafiche sanitarie con un file scaricabile
// (Ministero della Salute, Open Data IODL 2.0) → tre tabelle in DuckDB + righe nel
// `catalog`:
//
//   reparti              anagrafe E ATTIVITÀ dei reparti di ogni struttura di
//                        ricovero — la grana più fine di tutto il warehouse:
//                        posti letto, dimessi, giornate di degenza, degenza media
//                        e indice di case mix, per SINGOLO reparto
//   parafarmacie         gli esercizi di vicinato che vendono farmaci da banco
//   personale_flessibile chi lavora nel SSN senza un posto fisso
//
// **`reparti` è il pezzo che mancava sotto l'ospedale.** `sanita_strutture` dice
// quanti letti ha un ospedale e `letti_stabilimento` come sono divisi per
// disciplina; questa scende al singolo reparto con la sua attività. È la risposta
// alla domanda che un cittadino fa davvero — «c'è cardiologia, qui?» — e che
// nessuna delle altre tabelle poteva dare.
//
// **`parafarmacie` completa `farmacie`**, e la differenza fra le due va detta:
// una farmacia dispensa i farmaci con ricetta, una parafarmacia solo quelli da
// banco. Sommarle come «punti dove si comprano medicine» è vero per l'aspirina e
// falso per tutto il resto.
//
// **`personale_flessibile` è il complemento di `sanita_personale`**: quello conta
// chi ha un posto a tempo indeterminato, questo chi lavora a termine, in
// formazione lavoro o interinale. Il rapporto fra i due è la misura della
// precarietà di un'azienda, e nessuna delle due tabelle da sola la mostra.
//
// TRAPPOLE:
//  - le tre fonti hanno **tre convenzioni diverse per i nomi di colonna** — minuscolo
//    con underscore nei reparti, minuscolo nelle parafarmacie, MAIUSCOLO CON SPAZI
//    nel personale — quindi le colonne si leggono e si mappano invece di essere
//    scritte a mano;
//  - **i reparti NON hanno il codice comune**, solo il nome e la sigla: si
//    agganciano ai confini come le altre strutture del Ministero, con la stessa
//    normalizzazione. Cercare un codice che non c'è lascia la colonna vuota in
//    silenzio, ed è successo alla prima scrittura di questo ETL;
//  - **il file si chiama «di struttura e di ATTIVITÀ» e la seconda metà è la più
//    preziosa**: dimessi, giornate di degenza, degenza media e indice di case mix
//    per singolo reparto. Prendere solo l'anagrafe — come faceva la prima versione
//    di questo ETL — butta via il motivo per cui il dataset esiste;
//  - i file sono in **ISO-8859-1** e i campi riempiti di spazi, come tutto il
//    portale;
//  - **una parafarmacia non è una farmacia** e le due tabelle non vanno unite in
//    un conteggio unico senza dirlo (vedi sopra).
//
// Uso:  bun etl/sanita-anagrafiche.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/sanita-anagrafiche/";
const DB = ROOT + "warehouse.duckdb";
const PORTALE = "https://www.dati.salute.gov.it";

const FONTI = {
  reparti: "dati-di-struttura-e-di-attivita-dei-reparti-presenti-ciascuna-struttura-di-ricovero",
  parafarmacie: "parafarmacie",
  flessibile: [
    "personale-con-rapporto-di-lavoro-flessibile-delle-asl-aziende-ospedaliere-aziende",
    "personale-con-rapporto-di-lavoro-flessibile-delle-asl-aziende-ospedaliere-aziende-0",
    "personale-con-rapporto-di-lavoro-flessibile-delle-asl-aziende-ospedaliere-aziende-1",
    "personale-con-rapporto-di-lavoro-flessibile-delle-asl-aziende-ospedaliere-aziende-2",
  ],
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const norm = s =>
  String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]/g, "");

mkdirSync(RAW, { recursive: true });
console.log("▸ anagrafiche sanitarie: reparti, parafarmacie, personale flessibile");

async function prendi(dataset, nome) {
  const dest = RAW + nome;
  if (!refresh && (await Bun.file(dest).exists())) return dest;
  const html = await (
    await fetch(`${PORTALE}/it/dataset/${dataset}/`, { signal: AbortSignal.timeout(90_000) })
  ).text();
  const m = html.match(/href="([^"]*\.csv)"/i);
  if (!m) throw new Error(`nessun CSV in ${dataset}`);
  const url = m[1].startsWith("http") ? m[1] : PORTALE + decodeURI(m[1]);
  const res = await fetch(url, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${nome}: HTTP ${res.status}`);
  const grezzo = dest + ".latin1";
  await Bun.write(grezzo, await res.arrayBuffer());
  const conv = Bun.spawnSync(["iconv", "-f", "ISO-8859-1", "-t", "UTF-8", grezzo]);
  if (conv.exitCode !== 0) throw new Error(`iconv su ${nome}`);
  await Bun.write(dest, conv.stdout);
  return dest;
}

const fReparti = await prendi(FONTI.reparti, "reparti.csv");
const fPara = await prendi(FONTI.parafarmacie, "parafarmacie.csv");
const fFless = [];
for (const d of FONTI.flessibile) {
  try {
    fFless.push(await prendi(d, `flessibile-${fFless.length}.csv`));
  } catch (e) {
    console.log(`  ⚠ ${d.slice(-2)}: ${String(e.message ?? e).slice(0, 50)}`);
  }
}
console.log(`  reparti, parafarmacie e ${fFless.length} annate di personale flessibile`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const leggi = f =>
  `read_csv('${esc(f)}', delim = ';', header = true, all_varchar = true, ignore_errors = true)`;
const numero = c => `TRY_CAST(replace(trim(${c}), '.', '') AS BIGINT)`;
const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

// Le tre fonti hanno tre convenzioni diverse per i nomi: si leggono e si mappano.
const colonneDi = async f =>
  (await con.runAndReadAll(`DESCRIBE SELECT * FROM ${leggi(f)}`))
    .getRowObjects()
    .map(r => r.column_name);
const come = (colonne, ...alternative) => {
  const chiavi = alternative.map(norm);
  const t = colonne.find(c => chiavi.includes(norm(c)));
  return t ? `"${t}"` : null;
};

// ------------------------------------------------------------------- reparti
const cR = await colonneDi(fReparti);
const rep = (nome, ...alt) => {
  const c = come(cR, ...alt);
  return c ? `trim(${c}) AS ${nome}` : `CAST(NULL AS VARCHAR) AS ${nome}`;
};
// Il file NON porta il codice comune, solo il nome e la sigla: si aggancia ai
// confini come le altre strutture del Ministero, con la stessa normalizzazione.
const APOSTROFO = String.fromCharCode(39);
const nomeCom = col =>
  `upper(strip_accents(replace(replace(${col}, '${APOSTROFO}${APOSTROFO}', ''), ' ', '')))`;
const misR = (nome, ...alt) => {
  const c = come(cR, ...alt);
  return c ? `${numero(c)} AS ${nome}` : `CAST(NULL AS BIGINT) AS ${nome}`;
};
const decR = (nome, ...alt) => {
  const c = come(cR, ...alt);
  return c
    ? `TRY_CAST(replace(trim(${c}), ',', '.') AS DOUBLE) AS ${nome}`
    : `CAST(NULL AS DOUBLE) AS ${nome}`;
};
await con.run(`CREATE OR REPLACE TABLE reparti AS
  SELECT r.anno, r.asl_id, r.regione, r.asl, r.codice_struttura, r.struttura,
    r.indirizzo, r.tipo_struttura, r.disciplina,
    g.codice_istat,
    coalesce(g.comune, r.comune_dichiarato) AS comune,
    r.sigla, g.provincia,
    r.letti_ordinari, r.letti_day_hospital, r.letti_day_surgery, r.letti_utilizzati,
    r.dimessi, r.giornate_degenza, r.giornate_disponibili, r.degenza_media, r.icm
  FROM (
    SELECT ${rep("anno", "anno")},
      trim(${come(cR, "codice_regione")}) || '-' || trim(${come(cR, "codice_asl")}) AS asl_id,
      ${rep("regione", "regione")},
      ${rep("asl", "asl")},
      ${rep("codice_struttura", "codice_struttura")},
      ${rep("struttura", "struttura")},
      ${rep("indirizzo", "indirizzo")},
      ${rep("tipo_struttura", "tipo_struttura")},
      ${rep("disciplina", "disciplina")},
      ${rep("comune_dichiarato", "comune")},
      ${rep("sigla", "sigla_provincia", "sigla")},
      ${misR("letti_ordinari", "posti_letto_degenza_ordinaria")},
      ${misR("letti_day_hospital", "posti_letto_day_hospital")},
      ${misR("letti_day_surgery", "posti_letto_day_surgery")},
      ${misR("letti_utilizzati", "posti_letto_utilizzati")},
      ${misR("dimessi", "num_dimessi")},
      ${misR("giornate_degenza", "giornate_degenza")},
      ${misR("giornate_disponibili", "giornate_disponibili")},
      ${decR("degenza_media", "degenza_media_ordinaria")},
      ${decR("icm", "icm")}
    FROM ${leggi(fReparti)}
    WHERE trim(${come(cR, "codice_struttura")}) IS NOT NULL
  ) r
  LEFT JOIN istat_confini_comuni g
    ON g.sigla = r.sigla
   AND ${nomeCom("split_part(g.comune, '/', 1)")} = ${nomeCom("r.comune_dichiarato")}`);

// -------------------------------------------------------------- parafarmacie
const cP = await colonneDi(fPara);
const par = (nome, ...alt) => {
  const c = come(cP, ...alt);
  return c ? `trim(${c}) AS ${nome}` : `CAST(NULL AS VARCHAR) AS ${nome}`;
};
await con.run(`CREATE OR REPLACE TABLE parafarmacie AS
  SELECT ${par("codice", "codice_identificativo_sito")},
    ${par("nome", "sito_logistico")},
    ${par("indirizzo", "indirizzo")},
    ${par("cap", "cap")},
    ${par("codice_istat", "codice_comune")},
    ${par("comune", "comune")},
    ${par("sigla", "sigla_provincia")},
    ${par("regione", "regione")}
  FROM ${leggi(fPara)}
  WHERE trim(${come(cP, "codice_comune")}) IS NOT NULL`);

// ------------------------------------------------------- personale flessibile
if (fFless.length) {
  const pezzi = [];
  for (const f of fFless) {
    const c = await colonneDi(f);
    const reg = come(c, "CODICE REGIONE");
    const az = come(c, "CODICE AZIENDA");
    if (!reg || !az) continue;
    const m = (nome, ...alt) => {
      const col = come(c, ...alt);
      return col ? `${numero(col)} AS ${nome}` : `CAST(NULL AS BIGINT) AS ${nome}`;
    };
    pezzi.push(`SELECT TRY_CAST(trim(${come(c, "ANNO DI RIFERIMENTO", "ANNO")}) AS INTEGER) AS anno,
      trim(${reg}) || '-' || trim(${az}) AS asl_id,
      trim(${come(c, "DENOMINAZIONE REGIONE", "DESCRIZIONE REGIONE")}) AS regione,
      trim(${come(c, "DESCRIZIONE CATEGORIA", "CATEGORIA")}) AS categoria,
      ${m("tempo_determinato_u", "TEMPO DETERMINATO U")},
      ${m("tempo_determinato_d", "TEMPO DETERMINATO D")},
      ${m("formazione_lavoro_u", "FORMAZIONE LAVORO U")},
      ${m("formazione_lavoro_d", "FORMAZIONE LAVORO D")},
      ${m("interinale_u", "INTERINALE U")},
      ${m("interinale_d", "INTERINALE D")},
      ${m("lsu_u", "LSU U")},
      ${m("lsu_d", "LSU D")}
    FROM ${leggi(f)} WHERE trim(${reg}) IS NOT NULL`);
  }
  if (pezzi.length)
    await con.run(`CREATE OR REPLACE TABLE personale_flessibile AS
      -- Il modello conta QUATTRO forme di rapporto flessibile e non due: lasciare
      -- fuori interinale e LSU dimezzava il totale, e un totale dimezzato di
      -- precari e' esattamente il numero che qualcuno userebbe per dire che il
      -- problema e' piccolo.
      SELECT *, coalesce(tempo_determinato_u, 0) + coalesce(tempo_determinato_d, 0)
             + coalesce(formazione_lavoro_u, 0) + coalesce(formazione_lavoro_d, 0)
             + coalesce(interinale_u, 0) + coalesce(interinale_d, 0)
             + coalesce(lsu_u, 0) + coalesce(lsu_d, 0) AS persone
      FROM (${pezzi.join(" UNION ALL BY NAME ")})
      WHERE anno IS NOT NULL ORDER BY anno, asl_id`);
}

const r = await q(`SELECT count(*) righe, count(DISTINCT codice_struttura) strutture,
  count(DISTINCT codice_istat) comuni, count(DISTINCT disciplina) discipline,
  sum(letti_utilizzati) letti, sum(dimessi) dimessi FROM reparti`);
console.log(
  `  reparti:             ${r.righe} in ${r.strutture} strutture · ${r.comuni} comuni · ` +
    `${r.discipline} discipline`,
);
console.log(`                       ${r.letti} letti utilizzati, ${r.dimessi} dimessi`);

const p = await q(`SELECT count(*) righe, count(DISTINCT codice_istat) comuni FROM parafarmacie`);
const f = await q(`SELECT count(*) righe FROM farmacie`);
console.log(
  `  parafarmacie:        ${p.righe} in ${p.comuni} comuni (le farmacie sono ${f.righe}: ` +
    `non sono la stessa cosa e non vanno sommate)`,
);

const fl = await q(`SELECT count(*) righe, count(DISTINCT asl_id) aziende,
  min(anno) dal, max(anno) al, sum(persone) FILTER (WHERE anno = (SELECT max(anno) FROM personale_flessibile)) persone
  FROM personale_flessibile`).catch(() => null);
if (fl)
  console.log(
    `  personale flessibile: ${fl.righe} righe · ${fl.aziende} aziende · ${fl.dal}-${fl.al} · ` +
      `${fl.persone} persone nell'ultimo anno`,
  );

async function catalog(tbl, titleIt, titleEn, descIt, descEn, n) {
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
    VALUES ('${tbl}', 'dati.salute.gov.it', 'salute/anagrafiche',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      'https://www.dati.salute.gov.it/', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

await catalog(
  "reparti",
  "Reparti delle strutture di ricovero (Ministero della Salute)",
  "Hospital wards (Ministry of Health)",
  `L'anagrafe dei reparti di ogni struttura di ricovero pubblica ed equiparata: la grana più fine della sanità in questo warehouse. \`sanita_strutture\` dice quanti letti ha un ospedale e \`letti_stabilimento\` come sono divisi per disciplina; qui c'è il singolo reparto. È la tabella che risponde alla domanda che un cittadino fa davvero — «c'è cardiologia, qui?» — e che nessuna delle altre poteva dare. Porta il \`codice_istat\` del comune ma NON le coordinate: la collocazione è al comune, e non è stata inventata nessuna geocodifica. Si unisce al resto per \`asl_id\` e per \`codice_struttura\`.`,
  `The register of wards in every public and equivalent hospital: the finest granularity of health care in this warehouse. \`sanita_strutture\` says how many beds a hospital has and \`letti_stabilimento\` how they split by discipline; here is the individual ward. It is the table that answers what a citizen actually asks — "is there a cardiology ward here?" — which none of the others could. It carries the municipality \`codice_istat\` but NOT coordinates: placement is at municipality level, and no geocoding was invented. It joins the rest by \`asl_id\` and \`codice_struttura\`.`,
  Number(r.righe),
);

await catalog(
  "parafarmacie",
  "Parafarmacie (Ministero della Salute)",
  "Non-pharmacy medicine retailers (Ministry of Health)",
  `Gli esercizi di vicinato autorizzati a vendere medicinali senza obbligo di ricetta, con indirizzo e \`codice_istat\` del comune. VA TENUTA DISTINTA DA \`farmacie\`, e le due non vanno sommate in un unico conteggio di «punti dove si comprano medicine»: una farmacia dispensa anche i farmaci con ricetta e fa servizio notturno, una parafarmacia no. Sommarle è vero per l'aspirina e falso per tutto il resto.`,
  `Retail outlets authorised to sell over-the-counter medicines, with address and municipality \`codice_istat\`. KEEP IT SEPARATE FROM \`farmacie\`, and do not add the two into a single count of "places to buy medicine": a pharmacy also dispenses prescription drugs and runs night duty, a para-pharmacy does not. Adding them is true for aspirin and false for everything else.`,
  Number(p.righe),
);

if (fl)
  await catalog(
    "personale_flessibile",
    "Personale del SSN a rapporto flessibile (Ministero della Salute)",
    "NHS staff on flexible contracts (Ministry of Health)",
    `Chi lavora nel Servizio Sanitario senza un posto a tempo indeterminato: contratti a termine, formazione lavoro, interinale, per azienda e categoria. È il COMPLEMENTO di \`sanita_personale\`, che conta solo i dipendenti stabili, e il rapporto fra i due è la misura della precarietà di un'azienda — che nessuna delle due tabelle da sola mostra. Si unisce per \`asl_id\`.`,
    `Who works in the health service without a permanent post: fixed-term, work-training and agency contracts, by authority and category. It is the COMPLEMENT of \`sanita_personale\`, which counts only permanent staff, and the ratio between the two measures an authority's reliance on precarious work — which neither table shows alone. It joins by \`asl_id\`.`,
    Number(fl.righe),
  );

console.log(`\nreparti: ${r.righe} · parafarmacie: ${p.righe}${fl ? ` · personale_flessibile: ${fl.righe}` : ""}`);
await con.run("CHECKPOINT");
con.closeSync();
