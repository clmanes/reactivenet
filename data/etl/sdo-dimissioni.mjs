// Ingestione delle DIMISSIONI OSPEDALIERE — le SDO, Schede di Dimissione
// Ospedaliera (Ministero della Salute, Open Data IODL 2.0) → tre tabelle in
// DuckDB + righe nel `catalog`:
//
//   sdo_eta         ricoveri per istituto, sesso e classe d'età
//   sdo_esito       come finisce un ricovero: a casa, verso un'altra struttura,
//                   o con un decesso
//   sdo_traumi      ricoveri per azienda e tipologia di trauma
//
// **Dicono PER CHE COSA la gente finisce in ospedale, che è la domanda che né i
// posti letto né gli esiti toccano.** `sanita_posti_letto` dice quanta capienza
// c'è, `pne_esiti` come vanno a finire le cure di chi ci arriva: in mezzo mancava
// chi ci arriva, quanti anni ha, e come ne esce. Sono queste tre.
//
// `sdo_esito` è la più densa di significato e la più facile da leggere male: il
// rapporto fra decessi e dimissioni NON è la mortalità di un ospedale. Un
// hospice, una lungodegenza e un pronto soccorso di città hanno pazienti
// incomparabili, e il numero aggiustato per il rischio — l'unico confrontabile —
// sta in `pne_esiti`, non qui. Sta scritto nella descrizione di catalogo perché è
// il primo conto che verrebbe in mente.
//
// TRAPPOLE, e questi file ne hanno più di qualunque altra fonte del warehouse:
//
//  - **OGNI RIGA È UN UNICO CAMPO QUOTATO.** Il file non è un CSV con campi
//    quotati: è un CSV di UNA colonna, in cui ogni riga è una stringa che
//    *contiene* il punto e virgola, e le virgolette interne sono raddoppiate.
//    Letto come CSV normale dà una colonna sola con dentro tutto. Si legge una
//    riga per volta, si tolgono le virgolette esterne, si raddoppiano indietro
//    quelle interne, si divide sul punto e virgola e si spoglia ogni campo;
//  - **il punto è il separatore delle MIGLIAIA**: «10.487» dimissioni sono
//    diecimilaquattrocentottantasette, e lette come decimale diventano dieci.
//    Colpisce ogni conteggio di questi file, cioè tutto quello che contano;
//  - **`***` è il marcatore di dato OSCURATO**, non un valore: il Ministero lo
//    mette dove il numero è troppo piccolo per non identificare le persone.
//    Diventa NULL e non zero — uno zero direbbe «nessun ricovero», che è una cosa
//    diversa e falsa;
//  - **e da quel NULL discende la trappola peggiore: sommare le dieci colonne
//    dell'età con `+` fa sparire l'ospedale intero.** In SQL `x + NULL` è NULL, e
//    1712 righe su 2726 hanno almeno una classe oscurata — il Bambino Gesù, con
//    55.543 ricoveri, esce dal totale per una cella. Il totale nazionale calcolato
//    così dà 5,1 milioni contro i 7,6 veri, ed è un numero plausibile e sbagliato
//    di un terzo. Dove entrambi i file sono completi coincidono al ricovero
//    (Gemelli 90.841 = 90.841), il che è la prova che il parsing è giusto e che il
//    problema è solo la propagazione del NULL. **Il totale per ospedale si prende
//    da `sdo_esito`**, che ha tre colonne invece di dieci e quindi molte meno
//    occasioni di essere oscurato. E il NULL morde una seconda volta un livello
//    più su: se UNA delle due righe di un ospedale (maschi, femmine) ha una cella
//    oscurata, la sua somma è NULL e `sum()` fra le righe la SALTA — l'ospedale
//    non sparisce, compare con metà dei ricoveri. Le Molinette a 17.174 invece di
//    39.870, un numero plausibile e dimezzato, che è peggio di un numero assente;
//  - i file sono in **ISO-8859-1**: «Cl_età» letto come UTF-8 esce a pezzi;
//  - il codice istituto ha **otto caratteri** come nel PNE, mentre i file delle
//    strutture del Ministero ne usano sei: le due numerazioni non si agganciano,
//    e queste tabelle si uniscono al resto per AZIENDA o per nome, non per codice
//    struttura.
//
// Uso:  bun etl/sdo-dimissioni.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/sdo/";
const DB = ROOT + "warehouse.duckdb";
const PORTALE = "https://www.dati.salute.gov.it";

const FONTI = [
  ["dimissioni-ospedaliere-fasce-deta-e-sesso", "sdo-eta.csv"],
  ["dimissioni-ospedaliere-istituto-e-tipologia-di-dimissione", "sdo-esito.csv"],
  ["dimissioni-ospedaliere-azienda-sanitaria-e-tipologia-di-ricovero-traumatismo-o", "sdo-traumi.csv"],
];

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

mkdirSync(RAW, { recursive: true });
console.log("▸ dimissioni ospedaliere — SDO (Ministero della Salute)");

async function urlDelCsv(dataset) {
  const res = await fetch(`${PORTALE}/it/dataset/${dataset}/`, {
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`pagina ${dataset}: HTTP ${res.status}`);
  const html = await res.text();
  const m = html.match(/href="([^"]*\.csv)"/i);
  if (!m) throw new Error(`nessun CSV in ${dataset}`);
  return m[1].startsWith("http") ? m[1] : PORTALE + m[1];
}

async function prendi(dataset, nome) {
  const dest = RAW + nome;
  if (!refresh && (await Bun.file(dest).exists())) return dest;
  const url = await urlDelCsv(dataset);
  const res = await fetch(url, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${nome}: HTTP ${res.status}`);
  const grezzo = RAW + nome + ".latin1";
  await Bun.write(grezzo, await res.arrayBuffer());
  const conv = Bun.spawnSync(["iconv", "-f", "ISO-8859-1", "-t", "UTF-8", grezzo]);
  if (conv.exitCode !== 0) throw new Error(`iconv su ${nome}: ${conv.stderr}`);
  await Bun.write(dest, conv.stdout);
  return dest;
}

const [fEta, fEsito, fTraumi] = [
  await prendi(...FONTI[0]),
  await prendi(...FONTI[1]),
  await prendi(...FONTI[2]),
];
console.log("  tre file scaricati e convertiti in UTF-8");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

// Ogni riga è un unico campo quotato che CONTIENE i punti e virgola (vedi le
// trappole): si legge una riga alla volta e si spacchetta a mano.
const righeDi = f =>
  `read_csv('${esc(f)}', delim = '\\x01', header = true,
            columns = {'line': 'VARCHAR'}, ignore_errors = true)`;
const campi = `list_transform(
  string_split(replace(trim(line, chr(34)), chr(34) || chr(34), chr(34)), ';'),
  x -> trim(x, chr(34)))`;

// Il punto separa le MIGLIAIA e «***» è un dato oscurato, non un numero.
const conta = i =>
  `CASE WHEN ${campi}[${i}] = '***' THEN NULL
        ELSE TRY_CAST(replace(${campi}[${i}], '.', '') AS BIGINT) END`;
const testo = i => `nullif(${campi}[${i}], '***')`;

// ------------------------------------------------------------ per età e sesso
await con.run(`CREATE OR REPLACE TABLE sdo_eta AS
  SELECT TRY_CAST(${campi}[1] AS INTEGER) AS anno,
    ${testo(2)} AS codice_istituto,
    ${testo(3)} AS istituto,
    ${testo(4)} AS sesso,
    ${conta(5)} AS eta_0_5, ${conta(6)} AS eta_6_12, ${conta(7)} AS eta_13_18,
    ${conta(8)} AS eta_19_24, ${conta(9)} AS eta_25_34, ${conta(10)} AS eta_35_44,
    ${conta(11)} AS eta_45_54, ${conta(12)} AS eta_55_64, ${conta(13)} AS eta_65_74,
    ${conta(14)} AS eta_75_oltre
  FROM ${righeDi(fEta)}
  WHERE TRY_CAST(${campi}[1] AS INTEGER) IS NOT NULL
  ORDER BY anno, codice_istituto, sesso`);

// ------------------------------------------------------------ come finisce
await con.run(`CREATE OR REPLACE TABLE sdo_esito AS
  SELECT TRY_CAST(${campi}[1] AS INTEGER) AS anno,
    ${testo(2)} AS codice_istituto,
    ${testo(3)} AS istituto,
    ${conta(4)} AS decessi,
    ${conta(5)} AS a_domicilio,
    ${conta(6)} AS ad_altra_struttura
  FROM ${righeDi(fEsito)}
  WHERE TRY_CAST(${campi}[1] AS INTEGER) IS NOT NULL
  ORDER BY anno, codice_istituto`);

// ------------------------------------------------------------ traumi
await con.run(`CREATE OR REPLACE TABLE sdo_traumi AS
  SELECT TRY_CAST(${campi}[1] AS INTEGER) AS anno,
    ${testo(2)} || '-' || ${testo(3)} AS asl_id,
    ${testo(3)} AS codice_asl,
    ${testo(4)} AS asl,
    ${conta(5)} AS trauma_1, ${conta(6)} AS trauma_2, ${conta(7)} AS trauma_3,
    ${conta(8)} AS trauma_4, ${conta(9)} AS trauma_5, ${conta(10)} AS trauma_altro,
    ${conta(11)} AS ricoveri
  FROM ${righeDi(fTraumi)}
  WHERE TRY_CAST(${campi}[1] AS INTEGER) IS NOT NULL
  ORDER BY anno, asl_id`);

const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

const e = await q(`SELECT count(*) righe, count(DISTINCT codice_istituto) istituti,
  min(anno) dal, max(anno) al,
  sum(eta_0_5 + eta_6_12 + eta_13_18 + eta_19_24 + eta_25_34 + eta_35_44
      + eta_45_54 + eta_55_64 + eta_65_74 + eta_75_oltre) ricoveri
  FROM sdo_eta`);
console.log(
  `  per età:   ${e.righe} righe · ${e.istituti} istituti · ${e.dal}-${e.al} · ` +
    `${e.ricoveri} ricoveri`,
);

const s = await q(`SELECT count(*) righe, count(DISTINCT codice_istituto) istituti,
  sum(decessi) decessi, sum(a_domicilio) domicilio, sum(ad_altra_struttura) altrove
  FROM sdo_esito`);
console.log(
  `  esito:     ${s.righe} righe · ${s.istituti} istituti · ${s.decessi} decessi, ` +
    `${s.domicilio} a casa, ${s.altrove} verso un'altra struttura`,
);

const t = await q(`SELECT count(*) righe, count(DISTINCT asl_id) aziende,
  sum(ricoveri) ricoveri, count(*) FILTER (WHERE trauma_5 IS NULL) oscurate
  FROM sdo_traumi`);
console.log(
  `  traumi:    ${t.righe} righe · ${t.aziende} aziende · ${t.ricoveri} ricoveri · ` +
    `${t.oscurate} celle oscurate (***) tenute a NULL`,
);

// Il controllo indipendente ha due parti. La prima è la scala: i ricoveri in
// Italia sono 7-8 milioni l'anno. La seconda, più stringente, è che i due file
// devono raccontare lo STESSO numero per gli ospedali dove nessuna cella è
// oscurata — se lì divergono, il parsing è sbagliato.
const scala = Number(s.decessi) + Number(s.domicilio) + Number(s.altrove);
console.log(
  scala > 3_000_000 && scala < 12_000_000
    ? `  ✓ ${scala} dimissioni in tutto: la scala torna con quella nota del SSN`
    : `  ⚠ ${scala} dimissioni: fuori dall'ordine di grandezza atteso`,
);
// Il confronto vale SOLO sugli ospedali in cui nessuna cella e' oscurata: dove
// una lo e', la somma di quella riga e' NULL e `sum()` la salta, quindi
// l'ospedale compare con meta' dei ricoveri — le Molinette a 17.174 invece di
// 39.870. E' la stessa trappola del NULL vista un livello piu' su, ed e' peggio
// che far sparire l'ospedale: il numero resta, plausibile e dimezzato.
const accordo = await q(`SELECT count(*) confrontabili,
  -- nullif sul denominatore rende NULL il confronto quando il totale per esito
  -- e' zero, e NULL confrontato con 1 non e' vero: senza il coalesce quei sedici
  -- ospedali finivano fra i divergenti pur non divergendo affatto. E' lo stesso
  -- NULL che morde in tutta questa fonte, stavolta dentro il controllo stesso.
  count(*) FILTER (WHERE coalesce(abs(per_eta - per_esito) * 100.0
                                  / nullif(per_esito, 0), 0) < 1) uguali,
  max(coalesce(abs(per_eta - per_esito) * 100.0 / nullif(per_esito, 0), 0)) scarto_max
  FROM (SELECT e.codice_istituto,
      sum(e.eta_0_5 + e.eta_6_12 + e.eta_13_18 + e.eta_19_24 + e.eta_25_34
          + e.eta_35_44 + e.eta_45_54 + e.eta_55_64 + e.eta_65_74 + e.eta_75_oltre) per_eta,
      max(s.decessi + s.a_domicilio + s.ad_altra_struttura) per_esito
    FROM sdo_eta e JOIN sdo_esito s USING (codice_istituto, anno)
    WHERE e.codice_istituto NOT IN (
      SELECT codice_istituto FROM sdo_eta
      WHERE eta_0_5 IS NULL OR eta_6_12 IS NULL OR eta_13_18 IS NULL
         OR eta_19_24 IS NULL OR eta_25_34 IS NULL OR eta_35_44 IS NULL
         OR eta_45_54 IS NULL OR eta_55_64 IS NULL OR eta_65_74 IS NULL
         OR eta_75_oltre IS NULL)
    GROUP BY 1 HAVING per_eta IS NOT NULL)`);
// La soglia e' l'1%, e distingue due cose che a occhio si confondono: un errore di
// parsing sposta un totale del doppio o della meta', mentre i due file del
// Ministero non tornano fra loro per qualche unita' su decine di migliaia — 51
// ricoveri su 8135 a Cassino, 2 su 20.302 a Catania. Sotto l'1% e' la fonte;
// sopra, siamo noi.
const fuori = Number(accordo.confrontabili) - Number(accordo.uguali);
console.log(
  fuori === 0
    ? `  ✓ i due file si accordano entro l'1% su tutti i ${accordo.confrontabili} ospedali ` +
        `senza celle oscurate (scarto massimo ${Number(accordo.scarto_max).toFixed(2)}%)`
    : `  ⚠ i due file divergono di oltre l'1% su ${fuori} ospedali su ` +
        `${accordo.confrontabili}: il parsing va verificato`,
);
console.log(
  `  (${Number(e.righe)} righe per età, di cui molte con una classe oscurata: sommare ` +
    `le dieci colonne con + fa sparire l'ospedale, il totale sta in sdo_esito)`,
);

async function catalog(tbl, titleIt, titleEn, descIt, descEn, n) {
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
    VALUES ('${tbl}', 'dati.salute.gov.it', 'salute/sdo-dimissioni',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      'https://www.dati.salute.gov.it/', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

await catalog(
  "sdo_eta",
  "Ricoveri per età e sesso, per ospedale (SDO)",
  "Hospital admissions by age and sex (SDO)",
  `Quanti ricoveri ha avuto ogni ospedale italiano, divisi per sesso e per dieci classi d'età, dalle Schede di Dimissione Ospedaliera. Una riga è un istituto in un anno per un sesso, e le dieci colonne dell'età sono i conteggi. Risponde alla domanda che i posti letto non toccano: CHI finisce in ospedale — e il confronto fra \`eta_75_oltre\` e le classi giovani è il modo più diretto di vedere quanto un ospedale lavori sull'anziano. ATTENZIONE A SOMMARE LE DIECI COLONNE CON \`+\`: in SQL \`x + NULL\` è NULL, e 1712 righe su 2726 hanno almeno una classe oscurata, quindi quel conto fa sparire l'ospedale intero — il Bambino Gesù, 55.543 ricoveri, esce dal totale per una cella. Il totale per ospedale si prende da \`sdo_esito\`; qui si usano le singole classi, o si sommano con \`coalesce\` sapendo che il risultato è un minimo. Il codice istituto ha OTTO caratteri e non si aggancia ai file delle strutture del Ministero, che ne usano sei: queste tabelle si uniscono al resto per azienda o per nome.`,
  `How many admissions each Italian hospital had, split by sex and ten age bands, from hospital discharge records. A row is one facility in one year for one sex, and the ten age columns are the counts. It answers what bed counts cannot: WHO ends up in hospital — and comparing \`eta_75_oltre\` against the younger bands is the most direct way to see how much a hospital works with the elderly. The facility code has EIGHT characters and does not join the Ministry's facility files, which use six: MIND SUMMING THE TEN COLUMNS WITH \`+\`: in SQL \`x + NULL\` is NULL, and 1,712 of 2,726 rows have at least one suppressed band, so that sum makes the whole hospital vanish — Rome's children's hospital, 55,543 admissions, drops out of the total over one cell. Take the per-hospital total from \`sdo_esito\`; here use the individual bands, or sum with \`coalesce\` knowing the result is a floor. The facility code has EIGHT characters and does not join the Ministry's facility files, which use six: these tables join the rest by authority or by name.`,
  Number(e.righe),
);

await catalog(
  "sdo_esito",
  "Come finisce un ricovero, per ospedale (SDO)",
  "How an admission ends, by hospital (SDO)",
  `Come si esce da ogni ospedale italiano: a casa, verso un'altra struttura, o con un decesso. IL RAPPORTO FRA DECESSI E DIMISSIONI NON È LA MORTALITÀ DI UN OSPEDALE e non va calcolato come se lo fosse: un hospice, una lungodegenza e un pronto soccorso di città trattano pazienti incomparabili, e un reparto che accoglie i casi terminali avrà sempre la quota più alta proprio perché fa quel mestiere. Il numero aggiustato per il rischio dei pazienti — l'unico confrontabile fra strutture — sta in \`pne_esiti\`. Quello che questa tabella dice bene è un'altra cosa: la quota dimessa VERSO UN'ALTRA STRUTTURA, che misura quanto un ospedale sia un passaggio invece che una destinazione.`,
  `How people leave each Italian hospital: home, on to another facility, or deceased. THE RATIO OF DEATHS TO DISCHARGES IS NOT A HOSPITAL'S MORTALITY and must not be computed as if it were: a hospice, a long-term care ward and a city A&E treat incomparable patients, and a ward that takes terminal cases will always show the highest share precisely because that is its job. The risk-adjusted figure — the only one comparable across facilities — lives in \`pne_esiti\`. What this table does say well is something else: the share discharged TO ANOTHER FACILITY, which measures how much a hospital is a staging post rather than a destination.`,
  Number(s.righe),
);

await catalog(
  "sdo_traumi",
  "Ricoveri per trauma, per azienda sanitaria (SDO)",
  "Trauma admissions by health authority (SDO)",
  `Quanti ricoveri per trauma ha avuto ogni azienda sanitaria, divisi per le tipologie che le Schede di Dimissione registrano. Si unisce al resto della sanità per \`asl_id\` (codice regione + codice azienda), e da lì al territorio con sanita_asl_comuni. ATTENZIONE alle celle NULL: nella fonte sono \`***\`, il marcatore con cui il Ministero oscura i numeri troppo piccoli per non identificare le persone, e NON sono zeri — sommarle come zeri sottostima e leggerle come «nessun trauma» è falso.`,
  `How many trauma admissions each health authority had, split by the categories the discharge records register. It joins the rest of health through \`asl_id\` (region code + authority code), and from there to territory via sanita_asl_comuni. MIND the NULLs: in the source they are \`***\`, the marker with which the Ministry suppresses numbers too small to publish without identifying people, and they are NOT zeros — summing them as zeros understates, and reading them as "no trauma" is false.`,
  Number(t.righe),
);

console.log(`\nsdo_eta: ${e.righe} · sdo_esito: ${s.righe} · sdo_traumi: ${t.righe}`);
await con.run("CHECKPOINT");
con.closeSync();
