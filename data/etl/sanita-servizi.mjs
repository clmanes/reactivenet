// Ingestione dei SERVIZI TERRITORIALI del SSN — salute mentale, dipendenze e
// posti letto per disciplina (Ministero della Salute, Open Data IODL 2.0) → undici
// tabelle in DuckDB + righe nel `catalog`.
//
// **È un ETL solo con un REGISTRO, non undici ETL.** Le famiglie condividono la
// stessa forma — anno, regione, azienda, servizio, una dimensione, una misura —
// e scriverle una per una significherebbe undici copie della stessa lettura, che
// divergono al primo file che cambia. Qui la differenza fra una famiglia e
// l'altra è una voce di `FAMIGLIE`: quali dataset, quale tabella, quali colonne.
//
// Quello che copre, e che nel warehouse non c'era:
//   dsm_prestazioni       prestazioni erogate dai Dipartimenti di Salute Mentale
//   dsm_personale         chi ci lavora, per qualifica
//   dsm_convenzionate     personale delle strutture convenzionate
//   dsm_semiresidenziali  accessi e utenti dei centri diurni
//   dsm_residenziali      ammessi e dimessi dalle strutture residenziali
//   dsm_primo_eta         chi arriva per la prima volta, per età e sesso
//   dsm_primo_diagnosi    chi arriva per la prima volta, per gruppo diagnostico
//   dsm_prevalenza        utenti trattati per gruppo diagnostico
//   serd_personale        chi lavora nei servizi per le dipendenze
//   serd_trattamento      utenti per tipo di trattamento
//   letti_regione         posti letto per regione e disciplina
//   letti_stabilimento    posti letto per stabilimento e disciplina
//
// TRAPPOLE:
//  - **le intestazioni cambiano fra annate della stessa famiglia**, e non di poco:
//    «Codice Asl» diventa «CODICE AZIENDA», «DESCRIZIONE REGIONE» diventa
//    «DENOMINAZIONE REGIONE», e in una c'è pure «DECRIZIONE REGIONE» con il refuso.
//    Su ventidue famiglie ci sono quarantasei tracciati distinti. Le colonne di
//    OGNI file si leggono con `DESCRIBE` e si mappano su un nome canonico
//    ignorando spazi, accenti e maiuscole, con le alternative dichiarate: fidarsi
//    di come sono scritte significa perdere metà delle annate in silenzio;
//  - **dal 2021 diversi file mettono una riga di TITOLO sopra l'intestazione**, o
//    una riga di soli punti e virgola. Letta come intestazione produce colonne
//    senza nome e zero righe utili, senza un errore: il personale dei SerD
//    risultava fermo al 2020 con quattro annate scaricate e buttate. Si cerca la
//    prima riga che contiene una chiave attesa e si salta il resto;
//  - **sedici dataset del portale non hanno alcun file scaricabile** — tutta la
//    spesa per dispositivi medici dal 2013 al 2021, l'elenco nazionale dei
//    direttori, il personale universitario. La pagina esiste, il link no. Sono
//    elencati in `SENZA_FILE` perché la ricerca non venga rifatta;
//  - il **codice azienda è unico solo dentro la regione**, come in tutta la sanità
//    di questo warehouse: la chiave è `asl_id` = codice regione + codice azienda;
//  - i file sono in **ISO-8859-1** e i campi sono riempiti di spazi;
//  - le celle vuote **non sono zeri**: dove il Ministero oscura un numero troppo
//    piccolo restano NULL, e sommarle come zeri sottostima.
//
// Uso:  bun etl/sanita-servizi.mjs [--refresh]

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/sanita-servizi/";
const DB = ROOT + "warehouse.duckdb";
const PORTALE = "https://www.dati.salute.gov.it";

// Dataset che il portale elenca e per cui NON pubblica alcun file: annotati qui
// perché nessuno rifaccia la ricerca credendo di averli dimenticati.
const SENZA_FILE = [
  "dispositivi-medici e la spesa per azienda dal 2013 al 2021 (dieci annate)",
  "elenco-nazionale-direttori",
  "medicinali-spesa-regionale-fascia-di-rimborsabilita",
  "personale-universitario-delle-asl (quattro annate)",
  "utenti-ammessi-strutture-residenziali-anno-2021",
  "atti-di-concessione",
];

// Il registro. `col` mappa un nome canonico sulle alternative viste nei file.
const anni = (base, da, a) =>
  Array.from({ length: a - da + 1 }, (_, i) => base.replace("{A}", da + i));

const CORE = {
  anno: ["Anno", "ANNO", "ANNO DI RIFERIMENTO"],
  codice_regione: ["Codice Regione", "CODICE REGIONE"],
  regione: ["Descrizione Regione", "DESCRIZIONE REGIONE", "DENOMINAZIONE REGIONE", "DECRIZIONE REGIONE", "Regione"],
  codice_asl: ["Codice Asl", "CODICE ASL", "Codice Azienda", "CODICE AZIENDA"],
  asl: ["Asl", "ASL", "Denominazione Azienda", "DENOMINAZIONE AZIENDA", "DENOMINAZIONE_AZIENDA"],
};

const FAMIGLIE = [
  {
    tabella: "dsm_prestazioni",
    dataset: anni("distribuzione-delle-prestazioni-territoriali-erogate-sede-di-intervento-{A}", 2020, 2024),
    col: { ...CORE, dsm: ["DSM"], sede: ["Sede Intervento", "SEDE INTERVENTO"] },
    misure: { prestazioni: ["Numero di prestazioni erogate - DSM", "NUMERO DI PRESTAZIONI EROGATE - DSM"] },
    titolo: ["Prestazioni dei servizi di salute mentale", "Mental health service activity"],
  },
  {
    tabella: "dsm_personale",
    dataset: anni("personale-dei-dsm-{A}", 2019, 2023),
    col: { ...CORE, qualifica: ["DESCRIZIONE QUALIFICA", "Descrizione Qualifica"] },
    misure: { dipendenti: ["NUM. DIP. TEMPO PIENO", "NUMERO DIPENDENTI", "NUM. DIP. TEMPO PIENO TOT"] },
    titolo: ["Personale dei Dipartimenti di Salute Mentale", "Mental health department staff"],
  },
  {
    tabella: "dsm_convenzionate",
    dataset: anni("personale-delle-strutture-convenzionate-con-dsm-{A}", 2019, 2023),
    col: { ...CORE, qualifica: ["DESCRIZIONE QUALIFICA", "Descrizione Qualifica"] },
    misure: { dipendenti: ["NUMERO DIPENDENTI", "NUM. DIP. TEMPO PIENO"] },
    titolo: ["Personale delle strutture convenzionate con i DSM", "Staff of contracted mental health facilities"],
  },
  {
    tabella: "dsm_semiresidenziali",
    dataset: anni("accessi-semiresidenziali-erogati-{A}", 2020, 2024),
    col: { ...CORE, dsm: ["DSM"] },
    misure: {
      accessi: ["NUMERO DI ACCESSI SEMIRESIDENZIALE DSM", "Numero di accessi semiresidenziale DSM"],
      utenti: ["NUMERO DI UTENTI SEMIRESIDENZIALE DSM", "Numero di utenti semiresidenziale DSM"],
    },
    titolo: ["Centri diurni di salute mentale", "Mental health day centres"],
  },
  {
    tabella: "dsm_residenziali",
    dataset: [
      ...anni("utenti-ammessi-strutture-residenziali-anno-{A}", 2020, 2024),
      ...anni("utenti-dimessi-da-strutture-residenziali-anno-{A}", 2020, 2024),
    ],
    col: { ...CORE, dsm: ["DSM"], intensita: ["INTENSITÁ ASSISTENZIALE", "INTENSITA ASSISTENZIALE", "Intensità assistenziale"] },
    misure: {
      ammessi: ["NUMERO UTENTI AMMESSI DSM", "Numero utenti ammessi DSM"],
      dimessi: ["NUMERO UTENTI DIMESSI DSM", "Numero utenti dimessi DSM"],
    },
    titolo: ["Strutture residenziali di salute mentale", "Residential mental health facilities"],
  },
  {
    tabella: "dsm_primo_eta",
    dataset: anni("utenti-al-primo-contatto-con-i-servizi-di-salute-mentale-sesso-e-classi-di-eta-anno-{A}", 2022, 2024),
    col: { ...CORE, dsm: ["DSM"], classe_eta: ["CLASSE D'ETÀ", "Classe d'età"], sesso: ["SESSO", "Sesso"] },
    misure: { nuovi_utenti: ["NUOVI UTENTI NELL'ANNO", "Nuovi utenti nell'anno"] },
    titolo: ["Primo contatto con la salute mentale, per età", "First contact with mental health services, by age"],
  },
  {
    tabella: "dsm_primo_diagnosi",
    dataset: [
      ...anni("utenti-al-primo-contatto-con-i-servizi-di-salute-mentale-gruppo-diagnostico-anno-{A}", 2020, 2021),
      "utenti-al-primo-contatto-con-i-servizi-di-salute-mentale-sesso-e-gruppo-diagnostico-anno",
      "utenti-al-primo-contatto-con-i-servizi-di-salute-mentale-sesso-e-gruppo-diagnostico-anno-0",
      "utenti-al-primo-contatto-con-i-servizi-di-salute-mentale-sesso-e-gruppo-diagnostico-anno-1",
    ],
    col: { ...CORE, dsm: ["DSM"], gruppo: ["Gruppo Diagnostico", "GRUPPO DIAGNOSTICO"], sesso: ["Sesso", "SESSO"] },
    misure: { nuovi_utenti: ["Nuovi utenti nell'anno", "NUOVI UTENTI NELL'ANNO"] },
    titolo: ["Primo contatto con la salute mentale, per diagnosi", "First contact with mental health services, by diagnosis"],
  },
  {
    tabella: "dsm_prevalenza",
    dataset: [
      ...anni("prevalenza-degli-utenti-trattati-gruppo-diagnostico-{A}", 2020, 2021),
      ...anni("prevalenza-degli-utenti-trattati-nei-dsm-sesso-e-gruppo-diagnostico-{A}", 2022, 2024),
    ],
    col: { ...CORE, dsm: ["DSM"], gruppo: ["Gruppo Diagnostico", "GRUPPO DIAGNOSTICO"], sesso: ["Sesso", "SESSO"] },
    misure: { accessi: ["NUMERO ACCESSI", "Numero Accessi", "Numero accessi"] },
    titolo: ["Utenti trattati dai DSM, per diagnosi", "Mental health users treated, by diagnosis"],
  },
  {
    tabella: "serd_personale",
    dataset: anni("personale-dei-serd-anno-{A}", 2019, 2024),
    col: { ...CORE, qualifica: ["DESCRIZIONE QUALIFICA", "Descrizione Qualifica"] },
    misure: { dipendenti: ["NUM. DIP. TEMPO PIENO", "NUMERO DIPENDENTI", "NUM. DIP."] },
    titolo: ["Personale dei servizi per le dipendenze", "Addiction service staff"],
  },
  {
    tabella: "serd_trattamento",
    dataset: anni("utenti-carico-secondo-il-tipo-di-trattamento-anno-{A}", 2020, 2025),
    col: { ...CORE, servizio: ["SERD", "SerD"] },
    misure: {
      nuovi: ["Nuovi Utenti", "NUOVI UTENTI"],
      gia_in_carico: ["Utenti rientrati o già in carico", "UTENTI RIENTRATI O GIÀ IN CARICO"],
      totale: ["Totale", "TOTALE"],
    },
    titolo: ["Utenti dei SerD per tipo di trattamento", "Addiction service users by treatment"],
  },
  {
    tabella: "letti_regione",
    dataset: [...anni("posti-letto-regione-e-disciplina-{A}", 2020, 2023), "posti-letto-regione-e-disciplina-dal-2010-al-2019"],
    col: {
      anno: CORE.anno, codice_regione: CORE.codice_regione, regione: CORE.regione,
      disciplina: ["Descrizione disciplina", "DESCRIZIONE DISCIPLINA"],
      tipo_disciplina: ["Tipo di Disciplina", "TIPO DI DISCIPLINA"],
    },
    misure: {
      reparti: ["N° Reparti", "N. Reparti"],
      letti_ordinari: ["Posti letto degenza ordinaria", "POSTI LETTO DEGENZA ORDINARIA"],
      letti_day_hospital: ["Posti letto Day Hospital", "POSTI LETTO DAY HOSPITAL"],
    },
    titolo: ["Posti letto per regione e disciplina", "Beds by region and discipline"],
  },
  {
    tabella: "letti_stabilimento",
    dataset: [...anni("posti-letto-stabilimento-ospedaliero-e-disciplina-{A}", 2020, 2023), "posti-letto-stabilimento-ospedaliero-e-disciplina-dal-2010-al-2019"],
    col: {
      anno: CORE.anno, codice_regione: CORE.codice_regione, regione: CORE.regione,
      codice_asl: CORE.codice_asl,
      codice_struttura: ["Codice struttura", "CODICE STRUTTURA"],
      struttura: ["Denominazione Struttura/Stabilimento", "Denominazione struttura"],
      codice_istat: ["Codice Comune", "CODICE COMUNE"],
      disciplina: ["Descrizione disciplina", "Descrizione Disciplina"],
    },
    misure: {
      letti_ordinari: ["Posti letto degenza ordinaria", "POSTI LETTO DEGENZA ORDINARIA"],
      letti_day_hospital: ["Posti letto Day Hospital", "POSTI LETTO DAY HOSPITAL"],
    },
    titolo: ["Posti letto per stabilimento e disciplina", "Beds by hospital site and discipline"],
  },
];

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");
const norm = s =>
  String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]/g, "");

mkdirSync(RAW, { recursive: true });
console.log("▸ servizi territoriali del SSN: salute mentale, dipendenze, posti letto");

async function urlDelCsv(dataset) {
  const res = await fetch(`${PORTALE}/it/dataset/${dataset}/`, { signal: AbortSignal.timeout(90_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const html = await res.text();
  const m = html.match(/href="([^"]*\.csv)"/i);
  if (!m) throw new Error("nessun CSV nella pagina");
  return m[1].startsWith("http") ? m[1] : PORTALE + decodeURI(m[1]);
}

async function prendi(dataset) {
  const dest = RAW + dataset + ".csv";
  if (!refresh && (await Bun.file(dest).exists())) return dest;
  const url = await urlDelCsv(dataset);
  const res = await fetch(url, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const grezzo = dest + ".latin1";
  await Bun.write(grezzo, await res.arrayBuffer());
  const conv = Bun.spawnSync(["iconv", "-f", "ISO-8859-1", "-t", "UTF-8", grezzo]);
  if (conv.exitCode !== 0) throw new Error("iconv fallito");
  await Bun.write(dest, conv.stdout);
  return dest;
}

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
await con.run("INSTALL vss");
await con.run("LOAD vss");

const leggi = f =>
  `read_csv('${esc(f)}', delim = ';', header = true, all_varchar = true, ignore_errors = true)`;
const numero = c => `TRY_CAST(replace(trim(${c}), '.', '') AS BIGINT)`;
const q = async sql => (await con.runAndReadAll(sql)).getRowObjects()[0];

// Quante righe saltare prima dell'intestazione. Dal 2021 diversi file mettono
// sopra il titolo della rilevazione — o una riga di soli punti e virgola — e
// leggendo la prima riga come intestazione si ottiene una tabella di colonne
// senza nome e ZERO righe utili, senza un errore. La riga giusta e' la prima che
// contiene una delle chiavi che ci aspettiamo.
const saltoDi = async (file, attese) => {
  const testa = (await Bun.file(file).text()).slice(0, 8000).split(/\r?\n/).slice(0, 12);
  const chiavi = attese.map(norm);
  const i = testa.findIndex(riga => riga.split(";").some(c => chiavi.includes(norm(c))));
  return i > 0 ? i : 0;
};

const leggiCon = (f, salto) =>
  `read_csv('${esc(f)}', delim = ';', header = true, all_varchar = true,
            ignore_errors = true${salto ? `, skip = ${salto}` : ""})`;

const colonneDi = async (file, salto) =>
  (await con.runAndReadAll(`DESCRIBE SELECT * FROM ${leggiCon(file, salto)}`))
    .getRowObjects()
    .map(r => r.column_name);

// Trova la colonna il cui nome, ignorati spazi, accenti e maiuscole, e' una delle
// alternative dichiarate. Torna null se non c'e': una misura che manca in
// un'annata e' NULL per quelle righe, non un errore che ferma tutto.
const come = (colonne, alternative) => {
  const chiavi = alternative.map(norm);
  const trovata = colonne.find(c => chiavi.includes(norm(c)));
  return trovata ? `"${trovata}"` : null;
};

const esiti = [];
for (const fam of FAMIGLIE) {
  const pezzi = [];
  const mancanti = [];
  for (const d of fam.dataset) {
    let file;
    try {
      file = await prendi(d);
    } catch (e) {
      mancanti.push(`${d} (${String(e.message ?? e).slice(0, 40)})`);
      continue;
    }
    const salto = await saltoDi(file, fam.col.codice_regione ?? CORE.codice_regione);
    const c = await colonneDi(file, salto);
    const dim = Object.entries(fam.col).map(([nome, alt]) => {
      const col = come(c, alt);
      return col ? `trim(${col}) AS ${nome}` : `CAST(NULL AS VARCHAR) AS ${nome}`;
    });
    const mis = Object.entries(fam.misure).map(([nome, alt]) => {
      const col = come(c, alt);
      return col ? `${numero(col)} AS ${nome}` : `CAST(NULL AS BIGINT) AS ${nome}`;
    });
    const chiaveRegione = come(c, fam.col.codice_regione ?? CORE.codice_regione);
    const chiaveAsl = come(c, fam.col.codice_asl ?? CORE.codice_asl);
    const aslId =
      chiaveRegione && chiaveAsl
        ? `trim(${chiaveRegione}) || '-' || trim(${chiaveAsl}) AS asl_id`
        : `CAST(NULL AS VARCHAR) AS asl_id`;
    if (!chiaveRegione) {
      mancanti.push(`${d} (nessuna colonna regione: intestazione non trovata)`);
      continue;
    }
    pezzi.push(`SELECT ${aslId}, ${[...dim, ...mis].join(", ")} FROM ${leggiCon(file, salto)}
      WHERE trim(${chiaveRegione}) IS NOT NULL`);
  }
  if (!pezzi.length) {
    console.log(`  ⚠ ${fam.tabella}: nessun file utilizzabile`);
    continue;
  }
  await con.run(`CREATE OR REPLACE TABLE ${fam.tabella} AS
    SELECT * FROM (${pezzi.join(" UNION ALL BY NAME ")})
    WHERE TRY_CAST(anno AS INTEGER) IS NOT NULL`);
  const st = await q(`SELECT count(*) righe, count(DISTINCT asl_id) aziende,
    min(TRY_CAST(anno AS INTEGER)) dal, max(TRY_CAST(anno AS INTEGER)) al FROM ${fam.tabella}`);
  esiti.push({ ...fam, ...st, file: pezzi.length, mancanti });
  console.log(
    `  ${fam.tabella.padEnd(22)} ${String(st.righe).padStart(7)} righe · ${st.aziende} aziende · ` +
      `${st.dal}-${st.al} · ${pezzi.length} file` +
      (mancanti.length ? ` · ${mancanti.length} senza file` : ""),
  );
}

console.log(`\n  ${SENZA_FILE.length} gruppi di dataset del portale non hanno alcun file da scaricare:`);
for (const s of SENZA_FILE) console.log(`    ✗ ${s}`);

async function catalog(fam, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${fam.tabella}' AND column_name != 'embedding' ORDER BY ordinal_position`,
    )
  )
    .getRowObjects()
    .map(c => ({ name: c.column_name, type: c.data_type }));
  const misure = Object.keys(fam.misure).join(", ");
  const descIt = `${fam.titolo[0]}, dal Ministero della Salute. Una riga per azienda, anno e dimensione; le misure sono: ${misure}. Il livello è l'AZIENDA sanitaria e non il comune, perché è a quel livello che questi servizi sono organizzati: si porta sul territorio unendo \`asl_id\` a sanita_asl_comuni. ATTENZIONE alle celle vuote — dove il Ministero oscura un numero troppo piccolo per non identificare le persone il valore è NULL, e sommarlo come zero sottostima. Le intestazioni di questa famiglia cambiano fra un'annata e l'altra (maiuscole, spazi, sinonimi e almeno un refuso): l'ETL le legge da ogni file e le mappa su questi nomi, quindi una colonna assente in un'annata è NULL per quelle righe e non un buco nella tabella.`;
  const descEn = `${fam.titolo[1]}, from the Ministry of Health. One row per authority, year and dimension; the measures are: ${misure}. The level is the health AUTHORITY rather than the municipality, because that is how these services are organised: join \`asl_id\` to sanita_asl_comuni to reach the territory. MIND the empty cells — where the Ministry suppresses a number too small to publish without identifying people the value is NULL, and summing it as zero understates. This family's headers change from one vintage to the next (case, spacing, synonyms and at least one typo): the ETL reads them from each file and maps them onto these names, so a column absent in one vintage is NULL for those rows and not a hole in the table.`;
  await con.run(`DELETE FROM catalog WHERE table_name = '${fam.tabella}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${fam.tabella}', 'dati.salute.gov.it', 'salute/servizi-territoriali',
      '${esc(fam.titolo[0])}', '${esc(fam.titolo[1])}',
      '${esc(descIt)}', '${esc(descEn)}',
      'https://www.dati.salute.gov.it/', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

for (const fam of esiti) await catalog(fam, fam.righe);

console.log(`\n${esiti.length} tabelle, ${esiti.reduce((a, f) => a + Number(f.righe), 0)} righe in tutto`);
await con.run("CHECKPOINT");
con.closeSync();
