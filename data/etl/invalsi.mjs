// Ingestione dei risultati delle prove INVALSI aggregati per comune (INVALSI
// — Servizio Statistico, dati aperti) → tabella `invalsi` in DuckDB + riga
// nel `catalog`. Una riga per comune/grado/materia con il punteggio medio e
// la partecipazione: qualità dell'istruzione per territorio, incrociabile
// con scuole, redditi e demografia.
//
// Fonte (licenza CC BY 4.0 IT, nessuna registrazione), un file ZIP con la
// serie storica completa + un tracciato colonne:
//   https://serviziostatistico.invalsi.it/download/1023/punteggi-e-percentuale-
//     di-studenti-nei-livelli-di-competenza-per-ripartizioni-territoriali-e-
//     caratteristiche-di-contesto/14206/report_generale_agg_2025.zip
//
// TRAPPOLE:
//  - il dato PER SINGOLA SCUOLA è coperto da segreto statistico: il livello
//    più fine pubblicato è "Comune istituto principale" — e SOLO per i
//    comuni sopra la soglia minima di studenti (~900 su 7900, i centri più
//    popolati). Copertura parziale per disegno, non un bug dell'ETL;
//  - NESSUN codice provincia nel file: la disambiguazione si fa per
//    nome-comune-univoco-nazionale (fallback di scuole.mjs, qui l'UNICA
//    via — non essendoci una sigla come nel crosswalk delle elezioni);
//  - encoding NON utf-8/latin-1 puro (accenti in un charset esteso):
//    `ignore_errors = true` scarta le poche righe con byte non validi;
//  - numeri con virgola decimale; "888" è il sentinel INVALSI per "dato non
//    applicabile/non disponibile" → NULL;
//  - si tiene solo l'ANNO PIÙ RECENTE e aggregazione='Totale' (non le
//    scomposizioni per genere/nativo/straniero, che moltiplicherebbero le
//    righe).
//
// Uso:  bun etl/invalsi.mjs [--refresh]
//   --refresh  ignora la cache in raw/invalsi/ e riscarica (file da ~40MB)

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/invalsi/";
const DB = ROOT + "warehouse.duckdb";
const ZIP_URL =
  "https://serviziostatistico.invalsi.it/download/1023/punteggi-e-percentuale-di-studenti-nei-livelli-di-competenza-per-ripartizioni-territoriali-e-caratteristiche-di-contesto/14206/report_generale_agg_2025.zip";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

mkdirSync(RAW, { recursive: true });
console.log("▸ risultati INVALSI per comune (INVALSI — Servizio Statistico)");

let csv = `${RAW}dati.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const res = await fetch(ZIP_URL, { signal: AbortSignal.timeout(180_000) });
  if (!res.ok) throw new Error(`INVALSI zip: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  const entries = unzipSync(buf, { filter: f => f.name.toLowerCase().endsWith(".csv") });
  const name = Object.keys(entries)[0];
  if (!name) throw new Error("nessun csv nello zip INVALSI");
  await Bun.write(csv, entries[name]);
} else {
  console.log("  da cache");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig) non si
// ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT tocca
// tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const READ = `read_csv('${csv}', delim = ';', header = true, all_varchar = true, ignore_errors = true, null_padding = true)`;

await con.run(`CREATE OR REPLACE TEMP TABLE raw AS
  SELECT Denominazione AS comune_f, Grado AS grado, Materia AS materia, Anno AS anno,
    NULLIF(Punteggio_percentuale_medio, '888') AS punteggio_f,
    NULLIF(Percentuale_partecipazione, '888') AS partecip_f
  FROM ${READ}
  WHERE Aggregato_territoriale = 'Comune istituto principale' AND aggregazione = 'Totale'
    AND Anno = (SELECT max(Anno) FROM ${READ} WHERE Aggregato_territoriale = 'Comune istituto principale')`);

const num = c => `TRY_CAST(replace(${c}, ',', '.') AS DOUBLE)`;

// codice ISTAT per nome-comune-univoco-nazionale (nessuna provincia nel file
// per disambiguare, a differenza di scuole/elezioni)
await con.run(`CREATE OR REPLACE TABLE invalsi AS
WITH conf AS (
  SELECT codice_istat, comune, sigla, provincia, regione, ${N("comune")} AS cn FROM istat_confini_comuni
),
uni AS (
  SELECT cn, any_value(codice_istat) AS ci FROM conf GROUP BY cn HAVING count(*) = 1
),
matched AS (
  SELECT r.*, u.ci AS codice_istat FROM raw r LEFT JOIN uni u ON u.cn = ${N("r.comune_f")}
)
SELECT
  m.codice_istat,
  coalesce(g.comune, NULLIF(trim(m.comune_f), '')) AS comune,
  g.sigla, g.provincia, g.regione,
  m.anno, m.grado, m.materia,
  round(${num("m.punteggio_f")}, 1) AS punteggio_medio,
  round(${num("m.partecip_f")}, 1) AS percentuale_partecipazione
FROM matched m
LEFT JOIN istat_confini_comuni g ON g.codice_istat = m.codice_istat`);

const stat2 = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat, count(DISTINCT codice_istat) AS comuni,
    any_value(anno) AS anno FROM invalsi`)
).getRowObjects()[0];
console.log(
  `  invalsi: ${stat2.n} righe — ${stat2.comuni} comuni (anno ${stat2.anno}), ` +
    `${((Number(stat2.con_istat) / Number(stat2.n)) * 100).toFixed(1)}% agganciate al codice ISTAT`,
);
console.log("  copertura PARZIALE per disegno: solo i comuni sopra la soglia minima di studenti INVALSI");

// --- riga di catalogo ------------------------------------------------------------
const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'invalsi' AND column_name != 'embedding' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Risultati prove INVALSI per comune (INVALSI)";
const titleEn = "INVALSI standardized test results by municipality (INVALSI)";
const descIt = `Punteggi medi delle prove INVALSI aggregati per comune (istituto principale), anno scolastico ${stat2.anno} (fonte INVALSI — Servizio Statistico, CC BY 4.0 IT): punteggio percentuale medio e percentuale di partecipazione per grado scolastico (2ª/5ª primaria, 3ª secondaria I grado, 2ª secondaria II grado) e materia (Italiano, Matematica, Inglese lettura/ascolto). COPERTURA PARZIALE per disegno: pubblicato solo per i comuni sopra la soglia minima di studenti testati (segreto statistico sotto soglia). Si aggancia per nome comune a popolazione, redditi e scuole.`;
const descEn = `Average INVALSI standardized test scores aggregated by municipality (main school site), school year ${stat2.anno} (source INVALSI — Statistical Service, CC BY 4.0 IT): average percentage score and participation rate by grade (2nd/5th primary, 3rd lower secondary, 2nd upper secondary) and subject (Italian, Mathematics, English reading/listening). PARTIAL COVERAGE by design: published only for municipalities above the minimum tested-student threshold (statistical secrecy below it). Joined by municipality name to population, income and schools data.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'invalsi'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('invalsi', 'serviziostatistico.invalsi.it', 'invalsi/punteggi-comune',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://serviziostatistico.invalsi.it/en/catalogo-dati/', now(), ${Number(stat2.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\ninvalsi: ${stat2.n} righe (${stat2.comuni} comuni, anno ${stat2.anno})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
