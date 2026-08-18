// Ingestione del consumo di suolo ISPRA/SNPA → due tabelle in DuckDB + righe nel
// `catalog`:
//   consumo_suolo        (7896)   una riga per comune: quanto suolo è consumato OGGI,
//                                 in ettari e in percentuale della superficie
//   consumo_suolo_serie  (~87k)   una riga per comune e per periodo: quanto se n'è
//                                 consumato, quanto ripristinato, dal 2006 a oggi
//
// È il primo asse ambientale del warehouse dopo `rifiuti`, e si aggancia per
// codice_istat a tutto il resto: la percentuale di suolo consumato accanto alla
// popolazione, ai redditi, alle sezioni di censimento.
//
// FONTE (nessuna chiave, nessun WAF; licenza NON dichiarata in pagina — ISPRA
// rimanda a consumosuolo@isprambiente.it, da verificare prima di RIPUBBLICARE):
//   https://www.isprambiente.gov.it/it/attivita/suolo-e-territorio/suolo/
//     il-consumo-di-suolo/consumo_di_suolo_estratto_dati_<edizione>_anni_2006_<ultimo>.xlsx
//   ~1,7 MB, quattro fogli: Descrizione_campi, Comuni_…, Province_…, Regioni_…
//   Si legge solo quello comunale: province e regioni sono somme, e il warehouse
//   preferisce sommare da sé che archiviare due volte lo stesso numero.
//
// PERCHÉ DUE TABELLE, E NON UNA LARGA COME LE VARIABILI CENSUARIE. Il foglio è largo
// — undici periodi × tre misure, più lo stock dell'ultimo anno — ma questa è una
// SERIE STORICA, e la forma che `::chart-line` sa disegnare è quella lunga. Lo stock,
// invece, esiste per un anno solo: ripeterlo su ogni riga di periodo inviterebbe a
// sommarlo, che è esattamente lo sbaglio da cui questa separazione protegge. Una
// tabella dice «quanto ce n'è», l'altra «quanto se n'è aggiunto quando».
//
// TRAPPOLE:
//  - PRO_COM arriva SENZA zeri iniziali (Torino è 1272, non 001272): va lpad a 6 o il
//    join a istat_confini_comuni, istat_popolazione e mef_redditi manca in silenzio
//    per tutti i comuni delle prime nove province. La percentuale di aggancio
//    stampata a fine ETL è la guardia;
//  - **i periodi non hanno la stessa durata**: 2006-2012 sono sei anni, gli altri
//    uno. Un confronto fra incrementi grezzi mette il primo periodo fuori scala e fa
//    sembrare che il consumo sia crollato. Per questo la tabella porta `anni`, e chi
//    vuole un ritmo annuo divide per quello — la colonna esiste perché la divisione
//    sia disponibile invece che da ricordare;
//  - **netto e lordo non sono la stessa cosa e nessuno dei due è «il consumo»**: il
//    lordo è quanto suolo è stato consumato, il netto è quello meno il ripristino.
//    Sommare il netto di tutti i periodi dà lo stock di oggi meno quello del 2006;
//    sommare il lordo dà qualcosa che non è nulla in particolare;
//  - `read_xlsx` con `all_varchar = true` e `TRY_CAST` a valle: l'inferenza di tipo su
//    colonne con celle vuote cambia da un'edizione all'altra, e l'INSERT in una
//    tabella già creata fallirebbe a metà;
//  - l'URL porta l'anno dell'edizione nel nome del file e cambierà: lo scan parte
//    dall'anno corrente e scende, e se non trova nulla lo dice invece di indovinare.
//
// Uso:  bun etl/consumo-suolo.mjs [--edizione N] [--refresh]

import { mkdirSync } from "node:fs";
import { unzipSync } from "fflate";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/consumo-suolo/";
const DB = ROOT + "warehouse.duckdb";
const BASE =
  "https://www.isprambiente.gov.it/it/attivita/suolo-e-territorio/suolo/il-consumo-di-suolo/";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const argOf = name => (args.includes(name) ? args[args.indexOf(name) + 1] : null);
const refresh = args.includes("--refresh");
const forced = argOf("--edizione") === null ? null : Number(argOf("--edizione"));
const esc = s => String(s).replaceAll("'", "''");

const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

// Il nome del file dichiara l'edizione e l'ultimo anno coperto; l'edizione <anno>
// pubblica i dati fino a <anno-1>. Ritorna null se quella edizione non esiste.
const fileOf = edizione => `consumo_di_suolo_estratto_dati_${edizione}_anni_2006_${edizione - 1}.xlsx`;

async function grab(edizione) {
  const out = RAW + fileOf(edizione);
  if (!refresh && (await Bun.file(out).exists())) return out;
  let res;
  try {
    res = await fetch(BASE + fileOf(edizione), { headers: HEADERS, signal: AbortSignal.timeout(300_000) });
  } catch (e) {
    throw new Error(`edizione ${edizione}: ${e.message ?? e}`);
  }
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`edizione ${edizione}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  // un xlsx è uno zip: se il portale risponde 200 con una pagina di errore, si vede qui
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) return null;
  await Bun.write(out, buf);
  return out;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ consumo di suolo (ISPRA/SNPA)");

let path = null;
let edizione = null;
for (const y of forced === null ? [THIS_YEAR, THIS_YEAR - 1, THIS_YEAR - 2] : [forced]) {
  path = await grab(y);
  if (path) {
    edizione = y;
    break;
  }
}
if (!path)
  throw new Error(
    `nessuna edizione trovata fra ${THIS_YEAR - 2} e ${THIS_YEAR}. Il nome del file sul sito ISPRA ` +
      `è probabilmente cambiato: controllalo e passa --edizione N.`,
  );
console.log(`  edizione ${edizione}`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// excel per leggere il foglio senza passare da SheetJS; vss perché il CHECKPOINT
// finale tocca tutto il database e le tabelle con indice HNSW non si ricostruiscono
// senza l'estensione.
for (const ext of ["excel", "vss"]) {
  await con.run(`INSTALL ${ext}`);
  await con.run(`LOAD ${ext}`);
}

// Il foglio comunale si chiama Comuni_<primo>_<ultimo>: si risolve leggendo i nomi
// invece di ricostruirlo, così un'edizione che cambia gli estremi non rompe nulla.
// L'estensione excel di DuckDB non espone i nomi dei fogli, e un xlsx è uno zip:
// workbook.xml li elenca, e fflate è già una dipendenza per gli shapefile ISTAT.
const fogliDi = async file => {
  const wb = unzipSync(new Uint8Array(await Bun.file(file).arrayBuffer()))["xl/workbook.xml"];
  return [...new TextDecoder().decode(wb).matchAll(/<sheet[^>]*name="([^"]+)"/g)].map(m => m[1]);
};
const fogli = await fogliDi(path);
const foglio = fogli.find(n => /^Comuni_/i.test(n));
if (!foglio) throw new Error(`foglio comunale non trovato fra: ${fogli.join(", ")}`);

await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo AS
  SELECT * FROM read_xlsx('${esc(path)}', all_varchar = true, sheet = '${esc(foglio)}')`);

const colonne = (
  await con.runAndReadAll(`SELECT column_name FROM (DESCRIBE _grezzo)`)
).getRowObjects().map(r => r.column_name);

// Le colonne dichiarano misura, periodo e unità: "Incremento netto 2016-2017 [ettari]".
// I periodi si ricavano da lì e non da un elenco scritto a mano, perché ogni edizione
// ne aggiunge uno.
const periodi = [];
for (const c of colonne) {
  const m = c.match(/^Incremento netto\s+(\d{4})-(\d{4})\s*\[ettari\]$/i);
  if (m) periodi.push({ etichetta: `${m[1]}-${m[2]}`, da: Number(m[1]), a: Number(m[2]) });
}
if (!periodi.length) throw new Error(`nessun periodo riconosciuto fra le colonne di ${foglio}`);
const ultimo = Math.max(...periodi.map(p => p.a));
console.log(`  periodi: ${periodi.length} (${periodi[0].etichetta} … ${periodi.at(-1).etichetta})`);

const num = c => `TRY_CAST("${c}" AS DOUBLE)`;
const istat = `lpad("PRO_COM", 6, '0')`;

// --- lo stock: una riga per comune ------------------------------------------------
const colStockHa = colonne.find(c => new RegExp(`^Suolo consumato ${ultimo} \\[ettari\\]$`, "i").test(c));
const colStockPct = colonne.find(c => new RegExp(`^Suolo consumato ${ultimo} \\[%\\]$`, "i").test(c));
if (!colStockHa || !colStockPct)
  throw new Error(`colonne dello stock ${ultimo} non trovate in ${foglio}`);

await con.run(`CREATE OR REPLACE TABLE consumo_suolo AS
  SELECT ${istat} AS codice_istat,
    "Nome_Comune" AS comune,
    "Nome_Provincia" AS provincia,
    "Nome_Regione" AS regione,
    ${ultimo} AS anno,
    round(${num(colStockHa)}, 2) AS suolo_consumato_ha,
    round(${num(colStockPct)}, 3) AS suolo_consumato_pct,
    -- la somma degli incrementi netti È la differenza fra lo stock di oggi e quello
    -- del 2006: è il numero che risponde a "quanto se n'è consumato da allora", e
    -- averlo qui evita che ognuno lo ricalcoli sommando la serie a modo suo.
    round(${periodi.map(p => `coalesce(${num(`Incremento netto ${p.etichetta} [ettari]`)}, 0)`).join(" + ")}, 2)
      AS incremento_netto_2006_${ultimo}_ha
  FROM _grezzo
  WHERE "PRO_COM" IS NOT NULL
  ORDER BY 1`);

// --- la serie: una riga per comune e periodo ---------------------------------------
const unione = periodi
  .map(
    p => `SELECT ${istat} AS codice_istat, "Nome_Comune" AS comune,
      '${p.etichetta}' AS periodo, ${p.da} AS anno_da, ${p.a} AS anno_a, ${p.a - p.da} AS anni,
      round(${num(`Incremento netto ${p.etichetta} [ettari]`)}, 2) AS incremento_netto_ha,
      round(${num(`Incremento lordo ${p.etichetta} [ettari]`)}, 2) AS incremento_lordo_ha,
      round(${num(`Ripristino ${p.etichetta} [ettari]`)}, 2) AS ripristino_ha
    FROM _grezzo WHERE "PRO_COM" IS NOT NULL`,
  )
  .join("\nUNION ALL\n");
await con.run(`CREATE OR REPLACE TABLE consumo_suolo_serie AS
  ${unione} ORDER BY codice_istat, anno_da`);

// --- statistiche e coerenza col resto del warehouse -------------------------------
const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  (SELECT count(*) FROM consumo_suolo) comuni,
  (SELECT count(*) FROM consumo_suolo_serie) serie,
  (SELECT round(sum(suolo_consumato_ha)) FROM consumo_suolo) ha_totali,
  (SELECT count(*) FROM consumo_suolo WHERE suolo_consumato_pct IS NULL) senza_valore,
  (SELECT count(g.codice_istat) FROM consumo_suolo c
     LEFT JOIN istat_confini_comuni g ON g.codice_istat = c.codice_istat) agganciati`);
const pct = Number(st.comuni) ? Number(st.agganciati) / Number(st.comuni) : 1;
console.log(`  comuni:            ${st.comuni}`);
console.log(`  righe di serie:    ${st.serie}`);
console.log(`  suolo consumato:   ${st.ha_totali} ettari in tutto`);
console.log(`  aggancio ai confini: ${st.agganciati}/${st.comuni} (${(pct * 100).toFixed(1)}%)`);
if (Number(st.comuni) > 0 && pct < 0.99)
  console.warn(
    `  ⚠ aggancio sotto il 99%: PRO_COM non combacia con codice_istat. La causa più\n` +
      `    probabile sono gli zeri iniziali, la seconda un'annata di confini diversa.`,
  );
if (Number(st.senza_valore) > 0)
  console.log(`  ${st.senza_valore} comuni senza percentuale (celle vuote nell'origine)`);

// --- righe di catalogo --------------------------------------------------------------
async function catalog(tbl, source, dataflow, titleIt, titleEn, descIt, descEn, url, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', '${esc(source)}', '${esc(dataflow)}',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      '${esc(url)}', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

const URL_ISPRA =
  "https://www.isprambiente.gov.it/it/attivita/suolo-e-territorio/suolo/il-consumo-di-suolo/i-dati-sul-consumo-di-suolo";

await catalog(
  "consumo_suolo",
  "isprambiente.gov.it",
  "ispra/consumo-di-suolo",
  "Consumo di suolo per comune (ISPRA)",
  "Land take by municipality (ISPRA)",
  `Quanto suolo è coperto artificialmente in ogni comune italiano al ${ultimo}, secondo la cartografia ISPRA/SNPA: la superficie in ettari, la percentuale sulla superficie comunale, e quanto se n'è consumato in netto dal 2006. Si aggancia per codice_istat a popolazione, redditi, confini e sezioni di censimento — la percentuale è il campo giusto per una coropletica, perché è già normalizzata sulla dimensione del comune. Gli incrementi periodo per periodo sono in consumo_suolo_serie.`,
  `How much soil is artificially covered in each Italian municipality as of ${ultimo}, from the ISPRA/SNPA land-cover mapping: the area in hectares, the share of the municipal surface, and the net amount taken since 2006. Joins on codice_istat to population, income, boundaries and census areas — the percentage is the field to map, being already normalised by municipal size. Period-by-period increments live in consumo_suolo_serie.`,
  URL_ISPRA,
  Number(st.comuni),
);

await catalog(
  "consumo_suolo_serie",
  "isprambiente.gov.it",
  "ispra/consumo-di-suolo",
  "Consumo di suolo per comune e periodo (ISPRA)",
  "Land take by municipality and period (ISPRA)",
  `La serie storica del consumo di suolo, una riga per comune e periodo dal 2006 al ${ultimo}: incremento lordo (suolo consumato), ripristino (superfici tornate naturali) e incremento netto, che è la differenza fra i due. ATTENZIONE ai periodi di durata diversa — 2006-2012 sono sei anni, gli altri uno — quindi per confrontarli va diviso per il campo anni: senza, il primo periodo esce fuori scala e sembra che il consumo sia crollato. Lo stock attuale è in consumo_suolo.`,
  `The land-take time series, one row per municipality and period from 2006 to ${ultimo}: gross increase (soil taken), restoration (surfaces returned to natural cover) and the net increase between them. MIND the unequal periods — 2006-2012 spans six years, the others one — so divide by the anni field to compare them: without that the first period dwarfs the rest and land take looks as though it collapsed. The current stock is in consumo_suolo.`,
  URL_ISPRA,
  Number(st.serie),
);

console.log(`\nconsumo_suolo: ${st.comuni} comuni, ${st.serie} righe di serie (edizione ${edizione})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
