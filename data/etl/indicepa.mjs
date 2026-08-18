// Ingestione dell'anagrafica delle Pubbliche Amministrazioni da IndicePA
// (indicepa.gov.it) → tabella `indicepa` in DuckDB + riga nel `catalog`.
// È il registro di TUTTE le PA italiane: ministeri, comuni, ASL, università,
// camere di commercio, gestori di pubblici servizi. Trasforma l'amministrazione
// appaltante delle gare (oggi solo testo libero in anac_cig) in un'ENTITÀ
// profilata: tipo, comune con codice ISTAT, PEC, sito.
//
// Fonte: CKAN pubblico (licenza CC-BY 4.0, aggiornato ogni notte). L'URL del
// file porta degli UUID, quindi si risolve via `package_show` invece di
// cablarlo — così un cambio di risorsa non rompe l'ETL. Serve uno User-Agent da
// browser (il portale ha un WAF sui path API, non sui download).
//
// TRAPPOLE:
//  - `amministrazioni.txt` è TSV, UTF-8 con BOM, e usa la stringa letterale
//    `null` per i vuoti (70k occorrenze) → `nullstr='null'` obbligatorio;
//  - NON contiene il codice ISTAT del comune (solo `Comune` + `Provincia`
//    sigla): lo si ricava col join nome+sigla a voc_istat_cities, come per i
//    carburanti (comuni ATTUALI e DISTINCT, o il join moltiplica le righe);
//  - `tipologia_istat` NON è un codice ISTAT ma un'etichetta di categoria
//    ("Comuni e loro Consorzi…"): non usarla come chiave;
//  - la PEC è la prima delle 5 coppie mail/tipo_mail con tipo = "Pec".
//
// Ponte verso le gare: `cf` (codice fiscale, popolato al 100%) →
// anac_cig.cf_amministrazione_appaltante (aggancio ~88% verificato).
//
// Uso:  bun etl/indicepa.mjs [--refresh]
//   --refresh  ignora la cache in raw/indicepa/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/indicepa/";
const DB = ROOT + "warehouse.duckdb";
const API = "https://indicepa.gov.it/ipa-dati/api/3/action";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

// il WAF sui path API esige uno User-Agent da browser
const HEADERS = {
  accept: "application/json, text/plain, */*",
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

async function get(url, { tries = 4, timeoutMs = 120_000, json = true } = {}) {
  let lastErr;
  for (let i = 1; i <= tries; i++) {
    try {
      const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(timeoutMs) });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      if (!json) return await res.text();
      const text = await res.text();
      if (text.startsWith("<")) throw new Error("respinto dal WAF (User-Agent?)");
      return JSON.parse(text);
    } catch (e) {
      lastErr = e;
      if (i < tries) await new Promise(r => setTimeout(r, 2000 * i));
    }
  }
  throw new Error(`${url}: ${lastErr?.message ?? lastErr}`);
}

mkdirSync(RAW, { recursive: true });
console.log("▸ anagrafica PA da IndicePA (indicepa.gov.it)");

const txt = `${RAW}amministrazioni.txt`;
if (refresh || !(await Bun.file(txt).exists())) {
  // risolve l'URL del file (UUID) dal pacchetto CKAN
  const pkg = await get(`${API}/package_show?id=amministrazioni`);
  const res = (pkg.result?.resources ?? []).find(r => /amministrazioni\.txt$/i.test(r.url ?? ""));
  if (!res) throw new Error("risorsa amministrazioni.txt non trovata nel pacchetto CKAN");
  await Bun.write(txt, await get(res.url, { json: false }));
  console.log(`  scaricato (licenza ${pkg.result?.license_id ?? "?"})`);
} else {
  console.log("  da cache");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non possono
// essere ricostruite dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

// --- caricamento e normalizzazione → indicepa -----------------------------------
await con.run(`CREATE OR REPLACE TEMP TABLE amm AS
  SELECT * FROM read_csv('${txt}', delim = '\t', header = true, nullstr = 'null', all_varchar = true)`);

// la PEC è la prima delle 5 coppie (mail, tipo_mail) con tipo = "Pec"
const pec = Array.from({ length: 5 }, (_, i) => {
  const n = i + 1;
  return `CASE WHEN lower(tipo_mail${n}) = 'pec' THEN NULLIF(trim(mail${n}), '') END`;
}).join(", ");

await con.run(`CREATE OR REPLACE TABLE indicepa AS
WITH comuni AS (
  -- comuni ATTUALI e DISTINCT: il vocabolario ha più righe per codice
  -- (storico e varianti) e senza DISTINCT il join moltiplica le PA
  SELECT DISTINCT upper(strip_accents(LABEL_COMUNE_IT)) AS nome, SIGLA_AUTOMOBILISTICA AS sigla, CODICE_COMUNE AS codice
  FROM voc_istat_cities
  WHERE DATA_FINE_VALIDITA = '31-12-9999'
)
SELECT
  a.cod_amm,
  NULLIF(trim(a.des_amm), '') AS denominazione,
  NULLIF(trim(a.acronimo), '') AS acronimo,
  NULLIF(trim(a.tipologia_amm), '') AS tipologia,
  -- categoria ISTAT dell'ente (fine): "Comuni e loro Consorzi…", "Ministeri",
  -- "Aziende Sanitarie Locali", "Università"… — NON è un codice, ma è l'unico
  -- modo per filtrare per genere di ente (i comuni, le ASL, gli atenei)
  NULLIF(trim(a.tipologia_istat), '') AS categoria,
  NULLIF(trim(a.Comune), '') AS comune,
  NULLIF(trim(a.Provincia), '') AS provincia,
  NULLIF(trim(a.Regione), '') AS regione,
  c.codice AS codice_istat,
  NULLIF(trim(a.Cap), '') AS cap,
  NULLIF(trim(a.Indirizzo), '') AS indirizzo,
  NULLIF(trim(a.cf), '') AS cf,
  NULLIF(trim(a.sito_istituzionale), '') AS sito,
  coalesce(${pec}) AS pec
FROM amm a
LEFT JOIN comuni c ON upper(strip_accents(a.Comune)) = c.nome AND a.Provincia = c.sigla
WHERE a.cod_amm IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY a.cod_amm ORDER BY a.des_amm) = 1`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT cod_amm) AS pk,
    count(codice_istat) AS con_istat, count(cf) AS con_cf, count(pec) AS con_pec FROM indicepa`)
).getRowObjects()[0];
console.log(
  `  indicepa: ${stat.n} amministrazioni — ${stat.con_istat} con codice ISTAT ` +
    `(${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}%), ${stat.con_cf} con CF, ${stat.con_pec} con PEC`,
);

// copertura del ponte verso le gare (informativa)
const bridge = (
  await con.runAndReadAll(`SELECT round(100.0 * count(DISTINCT a.cf_amministrazione_appaltante)
      FILTER (WHERE i.cf IS NOT NULL) / count(DISTINCT a.cf_amministrazione_appaltante), 1) AS pct
    FROM anac_cig a LEFT JOIN indicepa i ON i.cf = a.cf_amministrazione_appaltante
    WHERE a.cf_amministrazione_appaltante IS NOT NULL`)
).getRowObjects()[0].pct;
if (bridge != null) console.log(`  ponte anac_cig.cf → indicepa.cf: ${bridge}% dei CF appaltanti agganciati`);

// --- riga di catalogo ------------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'indicepa' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Anagrafica delle Pubbliche Amministrazioni (IndicePA)";
const titleEn = "Registry of Italian public administrations (IndicePA)";
const descIt =
  "Anagrafica di tutte le Pubbliche Amministrazioni italiane (comuni, ministeri, ASL, università, camere di commercio, gestori di pubblici servizi): denominazione, tipologia, comune con codice ISTAT, indirizzo, codice fiscale, PEC e sito istituzionale. Si aggancia alle gare (anac_cig) tramite il codice fiscale dell'amministrazione appaltante, e ai vocabolari tramite codice_istat. Aggiornata ogni notte.";
const descEn =
  "Registry of every Italian public administration (municipalities, ministries, local health authorities, universities, chambers of commerce, public-service operators): name, type, municipality with ISTAT code, address, tax code, certified email (PEC) and institutional website. Joins to tenders (anac_cig) via the contracting authority's tax code, and to the vocabularies via codice_istat. Updated nightly.";
await con.run(`DELETE FROM catalog WHERE table_name = 'indicepa'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('indicepa', 'indicepa.gov.it', 'indicepa/amministrazioni',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://indicepa.gov.it', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nindicepa: ${stat.n} amministrazioni`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
