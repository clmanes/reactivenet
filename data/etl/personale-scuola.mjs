// Ingestione del PERSONALE SCOLASTICO di ruolo (MIUR — Portale Unico dei Dati
// della Scuola) → tabella `personale_scuola` in DuckDB + riga nel `catalog`.
// Una riga per (provincia, categoria, grado?, tipo posto?, fascia età, anno):
// docenti e personale ATA titolari. Il lato "chi insegna" che completa
// `iscrizioni_scolastiche` (chi studia) — rapporto alunni/docenti per
// territorio.
//
// Fonte (licenza IODL 2.0, nessuna chiave), area "Personale Scuola":
//   https://dati.istruzione.it/opendata/opendata/catalogo/elements1/leaf/
//     ?datasetId=DS0600DOCTIT   (docenti titolari — 10 anni)
//     ?datasetId=DS0610ATATIT   (personale ATA titolare — 10 anni)
// UN FILE PER ANNO SCOLASTICO; il primo anno (2015/16) ha un prefisso
// bizzarro nel nome ("AS1516DOCTIT...", tutti gli altri anni sono lisci
// "DOCTIT..."): si estraggono i link con un'unica regex che tollera
// entrambe le forme, non si assume un pattern fisso.
//
// SOLO TITOLARI: la fonte ha anche un dataset "supplenti" (DS0620DOCSUP, poi
// rinominato/sostituito da DS9999DOCSUPXXV dal 2023/24 — due famiglie
// diverse per lo stesso fenomeno, con schema leggermente diverso e uno
// switch a metà serie storica): non integrato qui per tenere la serie
// pulita e comparabile su tutti e 10 gli anni. Chi vuole il turnover
// precariato lo trova nella fonte, non in questo warehouse.
//
// TRAPPOLE:
//  - granularità PROVINCIA, non comune né singola scuola: la fonte non
//    pubblica il personale a un livello più fine;
//  - `PROVINCIA` è un nome testuale maiuscolo ("FORLI'-CESENA", "SUD
//    SARDEGNA"), nessun codice: si aggancia a `istat_confini_province` per
//    nome NORMALIZZATO (stesso pattern `N()` di scuole.mjs/aci-veicoli.mjs);
//  - i due file hanno schemi diversi: DOCTIT ha grado e tipo posto
//    (NORMALE/SOSTEGNO), ATATIT no (il personale ATA non si分 per grado) —
//    unificati in una tabella con `categoria` discriminante e colonne
//    grado/tipo_posto NULL per le righe ATA (il personale ATA non è
//    assegnato a un grado specifico);
//  - i conteggi sono per genere (maschi/femmine): si tiene sia il totale sia
//    il dettaglio, non si perde informazione sommando;
//  - alcune annualità scrivono la provincia in forma abbreviata o con un
//    refuso rispetto al nome ISTAT esteso ("REGGIO EMILIA" per "Reggio
//    nell'Emilia", "BARLETTA-ADRIA-TRANI" — refuso della fonte, manca la
//    "n" di Andria): tabella di alias editoriale verificata a mano: le
//    province SARDE abolite dalla riforma 2016 (Olbia-Tempio, Medio
//    Campidano, Ogliastra, Carbonia-Iglesias) restano invece SENZA alias
//    — sono dati storici di anni in cui esistevano davvero, non un refuso.
//
// Uso:  bun etl/personale-scuola.mjs [--refresh]
//   --refresh  ignora la cache in raw/personale-scuola/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/personale-scuola/";
const DB = ROOT + "warehouse.duckdb";
const HOST = "https://dati.istruzione.it";
const FILE_BASE = `${HOST}/opendata/opendata/catalogo/elements1/`;
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const N = x => `regexp_replace(upper(strip_accents(${x})), '[^A-Z0-9]', '', 'g')`;

mkdirSync(RAW, { recursive: true });
console.log("▸ personale scolastico titolare (MIUR — Portale Unico dei Dati della Scuola)");

async function resolveNames(datasetId, prefix) {
  const url = `${HOST}/opendata/opendata/catalogo/elements1/leaf/?datasetId=${datasetId}`;
  const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`${datasetId}: HTTP ${res.status}`);
  const html = await res.text();
  const names = [...new Set([...html.matchAll(new RegExp(`href="([A-Za-z0-9]*${prefix}\\d+\\.csv)"`, "gi"))].map(m => m[1]))];
  if (!names.length) throw new Error(`${datasetId}: nessun file ${prefix} trovato`);
  return names.sort();
}

async function downloadAll(names) {
  const paths = [];
  for (const name of names) {
    const path = `${RAW}${name}`;
    if (refresh || !(await Bun.file(path).exists())) {
      const res = await fetch(FILE_BASE + name, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
      if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
      await Bun.write(path, await res.arrayBuffer());
      console.log(`  scaricato ${name}`);
    }
    paths.push(path);
  }
  return paths;
}

const docNames = await resolveNames("DS0600DOCTIT", "DOCTIT");
const ataNames = await resolveNames("DS0610ATATIT", "ATATIT");
console.log(`  ${docNames.length} annualità docenti, ${ataNames.length} annualità ATA`);
const docPaths = await downloadAll(docNames);
const ataPaths = await downloadAll(ataNames);
console.log("  file annuali pronti (cache)");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const docList = docPaths.map(p => `'${p}'`).join(", ");
const ataList = ataPaths.map(p => `'${p}'`).join(", ");

await con.run(`CREATE OR REPLACE TABLE personale_scuola AS
WITH doc AS (
  SELECT ANNOSCOLASTICO AS anno_scolastico, PROVINCIA AS provincia_f,
    'Docente' AS categoria, ORDINESCUOLA AS grado, TIPOPOSTO AS tipo_posto,
    FASCIAETA AS fascia_eta,
    TRY_CAST(DOCENTITITOLARIMASCHI AS BIGINT) AS maschi,
    TRY_CAST(DOCENTITITOLARIFEMMINE AS BIGINT) AS femmine
  FROM read_csv([${docList}], header = true, all_varchar = true, union_by_name = true)
),
ata AS (
  SELECT ANNOSCOLASTICO AS anno_scolastico, PROVINCIA AS provincia_f,
    'ATA' AS categoria, NULL AS grado, NULL AS tipo_posto,
    FASCIAETA AS fascia_eta,
    TRY_CAST(ATATITOLARIMASCHI AS BIGINT) AS maschi,
    TRY_CAST(ATATITOLARIFEMMINE AS BIGINT) AS femmine
  FROM read_csv([${ataList}], header = true, all_varchar = true, union_by_name = true)
),
tutti AS (SELECT * FROM doc UNION ALL SELECT * FROM ata),
-- alias EDITORIALI: la fonte scrive alcune province in forma abbreviata o con
-- un refuso rispetto al nome ISTAT esteso (verificati uno per uno) — non
-- alias per le province SARDE abolite dalla riforma 2016 (Olbia-Tempio,
-- Medio Campidano, Ogliastra, Carbonia-Iglesias: dati storici di anni in cui
-- esistevano davvero, restano onestamente senza provincia corrente);
alias AS (
  SELECT ${N("src")} AS src_n, ${N("dst")} AS dst_n FROM (VALUES
    ('PESARO-URBINO', 'Pesaro e Urbino'),
    ('MASSA', 'Massa Carrara'),
    ('MONZA E BRIANZA', 'Monza e della Brianza'),
    ('REGGIO EMILIA', 'Reggio nell''Emilia'),
    ('REGGIO CALABRIA', 'Reggio di Calabria'),
    ('BARLETTA-ADRIA-TRANI', 'Barletta-Andria-Trani')
  ) AS t(src, dst)
),
prov AS (
  SELECT pr.provincia, pr.sigla, rg.regione, ${N("pr.provincia")} AS pn
  FROM istat_confini_province pr
  LEFT JOIN istat_confini_regioni rg ON rg.cod_reg = pr.cod_reg
)
SELECT
  t.anno_scolastico,
  p.provincia,
  p.sigla,
  p.regione,
  t.categoria,
  CASE t.grado
    WHEN 'SCUOLA INFANZIA' THEN 'Infanzia'
    WHEN 'SCUOLA PRIMARIA' THEN 'Primaria'
    WHEN 'SCUOLA SECONDARIA I GRADO' THEN 'Secondaria I grado'
    WHEN 'SCUOLA SECONDARIA II GRADO' THEN 'Secondaria II grado'
    ELSE t.grado
  END AS grado,
  CASE t.tipo_posto WHEN 'NORMALE' THEN 'Normale' WHEN 'SOSTEGNO' THEN 'Sostegno' ELSE t.tipo_posto END AS tipo_posto,
  CASE t.fascia_eta
    WHEN 'FINO A 34' THEN 'Fino a 34'
    WHEN 'TRA 35 E 44' THEN 'Tra 35 e 44'
    WHEN 'TRA 45 E 54' THEN 'Tra 45 e 54'
    WHEN 'OLTRE 54' THEN 'Oltre 54'
    ELSE t.fascia_eta
  END AS fascia_eta,
  t.maschi,
  t.femmine,
  (t.maschi + t.femmine) AS totale
FROM tutti t
LEFT JOIN alias a ON a.src_n = ${N("t.provincia_f")}
LEFT JOIN prov p ON p.pn = coalesce(a.dst_n, ${N("t.provincia_f")})`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(sigla) AS con_provincia, count(DISTINCT anno_scolastico) AS anni,
    min(anno_scolastico) AS da, max(anno_scolastico) AS a,
    (SELECT sum(totale) FROM personale_scuola WHERE categoria = 'Docente' AND anno_scolastico = (SELECT max(anno_scolastico) FROM personale_scuola)) AS docenti_ultimo_anno
    FROM personale_scuola`)
).getRowObjects()[0];
console.log(
  `  personale_scuola: ${stat.n} righe — ${stat.anni} anni scolastici (${stat.da}–${stat.a}), ` +
    `${((Number(stat.con_provincia) / Number(stat.n)) * 100).toFixed(1)}% agganciate alla provincia, ` +
    `${Number(stat.docenti_ultimo_anno).toLocaleString("it-IT")} docenti titolari nell'ultimo anno`,
);
if (Number(stat.con_provincia) < Number(stat.n)) console.warn("  ATTENZIONE: province non agganciate — verificare i nomi non normalizzati");

// --- riga di catalogo ---------------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'personale_scuola' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Personale scolastico titolare per provincia (MIUR)";
const titleEn = "Tenured school staff by province (MIUR)";
const descIt = `Docenti e personale ATA titolari (di ruolo) per provincia, dall'a.s. ${stat.da} al ${stat.a} (fonte MIUR — Portale Unico dei Dati della Scuola, Open Data IODL 2.0). Docenti: per grado (infanzia, primaria, secondaria I/II grado), tipo posto (normale/sostegno) e fascia d'età, maschi/femmine. ATA: per fascia d'età, maschi/femmine (nessuna scomposizione per grado — il personale non docente non è assegnato a un grado specifico). Granularità PROVINCIA (la fonte non pubblica un livello più fine). Solo personale di ruolo: il precariato (supplenti) non è integrato — famiglia di dataset separata e discontinua a metà serie storica.`;
const descEn = `Tenured teaching and administrative/technical (ATA) staff by province, from school year ${stat.da} to ${stat.a} (source MIUR — School Data Portal, Open Data IODL 2.0). Teachers: by grade (kindergarten, primary, lower/upper secondary), post type (regular/special-needs support) and age band, male/female. ATA staff: by age band, male/female (no grade breakdown — non-teaching staff isn't assigned to a specific grade). PROVINCE-level granularity (the source publishes nothing finer). Tenured staff only: substitute/temporary teachers aren't integrated — a separate dataset family, discontinued mid-series.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'personale_scuola'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('personale_scuola', 'dati.istruzione.it', 'miur/personale-titolare',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://dati.istruzione.it/opendata/', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\npersonale_scuola: ${stat.n} righe (${stat.anni} anni scolastici)`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
