// Ingestione del bilancio demografico ISTAT (demo.istat.it, file "P2") →
// tabella `istat_popolazione` in DuckDB + riga nel `catalog`. Una riga per
// comune con la popolazione residente e il movimento dell'anno (nati, morti,
// migrazioni). È il DENOMINATORE del warehouse: senza, ogni confronto tra
// comuni (spesa in gare, numero di distributori, …) è falsato dalla taglia del
// comune — 624 miliardi banditi non dicono nulla finché non sono pro capite.
//
// Fonte (licenza CC-BY 4.0, nessun WAF, nessuna chiave):
//   https://demo.istat.it/data/p2/P2_<anno>_it_Comuni.zip
// Un file per anno di bilancio (P2_2025 = movimento del 2025, popolazione al
// 31 dicembre 2025), pubblicato ~marzo dell'anno dopo. L'anno in corso NON
// esiste finché non si chiude: l'ETL parte dall'anno corrente e scende finché
// trova un file (--year forza un anno specifico).
//
// TRAPPOLE del CSV (comuni ai file demo.istat.it):
//  - `;`-separated, UTF-8 con BOM, e una RIGA DI TITOLO prima dell'header
//    ("Bilancio demografico e popolazione residente al 31 dicembre YYYY") →
//    skip=1;
//  - in coda c'è una RIGA DI NOTE ("Note: p = dato provvisorio…") con un solo
//    campo: manda in tilt lo sniffer di dialetto di DuckDB. Serve
//    `ignore_errors=true` per superarla; in più si filtra sul codice comune a
//    6 cifre, così la nota non diventa un finto comune anche se passasse;
//  - codici comune zero-padded e quotati (`"028001"`) → VARCHAR obbligatorio o
//    si perde lo zero iniziale.
//
// Join: `Codice comune` (6 cifre) → voc_istat_cities.CODICE_COMUNE, 100%
// (verificato). Popolazione totale d'Italia ~58,9M, coerente col dato reale.
//
// Uso:  bun etl/istat-popolazione.mjs [--year N] [--refresh]
//   --year     forza l'anno di bilancio (default: il più recente disponibile)
//   --refresh  ignora la cache in raw/istat-pop/ e riscarica

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/istat-pop/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://demo.istat.it/data/p2/";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const forcedYear = argOf("--year");

const esc = s => String(s).replaceAll("'", "''");

// scarica lo zip di un anno; null se non esiste (404) o non è uno zip
async function fetchYear(year, outPath) {
  if (!refresh && (await Bun.file(outPath).exists())) return true;
  let res;
  try {
    res = await fetch(`${BASE}P2_${year}_it_Comuni.zip`, { signal: AbortSignal.timeout(120_000) });
  } catch (e) {
    throw new Error(`P2_${year}: ${e.message ?? e}`);
  }
  if (res.status === 404) return false;
  if (!res.ok) throw new Error(`P2_${year}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  // un 200 con una pagina d'errore HTML non deve entrare
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) return false; // "PK" = zip
  await Bun.write(outPath, buf);
  return true;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ bilancio demografico ISTAT (demo.istat.it)");

// anno: quello forzato, oppure il più recente che esiste (dall'anno corrente giù)
let year = null;
const zip = y => `${RAW}P2_${y}_it_Comuni.zip`;
if (forcedYear) {
  if (!(await fetchYear(forcedYear, zip(forcedYear)))) throw new Error(`P2_${forcedYear} non disponibile`);
  year = forcedYear;
} else {
  for (let y = THIS_YEAR; y >= THIS_YEAR - 3; y--) {
    if (await fetchYear(y, zip(y))) {
      year = y;
      break;
    }
  }
  if (year == null) throw new Error(`nessun P2 trovato tra ${THIS_YEAR - 3} e ${THIS_YEAR}`);
}
console.log(`  anno di bilancio: ${year}`);

// estrai il CSV dallo zip su file temporaneo (DuckDB legge da path)
const entries = unzipSync(new Uint8Array(await Bun.file(zip(year)).arrayBuffer()), {
  filter: f => f.name.toLowerCase().endsWith(".csv"),
});
const name = Object.keys(entries)[0];
if (!name) throw new Error(`nessun csv in P2_${year}`);
const csv = `${RAW}P2_${year}.csv`;
await Bun.write(csv, entries[name]);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non possono
// essere ricostruite dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database — anche scrivendo solo su un'altra tabella.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// --- caricamento e normalizzazione → istat_popolazione --------------------------
// I nomi originali sono lunghissimi e quotati ("Popolazione al 31 dicembre -
// Totale"): si legge grezzo e si proietta un sottoinsieme con nomi puliti. Si
// tiene la popolazione (inizio/fine, M/F) e il movimento in totale — le stesse
// voci per sesso restano nel file, ma qui pesano poco e servono di rado.
await con.run(`CREATE OR REPLACE TEMP TABLE p2 AS
  SELECT * FROM read_csv('${csv}',
    delim = ';', quote = '"', header = true, skip = 1, ignore_errors = true, all_varchar = true)
  WHERE regexp_matches("Codice comune", '^[0-9]{6}$')`);

const col = n => `TRY_CAST("${n}" AS INTEGER)`;
await con.run(`CREATE OR REPLACE TABLE istat_popolazione AS
SELECT
  "Codice comune" AS codice_istat,
  NULLIF(trim("Comune"), '') AS comune,
  ${year} AS anno,
  ${col("Popolazione censita al 1° gennaio - Totale")} AS popolazione_inizio,
  ${col("Popolazione al 31 dicembre - Totale")} AS popolazione,
  ${col("Popolazione al 31 dicembre - Maschi")} AS maschi,
  ${col("Popolazione al 31 dicembre - Femmine")} AS femmine,
  ${col("Nati vivi - Totale")} AS nati,
  ${col("Morti - Totale")} AS morti,
  ${col("Saldo naturale - Totale")} AS saldo_naturale,
  ${col("Saldo migratorio interno - Totale")} AS saldo_migratorio_interno,
  ${col("Saldo migratorio con l'estero - Totale")} AS saldo_migratorio_estero
FROM p2`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT codice_istat) AS cod,
    sum(popolazione) AS pop_it FROM istat_popolazione`)
).getRowObjects()[0];
console.log(
  `  istat_popolazione: ${stat.n} comuni, popolazione totale ${Number(stat.pop_it).toLocaleString("it-IT")}`,
);

// --- riga di catalogo ------------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'istat_popolazione' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Popolazione residente per comune (ISTAT)";
const titleEn = "Resident population by municipality (ISTAT)";
const descIt = `Bilancio demografico ISTAT al 31 dicembre ${year}: per ogni comune italiano la popolazione residente (totale, maschi, femmine) all'inizio e alla fine dell'anno, più il movimento (nati, morti, saldo naturale e saldi migratori interno ed estero). Una riga per comune, agganciata ai vocabolari tramite codice_istat. È il denominatore per i confronti pro capite (spesa, gare, servizi).`;
const descEn = `ISTAT demographic balance at 31 December ${year}: for each Italian municipality the resident population (total, male, female) at the start and end of the year, plus the movement (births, deaths, natural balance and internal/foreign migration balances). One row per municipality, joined to the vocabularies via codice_istat. It is the denominator for per-capita comparisons (spending, tenders, services).`;
await con.run(`DELETE FROM catalog WHERE table_name = 'istat_popolazione'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('istat_popolazione', 'demo.istat.it', 'istat/bilancio-demografico',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://demo.istat.it', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nistat_popolazione: ${stat.n} comuni (bilancio ${year})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
