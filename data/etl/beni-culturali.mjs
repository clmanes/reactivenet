// Ingestione dei luoghi della cultura (MiC — ArCo / Cultural-ON) → tabella
// `beni_culturali` in DuckDB + riga nel `catalog`. Un luogo per riga: musei,
// archivi, biblioteche, aree archeologiche, monumenti — nome, indirizzo, comune e
// coordinate.
//
// È il primo layer di PUNTI culturali del warehouse, e con `::map{path lat lon}` si
// disegna da solo. Si incrocia con `turismo_capacita` (i posti letto di quel comune)
// e con `istat_popolazione` per la domanda che nessuna delle due tabelle risponde da
// sola: quanti luoghi della cultura per abitante, e quanti letti per luogo.
//
// FONTE: l'endpoint SPARQL del grafo della conoscenza del Ministero della Cultura,
// che è un canale bulk vero e non una ricerca da interrogare voce per voce:
//   https://dati.cultura.gov.it/sparql
// Nessuna chiave. La licenza non è dichiarata sull'endpoint (ArCo è generalmente
// CC-BY 4.0): da verificare prima di RIPUBBLICARE i dati.
//
// PERCHÉ SPARQL E NON IL DUMP RDF. Il dataset è pubblicato anche come JSON-LD e
// Turtle, ma sono l'intero grafo: milioni di triple da cui estrarre sei campi. Con
// SPARQL si chiedono i sei campi e basta, in una manciata di pagine.
//
// L'ONTOLOGIA VA LETTA, NON INDOVINATA. Tre predicati plausibili qui sono sbagliati,
// e sbagliano in silenzio — una OPTIONAL che non lega non dà errore, dà una colonna
// vuota:
//   - il nome è `rdfs:label` (61.128 occorrenze), NON `l0:name` (14.137): usando
//     quest'ultimo si perdono tre quarti dei luoghi;
//   - le coordinate sono `clvapit:lat` / `clvapit:long` della ontologia OntoPiA CLV,
//     NON `geo:lat` / `geo:long` del vocabolario WGS84 — che pure esiste nel grafo,
//     su un sottoinsieme diverso e più piccolo;
//   - la geometria pende dal LUOGO (`clvapit:hasGeometry`), l'indirizzo dal SITO
//     (`cis:hasSite/cis:siteAddress`): sono due rami diversi.
//
// TRAPPOLE:
//  - senza GROUP BY un luogo esce PIÙ VOLTE, una per sito e per indirizzo: si
//    raggruppa per soggetto e si prende un campione di ciascun campo;
//  - **la paginazione NON deve ordinare.** L'istinto è `ORDER BY ?s`, per avere pagine
//    stabili; Virtuoso però rifiuta un TOP ordinato oltre le diecimila righe — "Sorted
//    TOP clause specifies more than 15000 rows to sort" — quindi con ORDER BY la
//    seconda pagina è un 500 e basta. Senza, l'OFFSET profondo funziona e le pagine
//    combaciano: l'ultima si ferma a 58.941, che è il totale. Non ci si fida però
//    dell'ordine implicito: le righe si deduplicano per URI e alla fine il conteggio si
//    confronta con un COUNT chiesto a parte, così una paginazione che perdesse pezzi
//    si vedrebbe invece di passare per un dato più corto del vero;
//  - **la città NON porta un codice ISTAT**, solo il nome — quindi il codice si
//    ricava in due modi, nell'ordine: point-in-polygon dove ci sono le coordinate
//    (esatto, ~41% dei luoghi) e nome del comune dove è UNIVOCO in Italia. Dove il
//    nome è ambiguo e non ci sono coordinate resta NULL, perché indovinare fra due
//    comuni omonimi è peggio che non rispondere. I tre conteggi sono stampati.
//
// Uso:  bun etl/beni-culturali.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/beni-culturali/";
const DB = ROOT + "warehouse.duckdb";
const SPARQL = "https://dati.cultura.gov.it/sparql";
const PAGINA = 10000;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const PREFISSI = `PREFIX cis: <http://dati.beniculturali.it/cis/>
PREFIX clvapit: <https://w3id.org/italia/onto/CLV/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>`;

// Il corpo, uguale per il conteggio e per l'estrazione. Una OPTIONAL che non lega non
// dà errore, dà una colonna vuota: i predicati qui sono quelli letti dal grafo, non
// quelli plausibili.
const CORPO = `?s a cis:CulturalInstituteOrSite ; rdfs:label ?lab .
  OPTIONAL { ?s cis:hasSite/cis:siteAddress/clvapit:hasCity/rdfs:label ?cit }
  OPTIONAL { ?s clvapit:hasGeometry ?g . ?g clvapit:lat ?la ; clvapit:long ?lo }
  OPTIONAL { ?s cis:hasSite/cis:siteAddress/clvapit:fullAddress ?ind }`;

const iniziale = n => `UCASE(SUBSTR(STR(?lab),1,${n}))`;

async function chiedi(query, cosa) {
  const res = await fetch(`${SPARQL}?query=${encodeURIComponent(query)}`, {
    headers: { accept: "application/sparql-results+json", "user-agent": "reactive-data/1.0" },
    signal: AbortSignal.timeout(600_000),
  });
  if (!res.ok) throw new Error(`SPARQL (${cosa}): HTTP ${res.status} — ${(await res.text()).slice(0, 200)}`);
  return (await res.json()).results?.bindings ?? [];
}

// Il totale dichiarato dal grafo, per verificare a fine estrazione di non aver perso
// pagine per strada.
async function totale() {
  const r = await chiedi(
    `${PREFISSI}\nSELECT (COUNT(DISTINCT ?s) AS ?n) WHERE { ?s a cis:CulturalInstituteOrSite ; rdfs:label ?lab }`,
    "totale",
  );
  return Number(r[0]?.n?.value ?? 0);
}

const QUERY = offset => `${PREFISSI}
SELECT ?s (SAMPLE(?lab) AS ?nome) (SAMPLE(?cit) AS ?comune)
       (SAMPLE(?la) AS ?lat) (SAMPLE(?lo) AS ?lon) (SAMPLE(?ind) AS ?indirizzo)
WHERE { ${CORPO} }
GROUP BY ?s LIMIT ${PAGINA} OFFSET ${offset}`;

mkdirSync(RAW, { recursive: true });
console.log("▸ luoghi della cultura (MiC — ArCo)");

const locale = RAW + "luoghi.csv";
if (refresh || !(await Bun.file(locale).exists())) {
  const atteso = await totale();
  const righe = [];
  const visti = new Set();
  for (let offset = 0; ; offset += PAGINA) {
    const pagina = await chiedi(QUERY(offset), `pagina a ${offset}`);
    for (const b of pagina) {
      // Si deduplica sull'URI INTERO, non sulla sua coda: la coda è lo slug del nome e
      // due sottografi diversi possono averne uno uguale — deduplicare lì costava 35
      // luoghi, persi senza che nulla lo dicesse.
      const uri = b.s?.value ?? "";
      if (uri === "" || visti.has(uri)) continue;
      visti.add(uri);
      righe.push({
        uri,
        id: uri.split("/").pop(),
        nome: b.nome?.value ?? "",
        comune: b.comune?.value ?? "",
        indirizzo: b.indirizzo?.value ?? "",
        lat: b.lat?.value ?? "",
        lon: b.lon?.value ?? "",
      });
    }
    console.log(`  pagina a ${offset}: ${pagina.length} → ${righe.length} luoghi distinti`);
    if (pagina.length < PAGINA) break;
  }
  if (righe.length < atteso * 0.99)
    throw new Error(
      `estratti ${righe.length} luoghi su ${atteso} dichiarati dal grafo: la paginazione ha ` +
        `perso pagine, non si scrive un dato monco.`,
    );
  console.log(`  ${righe.length} luoghi su ${atteso} dichiarati`);
  const csvEsc = v => `"${String(v).replaceAll('"', '""')}"`;
  await Bun.write(
    locale,
    "uri,id,nome,comune,indirizzo,lat,lon\n" +
      righe.map(r => [r.uri, r.id, r.nome, r.comune, r.indirizzo, r.lat, r.lon].map(csvEsc).join(",")).join("\n"),
  );
} else {
  console.log("  dalla cache in raw/");
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// spatial per il point-in-polygon contro i confini comunali; vss perché il
// CHECKPOINT finale tocca tutto il database e le tabelle con indice HNSW non si
// ricostruiscono senza l'estensione.
for (const ext of ["spatial", "vss"]) {
  await con.run(`INSTALL ${ext}`);
  await con.run(`LOAD ${ext}`);
}

await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo AS
  SELECT uri, id, nome, nullif(trim(comune), '') AS comune_dichiarato,
    nullif(trim(indirizzo), '') AS indirizzo,
    TRY_CAST(lat AS DOUBLE) AS lat, TRY_CAST(lon AS DOUBLE) AS lon
  FROM read_csv('${esc(locale)}', header = true, all_varchar = true)
  WHERE nullif(trim(nome), '') IS NOT NULL`);

// I nomi di comune univoci in Italia: solo su questi il ripiego per nome è lecito.
// Gli omonimi restano senza codice invece di essere assegnati a caso.
await con.run(`CREATE OR REPLACE TEMP TABLE _univoci AS
  SELECT lower(strip_accents(comune)) AS chiave, any_value(codice_istat) AS codice_istat
  FROM istat_confini_comuni GROUP BY 1 HAVING count(*) = 1`);

await con.run(`CREATE OR REPLACE TABLE beni_culturali AS
  WITH punti AS (
    -- Point-in-polygon: esatto, e non si fida del nome. Vale per i luoghi con
    -- coordinate, e sono meno della metà.
    SELECT b.uri, g.codice_istat
    FROM _grezzo b
    JOIN istat_confini_comuni g
      ON b.lat IS NOT NULL AND b.lon IS NOT NULL
     AND ST_Within(ST_Point(b.lon, b.lat), ST_GeomFromGeoJSON(g.geojson))
  )
  SELECT b.uri,
    b.id,
    b.nome,
    b.indirizzo,
    b.comune_dichiarato,
    b.lat, b.lon,
    coalesce(p.codice_istat, u.codice_istat) AS codice_istat,
    -- come è stato ricavato il codice: chi mappa vuole poterlo sapere
    CASE WHEN p.codice_istat IS NOT NULL THEN 'coordinate'
         WHEN u.codice_istat IS NOT NULL THEN 'nome'
         ELSE NULL END AS aggancio,
    g.comune, g.provincia, g.regione
  FROM _grezzo b
  LEFT JOIN punti p ON p.uri = b.uri
  LEFT JOIN _univoci u ON u.chiave = lower(strip_accents(b.comune_dichiarato))
  LEFT JOIN istat_confini_comuni g ON g.codice_istat = coalesce(p.codice_istat, u.codice_istat)
  ORDER BY b.nome`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT
  count(*) luoghi,
  count(lat) con_coordinate,
  count(*) FILTER (WHERE aggancio = 'coordinate') per_coordinate,
  count(*) FILTER (WHERE aggancio = 'nome') per_nome,
  count(*) FILTER (WHERE codice_istat IS NULL) senza_comune,
  count(DISTINCT codice_istat) comuni
  FROM beni_culturali`);
console.log(`  luoghi:            ${st.luoghi}`);
console.log(`  con coordinate:    ${st.con_coordinate}`);
console.log(`  codice ISTAT:      ${st.per_coordinate} per point-in-polygon + ${st.per_nome} per nome univoco`);
console.log(`  senza comune:      ${st.senza_comune} (nome ambiguo e nessuna coordinata)`);
console.log(`  comuni coperti:    ${st.comuni}`);

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
  "beni_culturali",
  "dati.cultura.gov.it",
  "mic/arco-luoghi-della-cultura",
  "Luoghi della cultura (MiC)",
  "Cultural institutes and sites (MiC)",
  `Musei, archivi, biblioteche, aree archeologiche e monumenti d'Italia, dal grafo della conoscenza del Ministero della Cultura (ArCo / Cultural-ON): nome, indirizzo, comune e coordinate. Circa il 40% dei luoghi ha lat/lon ed è mappabile direttamente con ::map; per gli altri resta il comune. Il campo aggancio dice COME è stato ricavato il codice ISTAT — "coordinate" quando il punto cade dentro il confine comunale, "nome" quando il nome del comune è univoco in Italia, vuoto quando il nome è ambiguo e non ci sono coordinate: in quel caso il codice è NULL invece che indovinato. Si incrocia con turismo_capacita e istat_popolazione per luoghi per abitante e posti letto per luogo.`,
  `Museums, archives, libraries, archaeological areas and monuments across Italy, from the Ministry of Culture knowledge graph (ArCo / Cultural-ON): name, address, municipality and coordinates. About 40% of sites carry lat/lon and map directly with ::map; the rest still carry the municipality. The aggancio field records HOW the ISTAT code was derived — "coordinate" when the point falls inside the municipal boundary, "nome" when the municipality name is unique in Italy, empty when the name is ambiguous and there are no coordinates: the code is then NULL rather than guessed. Joins with turismo_capacita and istat_popolazione for sites per inhabitant and beds per site.`,
  "https://dati.cultura.gov.it/",
  Number(st.luoghi),
);

console.log(`\nbeni_culturali: ${st.luoghi} luoghi in ${st.comuni} comuni`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb.
await con.run("CHECKPOINT");
con.closeSync();
