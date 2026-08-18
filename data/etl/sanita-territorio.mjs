// Ingestione della SANITÀ TERRITORIALE — quella fuori dall'ospedale (Ministero
// della Salute — dati.salute.gov.it, Open Data IODL 2.0) → tre tabelle in DuckDB
// + righe nel `catalog`:
//
//   consultori          i consultori familiari, CON IL CODICE ISTAT DEL COMUNE
//   salute_mentale      utenti trattati dai Dipartimenti di Salute Mentale,
//                       per età e sesso, 2022-2024
//   dipendenze          utenti in carico ai SerD per sostanza, 2020-2025
//
// **È la sanità che un cittadino incontra senza essere ricoverato**, e finora nel
// warehouse non c'era niente di tutto questo: gli ospedali, i posti letto e gli
// esiti descrivono che cosa succede DENTRO una struttura, mentre un consultorio,
// un centro di salute mentale e un SerD sono i posti dove si va senza che sia
// successo niente di acuto. Sono anche i tre servizi di cui si parla di più e su
// cui si trovano meno numeri.
//
// I consultori sono l'unico dei tre a scendere al COMUNE: gli altri due si
// fermano all'azienda sanitaria, che è il livello a cui quei servizi sono
// organizzati. Non è una mancanza da colmare, è come funziona il servizio.
//
// TRAPPOLE:
//  - **le tre fonti hanno tre modi diversi di scrivere le stesse cose.** «Codice
//    Regione» / «Codice regione», «Codice ASL» / «Codice Asl», e la denominazione
//    dell'azienda a volte con lo spazio finale nel nome della colonna — e cambia
//    anche fra ANNATE della stessa fonte: il 2024 scrive «Descrizione Regione » e
//    il 2022 «Descrizione Regione». Con `UNION ALL BY NAME` diventano due colonne
//    distinte e qualunque nome si scelga fallisce per metà degli anni. Le colonne
//    di ogni file si LEGGONO (`DESCRIBE`) e si mappano su un nome canonico
//    ignorando spazi e maiuscole, invece di fidarsi di come sono scritte;
//  - **il codice ASL è unico solo dentro la regione**, come in tutta la sanità di
//    questo warehouse: la chiave è `asl_id` = codice regione + codice azienda;
//  - i file sono in **ISO-8859-1** e vanno convertiti, e i campi di testo sono
//    riempiti di spazi a destra;
//  - **nel file dei SerD la colonna degli utenti è spesso vuota**: sono le celle
//    che il Ministero non pubblica perché il numero è troppo piccolo per non
//    identificare le persone. Restano NULL e NON diventano zero: uno zero
//    direbbe «nessun utente», che è una cosa diversa e più grave da dire;
//  - i consultori hanno indirizzo e CAP ma **non le coordinate**: si collocano al
//    comune, non sulla mappa, e fingere il contrario richiederebbe una
//    geocodifica che qui non si fa di nascosto.
//
// Uso:  bun etl/sanita-territorio.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/sanita-territorio/";
const DB = ROOT + "warehouse.duckdb";
const PORTALE = "https://www.dati.salute.gov.it";

const CONSULTORI = ["consultori-familiari-anno-2022", "consultori.csv"];
const MENTALE = [2022, 2023, 2024].map(a => [
  `prevalenza-degli-utenti-trattati-nei-dsm-sesso-e-classi-di-eta-${a}`,
  `mentale-${a}.csv`,
]);
const SERD = [2020, 2021, 2022, 2023, 2024, 2025].map(a => [
  `utenti-carico-secondo-la-sostanza-dabuso-primaria-anno-${a}`,
  `serd-${a}.csv`,
]);

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ sanità territoriale: consultori, salute mentale, dipendenze");

async function urlDelCsv(dataset) {
  const res = await fetch(`${PORTALE}/it/dataset/${dataset}/`, {
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`pagina ${dataset}: HTTP ${res.status}`);
  const html = await res.text();
  const m = html.match(/href="([^"]*\.csv)"/i);
  if (!m) throw new Error(`nessun CSV in ${dataset}`);
  return m[1].startsWith("http") ? m[1] : PORTALE + m[1];
}

async function prendi(dataset, nome) {
  const dest = RAW + nome;
  if (!refresh && (await Bun.file(dest).exists())) return dest;
  const url = await urlDelCsv(dataset);
  const res = await fetch(url, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${nome}: HTTP ${res.status}`);
  const grezzo = RAW + nome + ".latin1";
  await Bun.write(grezzo, await res.arrayBuffer());
  const conv = Bun.spawnSync(["iconv", "-f", "ISO-8859-1", "-t", "UTF-8", grezzo]);
  if (conv.exitCode !== 0) throw new Error(`iconv su ${nome}: ${conv.stderr}`);
  await Bun.write(dest, conv.stdout);
  return dest;
}

const fConsultori = await prendi(...CONSULTORI);
const fMentale = [];
for (const [d, n] of MENTALE) fMentale.push([n.match(/\d{4}/)[0], await prendi(d, n)]);
const fSerd = [];
for (const [d, n] of SERD) {
  try {
    fSerd.push([n.match(/\d{4}/)[0], await prendi(d, n)]);
  } catch (e) {
    console.log(`  ⚠ ${n}: ${String(e.message ?? e).slice(0, 80)}`);
  }
}
console.log(`  consultori: 1 file · salute mentale: ${fMentale.length} · SerD: ${fSerd.length}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const leggi = f =>
  `read_csv('${esc(f)}', delim = ';', header = true, all_varchar = true, ignore_errors = true)`;
const numero = c => `TRY_CAST(replace(trim(${c}), '.', '') AS BIGINT)`;
const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

// ------------------------------------------------------------------ consultori
await con.run(`CREATE OR REPLACE TABLE consultori AS
  SELECT TRY_CAST(trim("Anno") AS INTEGER) AS anno,
    trim("Codice Regione") || '-' || trim("Codice Azienda") AS asl_id,
    trim("Descrizione Regione") AS regione,
    trim("Denominazione Azienda") AS asl,
    trim("Codice struttura") AS codice_struttura,
    trim("Denominazione struttura") AS struttura,
    trim("Tipo struttura") AS tipo,
    trim("Tipo rapporto con il S.S.N.") AS gestione,
    trim("Indirizzo") AS indirizzo,
    trim("CAP") AS cap,
    trim("Codice Comune") AS codice_istat,
    trim("Sigla provincia") AS sigla
  FROM ${leggi(fConsultori)}
  WHERE trim("Codice Comune") IS NOT NULL
  ORDER BY regione, codice_istat, struttura`);

// -------------------------------------------------------------- salute mentale
//
// Le intestazioni cambiano fra un'annata e l'altra per uno SPAZIO: il 2024 scrive
// «Descrizione Regione » e il 2022 «Descrizione Regione». Con `UNION ALL BY NAME`
// diventano due colonne diverse, e qualunque nome si scelga fallisce per meta'
// degli anni. Quindi le colonne di ogni file si leggono davvero e si mappano su
// un nome canonico, invece di fidarsi di come sono scritte.
const colonneDi = async file => {
  const righe = (await con.runAndReadAll(`DESCRIBE SELECT * FROM ${leggi(file)}`)).getRowObjects();
  return righe.map(r => r.column_name);
};
// Trova la colonna il cui nome, ignorati spazi e maiuscole, e' uno di quelli
// cercati. Le alternative servono perche' la stessa cosa cambia nome fra annate
// della stessa fonte: «Regione» diventa «Descrizione Regione» e viceversa.
const come = (colonne, ...voluti) => {
  const chiavi = voluti.map(v => v.toLowerCase().replace(/\s+/g, ""));
  const trovata = colonne.find(c =>
    chiavi.includes(String(c).toLowerCase().replace(/\s+/g, "")),
  );
  if (!trovata)
    throw new Error(`nessuna colonna «${voluti.join("» o «")}» fra: ${colonne.join(", ")}`);
  return `"${trovata}"`;
};

const pezziMentale = [];
for (const [, f] of fMentale) {
  const c = await colonneDi(f);
  pezziMentale.push(`SELECT TRY_CAST(trim(${come(c, "Anno")}) AS INTEGER) AS anno,
    trim(${come(c, "Codice Regione")}) || '-' || trim(${come(c, "Codice Asl", "Codice ASL")}) AS asl_id,
    trim(${come(c, "Descrizione Regione", "Regione")}) AS regione,
    trim(${come(c, "Asl", "ASL")}) AS asl,
    trim(${come(c, "DSM")}) AS dipartimento,
    trim(${come(c, "Classe d'età")}) AS classe_eta,
    trim(${come(c, "Sesso")}) AS sesso,
    ${numero(come(c, "Numero Accessi"))} AS accessi
  FROM ${leggi(f)}
  WHERE trim(${come(c, "Codice Regione")}) IS NOT NULL`);
}
await con.run(`CREATE OR REPLACE TABLE salute_mentale AS
  ${pezziMentale.join(" UNION ALL ")}
  ORDER BY anno, asl_id, classe_eta`);

// ------------------------------------------------------------------ dipendenze
if (fSerd.length) {
  const pezziSerd = [];
  for (const [, f] of fSerd) {
    const c = await colonneDi(f);
    pezziSerd.push(`SELECT TRY_CAST(trim(${come(c, "Anno")}) AS INTEGER) AS anno,
      trim(${come(c, "Codice regione", "Codice Regione")}) || '-' || trim(${come(c, "Codice ASL", "Codice Asl")}) AS asl_id,
      trim(${come(c, "Regione", "Descrizione Regione")}) AS regione,
      trim(${come(c, "ASL", "Asl", "Denominazione ASL")}) AS asl,
      trim(${come(c, "SERD")}) AS servizio,
      trim(${come(c, "Categoria Sostanza")}) AS sostanza,
      ${numero(come(c, "Utenti"))} AS utenti
    FROM ${leggi(f)}
    WHERE trim(${come(c, "Codice regione", "Codice Regione")}) IS NOT NULL`);
  }
  await con.run(`CREATE OR REPLACE TABLE dipendenze AS
    ${pezziSerd.join(" UNION ALL ")}
    ORDER BY anno, asl_id, sostanza`);
}

const c = await q(`SELECT count(*) righe, count(DISTINCT codice_istat) comuni,
  count(DISTINCT asl_id) aziende, max(anno) anno,
  count(*) FILTER (WHERE gestione ILIKE '%pubblic%') pubblici FROM consultori`);
console.log(
  `  consultori:     ${c.righe} in ${c.comuni} comuni · ${c.aziende} aziende · ` +
    `${c.pubblici} pubblici · anno ${c.anno}`,
);

const m = await q(`SELECT count(*) righe, count(DISTINCT asl_id) aziende,
  min(anno) dal, max(anno) al,
  sum(accessi) FILTER (WHERE anno = (SELECT max(anno) FROM salute_mentale)) accessi
  FROM salute_mentale`);
console.log(
  `  salute mentale: ${m.righe} righe · ${m.aziende} aziende · ${m.dal}-${m.al} · ` +
    `${m.accessi} accessi nell'ultimo anno`,
);

const d = await q(`SELECT count(*) righe, count(DISTINCT asl_id) aziende,
  min(anno) dal, max(anno) al,
  count(*) FILTER (WHERE utenti IS NULL) riservate,
  sum(utenti) FILTER (WHERE anno = (SELECT max(anno) FROM dipendenze)) utenti
  FROM dipendenze`);
console.log(
  `  dipendenze:     ${d.righe} righe · ${d.aziende} aziende · ${d.dal}-${d.al} · ` +
    `${d.utenti} utenti nell'ultimo anno`,
);
console.log(
  `                  ${d.riservate} celle senza numero: sono quelle troppo piccole ` +
    `perché il Ministero le pubblichi, e restano NULL invece di diventare zero`,
);

async function catalog(tbl, source, dataflow, titleIt, titleEn, descIt, descEn, url, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(x => ({ name: x.column_name, type: x.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', '${esc(source)}', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      '${esc(url)}', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

await catalog(
  "consultori",
  "dati.salute.gov.it",
  "salute/consultori-familiari",
  "Consultori familiari (Ministero della Salute)",
  "Family planning clinics (Ministry of Health)",
  `Dove sono i consultori familiari italiani, uno per riga, con indirizzo e CAP e — questa è la ragione per cui la tabella è utile — il \`codice_istat\` del comune, che li rende contabili e mappabili per territorio come le farmacie. \`gestione\` distingue i pubblici da quelli in convenzione con il Servizio Sanitario. È un servizio di prossimità: il rapporto fra consultori e popolazione ha senso sul COMUNE, al contrario dei posti letto d'ospedale, perché in consultorio ci si va da vicino. NON ci sono le coordinate: la collocazione è al comune, e non è stata inventata una geocodifica per far comparire dei punti su una mappa.`,
  `Where Italy's family planning clinics are, one per row, with address and postcode and — the reason the table is useful — the municipality \`codice_istat\`, which makes them countable and mappable by territory like pharmacies. \`gestione\` separates public ones from those contracted to the health service. It is a proximity service: the clinics-per-population ratio makes sense at MUNICIPALITY level, unlike hospital beds, because you go to one nearby. There are NO coordinates: placement is at municipality level, and no geocoding was invented to make dots appear on a map.`,
  "https://www.dati.salute.gov.it/",
  Number(c.righe),
);

await catalog(
  "salute_mentale",
  "dati.salute.gov.it",
  "salute/prevalenza-utenti-dsm",
  "Utenti dei servizi di salute mentale (Ministero della Salute)",
  "Mental health service users (Ministry of Health)",
  `Quante persone sono state trattate dai Dipartimenti di Salute Mentale, per azienda sanitaria, classe d'età e sesso, dal 2022. \`accessi\` è il numero di utenti trattati, non di visite. Il livello è l'AZIENDA e non il comune, perché è a quel livello che il servizio è organizzato: si porta sul territorio unendo \`asl_id\` a sanita_asl_comuni, che dice quali comuni serve ogni azienda. Un numero alto non è un cattivo segno: dice che il servizio intercetta le persone, e la lettura opposta — poche persone trattate uguale poco disagio — è quasi sempre sbagliata.`,
  `How many people were treated by mental health departments, by health authority, age band and sex, since 2022. \`accessi\` counts users treated, not visits. The level is the AUTHORITY rather than the municipality, because that is how the service is organised: it reaches the territory by joining \`asl_id\` to sanita_asl_comuni, which says which municipalities each authority serves. A high number is not a bad sign: it says the service is reaching people, and the opposite reading — few treated means little distress — is almost always wrong.`,
  "https://www.dati.salute.gov.it/",
  Number(m.righe),
);

await catalog(
  "dipendenze",
  "dati.salute.gov.it",
  "salute/utenti-serd-sostanza",
  "Utenti dei servizi per le dipendenze, per sostanza (Ministero della Salute)",
  "Addiction service users by substance (Ministry of Health)",
  `Quante persone sono in carico ai servizi per le dipendenze (SerD) per sostanza d'abuso primaria — oppiacei, cocaina, cannabis, alcol — per azienda sanitaria, dal 2020. ATTENZIONE alle celle vuote: \`utenti\` è NULL dove il numero è troppo piccolo perché il Ministero lo pubblichi senza rischiare di identificare le persone, e NON è uno zero. Sommare trattando i NULL come zeri sottostima, e leggerli come «nessun utente» è falso. Il livello è l'AZIENDA: si porta sul territorio unendo \`asl_id\` a sanita_asl_comuni.`,
  `How many people are in the care of addiction services by primary substance — opioids, cocaine, cannabis, alcohol — by health authority, since 2020. MIND the empty cells: \`utenti\` is NULL where the number is too small for the Ministry to publish without risking identification, and it is NOT a zero. Summing with NULLs treated as zeros understates, and reading them as "no users" is false. The level is the AUTHORITY: it reaches the territory by joining \`asl_id\` to sanita_asl_comuni.`,
  "https://www.dati.salute.gov.it/",
  Number(d.righe),
);

console.log(`\nconsultori: ${c.righe} · salute_mentale: ${m.righe} · dipendenze: ${d.righe}`);
await con.run("CHECKPOINT");
con.closeSync();
