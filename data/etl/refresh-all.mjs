// Orchestratore ETL: aggiorna il warehouse lanciando gli script sorgente
// in base alla loro CADENZA (registro SOURCES qui sotto), poi la coda
// finale fissa: semantica → embed (solo con Ollama raggiungibile) →
// export-site. Pensato per girare da cron ogni notte: a ogni run parte
// solo ciò che è scaduto rispetto all'ultimo run riuscito (stato in
// ../etl-state.json); una sorgente fallita viene ritentata al run
// successivo qualunque sia la sua cadenza.
//
// Le sorgenti dovute girano con --refresh (senza, la cache in raw/
// servirebbe file vecchi e "aggiornare" non aggiornerebbe niente); le tre
// sorgenti che calcolano embeddings (normattiva, anac, corte-costituzionale)
// ricevono --skip-embed quando Ollama non è raggiungibile, e il fatto resta
// annotato nello stato (i loro embeddings mancanti si recuperano al primo
// run con Ollama attivo, o con `bun run embed`).
//
// DuckDB è single-writer: PRIMA di partire si verifica di poter aprire il
// warehouse in scrittura (un server dati locale anche solo READ_ONLY basta
// a bloccare — fermarlo con `pkill -f "bun.*server.mjs"` e riavviarlo poi).
// La sovrapposizione tra run è demandata a flock nella riga di cron.
//
// Uso:  bun etl/refresh-all.mjs [flag]
//   --list        mostra il registro con cadenze, ultimo run e cosa è dovuto
//   --dry-run     come --list, ma pensato per il log (nessuna esecuzione)
//   --only a,b    limita alle sorgenti elencate (implica che siano dovute)
//   --force       ignora le cadenze: tutte le sorgenti selezionate girano
//   --seed        marca tutte le sorgenti come appena aggiornate (da usare
//                 una tantum quando il warehouse è già fresco, per evitare
//                 un primo run notturno che riscarica tutto)
//   --deploy      a run pulito lancia ../deploy.sh --data-only
//
// Cron consigliato (ogni notte alle 4, log accodato):
//   0 4 * * * cd <repo>/data && flock -n /tmp/reactive-etl.lock bun etl/refresh-all.mjs >> etl.log 2>&1

import { spawn, spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const ETL = ROOT + "etl/";
const DB = ROOT + "warehouse.duckdb";
const STATE_FILE = ROOT + "etl-state.json";
const OLLAMA = process.env.OLLAMA_URL ?? "http://localhost:11434";
const EMBED_MODEL = process.env.EMBED_MODEL ?? "qwen3-embedding:0.6b";
const TIMEOUT_MS = 90 * 60_000; // per singolo script; i dump grossi (anac, camera) restano sotto

const PERIODS = { daily: 1, weekly: 7, monthly: 30, quarterly: 90 }; // giorni

// Registro delle sorgenti: name = base del file in etl/ (e dello script
// npm etl:<name>). La cadenza riflette la pubblicazione della fonte, non
// un desiderio: le fonti annuali (ISTAT, MEF, INVALSI, ISPRA) si
// ricontrollano ogni trimestre perché le nuove edizioni escono in momenti
// diversi dell'anno. `ollama: true` = lo script accetta --skip-embed.
const SOURCES = [
  { name: "carburanti", every: "daily" }, // prezzi MIMIT, aggiornati ogni giorno
  { name: "normattiva", every: "weekly", ollama: true },
  { name: "camera", every: "weekly" },
  { name: "senato", every: "weekly" },
  { name: "giustizia-amministrativa", every: "weekly" },
  { name: "corte-costituzionale", every: "weekly", ollama: true },
  { name: "indicepa", every: "weekly" },
  { name: "anac", every: "monthly", ollama: true },
  { name: "anac-aggiudicatari", every: "monthly" },
  { name: "opencoesione", every: "monthly", ollama: true }, // pubblicazione bimestrale, si ricontrolla ogni mese
  { name: "opencup", every: "monthly" }, // pubblicazione osservata a inizio mese
  // DOPO opencup, sempre: il dataset di ReGiS non dice dove stanno i progetti, e il
  // comune si prende da lì per CUP. Invertirli darebbe una tabella senza territorio.
  { name: "pnrr", every: "monthly" },
  { name: "inail-infortuni", every: "monthly" },
  { name: "siope", every: "monthly" }, // cumulati di cassa: un mese nuovo ogni mese
  // 350 MB di zip al mese: l'ANNCSU si aggiorna mensilmente e non ha senso
  // ricontrollarlo più spesso, né meno.
  { name: "anncsu", every: "monthly" },
  { name: "farmacie", every: "monthly" },
  { name: "schema", every: "monthly" }, // vocabolari NDC
  { name: "istat-confini", every: "quarterly" },
  // basi territoriali: cambiano solo col censimento, ma le variabili censuarie
  // escono un'annata alla volta (2021, poi 2023) → si ricontrolla col resto ISTAT
  { name: "istat-sezioni", every: "quarterly" },
  { name: "istat-popolazione", every: "quarterly" },
  { name: "istat-indicatori", every: "quarterly" },
  { name: "mef-redditi", every: "quarterly" },
  { name: "scuole", every: "quarterly" },
  { name: "rifiuti", every: "quarterly" },
  { name: "consumo-suolo", every: "quarterly" }, // il rapporto ISPRA esce una volta l'anno, in autunno
  // La classificazione la fanno le regioni, con decreti sparsi: il DPC ripubblica
  // quando ne arriva uno, quindi non c'è una stagione da attendere.
  { name: "zone-sismiche", every: "quarterly" },
  { name: "elezioni", every: "quarterly" }, // statico fino a nuove elezioni
  { name: "imprese", every: "quarterly" },
  { name: "invalsi", every: "quarterly" },
  { name: "delitti", every: "quarterly" }, // ISTAT: rate limit aggressivo, mai infittire
  { name: "turismo", every: "quarterly" }, // idem
  { name: "turismo-capacita", every: "quarterly" }, // stesso endpoint, stesso rate limit
  // Idem. L'annata più recente esce provvisoria e senza gli zeri: ricontrollarla
  // ogni trimestre serve anche a raccoglierla quando ISTAT la consolida.
  { name: "incidenti-stradali", every: "quarterly" },
  // Il catalogo dei sistemi di sharing cambia quando un operatore entra o esce da
  // una città: mensile perché la verifica di ogni feed è anche il modo in cui ci
  // si accorge che uno ha smesso di rispondere.
  { name: "gbfs-sistemi", every: "monthly" },
  // Il Ministero ripubblica i file cambiando il segmento con anno e mese nell'URL:
  // l'ETL li rilegge dalla pagina del dataset, quindi un trimestre basta.
  { name: "sanita-strutture", every: "quarterly" },
  // Il PNE pubblica un'edizione l'anno e la tiene "in corso" per mesi: si
  // ricontrolla ogni trimestre. Sono 175 richieste da un secondo, non un dump.
  { name: "pne-esiti", every: "quarterly" },
  // Conto Annuale e apparecchiature: il primo esce una volta l'anno con due anni
  // di ritardo, il secondo si ripubblica di continuo con la data nel nome del file.
  { name: "sanita-personale", every: "quarterly" },
  // Non scarica niente: rilegge i file di siope, quindi va DOPO quello e alla sua
  // stessa cadenza, o resterebbe indietro di un mese sui dati che ha già in casa.
  { name: "sanita-spesa", every: "monthly" },
  { name: "sanita-territorio", every: "quarterly" },
  { name: "sdo-dimissioni", every: "quarterly" },
  { name: "sanita-servizi", every: "quarterly" },
  { name: "sanita-anagrafiche", every: "quarterly" },
  // ISTAT, rate limit severo: due richieste per dataset (sonda + dati) con due
  // minuti di pausa in mezzo. Trimestrale come gli altri SDMX di questo repo.
  { name: "istat-salute", every: "quarterly" },
  { name: "aci-veicoli", every: "quarterly" }, // annuale, data di rilascio non fissa
  { name: "giustizia-durata", every: "quarterly" },
  { name: "dispersione", every: "quarterly" }, // il Focus MIM è biennale, URL statici
  { name: "iscrizioni", every: "quarterly" },
  { name: "edilizia-scolastica", every: "quarterly" },
  { name: "personale-scuola", every: "quarterly" },
  { name: "beni-culturali", every: "quarterly" }, // ArCo cresce per aggiunte, non per edizioni
  // Rilevazione triennale pubblicata con due anni di ritardo: si ricontrolla ogni
  // trimestre solo per accorgersi dell'annata nuova, e DOPO anncsu, da cui prende
  // il crosswalk catastale→ISTAT senza il quale il comune del bene resta illeggibile.
  { name: "patrimonio-pa", every: "quarterly" },
  // Censimento 2011: statico. Si ricontrolla ogni trimestre solo per accorgersi
  // del giorno in cui ISTAT collegherà davvero la matrice 2021.
  { name: "pendolarismo", every: "quarterly" },
  { name: "invalsi-regionale", every: "quarterly" },
];

const args = process.argv.slice(2);
const flag = f => args.includes(f);
const only = (() => {
  const i = args.indexOf("--only");
  if (i === -1) return null;
  const names = (args[i + 1] ?? "").split(",").filter(Boolean);
  const bad = names.filter(n => !SOURCES.some(s => s.name === n));
  if (bad.length || !names.length) {
    console.error(`--only: sorgenti sconosciute o mancanti: ${bad.join(", ") || "(vuoto)"}`);
    process.exit(2);
  }
  return names;
})();

const log = msg => console.log(`[${new Date().toISOString().slice(0, 19)}] ${msg}`);

function loadState() {
  if (!existsSync(STATE_FILE)) return { sources: {} };
  try { return JSON.parse(readFileSync(STATE_FILE, "utf8")); }
  catch { return { sources: {} }; }
}
const state = loadState();
const saveState = () => writeFileSync(STATE_FILE, JSON.stringify(state, null, 1) + "\n");

// dovuta se: mai girata, ultimo run fallito, o cadenza scaduta (fattore
// 0.9: un job daily lanciato da cron alla stessa ora risulterebbe
// altrimenti "non ancora scaduto" per pochi minuti di jitter)
function isDue(src) {
  const st = state.sources[src.name];
  if (!st?.last) return true;
  if (!st.ok) return true;
  return Date.now() - Date.parse(st.last) >= PERIODS[src.every] * 86_400_000 * 0.9;
}

if (flag("--seed")) {
  const now = new Date().toISOString();
  for (const s of SOURCES) state.sources[s.name] = { last: now, ok: true, note: "seed" };
  saveState();
  log(`stato inizializzato: ${SOURCES.length} sorgenti marcate come aggiornate ora`);
  process.exit(0);
}

const selected = SOURCES.filter(s => !only || only.includes(s.name));
const due = selected.filter(s => flag("--force") || (only ? true : isDue(s)));

if (flag("--list") || flag("--dry-run")) {
  for (const s of SOURCES) {
    const st = state.sources[s.name];
    const last = st?.last ? st.last.slice(0, 10) + (st.ok ? "" : " FALLITA") : "mai";
    const mark = due.includes(s) ? "→ DOVUTA" : "";
    console.log(`${s.name.padEnd(26)} ${s.every.padEnd(10)} ultimo: ${last.padEnd(18)} ${mark}`);
  }
  process.exit(0);
}

if (!due.length) {
  log("niente di dovuto, esco");
  process.exit(0);
}

// guardia sul lock: prova ad aprire il DB in scrittura da un processo
// figlio (l'uscita del processo garantisce il rilascio del lock — un open
// in-process qui bloccherebbe a sua volta gli script figli)
function assertWritable() {
  const probe =
    `try{const{DuckDBInstance}=await import("@duckdb/node-api");` +
    `await DuckDBInstance.create(${JSON.stringify(DB)});process.exit(0)}` +
    `catch(e){console.error(e.message);process.exit(1)}`;
  const r = spawnSync("bun", ["-e", probe], { cwd: ROOT, encoding: "utf8", timeout: 60_000 });
  if (r.status !== 0) {
    log(`warehouse NON apribile in scrittura — c'è un server dati attivo su questo file?`);
    log(`  (${(r.stderr ?? "").trim().split("\n")[0]})`);
    log(`  ferma il server locale (pkill -f "bun.*server.mjs") e rilancia.`);
    process.exit(1);
  }
}
assertWritable();

async function ollamaUp() {
  try {
    const res = await fetch(`${OLLAMA}/api/tags`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return false;
    const models = (await res.json()).models ?? [];
    return models.some(m => (m.name ?? "").startsWith(EMBED_MODEL.split(":")[0]));
  } catch { return false; }
}
const embeddable = await ollamaUp();
log(`Ollama ${embeddable ? `raggiungibile con ${EMBED_MODEL}` : "assente/senza modello: gli embeddings saranno saltati"}`);

function runScript(file, extra, label) {
  const t0 = Date.now();
  return new Promise(resolve => {
    log(`▶ ${label} ${extra.join(" ")}`);
    const child = spawn("bun", [ETL + file, ...extra], { stdio: "inherit" });
    const killer = setTimeout(() => {
      log(`⏱ ${label}: timeout ${TIMEOUT_MS / 60000} min, termino`);
      child.kill("SIGTERM");
      setTimeout(() => child.kill("SIGKILL"), 30_000).unref();
    }, TIMEOUT_MS);
    const done = (ok, code) => { clearTimeout(killer); resolve({ ok, code, ms: Date.now() - t0 }); };
    child.on("exit", code => done(code === 0, code));
    child.on("error", () => done(false, -1));
  });
}

const results = [];
for (const src of due) {
  const extra = ["--refresh"];
  const skippedEmbed = src.ollama && !embeddable;
  if (skippedEmbed) extra.push("--skip-embed");
  const r = await runScript(src.name + ".mjs", extra, src.name);
  state.sources[src.name] = {
    last: new Date().toISOString(),
    ok: r.ok,
    ms: r.ms,
    ...(skippedEmbed && r.ok ? { note: "embeddings saltati (Ollama assente)" } : {}),
  };
  saveState(); // dopo OGNI sorgente: un crash non perde il progresso
  results.push({ name: src.name, ...r, skippedEmbed });
}

// coda finale: ha senso solo se almeno una sorgente è andata a buon fine
const finale = [];
if (results.some(r => r.ok)) {
  finale.push({ name: "semantica", ...(await runScript("semantica.mjs", [], "semantica")) });
  if (embeddable) finale.push({ name: "embed", ...(await runScript("embed.mjs", [], "embed")) });
  else log("▷ embed saltato (Ollama assente)");
  finale.push({ name: "export-site", ...(await runScript("export-site.mjs", [], "export-site")) });
}

const fmt = r =>
  `  ${r.ok ? "✓" : "✗"} ${r.name.padEnd(26)} ${(r.ms / 1000).toFixed(0)}s` +
  (r.skippedEmbed ? "  (embeddings saltati)" : "") + (r.ok ? "" : `  exit ${r.code}`);
log("— riepilogo —");
for (const r of [...results, ...finale]) console.log(fmt(r));

const failed = [...results, ...finale].filter(r => !r.ok);
if (failed.length) {
  log(`${failed.length} passi falliti: ${failed.map(r => r.name).join(", ")} — ritenteranno al prossimo run`);
  process.exit(1);
}

if (flag("--deploy")) {
  const r = await new Promise(resolve => {
    log("▶ deploy --data-only");
    const child = spawn(ROOT + "../deploy.sh", ["--data-only"], { stdio: "inherit", cwd: ROOT + ".." });
    child.on("exit", code => resolve(code === 0));
    child.on("error", () => resolve(false));
  });
  if (!r) { log("deploy fallito"); process.exit(1); }
}

log("tutto aggiornato");
