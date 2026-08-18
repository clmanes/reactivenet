// Ingestione del PROGRAMMA NAZIONALE ESITI (AGENAS) → due tabelle in DuckDB +
// righe nel `catalog`:
//
//   pne_indicatori   gli indicatori di esito, con la loro area clinica
//   pne_esiti        il valore di ogni indicatore per ogni struttura e per ogni
//                    azienda sanitaria, nell'edizione corrente
//
// **È il dato sanitario più utile che esista, e qui dentro non c'era.** Tutto il
// resto della sanità nel warehouse descrive una DOTAZIONE — quanti letti, quanto
// personale, quante strutture — e nessuna di quelle cose dice se le persone
// guariscono. Il PNE sì: misura, struttura per struttura e aggiustando per il
// rischio dei pazienti trattati, la mortalità a trenta giorni dopo un infarto,
// quanti femori vengono operati entro due giorni, quanti parti finiscono in
// cesareo. È la differenza fra sapere che un ospedale ha duecento letti e sapere
// come ci si esce.
//
// **Questo ETL esiste perché una ricognizione frettolosa aveva concluso il
// contrario.** Era stato scritto — sul sito e in questo repository — che gli esiti
// «si consultano struttura per struttura da un'interfaccia, non si scaricano».
// Falso: il portale è un'applicazione a pagina singola che parla con una API REST
// aperta, dichiarata nella sua stessa configurazione (`assets/config.json`,
// `apiUrl`), senza chiave e senza autenticazione. Guardare quali richieste fa il
// sito invece di guardare il sito è la differenza fra le due conclusioni, ed è la
// stessa disciplina con cui è stato trovato — e trovato SPENTO — il Punto di
// Accesso Nazionale della mobilità.
//
// Fonte: https://pne.agenas.it/pne (AGENAS, Programma Nazionale Esiti)
//
// TRAPPOLE:
//  - **le edizioni sono quattro e tre sono OFFLINE.** Il portale ne mostra una
//    sola, quella che la sua configurazione chiama `defaultEdition`; le altre
//    esistono nell'API ma il pubblicatore non le espone più. Si prende quella
//    corrente e basta: ripubblicare un'edizione ritirata sarebbe rimettere in
//    circolo numeri che AGENAS ha tolto, il che è peggio che non averli. L'ETL
//    la sceglie leggendo lo stato, non scrivendo un anno a mano;
//  - **si pagina, e il tetto è 2000 per pagina.** Non c'è un file in blocco e
//    `paged=false` è ignorato: l'edizione corrente sono ~350.000 valori, cioè
//    175 richieste da un secondo l'una. Ci sono anche 1,36 milioni di valori
//    contando tutte le edizioni, ed è esattamente il numero che NON va scaricato
//    per le ragioni qui sopra;
//  - **il campo `valore` cambia forma secondo il tipo di indicatore.** Ce ne sono
//    33 di tipi, alcuni con serie per anno, altri stratificati. Le tre grandezze
//    che tornano quasi sempre — numerosità, percentuale grezza e percentuale
//    AGGIUSTATA per il rischio — diventano colonne; il resto resta nel JSON
//    originale invece di essere buttato o forzato in uno schema che non ha;
//  - **666 NON È UN VALORE: è la sentinella di «aggiustamento non calcolato».**
//    Compare 7886 volte, solo nella colonna aggiustata — nel valore grezzo mai —
//    e sempre su righe con poche decine di casi, dove un aggiustamento per rischio
//    non avrebbe basi. Lasciarla dentro significa scrivere «666% di mortalità»
//    accanto al nome di un ospedale, cioè diffamare un reparto con un dato
//    ufficiale. Diventa NULL. E si toglie da QUELLA colonna soltanto: `casi` = 666
//    esiste ed è vero, sono le 666 PTCA del Gemelli;
//  - **la stessa colonna porta unità diverse secondo l'indicatore**, ed è il
//    motivo per cui non si chiama «percentuale»: per gli indicatori di VOLUME i
//    numeri sono conteggi — il Federico II ha 3046 sotto quella colonna per il
//    volume dei parti — mentre per mortalità e proporzioni sono percentuali. La
//    colonna `misura` dice quale delle due, e senza guardarla si sommano mele e
//    pere con la faccia di un dato ufficiale;
//  - **`perc_adj` è la colonna che conta, e confondere le due è il modo classico
//    di calunniare un ospedale.** La percentuale grezza mette insieme pazienti
//    che non sono confrontabili: un centro che prende i casi più gravi ha una
//    mortalità grezza più alta *proprio perché* fa il suo mestiere. L'aggiustata
//    è quella che AGENAS pubblica per il confronto, e la descrizione di catalogo
//    lo dice a chi scriverà la query;
//  - **il comune del PNE non porta il codice ISTAT**: ha solo il nome in
//    maiuscolo e un riferimento alla provincia. Si aggancia come le strutture del
//    Ministero — nome normalizzato più sigla, togliendo l'apostrofo che sta per
//    l'accento e leggendo la parte italiana dei nomi bilingui altoatesini — e la
//    copertura ottenuta è stampata invece di essere data per scontata;
//  - i codici struttura del PNE hanno OTTO caratteri, quelli del Ministero SEI:
//    sono due sistemi di numerazione diversi e non si agganciano fra loro. Le due
//    tabelle si incontrano per comune, non per codice, e fingere il contrario
//    produrrebbe righe unite a caso.
//
// Uso:  bun etl/pne-esiti.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/pne/";
const DB = ROOT + "warehouse.duckdb";
const API = "https://pne.agenas.it/pne";
const PAGINA = 2000;

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ Programma Nazionale Esiti (AGENAS)");

const chiedi = async url => {
  const res = await fetch(url, { signal: AbortSignal.timeout(180_000) });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return res.json();
};

// Scarica un'entità intera seguendo la paginazione di Spring Data.
async function tutto(percorso, etichetta) {
  const dest = RAW + etichetta + ".json";
  if (!refresh && (await Bun.file(dest).exists())) {
    return JSON.parse(await Bun.file(dest).text());
  }
  const separatore = percorso.includes("?") ? "&" : "?";
  const prima = await chiedi(`${API}/${percorso}${separatore}size=${PAGINA}&page=0`);
  const righe = [...prima.content];
  const pagine = prima.totalPages ?? 1;
  for (let p = 1; p < pagine; p++) {
    const parte = await chiedi(`${API}/${percorso}${separatore}size=${PAGINA}&page=${p}`);
    righe.push(...parte.content);
    if (pagine > 20 && p % 25 === 0)
      console.log(`    ${etichetta}: ${righe.length}/${prima.totalElements}`);
  }
  await Bun.write(dest, JSON.stringify(righe));
  console.log(`  ${etichetta}: ${righe.length} righe${pagine > 1 ? ` (${pagine} pagine)` : ""}`);
  return righe;
}

// L'edizione corrente è quella che il pubblicatore tiene in linea: le altre sono
// dichiarate OFFLINE e ripubblicarle rimetterebbe in circolo numeri ritirati.
const edizioni = await tutto("edizioni", "edizioni");
const corrente =
  edizioni.find(e => e.stato === "IN_CORSO") ??
  edizioni.find(e => e.stato === "ONLINE") ??
  edizioni[edizioni.length - 1];
if (!corrente) throw new Error("nessuna edizione dichiarata dall'API");
console.log(`  edizione corrente: ${corrente.descr} (${corrente.stato})`);

const [indicatori, aree, strutture, asl, comuni, province, regioni, tipiStruttura] =
  await Promise.all([
    tutto("indicatori", "indicatori"),
    tutto("aree-cliniche", "aree-cliniche"),
    tutto("strutture", "strutture"),
    tutto("asl", "asl"),
    tutto("comuni", "comuni"),
    tutto("province", "province"),
    tutto("regioni", "regioni"),
    tutto("strutture-types", "strutture-types"),
  ]);

const valori = await tutto(`valori?edizione=${corrente.id}`, "valori");

// --- indici in memoria --------------------------------------------------------
const per = righe => new Map(righe.map(r => [r.id, r]));
const iIndicatori = per(indicatori);
const iAree = per(aree);
const iStrutture = per(strutture);
const iAsl = per(asl);
const iComuni = per(comuni);
const iProvince = per(province);
const iRegioni = per(regioni);
const iTipi = per(tipiStruttura);

const rif = (mappa, campo) => (campo && campo.id ? (mappa.get(campo.id) ?? null) : null);

// Che cosa MISURA un indicatore, per i sette tipi che l'API dichiara. È una mappa
// EDITORIALE — l'endpoint `indicatori-types` risponde 403, quindi i nomi non si
// possono leggere dalla fonte — ricavata guardando le descrizioni di ciascun
// gruppo e verificata sui casi limite. Serve a una cosa sola, ed è grossa: le
// stesse due colonne portano una PERCENTUALE per gli indicatori di esito e un
// CONTEGGIO per quelli di volume. Il Federico II ha 3046 sotto la colonna
// «percentuale aggiustata» per il volume dei parti, e chiunque la legga come una
// percentuale legge una cifra assurda con l'aria di un dato. Da qui il nome
// neutro delle colonne e questa mappa accanto.
const MISURA = {
  "825ee82b": "volume",         // volume di ricoveri / di interventi (354)
  "2b412680": "proporzione",    // proporzioni, percentuali di processo (197)
  "5e2b9638": "ospedalizzazione", // tassi di ospedalizzazione (148)
  "d8d6329d": "mortalità",      // mortalità a 30 giorni, a 1 anno (123)
  "719896db": "degenza",        // giornate di degenza postoperatoria (8)
  "63b3339f": "volume",         // volumi di interventi (4)
  "fc41d5ba": "tasso",          // tassi di accesso al pronto soccorso (4)
};
const misuraDi = indicatore => {
  const id = (indicatore?.type ?? {}).id;
  return id ? (MISURA[String(id).slice(0, 8)] ?? null) : null;
};

const righeEsiti = valori.map(v => {
  const struttura = rif(iStrutture, v.struttura);
  const azienda = rif(iAsl, v.asl);
  const comune = rif(iComuni, struttura?.comune ?? v.comune);
  const provincia = rif(iProvince, comune?.provincia);
  const indicatore = rif(iIndicatori, v.indicatore);
  const area = rif(iAree, indicatore?.areaClinica ?? indicatore?.area);
  const regione = rif(iRegioni, azienda?.regione ?? provincia?.regione);
  const valore = v.valore ?? {};
  // Fra le "strutture" ce ne sono due che ospedali non sono: il codice 00000001
  // e' l'ITALIA — l'aggregato nazionale, cioe' il termine di paragone piu' utile
  // che ci sia — e 00000000 e' "Altre Strutture", il fondo in cui finisce quello
  // che non e' attribuito. Lasciarle passare per ospedali metterebbe l'Italia in
  // una classifica di ospedali e falserebbe ogni media: si distinguono qui, una
  // volta, invece di chiedere a ogni query di ricordarsene.
  const livello = !struttura
    ? azienda
      ? "asl"
      : "altro"
    : struttura.codice === "00000001"
      ? "italia"
      : struttura.codice === "00000000"
        ? "non attribuito"
        : "struttura";
  return {
    livello,
    codice_indicatore: indicatore?.codice ?? null,
    indicatore: indicatore?.descr ?? null,
    area_clinica: area?.descr ?? null,
    codice_struttura: struttura?.codice ?? null,
    // Le denominazioni arrivano con tabulazioni e spazi doppi dentro.
    struttura: (struttura?.descr ?? "").replace(/\s+/g, " ").trim() || null,
    tipo_struttura: rif(iTipi, struttura?.type)?.descr ?? null,
    codice_asl: azienda?.codice ?? null,
    asl: azienda?.descr ?? null,
    comune_dichiarato: comune?.descr ?? null,
    sigla: provincia?.sigla ?? null,
    regione: regione?.descr ?? null,
    misura: misuraDi(indicatore),
    casi: valore.n ?? null,
    perc: valore.perc ?? null,
    perc_adj: valore.perc_adj ?? null,
    valore_json: JSON.stringify(valore),
  };
});

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const grezzoEsiti = RAW + "esiti.json";
await Bun.write(grezzoEsiti, righeEsiti.map(r => JSON.stringify(r)).join("\n"));
await con.run(`CREATE OR REPLACE TEMP TABLE _esiti AS
  SELECT * FROM read_json_auto('${esc(grezzoEsiti)}', format = 'newline_delimited')`);

// Il nome del comune arriva in maiuscolo e senza codice: stessa normalizzazione
// delle strutture del Ministero — apostrofo per accento, nome bilingue altoatesino.
// Apostrofo per accento («FORLI'»), nome bilingue altoatesino («Bolzano/Bozen»)
// e spaziatura che balla («Castelnovo Ne'monti» contro «Castelnovo ne' Monti»):
// togliendo apostrofi E spazi i tre casi si riducono a uno. Dentro la stessa
// provincia due comuni diversi non collassano l'uno sull'altro.
const nome = col =>
  `upper(strip_accents(replace(replace(${col}, '''', ''), ' ', '')))`;

// L'API restituisce la STESSA misura piu' volte per la stessa coppia
// (indicatore, struttura): righe identiche fino al JSON del valore, che non
// portano niente in piu' e che raddoppiano un ospedale in qualunque classifica o
// media. Si tengono distinte. La deduplica e' sul JSON e non sui numeri estratti,
// perche' due misure diverse dello stesso indicatore — una puntuale e una serie
// per anno — sono righe legittimamente diverse che vanno tenute entrambe.
await con.run(`CREATE OR REPLACE TABLE pne_esiti AS
  SELECT DISTINCT e.livello,
    ${Number(corrente.descr) || "NULL"} AS edizione,
    e.codice_indicatore, e.indicatore, e.area_clinica, e.misura,
    e.codice_struttura, e.struttura, e.tipo_struttura,
    e.codice_asl, e.asl,
    g.codice_istat,
    coalesce(g.comune, e.comune_dichiarato) AS comune,
    e.sigla, e.regione,
    TRY_CAST(e.casi AS BIGINT) AS casi,
    TRY_CAST(e.perc AS DOUBLE) AS valore_grezzo,
    -- 666 non e' un valore: e' la sentinella con cui AGENAS dice «aggiustamento
    -- non calcolato», e compare 7886 volte su righe con poche decine di casi,
    -- dove un aggiustamento per rischio non ha basi. Sta SOLO in questa colonna —
    -- nel grezzo non compare mai — e va tolta qui, perche' lasciata dentro
    -- metterebbe «666% di mortalita'» in una classifica di ospedali, che e' il
    -- modo piu' rapido di diffamare un reparto con un dato ufficiale. Attenzione:
    -- casi = 666 esiste ed e' vero (666 PTCA al Gemelli), quindi la sentinella
    -- si toglie da una colonna sola e non dalla riga.
    nullif(TRY_CAST(e.perc_adj AS DOUBLE), 666) AS valore_aggiustato,
    e.valore_json
  FROM _esiti e
  LEFT JOIN istat_confini_comuni g
    ON g.sigla = e.sigla
   AND ${nome("split_part(g.comune, '/', 1)")} = ${nome("e.comune_dichiarato")}
  ORDER BY e.codice_indicatore, e.struttura`);

const grezzoInd = RAW + "indicatori-piatti.json";
await Bun.write(
  grezzoInd,
  indicatori
    .map(i =>
      JSON.stringify({
        codice: i.codice ?? null,
        descrizione: i.descr ?? null,
        area_clinica: rif(iAree, i.areaClinica ?? i.area)?.descr ?? null,
        edizione: rif(per(edizioni), i.edizione)?.descr ?? null,
      }),
    )
    .join("\n"),
);
await con.run(`CREATE OR REPLACE TABLE pne_indicatori AS
  SELECT DISTINCT codice, descrizione, area_clinica, TRY_CAST(edizione AS INTEGER) AS edizione
  FROM read_json_auto('${esc(grezzoInd)}', format = 'newline_delimited')
  WHERE codice IS NOT NULL
  ORDER BY codice`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];
const st = await q(`SELECT count(*) righe,
  count(DISTINCT codice_indicatore) indicatori,
  count(DISTINCT codice_struttura) FILTER (WHERE livello = 'struttura') strutture,
  count(DISTINCT codice_asl) aziende,
  count(DISTINCT codice_istat) comuni,
  count(*) FILTER (WHERE codice_istat IS NULL AND comune IS NOT NULL) senza_comune,
  count(*) FILTER (WHERE valore_aggiustato IS NOT NULL) con_aggiustata
  FROM pne_esiti`);
console.log(
  `  esiti: ${st.righe} righe · ${st.indicatori} indicatori · ${st.strutture} strutture · ` +
    `${st.aziende} aziende · ${st.comuni} comuni`,
);
console.log(
  `  di cui ${st.con_aggiustata} con la percentuale aggiustata per il rischio` +
    (Number(st.senza_comune) > 0
      ? ` · ${st.senza_comune} righe con un comune non agganciato ai confini`
      : ""),
);

// Un esempio stampato, perché un numero senza il suo significato non si controlla:
// la mortalità a 30 giorni dopo infarto è l'indicatore più noto del PNE.
const esempio = await q(`SELECT struttura, comune, casi, valore_grezzo, valore_aggiustato
  FROM pne_esiti
  WHERE misura = 'mortalità' AND indicatore ILIKE '%infarto%' AND indicatore ILIKE '%30 giorni%'
    AND livello = 'struttura' AND casi > 300 AND valore_aggiustato > 0
  ORDER BY casi DESC LIMIT 1`);
if (esempio)
  console.log(
    `  esempio: ${esempio.struttura} (${esempio.comune}) — ${esempio.casi} casi, ` +
      `${esempio.valore_grezzo}% grezzo contro ${esempio.valore_aggiustato}% aggiustato ` +
      `(mortalità a 30 giorni dall'infarto)`,
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
  "pne_esiti",
  "pne.agenas.it",
  "agenas/programma-nazionale-esiti",
  "Esiti delle cure per struttura (PNE — AGENAS)",
  "Care outcomes by hospital (PNE — AGENAS)",
  `Come vanno a finire le cure, struttura per struttura: mortalità a trenta giorni dopo un infarto o un ictus, quota di femori operati entro due giorni, parti cesarei, riammissioni. È l'unica misura di ESITO della sanità nel warehouse — tutto il resto (posti letto, personale, strutture) descrive una dotazione e non dice se le persone guariscono. Una riga è un indicatore misurato su una struttura o su un'azienda sanitaria: \`livello\` dice quale dei due. LA COLONNA DA USARE È \`valore_aggiustato\`, non \`valore_grezzo\`: il grezzo mette insieme pazienti non confrontabili, e un centro che prende i casi più gravi ha una mortalità grezza più alta proprio perché fa il suo mestiere — l'aggiustato per rischio è quello che AGENAS pubblica per il confronto. LEGGERE SEMPRE \`misura\` PRIMA DEL NUMERO: la stessa colonna porta una PERCENTUALE quando misura vale 'mortalità', 'proporzione', 'ospedalizzazione' o 'tasso', e un CONTEGGIO quando vale 'volume' — sommarle insieme mette parti e percentuali nello stesso totale. Il valore 666 dell'origine, con cui AGENAS segnala «aggiustamento non calcolato» su numerosità troppo basse, è già stato tolto: qui è NULL, e non va reintrodotto leggendo \`valore_json\`. \`casi\` è la numerosità, e un indicatore su pochi casi non è confrontabile con niente: AGENAS stessa non ne pubblica il valore sotto certe soglie. Si aggancia al resto del warehouse per \`codice_istat\` del comune della struttura; NON per codice struttura, che nel PNE ha otto caratteri e nei file del Ministero sei, due sistemi di numerazione diversi. Solo l'edizione corrente: le precedenti sono dichiarate OFFLINE dal pubblicatore.`,
  `How care actually ends, hospital by hospital: thirty-day mortality after a heart attack or stroke, share of hip fractures operated within two days, caesarean sections, readmissions. It is the only OUTCOME measure of health care in the warehouse — everything else (beds, staff, facilities) describes provision and does not say whether people get better. A row is one indicator measured on one facility or one health authority: \`livello\` says which. THE COLUMN TO USE IS \`valore_aggiustato\`, not \`valore_grezzo\`: the crude rate pools patients who are not comparable, and a centre that takes the severest cases has a higher crude mortality precisely because it is doing its job — the risk-adjusted figure is the one AGENAS publishes for comparison. ALWAYS READ \`misura\` BEFORE THE NUMBER: the same column carries a PERCENTAGE when misura is 'mortalità', 'proporzione', 'ospedalizzazione' or 'tasso', and a COUNT when it is 'volume' — adding them together puts births and percentages in one total. The source's 666, with which AGENAS flags "adjustment not computed" on too-small denominators, has already been removed: here it is NULL, and must not be reintroduced by reading \`valore_json\`. \`casi\` is the case count, and an indicator over few cases is comparable with nothing: AGENAS itself withholds values below certain thresholds. It joins the rest of the warehouse through the facility's municipality \`codice_istat\`; NOT through the facility code, which has eight characters here and six in the Ministry files — two different numbering systems. Current edition only: the earlier ones are declared OFFLINE by the publisher.`,
  "https://pne.agenas.it/",
  Number(st.righe),
);

const ind = await q(`SELECT count(*) n FROM pne_indicatori`);
await catalog(
  "pne_indicatori",
  "pne.agenas.it",
  "agenas/pne-indicatori",
  "Gli indicatori di esito del PNE (AGENAS)",
  "PNE outcome indicators (AGENAS)",
  `Il catalogo degli indicatori del Programma Nazionale Esiti con la loro area clinica: che cosa viene misurato, prima di guardare quanto vale. Serve per capire \`pne_esiti\` senza doverne leggere le descrizioni riga per riga — e per accorgersi che «mortalità a 30 giorni» esiste per una decina di condizioni diverse, che non vanno confuse fra loro.`,
  `The catalogue of Programma Nazionale Esiti indicators with their clinical area: what is being measured, before looking at what it comes to. It is how to read \`pne_esiti\` without going through its descriptions row by row — and how to notice that "thirty-day mortality" exists for a dozen different conditions that must not be mixed up.`,
  "https://pne.agenas.it/",
  Number(ind.n),
);

console.log(`\npne_esiti: ${st.righe} righe · pne_indicatori: ${ind.n}`);
await con.run("CHECKPOINT");
con.closeSync();
