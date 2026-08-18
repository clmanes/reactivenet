// Ingestione degli ALUNNI ISCRITTI per comune/grado/anno (MIUR — Portale
// Unico dei Dati della Scuola) → tabella `iscrizioni_scolastiche` in DuckDB +
// riga nel `catalog`. Una riga per (comune, grado, anno scolastico): quadro
// attuale e trend pluriennale delle iscrizioni. Completa `scuole` (anagrafica,
// senza numeri) e si aggancia a `dispersione_scolastica`/`invalsi` sullo
// stesso grado di istruzione.
//
// Fonte (licenza IODL 2.0, nessuna chiave):
//   https://dati.istruzione.it/opendata/opendata/catalogo/elements1/leaf/
//     ?datasetId=DS0010ALUCORSOETASTA
// UN FILE PER ANNO SCOLASTICO (non un unico file multi-anno), 10 anni
// disponibili (2015/16-2024/25): si scaricano tutti, si scelgono con un
// glob su DuckDB (stesso schema di colonne in ogni file).
//
// TRAPPOLE:
//  - il file è per SINGOLA SCUOLA STATALE (CODICESCUOLA) senza comune: il
//    codice ISTAT si ottiene per JOIN su `scuole.codice_scuola` (l'anagrafe
//    già ingerita da scuole.mjs, che risolve il codice catastale → ISTAT) —
//    le scuole non presenti nell'anagrafe corrente (istituti chiusi negli
//    anni passati) restano senza comune, non un bug;
//  - scuola dell'INFANZIA esplicitamente assente da questo dataset (la fonte
//    la pubblica in una famiglia di dataset separata, DS111x, non integrata
//    qui): solo primaria, secondaria I grado, secondaria II grado;
//  - si aggrega SOMMANDO su ANNOCORSO e FASCIAETA (non essenziali per un
//    quadro comune/grado/anno, moltiplicherebbero le righe senza aggiungere
//    valore) — chi serve il dettaglio per anno di corso lo trova invece in
//    ALUSECGRADOINDSTA (non integrato: indirizzo di studio, dataset a parte);
//  - solo scuola STATALE: la fonte ha un dataset gemello per le paritarie
//    (ALUCORSOETAPAR, stesso schema) non integrato qui — coerente con
//    `scuole`, che è anch'essa solo statale.
//
// Uso:  bun etl/iscrizioni.mjs [--refresh]
//   --refresh  ignora la cache in raw/iscrizioni/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/iscrizioni/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://dati.istruzione.it";
const DATASET_PAGE = `${HOST}/opendata/opendata/catalogo/elements1/leaf/?datasetId=DS0010ALUCORSOETASTA`;
const FILE_BASE = `${HOST}/opendata/opendata/catalogo/elements1/`;
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ alunni iscritti per comune/grado/anno (MIUR — Portale Unico dei Dati della Scuola)");

// --- 1. risolve e scarica TUTTI i file annuali (cache in raw/iscrizioni/) -----------

const pageRes = await fetch(DATASET_PAGE, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
if (!pageRes.ok) throw new Error(`pagina dataset: HTTP ${pageRes.status}`);
const pageHtml = await pageRes.text();
const names = [...new Set([...pageHtml.matchAll(/ALUCORSOETASTA\d+\.csv/gi)].map(m => m[0]))].sort();
if (!names.length) throw new Error("nessun file ALUCORSOETASTA trovato nella pagina");
console.log(`  ${names.length} annualità trovate`);

for (const name of names) {
  const path = `${RAW}${name}`;
  if (refresh || !(await Bun.file(path).exists())) {
    const res = await fetch(FILE_BASE + name, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
    if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
    await Bun.write(path, await res.arrayBuffer());
    console.log(`  scaricato ${name}`);
  }
}
console.log("  file annuali pronti (cache)");

// --- 2. caricamento: glob su tutti i file, stesso schema di colonne ----------------

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TABLE iscrizioni_scolastiche AS
WITH raw AS (
  SELECT ANNOSCOLASTICO AS anno_scolastico, CODICESCUOLA AS codice_scuola,
    ORDINESCUOLA AS grado, TRY_CAST(ALUNNI AS BIGINT) AS alunni
  FROM read_csv('${RAW}ALUCORSOETASTA*.csv', header = true, all_varchar = true, union_by_name = true)
)
SELECT
  r.anno_scolastico,
  s.codice_istat,
  s.comune,
  s.sigla,
  s.provincia,
  s.regione,
  CASE r.grado
    WHEN 'SCUOLA PRIMARIA' THEN 'Primaria'
    WHEN 'SCUOLA SECONDARIA I GRADO' THEN 'Secondaria I grado'
    WHEN 'SCUOLA SECONDARIA II GRADO' THEN 'Secondaria II grado'
    ELSE r.grado
  END AS grado,
  sum(r.alunni) AS alunni
FROM raw r
LEFT JOIN scuole s ON s.codice_scuola = r.codice_scuola
GROUP BY r.anno_scolastico, s.codice_istat, s.comune, s.sigla, s.provincia, s.regione, r.grado`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat, count(DISTINCT anno_scolastico) AS anni,
    min(anno_scolastico) AS da, max(anno_scolastico) AS a,
    (SELECT sum(alunni) FROM iscrizioni_scolastiche WHERE anno_scolastico = (SELECT max(anno_scolastico) FROM iscrizioni_scolastiche)) AS alunni_ultimo_anno
    FROM iscrizioni_scolastiche`)
).getRowObjects()[0];
console.log(
  `  iscrizioni_scolastiche: ${stat.n} righe — ${stat.anni} anni scolastici (${stat.da}–${stat.a}), ` +
    `${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% agganciate al comune, ` +
    `${Number(stat.alunni_ultimo_anno).toLocaleString("it-IT")} alunni nell'ultimo anno (${stat.a})`,
);

// --- 3. riga di catalogo -----------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'iscrizioni_scolastiche' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Alunni iscritti per comune, grado e anno (MIUR)";
const titleEn = "Enrolled students by municipality, grade and year (MIUR)";
const descIt = `Numero di alunni iscritti nelle scuole statali per comune, grado (primaria, secondaria I grado, secondaria II grado) e anno scolastico, dall'a.s. ${stat.da} al ${stat.a} (fonte MIUR — Portale Unico dei Dati della Scuola, Open Data IODL 2.0). Aggregato dall'anagrafe per-scuola sommando su anno di corso e fascia d'età; il comune deriva dal join con l'anagrafe scuole (\`scuole.codice_scuola\`). Solo scuola statale, scuola dell'infanzia esclusa dalla fonte. Il quadro numerico che completa \`scuole\` (anagrafica) e si incrocia con \`dispersione_scolastica\` e \`invalsi\` sullo stesso grado di istruzione.`;
const descEn = `Number of students enrolled in state schools by municipality, grade (primary, lower secondary, upper secondary) and school year, from ${stat.da} to ${stat.a} (source MIUR — School Data Portal, Open Data IODL 2.0). Aggregated from the per-school registry, summed over course year and age band; municipality comes from a join with the school registry (\`scuole.codice_scuola\`). State schools only, kindergarten excluded by the source. The enrollment counterpart to \`scuole\` (registry), cross-referenceable with \`dispersione_scolastica\` and \`invalsi\` at the same education level.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'iscrizioni_scolastiche'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('iscrizioni_scolastiche', 'dati.istruzione.it', 'miur/alunni-iscritti-corso-eta',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.istruzione.it/opendata/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\niscrizioni_scolastiche: ${stat.n} righe (${stat.anni} anni scolastici)`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
