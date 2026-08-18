// Ingestione dell'ANNCSU — l'Archivio Nazionale dei Numeri Civici e delle Strade
// Urbane (Agenzia delle Entrate + ISTAT) → due tabelle in DuckDB + righe nel
// `catalog`:
//   anncsu_strade  (~1,3M)   una strada per riga: odonimo, località, quanti accessi
//   anncsu_civici  (27,4M)   un numero civico per riga, con LATITUDINE E LONGITUDINE
//   comuni_codici  (~7,9k)   il CROSSWALK fra codice ISTAT e codice catastale
//
// È il geocoding, e la prima volta che questo warehouse può rispondere «dove sta
// questo indirizzo» senza chiedere a nessuno. Finora l'unica georeferenziazione di un
// indirizzo passava da `::geocode`, che interroga Nominatim: un servizio di terze
// parti, una richiesta al secondo, e un indirizzo alla volta. Qui sono venti milioni
// di punti in locale, e una JOIN.
//
// FONTE, ed è cambiata di recente: l'ANNCSU è ora pubblicato come **High Value
// Dataset** ai sensi del Reg. UE 2023/138, quindi obbligatoriamente gratuito e in
// bulk. Fino a poco fa l'accesso era riservato alle amministrazioni.
//   https://www.anncsu.gov.it/it/consultazione-dellarchivio/open-data/
//   stradario     ~14 MB zip  →   56 MB csv
//   indirizzario ~336 MB zip  → 2,21 GB csv
// Aggiornamento mensile; il nome del file dentro lo zip porta la data di creazione.
//
// QUANTO COPRE, che è la cosa da sapere prima di prometterlo a qualcuno:
// **20,7 milioni di civici su 27,4 hanno le coordinate (75,6%), ma 2.402 comuni su
// 7.890 non ne hanno NESSUNA.** Il geocoding funziona in circa cinquemilacinquecento
// comuni, non ovunque, e la differenza non è casuale: dipende da quali Comuni hanno
// caricato la georeferenziazione. Un'app che dà per scontato di trovare un punto
// mostrerà una mappa vuota in un comune su tre — e il modo giusto di scriverla è
// controllare, non sperare.
//
// `metodo` dice COME il Comune ha attribuito la coordinata, ed è un indice di
// accuratezza, non un dettaglio burocratico: 1 e 2 sono rilievo strumentale sul campo
// (sotto e sopra i 5 metri), 3 e 4 derivazione da base dati territoriale (idem), 5
// derivazione tramite il Portale per i Comuni. Meno della metà dei civici (42%) è
// accurata sotto i cinque metri.
//
// IL CROSSWALK È UN REGALO DI QUESTA FONTE. Mezza amministrazione italiana non usa il
// codice ISTAT ma il **codice catastale** (o Belfiore, o «codice comune dell'Agenzia
// delle Entrate»): A013 è Abriola, e con quello sono scritti il patrimonio immobiliare
// del MEF, i codici fiscali e mezzo catasto. Il warehouse non aveva modo di tradurlo —
// né `voc_istat_cities` né `istat_confini_comuni` lo portano — e l'ANNCSU ha ENTRAMBI i
// codici su ogni riga. Costa un DISTINCT, e da qui in avanti qualunque dataset scritto
// in catastale si aggancia al resto senza passare per i nomi.
//
// TRAPPOLE:
//  - le coordinate hanno la **virgola decimale** (`13,9961659`): un TRY_CAST diretto
//    non fallisce, restituisce NULL — venti milioni di punti che spariscono senza un
//    errore;
//  - il CSV è separato da **punto e virgola** e ogni riga finisce con un separatore
//    in più, quindi l'ultima colonna letta è vuota;
//  - il sistema di riferimento è **ETRF2000 (ETRS89), epoca 2008.0**, non WGS84 alla
//    lettera. Alle distanze che interessano una mappa i due coincidono entro pochi
//    centimetri, quindi NON si riproietta: mettere una trasformazione qui
//    aggiungerebbe errore invece di toglierlo;
//  - l'odonimo è ripetuto su ogni civico. Tenerlo costerebbe 283 MB invece di 227 —
//    meno di quanto sembri, perché DuckDB comprime a dizionario — ma sta già in
//    `anncsu_strade`, e una sola copia è una sola verità: il nome si prende con una
//    JOIN su `strada`;
//  - il CSV grande è di 2,2 GB: lo legge DuckDB direttamente da disco. Farlo passare
//    per lo heap di JS non serve e non finirebbe.
//
// Uso:  bun etl/anncsu.mjs [--refresh]

import { mkdirSync, readdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/anncsu/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://anncsu.open.agenziaentrate.gov.it/age-inspire/opendata/anncsu/getds.php";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

mkdirSync(RAW, { recursive: true });
console.log("▸ ANNCSU — strade e numeri civici (Agenzia delle Entrate + ISTAT)");

// Scarica ed estrae uno dei due archivi; ritorna il csv estratto (il nome porta la data).
async function prendi(codice, nome, atteso) {
  const zip = `${RAW}${nome}.zip`;
  if (refresh || !(await Bun.file(zip).exists())) {
    console.log(`  scarico ${nome}…`);
    const res = await fetch(`${BASE}?${codice}`, { headers: HEADERS, signal: AbortSignal.timeout(1_800_000) });
    if (!res.ok) throw new Error(`${nome}: HTTP ${res.status}`);
    const buf = new Uint8Array(await res.arrayBuffer());
    if (buf[0] !== 0x50 || buf[1] !== 0x4b) throw new Error(`${nome}: la risposta non è uno zip`);
    await Bun.write(zip, buf);
  }
  // unzip di sistema e non fflate: il csv dell'indirizzario è di 2,2 GB, e
  // decomprimerlo in memoria per riscriverlo su disco è un giro inutile.
  const p = Bun.spawnSync(["unzip", "-o", "-q", zip, "-d", RAW]);
  if (p.exitCode !== 0) throw new Error(`${nome}: unzip fallito`);
  const csv = readdirSync(RAW).find(f => f.startsWith(atteso) && f.endsWith(".csv"));
  if (!csv) throw new Error(`${nome}: nessun ${atteso}*.csv dopo l'estrazione`);
  return RAW + csv;
}

const csvStrade = await prendi("STRAD_ITA", "stradario", "STRAD_ITA");
const csvCivici = await prendi("INDIR_ITA", "indirizzario", "INDIR_ITA");
// La data di creazione è nel nome del file: è l'annata del dato, e va detta.
const versione = (csvCivici.match(/_(\d{8})\.csv$/) ?? [])[1] ?? null;
console.log(`  edizione: ${versione ? versione.replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3") : "sconosciuta"}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// vss perché il CHECKPOINT finale tocca tutto il database e le tabelle con indice
// HNSW non si ricostruiscono senza l'estensione.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const leggi = f => `read_csv('${esc(f)}', delim = ';', header = true, all_varchar = true, ignore_errors = true)`;

await con.run(`CREATE OR REPLACE TABLE anncsu_strade AS
  SELECT lpad("CODICE_ISTAT", 6, '0') AS codice_istat,
    TRY_CAST("PROGRESSIVO_NAZIONALE" AS INTEGER) AS strada,
    "ODONIMO" AS odonimo,
    nullif("LOCALITA'", '') AS localita,
    TRY_CAST("TOTALE_ACCESSI" AS INTEGER) AS accessi
  FROM ${leggi(csvStrade)}
  WHERE "PROGRESSIVO_NAZIONALE" IS NOT NULL`);

// La virgola decimale è il punto delicato: senza il replace, TRY_CAST non fallisce —
// restituisce NULL, e i venti milioni di punti spariscono in silenzio.
const grado = c => `TRY_CAST(replace("${c}", ',', '.') AS DOUBLE)`;
await con.run(`CREATE OR REPLACE TABLE anncsu_civici AS
  SELECT lpad("CODICE_ISTAT", 6, '0') AS codice_istat,
    TRY_CAST("PROGRESSIVO_NAZIONALE" AS INTEGER) AS strada,
    nullif("CIVICO", '') AS civico,
    nullif("ESPONENTE", '') AS esponente,
    nullif("SPECIFICITA", '') AS specificita,
    ${grado("COORD_Y_COMUNE")} AS lat,
    ${grado("COORD_X_COMUNE")} AS lon,
    TRY_CAST("METODO" AS TINYINT) AS metodo
  FROM ${leggi(csvCivici)}
  WHERE "PROGRESSIVO_NAZIONALE" IS NOT NULL`);

// Il crosswalk, dallo stradario che è cento volte più piccolo dell'indirizzario e
// porta gli stessi due codici.
await con.run(`CREATE OR REPLACE TABLE comuni_codici AS
  SELECT DISTINCT lpad("CODICE_ISTAT", 6, '0') AS codice_istat,
    upper(trim("CODICE_COMUNE")) AS codice_catastale
  FROM ${leggi(csvStrade)}
  WHERE "CODICE_ISTAT" IS NOT NULL AND nullif(trim("CODICE_COMUNE"), '') IS NOT NULL
  ORDER BY 1`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  (SELECT count(*) FROM comuni_codici) codici,
  (SELECT count(*) FROM anncsu_strade) strade,
  (SELECT count(*) FROM anncsu_civici) civici,
  (SELECT count(lat) FROM anncsu_civici) con_coord,
  (SELECT count(DISTINCT codice_istat) FROM anncsu_civici) comuni,
  (SELECT count(*) FROM (SELECT codice_istat FROM anncsu_civici GROUP BY 1 HAVING count(lat) = 0)) comuni_senza_coord,
  (SELECT count(*) FROM anncsu_civici WHERE metodo IN (1, 3)) sotto_5m`);
const pct = Number(st.civici) ? Number(st.con_coord) / Number(st.civici) : 0;
console.log(`  crosswalk istat↔catastale: ${st.codici} comuni`);
console.log(`  strade:            ${st.strade}`);
console.log(`  civici:            ${st.civici}`);
console.log(`  con coordinate:    ${st.con_coord} (${(pct * 100).toFixed(1)}%), di cui ${st.sotto_5m} accurati sotto i 5 m`);
console.log(`  comuni:            ${st.comuni}, ma ${st.comuni_senza_coord} senza NESSUNA coordinata`);

// Il join fra le due tabelle è l'unica cosa che può rompersi in silenzio: un civico la
// cui strada non c'è nello stradario resta senza nome e nessuno se ne accorge.
const orfani = await q(`SELECT count(*) n FROM anncsu_civici c
  WHERE NOT EXISTS (SELECT 1 FROM anncsu_strade s
    WHERE s.codice_istat = c.codice_istat AND s.strada = c.strada)`);
if (Number(orfani.n) > 0)
  console.warn(`  ⚠ ${orfani.n} civici la cui strada non è nello stradario: le due estrazioni non combaciano`);

const agganciati = await q(`SELECT count(DISTINCT c.codice_istat) n FROM anncsu_civici c
  JOIN istat_confini_comuni g ON g.codice_istat = c.codice_istat`);
console.log(`  aggancio ai confini: ${agganciati.n}/${st.comuni} comuni`);

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

const URL_ANNCSU = "https://www.anncsu.gov.it/it/consultazione-dellarchivio/open-data/";

await catalog(
  "anncsu_civici",
  "anncsu.gov.it",
  "anncsu/indirizzario",
  "Numeri civici georeferenziati (ANNCSU)",
  "Geocoded street numbers (ANNCSU)",
  `Tutti i numeri civici d'Italia con latitudine e longitudine, dall'Archivio Nazionale dei Numeri Civici e delle Strade Urbane (Agenzia delle Entrate + ISTAT), pubblicato come High Value Dataset. È il geocoding in locale: un indirizzo diventa un punto senza interrogare nessun servizio esterno. Il nome della strada sta in anncsu_strade e si unisce per (codice_istat, strada). ATTENZIONE alla copertura: ${st.con_coord} civici su ${st.civici} hanno le coordinate, ma ${st.comuni_senza_coord} comuni su ${st.comuni} non ne hanno NESSUNA — il geocoding non funziona ovunque, e va controllato invece che dato per scontato. Il campo metodo è l'accuratezza: 1 e 2 rilievo strumentale sul campo (sotto e sopra i 5 m), 3 e 4 derivazione da base dati territoriale, 5 derivazione tramite il Portale per i Comuni. Le coordinate sono ETRF2000 epoca 2008.0, che per una mappa coincide con WGS84.`,
  `Every street number in Italy with latitude and longitude, from the national street and house-number archive (Revenue Agency + ISTAT), published as a High Value Dataset. This is local geocoding: an address becomes a point without querying any external service. Street names live in anncsu_strade, joined on (codice_istat, strada). MIND the coverage: ${st.con_coord} of ${st.civici} numbers carry coordinates, but ${st.comuni_senza_coord} municipalities out of ${st.comuni} have none at all — geocoding does not work everywhere, and that must be checked rather than assumed. The metodo field is the accuracy: 1 and 2 field survey (under and over 5 m), 3 and 4 derived from territorial databases, 5 derived through the municipal portal. Coordinates are ETRF2000 epoch 2008.0, which for mapping purposes is WGS84.`,
  URL_ANNCSU,
  Number(st.civici),
);

await catalog(
  "anncsu_strade",
  "anncsu.gov.it",
  "anncsu/stradario",
  "Stradario nazionale (ANNCSU)",
  "National street directory (ANNCSU)",
  `Tutte le aree di circolazione d'Italia — vie, piazze, contrade, strade vicinali — certificate dai Comuni: odonimo completo (specie più denominazione), località e quanti accessi vi si affacciano. È il dizionario dei nomi che anncsu_civici non ripete: un civico porta il codice della strada, e il nome si prende da qui con una JOIN su (codice_istat, strada). Serve da solo per l'autocompletamento di un indirizzo, e insieme ai civici per il geocoding.`,
  `Every named thoroughfare in Italy — streets, squares, hamlet roads — as certified by the municipalities: the full odonym (type plus name), the locality and how many accesses face it. It is the name dictionary that anncsu_civici does not repeat: a house number carries the street code, and the name comes from here with a JOIN on (codice_istat, strada). Useful on its own for address autocompletion, and with the numbers for geocoding.`,
  URL_ANNCSU,
  Number(st.strade),
);

await catalog(
  "comuni_codici",
  "anncsu.gov.it",
  "anncsu/stradario",
  "Codice ISTAT ↔ codice catastale dei comuni",
  "ISTAT ↔ cadastral code crosswalk for municipalities",
  `La traduzione fra i due codici con cui l'amministrazione italiana chiama lo stesso comune: il codice ISTAT a sei cifre, che è la chiave di quasi tutto questo warehouse, e il codice catastale a quattro caratteri (detto anche Belfiore, o codice dell'Agenzia delle Entrate) con cui sono scritti il patrimonio immobiliare del MEF, i codici fiscali e il catasto. A013 è Abriola. Ricavato dallo stradario ANNCSU, che porta entrambi i codici su ogni riga: è la sola fonte del warehouse in cui convivono.`,
  `The translation between the two codes Italian public administration uses for the same municipality: the six-digit ISTAT code, which keys almost everything in this warehouse, and the four-character cadastral code (also called Belfiore, or Revenue Agency code) used by the MEF property register, tax codes and the land registry. A013 is Abriola. Derived from the ANNCSU street directory, which carries both codes on every row: the only source in the warehouse where they sit together.`,
  URL_ANNCSU,
  Number(st.codici),
);

console.log(`\nanncsu: ${st.strade} strade, ${st.civici} civici (${st.con_coord} georiferiti)`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
