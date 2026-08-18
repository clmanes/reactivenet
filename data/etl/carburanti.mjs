// Ingestione dell'Osservaprezzi carburanti del MIMIT → tabelle `carb_impianti`
// e `carb_prezzi` in DuckDB + righe nel `catalog`. È la fonte di fatti più
// VIVA del warehouse: il MIMIT ripubblica i due CSV ogni mattina, quindi ogni
// run è uno snapshot completo che sostituisce il precedente (nessuno storico:
// i file non lo espongono).
//
// Fonte (nessun WAF, nessuna chiave, licenza IODL 2.0):
//   https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv
//   https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv
//
// I due file sono pipe-separated e hanno una RIGA DI TITOLO prima dell'header
// ("Estrazione del YYYY-MM-DD" — da cui si ricava data_estrazione).
//
// TRAPPOLA dell'anagrafica: il campo "Nome Impianto" contiene a volte un '|'
// NON quotato (es. "STOIL SIMPLE | gestori.prezzibenzina.it"), quindi ~100
// righe su 24k hanno 11-12 campi invece di 10 e lo sniffer di DuckDB fallisce
// del tutto ("It was not possible to automatically detect the CSV parsing
// dialect"). Non è recuperabile con null_padding (che pareggia i campi
// MANCANTI, non quelli in più) e ignore_errors butterebbe via le righe. Si
// legge quindi riga per riga e si spacchetta POSIZIONALMENTE: i primi 4 campi
// e gli ultimi 5 sono fissi, tutto ciò che sta in mezzo è il nome. L'assunzione
// è verificata su tutte le righe (provincia sempre 2 lettere, id sempre
// numerico) e ricontrollata a ogni run: se salta, l'ETL si ferma.
//
// Il codice ISTAT non c'è: l'anagrafica porta solo nome comune + sigla
// provincia. Si aggancia a voc_istat_cities (comuni ATTUALMENTE validi,
// DEDUPLICATI — il vocabolario ha 8229 righe per 7896 codici e un join
// ingenuo moltiplicherebbe gli impianti). Copertura ~99.7%: i non agganciati
// sono comuni fusi/soppressi che il MIMIT non ha aggiornato (CORIGLIANO
// CALABRO e ROSSANO → Corigliano-Rossano, POPOLI → Popoli Terme, …).
//
// Uso:  bun etl/carburanti.mjs [--refresh]
//   --refresh  ignora la cache in raw/carburanti/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/carburanti/";
const DB = ROOT + "warehouse.duckdb";
const BASE = "https://www.mimit.gov.it/images/exportCSV/";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

// il portale ogni tanto risponde 5xx: retry con backoff
async function download(name, outPath) {
  let lastErr;
  for (let i = 1; i <= 3; i++) {
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), 120_000);
    try {
      const res = await fetch(BASE + name, { signal: ctl.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const text = await res.text();
      // un portale che risponde 200 con una pagina d'errore non deve entrare
      if (!text.startsWith("Estrazione del")) throw new Error("risposta senza riga di estrazione");
      await Bun.write(outPath, text);
      return;
    } catch (e) {
      lastErr = e;
      if (i < 3) await new Promise(r => setTimeout(r, 2000 * i));
    } finally {
      clearTimeout(t);
    }
  }
  throw new Error(`${name}: ${lastErr?.message ?? lastErr}`);
}

// "Estrazione del 2026-07-16" → 2026-07-16
async function extractionDate(path) {
  const head = (await Bun.file(path).text()).slice(0, 60);
  const m = head.match(/Estrazione del (\d{4}-\d{2}-\d{2})/);
  if (!m) throw new Error(`${path}: riga di estrazione non riconosciuta`);
  return m[1];
}

mkdirSync(RAW, { recursive: true });
console.log("▸ Osservaprezzi carburanti (mimit.gov.it)");

const files = {
  impianti: RAW + "anagrafica_impianti_attivi.csv",
  prezzi: RAW + "prezzo_alle_8.csv",
};
for (const [key, path] of Object.entries(files)) {
  if (!refresh && (await Bun.file(path).exists())) {
    console.log(`  ${key}: da cache`);
    continue;
  }
  await download(key === "impianti" ? "anagrafica_impianti_attivi.csv" : "prezzo_alle_8.csv", path);
  console.log(`  ${key}: scaricato`);
}

const dataImpianti = await extractionDate(files.impianti);
const dataPrezzi = await extractionDate(files.prezzi);
console.log(`  estrazione: impianti ${dataImpianti}, prezzi ${dataPrezzi}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO anche qui, benché i carburanti non abbiano embeddings: le
// tabelle con indice HNSW (lex_atti, anac_cig) non possono essere ricostruite
// dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// --- 1. impianti: parse posizionale (vedi TRAPPOLA in testa) --------------------
// delim = un byte di controllo che nel file non esiste: così read_csv NON
// spacchetta nulla e restituisce la riga intera, senza sniffer di dialetto.
await con.run(`CREATE OR REPLACE TEMP TABLE imp_raw AS
  SELECT str_split(line, '|') AS f, len(str_split(line, '|')) AS n
  FROM read_csv('${files.impianti}',
    columns = {'line': 'VARCHAR'}, delim = '${"\x01"}', header = false, skip = 2, quote = '', escape = '')
  WHERE trim(line) != ''`);

// L'assunzione posizionale va riverificata a ogni run: se il MIMIT cambia il
// tracciato, meglio fermarsi che caricare colonne sfasate in silenzio.
const check = (
  await con.runAndReadAll(`SELECT
    count(*) AS tot,
    sum(CASE WHEN n < 10 THEN 1 ELSE 0 END) AS troppo_corte,
    sum(CASE WHEN NOT regexp_matches(f[n-2], '^[A-Z]{2}$') THEN 1 ELSE 0 END) AS prov_non_valida,
    sum(CASE WHEN TRY_CAST(f[1] AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS id_non_numerico
  FROM imp_raw`)
).getRowObjects()[0];
if (Number(check.troppo_corte) > 0 || Number(check.prov_non_valida) > 0 || Number(check.id_non_numerico) > 0)
  throw new Error(
    `tracciato anagrafica inatteso su ${check.tot} righe: ${check.troppo_corte} corte, ` +
      `${check.prov_non_valida} con provincia non valida, ${check.id_non_numerico} con id non numerico`,
  );

await con.run(`CREATE OR REPLACE TABLE carb_impianti AS
WITH parsed AS (
  SELECT
    TRY_CAST(f[1] AS BIGINT) AS id_impianto,
    NULLIF(trim(f[2]), '') AS gestore,
    NULLIF(trim(f[3]), '') AS bandiera,
    NULLIF(trim(f[4]), '') AS tipo_impianto,
    -- tutto ciò che sta tra i 4 campi iniziali e i 5 finali è il nome
    NULLIF(trim(array_to_string(array_slice(f, 5, n - 5), '|')), '') AS nome_impianto,
    NULLIF(trim(f[n-4]), '') AS indirizzo,
    NULLIF(trim(f[n-3]), '') AS comune,
    NULLIF(trim(f[n-2]), '') AS provincia,
    TRY_CAST(f[n-1] AS DOUBLE) AS latitudine,
    TRY_CAST(f[n] AS DOUBLE) AS longitudine
  FROM imp_raw
), comuni AS (
  -- comuni ATTUALMENTE validi, una riga per chiave: il vocabolario ne ha di
  -- più (storico e varianti) e senza DISTINCT il join duplica gli impianti
  SELECT DISTINCT upper(strip_accents(LABEL_COMUNE_IT)) AS nome, SIGLA_AUTOMOBILISTICA AS sigla, CODICE_COMUNE AS codice
  FROM voc_istat_cities
  WHERE DATA_FINE_VALIDITA = '31-12-9999'
)
SELECT
  p.id_impianto, p.gestore, p.bandiera, p.tipo_impianto, p.nome_impianto,
  p.indirizzo, p.comune, p.provincia,
  c.codice AS codice_istat,
  -- coordinate palesemente fuori dall'Italia = dato sporco, meglio NULL che
  -- un impianto che finisce in mezzo all'oceano su una mappa
  CASE WHEN p.latitudine BETWEEN 35 AND 48 THEN p.latitudine END AS latitudine,
  CASE WHEN p.longitudine BETWEEN 6 AND 19 THEN p.longitudine END AS longitudine,
  DATE '${dataImpianti}' AS data_estrazione
FROM parsed p
LEFT JOIN comuni c ON upper(strip_accents(p.comune)) = c.nome AND p.provincia = c.sigla
QUALIFY row_number() OVER (PARTITION BY p.id_impianto ORDER BY p.nome_impianto) = 1`);

const imp = (
  await con.runAndReadAll(`SELECT count(*) AS n,
    count(codice_istat) AS con_istat,
    count(latitudine) AS con_coord FROM carb_impianti`)
).getRowObjects()[0];
console.log(
  `  carb_impianti: ${imp.n} impianti — ${imp.con_istat} con codice ISTAT ` +
    `(${((Number(imp.con_istat) / Number(imp.n)) * 100).toFixed(1)}%), ${imp.con_coord} con coordinate`,
);

// --- 2. prezzi: il file è regolare (5 campi sempre) ------------------------------
// dtComu è 'dd/mm/yyyy HH:MM:SS'. Una stessa combinazione impianto/carburante/
// self può comparire più volte: si tiene la comunicazione più recente.
await con.run(`CREATE OR REPLACE TABLE carb_prezzi AS
SELECT
  TRY_CAST(idImpianto AS BIGINT) AS id_impianto,
  NULLIF(trim(descCarburante), '') AS carburante,
  TRY_CAST(prezzo AS DOUBLE) AS prezzo,
  isSelf = '1' AS self,
  TRY_STRPTIME(dtComu, '%d/%m/%Y %H:%M:%S') AS data_comunicazione,
  DATE '${dataPrezzi}' AS data_estrazione
FROM read_csv('${files.prezzi}', delim = '|', header = true, skip = 1, all_varchar = true)
WHERE TRY_CAST(idImpianto AS BIGINT) IS NOT NULL
QUALIFY row_number() OVER (
  PARTITION BY idImpianto, descCarburante, isSelf
  ORDER BY TRY_STRPTIME(dtComu, '%d/%m/%Y %H:%M:%S') DESC NULLS LAST
) = 1`);

const pr = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT id_impianto) AS impianti,
    count(DISTINCT carburante) AS carburanti, count(prezzo) AS con_prezzo FROM carb_prezzi`)
).getRowObjects()[0];
const orfani = (
  await con.runAndReadAll(`SELECT count(DISTINCT p.id_impianto) AS n FROM carb_prezzi p
    LEFT JOIN carb_impianti i USING (id_impianto) WHERE i.id_impianto IS NULL`)
).getRowObjects()[0].n;
console.log(
  `  carb_prezzi: ${pr.n} prezzi su ${pr.impianti} impianti, ${pr.carburanti} tipi di carburante` +
    (Number(orfani) > 0 ? ` (${orfani} impianti non in anagrafica)` : ""),
);

// --- 3. righe di catalogo --------------------------------------------------------

const colsOf = async table =>
  (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${esc(table)}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(c => ({ name: c.column_name, type: c.data_type }));

const catalogRow = async (table, dataflow, titleIt, titleEn, descIt, descEn, rows) => {
  await con.run(`DELETE FROM catalog WHERE table_name = '${esc(table)}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${esc(table)}', 'mimit.gov.it', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      'https://www.mimit.gov.it/it/prezzi-carburanti', now(), ${rows},
      '${esc(JSON.stringify(await colsOf(table)))}')`);
};

await catalogRow(
  "carb_impianti",
  "mimit/osservaprezzi-impianti",
  "Impianti di distribuzione carburanti (Osservaprezzi MIMIT)",
  "Fuel stations registry (MIMIT price observatory)",
  "Anagrafica di tutti gli impianti di distribuzione carburanti attivi in Italia: gestore, bandiera, tipo di impianto (stradale o autostradale), nome, indirizzo, comune con codice ISTAT e coordinate geografiche. Si aggancia a carb_prezzi tramite id_impianto. Aggiornata ogni giorno.",
  "Registry of every active fuel station in Italy: operator, brand, station type (road or motorway), name, address, municipality with ISTAT code and geographic coordinates. Joins to carb_prezzi via id_impianto. Updated daily.",
  Number(imp.n),
);
await catalogRow(
  "carb_prezzi",
  "mimit/osservaprezzi-prezzi",
  "Prezzi dei carburanti per impianto (Osservaprezzi MIMIT)",
  "Fuel prices by station (MIMIT price observatory)",
  "Prezzi comunicati dai gestori per ogni impianto e tipo di carburante (benzina, gasolio, GPL, metano, …), distinti tra self service e servito, con la data della comunicazione. Fotografia quotidiana, non storico. Si aggancia a carb_impianti tramite id_impianto per avere comune, coordinate e bandiera.",
  "Fuel prices reported by operators for each station and fuel type (petrol, diesel, LPG, methane, …), split between self-service and attended, with the report timestamp. A daily snapshot, not a time series. Joins to carb_impianti via id_impianto for municipality, coordinates and brand.",
  Number(pr.n),
);

console.log(`\ncarburanti: ${imp.n} impianti, ${pr.n} prezzi (estrazione ${dataPrezzi})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
