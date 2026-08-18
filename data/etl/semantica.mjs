// Layer SEMANTICO del warehouse → tre tabelle di metadati in DuckDB + righe
// nel `catalog`. Formalizza ciò che finora viveva implicito in tre posti
// (euristiche JS dell'esploratore, compactRef dell'assistente, descrizioni del
// catalog): quali CHIAVI concettuali agganciano le tabelle, quali RELAZIONI
// esistono davvero, e che concetto porta ogni colonna.
//
//   catalog_keys       le chiavi concettuali (codice ISTAT, CF, CIG, …) con
//                      l'URI OntoPiA dove esiste — l'ancora ontologica
//   catalog_relations  le relazioni tabella→tabella (from/to, chiave,
//                      cardinalità) con la COPERTURA MISURATA sul dato reale:
//                      ogni relazione dichiarata viene VERIFICATA con il join
//                      e la percentuale finisce nella riga stessa — la
//                      documentazione si autoverifica a ogni run
//   catalog_columns    ogni colonna di ogni tabella del catalog, col concetto
//                      chiave quando la colonna ne porta uno
//
// Le tre tabelle sono interrogabili via od-query come tutto il resto: il
// warehouse descrive sé stesso (l'esploratore del sito ci costruisce il grafo
// delle relazioni, e l'assistente può rispondere "come si uniscono X e Y?"
// con una SELECT).
//
// URI ONTOLOGICI: si usano solo quelli certi di OntoPiA (CLV per i luoghi,
// COV per il codice fiscale). Dove non esiste un concetto standard (CIG,
// id impianto) l'URI resta NULL con la sola descrizione: meglio onesti che
// inventati.
//
// Uso:  bun etl/semantica.mjs

import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const DB = ROOT + "warehouse.duckdb";
const esc = s => String(s).replaceAll("'", "''");
const lit = s => (s == null ? "NULL" : `'${esc(s)}'`);

// --- le CHIAVI concettuali -------------------------------------------------------
const CHIAVI = [
  {
    id: "istat",
    label_it: "Codice ISTAT del comune",
    label_en: "ISTAT municipality code",
    uri: "https://w3id.org/italia/onto/CLV/City",
    descr: "Codice a 6 cifre del comune (zero-padded); la spina dorsale geografica del warehouse.",
  },
  {
    id: "istituto_sdo",
    label_it: "Codice istituto (SDO)",
    label_en: "Facility code (hospital discharge records)",
    uri: null,
    descr:
      "Codice a otto caratteri dell'istituto di ricovero usato dalle Schede di Dimissione Ospedaliera e dal PNE. NON e' il codice a sei caratteri dei file delle strutture del Ministero: sono due numerazioni diverse e unirle produrrebbe righe accostate a caso.",
  },
  {
    id: "area_sdmx",
    label_it: "Codice territoriale SDMX",
    label_en: "SDMX territorial code",
    uri: null,
    descr:
      "Il codice della codelist ISTAT CL_ITTER107 usato dai flussi SDMX: ITC = ripartizione, ITC1 = regione, ITC11 = provincia. NON e' il codice ISTAT a sei cifre del comune e non gli somiglia: la tabella istat_aree e' l'unico ponte fra questi codici e i confini del warehouse.",
  },
  {
    id: "asl",
    label_it: "Azienda sanitaria",
    label_en: "Health authority",
    uri: null,
    descr:
      "Identificativo dell'azienda sanitaria come codice REGIONE + codice AZIENDA (per esempio 030-321). Il codice azienda da solo NON basta: si ripete fra regioni — il 201 esiste in dieci — e unire su quello fonde aziende diverse, facendone risultare 52 invece di 110.",
  },
  {
    id: "struttura_sanitaria",
    label_it: "Codice della struttura sanitaria",
    label_en: "Health facility code",
    uri: null,
    descr:
      "Codice ministeriale della struttura di ricovero (sei cifre: le prime tre sono la regione). Unisce le tabelle che descrivono lo stesso ospedale da lati diversi \u2014 i posti letto per disciplina e l'attivit\u00e0 dell'anno.",
  },
  {
    id: "sezione",
    label_it: "Sezione di censimento",
    label_en: "Census section",
    uri: null,
    descr:
      "Identificativo ISTAT della sezione di censimento (SEZ21_ID): l'unica grana SUB-comunale del warehouse, qualche isolato in città e una frazione altrove. È quello che fa incontrare la geometria (istat_sezioni) con le variabili censuarie (istat_censimento_sezioni). ATTENZIONE: è a lunghezza variabile — 11 caratteri dove il codice comune ne ha 4, 12 dove ne ha 5 — quindi non va mai riempito a lunghezza fissa.",
  },
  {
    id: "cf",
    label_it: "Codice fiscale",
    label_en: "Tax code",
    uri: "https://w3id.org/italia/onto/COV/taxCode",
    descr: "Codice fiscale dell'ente o dell'impresa; aggancia gare, PA e aggiudicatari.",
  },
  {
    id: "cig",
    label_it: "CIG (gara)",
    label_en: "CIG (tender)",
    uri: null,
    descr: "Codice Identificativo di Gara (ANAC): una gara/lotto di appalto pubblico.",
  },
  {
    id: "sigla",
    label_it: "Sigla provincia",
    label_en: "Province code",
    uri: "https://w3id.org/italia/onto/CLV/Province",
    descr: "Sigla automobilistica della provincia/UTS.",
  },
  {
    id: "reg",
    label_it: "Codice regione",
    label_en: "Region code",
    uri: "https://w3id.org/italia/onto/CLV/Region",
    descr: "Codice ISTAT della regione a 2 cifre (zero-padded).",
  },
  {
    id: "impianto",
    label_it: "id impianto",
    label_en: "station id",
    uri: null,
    descr: "Identificativo MIMIT dell'impianto di distribuzione carburanti.",
  },
  {
    id: "regione_nome",
    label_it: "Nome regione",
    label_en: "Region name",
    uri: "https://w3id.org/italia/onto/CLV/Region",
    descr: "Nome della regione in chiaro (non il codice ISTAT a 2 cifre): usato dove la fonte non porta un codice regione.",
  },
  {
    id: "atto_camera",
    label_it: "id atto Camera",
    label_en: "Chamber bill id",
    uri: null,
    descr: "Identificativo opaco (ontologia OCD) di un atto/progetto di legge alla Camera dei Deputati.",
  },
  {
    id: "cod_progetto",
    label_it: "Codice locale progetto",
    label_en: "Project local code",
    uri: null,
    descr: "Codice Locale Progetto (OpenCoesione): un progetto finanziato con fondi di coesione.",
  },
  {
    id: "cup",
    label_it: "CUP (progetto)",
    label_en: "CUP (project)",
    uri: null,
    descr: "Codice Unico di Progetto (DIPE): stringa alfanumerica di 15 caratteri, identifica in modo univoco un progetto d'investimento pubblico dal 2003 in poi — aggancia OpenCUP e OpenCoesione.",
  },
];

// mappa nome-colonna (minuscolo) → chiave concettuale, per catalog_columns
const COL2CHIAVE = {
  codice_istat: "istat", luogo_istat: "istat", codice_comune: "istat",
  cf: "cf", cf_amministrazione_appaltante: "cf", cf_aggiudicatario: "cf",
  cig: "cig",
  id_impianto: "impianto",
  sigla: "sigla", sigla_automobilistica: "sigla", sigla_provincia: "sigla",
  cod_reg: "reg", codice_regione: "reg",
  regione: "regione_nome",
  rif_atto: "atto_camera",
  cod_progetto: "cod_progetto",
  cup: "cup",
  cf_beneficiario: "cf", cf_soggetto_titolare: "cf",
  // La destinazione di un flusso è un codice ISTAT quanto l'origine: senza
  // questa riga metà del pendolarismo non porterebbe nessun concetto.
  codice_istat_destinazione: "istat",
  cf_amministrazione: "cf", cf_soggetto_attuatore: "cf",
  sez_id: "sezione",
  codice_struttura: "struttura_sanitaria",
  asl_id: "asl",
  ref_area: "area_sdmx",
  codice_istituto: "istituto_sdo",
};

// --- le RELAZIONI (dichiarate; la copertura viene misurata sotto) ---------------
const R = (from, to, chiave, label_it, label_en, card = "N:1") => {
  const [ft, fc] = from.split(".");
  const [tt, tc] = to.split(".");
  return { ft, fc, tt, tc, chiave, label_it, label_en, card };
};
const RELAZIONI = [
  R("anac_cig.luogo_istat", "istat_confini_comuni.codice_istat", "istat", "comune di esecuzione", "place of performance"),
  R("anac_cig.cf_amministrazione_appaltante", "indicepa.cf", "cf", "amministrazione appaltante", "contracting authority"),
  R("anac_aggiudicatari.cig", "anac_cig.cig", "cig", "gara aggiudicata", "awarded tender"),
  R("carb_prezzi.id_impianto", "carb_impianti.id_impianto", "impianto", "impianto del prezzo", "priced station"),
  R("carb_impianti.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'impianto", "station municipality"),
  R("indicepa.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'ente", "authority municipality"),
  R("siope_spese.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della spesa", "spending municipality"),
  R("siope_entrate.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'entrata", "revenue municipality"),
  R("istat_popolazione.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune", "municipality"),
  R("mef_redditi.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dei redditi", "income municipality"),
  R("farmacie.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della farmacia", "pharmacy municipality"),
  R("scuole.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della scuola", "school municipality"),
  R("istat_indicatori.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune", "municipality"),
  R("inail_infortuni.sigla", "istat_confini_province.sigla", "sigla", "provincia dell'infortunio", "injury province"),
  R("rifiuti.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dei rifiuti", "waste municipality"),
  R("elezioni.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune elettorale", "election municipality"),
  R("imprese.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune delle imprese", "business municipality"),
  R("invalsi.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della scuola INVALSI", "INVALSI school municipality"),
  R("delitti.sigla", "istat_confini_province.sigla", "sigla", "provincia dei delitti", "crime province"),
  R("turismo.sigla", "istat_confini_province.sigla", "sigla", "provincia del turismo", "tourism province"),
  R("istat_confini_comuni.codice_istat", "voc_istat_cities.CODICE_COMUNE", "istat", "voce di vocabolario", "vocabulary entry"),
  R("istat_confini_comuni.sigla", "istat_confini_province.sigla", "sigla", "provincia del comune", "municipality province"),
  R("istat_confini_comuni.cod_reg", "istat_confini_regioni.cod_reg", "reg", "regione del comune", "municipality region"),
  R("istat_confini_province.cod_reg", "istat_confini_regioni.cod_reg", "reg", "regione della provincia", "province region"),
  R("giustizia_amministrativa.regione", "istat_confini_regioni.regione", "regione_nome", "regione della sede giudicante", "judging seat region"),
  R("camera_votazioni.rif_atto", "camera_atti.id", "atto_camera", "atto votato", "voted bill"),
  R("opencoesione.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del progetto", "project municipality"),
  R("aci_veicoli.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del parco veicolare", "vehicle fleet municipality"),
  R("aci_veicoli_alimentazione.sigla", "istat_confini_province.sigla", "sigla", "provincia del parco veicolare", "vehicle fleet province"),
  R("giustizia_durata.regione", "istat_confini_regioni.regione", "regione_nome", "regione della sede giudicante", "judging seat region"),
  R("dispersione_scolastica.regione", "istat_confini_regioni.regione", "regione_nome", "regione della dispersione scolastica", "school drop-out region"),
  R("iscrizioni_scolastiche.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune delle iscrizioni", "enrollment municipality"),
  R("edilizia_scolastica.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'edificio scolastico", "school building municipality"),
  R("personale_scuola.sigla", "istat_confini_province.sigla", "sigla", "provincia del personale scolastico", "school staff province"),
  R("invalsi_regionale.regione", "istat_confini_regioni.regione", "regione_nome", "regione INVALSI campionaria", "INVALSI sample region"),
  R("opencup.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del progetto CUP", "CUP project municipality"),
  R("opencoesione.cup", "opencup.cup", "cup", "progetto anche in OpenCUP", "project also in OpenCUP", "1:1"),

  // --- mobilità -----------------------------------------------------------
  R("incidenti_stradali.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'incidente", "accident municipality"),
  R("aci_veicoli_euro.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del parco per classe Euro", "Euro-class fleet municipality"),
  R("gbfs_sistemi.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del sistema di sharing", "shared-mobility system municipality"),

  // --- sanità ---------------------------------------------------------------
  R("sanita_asl_comuni.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune servito dall'ASL", "municipality served by the health authority", "1:1"),
  R("sanita_posti_letto.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della struttura ospedaliera", "hospital facility municipality"),
  R("sanita_strutture.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'ospedale o della casa di cura", "hospital or clinic municipality"),
  // Le due tabelle delle strutture descrivono gli stessi ospedali da due lati —
  // i letti per disciplina e l'attivita' dell'anno — e il codice struttura le unisce.
  R("sanita_strutture.codice_struttura", "sanita_posti_letto.codice_struttura", "struttura_sanitaria", "letti della stessa struttura", "beds of the same facility"),
  // Il PNE numera le strutture in modo suo (otto caratteri contro sei): le due
  // sanita' si incontrano per COMUNE, non per codice, e dichiararlo per codice
  // sarebbe dichiarare un legame che non c'e'.
  R("pne_esiti.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della struttura misurata", "municipality of the measured facility"),
  // Il personale e le apparecchiature stanno per AZIENDA: la loro chiave e'
  // asl_id, non il comune, ed e' la corrispondenza ASL a portarli sul territorio.
  R("sanita_personale.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del personale", "authority of the staff"),
  R("sanita_apparecchiature.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda delle apparecchiature", "authority of the equipment"),
  R("sanita_apparecchiature.codice_struttura", "sanita_posti_letto.codice_struttura", "struttura_sanitaria", "letti della stessa struttura", "beds of the same facility"),
  // SIOPE non porta il codice dell'azienda, solo il nome: l'unico aggancio onesto
  // e' il comune della SEDE. Dichiararlo su asl_id sarebbe dichiarare un legame
  // che i dati non hanno.
  R("sanita_spesa.codice_istat_sede", "istat_confini_comuni.codice_istat", "istat", "comune della sede dell'azienda", "municipality where the authority is seated"),
  R("consultori.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del consultorio", "clinic municipality"),
  R("consultori.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del consultorio", "authority of the clinic"),
  R("salute_mentale.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio di salute mentale", "authority of the mental health service"),
  R("dipendenze.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio per le dipendenze", "authority of the addiction service"),
  // Le SDO numerano gli istituti a otto caratteri come il PNE: NON si agganciano
  // alle strutture del Ministero, che ne usano sei. L'unico legame dichiarabile e'
  // quello dei traumi, che stanno per azienda.
  R("sdo_traumi.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda dei ricoveri per trauma", "authority of trauma admissions"),
  R("sdo_esito.codice_istituto", "sdo_eta.codice_istituto", "istituto_sdo", "lo stesso ospedale per eta", "the same hospital by age"),

  // I servizi territoriali stanno tutti per AZIENDA: e' asl_id a portarli sul
  // territorio, attraverso la corrispondenza con i comuni.
  R("dsm_prestazioni.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_personale.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_convenzionate.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_semiresidenziali.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_residenziali.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_primo_eta.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_primo_diagnosi.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("dsm_prevalenza.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("serd_personale.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("serd_trattamento.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("letti_stabilimento.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del servizio", "authority of the service"),
  R("letti_stabilimento.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dello stabilimento", "municipality of the hospital site"),
  R("reparti.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del reparto", "ward municipality"),
  R("reparti.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del reparto", "authority of the ward"),
  R("parafarmacie.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della parafarmacia", "municipality of the outlet"),
  R("personale_flessibile.asl_id", "sanita_asl_comuni.asl_id", "asl", "azienda del personale a termine", "authority of the flexible staff"),

  // I dati ISTAT usano i codici territoriali SDMX (ITC11), che non somigliano a
  // niente altro nel warehouse: `istat_aree` e' l'unico ponte verso i confini.
  R("istat_mortalita_causa.ref_area", "istat_aree.codice", "area_sdmx", "area territoriale", "territorial area"),
  R("istat_speranza_vita.ref_area", "istat_aree.codice", "area_sdmx", "area territoriale", "territorial area"),
  R("istat_mortalita_infantile.ref_area", "istat_aree.codice", "area_sdmx", "area territoriale", "territorial area"),
  // Le due estremità di un flusso: la SECONDA è quella che rende la tabella un
  // grafo invece di un elenco, e va dichiarata o l'esploratore disegna solo
  // metà dei legami — l'origine senza la destinazione.
  R("pendolarismo.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune di origine dello spostamento", "commute origin municipality"),
  R("pendolarismo.codice_istat_destinazione", "istat_confini_comuni.codice_istat", "istat", "comune di destinazione dello spostamento", "commute destination municipality"),
  R("pendolarismo_mezzo.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune di origine, per mezzo usato", "commute origin, by mode"),
  R("pendolarismo_mezzo.codice_istat_destinazione", "istat_confini_comuni.codice_istat", "istat", "comune di destinazione, per mezzo usato", "commute destination, by mode"),

  // --- territorio e indirizzi ---------------------------------------------
  R("anncsu_strade.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della strada", "street municipality"),
  R("anncsu_civici.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del numero civico", "house number municipality"),
  R("comuni_codici.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del codice catastale", "cadastral code municipality", "1:1"),
  R("istat_sezioni.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della sezione di censimento", "census section municipality"),
  // La sezione, non il comune: è l'unico aggancio a grana sub-comunale del
  // warehouse, ed è quello che fa incontrare la geometria con le variabili.
  R("istat_censimento_sezioni.sez_id", "istat_sezioni.sez_id", "sezione", "geometria della sezione censita", "geometry of the censused section", "1:1"),
  R("consumo_suolo.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del consumo di suolo", "land consumption municipality"),
  R("consumo_suolo_serie.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della serie di consumo", "land consumption series municipality"),
  R("zone_sismiche.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della zona sismica", "seismic zone municipality", "1:1"),

  // --- spesa pubblica e patrimonio ----------------------------------------
  R("pnrr_progetti.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del progetto PNRR", "PNRR project municipality"),
  // Il PNRR non porta un luogo: il comune arriva da qui, ed è il motivo per cui
  // pnrr gira DOPO opencup nell'orchestratore.
  R("pnrr_progetti.cup", "opencup.cup", "cup", "progetto anche in OpenCUP, da cui viene il comune", "project also in OpenCUP, source of its municipality"),
  R("patrimonio_pa.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune dell'immobile pubblico", "public property municipality"),
  R("patrimonio_pa.cf_amministrazione", "indicepa.cf", "cf", "amministrazione dichiarante", "declaring authority"),
  R("beni_culturali.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune del bene culturale", "cultural heritage municipality"),
  R("turismo_capacita.codice_istat", "istat_confini_comuni.codice_istat", "istat", "comune della capacità ricettiva", "accommodation capacity municipality"),
];

console.log("▸ layer semantico del warehouse (chiavi, relazioni, colonne)");

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: vss per il CHECKPOINT (indici HNSW su lex_atti/anac_cig).
await con.run("INSTALL vss");
await con.run("LOAD vss");

// --- catalog_keys ----------------------------------------------------------------
await con.run(`CREATE OR REPLACE TABLE catalog_keys (
  chiave VARCHAR PRIMARY KEY, label_it VARCHAR, label_en VARCHAR, uri VARCHAR, descr VARCHAR)`);
for (const k of CHIAVI) {
  await con.run(`INSERT INTO catalog_keys VALUES (${lit(k.id)}, ${lit(k.label_it)}, ${lit(k.label_en)}, ${lit(k.uri)}, ${lit(k.descr)})`);
}

// --- catalog_relations, con COPERTURA misurata sul dato --------------------------
await con.run(`CREATE OR REPLACE TABLE catalog_relations (
  from_table VARCHAR, from_column VARCHAR, to_table VARCHAR, to_column VARCHAR,
  chiave VARCHAR, cardinalita VARCHAR, label_it VARCHAR, label_en VARCHAR,
  copertura_pct DOUBLE)`);

console.log("  misuro la copertura di ogni relazione…");
for (const r of RELAZIONI) {
  // % dei valori NON NULL di from_column che trovano un aggancio in to_column
  let pct = null;
  try {
    const q = await con.runAndReadAll(`
      SELECT round(100.0 * count(t.v) / nullif(count(*), 0), 1) AS pct
      FROM (SELECT "${r.fc}" AS v FROM ${r.ft} WHERE "${r.fc}" IS NOT NULL) f
      LEFT JOIN (SELECT DISTINCT "${r.tc}" AS v FROM ${r.tt}) t ON t.v = f.v`);
    pct = q.getRowObjects()[0].pct;
  } catch (e) {
    console.warn(`  ⚠ ${r.ft}.${r.fc} → ${r.tt}.${r.tc}: ${e.message ?? e}`);
  }
  await con.run(`INSERT INTO catalog_relations VALUES (
    ${lit(r.ft)}, ${lit(r.fc)}, ${lit(r.tt)}, ${lit(r.tc)},
    ${lit(r.chiave)}, ${lit(r.card)}, ${lit(r.label_it)}, ${lit(r.label_en)},
    ${pct == null ? "NULL" : Number(pct)})`);
  const flag = pct == null ? "?" : pct < 80 ? "⚠" : "✓";
  console.log(`  ${flag} ${r.ft}.${r.fc} → ${r.tt}.${r.tc}  ${pct ?? "n/d"}%`);
}

// --- catalog_columns (generata dal catalog, arricchita con le chiavi) -----------
const rows = (
  await con.runAndReadAll(`SELECT table_name, columns FROM catalog WHERE table_name NOT LIKE 'catalog%' ORDER BY table_name`)
).getRowObjects();
await con.run(`CREATE OR REPLACE TABLE catalog_columns (
  table_name VARCHAR, column_name VARCHAR, data_type VARCHAR, chiave VARCHAR)`);
const values = [];
for (const t of rows) {
  let cols = [];
  try { cols = JSON.parse(t.columns ?? "[]"); } catch { /* columns malformato: tabella senza colonne note */ }
  for (const c of cols) {
    const chiave = COL2CHIAVE[String(c.name).toLowerCase()] ?? null;
    values.push(`(${lit(t.table_name)}, ${lit(c.name)}, ${lit(c.type)}, ${lit(chiave)})`);
  }
}
for (let i = 0; i < values.length; i += 500) {
  await con.run(`INSERT INTO catalog_columns VALUES ${values.slice(i, i + 500).join(",")}`);
}

const stat = (
  await con.runAndReadAll(`SELECT
    (SELECT count(*) FROM catalog_keys) AS chiavi,
    (SELECT count(*) FROM catalog_relations) AS relazioni,
    (SELECT count(*) FROM catalog_columns) AS colonne,
    (SELECT count(*) FROM catalog_columns WHERE chiave IS NOT NULL) AS col_chiave`)
).getRowObjects()[0];
console.log(
  `  catalog_keys: ${stat.chiavi} chiavi · catalog_relations: ${stat.relazioni} relazioni · ` +
    `catalog_columns: ${stat.colonne} colonne (${stat.col_chiave} con concetto chiave)`,
);

// --- righe di catalogo (il layer si descrive nel catalog come tutto il resto) ---
async function registra(tbl, titleIt, titleEn, descIt, descEn, n) {
  const cols = (
    await con.runAndReadAll(
      `SELECT column_name, data_type FROM information_schema.columns
       WHERE table_name = '${tbl}' ORDER BY ordinal_position`,
    )
  ).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));
  await con.run(`DELETE FROM catalog WHERE table_name = '${tbl}'`);
  await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
    VALUES ('${tbl}', 'reactivenet.ai', 'reactive/semantica',
      '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
      'https://reactivenet.ai/dati/', now(), ${Number(n)}, '${esc(JSON.stringify(cols))}')`);
}

await registra(
  "catalog_keys",
  "Chiavi concettuali del warehouse",
  "Warehouse key concepts",
  "Le chiavi concettuali che agganciano le tabelle del warehouse (codice ISTAT del comune, codice fiscale, CIG, sigla provincia, codice regione, id impianto), con l'URI dell'ontologia OntoPiA dove esiste. È l'ancora semantica del warehouse: catalog_relations e catalog_columns vi fanno riferimento.",
  "The key concepts that link the warehouse tables (ISTAT municipality code, tax code, CIG, province code, region code, station id), with the OntoPiA ontology URI where one exists. The semantic anchor of the warehouse: catalog_relations and catalog_columns reference it.",
  stat.chiavi,
);
await registra(
  "catalog_relations",
  "Relazioni tra le tabelle del warehouse",
  "Warehouse table relationships",
  "Le relazioni formali tra le tabelle del warehouse: colonna di partenza, colonna di arrivo, chiave concettuale, cardinalità e — misurata a ogni run dell'ETL — la percentuale di copertura reale del join. Rispondere a «come si uniscono X e Y?» è una SELECT su questa tabella.",
  "The formal relationships between warehouse tables: source column, target column, key concept, cardinality and — measured at every ETL run — the real join coverage percentage. Answering \"how do X and Y join?\" is a SELECT on this table.",
  stat.relazioni,
);
await registra(
  "catalog_columns",
  "Colonne delle tabelle del warehouse",
  "Warehouse table columns",
  "Ogni colonna di ogni tabella del catalogo, con il tipo e — quando la colonna porta una chiave concettuale (codice ISTAT, CF, CIG, …) — il riferimento a catalog_keys. Generata automaticamente dal catalog.",
  "Every column of every catalogued table, with its type and — when the column carries a key concept (ISTAT code, tax code, CIG, …) — the reference to catalog_keys. Generated automatically from the catalog.",
  stat.colonne,
);

console.log(`\nlayer semantico: ${stat.chiavi} chiavi, ${stat.relazioni} relazioni, ${stat.colonne} colonne`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
