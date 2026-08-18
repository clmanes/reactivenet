// Ingestione dei CIG (Codici Identificativi di Gara) dall'Open Data di ANAC
// → tabella `anac_cig` in DuckDB + riga nel `catalog`. È il corpus di gare
// pubbliche italiane: chi ha bandito cosa, dove, per quanto.
//
// Fonte: il portale è un CKAN (licenza CC-BY-SA 4.0) — attenzione, NON risponde
// su /api/3/ ma su /opendata/api/3/. Un pacchetto per anno (cig-2007 … cig-2025,
// l'anno in corso NON esiste: vedi "BUCO" più sotto), con 12 risorse zip
// mensili di CSV più le stesse cose in JSON e TTL, che qui si ignorano (il TTL
// pesa 10 volte il CSV a parità di contenuto).
//
// TRAPPOLA WAF: il portale è dietro un F5 che rifiuta le richieste in base allo
// User-Agent, e il criterio è la LUNGHEZZA/plausibilità: "Mozilla/5.0" viene
// respinto ("Request Rejected"), serve uno UA Chrome completo. Non servono
// Origin/Referer (a differenza di normattiva.mjs). I path /opendata/download/
// non sono protetti, ma mandiamo lo UA ovunque per semplicità.
//
// TRAPPOLA CKAN: il campo `size` delle risorse è la dimensione NON compressa
// (~92 MB), non quella dello zip (~20 MB), e va in overflow NEGATIVO sopra i
// 2 GB. Non usarlo per stimare i download.
//
// BUCO 2026: i pacchetti per anno sono snapshot annuali e `cig-2026` non
// esiste ancora. I dati dell'anno in corso passano solo dal pacchetto `cig`
// ("aggiornamenti delta"), con finestre mensili e ~4 mesi di RETENTION: un
// delta non scaricato in tempo è perso per sempre. Questo ETL copre solo i
// pacchetti per anno; il delta è un lavoro a parte.
//
// EMBEDDINGS: `oggetto_gara` è un ottimo corpus semantico (108 caratteri di
// media, mai vuoto). Di default si embedda e si INDICIZZA solo il perimetro
// ≥ 140.000 € (--embed-min, la soglia comunitaria per forniture/servizi): ~304k
// righe su 2,67M. Non è una scelta di gusto ma un VINCOLO DELLA MACCHINA DI
// PRODUZIONE (15 GB di RAM): l'indice HNSW è memory-resident quando lo si
// interroga e cresce col numero di vettori — misurato, 2,67M vettori = ~23 GB
// residenti (fuori portata per 15 GB), mentre 304k = ~2,7 GB (comodo). Vedi la
// nota "Produzione" nel README.
//
// I vettori vivono in `anac_emb`, tabella append-only in un file SUO
// (anac-emb.duckdb) LOCALE, mai deployato: la cache può contenere PIÙ del
// perimetro servito (oggi ha tutti i 2,67M) così allargare il perimetro domani
// — se il server cresce — non ricalcola nulla. Il calcolo è ~3700 vettori/min
// su GPU locale ed è RIPARTIBILE (sopravvive a run e interruzioni).
//
// --embed-min 0 embedda tutto (~12 ore); solo le righe entro il perimetro
// finiscono nella colonna `embedding` della tabella finale e quindi
// nell'indice. La ricerca a forza bruta su questi volumi NON regge il timeout
// del servizio (3,3s a query su 2,67M): serve l'indice ANN (HNSW, estensione
// vss) creato in coda — vedi il passo 6 e la nota in server.mjs sul flag
// enable_external_access.
//
// Uso:  bun etl/anac.mjs [--from A] [--to B] [--refresh] [--skip-embed] [--embed-min N]
//   --from/--to    intervallo di anni (default: ultimi 2 anni disponibili)
//   --refresh      ignora la cache in raw/anac/ e riscarica
//   --skip-embed   salta il calcolo degli embeddings (solo caricamento)
//   --embed-min    importo minimo del lotto per il perimetro servito (default 140000
//                  = soglia UE; 0 = tutti, ma l'indice non entra in 15 GB di RAM)

import { mkdirSync, unlinkSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/anac/";
const DB = ROOT + "warehouse.duckdb";
const EMB_DB = ROOT + "anac-emb.duckdb"; // cache dei vettori, fuori dal warehouse
const API = "https://dati.anticorruzione.it/opendata/api/3/action";
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const BATCH = 16;
const THIS_YEAR = new Date().getFullYear();

// Il WAF misura la plausibilità dello User-Agent: uno UA corto viene RIFIUTATO
// (verificato: "Mozilla/5.0" → Request Rejected, questo → 200).
const HEADERS = {
  accept: "application/json, text/plain, */*",
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const skipEmbed = args.includes("--skip-embed");
const embedMin = argOf("--embed-min") ?? 140_000; // soglia UE; l'indice servito sta in 15 GB
const fromYear = argOf("--from") ?? THIS_YEAR - 2;
const toYear = argOf("--to") ?? THIS_YEAR;

const esc = s => String(s).replaceAll("'", "''");

async function get(url, { tries = 4, timeoutMs = 300_000, json = true } = {}) {
  let lastErr;
  for (let i = 1; i <= tries; i++) {
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), timeoutMs);
    try {
      const res = await fetch(url, { headers: HEADERS, signal: ctl.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      if (!json) return new Uint8Array(await res.arrayBuffer());
      const text = await res.text();
      // il WAF risponde 200 con una pagina HTML: va riconosciuto, non parsato
      if (text.startsWith("<")) throw new Error("respinto dal WAF (User-Agent?)");
      return JSON.parse(text);
    } catch (e) {
      lastErr = e;
      if (i < tries) await new Promise(r => setTimeout(r, 3000 * i));
    } finally {
      clearTimeout(t);
    }
  }
  throw new Error(`${url}: ${lastErr?.message ?? lastErr}`);
}

// risorse CSV mensili di un anno: [{mese, url}] — ordinate per mese
async function monthsOf(year) {
  let pkg;
  try {
    pkg = await get(`${API}/package_show?id=cig-${year}`, { tries: 2 });
  } catch {
    return null; // anno non pubblicato (es. l'anno in corso)
  }
  return (pkg.result?.resources ?? [])
    .map(r => ({ m: /^cig_csv_\d{4}_(\d{2})$/.exec(r.name ?? "")?.[1], url: r.url }))
    .filter(r => r.m && r.url?.endsWith(".zip"))
    .sort((a, b) => a.m.localeCompare(b.m));
}

mkdirSync(RAW, { recursive: true });
console.log(`▸ CIG da dati.anticorruzione.it (${fromYear}–${toYear})`);

// --- 1. download degli zip mensili (cache in raw/anac/) -------------------------

const months = [];
for (let year = fromYear; year <= toYear; year++) {
  const res = await monthsOf(year);
  if (!res) {
    console.warn(`  ${year}: pacchetto non pubblicato — saltato`);
    continue;
  }
  for (const { m, url } of res) {
    const zip = `${RAW}cig_${year}_${m}.zip`;
    months.push({ year, m, zip });
    if (!refresh && (await Bun.file(zip).exists())) continue;
    const bytes = await get(url, { json: false });
    await Bun.write(zip, bytes);
    console.log(`  ${year}-${m}: ${(bytes.length / 1e6).toFixed(1)} MB`);
    await new Promise(r => setTimeout(r, 200)); // cortesia
  }
  console.log(`  ${year}: ${res.length} mesi`);
}
if (months.length === 0) throw new Error(`nessun mese scaricabile per ${fromYear}–${toYear}`);

// --- 2. caricamento in staging, un mese alla volta ------------------------------
// Ogni zip contiene UN csv (';', tutto quotato, UTF-8). Si estrae su file
// temporaneo perché DuckDB legge da path, si carica e si cancella subito: i
// csv sono ~92 MB l'uno, tenerli tutti costerebbe più di un giro di download.
//
// Le colonne prese sono un SOTTOINSIEME utile delle 61 del tracciato (come
// normattiva.mjs prende i metadati e lascia stare il resto). Il tracciato
// cambia negli anni: le colonne assenti in un mese diventano NULL invece di
// far fallire il caricamento.

const WANTED = [
  "cig", "numero_gara", "oggetto_gara", "oggetto_lotto", "importo_complessivo_gara", "importo_lotto",
  "n_lotti_componenti", "oggetto_principale_contratto", "stato", "settore", "luogo_istat", "provincia",
  "data_pubblicazione", "data_scadenza_offerta", "tipo_scelta_contraente", "modalita_realizzazione",
  "cf_amministrazione_appaltante", "denominazione_amministrazione_appaltante", "sezione_regionale",
  "denominazione_centro_costo", "anno_pubblicazione", "cod_cpv", "descrizione_cpv", "durata_prevista",
  "importo_sicurezza", "esito", "data_comunicazione_esito", "motivo_cancellazione", "data_cancellazione",
  "flag_pnrr_pnc", "cig_collegamento",
];

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO in ogni ETL che apre il warehouse in SCRITTURA: le tabelle con
// indice HNSW non possono essere ricostruite dal CHECKPOINT senza l'estensione,
// e il CHECKPOINT tocca tutto il database. Serve anche per creare l'indice al
// passo 6; la persistenza su file è ancora sperimentale.
await con.run("INSTALL vss");
await con.run("LOAD vss");
await con.run("SET hnsw_enable_experimental_persistence = true");

// La cache degli embeddings sta in un file SUO, non nel warehouse: sono ~11 GB
// di vettori (2,7M × FLOAT[1024]) che servono solo all'ETL — nel warehouse
// raddoppierebbero la colonna embedding e viaggerebbero a ogni deploy
// (deploy.sh fa l'rsync di warehouse.duckdb). Qui restano locali.
await con.run(`ATTACH IF NOT EXISTS '${EMB_DB}' AS embcache`);

await con.run(`CREATE OR REPLACE TEMP TABLE stage (${WANTED.map(c => `${c} VARCHAR`).join(", ")})`);

for (const { year, m, zip } of months) {
  const buf = new Uint8Array(await Bun.file(zip).arrayBuffer());
  const entries = unzipSync(buf, { filter: f => f.name.toLowerCase().endsWith(".csv") });
  const name = Object.keys(entries)[0];
  if (!name) throw new Error(`${zip}: nessun csv nello zip`);
  const csv = `${RAW}_tmp_${year}_${m}.csv`;
  await Bun.write(csv, entries[name]);
  try {
    // header vero del file → le colonne assenti diventano NULL
    const header = (await Bun.file(csv).slice(0, 8192).text())
      .split("\n")[0]
      .split(";")
      .map(h => h.trim().replaceAll('"', "").toLowerCase());
    const present = new Set(header);
    const select = WANTED.map(c => (present.has(c) ? c : `CAST(NULL AS VARCHAR) AS ${c}`)).join(", ");
    await con.run(`INSERT INTO stage SELECT ${select}
      FROM read_csv('${csv}', delim = ';', quote = '"', header = true, all_varchar = true)`);
  } finally {
    unlinkSync(csv);
  }
}
const staged = (await con.runAndReadAll("SELECT count(*) AS n FROM stage")).getRowObjects()[0].n;
console.log(`  ${staged} righe caricate`);

// --- 3. testi da embeddare (dedup per cig) --------------------------------------
// Il perimetro si decide QUI, prima di costruire la tabella finale: gli
// embeddings finiscono in una tabella LATERALE (anac_emb) e la tabella vera
// nasce già con la sua colonna via LEFT JOIN. Motivo: un UPDATE per riga su
// milioni di righe riscrive interi row group (write amplification enorme: 380 MB
// di crescita del file per soli 14k vettori in una versione precedente).

await con.run(`CREATE OR REPLACE TEMP TABLE testi AS
SELECT cig, oggetto_gara, oggetto_lotto, importo_lotto, data_pubblicazione FROM (
  SELECT
    cig,
    NULLIF(trim(regexp_replace(oggetto_gara, '\\s+', ' ', 'g')), '') AS oggetto_gara,
    NULLIF(trim(regexp_replace(oggetto_lotto, '\\s+', ' ', 'g')), '') AS oggetto_lotto,
    TRY_CAST(importo_lotto AS DOUBLE) AS importo_lotto,
    TRY_CAST(data_pubblicazione AS DATE) AS data_pubblicazione
  FROM stage
  WHERE cig IS NOT NULL AND trim(cig) != ''
  QUALIFY row_number() OVER (
    PARTITION BY cig ORDER BY TRY_CAST(data_pubblicazione AS DATE) DESC NULLS LAST
  ) = 1
)`);

// --- 4. embeddings (tabella laterale, append-only e RIPARTIBILE) ----------------
// anac_emb sopravvive ai run: è sia la cache tra un run e l'altro sia il
// checkpoint di un run lungo. Un'interruzione (Ollama che singhiozza, macchina
// riavviata) costa solo il batch in corso.

await con.run(`CREATE TABLE IF NOT EXISTS embcache.anac_emb (cig VARCHAR PRIMARY KEY, embedding FLOAT[1024])`);

if (!skipEmbed) {
  const todo = (
    await con.runAndReadAll(`SELECT t.cig, t.oggetto_gara, t.oggetto_lotto FROM testi t
      LEFT JOIN embcache.anac_emb e USING (cig)
      WHERE e.cig IS NULL AND t.oggetto_gara IS NOT NULL
        AND t.importo_lotto >= ${embedMin}
      ORDER BY t.data_pubblicazione`)
  ).getRowObjects();
  const perimetro = embedMin > 0 ? `lotti ≥ ${embedMin.toLocaleString("it-IT")} €` : "TUTTI i lotti";
  console.log(`▸ embeddings: ${todo.length} CIG da calcolare (${perimetro}, ${EMBED_MODEL})`);

  // testo indicizzato = oggetto della gara + quello del lotto se aggiunge
  // informazione; nessun prefisso (convenzione RagIndex: solo la query porta
  // l'istruzione)
  const textOf = r =>
    r.oggetto_lotto && r.oggetto_lotto !== r.oggetto_gara ? `${r.oggetto_gara}\n${r.oggetto_lotto}` : r.oggetto_gara;

  // Un run su tutto il dataset dura ORE: un singolo intoppo di Ollama non deve
  // buttare via il lavoro fatto (è già successo: ConnectionRefused a 28k/82k).
  async function embedBatch(texts) {
    let lastErr;
    for (let i = 1; i <= 8; i++) {
      try {
        const res = await fetch(`${OLLAMA}/api/embed`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ model: EMBED_MODEL, input: texts }),
          signal: AbortSignal.timeout(120_000),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const vecs = (await res.json()).embeddings;
        if (!Array.isArray(vecs) || vecs.length !== texts.length) throw new Error("risposta embed incompleta");
        for (const v of vecs) if (v.length !== 1024) throw new Error(`dimensione inattesa: ${v.length}`);
        return vecs;
      } catch (e) {
        lastErr = e;
        if (i < 8) {
          const wait = Math.min(60_000, 2000 * 2 ** (i - 1)); // 2s, 4s, 8s … max 60s
          console.warn(`  ⚠ Ollama: ${e.message ?? e} — ritento tra ${wait / 1000}s (${i}/7)`);
          await new Promise(r => setTimeout(r, wait));
        }
      }
    }
    throw new Error(
      `Ollama irraggiungibile dopo 8 tentativi (${lastErr?.message ?? lastErr}). ` +
        `Gli embeddings già calcolati sono salvi in anac_emb: rilanciando riparte da lì.`,
    );
  }

  const t0 = Date.now();
  let done = 0;
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const vecs = await embedBatch(batch.map(textOf));
    // INSERT append-only: nessuna riscrittura di row group
    const values = batch.map((r, j) => `('${esc(r.cig)}', [${vecs[j].join(",")}]::FLOAT[1024])`).join(",");
    await con.run(`INSERT OR REPLACE INTO embcache.anac_emb (cig, embedding) VALUES ${values}`);
    done += batch.length;
    if (done % (BATCH * 250) === 0 || done === todo.length) {
      const rate = done / ((Date.now() - t0) / 60000);
      const eta = Math.round((todo.length - done) / rate);
      console.log(`  ${done}/${todo.length} (${Math.round(rate)}/min, ~${eta} min rimanenti)`);
    }
  }
}
const embN = (await con.runAndReadAll("SELECT count(*) AS n FROM embcache.anac_emb")).getRowObjects()[0].n;
console.log(`  anac_emb: ${embN} vettori disponibili`);

// --- 5. normalizzazione → anac_cig ----------------------------------------------
// Una riga = un LOTTO (il cig ne è la chiave). Un cig può ricomparire in mesi
// diversi: si tiene la versione più recente per data di pubblicazione. La
// colonna embedding arriva dalla tabella laterale con una LEFT JOIN: nessun
// UPDATE, la tabella nasce completa.

await con.run(`CREATE OR REPLACE TABLE anac_cig_new AS
SELECT
  s.cig AS cig,
  NULLIF(trim(numero_gara), '') AS numero_gara,
  NULLIF(trim(regexp_replace(oggetto_gara, '\\s+', ' ', 'g')), '') AS oggetto_gara,
  NULLIF(trim(regexp_replace(oggetto_lotto, '\\s+', ' ', 'g')), '') AS oggetto_lotto,
  TRY_CAST(importo_complessivo_gara AS DOUBLE) AS importo_complessivo_gara,
  TRY_CAST(importo_lotto AS DOUBLE) AS importo_lotto,
  TRY_CAST(importo_sicurezza AS DOUBLE) AS importo_sicurezza,
  TRY_CAST(n_lotti_componenti AS INTEGER) AS n_lotti_componenti,
  NULLIF(trim(oggetto_principale_contratto), '') AS tipo_contratto,
  NULLIF(trim(stato), '') AS stato,
  NULLIF(trim(settore), '') AS settore,
  NULLIF(trim(luogo_istat), '') AS luogo_istat,
  NULLIF(trim(provincia), '') AS provincia,
  TRY_CAST(data_pubblicazione AS DATE) AS data_pubblicazione,
  TRY_CAST(data_scadenza_offerta AS DATE) AS data_scadenza_offerta,
  TRY_CAST(anno_pubblicazione AS INTEGER) AS anno_pubblicazione,
  NULLIF(trim(tipo_scelta_contraente), '') AS tipo_scelta_contraente,
  NULLIF(trim(modalita_realizzazione), '') AS modalita_realizzazione,
  NULLIF(trim(cf_amministrazione_appaltante), '') AS cf_amministrazione_appaltante,
  NULLIF(trim(denominazione_amministrazione_appaltante), '') AS amministrazione,
  NULLIF(trim(sezione_regionale), '') AS sezione_regionale,
  NULLIF(trim(denominazione_centro_costo), '') AS centro_costo,
  NULLIF(trim(cod_cpv), '') AS cod_cpv,
  NULLIF(trim(descrizione_cpv), '') AS descrizione_cpv,
  TRY_CAST(durata_prevista AS INTEGER) AS durata_prevista_giorni,
  NULLIF(trim(esito), '') AS esito,
  TRY_CAST(data_comunicazione_esito AS DATE) AS data_comunicazione_esito,
  NULLIF(trim(motivo_cancellazione), '') AS motivo_cancellazione,
  TRY_CAST(data_cancellazione AS DATE) AS data_cancellazione,
  NULLIF(trim(flag_pnrr_pnc), '') AS flag_pnrr_pnc,
  NULLIF(trim(cig_collegamento), '') AS cig_collegamento,
  e.embedding AS embedding
FROM stage s
-- il perimetro servito sta nella CONDIZIONE di join (non in un CASE: DuckDB non
-- ammette FLOAT[1024] in un CASE): fuori perimetro il LEFT JOIN dà NULL, così
-- solo le righe ≥ embedMin entrano nella colonna embedding e quindi nell'indice.
-- La cache anac_emb può averne di più; materializzarli tutti gonfierebbe
-- warehouse e indice oltre la RAM del server. embedMin=0 → tutti.
LEFT JOIN embcache.anac_emb e
  ON s.cig = e.cig AND TRY_CAST(s.importo_lotto AS DOUBLE) >= ${embedMin}
WHERE s.cig IS NOT NULL AND trim(s.cig) != ''
QUALIFY row_number() OVER (
  PARTITION BY s.cig
  ORDER BY TRY_CAST(s.data_pubblicazione AS DATE) DESC NULLS LAST
) = 1`);

const norm = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT luogo_istat) AS comuni,
    round(100.0 * count(luogo_istat) / count(*), 1) AS pct_istat,
    count(embedding) AS con_emb FROM anac_cig_new`)
).getRowObjects()[0];
console.log(
  `  ${norm.n} CIG normalizzati — ${norm.pct_istat}% con codice ISTAT su ${norm.comuni} comuni, ${norm.con_emb} con embedding`,
);

await con.run("DROP TABLE IF EXISTS anac_cig");
await con.run("ALTER TABLE anac_cig_new RENAME TO anac_cig");

// --- 6. indice ANN (HNSW) sugli embeddings --------------------------------------
// Senza indice /search fa una scansione completa con cosine su ogni riga: su
// 2,67M vettori sono ~3,3 SECONDI a query (vicino al timeout del servizio),
// contro ~25 ms con l'indice (misurato, recall@10 100% vs forza bruta).
// L'indice appartiene alla TABELLA: il DROP/RENAME qui sopra lo porta via, va
// ricreato a ogni run — dopo lo swap, non prima. vss e il flag di persistenza
// sono già stati caricati all'apertura.
//
// ⚠️ MEMORY_LIMIT OBBLIGATORIO. La build di vss alloca il grafo FUORI dalla
// memoria tracciata da DuckDB: senza un tetto il processo veniva ucciso da OOM
// a 2,67M vettori (log troncato SENZA riga di errore, firma classica del kill).
// Col limite DuckDB comprime il resto e spilla su disco; la build è arrivata a
// ~43 GB di RAM su 60 fisici. In produzione (deploy.sh → 185.58.193.49) va
// tarato sulla RAM DI QUELLA macchina: se ha meno di ~48 GB, o si abbassa qui o
// l'indice non si costruisce.
const hasEmb = Number((await con.runAndReadAll("SELECT count(embedding) AS n FROM anac_cig")).getRowObjects()[0].n);
if (hasEmb > 0) {
  await con.run("SET memory_limit = '40GB'"); // lascia margine ai ~11 GB non tracciati di vss
  await con.run(`SET temp_directory = '${ROOT}duckdb_spill'`);
  const t0 = Date.now();
  await con.run("CREATE INDEX idx_anac_cig_emb ON anac_cig USING HNSW (embedding) WITH (metric = 'cosine')");
  console.log(`  indice HNSW su ${hasEmb} vettori: ${((Date.now() - t0) / 60000).toFixed(1)} min`);
}

// --- 7. riga di catalogo ---------------------------------------------------------

const n = (await con.runAndReadAll("SELECT count(*) AS n FROM anac_cig")).getRowObjects()[0].n;
const emb = (await con.runAndReadAll("SELECT count(*) AS n FROM anac_cig WHERE embedding IS NOT NULL")).getRowObjects()[0].n;
const anni = (
  await con.runAndReadAll("SELECT min(anno_pubblicazione) AS da, max(anno_pubblicazione) AS a FROM anac_cig")
).getRowObjects()[0];
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'anac_cig' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Gare e contratti pubblici — CIG (ANAC)";
const titleEn = "Italian public tenders and contracts — CIG (ANAC)";
const descIt = `Ogni lotto di gara pubblica italiana identificato dal CIG (Codice Identificativo di Gara), dal ${anni.da} al ${anni.a}: oggetto della gara e del lotto, importi, amministrazione appaltante con codice fiscale, comune di esecuzione con codice ISTAT, categoria merceologica CPV, procedura di scelta del contraente, date di pubblicazione e scadenza, esito. Si aggancia ai vocabolari ISTAT tramite luogo_istat. La ricerca semantica copre i lotti di importo maggiore.`;
const descEn = `Every lot of an Italian public tender identified by its CIG code, from ${anni.da} to ${anni.a}: tender and lot subject, amounts, contracting authority with tax code, place of performance with ISTAT municipality code, CPV category, award procedure, publication and deadline dates, outcome. Joins to the ISTAT vocabularies via luogo_istat. Semantic search covers the higher-value lots.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'anac_cig'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('anac_cig', 'dati.anticorruzione.it', 'anac/cig',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.anticorruzione.it/opendata', now(), ${n}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nanac_cig: ${n} CIG (${anni.da}–${anni.a}), ${emb} con embedding`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
