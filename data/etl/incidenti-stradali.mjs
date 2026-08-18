// Ingestione degli INCIDENTI STRADALI PER COMUNE (ISTAT — IstatData/SDMX) →
// tabella `incidenti_stradali` in DuckDB + riga nel `catalog`. Una riga per comune e
// anno: quanti incidenti con lesioni alle persone, quanti morti, quanti feriti.
//
// È la prima misura di ESITO della mobilità nel warehouse. Tutto il resto che
// riguarda gli spostamenti descrive una dotazione o una struttura — `aci_veicoli`
// quante auto ci sono, `anncsu_strade` dove passano le strade, `pendolarismo` chi
// gravita su chi — e nessuna di queste dice come va a finire. Questa sì, ed è
// l'unica che lo dice per OGNI comune e per ventiquattro anni di fila.
//
// Fonte (nessuna chiave), dataflow 41_983_DF_DCIS_INCIDMORFER_COM_1 «Road accidents,
// killed and injured - municipalities»:
//   https://esploradati.istat.it/SDMXWS/rest/data/IT1,41_983_DF_DCIS_INCIDMORFER_COM_1,1.0/<key>
//
// LA PROVA CHE IL PARSING È GIUSTO è il totale nazionale: sommando i comuni del 2024
// vengono 173.364 incidenti, 3.030 morti e 233.853 feriti, che sono esattamente le
// cifre che ISTAT pubblica per l'Italia. Se questo controllo — stampato a fine ETL —
// smette di tornare, è cambiato qualcosa nella risposta, non nell'incidentalità.
//
// TRAPPOLE:
//  - ISTAT applica un RATE LIMIT aggressivo (poche richieste al minuto, ban di 1-2
//    giorni se superato): **UNA sola richiesta** per tutto il Paese e tutti gli anni,
//    con REF_AREA lasciata vuota. Mai un ciclo per comune o per anno — sarebbero
//    ottomila richieste e un blocco garantito. Qui costa 45 MB e una ventina di
//    secondi, il che rende il ciclo non solo dannoso ma inutile;
//  - **le tre misure arrivano come tre RIGHE, non tre colonne**, distinte da due
//    dimensioni che vanno lette insieme: `ROADACC × 9` è il numero di incidenti
//    (l'esito «9» vale *totale* e non è una terza categoria di persone), mentre
//    `KILLINJ × M` e `KILLINJ × F` sono i morti e i feriti. Sommare tutto ciò che
//    ha lo stesso codice comune e anno mette insieme incidenti e persone, che sono
//    unità diverse: il pivot qui sotto le tiene separate con dei FILTER;
//  - la codelist REF_AREA di questo dataflow contiene **solo comuni** — nessuna
//    riga di regione, ripartizione o nazione, al contrario di altri dataflow ISTAT
//    dove l'aggregato viaggia insieme al dettaglio. Il filtro sulle sei cifre resta
//    lo stesso come guardia: se un giorno ISTAT aggiungesse i totali, sommarli
//    raddoppierebbe l'Italia in silenzio;
//  - i comuni distinti sono **8.578 contro i 7.896 di oggi**: la differenza sono i
//    soppressi per fusione, che la serie storica conserva perché nel 2001 esistevano.
//    Non è sporcizia da ripulire — è il motivo per cui l'aggancio ai confini correnti
//    è un LEFT JOIN e il conteggio degli orfani è stampato;
//
//  - **L'ULTIMO ANNO OMETTE GLI ZERI, e senza accorgersene si disegnano mappe false.**
//    Dal 2001 al 2023 ISTAT pubblica una riga anche per il comune che non ha avuto
//    nessun incidente — sono circa 1.700 comuni l'anno, e l'aver scritto «0» è un
//    dato, non una svista. Nel 2024 quelle righe non ci sono: i comuni presenti sono
//    6.339 invece di 7.896, e i 1.557 mancanti sono esattamente quelli con zero
//    incidenti. Che siano zeri e non dati soppressi lo dimostra il totale nazionale,
//    che torna esatto senza di loro: se fossero ignoti, la somma dei comuni non farebbe
//    3.030 morti. Lasciarli fuori significa che ogni mappa dell'anno più recente
//    colora di grigio «non pervenuto» un quinto dei comuni italiani, dove la risposta
//    giusta è la migliore possibile. Perciò l'ETL **completa gli zeri dell'ultimo anno**
//    contro i confini correnti, e lo fa solo se quell'anno non ne contiene già —
//    la regola è legata all'asimmetria osservata, non all'anno scritto a mano, così
//    quando ISTAT consoliderà il 2024 e pubblicherà il 2025 il completamento si
//    sposterà da solo. Il conteggio delle righe aggiunte è stampato;
//  - il tasso per abitante NON è calcolato qui: la popolazione sta in
//    `istat_popolazione` con lo stesso `codice_istat`, e il rapporto si fa al momento
//    della query. Precalcolarlo significherebbe fissare oggi quale denominatore è
//    quello giusto, e per un comune di duemila abitanti con l'autostrada che gli passa
//    accanto il denominatore giusto non è la sua popolazione.
//
// Uso:  bun etl/incidenti-stradali.mjs [--refresh]
//   --refresh  ignora la cache in raw/incidenti-stradali/ e riscarica
//              (ATTENZIONE al rate limit ISTAT: non abusare)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/incidenti-stradali/";
const DB = ROOT + "warehouse.duckdb";

// FREQ . REF_AREA . DATA_TYPE . RESULT — quattro dimensioni, tre lasciate aperte
const KEY = "A...";
const URL_SDMX = `https://esploradati.istat.it/SDMXWS/rest/data/IT1,41_983_DF_DCIS_INCIDMORFER_COM_1,1.0/${KEY}`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ incidenti stradali per comune (ISTAT)");

const locale = RAW + "incidenti.csv";
if (refresh || !(await Bun.file(locale).exists())) {
  console.log("  una sola richiesta SDMX per tutto il Paese e tutti gli anni…");
  const res = await fetch(URL_SDMX, {
    headers: { accept: "application/vnd.sdmx.data+csv" },
    signal: AbortSignal.timeout(600_000),
  });
  if (res.status === 429 || res.status === 403)
    throw new Error(
      `ISTAT ha risposto ${res.status}: rate limit. Il blocco dura 1-2 giorni — ` +
        `NON riprovare in ciclo, aspetta.`,
    );
  if (!res.ok) throw new Error(`SDMX: HTTP ${res.status}`);
  const testo = await res.text();
  if (!testo.startsWith("DATAFLOW")) throw new Error("la risposta non è il CSV SDMX atteso");
  await Bun.write(locale, testo);
  console.log(`  ${(testo.length / 1e6).toFixed(1)} MB`);
} else {
  console.log("  dalla cache in raw/");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// vss perché il CHECKPOINT finale tocca tutto il database e le tabelle con indice
// HNSW non si ricostruiscono senza l'estensione.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo AS
  SELECT * FROM read_csv('${esc(locale)}', header = true, all_varchar = true)`);

// Il pivot: le tre misure arrivano come righe distinte da DATA_TYPE × RESULT.
const misura = cond =>
  `max(TRY_CAST(OBS_VALUE AS BIGINT)) FILTER (WHERE ${cond})`;

await con.run(`CREATE OR REPLACE TABLE incidenti_stradali AS
  WITH comunali AS (
    -- guardia: oggi la codelist contiene solo comuni, ma un aggregato che si
    -- aggiungesse domani raddoppierebbe l'Italia senza dirlo
    SELECT * FROM _grezzo WHERE regexp_matches(REF_AREA, '^\\d{6}$')
  )
  SELECT c.REF_AREA AS codice_istat,
    g.comune,
    g.sigla,
    g.provincia,
    g.regione,
    TRY_CAST(c.TIME_PERIOD AS INTEGER) AS anno,
    ${misura("DATA_TYPE = 'ROADACC'")} AS incidenti,
    ${misura("DATA_TYPE = 'KILLINJ' AND RESULT = 'M'")} AS morti,
    ${misura("DATA_TYPE = 'KILLINJ' AND RESULT = 'F'")} AS feriti
  FROM comunali c
  LEFT JOIN istat_confini_comuni g ON g.codice_istat = c.REF_AREA
  GROUP BY 1, 2, 3, 4, 5, 6
  HAVING anno IS NOT NULL
  ORDER BY 1, 6`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

// Completamento degli zeri dell'ultimo anno (vedi la trappola in testa al file):
// solo se quell'anno non ne contiene già, così la regola segue il dato invece di
// inseguire un anno scritto a mano.
const ultimoAnno = Number(
  (await q(`SELECT max(anno) a FROM incidenti_stradali`)).a,
);
const zeriUltimo = Number(
  (await q(`SELECT count(*) n FROM incidenti_stradali WHERE anno = ${ultimoAnno} AND incidenti = 0`)).n,
);
let completati = 0;
if (zeriUltimo === 0) {
  await con.run(`INSERT INTO incidenti_stradali
    SELECT g.codice_istat, g.comune, g.sigla, g.provincia, g.regione,
           ${ultimoAnno}, 0, 0, 0
    FROM istat_confini_comuni g
    WHERE NOT EXISTS (
      SELECT 1 FROM incidenti_stradali i
      WHERE i.codice_istat = g.codice_istat AND i.anno = ${ultimoAnno})`);
  completati = Number(
    (await q(`SELECT count(*) n FROM incidenti_stradali WHERE anno = ${ultimoAnno} AND incidenti = 0`)).n,
  );
}

const st = await q(`SELECT
  count(*) righe,
  count(DISTINCT codice_istat) comuni,
  count(DISTINCT anno) anni,
  min(anno) dal, max(anno) al,
  count(*) FILTER (WHERE comune IS NULL) senza_confine
  FROM incidenti_stradali`);
const ultimo = await q(`SELECT anno, sum(incidenti) incidenti, sum(morti) morti, sum(feriti) feriti
  FROM incidenti_stradali WHERE anno = (SELECT max(anno) FROM incidenti_stradali) GROUP BY 1`);

console.log(`  righe:    ${st.righe} (${st.comuni} comuni, ${st.dal}-${st.al})`);
console.log(
  `  al ${st.al}:  ${ultimo.incidenti} incidenti, ${ultimo.morti} morti, ${ultimo.feriti} feriti`,
);

// Il controllo indipendente: il totale nazionale che ISTAT pubblica a parte.
const ATTESO = { anno: 2024, incidenti: 173364, morti: 3030, feriti: 233853 };
if (Number(ultimo.anno) === ATTESO.anno) {
  const ok =
    Number(ultimo.incidenti) === ATTESO.incidenti &&
    Number(ultimo.morti) === ATTESO.morti &&
    Number(ultimo.feriti) === ATTESO.feriti;
  console.log(
    ok
      ? `  ✓ combacia con il totale nazionale ISTAT del ${ATTESO.anno}`
      : `  ⚠ il ${ATTESO.anno} NON combacia con il totale nazionale ISTAT ` +
          `(atteso ${ATTESO.incidenti}/${ATTESO.morti}/${ATTESO.feriti}): ` +
          `controllare che la risposta non abbia cambiato forma`,
  );
}
if (completati > 0)
  console.log(
    `  ${completati} comuni senza riga nel ${ultimoAnno} completati a zero: ISTAT omette ` +
      `gli zeri nell'ultimo anno, e senza questo ogni mappa del ${ultimoAnno} li darebbe ` +
      `per «non pervenuto»`,
  );
if (Number(st.senza_confine) > 0)
  console.log(
    `  ${st.senza_confine} righe con un codice non nei confini correnti: sono i comuni ` +
      `soppressi per fusione, che la serie storica conserva`,
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
  "incidenti_stradali",
  "esploradati.istat.it",
  "istat/incidenti-morti-feriti-comuni",
  "Incidenti stradali per comune (ISTAT)",
  "Road accidents by municipality (ISTAT)",
  `Quanti incidenti stradali con lesioni alle persone avvengono ogni anno in ogni comune italiano, e quanti morti e feriti ne risultano, dal 2001. Le tre misure sono unità diverse e non vanno sommate fra loro: \`incidenti\` conta i sinistri, \`morti\` e \`feriti\` contano le persone. È l'unica misura di ESITO della mobilità disponibile per ogni comune: il parco veicolare sta in \`aci_veicoli\`, gli spostamenti casa-lavoro in \`pendolarismo\`, la rete viaria in \`anncsu_strade\`, e nessuna di queste dice come va a finire. Il tasso per abitante si calcola al momento della query contro \`istat_popolazione\` (stesso codice_istat) e NON è precalcolato, perché per un comune piccolo attraversato da una strada di grande traffico la sua popolazione è il denominatore sbagliato. I comuni distinti sono 8.578 contro i 7.896 attuali: la differenza sono quelli soppressi per fusione, che nel 2001 esistevano. Uno ZERO è un dato e va letto come tale: circa 1.700 comuni l'anno non hanno nessun incidente, e la riga c'è. ISTAT però omette gli zeri nell'ANNO PIÙ RECENTE, dove pubblica solo i comuni con almeno un incidente: quelle righe sono ricostruite a zero contro i confini correnti, perché altrimenti una mappa dell'ultimo anno colorerebbe di «non pervenuto» un quinto dei comuni dove la risposta è zero. Somma di controllo: il 2024 nazionale fa 173.364 incidenti, 3.030 morti e 233.853 feriti, esattamente le cifre che ISTAT pubblica — ed è la prova che i comuni omessi valgono zero e non sono ignoti.`,
  `How many injury road accidents happen each year in each Italian municipality, and how many people are killed or injured, since 2001. The three measures are different units and must not be added together: \`incidenti\` counts crashes, \`morti\` and \`feriti\` count people. It is the only OUTCOME measure of mobility available for every municipality: the vehicle fleet is in \`aci_veicoli\`, commuting in \`pendolarismo\`, the road network in \`anncsu_strade\`, and none of them says how it ends. The per-capita rate is computed at query time against \`istat_popolazione\` (same codice_istat) and is deliberately NOT precomputed, because for a small municipality crossed by a busy road its own population is the wrong denominator. Distinct municipalities are 8,578 against today's 7,896: the difference is those merged away, which existed in 2001. A ZERO is data and must be read as such: some 1,700 municipalities a year have no accident at all, and the row is there. ISTAT however omits the zeros in the MOST RECENT year, publishing only municipalities with at least one accident: those rows are reconstructed as zero against current boundaries, because otherwise a map of the latest year would paint a fifth of the country as "no data" where the answer is zero. Check figure: the 2024 national total is 173,364 accidents, 3,030 killed and 233,853 injured — exactly what ISTAT publishes, which is the proof that the omitted municipalities are zeros and not unknowns.`,
  "https://esploradati.istat.it/",
  Number(st.righe),
);

console.log(`\nincidenti_stradali: ${st.righe} righe, ${st.comuni} comuni`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
