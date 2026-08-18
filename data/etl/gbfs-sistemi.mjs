// Ingestione del CATALOGO dei sistemi di sharing GBFS in Italia → tabella
// `gbfs_sistemi` in DuckDB + riga nel `catalog`. Una riga per sistema: chi lo
// gestisce, in che comune, e a quale URL risponde in tempo reale.
//
// **QUI DENTRO NON C'È NIENTE IN TEMPO REALE, ED È DELIBERATO.** Un monopattino
// si sposta ogni minuto e il warehouse si aggiorna a cadenza di giorni: una
// fotografia delle posizioni salvata qui sarebbe un dato vecchio che *sembra*
// vivo, cioè l'inganno peggiore che un dato possa fare. Quello che è statico —
// quali sistemi esistono, dove, e a quale indirizzo rispondono — è metadato di
// catalogo e sta bene qui; le posizioni si leggono dal browser con
// `::api-query{every="60"}`, che è il posto giusto perché è l'unico che le
// guarda nel momento in cui qualcuno le sta guardando.
//
// Fonte: il catalogo ufficiale GBFS di MobilityData (CC0), che è l'elenco che i
// gestori stessi aggiornano via pull request:
//   https://raw.githubusercontent.com/MobilityData/gbfs/master/systems.csv
//
// GBFS (General Bikeshare Feed Specification) è lo standard che rende questa
// tabella possibile: 36 sistemi di otto operatori diversi rispondono tutti con
// la stessa forma, senza chiave e con `Access-Control-Allow-Origin: *` — cioè
// leggibili da una pagina web senza proxy. È il motivo per cui la micromobilità
// è l'unico pezzo di mobilità italiana disponibile in tempo reale a chiunque.
//
// COPERTURA, detta per intero perché è il limite della cosa: **26 comuni
// elencati su 7896, e 23 con un feed che risponde davvero** — le due cifre vanno
// tenute distinte, perché è la seconda quella su cui si può disegnare qualcosa.
// Il tempo reale in Italia esiste dove c'è lo sharing e finisce lì; una
// dashboard che promettesse dati in diretta «per ogni comune» starebbe mentendo.
//
// TRAPPOLE:
//  - **i nomi di città sono ESONIMI INGLESI** — Naples, Florence, Milan, Rome,
//    Turin, Padua — più qualche variante locale (Lido di Jesolo per Jesolo,
//    Mazara per Mazara del Vallo, Reggio Emilia per Reggio nell'Emilia). Il join
//    per nome contro i confini fallirebbe su un terzo delle righe, quindi c'è
//    una mappa EDITORIALE, verificata a mano contro `istat_confini_comuni` —
//    stesso precedente della tabella delle province in `aci-veicoli.mjs`. È
//    piccola (23 voci) e va corretta a mano quando il catalogo cresce: l'ETL
//    ELENCA le città che non ha saputo agganciare invece di lasciarle cadere,
//    perché una riga persa in silenzio qui è un comune che non avrà mai la sua
//    pagina in tempo reale e nessuno saprà perché;
//  - **ogni feed viene interrogato davvero**, uno per uno, e si tiene il numero
//    di veicoli che ha risposto. Un sistema può stare nel catalogo ed essere
//    spento — l'operatore che lascia una città non manda una pull request — e
//    un URL elencato senza essere provato è esattamente il tipo di dato che
//    fallisce dopo, davanti a chi lo usa. La colonna `veicoli_alla_verifica` non
//    è un dato di traffico: è la prova che il feed rispondeva;
//  - il documento di scoperta (`gbfs.json`) elenca i feed per LINGUA, e la
//    lingua non è sempre `it` né sempre `en`: si prende la prima disponibile;
//  - due nomi convivono per la stessa cosa — `free_bike_status` in GBFS 2.x è
//    diventato `vehicle_status` in 3.0 (Cooltra) — e i sistemi a stazione
//    (BikeMi, nextbike, Verona Bike) non hanno né l'uno né l'altro: hanno
//    `station_status`. La colonna `tipo` distingue i due mondi, perché a chi
//    disegna una mappa servono cose diverse: veicoli sparsi o stazioni fisse.
//
// Uso:  bun etl/gbfs-sistemi.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/gbfs/";
const DB = ROOT + "warehouse.duckdb";
const CATALOGO = "https://raw.githubusercontent.com/MobilityData/gbfs/master/systems.csv";

// Mappa EDITORIALE città del catalogo → comune italiano (vedi trappole).
const COMUNE = {
  Naples: "Napoli",
  Florence: "Firenze",
  Milan: "Milano",
  Rome: "Roma",
  Turin: "Torino",
  Padua: "Padova",
  Genova: "Genova",
  "Cagliari, IT": "Cagliari",
  "Lido di Jesolo": "Jesolo",
  "Senigallia, IT": "Senigallia",
  Mazara: "Mazara del Vallo",
  "Reggio Emilia": "Reggio nell'Emilia",
  Arezzo: "Arezzo",
  Bari: "Bari",
  Bergamo: "Bergamo",
  Catania: "Catania",
  Ferrara: "Ferrara",
  Lecco: "Lecco",
  Modena: "Modena",
  Monza: "Monza",
  Palermo: "Palermo",
  Trento: "Trento",
  Varese: "Varese",
  Verona: "Verona",
  Anzio: "Anzio",
  Augusta: "Augusta",
};

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ catalogo dei sistemi di sharing GBFS in Italia");

const locale = RAW + "systems.csv";
if (refresh || !(await Bun.file(locale).exists())) {
  const res = await fetch(CATALOGO, { signal: AbortSignal.timeout(120_000) });
  if (!res.ok) throw new Error(`catalogo GBFS: HTTP ${res.status}`);
  await Bun.write(locale, await res.text());
}

// --- CSV → righe italiane -----------------------------------------------------
function parseCsv(testo) {
  const righe = [];
  let campo = "";
  let riga = [];
  let quoted = false;
  for (let i = 0; i < testo.length; i++) {
    const ch = testo[i];
    if (quoted) {
      if (ch === '"' && testo[i + 1] === '"') { campo += '"'; i++; }
      else if (ch === '"') quoted = false;
      else campo += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") { riga.push(campo); campo = ""; }
    else if (ch === "\n") { riga.push(campo); righe.push(riga); riga = []; campo = ""; }
    else if (ch !== "\r") campo += ch;
  }
  if (campo || riga.length) { riga.push(campo); righe.push(riga); }
  const testa = righe.shift();
  return righe
    .filter(r => r.length === testa.length)
    .map(r => Object.fromEntries(testa.map((k, i) => [k, r[i]])));
}

const tutti = parseCsv(await Bun.file(locale).text());
const italiani = tutti.filter(r => r["Country Code"] === "IT");
console.log(`  ${tutti.length} sistemi nel mondo, ${italiani.length} in Italia`);

// --- verifica di ogni feed, uno per uno ---------------------------------------
async function interroga(discovery) {
  const risposta = await fetch(discovery, { signal: AbortSignal.timeout(25_000) });
  if (!risposta.ok) throw new Error(`HTTP ${risposta.status}`);
  const doc = await risposta.json();
  // GBFS 2.x annida i feed per LINGUA (`data.it.feeds`); la 3.0 ha tolto quel
  // livello e li mette in `data.feeds`. Trattare la 3.0 come la 2.x prende il
  // primo valore di `data` — che è già l'array — e poi ne cerca `.feeds`, che
  // non esiste: i tre sistemi Cooltra risultavano «senza feed» pur essendo vivi.
  const scoperta = doc.data ?? {};
  const feeds = Array.isArray(scoperta.feeds)
    ? scoperta.feeds
    : ((scoperta.it ?? scoperta.en ?? Object.values(scoperta)[0])?.feeds ?? []);
  const trova = nome => feeds.find(f => f.name === nome)?.url ?? null;
  // free_bike_status (GBFS 2.x) e vehicle_status (3.0) sono la stessa cosa
  const liberi = trova("free_bike_status") ?? trova("vehicle_status");
  const stazioni = trova("station_status");
  const url = liberi ?? stazioni;
  if (!url) throw new Error("nessun feed di veicoli o stazioni");
  const dati = await (await fetch(url, { signal: AbortSignal.timeout(25_000) })).json();
  const d = dati.data ?? {};
  const n = (d.bikes ?? d.vehicles ?? d.stations ?? []).length;
  return { tipo: liberi ? "veicoli" : "stazioni", url, veicoli: n };
}

const esiti = [];
for (const s of italiani) {
  const base = {
    sistema: s["System ID"],
    nome: s.Name,
    citta: s.Location,
    comune: COMUNE[s.Location] ?? null,
    versioni: s["Supported Versions"],
    discovery: s["Auto-Discovery URL"],
  };
  try {
    const v = await interroga(base.discovery);
    esiti.push({ ...base, ...v, errore: null });
  } catch (e) {
    esiti.push({ ...base, tipo: null, url: null, veicoli: null, errore: String(e.message ?? e) });
  }
}

const vivi = esiti.filter(e => !e.errore);
const morti = esiti.filter(e => e.errore);
console.log(`  ${vivi.length} feed rispondono, ${morti.length} no`);
for (const m of morti) console.log(`    ✗ ${m.nome}: ${m.errore}`);

const senzaComune = [...new Set(esiti.filter(e => !e.comune).map(e => e.citta))];
if (senzaComune.length)
  console.log(
    `  ⚠ città non mappate a un comune (aggiungerle a COMUNE in questo file): ` +
      senzaComune.join(", "),
  );

// --- in DuckDB ----------------------------------------------------------------
const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const val = v => (v === null || v === undefined ? "NULL" : `'${esc(v)}'`);
const num = v => (v === null || v === undefined ? "NULL" : Number(v));
const valori = esiti
  .map(
    e =>
      `(${val(e.sistema)}, ${val(e.nome)}, ${val(e.citta)}, ${val(e.comune)}, ` +
      `${val(e.tipo)}, ${val(e.discovery)}, ${val(e.url)}, ${num(e.veicoli)}, ` +
      `${val(e.versioni)}, ${val(e.errore)})`,
  )
  .join(",\n    ");

await con.run(`CREATE OR REPLACE TEMP TABLE _grezzo (
  sistema VARCHAR, nome VARCHAR, citta VARCHAR, comune_mappato VARCHAR,
  tipo VARCHAR, discovery VARCHAR, url VARCHAR, veicoli BIGINT,
  versioni VARCHAR, errore VARCHAR)`);
await con.run(`INSERT INTO _grezzo VALUES\n    ${valori}`);

await con.run(`CREATE OR REPLACE TABLE gbfs_sistemi AS
  SELECT r.sistema,
    r.nome,
    r.citta AS citta_catalogo,
    g.codice_istat,
    coalesce(g.comune, r.comune_mappato) AS comune,
    g.sigla,
    g.provincia,
    g.regione,
    r.tipo,
    r.discovery AS url_scoperta,
    r.url AS url_stato,
    r.veicoli AS veicoli_alla_verifica,
    r.versioni,
    r.errore
  FROM _grezzo r
  LEFT JOIN istat_confini_comuni g ON g.comune = r.comune_mappato
  ORDER BY 5, 2`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT count(*) righe,
  count(DISTINCT codice_istat) comuni,
  count(*) FILTER (WHERE codice_istat IS NULL) senza_comune,
  count(*) FILTER (WHERE errore IS NULL) vivi,
  sum(veicoli_alla_verifica) veicoli
  FROM gbfs_sistemi`);
console.log(
  `  righe: ${st.righe} sistemi in ${st.comuni} comuni · ${st.vivi} feed vivi · ` +
    `${st.veicoli} veicoli alla verifica`,
);
if (Number(st.senza_comune) > 0)
  console.log(`  ⚠ ${st.senza_comune} sistemi senza aggancio al comune`);

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
  "gbfs_sistemi",
  "github.com/MobilityData/gbfs",
  "mobilitydata/gbfs-systems-it",
  "Sistemi di sharing in tempo reale (GBFS)",
  "Real-time shared mobility systems (GBFS)",
  `Quali sistemi di bike e scooter sharing esistono in Italia, in che comune, e a quale indirizzo pubblicano lo stato dei loro veicoli in tempo reale secondo lo standard GBFS. QUESTA TABELLA NON CONTIENE POSIZIONI: sono metadati statici: le posizioni si leggono dal browser con \`::api-query{every="60"}\` sull'url_stato, perché un monopattino si sposta ogni minuto mentre il warehouse si aggiorna a giorni, e una fotografia salvata qui sarebbe un dato vecchio che sembra vivo. \`tipo\` distingue i sistemi a veicoli liberi (monopattini, scooter: il feed elenca mezzi sparsi) da quelli a stazione (bike sharing classico: il feed elenca stazioni con posti liberi e occupati), che si disegnano in modo diverso. \`veicoli_alla_verifica\` non è un dato di traffico ma la prova che il feed rispondeva quando l'ETL l'ha interrogato; \`errore\` dice perché un sistema elencato non ha risposto. COPERTURA: 26 comuni elencati su 7896, di cui 23 con un feed che risponde davvero — le due cifre vanno tenute distinte, perché è la seconda quella su cui si può disegnare qualcosa, e si filtra con \`errore IS NULL\`. Il tempo reale in Italia esiste dove c'è lo sharing e finisce lì, e una dashboard che lo promettesse per ogni comune starebbe mentendo. I feed sono senza chiave e con CORS aperto, quindi leggibili da una pagina web senza proxy.`,
  `Which bike and scooter sharing systems exist in Italy, in which municipality, and at what address they publish their vehicles' live status under the GBFS standard. THIS TABLE HOLDS NO POSITIONS: it is static metadata; positions are read from the browser with \`::api-query{every="60"}\` against url_stato, because a scooter moves every minute while the warehouse refreshes in days, and a snapshot stored here would be stale data that looks live. \`tipo\` separates free-floating systems (scooters, mopeds: the feed lists scattered vehicles) from station-based ones (classic bike sharing: the feed lists docks with free and taken slots), which are drawn differently. \`veicoli_alla_verifica\` is not traffic data but the proof the feed answered when the ETL asked; \`errore\` says why a listed system did not. COVERAGE: 26 municipalities listed out of 7,896, of which 23 have a feed that actually answers — keep the two figures apart, because the second is the one you can draw on, and it is filtered with \`errore IS NULL\`. Real-time in Italy exists where sharing exists and no further, and a dashboard promising it for every municipality would be lying. The feeds need no key and send open CORS, so a web page can read them without a proxy.`,
  "https://github.com/MobilityData/gbfs",
  Number(st.righe),
);

console.log(`\ngbfs_sistemi: ${st.righe} sistemi, ${st.comuni} comuni`);
await con.run("CHECKPOINT");
con.closeSync();
