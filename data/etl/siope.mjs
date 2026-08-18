// Ingestione di SPESE ed ENTRATE per CASSA dei COMUNI dai flussi SIOPE
// pubblicati da OpenBDAP (MEF-RGS, licenza CC-BY) → tabelle `siope_spese` e
// `siope_entrate` in DuckDB + righe nel `catalog`. Una riga per (comune,
// anno, categoria): "come spende e quanto incassa il tuo comune", per cassa,
// con serie annuale e dati correnti — il cuore della dashboard "I soldi del
// territorio" (saldo, autonomia finanziaria, multe incluse).
//
// PERCHE' SIOPE e non i bilanci armonizzati per missione: gli schemi
// armonizzati elaborabili di OpenBDAP non sono scaricabili in blocco (il
// prelievo è un wizard con consegna via mail; la serie storica "Gestione
// finanziaria" dei /Data/FET si ferma al 2015 con la classificazione
// pre-armonizzazione). I movimenti SIOPE invece sono sul portale CKAN in
// ~520 dataset (20 regioni × anni dal 2014 × {Spesa, Entrata}) con DUMP CSV
// diretto e arrivano all'ANNO CORRENTE: cassa, non competenza — va detto
// nella descrizione — ma per il cittadino "quanto è entrato e uscito
// davvero" è la domanda giusta.
//
// Fonte (nessuna chiave):
//   indice:  SpodCkanApi package_search, una query per movimento (titoli
//            "ANNO - Regione - SIOPE Movimenti cumulati mensili di <Mov>",
//            risorsa csv = datastore/dump/<uuid>.csv)
//   dump:    ~24MB la regione più piccola; ; -separated, LATIN-1 (si
//            transcodifica a UTF-8 al download), righe = ente × codice
//            gestionale × mese con IMPORTO CUMULATO da inizio anno.
//
// Aggregazione: si tengono i soli COMUNI (Codice Tipologia Ente BDAP = CO),
// per ogni ente il MESE MASSIMO presente nell'anno (12 = anno chiuso; per
// l'anno corrente il cumulato all'ultimo mese pubblicato, salvato in `mese`)
// e si somma per CATEGORIA = livello II del piano dei conti (U.1.03 =
// "Acquisto di beni e servizi", E.3.02 = multe; dict LIV2/LIV2_E qui sotto;
// fallback sul titolo, contato nel log). Nei TOTALI escludere le partite di
// giro: spese 7.01/7.02/0.00, entrate 9.01/9.02/0.00. Codice ISTAT =
// provincia(3)+comune(3) del tracciato, verificato col bridge sui confini.
// Gli anni dal 2021 sono sul NUOVO piano dei conti (NPC); anni molto vecchi
// (≤2016) usano codici pre-armonizzazione e finirebbero nel fallback — per
// questo il default parte da pochi anni fa.
//
// Uso:  bun etl/siope.mjs [--from A] [--to B] [--refresh]
//   --from/--to  intervallo di anni (default: ultimi 3 incluso il corrente)
//   --refresh    riscarica indici e anni; l'ANNO CORRENTE viene comunque
//                riscaricato a ogni run (il cumulato cresce ogni mese)

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/siope/";
const DB = ROOT + "warehouse.duckdb";
const API = "https://bdap-opendata.rgs.mef.gov.it/SpodCkanApi/api/3/action/package_search";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const fromY = args.includes("--from") ? Number(args[args.indexOf("--from") + 1]) : THIS_YEAR - 2;
const toY = args.includes("--to") ? Number(args[args.indexOf("--to") + 1]) : THIS_YEAR;
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// Categorie = livello II del piano dei conti finanziario (D.Lgs 118/2011),
// chiave = "titolo.livello2" estratti dal codice gestionale [UE] T LL ...
// Nomi stabili per norma; le voci non mappate ripiegano sulla descrizione
// del titolo (e il fallback viene contato nel log).
const LIV2_SPESE = {
  "1.01": "Redditi da lavoro dipendente",
  "1.02": "Imposte e tasse a carico dell'ente",
  "1.03": "Acquisto di beni e servizi",
  "1.04": "Trasferimenti correnti",
  "1.05": "Trasferimenti di tributi",
  "1.06": "Fondi perequativi",
  "1.07": "Interessi passivi",
  "1.08": "Altre spese per redditi da capitale",
  "1.09": "Rimborsi e poste correttive delle entrate",
  "1.10": "Altre spese correnti",
  "2.02": "Investimenti fissi lordi e acquisto di terreni",
  "2.03": "Contributi agli investimenti",
  "2.04": "Altri trasferimenti in conto capitale",
  "2.05": "Altre spese in conto capitale",
  "3.01": "Acquisizioni di attività finanziarie",
  "3.02": "Concessione di crediti",
  "3.03": "Altre spese per incremento di attività finanziarie",
  "4.01": "Rimborso di titoli obbligazionari",
  "4.02": "Rimborso di prestiti a breve termine",
  "4.03": "Rimborso di mutui e altri finanziamenti",
  "4.04": "Rimborso di altre forme di indebitamento",
  "5.01": "Chiusura di anticipazioni da tesoriere",
  "7.01": "Uscite per partite di giro",
  "7.02": "Uscite per conto terzi",
  "0.00": "Pagamenti da regolarizzare",
};

const LIV2_ENTRATE = {
  "1.01": "Imposte, tasse e proventi assimilati",
  "1.03": "Fondi perequativi",
  "1.04": "Compartecipazioni di tributi",
  "2.01": "Trasferimenti correnti da Amministrazioni pubbliche",
  "2.02": "Trasferimenti correnti da famiglie",
  "2.03": "Trasferimenti correnti da imprese",
  "2.04": "Trasferimenti correnti da istituzioni sociali private",
  "2.05": "Trasferimenti correnti dall'UE e dal resto del mondo",
  "3.01": "Vendita di beni e servizi e gestione dei beni",
  "3.02": "Proventi da attività di controllo e repressione (sanzioni)",
  "3.03": "Interessi attivi",
  "3.04": "Altre entrate da redditi da capitale",
  "3.05": "Rimborsi e altre entrate correnti",
  "4.01": "Tributi in conto capitale",
  "4.02": "Contributi agli investimenti",
  "4.03": "Altri trasferimenti in conto capitale",
  "4.04": "Alienazione di beni materiali e immateriali",
  "4.05": "Altre entrate in conto capitale",
  "5.01": "Alienazione di attività finanziarie",
  "5.02": "Riscossione di crediti",
  "5.03": "Altre entrate per riduzione di attività finanziarie",
  "6.01": "Emissione di titoli obbligazionari",
  "6.02": "Accensione di prestiti a breve termine",
  "6.03": "Accensione di mutui e altri finanziamenti",
  "6.04": "Altre forme di indebitamento",
  "7.01": "Anticipazioni da istituto tesoriere",
  "9.01": "Entrate per partite di giro",
  "9.02": "Entrate per conto terzi",
  "0.00": "Riscossioni da regolarizzare",
};

// I due flussi: stessa pipeline, tabella e movimento diversi. I file delle
// spese restano `<anno>_<regione>.csv` (cache storica gia' scaricata);
// le entrate aggiungono il suffisso.
const KINDS = [
  { mov: "Spesa", query: "%22cumulati+mensili+di+Spesa%22", index: "index.json", suffix: "", table: "siope_spese", liv2: LIV2_SPESE, giro: "'7.01','7.02','0.00'" },
  { mov: "Entrata", query: "%22cumulati+mensili+di+Entrata%22", index: "index-entrate.json", suffix: "_entrate", table: "siope_entrate", liv2: LIV2_ENTRATE, giro: "'9.01','9.02','0.00'" },
];

mkdirSync(RAW, { recursive: true });
console.log("▸ spese ed entrate per cassa dei comuni (SIOPE via OpenBDAP)");

// --- indice dei dataset (CKAN) ------------------------------------------------
// NB: questo CKAN vuole gli spazi come "+" (con %20 risponde "Dato non
// trovato") ed e' CAPRICCIOSO: la stessa query a volte risponde "Dato non
// trovato" a vuoto — si ritenta con pausa prima di arrendersi, e un indice
// gia' in cache non viene MAI sovrascritto con una risposta vuota.
async function fetchIndex(kind) {
  const indexFile = RAW + kind.index;
  if (refresh || !(await Bun.file(indexFile).exists())) {
    let got = null;
    for (let attempt = 1; attempt <= 5 && !got; attempt++) {
      try {
        const res = await fetch(`${API}?q=${kind.query}&rows=400`, {
          headers: HEADERS,
          signal: AbortSignal.timeout(120_000),
        });
        if (res.ok) {
          const text = await res.text();
          const parsed = JSON.parse(text);
          if (parsed.success && parsed.result?.results?.length) got = text;
        }
      } catch {
        /* rete: si ritenta */
      }
      if (!got && attempt < 5) await new Promise(r => setTimeout(r, 5000 * attempt));
    }
    if (got) await Bun.write(indexFile, got);
    else if (!(await Bun.file(indexFile).exists()))
      throw new Error(`indice CKAN ${kind.mov} non disponibile dopo 5 tentativi`);
    else console.log(`  indice ${kind.mov} non aggiornabile ora: uso la cache`);
  }
  const index = JSON.parse(await Bun.file(indexFile).text());
  if (!index.success || !index.result?.results) {
    throw new Error(`indice CKAN ${kind.mov} in cache non valido — rimuovere raw/siope/${kind.index}`);
  }
  const out = [];
  const re = new RegExp(`^(\\d{4}) - (.+) - SIOPE Movimenti cumulati mensili di ${kind.mov}\\s*$`);
  for (const r of index.result.results) {
    const m = re.exec(r.title || "");
    if (!m) continue;
    const year = Number(m[1]);
    if (year < fromY || year > toY) continue;
    const dump = (r.resources || []).find(x => /datastore\/dump\/.+\.csv$/.test(x.url || ""));
    if (!dump) continue;
    out.push({ year, regione: m[2].trim(), url: dump.url.replace(/^http:/, "https:") });
  }
  out.sort((a, b) => a.year - b.year || a.regione.localeCompare(b.regione));
  return out;
}

// --- download (cache per regione-anno; il corrente si riscarica sempre) --------
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g, "_");

async function download(kind, datasets) {
  const files = [];
  for (const d of datasets) {
    const out = `${RAW}${d.year}_${slug(d.regione)}${kind.suffix}.csv`;
    const cached = await Bun.file(out).exists();
    const mustFetch = refresh || !cached || d.year === THIS_YEAR;
    if (mustFetch) {
      process.stdout.write(`  scarico ${kind.mov} ${d.year} ${d.regione}… `);
      let res;
      try {
        res = await fetch(d.url, { headers: HEADERS, signal: AbortSignal.timeout(600_000) });
      } catch (e) {
        console.log(cached ? "fallito, uso la cache" : "fallito, SALTO");
        if (cached) files.push({ ...d, file: out });
        continue;
      }
      if (!res.ok) {
        console.log(`http ${res.status}${cached ? ", uso la cache" : ", SALTO"}`);
        if (cached) files.push({ ...d, file: out });
        continue;
      }
      // LATIN-1 → UTF-8 (il dump non dichiara charset e contiene accentate)
      const buf = await res.arrayBuffer();
      const text = new TextDecoder("latin1").decode(buf);
      if (!/Codice istat provincia/i.test(text.slice(0, 300))) {
        console.log(`tracciato inatteso${cached ? ", uso la cache" : ", SALTO"}`);
        if (cached) files.push({ ...d, file: out });
        continue;
      }
      await Bun.write(out, text);
      console.log(`${(buf.byteLength / 1048576).toFixed(1)} MB`);
    }
    files.push({ ...d, file: out });
  }
  return files;
}

// --- carico e aggrego ----------------------------------------------------------
async function loadKind(con, kind, files) {
  await con.run(`CREATE OR REPLACE TEMP TABLE liv2_map (codice VARCHAR, categoria VARCHAR)`);
  for (const [k, v] of Object.entries(kind.liv2)) {
    await con.run(`INSERT INTO liv2_map VALUES ('${k}', '${esc(v)}')`);
  }

  // null_padding OBBLIGATORIO: ogni riga del dump termina con ';' (ultima
  // colonna vuota senza nome) e senza padding DuckDB scarta ~25% delle righe
  // — interi comuni, visto che il file e' raggruppato per ente (bug reale:
  // 1113 comuni su 1502 in Lombardia al primo load). E null_padding con
  // newline DENTRO le virgolette (descrizioni multiriga) esige
  // parallel=false: lettura single-thread, piu' lenta ma completa.
  const unions = files
    .map(
      f => `SELECT *, ${f.year} AS anno_ds FROM read_csv('${f.file}',
        delim = ';', header = true, all_varchar = true, null_padding = true,
        quote = '"', escape = '"', parallel = false,
        ignore_errors = true, strict_mode = false)`,
    )
    .join("\n  UNION ALL BY NAME\n  ");

  // Solo COMUNI, solo il movimento del flusso; il mese e' la coda di
  // "2024/07"; categoria dal codice gestionale [UE] T LL x...
  await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
    SELECT
      "Codice istat provincia" || "Codice istat comune" AS codice_istat,
      "Descrizione Ente BDAP" AS ente,
      anno_ds AS anno,
      TRY_CAST(right("Anno/Mese calendario", 2) AS INTEGER) AS mese,
      substr("Codice Gestionale Enti Locali", 2, 1) || '.' || substr("Codice Gestionale Enti Locali", 3, 2) AS liv2,
      "Descrizione Titolo CG" AS titolo,
      TRY_CAST("Importo cumulato" AS DOUBLE) AS importo,
      TRY_CAST("Popolazione ISTAT" AS BIGINT) AS popolazione
    FROM (${unions})
    WHERE "Codice Tipologia Ente BDAP" = 'CO'
      AND "Tipologia del Movimento" = '${kind.mov}'
      AND TRY_CAST("Importo cumulato" AS DOUBLE) IS NOT NULL`);

  await con.run(`CREATE OR REPLACE TABLE ${kind.table} AS
  WITH ultimo AS (
    SELECT codice_istat, anno, max(mese) AS mese FROM raw GROUP BY 1, 2
  ),
  agg AS (
    SELECT r.codice_istat, r.anno, u.mese, r.liv2, any_value(r.titolo) AS titolo,
      any_value(r.ente) AS ente, max(r.popolazione) AS popolazione,
      sum(r.importo) AS importo
    FROM raw r JOIN ultimo u USING (codice_istat, anno)
    WHERE r.mese = u.mese
    GROUP BY 1, 2, 3, 4
  )
  SELECT
    a.codice_istat,
    coalesce(c.comune, a.ente) AS comune,
    c.sigla, c.provincia, c.regione, c.cod_reg,
    a.anno, a.mese,
    a.liv2 AS categoria_codice,
    coalesce(m.categoria, a.titolo) AS categoria,
    a.titolo,
    round(a.importo, 2) AS importo,
    a.popolazione
  FROM agg a
  LEFT JOIN liv2_map m ON m.codice = a.liv2
  LEFT JOIN istat_confini_comuni c ON c.codice_istat = a.codice_istat
  WHERE a.importo != 0`);

  const stat = (
    await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT codice_istat) AS comuni,
      min(anno) AS da, max(anno) AS a,
      round(100.0 * count(*) FILTER (WHERE comune IS NOT NULL AND sigla IS NOT NULL) / count(*), 1) AS bridge,
      round(100.0 * count(*) FILTER (WHERE categoria = titolo) / count(*), 1) AS fallback_pct
      FROM ${kind.table}`)
  ).getRowObjects()[0];
  console.log(
    `  ${kind.table}: ${stat.n} righe — ${stat.comuni} comuni, anni ${stat.da}–${stat.a}, ` +
      `aggancio confini ${stat.bridge}%, categorie non mappate ${stat.fallback_pct}%`,
  );
  if (Number(stat.bridge) < 90) console.warn("  ATTENZIONE: aggancio basso, verificare i codici ISTAT");
  return stat;
}

async function catalogRow(con, kind, stat) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${kind.table}' ORDER BY ordinal_position`,
    )
  ).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

  const isSpese = kind.mov === "Spesa";
  const titleIt = isSpese
    ? "Spesa per cassa dei comuni per categoria (SIOPE, OpenBDAP)"
    : "Entrate per cassa dei comuni per categoria (SIOPE, OpenBDAP)";
  const titleEn = isSpese
    ? "Municipal cash spending by category (SIOPE, OpenBDAP)"
    : "Municipal cash revenue by category (SIOPE, OpenBDAP)";
  const descIt = isSpese
    ? `Pagamenti dei COMUNI italiani per anno e categoria di spesa, anni ${stat.da}–${stat.a} (fonte MEF-RGS OpenBDAP, flussi SIOPE, licenza CC-BY). Una riga per comune/anno/categoria: le ~25 voci del livello II del piano dei conti (redditi da lavoro dipendente, acquisto di beni e servizi, investimenti fissi lordi, interessi passivi, rimborso mutui, …) con l'importo CUMULATO all'ultimo mese pubblicato (colonna mese: 12 = anno chiuso; l'anno corrente e' parziale). Dati di CASSA (pagato, non impegnato). Nei totali escludere le partite di giro (categoria_codice 7.01/7.02/0.00). Agganciata a confini e popolazione via codice_istat: "come spende il tuo comune", pro capite e nel tempo. Il gemello delle entrate e' siope_entrate.`
    : `Incassi dei COMUNI italiani per anno e categoria di entrata, anni ${stat.da}–${stat.a} (fonte MEF-RGS OpenBDAP, flussi SIOPE, licenza CC-BY). Una riga per comune/anno/categoria: le voci del livello II del piano dei conti (imposte tasse e proventi, trasferimenti correnti da PA, vendita di beni e servizi, SANZIONI da controllo e repressione — le multe —, contributi agli investimenti, accensione mutui, …) con l'importo CUMULATO all'ultimo mese pubblicato (colonna mese: 12 = anno chiuso; l'anno corrente e' parziale). Dati di CASSA (incassato, non accertato). Nei totali escludere le partite di giro (categoria_codice 9.01/9.02/0.00). Autonomia finanziaria = (titolo 1 + titolo 3) / entrate correnti (titoli 1+2+3). Il gemello delle spese e' siope_spese.`;
  const descEn = isSpese
    ? `Cash payments of Italian MUNICIPALITIES by year and spending category, years ${stat.da}–${stat.a} (source MEF-RGS OpenBDAP, SIOPE flows, CC-BY). One row per municipality/year/category (~25 level-II items of the harmonized chart of accounts) with the amount CUMULATED to the last published month (mese: 12 = closed year). CASH data (paid, not committed). Exclude pass-through items (categoria_codice 7.01/7.02/0.00) from totals. Revenue twin: siope_entrate.`
    : `Cash revenue of Italian MUNICIPALITIES by year and revenue category, years ${stat.da}–${stat.a} (source MEF-RGS OpenBDAP, SIOPE flows, CC-BY). One row per municipality/year/category (level-II items: taxes, transfers from government, sale of goods and services, FINES from control activity, investment grants, new loans, …) with the amount CUMULATED to the last published month (mese: 12 = closed year). CASH data (collected, not assessed). Exclude pass-through items (categoria_codice 9.01/9.02/0.00) from totals. Financial autonomy = (title 1 + title 3) / current revenue (titles 1+2+3). Spending twin: siope_spese.`;
  await con.run(`DELETE FROM catalog WHERE table_name = '${kind.table}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${kind.table}', 'bdap-opendata.rgs.mef.gov.it', 'rgs/siope-movimenti-${isSpese ? "spesa" : "entrata"}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      'https://bdap-opendata.rgs.mef.gov.it/catalog/RND_SPE_SIO', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);
}

// --- esecuzione -----------------------------------------------------------------
const plans = [];
for (const kind of KINDS) {
  const datasets = await fetchIndex(kind);
  console.log(`  ${kind.mov}: ${datasets.length} dataset nell'intervallo ${fromY}–${toY}`);
  const files = await download(kind, datasets);
  if (files.length === 0) throw new Error(`nessun file SIOPE ${kind.mov} disponibile`);
  plans.push({ kind, files });
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

for (const { kind, files } of plans) {
  const stat = await loadKind(con, kind, files);
  await catalogRow(con, kind, stat);
}

// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
await con.run("CHECKPOINT");
con.closeSync();
console.log("\nsiope: spese + entrate caricate");
