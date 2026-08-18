// Ingestione del PERSONALE e delle APPARECCHIATURE del SSN (Ministero della
// Salute — dati.salute.gov.it, Open Data IODL 2.0) → due tabelle in DuckDB + righe
// nel `catalog`:
//
//   sanita_personale        medici e infermieri per azienda sanitaria, 2020-2022
//   sanita_apparecchiature  TAC, risonanze, acceleratori… per struttura, CON LE
//                           COORDINATE
//
// **Insieme rispondono alla domanda che i posti letto non toccano: con che cosa.**
// Un reparto è fatto di persone e di macchine, e finora il warehouse sapeva solo
// quanti letti aveva. `sanita_personale` conta chi ci lavora — divisi fra medici e
// infermieri, che è la ripartizione da cui si vede se un'azienda è coperta o
// tirata — e `sanita_apparecchiature` dice quante TAC e quante risonanze ci sono e
// DOVE, perché porta latitudine e longitudine: è un layer di punti, disegnabile su
// una mappa senza geocodificare niente.
//
// TRAPPOLE:
//  - **il personale è in XLSX e il foglio non dichiara le proprie dimensioni.**
//    Senza un `<dimension>` DuckDB deduce la larghezza dalla PRIMA riga, che qui è
//    il titolo del modello: una cella sola, quindi una colonna sola, quindi un file
//    che sembra vuoto. Si legge con un `range` esplicito, e la larghezza è scritta
//    qui perché è una proprietà del modello ministeriale, non del file;
//  - **l'intestazione non è la prima riga**: sopra ci sono il titolo del modello e
//    una riga vuota, e la colonna A è vuota per tutta l'altezza. La riga
//    dell'intestazione si CERCA (è quella che contiene «CODICE REGIONE») invece di
//    scriverne il numero, così un'annata che aggiunge una riga di note non rompe
//    l'ETL in silenzio spostando ogni colonna di uno;
//  - **il foglio giusto è il secondo.** `TAB1` è il personale per ruolo giuridico —
//    dirigenza, comparto — mentre `MED E INF` è la ripartizione che interessa a chi
//    guarda un ospedale. Si sceglie per NOME, cercando il foglio che comincia per
//    «MED E INF», perché il nome porta l'anno attaccato e cambia ogni edizione;
//  - **il 2019 è in .xls, non .xlsx**, e l'estensione excel di DuckDB legge solo il
//    secondo. Si parte dal 2020: tre annate invece di quattro, detto qui e nella
//    descrizione di catalogo invece di lasciare che sembri un buco nei dati;
//  - **il codice azienda è unico solo dentro la regione**, come in
//    `sanita-strutture.mjs`: `asl_id` = codice regione + codice azienda è l'unica
//    colonna con cui unire senza fondere aziende di regioni diverse;
//  - **`dotazione_organica` c'è e vale sempre ZERO**, su tutte le 1191 righe: la
//    colonna del modello non è compilata. Una colonna vuota che porta un nome
//    promettente è peggio di una colonna assente, perché qualcuno ci calcolerà
//    sopra la scopertura degli organici e otterrà il 100% ovunque;
//  - i nomi di regione sono **riempiti di spazi a destra** (tracciato a larghezza
//    fissa), e i numeri arrivano come testo: si convertono dopo il `trim`;
//  - le colonne del totale si chiamano `PERS. ANNO RIF. U` e `… D`, non «TOTALE»:
//    il modello conta a parte il tempo pieno e i due scaglioni di part-time, e
//    sommare quelli darebbe lo stesso numero solo finché il tracciato non cambia.
//    Le tre annate hanno intestazioni identiche, il che è la ragione per cui si
//    possono unire — ed è stato VERIFICATO, non supposto.
//
// Uso:  bun etl/sanita-personale.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/sanita-personale/";
const DB = ROOT + "warehouse.duckdb";
const PORTALE = "https://www.dati.salute.gov.it";

// Il modello T1 ha sedici colonne; il foglio non le dichiara e vanno chieste.
const LARGHEZZA = "P";
const RIGHE_MAX = 2000;

const PERSONALE = [
  ["personale-dipendente-delle-asl-aziende-ospedaliere-aziende-ospedaliere-universitarie-e-0", "personale-2020.xlsx"],
  ["personale-dipendente-delle-asl-aziende-ospedaliere-aziende-ospedaliere-universitarie-e-1", "personale-2021.xlsx"],
  ["personale-dipendente-delle-asl-aziende-ospedaliere-aziende-ospedaliere-universitarie-e-2", "personale-2022.xlsx"],
];
const APPARECCHIATURE = ["apparecchiature-sanitarie", "apparecchiature.csv"];

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ personale e apparecchiature del SSN (Ministero della Salute)");

// Come in `sanita-strutture.mjs`: l'URL del file si legge dalla PAGINA del
// dataset, perché contiene un segmento con anno e mese che cambia a ogni
// ripubblicazione.
async function urlDelFile(dataset, estensione) {
  const res = await fetch(`${PORTALE}/it/dataset/${dataset}/`, {
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`pagina del dataset ${dataset}: HTTP ${res.status}`);
  const html = await res.text();
  const m = html.match(new RegExp(`href="([^"]*\\.${estensione})"`, "i"));
  if (!m) throw new Error(`nessun .${estensione} nella pagina del dataset ${dataset}`);
  return m[1].startsWith("http") ? m[1] : PORTALE + decodeURI(m[1]);
}

async function prendi(dataset, nome, estensione) {
  const dest = RAW + nome;
  if (!refresh && (await Bun.file(dest).exists())) return dest;
  const url = await urlDelFile(dataset, estensione);
  const res = await fetch(url, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${nome}: HTTP ${res.status}`);
  await Bun.write(dest, await res.arrayBuffer());
  console.log(`  ${nome} — ${((await Bun.file(dest).size) / 1e6).toFixed(1)} MB`);
  return dest;
}

const fileAnni = [];
for (const [dataset, nome] of PERSONALE)
  fileAnni.push([nome.match(/\d{4}/)[0], await prendi(dataset, nome, "xlsx")]);
const fileApp = await prendi(APPARECCHIATURE[0], APPARECCHIATURE[1], "csv");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");
await con.run("INSTALL excel");
await con.run("LOAD excel");

const righe = async sql => (await con.runAndReadAll(sql)).getRowObjects();

// Il foglio si sceglie per nome — porta l'anno attaccato — e l'intestazione si
// CERCA invece di contarla: un'annata con una riga di note in più sposterebbe
// altrimenti ogni colonna di uno, in silenzio.
//
// I nomi dei fogli si leggono dal `xl/workbook.xml` dentro lo zip, come in
// `consumo-suolo.mjs`: questa build di DuckDB non espone `read_xlsx_sheet_names`.
async function foglioMedEInf(file) {
  const zip = unzipSync(new Uint8Array(await Bun.file(file).arrayBuffer()));
  const workbook = new TextDecoder().decode(zip["xl/workbook.xml"]);
  const nomi = [...workbook.matchAll(/<sheet[^>]*name="([^"]+)"/g)].map(m => m[1]);
  const nome = nomi.find(n => /^MED\s*E\s*INF/i.test(n));
  if (!nome) throw new Error(`nessun foglio «MED E INF» in ${file} (ci sono: ${nomi.join(", ")})`);
  return nome;
}

async function rigaIntestazione(file, foglio) {
  const prime = await righe(
    `SELECT * FROM read_xlsx('${esc(file)}', sheet = '${esc(foglio)}',
       range = 'A1:${LARGHEZZA}12', header = false, all_varchar = true)`,
  );
  const indice = prime.findIndex(r =>
    Object.values(r).some(v => String(v ?? "").trim().toUpperCase() === "CODICE REGIONE"),
  );
  if (indice === -1) throw new Error(`nessuna intestazione in ${file} / ${foglio}`);
  return indice + 1; // le righe del foglio si contano da 1
}

const pezzi = [];
for (const [anno, file] of fileAnni) {
  const foglio = await foglioMedEInf(file);
  const testa = await rigaIntestazione(file, foglio);
  pezzi.push(`SELECT '${anno}' AS anno_file, * FROM read_xlsx('${esc(file)}',
    sheet = '${esc(foglio)}', range = 'A${testa}:${LARGHEZZA}${RIGHE_MAX}',
    header = true, all_varchar = true)`);
  console.log(`  ${anno}: foglio «${foglio}», intestazione alla riga ${testa}`);
}

await con.run(`CREATE OR REPLACE TEMP TABLE _personale AS
  ${pezzi.join(" UNION ALL BY NAME ")}`);

const numero = c => `TRY_CAST(replace(trim(${c}), '.', '') AS BIGINT)`;

await con.run(`CREATE OR REPLACE TABLE sanita_personale AS
  SELECT TRY_CAST(trim("ANNO DI RIFERIMENTO") AS INTEGER) AS anno,
    trim("CODICE REGIONE") || '-' || trim("CODICE AZIENDA") AS asl_id,
    trim("CODICE AZIENDA") AS codice_asl,
    trim("DENOMINAZIONE REGIONE") AS regione,
    trim("PERSONALE MEDICO E INFERMIERISTICO") AS ruolo,
    ${numero('"PERS. ANNO RIF. U"')} AS uomini,
    ${numero('"PERS. ANNO RIF. D"')} AS donne,
    coalesce(${numero('"PERS. ANNO RIF. U"')}, 0) + coalesce(${numero('"PERS. ANNO RIF. D"')}, 0) AS persone,
    ${numero('"DOTAZIONI ORGANICHE"')} AS dotazione_organica
  FROM _personale
  WHERE trim("CODICE REGIONE") IS NOT NULL
    AND TRY_CAST(trim("ANNO DI RIFERIMENTO") AS INTEGER) IS NOT NULL
  ORDER BY anno, asl_id, ruolo`);

// --- apparecchiature ----------------------------------------------------------
await con.run(`CREATE OR REPLACE TABLE sanita_apparecchiature AS
  SELECT trim("codice_regione") AS codice_regione,
    trim("regione") AS regione,
    trim("codice_regione") || '-' || trim("codice_azienda_sanitaria_asl") AS asl_id,
    trim("codice_azienda_sanitaria_asl") AS codice_asl,
    trim("azienda_sanitaria_ASL") AS asl,
    trim("codice_struttura") AS codice_struttura,
    trim("denominazione_struttura") AS struttura,
    trim("indirizzo_struttura") AS indirizzo,
    -- Diciassette strutture portano coordinate fuori dall'Italia: sono errori
    -- della fonte, e un punto sbagliato su una mappa non e' un dettaglio — tira
    -- l'inquadratura dall'altra parte del Paese e nasconde tutti gli altri. Chi
    -- cade fuori dal rettangolo del territorio nazionale resta senza coordinate
    -- invece di essere disegnato dove non e'.
    CASE WHEN TRY_CAST(replace(trim("latitudine"), ',', '.') AS DOUBLE) BETWEEN 35 AND 47.5
         THEN TRY_CAST(replace(trim("latitudine"), ',', '.') AS DOUBLE) END AS lat,
    CASE WHEN TRY_CAST(replace(trim("latitudine"), ',', '.') AS DOUBLE) BETWEEN 35 AND 47.5
          AND TRY_CAST(replace(trim("longitudine"), ',', '.') AS DOUBLE) BETWEEN 6 AND 19
         THEN TRY_CAST(replace(trim("longitudine"), ',', '.') AS DOUBLE) END AS lon,
    trim("tipo_apparecchiatura") AS apparecchiatura,
    trim("descrizione_cnd") AS classificazione,
    ${numero('"num_apparecchiature"')} AS quante,
    ${numero('"num_app_disponibili"')} AS disponibili
  FROM read_csv('${esc(fileApp)}', delim = ';', header = true, all_varchar = true,
                ignore_errors = true)
  WHERE trim("codice_struttura") IS NOT NULL
  ORDER BY regione, struttura, apparecchiatura`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

const pers = await q(`SELECT count(*) righe, count(DISTINCT asl_id) aziende,
  min(anno) dal, max(anno) al,
  sum(persone) FILTER (WHERE ruolo ILIKE '%MEDIC%' AND anno = (SELECT max(anno) FROM sanita_personale)) medici,
  sum(persone) FILTER (WHERE ruolo ILIKE '%INFERMIER%' AND anno = (SELECT max(anno) FROM sanita_personale)) infermieri
  FROM sanita_personale`);
console.log(
  `  personale:      ${pers.righe} righe · ${pers.aziende} aziende · ${pers.dal}-${pers.al} · ` +
    `al ${pers.al}: ${pers.medici} medici e ${pers.infermieri} infermieri`,
);

const app = await q(`SELECT count(*) righe, count(DISTINCT codice_struttura) strutture,
  count(*) FILTER (WHERE lat IS NOT NULL) con_coordinate,
  sum(quante) macchine,
  sum(quante) FILTER (WHERE apparecchiatura = 'RMN') risonanze,
  sum(quante) FILTER (WHERE apparecchiatura = 'TAC') tac,
  count(*) FILTER (WHERE disponibili <> quante) discordi
  FROM sanita_apparecchiature`);
console.log(
  `  apparecchiature: ${app.righe} righe · ${app.strutture} strutture · ` +
    `${app.con_coordinate} con coordinate · ${app.macchine} macchine`,
);
console.log(
  `                   di cui ${app.risonanze} risonanze (RMN) e ${app.tac} TAC · ` +
    `${app.discordi} righe in cui le due colonne del conteggio non coincidono`,
);

// Il controllo indipendente: il personale medico e infermieristico del SSN è noto
// per ordine di grandezza — circa 110.000 medici e 270.000 infermieri dipendenti.
const plausibile =
  Number(pers.medici) > 80_000 &&
  Number(pers.medici) < 150_000 &&
  Number(pers.infermieri) > 200_000 &&
  Number(pers.infermieri) < 350_000;
console.log(
  plausibile
    ? "  ✓ gli ordini di grandezza tornano con quelli noti del SSN"
    : "  ⚠ i totali sono fuori dagli ordini di grandezza attesi: verificare il foglio letto",
);

// Quante aziende del personale si agganciano alla corrispondenza ASL già in casa.
const agganciate = await q(`SELECT count(DISTINCT p.asl_id) totali,
  count(DISTINCT p.asl_id) FILTER (WHERE EXISTS (
    SELECT 1 FROM sanita_asl_comuni a WHERE a.asl_id = p.asl_id)) agganciate
  FROM sanita_personale p WHERE p.anno = (SELECT max(anno) FROM sanita_personale)`);
console.log(
  `  ${agganciate.agganciate} aziende su ${agganciate.totali} si agganciano a sanita_asl_comuni ` +
    `(le altre sono aziende ospedaliere e IRCCS, che non servono un territorio)`,
);

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

await catalog(
  "sanita_personale",
  "dati.salute.gov.it",
  "salute/personale-dipendente-ssn",
  "Medici e infermieri per azienda sanitaria (Ministero della Salute)",
  "Doctors and nurses by health authority (Ministry of Health)",
  `Quanti medici e quanti infermieri dipendenti a tempo indeterminato ha ogni azienda sanitaria italiana, divisi per sesso, dal 2020. Una riga è un'azienda in un anno per un ruolo: \`ruolo\` vale «MEDICI E ODONTOIATRI» o «PERSONALE INFERMIERISTICO», e sommare senza guardarlo mette insieme due professioni. \`dotazione_organica\` sarebbe quanti ne erano previsti, ma nella fonte vale ZERO su tutte le 1191 righe: la colonna esiste e non è compilata, quindi non è la misura di quanto un'azienda sia scoperta e non va usata come tale. La colonna con cui unire è \`asl_id\` (codice regione + codice azienda), non \`codice_asl\` da solo: quello si ripete fra regioni. Si aggancia a sanita_asl_comuni per sapere quali comuni serve un'azienda — ma solo le ASL servono un territorio, mentre le aziende ospedaliere e gli IRCCS in quella tabella non compaiono. ANNATE: dal 2020, perché il 2019 è pubblicato in .xls e l'estensione Excel di DuckDB legge solo .xlsx.`,
  `How many salaried doctors and nurses each Italian health authority has, split by sex, since 2020. A row is one authority in one year for one role: \`ruolo\` is either doctors or nursing staff, and summing without looking at it mixes two professions. \`dotazione_organica\` would be the establishment, but in the source it is ZERO on all 1,191 rows: the column exists and is not filled in, so it does not measure understaffing and must not be used as if it did. The column to join on is \`asl_id\` (region code + authority code), not \`codice_asl\` alone, which repeats across regions. It joins sanita_asl_comuni to learn which municipalities an authority serves — but only local health authorities serve a territory, while hospital trusts and research hospitals do not appear there. VINTAGES: from 2020, because 2019 is published as .xls and DuckDB's Excel extension reads only .xlsx.`,
  "https://www.dati.salute.gov.it/",
  Number(pers.righe),
);

await catalog(
  "sanita_apparecchiature",
  "dati.salute.gov.it",
  "salute/apparecchiature-sanitarie",
  "Apparecchiature sanitarie per struttura, geolocalizzate (Ministero della Salute)",
  "Medical equipment by facility, geolocated (Ministry of Health)",
  `Quante TAC, risonanze magnetiche, acceleratori lineari, mammografi e altre grandi apparecchiature ha ogni struttura sanitaria italiana, e DOVE: la tabella porta latitudine e longitudine, quindi è un layer di punti disegnabile su una mappa senza geocodificare niente. Le due colonne di conteggio arrivano dalla fonte come \`num_apparecchiature\` e \`num_app_disponibili\` e QUI NON SI FINGE DI SAPERE COSA LE DISTINGUE: coincidono in 6438 righe su 6771, e dove differiscono lo fanno in ENTRAMBE le direzioni — 200 volte \`disponibili\` supera \`quante\` — il che esclude la lettura ovvia «installate contro funzionanti». Per contare le macchine si usa \`quante\`; la differenza fra le due non va raccontata come guasti finché la fonte non dice cosa significa. \`apparecchiatura\` è il tipo e \`classificazione\` la voce della Classificazione Nazionale dei Dispositivi Medici. Si unisce alle altre tabelle sanitarie per \`asl_id\` (codice regione + codice azienda), e alle strutture del Ministero per \`codice_struttura\`.`,
  `How many CT scanners, MRI machines, linear accelerators, mammographs and other major equipment each Italian health facility has, and WHERE: the table carries latitude and longitude, so it is a point layer drawable on a map with no geocoding. The two count columns come from the source as \`num_apparecchiature\` and \`num_app_disponibili\` and WHAT SEPARATES THEM IS NOT GUESSED AT HERE: they agree on 6,438 of 6,771 rows, and where they differ they do so in BOTH directions — 200 times \`disponibili\` exceeds \`quante\` — which rules out the obvious reading of "installed versus working". Use \`quante\` to count machines; the gap must not be told as breakdowns until the source says what it means. \`apparecchiatura\` is the type and \`classificazione\` the National Medical Device Classification entry. It joins the other health tables through \`asl_id\` (region code + authority code), and the Ministry's facilities through \`codice_struttura\`.`,
  "https://www.dati.salute.gov.it/",
  Number(app.righe),
);

console.log(`\nsanita_personale: ${pers.righe} · sanita_apparecchiature: ${app.righe}`);
await con.run("CHECKPOINT");
con.closeSync();
