// Ingestione della capacità ricettiva PER COMUNE (ISTAT — IstatData/SDMX) →
// tabella `turismo_capacita` in DuckDB + riga nel `catalog`. Una riga per comune e
// anno: quanti esercizi ricettivi ci sono e quanti posti letto offrono.
//
// È il gemello comunale di `turismo`, e la differenza fra i due va capita prima di
// usarli: `turismo` è il MOVIMENTO (arrivi e presenze) e si ferma alla PROVINCIA,
// perché ISTAT lo copre con il segreto statistico sui comuni con poche strutture;
// questa è la CAPACITÀ (quante strutture ci sono e quanti letti hanno), che è un
// censimento dell'offerta e non un conteggio di persone, e per comune c'è. La nota
// in testa a `turismo.mjs` — «il dataflow esplicitamente comunale risulta
// scollegato» — riguardava il movimento, ed è ancora vera per quello.
//
// Fonte (nessuna chiave), dataflow 122_54_DF_DCSC_TUR_1 «Capacity of collective
// accommodation establishments by type of accommodation - com.»:
//   https://esploradati.istat.it/SDMXWS/rest/data/IT1,122_54_DF_DCSC_TUR_1,1.0/<key>
//
// TRAPPOLE:
//  - ISTAT applica un RATE LIMIT aggressivo (poche richieste al minuto, ban di 1-2
//    giorni se superato): **UNA sola richiesta** per tutto il Paese e tutti gli anni,
//    con i tipi combinati da '+' nella chiave e REF_AREA lasciata vuota. Mai un ciclo
//    per comune o per anno — sarebbero ottomila richieste e un blocco garantito;
//  - **`endPeriod` viene ignorato** da questo endpoint: chiedendo 2023-2023 tornano
//    anche il 2024. Non è un errore, ed è il motivo per cui la tabella tiene l'anno
//    come colonna invece di fidarsi del filtro;
//  - REF_AREA senza filtro porta ANCHE nazione, ripartizioni, regioni e province: i
//    comuni sono i codici a **sei cifre**, e si tengono solo quelli. La codelist ne
//    dichiara 9380, più dei 7896 di oggi, perché contiene anche i comuni soppressi —
//    l'aggancio a istat_confini_comuni è stampato a fine ETL per vederlo;
//  - le undici dimensioni vanno fissate tutte o la risposta esplode: DATA_TYPE
//    NUM_EST (esercizi) e BEDS (posti letto), ADJUSTMENT=N, ECON_ACTIVITY=551_553
//    (alloggio), COUNTRY_RES_GUESTS=NAP, il resto ALL/TOT;
//  - TYPE_ACCOMMODATION: per comune ISTAT pubblica **solo il totale** (ALL).
//    Chiedere anche HOTELLIKE e OTHER — alberghiero ed extra-alberghiero — non dà
//    errore: dà semplicemente zero righe, e quattro colonne NULL per sempre. Quella
//    ripartizione esiste solo dalla provincia in su, e qui non si finge di averla;
//
//  - **IL 2025 È UNA ROTTURA DI SERIE, e va detto a chiunque disegni una linea.**
//    Gli esercizi passano da 265.319 (2024) a 738.751 (2025) e i posti letto da 5,5 a
//    7,7 milioni: non è un boom, è ISTAT che comincia a contare gli affitti brevi
//    censiti dalla banca dati nazionale. Si vede dal rapporto fra i due salti —
//    gli esercizi quasi triplicano, i letti crescono di un quarto, che è la firma di
//    centinaia di migliaia di unità minuscole (un appartamento = un esercizio, quattro
//    letti). Un confronto 2020-2025 senza questa nota misura un cambio di metodo e lo
//    chiama crescita.
//
// Uso:  bun etl/turismo-capacita.mjs [--refresh]
//   --refresh  ignora la cache in raw/turismo-capacita/ e riscarica
//              (ATTENZIONE al rate limit ISTAT: non abusare)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/turismo-capacita/";
const DB = ROOT + "warehouse.duckdb";
const THIS_YEAR = new Date().getFullYear();
const FROM_YEAR = THIS_YEAR - 6;

// FREQ . REF_AREA . DATA_TYPE . ADJUSTMENT . TYPE_ACCOMMODATION . ECON_ACTIVITY .
// COUNTRY_RES_GUESTS . LOCALITY_TYPE . URBANIZ_DEGREE . COASTAL_AREA . SIZE
const KEY = "A..NUM_EST+BEDS.N.ALL.551_553.NAP.ALL.ALL.ALL.TOT";
const URL_SDMX =
  `https://esploradati.istat.it/SDMXWS/rest/data/IT1,122_54_DF_DCSC_TUR_1,1.0/${KEY}` +
  `?startPeriod=${FROM_YEAR}`;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ capacità ricettiva per comune (ISTAT)");

const locale = RAW + "capacita.csv";
if (refresh || !(await Bun.file(locale).exists())) {
  console.log("  una sola richiesta SDMX per tutto il Paese…");
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

// Il pivot: una riga per comune e anno, con esercizi e posti letto.
const misura = (tipo, dato) =>
  `max(TRY_CAST(OBS_VALUE AS BIGINT)) FILTER (WHERE TYPE_ACCOMMODATION = '${tipo}' AND DATA_TYPE = '${dato}')`;

await con.run(`CREATE OR REPLACE TABLE turismo_capacita AS
  WITH comunali AS (
    -- solo i codici a sei cifre: senza filtro REF_AREA la risposta porta anche
    -- nazione, ripartizioni, regioni e province
    SELECT * FROM _grezzo WHERE regexp_matches(REF_AREA, '^\\d{6}$')
  )
  SELECT c.REF_AREA AS codice_istat,
    g.comune,
    g.provincia,
    g.regione,
    TRY_CAST(c.TIME_PERIOD AS INTEGER) AS anno,
    ${misura("ALL", "NUM_EST")} AS esercizi,
    ${misura("ALL", "BEDS")} AS posti_letto
  FROM comunali c
  LEFT JOIN istat_confini_comuni g ON g.codice_istat = c.REF_AREA
  GROUP BY 1, 2, 3, 4, 5
  HAVING anno IS NOT NULL
  ORDER BY 1, 5`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  count(*) righe,
  count(DISTINCT codice_istat) comuni,
  count(DISTINCT anno) anni,
  min(anno) dal, max(anno) al,
  count(*) FILTER (WHERE comune IS NULL) senza_confine
  FROM turismo_capacita`);
const ultimo = await q(`SELECT sum(esercizi) esercizi, sum(posti_letto) letti
  FROM turismo_capacita WHERE anno = (SELECT max(anno) FROM turismo_capacita)`);
console.log(`  righe:    ${st.righe} (${st.comuni} comuni × ${st.anni} anni, ${st.dal}-${st.al})`);
console.log(`  al ${st.al}:  ${ultimo.esercizi} esercizi, ${ultimo.letti} posti letto in tutta Italia`);
if (Number(st.senza_confine) > 0)
  console.log(
    `  ${st.senza_confine} righe con un codice non nei confini correnti: sono comuni ` +
      `soppressi, che la codelist ISTAT conserva`,
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
  "turismo_capacita",
  "esploradati.istat.it",
  "istat/capacita-esercizi-ricettivi",
  "Capacità ricettiva per comune (ISTAT)",
  "Accommodation capacity by municipality (ISTAT)",
  `Quante strutture ricettive ci sono in ogni comune italiano e quanti posti letto offrono, per anno, alberghieri ed extra-alberghieri insieme (ISTAT non scorpora le due voci per comune). È l'offerta turistica, non il movimento: gli arrivi e le presenze stanno in \`turismo\` e si fermano alla provincia, perché ISTAT li copre con il segreto statistico dove le strutture sono poche. Il rapporto fra posti letto e popolazione residente (in istat_popolazione, stesso codice_istat) è la misura di pressione turistica che questa tabella esiste per rendere calcolabile. ATTENZIONE alla rottura di serie del 2025: gli esercizi passano da 265.319 a 738.751 perché ISTAT comincia a contare gli affitti brevi censiti dalla banca dati nazionale — un confronto 2020-2025 misura un cambio di metodo, non una crescita.`,
  `How many accommodation establishments each Italian municipality has and how many beds they offer, per year, hotels and non-hotel accommodation together (ISTAT does not split the two per municipality). This is supply, not movement: arrivals and overnight stays live in \`turismo\` and stop at province level, because ISTAT withholds them where establishments are few. The ratio of beds to resident population (in istat_popolazione, same codice_istat) is the tourism-pressure measure this table exists to make computable. MIND the 2025 break in series: establishments jump from 265,319 to 738,751 because ISTAT starts counting short-term rentals from the national register — a 2020-2025 comparison measures a change of method, not growth.`,
  "https://esploradati.istat.it/",
  Number(st.righe),
);

console.log(`\nturismo_capacita: ${st.righe} righe, ${st.comuni} comuni`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
