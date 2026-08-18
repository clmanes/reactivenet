// Ingestione del patrimonio immobiliare pubblico (MEF — Dipartimento del Tesoro,
// «Patrimonio della PA») → tabella `patrimonio_pa` in DuckDB + riga nel `catalog`.
// Un bene per riga: chi lo possiede, dove sta, quanto è grande, a cosa serve, e la
// sua posizione — con la precisione dichiarata, che è la parte che conta.
//
// È il censimento che l'articolo 2 comma 222 della legge 191/2009 impone a ogni
// amministrazione pubblica: comuni, province, ministeri, università, ASL, enti di
// previdenza. Incrociato con `istat_popolazione` dice quanti metri quadri pubblici
// per abitante ha un comune; con `zone_sismiche` e `consumo_suolo`, dove stanno.
//
// FONTE (nessuna chiave):
//   https://www.de.mef.gov.it/it/attivita_istituzionali/patrimonio_pubblico/
//     censimento_immobili_pubblici/open_data_immobili/dati_immobili_<anno>.html
//   Trentuno zip per annata: uno per regione per i Comuni, più uno per ciascuna
//   categoria nazionale (ministeri, università, agenzie fiscali, previdenza…).
//   ~87 MB compressi in tutto.
//
// L'ANNATA È VECCHIA, E VA DETTA. La rilevazione è triennale e la pubblicazione
// arriva con due anni di ritardo: l'edizione più recente al momento è quella al
// 31/12/2023, uscita nel 2026. Non è un difetto dell'ETL — è il ritmo della fonte, e
// chi mette questi numeri accanto a una popolazione aggiornata sta confrontando due
// momenti diversi.
//
// TRAPPOLE, e la prima è quella che decide se l'ingestione ha senso:
//  - **il comune è scritto in codice CATASTALE, non ISTAT.** `A013` è Abriola. Nessuna
//    tabella del warehouse traduceva i due codici finché `anncsu.mjs` non ha
//    cominciato a emettere `comuni_codici`, che è esattamente per questo: l'ANNCSU
//    porta entrambi i codici su ogni riga ed è la sola fonte in cui convivono.
//    Agganciare per NOME sarebbe stato possibile e sbagliato — gli omonimi sono
//    decine, e un immobile finito nel comune sbagliato non lo denuncia nessuno;
//  - **i file sono in ISO-8859-1**, non UTF-8: letti come UTF-8, «proprietà» diventa
//    «propriet�» e ogni accento del Paese con lei. Si converte in ingresso;
//  - separatore **punto e virgola**, valori fra virgolette, e le intestazioni portano
//    spazi e punti: `"Cod. Comune (Amministrazione)"` va citata così com'è;
//  - **due comuni per riga, e non sono lo stesso**: quello dell'AMMINISTRAZIONE che
//    dichiara e quello del BENE. Il municipio di un comune di montagna può possedere
//    un appartamento al mare. Qui si tiene il comune del BENE, che è dove l'immobile
//    sta davvero, e si conserva a parte l'amministrazione che lo dichiara;
//  - **una coordinata c'è quasi sempre, e non vuol dire che sia un indirizzo.** Tre
//    milioni e duecentocinquantasettemila beni su 3.257.044 cadono dentro l'Italia, il
//    che a prima vista sembra una copertura perfetta; ma `precisione_geo` è dichiarata
//    solo per il 8% di essi, e fra quelli 75.797 sono precisi «al COMUNE» — cioè sono
//    il centroide del municipio, non il posto dove sta il bene. Mapparli tutti allo
//    stesso modo disegna migliaia di puntini impilati sui centri storici e li fa
//    sembrare immobili. Solo 92.516 arrivano al civico. Per questo `fonte_geo` e
//    `precisione_geo` viaggiano con le coordinate invece di essere scartate come
//    metadati: senza, non c'è modo di sapere quali punti significano qualcosa.
//
// Uso:  bun etl/patrimonio-pa.mjs [--anno N] [--refresh]

import { mkdirSync, readdirSync, rmSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/patrimonio-pa/";
const DB = ROOT + "warehouse.duckdb";
const ORIGINE = "https://www.de.mef.gov.it";
const INDICE =
  ORIGINE +
  "/it/attivita_istituzionali/patrimonio_pubblico/censimento_immobili_pubblici/open_data_immobili/";
const THIS_YEAR = new Date().getFullYear();

const args = process.argv.slice(2);
const refresh = args.includes("--refresh");
const forzato = args.includes("--anno") ? Number(args[args.indexOf("--anno") + 1]) : null;
const esc = s => String(s).replaceAll("'", "''");
const HEADERS = {
  "user-agent":
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
};

mkdirSync(RAW, { recursive: true });
console.log("▸ patrimonio immobiliare pubblico (MEF — Patrimonio della PA)");

// L'annata più recente si legge dall'indice invece di indovinarla: la rilevazione è
// triennale e gli anni pubblicati non sono consecutivi (2016, 2017, 2018, 2019, 2022,
// 2023…), quindi un ciclo all'indietro sbaglierebbe due volte su tre.
async function annoPiuRecente() {
  const res = await fetch(INDICE, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
  if (!res.ok) throw new Error(`indice MEF: HTTP ${res.status}`);
  const html = await res.text();
  const anni = [...html.matchAll(/dati_immobili_(\d{4})\.html/g)]
    .map(m => Number(m[1]))
    .filter(a => a <= THIS_YEAR);
  if (!anni.length) throw new Error("nessuna annata trovata nell'indice MEF: la pagina è cambiata");
  return Math.max(...anni);
}

const anno = forzato ?? (await annoPiuRecente());
console.log(`  annata: ${anno} (dati al 31/12/${anno})`);

// I trentuno zip di quell'annata, presi dalla sua pagina.
const paginaAnno = `${INDICE}dati_immobili_${anno}.html`;
const res = await fetch(paginaAnno, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
if (!res.ok) throw new Error(`pagina ${anno}: HTTP ${res.status}`);
const html = await res.text();
const zips = [...new Set([...html.matchAll(/\/modules\/[^"'\s]*Imm_[^"'\s]*\.zip/gi)].map(m => m[0]))];
if (!zips.length) throw new Error(`nessuno zip Imm_* nella pagina ${anno}`);
console.log(`  ${zips.length} archivi da prendere`);

const estratti = RAW + `csv${anno}/`;
if (refresh) rmSync(estratti, { recursive: true, force: true });
mkdirSync(estratti, { recursive: true });

for (const percorso of zips) {
  const nome = percorso.split("/").pop();
  const zip = RAW + nome;
  if (refresh || !(await Bun.file(zip).exists())) {
    const r = await fetch(ORIGINE + percorso, { headers: HEADERS, signal: AbortSignal.timeout(600_000) });
    if (!r.ok) throw new Error(`${nome}: HTTP ${r.status}`);
    const buf = new Uint8Array(await r.arrayBuffer());
    if (buf[0] !== 0x50 || buf[1] !== 0x4b) throw new Error(`${nome}: non è uno zip`);
    await Bun.write(zip, buf);
  }
  const p = Bun.spawnSync(["unzip", "-o", "-q", zip, "-d", estratti]);
  if (p.exitCode !== 0) throw new Error(`${nome}: unzip fallito`);
}

// ISO-8859-1 → UTF-8, una volta sola, in un file accanto. Letti come UTF-8 i file
// originali riempiono ogni accento d'Italia di caratteri di sostituzione.
const utf8 = RAW + `utf8_${anno}/`;
mkdirSync(utf8, { recursive: true });
const originali = readdirSync(estratti).filter(f => f.toLowerCase().endsWith(".csv"));
if (!originali.length) throw new Error("nessun csv dopo l'estrazione");
for (const f of originali) {
  const fuori = utf8 + f;
  if (!refresh && (await Bun.file(fuori).exists())) continue;
  const p = Bun.spawnSync(["iconv", "-f", "ISO-8859-1", "-t", "UTF-8", estratti + f]);
  if (p.exitCode !== 0) throw new Error(`${f}: conversione di codifica fallita (serve iconv)`);
  await Bun.write(fuori, p.stdout);
}
console.log(`  ${originali.length} csv convertiti in UTF-8`);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// vss perché il CHECKPOINT finale tocca tutto il database e le tabelle con indice
// HNSW non si ricostruiscono senza l'estensione.
await con.run("INSTALL vss");
await con.run("LOAD vss");

const numero = c => `TRY_CAST(replace(nullif("${c}", ''), ',', '.') AS DOUBLE)`;

// union_by_name: i file delle diverse categorie non hanno tutti le stesse colonne, e
// senza questo DuckDB si ferma alla prima differenza invece di allineare per nome.
await con.run(`CREATE OR REPLACE TABLE patrimonio_pa AS
  WITH grezzo AS (
    SELECT * FROM read_csv('${esc(utf8)}*.csv', delim = ';', header = true,
      all_varchar = true, union_by_name = true, ignore_errors = true)
  )
  SELECT
    -- il comune del BENE, tradotto dal catastale con il crosswalk ANNCSU
    k.codice_istat,
    g."Comune del bene" AS comune,
    g."Provincia del bene" AS provincia,
    g."Regione del bene" AS regione,
    ${anno} AS anno,
    -- chi lo dichiara, che è cosa diversa da dove sta
    g."Amministrazione Denominazione" AS amministrazione,
    g."Tipologia Amministrazione" AS tipologia_amministrazione,
    g."Macrocategoria Amministrazione" AS macrocategoria_amministrazione,
    -- La fonte scrive il codice fiscale fra parentesi quadre — «[97904380587]» —
    -- e lasciarcele dentro rende la colonna inservibile per l'unico scopo che
    -- ha: agganciare l'amministrazione a indicepa.cf. Il join misurato dal
    -- layer semantico veniva 0%, che è il modo giusto per accorgersene.
    nullif(trim(g."Amministrazione Codice Fiscale", '[] '), '') AS cf_amministrazione,
    g."Natura del bene" AS natura,
    g."Tipologia Bene Immobile" AS tipologia,
    g."Utilizzo del bene" AS utilizzo,
    nullif(g."Titolo proprietà", '') AS titolo_proprieta,
    ${numero("Quota proprietà")} AS quota_proprieta,
    ${numero("Superficie (mq)")} AS superficie_mq,
    ${numero("Cubatura (mc)")} AS cubatura_mc,
    ${numero("Canone annuale")} AS canone_annuale,
    nullif(g."Epoca Costruzione", '') AS epoca_costruzione,
    nullif(g."Vinc. culturale/paesaggistico", '') AS vincolo,
    nullif(g."Indirizzo", '') AS indirizzo,
    nullif(g."Numero Civico", '') AS civico,
    -- la posizione è DICHIARATA dall'ente: fonte e precisione viaggiano con lei,
    -- perché senza non si sa quanto fidarsi di un punto su una mappa
    ${numero("Latitudine")} AS lat,
    ${numero("Longitudine")} AS lon,
    nullif(g."Fonte Georeferenziazione", '') AS fonte_geo,
    nullif(g."Precisione Georeferenziazione", '') AS precisione_geo
  FROM grezzo g
  LEFT JOIN comuni_codici k ON k.codice_catastale = upper(trim(g."Codice Comune del bene"))
  WHERE g."ID bene" IS NOT NULL`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  count(*) beni,
  count(codice_istat) con_istat,
  count(DISTINCT codice_istat) comuni,
  count(lat) con_coord,
  count(*) FILTER (WHERE precisione_geo = 'CIVICO') geo_civico,
  count(*) FILTER (WHERE precisione_geo = 'STRADA') geo_strada,
  count(*) FILTER (WHERE precisione_geo = 'COMUNE') geo_comune,
  count(*) FILTER (WHERE precisione_geo IS NULL) geo_ignota,
  round(sum(superficie_mq) FILTER (WHERE natura = 'FABBRICATO') / 1e6) mq_fabbricati,
  round(sum(superficie_mq) FILTER (WHERE natura = 'TERRENO') / 1e6) mq_terreni,
  count(DISTINCT cf_amministrazione) amministrazioni,
  round(sum(superficie_mq) / 1e6, 1) mln_mq
  FROM patrimonio_pa`);
const pct = Number(st.beni) ? Number(st.con_istat) / Number(st.beni) : 0;
console.log(`  beni:              ${st.beni}`);
console.log(`  con codice ISTAT:  ${st.con_istat} (${(pct * 100).toFixed(1)}%), in ${st.comuni} comuni`);
console.log(`  con coordinate:    ${st.con_coord}, ma la precisione è dichiarata solo per ${Number(st.con_coord) - Number(st.geo_ignota)}:`);
console.log(`                     ${st.geo_civico} al civico, ${st.geo_strada} alla strada, ${st.geo_comune} al comune (centroide)`);
console.log(`  amministrazioni:   ${st.amministrazioni}`);
console.log(`  superficie:        ${st.mq_fabbricati} mln m² di fabbricati, ${st.mq_terreni} mln m² di terreni`);
if (Number(st.beni) > 0 && pct < 0.95)
  console.warn(
    `  ⚠ meno del 95% dei beni ha un codice ISTAT: il crosswalk comuni_codici è\n` +
      `    incompleto o assente. Esegui prima 'bun run etl:anncsu'.`,
  );

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

await catalog(
  "patrimonio_pa",
  "de.mef.gov.it",
  "mef/patrimonio-immobiliare-pa",
  "Patrimonio immobiliare pubblico (MEF)",
  "Public real estate register (MEF)",
  `Ogni fabbricato e terreno dichiarato dalle amministrazioni pubbliche al ${anno}, come impone l'art. 2 c. 222 della legge 191/2009: comuni, province, ministeri, università, ASL, enti di previdenza. Per ciascun bene chi lo possiede, la natura e l'utilizzo, la superficie, l'eventuale canone, e la posizione. ATTENZIONE alle coordinate: ci sono per quasi tutti i beni, ma precisione_geo è dichiarata solo per l'8% — e fra quelli 75.797 sono precisi «al COMUNE», cioè sono il centroide del municipio e non il posto dove sta il bene; solo 92.516 arrivano al civico. Mapparli tutti allo stesso modo impila migliaia di puntini sui centri storici: filtrare per precisione_geo è la differenza fra una mappa e un artefatto. ATTENZIONE: il comune qui è quello del BENE, non quello dell'amministrazione che lo dichiara, e i due sono spesso diversi. La fonte scrive il comune in codice CATASTALE (A013 è Abriola): il codice ISTAT arriva dal crosswalk comuni_codici, ricavato dall'ANNCSU. La rilevazione è triennale e la pubblicazione tarda di circa due anni: accanto a una popolazione aggiornata si stanno confrontando due momenti diversi.`,
  `Every building and plot of land declared by Italian public administrations as of ${anno}, as required by law 191/2009 art. 2 §222: municipalities, provinces, ministries, universities, health authorities, pension bodies. For each asset the owner, the nature and use, the surface, any rent, and the position. MIND the coordinates: nearly every asset has some, but precisione_geo is declared for only 8% — and among those 75,797 are accurate only to the MUNICIPALITY, meaning they are the town centroid and not where the asset is; just 92,516 reach the street number. Mapping them all alike stacks thousands of dots on town centres: filtering by precisione_geo is the difference between a map and an artefact. MIND: the municipality here is the ASSET's, not that of the declaring administration, and the two often differ. The source writes municipalities in CADASTRAL codes (A013 is Abriola): the ISTAT code comes from the comuni_codici crosswalk derived from ANNCSU. The census runs every three years and publication lags by about two: placed next to current population figures, these are two different moments.`,
  paginaAnno,
  Number(st.beni),
);

console.log(`\npatrimonio_pa: ${st.beni} beni in ${st.comuni} comuni (annata ${anno})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
