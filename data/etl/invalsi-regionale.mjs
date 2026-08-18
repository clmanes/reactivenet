// Ingestione dei risultati INVALSI CAMPIONARI per regione/area geografica
// (INVALSI — Servizio Statistico) → tabella `invalsi_regionale` in DuckDB +
// riga nel `catalog`. Una riga per (territorio, grado, materia, anno):
// punteggio medio, errore standard, percentili. Completa `invalsi` (che è
// censuario ma solo per COMUNE, solo l'anno più recente) con la dimensione
// che a quello manca: la SERIE STORICA per REGIONE/area geografica.
//
// Fonte (licenza CC BY 4.0 IT, nessuna registrazione — pagina "Open Data",
// distinta dall'archivio microdati a registrazione):
//   https://serviziostatistico.invalsi.it/it/invalsi_ss_data/
//     dati-regionali-di-area-geografica-e-nazionali-campionari/
//   → dati-campione-2013-2023.csv
//
// TRAPPOLE:
//  - delimitatore `;`, separatore decimale `,` (formato italiano): serve
//    `decimal_separator=','` in read_csv, non il default punto;
//  - `Ripartizione_geografica` mescola TRE livelli nella stessa colonna
//    (Italia, le 5 aree geografiche, le 19 regioni + le 2 PROVINCE autonome
//    di Trento/Bolzano al posto del Trentino-Alto Adige unificato): si
//    classifica con `livello` e si aggancia a `istat_confini_regioni` SOLO
//    le righe di livello 'regione' (join per nome, non serve tabella alias:
//    i nomi INVALSI combaciano già con quelli ISTAT del warehouse);
//  - CAMPIONARIO, non censuario: è un sondaggio su un campione di scuole,
//    non il totale degli studenti come `invalsi` (comune) — i due dataset
//    NON si sommano, si affiancano (comune = dettaglio fine ma solo ultimo
//    anno; regionale = meno fine ma 11 anni di serie storica);
//  - NESSUNA rottura per indirizzo di studio (liceo/tecnico/professionale)
//    nella fonte open data verificata: solo macroarea/regione. Chi cerca
//    quel dettaglio deve rivolgersi ai microdati campionari INVALSI (a
//    registrazione), non integrati qui;
//  - a.s. 2019/2020 assente (niente prove quell'anno, emergenza COVID): un
//    buco della fonte, non dell'ETL;
//  - il sentinel di "dato non disponibile" è `999`, applicato dove capita
//    (non sempre): `NULLIF` su tutte le colonne numeriche.
//
// Uso:  bun etl/invalsi-regionale.mjs [--refresh]
//   --refresh  ignora la cache in raw/invalsi-regionale/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/invalsi-regionale/";
const DB = ROOT + "warehouse.duckdb";
const CSV_URL =
  "https://serviziostatistico.invalsi.it/en/download/487/dati-regionali-di-area-geografica-e-nazionali-campionari/8554/dati-campione-2013-2023.csv/";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ risultati INVALSI campionari per regione/area geografica (INVALSI — Servizio Statistico)");

const csv = `${RAW}dati-campione.csv`;
if (refresh || !(await Bun.file(csv).exists())) {
  const res = await fetch(CSV_URL, { signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`CSV: HTTP ${res.status}`);
  await Bun.write(csv, await res.arrayBuffer());
  console.log("  scaricato");
} else {
  console.log("  da cache");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const AREE = ["Nord Ovest", "Nord Est", "Centro", "Sud", "Sud e Isole"];
const PROVINCE_AUTONOME = ["Prov. Aut. Bolzano (l. it.)", "Prov. Aut. Trento"];
const areeValues = AREE.map(a => `'${esc(a)}'`).join(", ");
const provAutValues = PROVINCE_AUTONOME.map(a => `'${esc(a)}'`).join(", ");

const READ = `read_csv('${csv}', delim = ';', header = true, all_varchar = true)`;

await con.run(`CREATE OR REPLACE TABLE invalsi_regionale AS
WITH raw AS (
  SELECT
    Anno AS anno,
    TRY_CAST(Grado AS TINYINT) AS grado_cod,
    Materia AS materia,
    Ripartizione_geografica AS territorio,
    NULLIF(TRY_CAST(replace(Punteggio_WLE, ',', '.') AS DOUBLE), 999) AS punteggio_medio,
    NULLIF(TRY_CAST(replace(ES, ',', '.') AS DOUBLE), 999) AS errore_standard,
    NULLIF(TRY_CAST(replace(Deviazione_standard_WLE, ',', '.') AS DOUBLE), 999) AS deviazione_standard,
    NULLIF(TRY_CAST(replace(Percentile5, ',', '.') AS DOUBLE), 999) AS percentile5,
    NULLIF(TRY_CAST(replace(Percentile25, ',', '.') AS DOUBLE), 999) AS percentile25,
    NULLIF(TRY_CAST(replace(Percentile75, ',', '.') AS DOUBLE), 999) AS percentile75,
    NULLIF(TRY_CAST(replace(Percentile95, ',', '.') AS DOUBLE), 999) AS percentile95
  FROM ${READ}
)
SELECT
  r.anno,
  CASE r.grado_cod
    WHEN 2 THEN '2ª primaria' WHEN 5 THEN '5ª primaria' WHEN 8 THEN '3ª secondaria I grado'
    WHEN 10 THEN '2ª secondaria II grado' WHEN 13 THEN '5ª secondaria II grado' ELSE NULL
  END AS grado,
  r.materia,
  CASE
    WHEN r.territorio = 'Italia' THEN 'nazionale'
    WHEN r.territorio IN (${areeValues}) THEN 'area_geografica'
    WHEN r.territorio IN (${provAutValues}) THEN 'provincia_autonoma'
    ELSE 'regione'
  END AS livello,
  r.territorio,
  CASE WHEN r.territorio NOT IN (${areeValues}, ${provAutValues}) AND r.territorio != 'Italia'
    THEN g.regione ELSE NULL END AS regione,
  r.punteggio_medio, r.errore_standard, r.deviazione_standard,
  r.percentile5, r.percentile25, r.percentile75, r.percentile95
FROM raw r
LEFT JOIN istat_confini_regioni g ON g.regione = r.territorio`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT territorio) AS territori,
    count(DISTINCT anno) AS anni, min(anno) AS da, max(anno) AS a,
    count(*) FILTER (WHERE livello = 'regione' AND regione IS NULL) AS regioni_non_agganciate
    FROM invalsi_regionale`)
).getRowObjects()[0];
console.log(
  `  invalsi_regionale: ${stat.n} righe — ${stat.territori} territori, ${stat.anni} anni (${stat.da}–${stat.a})`,
);
if (Number(stat.regioni_non_agganciate) > 0) console.warn(`  ATTENZIONE: ${stat.regioni_non_agganciate} righe di livello regione non agganciate — verificare i nomi`);

// --- riga di catalogo ------------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'invalsi_regionale' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Risultati prove INVALSI per regione e area geografica (INVALSI)";
const titleEn = "INVALSI standardized test results by region and geographic area (INVALSI)";
const descIt = `Punteggi medi campionari delle prove INVALSI per regione, area geografica (Nord Ovest, Nord Est, Centro, Sud, Sud e Isole) e Italia, anni ${stat.da}–${stat.a} (fonte INVALSI — Servizio Statistico, Open Data CC BY 4.0 IT, nessuna registrazione): punteggio medio (scala WLE), errore standard, deviazione standard, percentili 5/25/75/95, per grado (2ª/5ª primaria, 3ª secondaria I grado, 2ª/5ª secondaria II grado) e materia (Italiano, Matematica, Inglese lettura/ascolto). CAMPIONARIO (non censuario): completa \`invalsi\` (comune, censuario, solo ultimo anno) con la serie storica regionale. A.s. 2019/2020 assente (niente prove, emergenza COVID). Nessuna rottura per indirizzo di studio nella fonte open data.`;
const descEn = `Average INVALSI standardized-test sample scores by region, geographic area (North-West, North-East, Centre, South, South and Islands) and Italy, years ${stat.da}–${stat.a} (source INVALSI — Statistical Service, Open Data CC BY 4.0 IT, no registration): average score (WLE scale), standard error, standard deviation, 5th/25th/75th/95th percentiles, by grade (2nd/5th primary, 3rd lower secondary, 2nd/5th upper secondary) and subject (Italian, Mathematics, English reading/listening). SAMPLE-based (not census): complements \`invalsi\` (municipality-level, census, latest year only) with the regional historical series. School year 2019/2020 missing (no tests, COVID). No school-track breakdown in the open-data source.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'invalsi_regionale'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('invalsi_regionale', 'serviziostatistico.invalsi.it', 'invalsi/dati-campione-regionale',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://serviziostatistico.invalsi.it/it/invalsi_ss_data/dati-regionali-di-area-geografica-e-nazionali-campionari/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\ninvalsi_regionale: ${stat.n} righe (anni ${stat.da}–${stat.a})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
