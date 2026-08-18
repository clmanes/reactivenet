// Ingestione dei redditi IRPEF su base comunale (MEF — Dipartimento delle
// Finanze) → tabella `mef_redditi` in DuckDB + riga nel `catalog`. Una riga per
// comune con il numero di contribuenti, il reddito complessivo dichiarato e il
// REDDITO MEDIO per dichiarante. È il complemento naturale di istat_popolazione
// e istat_confini_comuni: incrociati per codice_istat diventano la mappa
// "reddito per comune" — quella che tutti cercano — a costo quasi nullo.
//
// Fonte (licenza CC BY 3.0 IT, nessuna chiave):
//   https://www1.finanze.gov.it/finanze/analisi_stat/public/v_4_0_0/contenuti/
//     Redditi_e_principali_variabili_IRPEF_su_base_comunale_CSV_<anno>.zip
// Un file per ANNO DI IMPOSTA, pubblicato con ~due anni di ritardo (il 2023 esce
// nel 2025): l'ETL parte dall'anno corrente e scende finché trova lo zip.
//
// TRAPPOLE:
//  - CSV `;`-separated, con una coppia Frequenza/Ammontare per ogni voce (52
//    colonne): si legge grezzo (all_varchar) e si proietta il sottoinsieme utile;
//  - il `Codice Istat Comune` è a 6 cifre zero-padded (`058091`) e quotato →
//    VARCHAR obbligatorio o si perde lo zero iniziale. Combacia 1:1 con
//    voc_istat_cities.CODICE_COMUNE / istat_confini_comuni.codice_istat;
//  - i nomi comune del MEF rendono gli accenti come apostrofi ("AGLIE'"): per il
//    display si preferisce l'etichetta pulita di voc_istat_cities, con fallback
//    al nome MEF;
//  - per i comuni molto piccoli alcune celle sono soppresse (vuote) per privacy
//    → TRY_CAST + guardia sulla divisione del reddito medio.
//
// reddito_medio = "Reddito complessivo - Ammontare" / "Reddito complessivo -
// Frequenza" (il reddito medio per dichiarante, la definizione MEF).
//
// Uso:  bun etl/mef-redditi.mjs [--year N] [--refresh]
//   --year     forza l'anno di imposta (default: il più recente disponibile)
//   --refresh  ignora la cache in raw/mef-redditi/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/mef-redditi/";
const DB = ROOT + "warehouse.duckdb";
const BASE =
  "https://www1.finanze.gov.it/finanze/analisi_stat/public/v_4_0_0/contenuti/Redditi_e_principali_variabili_IRPEF_su_base_comunale_CSV_";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const forcedYear = argOf("--year");
const esc = s => String(s).replaceAll("'", "''");

// scarica lo zip di un anno; false se non esiste o non è uno zip
async function fetchYear(year, outPath) {
  if (!refresh && (await Bun.file(outPath).exists())) return true;
  let res;
  try {
    res = await fetch(`${BASE}${year}.zip`, { signal: AbortSignal.timeout(120_000) });
  } catch (e) {
    throw new Error(`redditi ${year}: ${e.message ?? e}`);
  }
  if (res.status === 404) return false;
  if (!res.ok) return false;
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) return false; // "PK" = zip (una pagina d'errore no)
  await Bun.write(outPath, buf);
  return true;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ redditi IRPEF su base comunale (MEF — Dipartimento delle Finanze)");

let year = null;
const zip = y => `${RAW}redditi_${y}.zip`;
if (forcedYear) {
  if (!(await fetchYear(forcedYear, zip(forcedYear)))) throw new Error(`redditi ${forcedYear} non disponibili`);
  year = forcedYear;
} else {
  for (let y = THIS_YEAR; y >= THIS_YEAR - 5; y--) {
    if (await fetchYear(y, zip(y))) {
      year = y;
      break;
    }
  }
  if (year == null) throw new Error(`nessun file redditi trovato tra ${THIS_YEAR - 5} e ${THIS_YEAR}`);
}
console.log(`  anno di imposta: ${year}`);

// estrai il CSV dallo zip su file (DuckDB legge da path)
const entries = unzipSync(new Uint8Array(await Bun.file(zip(year)).arrayBuffer()), {
  filter: f => f.name.toLowerCase().endsWith(".csv"),
});
const name = Object.keys(entries)[0];
if (!name) throw new Error(`nessun csv in redditi_${year}`);
const csv = `${RAW}redditi_${year}.csv`;
await Bun.write(csv, entries[name]);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca tutto
// il database anche scrivendo su un'altra tabella.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// null_padding: alcune annate (2024) hanno un ';' finale nell'header → 53
// colonne nell'header contro 52 nei dati; senza padding lo sniffer si blocca.
// La 53ª colonna spuria resta vuota e non viene proiettata.
await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
  SELECT * FROM read_csv('${csv}', delim = ';', header = true, all_varchar = true, null_padding = true)
  WHERE regexp_matches("Codice Istat Comune", '^[0-9]{6}$')`);

// proiezione pulita; il reddito medio è protetto dalla divisione per zero e gli
// importi/frequenze soppressi diventano NULL. Nome/sigla puliti dai vocabolari.
const num = n => `TRY_CAST(NULLIF(trim("${n}"), '') AS BIGINT)`;
await con.run(`CREATE OR REPLACE TABLE mef_redditi AS
WITH comuni AS (
  SELECT DISTINCT CODICE_COMUNE AS cod, LABEL_COMUNE_IT AS nome, SIGLA_AUTOMOBILISTICA AS sigla
  FROM voc_istat_cities WHERE DATA_FINE_VALIDITA = '31-12-9999'
)
SELECT
  r."Codice Istat Comune" AS codice_istat,
  coalesce(c.nome, NULLIF(trim(r."Denominazione Comune"), '')) AS comune,
  coalesce(c.sigla, NULLIF(trim(r."Sigla Provincia"), '')) AS sigla,
  NULLIF(trim(r."Regione"), '') AS regione,
  ${year} AS anno,
  ${num("Numero contribuenti")} AS contribuenti,
  ${num("Reddito complessivo - Ammontare in euro")} AS reddito_complessivo,
  ${num("Reddito complessivo - Frequenza")} AS dichiaranti,
  CASE WHEN ${num("Reddito complessivo - Frequenza")} > 0
    THEN round(${num("Reddito complessivo - Ammontare in euro")}::DOUBLE / ${num("Reddito complessivo - Frequenza")})
  END AS reddito_medio,
  ${num("Reddito imponibile - Ammontare in euro")} AS reddito_imponibile,
  ${num("Imposta netta - Ammontare in euro")} AS imposta_netta,
  coalesce(${num("Reddito complessivo minore o uguale a zero euro - Frequenza")}, 0)
    + coalesce(${num("Reddito complessivo da 0 a 10000 euro - Frequenza")}, 0) AS contribuenti_bassi,
  coalesce(${num("Reddito complessivo da 75000 a 120000 euro - Frequenza")}, 0)
    + coalesce(${num("Reddito complessivo oltre 120000 euro - Frequenza")}, 0) AS contribuenti_alti
FROM raw r
LEFT JOIN comuni c ON c.cod = r."Codice Istat Comune"`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(reddito_medio) AS con_medio,
    round(median(reddito_medio)) AS mediana, round(sum(reddito_complessivo) / 1e9, 1) AS mld
    FROM mef_redditi`)
).getRowObjects()[0];
console.log(
  `  mef_redditi: ${stat.n} comuni — reddito medio mediano ${Number(stat.mediana).toLocaleString("it-IT")} €, ` +
    `reddito complessivo dichiarato ${stat.mld} mld €`,
);

// aggancio ai confini (informativo, se presenti)
const bridge = (
  await con.runAndReadAll(`SELECT count(g.codice_istat) AS con_geo, count(*) AS n
    FROM mef_redditi m LEFT JOIN istat_confini_comuni g ON g.codice_istat = m.codice_istat`)
).getRowObjects()[0];
if (Number(bridge.con_geo) > 0)
  console.log(`  aggancio a istat_confini_comuni: ${bridge.con_geo}/${bridge.n} comuni mappabili`);

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'mef_redditi' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Redditi IRPEF per comune (MEF)";
const titleEn = "Personal income tax (IRPEF) by municipality (MEF)";
const descIt = `Dichiarazioni dei redditi delle persone fisiche (IRPEF) aggregate per comune, anno di imposta ${year} (fonte MEF — Dipartimento delle Finanze, CC BY 3.0): numero di contribuenti, reddito complessivo dichiarato, REDDITO MEDIO per dichiarante, reddito imponibile, imposta netta e la ripartizione dei contribuenti per fasce di reddito (bassi ≤10.000 €, alti >75.000 €). Una riga per comune, agganciata a popolazione e confini tramite codice_istat: è la mappa "reddito per comune".`;
const descEn = `Personal income tax (IRPEF) returns aggregated by municipality, tax year ${year} (source MEF — Department of Finance, CC BY 3.0): number of taxpayers, total declared income, AVERAGE INCOME per filer, taxable income, net tax and the split of taxpayers by income bracket (low ≤€10,000, high >€75,000). One row per municipality, joined to population and boundaries via codice_istat: the "income by municipality" map.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'mef_redditi'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('mef_redditi', 'finanze.gov.it', 'mef/redditi-irpef-comunali',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://www.finanze.gov.it/it/statistiche-fiscali/open-data-comunale-principali-variabili-irpef/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nmef_redditi: ${stat.n} comuni (anno di imposta ${year})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
