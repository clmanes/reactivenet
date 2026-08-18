// Ingestione dell'intero universo dei progetti d'investimento pubblico
// tracciati dal Codice Unico di Progetto (CUP) → tabella `opencup` in DuckDB
// + riga nel `catalog`. Una riga per CUP: descrizione, natura dell'intervento
// (lavori pubblici/incentivi/contributi/…), costo e finanziamento, soggetto
// titolare, beneficiario, localizzazione, fonti di copertura finanziaria.
//
// È il complemento naturale di `opencoesione` (che copre SOLO i progetti
// finanziati con fondi di coesione): OpenCUP copre TUTTI i progetti
// d'investimento pubblico italiani dal 2003 in poi, a prescindere dalla
// fonte di finanziamento — chiave di aggancio: lo stesso campo `cup`.
//
// Fonte (licenza CC BY, nessuna chiave): opencup.gov.it — il DIPE (Dip. per
// la programmazione e il coordinamento della politica economica) pubblica
// QUATTRO dataset nazionali come zip di CSV (";"-delimited, UTF-8):
//   Progetti        (anagrafica progetto, ~2,2 GB zip — split in PIÙ CSV
//                    da ~2 GB l'uno perché il sistema sorgente ha un tetto
//                    di dimensione per file esportato)
//   Localizzazione  (CUP → comune/provincia/regione, 1:N: un progetto può
//                    interessare più comuni)
//   Soggetti        (registro dei soggetti titolari, per PIVA/CF — un
//                    dataset piccolo, ~28.700 enti distinti: NON è un
//                    dataset per-progetto, è l'anagrafica di CHI richiede i
//                    CUP, riusata da milioni di progetti)
//   Fonti_Copertura (CUP → tipo di copertura finanziaria, 1:N: un progetto
//                    può avere più fonti)
// I quattro URL sono permalink STABILI del document-repository Liferay del
// portale (stesso URL, contenuto aggiornato in-place: verificato via
// Last-Modified) — a differenza di opencoesione.mjs qui non serve
// risolvere un alias datato.
//
// Aggiornamento: mensile (osservato: pubblicazioni a inizio mese).
//
// NIENTE EMBEDDINGS: a differenza di anac.mjs/opencoesione.mjs, qui non si
// calcola una ricerca semantica per riga. Motivi: (1) la scala — 11,86M CUP,
// più del doppio di anac_cig — con un indice HNSW memory-resident
// aggiuntivo si rischierebbe il budget di RAM in produzione già impegnato
// dai due indici esistenti; (2) il CUP è già la chiave di aggancio a
// `opencoesione` (che la ricerca semantica ce l'ha), quindi il valore
// aggiunto di un terzo indice è marginale rispetto al costo. Il valore di
// OpenCUP qui sta nella copertura GEOGRAFICA e nel volume, non nel testo
// libero.
//
// TRAPPOLE:
//  - il dataset Progetti è FISICAMENTE diviso in più CSV (osservato: 7 file
//    "OpenCup_ProgettiN.csv", N=0..6, ~2 GB l'uno) ciascuno col PROPRIO
//    header — non un CSV unico rinominato: si processano uno alla volta;
//  - decomprimere l'intero zip di Progetti IN MEMORIA con un colpo solo
//    (tutti i CSV insieme, ~13,8 GB scompattati) più scriverli su un
//    filesystem RAM-backed (es. /tmp se è tmpfs) può saturare la RAM della
//    macchina — si decomprime UN CSV alla volta (fflate `filter` per nome
//    esatto salta la decompressione degli altri) e si scrive su disco vero;
//  - CODICE_COMUNE in Localizzazione vale "-1" (con COMUNE="TUTTI") per i
//    progetti che non riguardano un comune specifico (interventi
//    provinciali/regionali/nazionali): non un errore, un NULL semantico —
//    NULLIF esplicito, non un codice ISTAT da recuperare;
//  - un progetto senza comune specifico può avere STATO≠"ITALIA" (progetti
//    realizzati all'estero, CODICE_COMUNE a 2 cifre = codice nazione): fuori
//    da qualunque mappatura ISTAT, restano con codice_istat NULL;
//  - ~0,3% dei codici comune storici non trova riscontro in
//    istat_confini_comuni (fusioni/ridenominazioni successive alla
//    registrazione del CUP — es. Quero Vas, Sardegna con le sue riforme
//    provinciali ricorrenti): stessa natura degli scarti già visti in
//    personale-scuola.mjs, non corretti in silenzio;
//  - PIVA_CF_BENEFICIARIO/DENOMINAZIONE_BENEFICIARIO/DENO_IMPRESA_STABILIMENTO
//    portano il valore letterale "**********" (10 asterischi) quando il
//    dato è oscurato per privacy (persona fisica/piccola impresa
//    beneficiaria di un incentivo): NULLIF, non un valore reale;
//  - Soggetti.csv NON ha una colonna CUP: è il registro dei ~28.700 SOGGETTI
//    TITOLARI (enti che gestiscono i progetti), agganciato a Progetti via
//    PIVA_CODFISCALE_SOG_TITOLARE — porta duplicati per PIVA (stesso ente,
//    indirizzi diversi nel tempo): si aggrega con any_value, la
//    categorizzazione (PAL/centrale/altro) è stabile per soggetto;
//  - la scheda Metadati.xlsx del portale documenta anche campi
//    (LINK_OPENCOESIONE, LINK_SCUOLE_SICURE) che NON esistono nell'export
//    Progetti reale: il metadato descrive un superset, non fare affidamento
//    sulla sua lista per il parsing, verificare l'header vero.
//
// Uso:  bun etl/opencup.mjs [--refresh]
//   --refresh   ignora la cache in raw/opencup/ e riscarica

import { mkdirSync, unlinkSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/opencup/";
const DB = ROOT + "warehouse.duckdb";

const FILES = {
  progetti: {
    url: "https://www.opencup.gov.it/portale/documents/21195/299152/OpendataProgetti.zip/7384382b-679a-0380-c750-ce40779b59d7",
    zip: "OpendataProgetti.zip",
  },
  localizzazione: {
    url: "https://www.opencup.gov.it/portale/documents/21195/299152/OpendataLocalizzazione.zip/ac230d13-23a0-5929-8778-d34c21c9a7a4",
    zip: "OpendataLocalizzazione.zip",
  },
  soggetti: {
    url: "https://www.opencup.gov.it/portale/documents/21195/299152/OpendataSoggetti.zip/411e1e80-bce0-d085-bb96-b8036deb590f",
    zip: "OpendataSoggetti.zip",
  },
  fontiCopertura: {
    url: "https://www.opencup.gov.it/portale/documents/21195/299152/OpendataFontiCopertura.zip/229bb5a8-cb28-cb64-dfd8-44ebac4b3693",
    zip: "OpendataFontiCopertura.zip",
  },
};
const UA = "Mozilla/5.0 (compatible; reactive-etl/1.0)";

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ progetti d'investimento pubblico (CUP) — opencup.gov.it");

// --- 1. scarica i 4 zip (cache in raw/opencup/) ----------------------------------

for (const [key, f] of Object.entries(FILES)) {
  const localPath = RAW + f.zip;
  if (!refresh && (await Bun.file(localPath).exists())) {
    console.log(`  da cache: ${f.zip}`);
    continue;
  }
  const res = await fetch(f.url, { headers: { "user-agent": UA }, signal: AbortSignal.timeout(1_800_000) });
  if (!res.ok) throw new Error(`${f.zip}: HTTP ${res.status}`);
  const mb = (Number(res.headers.get("content-length") ?? 0) / 1e6).toFixed(0);
  console.log(`  scarico ${f.zip} (${mb} MB)`);
  await Bun.write(localPath, await res.arrayBuffer());
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO anche se `opencup` non ha embeddings: il CHECKPOINT finale
// tocca l'intero database, e le tabelle con indice HNSW già presenti
// (anac_cig, opencoesione) non si ricostruiscono senza l'estensione vss
// caricata nella connessione (pattern opencoesione.mjs).
await con.run("INSTALL vss");
await con.run("LOAD vss");
await con.run("SET hnsw_enable_experimental_persistence = true");

// --- 2. estrae UN CSV ALLA VOLTA (mai tutto lo zip in memoria insieme) ----------
// entryNames: se null, decomprime l'unico file dello zip (pattern anac.mjs);
// se una funzione, prova nomi in sequenza finché non trova più corrispondenze
// (i CSV split di Progetti non hanno un conteggio fisso dichiarato altrove).

async function withEntry(zipName, entryName, fn) {
  const buf = new Uint8Array(await Bun.file(RAW + zipName).arrayBuffer());
  const entries = unzipSync(buf, { filter: f => f.name === entryName });
  const data = entries[entryName];
  if (!data) return false;
  const tmp = `${RAW}_tmp_${entryName}`;
  await Bun.write(tmp, data);
  try {
    await fn(tmp);
  } finally {
    unlinkSync(tmp);
  }
  return true;
}

async function withSoleEntry(zipName, fn) {
  const buf = new Uint8Array(await Bun.file(RAW + zipName).arrayBuffer());
  const entries = unzipSync(buf, { filter: f => f.name.toLowerCase().endsWith(".csv") });
  const name = Object.keys(entries)[0];
  if (!name) throw new Error(`${zipName}: nessun CSV nello zip`);
  const tmp = `${RAW}_tmp_${name}`;
  await Bun.write(tmp, entries[name]);
  try {
    await fn(tmp);
  } finally {
    unlinkSync(tmp);
  }
}

const CSV_OPTS = "delim = ';', quote = '\"', header = true, all_varchar = true";

// --- 3. staging: Progetti (split in più CSV, un header ciascuno) ----------------

await con.run(`CREATE OR REPLACE TEMP TABLE stage_progetti (
  cup VARCHAR, descrizione VARCHAR, anno_decisione VARCHAR, stato_progetto VARCHAR,
  costo_progetto VARCHAR, finanziamento_progetto VARCHAR, soggetto_titolare VARCHAR,
  cf_soggetto_titolare VARCHAR, natura_intervento VARCHAR, tipologia_intervento VARCHAR,
  area_intervento VARCHAR, settore_intervento VARCHAR, tipologia_cup VARCHAR,
  beneficiario VARCHAR, cf_beneficiario VARCHAR, struttura_infrastruttura VARCHAR,
  indirizzo_intervento VARCHAR, flag_legge_obiettivo VARCHAR,
  data_generazione_cup VARCHAR, data_chiusura_revoca VARCHAR
)`);

let n = 0;
for (let i = 0; ; i++) {
  const entryName = `OpenCup_Progetti${i}.csv`;
  const found = await withEntry(FILES.progetti.zip, entryName, async tmp => {
    await con.run(`INSERT INTO stage_progetti
      SELECT
        CUP, NULLIF(trim(DESCRIZIONE_SINTETICA_CUP), ''), ANNO_DECISIONE, STATO_PROGETTO,
        COSTO_PROGETTO, FINANZIAMENTO_PROGETTO, NULLIF(trim(SOGGETTO_TITOLARE), ''),
        PIVA_CODFISCALE_SOG_TITOLARE, NULLIF(trim(NATURA_INTERVENTO), ''), NULLIF(trim(TIPOLOGIA_INTERVENTO), ''),
        NULLIF(trim(AREA_INTERVENTO), ''), NULLIF(trim(SETTORE_INTERVENTO), ''), TIPOLOGIA_CUP,
        NULLIF(DENOMINAZIONE_BENEFICIARIO, '**********'), NULLIF(PIVA_CF_BENEFICIARIO, '**********'),
        NULLIF(trim(STRUTTURA_INFRASTRUTTURA), ''), NULLIF(trim(INDIRIZZO_INTERVENTO), ''), FLAG_LEGGE_OBIETTIVO,
        DATA_GENERAZIONE_CUP, DATA_CHIUSURA_REVOCA
      FROM read_csv('${tmp}', ${CSV_OPTS})`);
    n++;
  });
  if (!found) {
    if (i === 0) throw new Error(`${FILES.progetti.zip}: nessun file OpenCup_ProgettiN.csv trovato`);
    break;
  }
}
const staged = (await con.runAndReadAll("SELECT count(*) AS n FROM stage_progetti")).getRowObjects()[0].n;
console.log(`  progetti: ${staged} righe da ${n} file CSV`);

// --- 4. staging: Localizzazione (1:N, si tiene la localizzazione "migliore") ----
// preferenza a un comune reale rispetto a "-1"/TUTTI quando un CUP ne ha più di una.

await withSoleEntry(FILES.localizzazione.zip, async tmp => {
  await con.run(`CREATE OR REPLACE TEMP TABLE stage_loc AS
    SELECT CUP AS cup,
      NULLIF(CODICE_COMUNE, '-1') AS codice_istat,
      NULLIF(COMUNE, 'TUTTI') AS comune,
      NULLIF(PROVINCIA, 'TUTTE') AS provincia,
      NULLIF(trim(REGIONE), '') AS regione,
      NULLIF(trim(AREA_GEOGRAFICA), '') AS area_geografica
    FROM (
      SELECT *, ROW_NUMBER() OVER (
        PARTITION BY CUP ORDER BY CASE WHEN CODICE_COMUNE = '-1' THEN 1 ELSE 0 END
      ) AS rn
      FROM read_csv('${tmp}', ${CSV_OPTS})
    ) WHERE rn = 1`);
});
const locN = (await con.runAndReadAll("SELECT count(*) AS n FROM stage_loc")).getRowObjects()[0].n;
console.log(`  localizzazione: ${locN} CUP georeferenziati`);

// --- 5. staging: Fonti di copertura finanziaria (1:N → lista aggregata) ---------

await withSoleEntry(FILES.fontiCopertura.zip, async tmp => {
  await con.run(`CREATE OR REPLACE TEMP TABLE stage_cop AS
    SELECT CUP AS cup, string_agg(DISTINCT NULLIF(trim(COPERTURA_FINANZIARIA), ''), ', ') AS coperture_finanziarie
    FROM read_csv('${tmp}', ${CSV_OPTS})
    GROUP BY CUP`);
});
const copN = (await con.runAndReadAll("SELECT count(*) AS n FROM stage_cop")).getRowObjects()[0].n;
console.log(`  fonti di copertura: ${copN} CUP`);

// --- 6. staging: Soggetti (registro dei titolari, non per-CUP) ------------------

await withSoleEntry(FILES.soggetti.zip, async tmp => {
  await con.run(`CREATE OR REPLACE TEMP TABLE stage_sog AS
    SELECT PIVA_CODFISCALE_SOG_TITOLARE AS cf,
      any_value(NULLIF(trim(AREA_SOGGETTO), '')) AS area_soggetto,
      any_value(NULLIF(trim(CATEGORIA_SOGGETTO), '')) AS categoria_soggetto
    FROM read_csv('${tmp}', ${CSV_OPTS})
    GROUP BY PIVA_CODFISCALE_SOG_TITOLARE`);
});

// --- 7. tabella finale: un JOIN per CUP, niente moltiplicazione di righe -------

await con.run(`CREATE OR REPLACE TABLE opencup_new AS
SELECT
  p.cup, p.descrizione, TRY_CAST(p.anno_decisione AS INTEGER) AS anno_decisione,
  p.stato_progetto, p.tipologia_cup, p.natura_intervento, p.area_intervento, p.settore_intervento,
  TRY_CAST(p.costo_progetto AS DOUBLE) AS costo_progetto,
  TRY_CAST(p.finanziamento_progetto AS DOUBLE) AS finanziamento_progetto,
  p.soggetto_titolare, p.cf_soggetto_titolare,
  sog.area_soggetto AS area_soggetto_titolare, sog.categoria_soggetto AS categoria_soggetto_titolare,
  p.beneficiario, p.cf_beneficiario, p.struttura_infrastruttura, p.indirizzo_intervento,
  loc.codice_istat, loc.comune, loc.provincia, loc.regione, loc.area_geografica,
  cop.coperture_finanziarie, p.flag_legge_obiettivo,
  TRY_STRPTIME(p.data_generazione_cup, '%d-%b-%Y')::DATE AS data_generazione_cup,
  TRY_STRPTIME(p.data_chiusura_revoca, '%d-%b-%Y')::DATE AS data_chiusura_revoca
FROM stage_progetti p
LEFT JOIN stage_loc loc USING (cup)
LEFT JOIN stage_cop cop USING (cup)
LEFT JOIN stage_sog sog ON p.cf_soggetto_titolare = sog.cf`);

await con.run("DROP TABLE IF EXISTS opencup");
await con.run("ALTER TABLE opencup_new RENAME TO opencup");

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(codice_istat) AS con_istat,
    count(DISTINCT codice_istat) AS comuni, round(sum(costo_progetto) / 1e9, 1) AS mld
    FROM opencup`)
).getRowObjects()[0];
console.log(
  `  opencup: ${stat.n} CUP — ${((Number(stat.con_istat) / Number(stat.n)) * 100).toFixed(1)}% georeferenziati ` +
    `su ${stat.comuni} comuni, ${stat.mld} mld € di costo complessivo`,
);

// --- 8. riga di catalogo ----------------------------------------------------------

const cols = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'opencup' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Progetti d'investimento pubblico (OpenCUP)";
const titleEn = "Public investment projects (OpenCUP)";
const descIt = `Tutti i progetti d'investimento pubblico italiani tracciati dal Codice Unico di Progetto (CUP), fonte opencup.gov.it — DIPE, Presidenza del Consiglio, CC BY. Una riga per CUP: descrizione, natura dell'intervento (lavori pubblici, incentivi, contributi, servizi…), area e settore, costo e finanziamento, soggetto titolare con categoria, beneficiario, comune di realizzazione, fonti di copertura finanziaria. Il complemento generale di opencoesione (che copre solo i progetti a fondi di coesione) sullo stesso CUP: qui l'intero universo, dal 2003.`;
const descEn = `All Italian public investment projects tracked by the Unique Project Code (CUP), source opencup.gov.it — DIPE, Prime Minister's Office, CC BY. One row per CUP: description, nature of the intervention (public works, incentives, grants, services…), area and sector, cost and funding, responsible entity with category, beneficiary, implementing municipality, financial coverage sources. The general-purpose complement of opencoesione (which covers only cohesion-fund projects) on the same CUP: here the whole universe, since 2003.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'opencup'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('opencup', 'opencup.gov.it', 'opencup/progetti',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://www.opencup.gov.it/portale/web/opencup/accesso-agli-open-data', now(), ${Number(stat.n)}, '${esc(JSON.stringify(cols))}')`);

console.log(`\nopencup: ${stat.n} progetti caricati`);
await con.run("CHECKPOINT");
con.closeSync();
