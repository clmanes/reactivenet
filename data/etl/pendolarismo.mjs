// Ingestione della matrice del pendolarismo (ISTAT, Censimento 2011) → due tabelle
// in DuckDB + righe nel `catalog`:
//   pendolarismo        (~988k)  un flusso per riga: da quale comune a quale, per
//                                studio o per lavoro, per sesso, quante persone
//   pendolarismo_mezzo  (~2,5M)  lo stesso flusso spezzato per MEZZO di trasporto
//
// È la prima tabella di FLUSSI del warehouse. Tutto il resto descrive un luogo —
// quanti abitanti, quanto suolo, quanti civici; questa descrive un LEGAME fra due
// luoghi, e con `::map` o un grafo racconta cose che nessuna somma per comune può
// dire: quali paesi si svuotano la mattina, dove va la gente che ci vive, quanto
// pesa un capoluogo sui comuni attorno.
//
// L'ANNATA È IL 2011, E NON È UNA SCELTA. La matrice del Censimento 2021 esiste — è
// stata pubblicata il 2 ottobre 2025 — ma è consultabile SOLO attraverso IstatData, e
// il suo dataflow `DF_BULK_PEND_LAV_2021_1` risponde:
//     Dataflow ... doesn't contain a mapping set
// cioè è dichiarato nel catalogo e scollegato dal motore dei dati. È lo stesso guasto
// che `turismo.mjs` documenta per il dataflow comunale del movimento turistico: sul
// portale ISTAT i dataflow «BULK» sono spesso vetrine senza dietro niente. Non
// esiste, al momento, un file della matrice 2021 da scaricare — solo 1991, 2001 e
// 2011 sono pubblicati come archivi.
//
// **Quindici anni sono tanti per il pendolarismo**, che nel frattempo ha attraversato
// il lavoro da remoto: questi numeri descrivono l'Italia che andava in ufficio tutti i
// giorni. Vanno usati per la STRUTTURA dei legami — chi gravita su chi — molto più che
// per le quantità. È scritto nella descrizione di catalogo, dove lo legge chi scrive
// la query.
//
// FONTE (nessuna chiave):
//   https://www.istat.it/storage/cartografia/matrici_pendolarismo/matrici_pendolarismo_2011.zip
//   36 MB di zip → un file a **larghezza fissa** di 307 MB, 4.876.242 record.
//
// TRAPPOLE:
//  - **è a larghezza fissa, e il tracciato sta in un .doc dentro lo zip.** Le
//    posizioni qui sotto sono lette da lì, non dedotte guardando le prime righe: una
//    colonna spostata di un carattere produce codici comune plausibili e sbagliati,
//    che è il modo peggiore di rompersi;
//  - **due tipi di record nello stesso file, e sommarli insieme conta tutto due
//    volte.** I record `S` sono i totali per strato (988.625); i record `L` (3.887.617)
//    spezzano gli stessi flussi per mezzo, orario e tempo di percorrenza. Qui `S`
//    alimenta la tabella dei flussi e `L` quella dei mezzi, e nessuna delle due
//    contiene l'altra;
//  - il codice comune è spezzato in **provincia (3) + comune (3)**: il codice ISTAT a
//    sei cifre si ottiene concatenandoli, non sommandoli;
//  - i campi non applicabili valgono `+`, non vuoto: su un record `S` mezzo, orario e
//    tempo sono `+` perché quel record non li distingue;
//  - **i codici sono quelli del 1° gennaio 2011**: da allora decine di comuni si sono
//    fusi, quindi una parte dei flussi non aggancia i confini correnti. Il conteggio
//    è stampato a fine ETL — è un fatto del dato, non un errore da correggere;
//  - `luogo` distingue tre casi che una lettura frettolosa confonde: 1 dentro lo
//    stesso comune, 2 verso un altro comune italiano, 3 all'estero. Il pendolarismo
//    «vero» — quello che attraversa un confine comunale — è solo il 2.
//
// Uso:  bun etl/pendolarismo.mjs [--refresh]

import { mkdirSync, readdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/pendolarismo/";
const DB = ROOT + "warehouse.duckdb";
const URL_ZIP =
  "https://www.istat.it/storage/cartografia/matrici_pendolarismo/matrici_pendolarismo_2011.zip";
const ANNO = 2011;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log(`▸ matrice del pendolarismo (ISTAT, Censimento ${ANNO})`);

const zip = RAW + "matrici_pendolarismo_2011.zip";
if (refresh || !(await Bun.file(zip).exists())) {
  console.log("  scarico…");
  const res = await fetch(URL_ZIP, {
    headers: { "user-agent": "reactive-data/1.0" },
    signal: AbortSignal.timeout(900_000),
  });
  if (!res.ok) throw new Error(`zip: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) throw new Error("la risposta non è uno zip");
  await Bun.write(zip, buf);
}
const p = Bun.spawnSync(["unzip", "-o", "-q", zip, "-d", RAW]);
if (p.exitCode !== 0) throw new Error("unzip fallito");

// Il .txt sta in una sottocartella con lo spazio nel nome: si cerca invece di cablarlo.
function trovaTxt(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const q = dir + e.name;
    if (e.isDirectory()) {
      const hit = trovaTxt(q + "/");
      if (hit) return hit;
    } else if (/^matrix_pendo\d{4}.*\.txt$/i.test(e.name)) return q;
  }
  return null;
}
const txt = trovaTxt(RAW);
if (!txt) throw new Error("matrix_pendo*.txt non trovato dopo l'estrazione");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// vss perché il CHECKPOINT finale tocca tutto il database e le tabelle con indice
// HNSW non si ricostruiscono senza l'estensione.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// Larghezza fissa: si legge una colonna sola con un separatore che non compare mai, e
// si taglia con substr. Le posizioni vengono dal tracciato ufficiale.
const campo = (inizio, lunghezza) => `trim(substr(r, ${inizio}, ${lunghezza}))`;
await con.run(`CREATE OR REPLACE TEMP TABLE _righe AS
  SELECT column0 AS r FROM read_csv('${esc(txt)}', delim = '\\x01', header = false,
    all_varchar = true, ignore_errors = true, columns = {'column0': 'VARCHAR'})`);

const ORIGINE = `${campo(5, 3)} || ${campo(9, 3)}`;
const DESTINAZIONE = `${campo(20, 3)} || ${campo(24, 3)}`;
const COMUNE = "CASE WHEN " + campo(18, 1) + " = '2' THEN " + DESTINAZIONE + " END";
const MOTIVO = `CASE ${campo(16, 1)} WHEN '1' THEN 'studio' WHEN '2' THEN 'lavoro' END`;
const LUOGO = `CASE ${campo(18, 1)}
  WHEN '1' THEN 'stesso comune' WHEN '2' THEN 'altro comune' WHEN '3' THEN 'estero' END`;
const SESSO = `CASE ${campo(14, 1)} WHEN '1' THEN 'M' WHEN '2' THEN 'F' END`;

await con.run(`CREATE OR REPLACE TABLE pendolarismo AS
  SELECT ${ORIGINE} AS codice_istat,
    ${COMUNE} AS codice_istat_destinazione,
    ${LUOGO} AS destinazione,
    ${MOTIVO} AS motivo,
    ${SESSO} AS sesso,
    nullif(${campo(28, 3)}, '000') AS stato_estero,
    TRY_CAST(${campo(51, 12)} AS INTEGER) AS individui,
    ${ANNO} AS anno
  FROM _righe
  WHERE substr(r, 1, 1) = 'S'
  ORDER BY 1, 2`);

// I record L, aggregati per mezzo: la stessa gente, spezzata per come si muove.
const MEZZO = `CASE ${campo(32, 2)}
  WHEN '01' THEN 'treno' WHEN '02' THEN 'tram' WHEN '03' THEN 'metropolitana'
  WHEN '04' THEN 'autobus urbano' WHEN '05' THEN 'corriera' WHEN '06' THEN 'autobus aziendale'
  WHEN '07' THEN 'auto (conducente)' WHEN '08' THEN 'auto (passeggero)'
  WHEN '09' THEN 'moto' WHEN '10' THEN 'bicicletta' WHEN '11' THEN 'altro'
  WHEN '12' THEN 'a piedi' END`;
await con.run(`CREATE OR REPLACE TABLE pendolarismo_mezzo AS
  SELECT ${ORIGINE} AS codice_istat,
    ${COMUNE} AS codice_istat_destinazione,
    ${MOTIVO} AS motivo,
    ${MEZZO} AS mezzo,
    -- il conteggio dei record L è una STIMA, con i decimali: la fonte la chiama così
    round(sum(TRY_CAST(${campo(39, 12)} AS DOUBLE))) AS individui,
    ${ANNO} AS anno
  FROM _righe
  WHERE substr(r, 1, 1) = 'L'
  GROUP BY 1, 2, 3, 4
  HAVING individui > 0
  ORDER BY 1, 2`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  (SELECT count(*) FROM pendolarismo) flussi,
  (SELECT sum(individui) FROM pendolarismo) persone,
  (SELECT sum(individui) FROM pendolarismo WHERE destinazione = 'altro comune') fuori,
  (SELECT count(DISTINCT codice_istat) FROM pendolarismo) comuni,
  (SELECT count(*) FROM pendolarismo_mezzo) righe_mezzo,
  (SELECT count(*) FROM pendolarismo p
     WHERE NOT EXISTS (SELECT 1 FROM istat_confini_comuni g WHERE g.codice_istat = p.codice_istat)) orfani`);
console.log(`  flussi (record S): ${st.flussi}, da ${st.comuni} comuni`);
console.log(`  persone:           ${st.persone}, di cui ${st.fuori} verso un altro comune`);
console.log(`  righe per mezzo:   ${st.righe_mezzo}`);
console.log(`  senza confine corrente: ${st.orfani} flussi (comuni fusi dopo il ${ANNO})`);

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

const NOTA_ANNO =
  `ATTENZIONE all'annata: questi sono i dati del Censimento ${ANNO}, e sono i più recenti ` +
  `SCARICABILI — la matrice 2021 esiste ma il suo dataflow su IstatData è scollegato dal ` +
  `motore dei dati e non risponde. Quindici anni comprendono la diffusione del lavoro da ` +
  `remoto: questi numeri descrivono l'Italia che andava in ufficio tutti i giorni, e vanno ` +
  `usati per la STRUTTURA dei legami — chi gravita su chi — molto più che per le quantità.`;

await catalog(
  "pendolarismo",
  "istat.it",
  "istat/matrice-pendolarismo",
  "Pendolarismo: flussi casa-lavoro e casa-studio (ISTAT)",
  "Commuting flows for work and study (ISTAT)",
  `Quante persone si spostano ogni giorno da un comune all'altro per studio o per lavoro, per sesso, al Censimento ${ANNO}. È la prima tabella di FLUSSI del warehouse: tutto il resto descrive un luogo, questa un legame fra due luoghi. Il campo destinazione distingue i tre casi che una lettura frettolosa confonde — "stesso comune", "altro comune", "estero" — e il pendolarismo che attraversa un confine è solo il secondo, con codice_istat_destinazione valorizzato. La ripartizione per mezzo di trasporto è in pendolarismo_mezzo. ${NOTA_ANNO}`,
  `How many people travel daily from one municipality to another for work or study, by sex, at the ${ANNO} census. This is the warehouse's first FLOW table: everything else describes a place, this describes a link between two. The destinazione field separates the three cases a hasty reading conflates — same municipality, another municipality, abroad — and commuting that crosses a boundary is only the second, where codice_istat_destinazione is set. The breakdown by transport mode is in pendolarismo_mezzo. MIND the vintage: this is the ${ANNO} census, the most recent DOWNLOADABLE — the 2021 matrix exists but its IstatData dataflow is disconnected from the data engine. Fifteen years span the spread of remote work: these numbers describe the Italy that commuted every day, and serve the STRUCTURE of the links far better than the quantities.`,
  "https://www.istat.it/notizia/matrici-di-contiguita-distanza-e-pendolarismo/",
  Number(st.flussi),
);

await catalog(
  "pendolarismo_mezzo",
  "istat.it",
  "istat/matrice-pendolarismo",
  "Pendolarismo per mezzo di trasporto (ISTAT)",
  "Commuting by transport mode (ISTAT)",
  `Gli stessi spostamenti di pendolarismo, spezzati per come si compiono: treno, tram, metropolitana, autobus urbano, corriera, autobus aziendale, auto come conducente o passeggero, moto, bicicletta, a piedi. Una riga per origine, destinazione, motivo e mezzo. I conteggi sono STIME (la fonte li chiama così e li pubblica con i decimali), arrotondate qui all'unità; non vanno sommati a quelli di pendolarismo, che vengono da record diversi dello stesso file e conterebbero le stesse persone due volte. ${NOTA_ANNO}`,
  `The same commuting trips, split by how they are made: train, tram, metro, city bus, coach, company bus, car as driver or passenger, motorcycle, bicycle, on foot. One row per origin, destination, purpose and mode. The counts are ESTIMATES (the source calls them that and publishes them with decimals), rounded here to whole people; they must not be added to those in pendolarismo, which come from different records of the same file and would count the same people twice.`,
  "https://www.istat.it/notizia/matrici-di-contiguita-distanza-e-pendolarismo/",
  Number(st.righe_mezzo),
);

console.log(`\npendolarismo: ${st.flussi} flussi, ${st.righe_mezzo} righe per mezzo (censimento ${ANNO})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
