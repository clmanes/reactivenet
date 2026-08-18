// Ingestione dei progetti finanziati con fondi di coesione (UE + Fondo
// Sviluppo e Coesione) → tabella `opencoesione` in DuckDB + riga nel
// `catalog`. Una riga per PROGETTO: titolo, sintesi, importi, comune di
// realizzazione, beneficiario, stato di avanzamento. È il complemento
// naturale di `anac_cig`: ANAC dice chi VINCE gli appalti, OpenCoesione dice
// CHI SPENDE i fondi di sviluppo — la ricerca semantica sull'oggetto del
// progetto chiude il cerchio "chi spende, dove, per fare cosa".
//
// Fonte (licenza CC BY 4.0, nessuna chiave): il portale opencoesione.gov.it
// pubblica un export nazionale UNICO — niente CKAN, niente paginazione:
//   https://opencoesione.gov.it/it/opendata/progetti_esteso.parquet
// (alias stabile: redirige a un file datato tipo
// progetti_esteso_<AAAAMMGG>.parquet, ~260 MB — il nome cambia a ogni
// pubblicazione, quindi si RISOLVE l'URL invece di cablarlo, come già
// facciamo per farmacie/scuole). Esiste anche `.zip` con lo stesso contenuto
// in CSV (~4,5 GB decompresso): il Parquet è tipizzato correttamente
// (numeri come DOUBLE, non stringhe con la virgola) e 15 volte più leggero
// da scaricare — si usa quello.
//
// Aggiornamento: bimestrale (pubblicato ~3 mesi dopo la data di riferimento).
//
// EMBEDDINGS: `OC_TITOLO_PROGETTO` (+ `OC_SINTESI_PROGETTO` quando presente)
// è il corpus semantico. Stesso pattern di anac.mjs: si embedda e indicizza
// solo il perimetro ≥ --embed-min (default 150.000 €, ~169k righe su 1,85M)
// — non per gusto ma per lo stesso VINCOLO DI RAM del server di produzione
// (indice HNSW memory-resident): 169k vettori ≈ 1,5 GB residenti, accanto ai
// ~2,7 GB di anac_cig restano ben dentro i 15 GB disponibili. I vettori
// vivono in un file laterale SUO (opencoesione-emb.duckdb, locale, mai
// deployato) append-only: --embed-min 0 embedda tutto (ore) e resta
// ripartibile.
//
// TRAPPOLE:
//  - un progetto può interessare PIÙ comuni: `COD_COMUNE`/`DEN_COMUNE`
//    diventano allora liste separate da ":::" (es. "015065002:::015065147").
//    Si tiene solo il PRIMO comune (il luogo principale) — un domani
//    `localizzazioni.zip` (dataset satellite, join su COD_LOCALE_PROGETTO)
//    darebbe la scomposizione completa multi-comune, non serve qui;
//  - `COD_COMUNE` non è il codice ISTAT nudo: porta un prefisso di 2-3 cifre
//    (codice regione, zero-padded) davanti ai 6 del codice ISTAT vero
//    (verificato: "015064099" → Serino, codice ISTAT reale "064099") — si
//    prendono gli ultimi 6 caratteri, copertura 99,9% su voc_istat_cities;
//  - il dataset nazionale unico è `progetti_esteso.parquet`: esistono DECINE
//    di export ridondanti per regione/fondo/tema/ciclo (`regioni/`, `fondi/`,
//    …) da NON scaricare, causerebbero doppioni;
//  - `robots.txt` blocca il crawling degli export dai filtri interattivi
//    (`/*/progetti/*.csv`) ma non il bulk ufficiale in `/it/opendata/`;
//  - ~0,8% dei titoli (14.635 righe) porta un carattere "¿" al posto di un
//    apostrofo/accento: è già così nel Parquet ufficiale (verificato — non è
//    un bug di lettura DuckDB), un difetto della fonte da non correggere in
//    silenzio.
//
// Uso:  bun etl/opencoesione.mjs [--refresh] [--skip-embed] [--embed-min N]
//   --refresh      ignora la cache in raw/opencoesione/ e riscarica
//   --skip-embed   salta il calcolo degli embeddings (solo caricamento)
//   --embed-min    importo minimo del progetto per il perimetro servito
//                  (default 150000; l'indice servito deve stare in RAM)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/opencoesione/";
const DB = ROOT + "warehouse.duckdb";
const EMB_DB = ROOT + "opencoesione-emb.duckdb"; // cache dei vettori, fuori dal warehouse
const ALIAS_URL = "https://opencoesione.gov.it/it/opendata/progetti_esteso.parquet";
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const BATCH = 16;

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : null);
const refresh = args.includes("--refresh");
const skipEmbed = args.includes("--skip-embed");
const embedMin = argOf("--embed-min") ?? 150_000;

const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ progetti coesione (UE + Fondo Sviluppo e Coesione) — opencoesione.gov.it");

// --- 1. risolve l'URL datato e scarica (cache in raw/opencoesione/) -------------

const head = await fetch(ALIAS_URL, { method: "HEAD", signal: AbortSignal.timeout(60_000) });
if (!head.ok) throw new Error(`alias progetti_esteso.parquet: HTTP ${head.status}`);
const fileUrl = head.url;
const fileName = fileUrl.split("/").pop();
const localPath = `${RAW}${fileName}`;

if (refresh || !(await Bun.file(localPath).exists())) {
  console.log(`  scarico ${fileName} (${(Number(head.headers.get("content-length") ?? 0) / 1e6).toFixed(0)} MB)`);
  // Trenta minuti, non dieci: il parquet è di 261 MB e il server di OpenCoesione a
  // volte serve sotto i 500 KB/s — con il tetto precedente il download moriva a metà
  // per TimeoutError, che in un run notturno si legge come «la fonte è giù» mentre la
  // fonte sta benissimo. È lo stesso valore che usa opencup, che scarica file dieci
  // volte più grandi dalla stessa classe di portali.
  const res = await fetch(fileUrl, { signal: AbortSignal.timeout(1_800_000) });
  if (!res.ok) throw new Error(`${fileName}: HTTP ${res.status}`);
  await Bun.write(localPath, await res.arrayBuffer());
} else {
  console.log(`  da cache: ${fileName}`);
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database. Serve anche per creare l'indice al passo 5.
await con.run("INSTALL vss");
await con.run("LOAD vss");
await con.run("SET hnsw_enable_experimental_persistence = true");

// cache degli embeddings in un file SUO: locale, mai deployato (pattern anac.mjs)
await con.run(`ATTACH IF NOT EXISTS '${EMB_DB}' AS embcache`);

// --- 2. staging dal parquet (già tipizzato: niente virgole/TRY_CAST) ------------
// solo il PRIMO comune per i progetti multi-comune (":::"-separated, vedi trappole).

await con.run(`CREATE OR REPLACE TEMP TABLE stage AS
SELECT
  COD_LOCALE_PROGETTO AS cod_progetto,
  NULLIF(trim(CUP), '') AS cup,
  NULLIF(trim(OC_TITOLO_PROGETTO), '') AS titolo,
  NULLIF(trim(OC_SINTESI_PROGETTO), '') AS sintesi,
  NULLIF(trim(OC_TEMA_SINTETICO), '') AS tema,
  NULLIF(trim(OC_DESCR_FONTE), '') AS fonte,
  NULLIF(trim(OC_DESCR_CICLO), '') AS ciclo,
  NULLIF(trim(OC_DESCRIZIONE_PROGRAMMA), '') AS programma,
  right(split_part(COD_COMUNE, ':::', 1), 6) AS codice_istat,
  NULLIF(split_part(DEN_COMUNE, ':::', 1), '') AS comune,
  NULLIF(trim(DEN_PROVINCIA), '') AS provincia,
  NULLIF(trim(DEN_REGIONE), '') AS regione,
  NULLIF(trim(OC_MACROAREA), '') AS macroarea,
  FINANZ_TOTALE_PUBBLICO AS finanz_totale_pubblico,
  FINANZ_UE AS finanz_ue,
  FINANZ_STATO_FSC AS finanz_stato_fsc,
  COSTO_REALIZZATO AS costo_realizzato,
  OC_COSTO_COESIONE AS costo_coesione,
  NULLIF(trim(OC_STATO_PROGETTO), '') AS stato_progetto,
  NULLIF(trim(OC_STATO_FINANZIARIO), '') AS stato_finanziario,
  NULLIF(trim(OC_STATO_PROCEDURALE), '') AS stato_procedurale,
  NULLIF(trim(OC_CODFISC_BENEFICIARIO), '') AS cf_beneficiario,
  NULLIF(trim(OC_DENOM_BENEFICIARIO), '') AS beneficiario,
  OC_DATA_INIZIO_PROGETTO AS data_inizio,
  OC_DATA_FINE_PROGETTO_PREVISTA AS data_fine_prevista,
  OC_DATA_FINE_PROGETTO_EFFETTIVA AS data_fine_effettiva,
  DATA_AGGIORNAMENTO AS data_aggiornamento
FROM read_parquet('${localPath}')
WHERE COD_LOCALE_PROGETTO IS NOT NULL`);
const staged = (await con.runAndReadAll("SELECT count(*) AS n FROM stage")).getRowObjects()[0].n;
console.log(`  ${staged} progetti caricati`);

// --- 3. embeddings (tabella laterale, append-only e RIPARTIBILE) ----------------
// Stesso motivo di anac.mjs: un UPDATE per riga su milioni di righe riscrive
// interi row group. embcache.opencoesione_emb sopravvive ai run.

await con.run(`CREATE TABLE IF NOT EXISTS embcache.opencoesione_emb (cod_progetto VARCHAR PRIMARY KEY, embedding FLOAT[1024])`);

if (!skipEmbed) {
  const todo = (
    await con.runAndReadAll(`SELECT s.cod_progetto, s.titolo, s.sintesi FROM stage s
      LEFT JOIN embcache.opencoesione_emb e USING (cod_progetto)
      WHERE e.cod_progetto IS NULL AND s.titolo IS NOT NULL
        AND s.finanz_totale_pubblico >= ${embedMin}
      ORDER BY s.data_aggiornamento DESC`)
  ).getRowObjects();
  const perimetro = embedMin > 0 ? `progetti ≥ ${embedMin.toLocaleString("it-IT")} €` : "TUTTI i progetti";
  console.log(`▸ embeddings: ${todo.length} progetti da calcolare (${perimetro}, ${EMBED_MODEL})`);

  const textOf = r => (r.sintesi && r.sintesi !== r.titolo ? `${r.titolo}\n${r.sintesi}` : r.titolo);

  // Un run su tutto il dataset dura ore: un singolo intoppo di Ollama non deve
  // buttare via il lavoro fatto (pattern anac.mjs).
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
          const wait = Math.min(60_000, 2000 * 2 ** (i - 1));
          console.warn(`  ⚠ Ollama: ${e.message ?? e} — ritento tra ${wait / 1000}s (${i}/7)`);
          await new Promise(r => setTimeout(r, wait));
        }
      }
    }
    throw new Error(
      `Ollama irraggiungibile dopo 8 tentativi (${lastErr?.message ?? lastErr}). ` +
        `Gli embeddings già calcolati sono salvi in opencoesione_emb: rilanciando riparte da lì.`,
    );
  }

  const t0 = Date.now();
  let done = 0;
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const vecs = await embedBatch(batch.map(textOf));
    const values = batch.map((r, j) => `('${esc(r.cod_progetto)}', [${vecs[j].join(",")}]::FLOAT[1024])`).join(",");
    await con.run(`INSERT OR REPLACE INTO embcache.opencoesione_emb (cod_progetto, embedding) VALUES ${values}`);
    done += batch.length;
    if (done % (BATCH * 250) === 0 || done === todo.length) {
      const rate = done / ((Date.now() - t0) / 60000);
      const eta = Math.round((todo.length - done) / rate);
      console.log(`  ${done}/${todo.length} (${Math.round(rate)}/min, ~${eta} min rimanenti)`);
    }
  }
}
const embN = (await con.runAndReadAll("SELECT count(*) AS n FROM embcache.opencoesione_emb")).getRowObjects()[0].n;
console.log(`  opencoesione_emb: ${embN} vettori disponibili`);

// --- 4. tabella finale, embedding via LEFT JOIN (nessun UPDATE per riga) -------

await con.run(`CREATE OR REPLACE TABLE opencoesione_new AS
SELECT s.*, e.embedding AS embedding
FROM stage s
-- il perimetro servito sta nella CONDIZIONE di join, non in un CASE (DuckDB non
-- ammette FLOAT[1024] in un CASE): fuori perimetro il LEFT JOIN dà NULL.
LEFT JOIN embcache.opencoesione_emb e
  ON s.cod_progetto = e.cod_progetto AND s.finanz_totale_pubblico >= ${embedMin}`);

await con.run("DROP TABLE IF EXISTS opencoesione");
await con.run("ALTER TABLE opencoesione_new RENAME TO opencoesione");

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat,
    count(DISTINCT codice_istat) AS comuni, count(embedding) AS con_emb,
    round(sum(finanz_totale_pubblico) / 1e9, 1) AS mld
    FROM opencoesione`)
).getRowObjects()[0];
console.log(
  `  opencoesione: ${stat.n} progetti — ${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% con codice ISTAT ` +
    `su ${stat.comuni} comuni, ${stat.con_emb} con embedding, ${stat.mld} mld € finanziati`,
);

// --- 5. indice ANN (HNSW) sugli embeddings --------------------------------------
// Vedi anac.mjs per la spiegazione completa (memory_limit obbligatorio, l'indice
// appartiene alla tabella e va ricreato dopo lo swap sopra, non prima).
const hasEmb = Number((await con.runAndReadAll("SELECT count(embedding) AS n FROM opencoesione")).getRowObjects()[0].n);
if (hasEmb > 0) {
  await con.run("SET memory_limit = '40GB'");
  await con.run(`SET temp_directory = '${ROOT}duckdb_spill'`);
  const t0 = Date.now();
  await con.run("CREATE INDEX idx_opencoesione_emb ON opencoesione USING HNSW (embedding) WITH (metric = 'cosine')");
  console.log(`  indice HNSW su ${hasEmb} vettori: ${((Date.now() - t0) / 60000).toFixed(1)} min`);
}

// --- 6. riga di catalogo ----------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'opencoesione' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Progetti finanziati dai fondi di coesione (OpenCoesione)";
const titleEn = "EU cohesion and development fund projects (OpenCoesione)";
const descIt = `Progetti finanziati con fondi di coesione (Fondi UE FESR/FSE/FEASR/FEAMP + Fondo Sviluppo e Coesione), fonte opencoesione.gov.it — Presidenza del Consiglio, CC BY 4.0. Una riga per progetto: titolo e sintesi in chiaro (ricerca semantica), tema, comune di realizzazione con codice ISTAT, importi finanziati e rendicontati, beneficiario con codice fiscale, stato di avanzamento, date. Il complemento di anac_cig lato SPESA: chi finanzia cosa, dove.`;
const descEn = `Projects financed with cohesion funds (EU FESR/FSE/FEASR/FEAMP + national Development and Cohesion Fund), source opencoesione.gov.it — Prime Minister's Office, CC BY 4.0. One row per project: plain-text title and summary (semantic search), theme, implementing municipality with ISTAT code, financed and reported amounts, beneficiary with tax code, progress status, dates. The spending-side complement of anac_cig: who funds what, where.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'opencoesione'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('opencoesione', 'opencoesione.gov.it', 'opencoesione/progetti',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://opencoesione.gov.it/it/opendata/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nopencoesione: ${stat.n} progetti, ${stat.con_emb} con embedding`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
