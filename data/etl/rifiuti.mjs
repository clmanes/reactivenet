// Ingestione della produzione/raccolta differenziata di rifiuti urbani per
// comune (ISPRA — Catasto Nazionale Rifiuti) → tabella `rifiuti` in DuckDB +
// riga nel `catalog`. Una riga per comune/anno, con le principali frazioni
// merceologiche e la percentuale di raccolta differenziata: la mappa
// "differenziata per comune", incrociabile con popolazione e reddito.
//
// Fonte (nessuna chiave), un file CSV per ANNO:
//   https://www.catasto-rifiuti.isprambiente.it/get/getDettaglioComunale.csv.php?&aa=<anno>
// Si scaricano gli ultimi N anni disponibili (loop dall'anno corrente-1 a
// scendere, si ferma dopo averne trovati YEARS_WANTED).
//
// TRAPPOLE:
//  - il file è "sporco": riga 1 = titolo (skip), riga 2 = header vero, righe
//    dati precedute da 4 TAB prima del primo campo, ultima riga = nota a piè
//    pagina. Si legge senza header (posizionale) e si scarta col regex sul
//    primo campo ripulito dai tab;
//  - `IstatComune` è a 8 cifre = codice REGIONE(2) + codice ISTAT comune
//    standard(6, provincia+comune) — si usa right(...,6) per agganciarsi a
//    istat_confini_comuni.codice_istat (verificato via il bridge sotto);
//  - numeri in formato italiano (punto migliaia, virgola decimali,
//    "62,61%" con simbolo incluso, "-" = dato mancante);
//  - CSV `;`-separated, CRLF, encoding ASCII-compatibile.
//
// Uso:  bun etl/rifiuti.mjs [--years N] [--refresh]
//   --years    quanti anni scaricare (default 5)
//   --refresh  ignora la cache in raw/rifiuti/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/rifiuti/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://www.catasto-rifiuti.isprambiente.it/get/getDettaglioComunale.csv.php?&aa=";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const yearsWanted = args.includes("--years") ? Number(args[args.indexOf("--years") + 1]) : 5;
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// scarica il csv di un anno; false se non disponibile (pagina d'errore invece del csv)
async function fetchYear(year) {
  const out = `${RAW}${year}.csv`;
  if (!refresh && (await Bun.file(out).exists())) return true;
  let res;
  try {
    res = await fetch(`${BASE}${year}`, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
  } catch {
    return false;
  }
  if (!res.ok) return false;
  const text = await res.text();
  if (!/^\s*\t*Produzione e raccolta/i.test(text)) return false; // pagina d'errore, non il csv
  await Bun.write(out, text);
  return true;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ rifiuti urbani per comune (ISPRA — Catasto Nazionale Rifiuti)");

const years = [];
for (let y = THIS_YEAR - 1; y >= 2015 && years.length < yearsWanted; y--) {
  if (await fetchYear(y)) years.push(y);
}
if (years.length === 0) throw new Error("nessun anno rifiuti disponibile");
console.log(`  anni scaricati: ${years.join(", ")}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const num = col =>
  `TRY_CAST(NULLIF(replace(replace(trim(regexp_replace(${col}, '%', '')), '.', ''), ',', '.'), '-') AS DOUBLE)`;

const unions = years
  .map(
    y => `SELECT *, ${y} AS anno FROM read_csv('${RAW}${y}.csv',
      delim = ';', header = false, skip = 2, all_varchar = true, null_padding = true, ignore_errors = true,
      strict_mode = false, quote = '')`,
  )
  .join("\n  UNION ALL BY NAME\n  ");

await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
  WITH u AS (${unions})
  SELECT trim(column00, chr(9)) AS ic, column01 AS reg_f, column02 AS prov_f, column03 AS comune_f,
    column04 AS pop_f, column06 AS umida, column07 AS verde, column08 AS carta, column09 AS vetro,
    column10 AS legno, column11 AS metallo, column12 AS plastica, column13 AS raee, column14 AS tessili,
    column20 AS totale_rd_f, column21 AS ingombranti_smalt, column22 AS indiff, column23 AS totale_ru_f,
    column24 AS pct_rd_f, anno
  FROM u
  WHERE regexp_matches(trim(column00, chr(9)), '^[0-9]{8}$')`);

await con.run(`CREATE OR REPLACE TABLE rifiuti AS
WITH comuni AS (
  SELECT codice_istat, comune, sigla, provincia, regione, cod_reg FROM istat_confini_comuni
)
SELECT
  right(r.ic, 6) AS codice_istat,
  coalesce(c.comune, NULLIF(trim(r.comune_f), '')) AS comune,
  coalesce(c.sigla, NULLIF(trim(r.prov_f), '')) AS sigla,
  c.provincia,
  coalesce(c.regione, NULLIF(trim(r.reg_f), '')) AS regione,
  c.cod_reg,
  r.anno,
  ${num("r.pop_f")}::BIGINT AS popolazione,
  ${num("r.umida")} AS umido,
  ${num("r.verde")} AS verde,
  ${num("r.carta")} AS carta_cartone,
  ${num("r.vetro")} AS vetro,
  ${num("r.plastica")} AS plastica,
  ${num("r.metallo")} AS metallo,
  ${num("r.raee")} AS raee,
  (${num("r.ingombranti_smalt")}) AS ingombranti_smaltimento,
  ${num("r.indiff")} AS indifferenziato,
  ${num("r.totale_rd_f")} AS totale_rd,
  ${num("r.totale_ru_f")} AS totale_ru,
  ${num("r.pct_rd_f")} AS percentuale_rd
FROM raw r
LEFT JOIN comuni c ON c.codice_istat = right(r.ic, 6)`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT codice_istat) AS comuni,
    round(avg(percentuale_rd), 1) AS media_rd, min(anno) AS da, max(anno) AS a FROM rifiuti`)
).getRowObjects()[0];
console.log(
  `  rifiuti: ${stat.n} righe — ${stat.comuni} comuni, anni ${stat.da}–${stat.a}, ` +
    `differenziata media ${stat.media_rd}%`,
);

// aggancio ai confini (verifica l'assunzione right(IstatComune,6))
const bridge = (
  await con.runAndReadAll(`SELECT round(100.0 * count(*) FILTER (WHERE comune IS NOT NULL AND sigla IS NOT NULL) / count(*), 1) AS pct
    FROM rifiuti`)
).getRowObjects()[0].pct;
console.log(`  aggancio a istat_confini_comuni: ${bridge}% delle righe`);
if (Number(bridge) < 90) console.warn("  ATTENZIONE: aggancio basso, verificare l'estrazione del codice ISTAT");

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'rifiuti' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Rifiuti urbani e raccolta differenziata per comune (ISPRA)";
const titleEn = "Municipal waste and separate collection by municipality (ISPRA)";
const descIt = `Produzione di rifiuti urbani e raccolta differenziata per comune, anni ${stat.da}–${stat.a} (fonte ISPRA — Catasto Nazionale Rifiuti, dati aperti): totale rifiuti urbani, totale raccolta differenziata, PERCENTUALE di raccolta differenziata e le principali frazioni merceologiche (umido, verde, carta e cartone, vetro, plastica, metallo, RAEE, indifferenziato). Una riga per comune/anno, agganciata a popolazione e confini tramite codice_istat: la mappa "differenziata per comune" e il suo andamento nel tempo.`;
const descEn = `Municipal waste generation and separate (recycling) collection by municipality, years ${stat.da}–${stat.a} (source ISPRA — National Waste Register, open data): total municipal waste, total separate collection, separate-collection RATE and the main waste fractions (organic, green, paper/cardboard, glass, plastic, metal, WEEE, residual). One row per municipality/year, joined to population and boundaries via codice_istat: the "recycling rate by municipality" map and its trend over time.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'rifiuti'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('rifiuti', 'catasto-rifiuti.isprambiente.it', 'ispra/catasto-rifiuti-comunale',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://www.catasto-rifiuti.isprambiente.it/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nrifiuti: ${stat.n} righe (${stat.comuni} comuni, anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
