// Rifà le schermate delle schede app del sito guidando l'app VERA in Chrome.
//
//   bun run shots                          # tutte le schede
//   bun run shots orario-scolastico        # una sola
//   bun run shots --publish                # sostituisce quelle in linea
//   bun run shots --url http://localhost:4173
//
// Perché esiste. Le figure di una scheda app sono la prova di quello che la scheda
// dice, e sono anche la cosa che invecchia per prima: l'app guadagna una pagina, un
// pannello cambia nome, e la figura continua a mostrare la versione di sei mesi fa
// mentre la didascalia accanto racconta quella di oggi. Fatte a mano si rifanno
// quando qualcuno se ne ricorda; fatte in un comando si rifanno insieme all'app.
//
// **Sono l'app vera.** Il documento si semina in IndexedDB, i blocchi si eseguono
// davvero, i dati arrivano davvero dal servizio open data. Una schermata truccata è
// la prima cosa che toglie credibilità a tutto il resto della pagina — e su una
// scheda che promette «gira nel tuo browser» sarebbe una bugia sul punto centrale.
//
// **Niente si pubblica finché non lo si guarda.** L'uscita va in `shots-nuovi/`, e
// solo `--publish` sovrascrive quelle in `site/assets/img/app/`. È la regola delle
// clip, imparata sostituendo quattro riprese buone con quattro sbagliate.
//
// **L'inquadratura si dichiara per titolo, non per pixel.** `reveal("I pesi")` porta
// quel titolo in cima; un offset in pixel sarebbe giusto oggi e sbagliato al primo
// paragrafo aggiunto sopra, e nessuno se ne accorgerebbe se non guardando.
//
// Serve: google-chrome e il dev server dell'app (bun run dev). Le due schede di open
// data vogliono anche il servizio dati (bun run od): è dichiarato in `needs`.

import { writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import sharp from "sharp";
import { Cdp, launchChrome, browserSocket, reachable, driver, wait } from "./chrome-driver.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..");
const SHOTS_DIR = join(REPO, "site", "assets", "img", "app");
const STAGE = join(REPO, "shots-nuovi");

const args = process.argv.slice(2);
const urlFlag = args.indexOf("--url");
const BASE = urlFlag === -1 ? "http://localhost:5173" : args[urlFlag + 1];
const publish = args.includes("--publish");
const wanted = args.filter((a, i) => !a.startsWith("--") && !(urlFlag !== -1 && i === urlFlag + 1));

const PORT = 9334;

// La finestra è quella delle schermate già in linea, e la scheda le ridimensiona a
// 1520 e 760: si riprende al doppio della densità e si riduce a questa larghezza,
// così il testo resta nitido anche sulla variante piccola.
const WIDTH = 1568;
const HEIGHT = 765;

const { steps, appIdOf, seed } = driver(BASE, REPO);

// ------------------------------------------------------------- passi in più

// Porta un titolo in cima al riquadro che scorre. Il margine lascia respirare la
// barra appiccicosa sopra, che altrimenti coprirebbe proprio la riga che si voleva
// mostrare.
const reveal = (text, gap = 88) => async (c) => {
  await steps.eval(
    `(() => {
      const wanted = ${JSON.stringify(text.toLowerCase())};
      const heads = [...document.querySelectorAll(".rn-markdown h1, .rn-markdown h2, .rn-markdown h3")]
        .filter(h => h.offsetParent !== null);
      const node = heads.find(h => h.textContent.trim().toLowerCase().startsWith(wanted));
      if (!node) throw new Error("nessun titolo « " + wanted + " » in pagina");
      const box = document.querySelector(".rn-preview");
      const from = box ? box.getBoundingClientRect().top : 0;
      const target = box || document.scrollingElement;
      target.scrollBy(0, node.getBoundingClientRect().top - from - ${gap});
    })()`,
  )(c);
  await wait(800);
};

// E quando la figura È un componente — una griglia, un grafico — è quello che va
// portato in cima, non il titolo che lo annuncia: fra i due c'è il paragrafo che lo
// spiega, ed è testo che nella figura non serve a nessuno. Si nomina per quello che
// il componente dichiara di essere (`data-rn-chart-data="saturazione"`), non per
// posizione, così due grafici nella stessa pagina restano distinguibili.
const revealSel = (selector, gap = 40) => async (c) => {
  await steps.eval(
    `(() => {
      const node = document.querySelector(${JSON.stringify(selector)});
      if (!node) throw new Error("nessun elemento " + ${JSON.stringify(selector)});
      const box = document.querySelector(".rn-preview");
      const from = box ? box.getBoundingClientRect().top : 0;
      const target = box || document.scrollingElement;
      target.scrollBy(0, node.getBoundingClientRect().top - from - ${gap});
    })()`,
  )(c);
  await wait(800);
};

// Scrive in un controllo sorgente come ci scriverebbe una persona: il valore e poi
// l'annuncio, che è l'unica cosa che il negozio reattivo ascolta. Non si passa da
// `reactiveNet.set` perché quello aggiorna il valore e lascia la casella vuota: la
// figura mostrerebbe una tabella filtrata da una ricerca che non c'è.
const setKey = (key, value) => async (c) => {
  await steps.eval(
    `(() => {
      const node = document.querySelector('[data-reactive-source="' + ${JSON.stringify(key)} + '"]');
      if (!node) throw new Error("nessun controllo per la chiave " + ${JSON.stringify(key)});
      node.value = ${JSON.stringify(value)};
      node.dispatchEvent(new Event("input", { bubbles: true }));
    })()`,
  )(c);
  await wait(900);
};

// Un blocco Python è fermo quando non ha più il bottone Stop e non sta più dicendo
// di stare caricando: sono i due segni che il binder mette e toglie da sé, quindi
// non c'è una frase da indovinare nella lingua del documento.
const IDLE =
  `![...document.querySelectorAll("[data-rn-python]")]
     .some(n => n.querySelector(".rn-python-stop") || n.querySelector(".rn-python-pending"))`;

// Avvia i blocchi indicati dalla collezione che scrivono, e aspetta che TUTTI i
// blocchi della pagina siano fermi: l'interprete è uno solo e i blocchi si mettono
// in coda, quindi aspettare quelli avviati uno per uno non direbbe niente di più.
const runBlocks = (targets, timeout = 1800000) => async (c) => {
  await steps.eval(
    `(async () => {
      const wanted = ${JSON.stringify(targets)};
      for (const writes of wanted) {
        const node = [...document.querySelectorAll("[data-rn-python]")]
          .find(n => n.getAttribute("data-rn-python-writes") === writes);
        if (!node) throw new Error("nessun blocco che scrive « " + writes + " »");
        const button = [...node.querySelectorAll("button")].find(b => !/codice|code/i.test(b.textContent));
        if (!button) throw new Error("nessun bottone Esegui su « " + writes + " »");
        button.click();
        await new Promise(r => setTimeout(r, 300));
      }
    })()`,
  )(c);
  await wait(1500);

  // L'attesa si racconta. Un orario si genera in minuti, e un quarto d'ora di
  // silenzio seguito da «condizione mai vera» non dice se stava lavorando o se era
  // fermo: la barra di avanzamento che il blocco disegna da sé è la risposta, e
  // costa una riga ogni quindici secondi leggerla.
  const deadline = Date.now() + timeout;
  let said = "";
  while (Date.now() < deadline) {
    const state = await steps.eval(
      `(() => {
        const blocks = [...document.querySelectorAll("[data-rn-python]")];
        const busy = blocks.filter(n => n.querySelector(".rn-python-stop") || n.querySelector(".rn-python-pending"));
        return {
          fermi: busy.length === 0,
          quanti: busy.length,
          dice: busy.map(n => (n.getAttribute("data-rn-python-writes") || "?") + ": " +
            ((n.querySelector(".rn-python-said") || {}).textContent || "").trim()).join(" | "),
        };
      })()`,
    )(c);
    if (state.fermi) {
      await wait(600);
      return;
    }
    if (state.dice !== said) {
      said = state.dice;
      console.log(`      · ${said}`);
    }
    await wait(15000);
  }
  throw new Error(`blocchi ancora al lavoro dopo ${Math.round(timeout / 60000)} minuti — ${said}`);
};

// Le interrogazioni open data sono ferme quando nessuna sta più dicendo di caricare.
// Il messaggio di attesa finisce con i puntini di sospensione in tutte e sette le
// lingue (`Translations.OdLoading`), e quello che lo sostituisce non ne ha: è il
// solo modo di chiederlo senza cablare qui la frase di una lingua sola.
const OD_SETTLED =
  `[...document.querySelectorAll(".rn-od-status")].every(n => !n.textContent.includes("…"))`;

const odSettled = (timeout = 300000) => async (c) => {
  await wait(1200);
  await steps.until(OD_SETTLED, timeout)(c);
  await wait(1200);
};

// Una mappa e un pivot si costruiscono solo quando la loro pagina ha davvero una
// dimensione: finché la pagina è nascosta il contenitore misura zero e il binder
// rimanda. Quindi si aspetta l'elemento DOPO aver aperto la pagina, mai prima.
const mapReady = (timeout = 120000) => async (c) => {
  await steps.until(`document.querySelector(".leaflet-container .leaflet-overlay-pane path")`, timeout)(c);
  await wait(2500);
};

const exploreReady = (timeout = 180000) => async (c) => {
  await steps.until(`document.querySelector("perspective-viewer")`, timeout)(c);
  await wait(6000);
};

// ---------------------------------------------------------------- le schede

const SCHEDE = {
  "orario-scolastico": {
    doc: "mcp/examples/orario-scolastico.md",
    needs: ["Pyodide, che la prima volta si carica dall'app (13 MB, vendorizzati)"],
    // Le figure mostrano un orario generato, quindi l'orario si genera: le cinque
    // anagrafiche, poi la collocazione, poi il controllo, poi le misure. È la stessa
    // sequenza che segue una persona, ed è lunga perché lo è davvero.
    setup: [
      steps.goto("/"),
      seed("mcp/examples/orario-scolastico.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/orario-scolastico.md")),
      steps.until("document.querySelectorAll('[data-rn-python]').length > 0"),
      steps.wait(1500),
      runBlocks(["classi", "docenti", "aule", "discipline", "cattedre"]),
      steps.page("Controlli e generazione"),
      runBlocks(["lezioni"]),
      runBlocks(["violazioni"]),
      steps.page("Monitor"),
      runBlocks(["fattibilita", "giorni-liberi", "indicatori"]),
      steps.page("Laboratori e qualità"),
      runBlocks(["saturazione", "qualita-docenti"]),
    ],
    shots: {
      griglia: [steps.page("Orario"), revealSel("#grigliaClasse", 30), steps.wait(1200)],
      pesi: [
        steps.page("Controlli e generazione"),
        reveal("La configurazione dell'istituto"),
        steps.wait(800),
      ],
      monitor: [steps.page("Monitor"), reveal("Prima di generare"), steps.wait(1000)],
      saturazione: [
        steps.page("Laboratori e qualità"),
        revealSel('[data-rn-chart-data="saturazione"]'),
        steps.wait(1500),
      ],
      qualita: [
        steps.page("Laboratori e qualità"),
        revealSel('[data-rn-chart-data="qualita-docenti"]'),
        steps.wait(1500),
      ],
    },
  },

  // Le tre schede di segreteria e didattica. Non hanno open data e non hanno mappe:
  // quello che hanno sono le collezioni che i blocchi di avvio seminano, e le figure
  // mostrano quelle. Le collezioni che appartengono a chi usa l'app — le pratiche, i
  // contenuti di un PEI — restano vuote, ed è giusto così: sono i dati di un ufficio,
  // e inventarli per una figura significherebbe mostrare un'app che non è quella che
  // si apre.
  "graduatorie-interne": {
    doc: "mcp/examples/graduatorie-interne.md",
    needs: ["Pyodide, che la prima volta si carica dall'app (13 MB, vendorizzati)"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/graduatorie-interne.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/graduatorie-interne.md")),
      steps.until("document.querySelectorAll('[data-rn-python]').length > 0"),
      steps.wait(1500),
      runBlocks(["personale", "tabella"]),
      runBlocks(["servizi", "dichiarazioni", "archivio", "anomalie"]),
      runBlocks(["prospetto", "graduatoria"]),
    ],
    shots: {
      tabella: [steps.page("Tabella"), revealSel('[data-rn-table="tabella"]'), steps.wait(1200)],
      // Il prospetto individuale sarebbe la figura giusta — è la promessa della
      // scheda — ma sta dentro un `::columns{min="20rem"}` che gli lascia un terzo
      // di larghezza, e una tabella di otto colonne lì dentro si sbriciola. È un
      // problema di quella pagina, non della ripresa: finché resta, la figura
      // mostrerebbe un difetto invece di una funzione.
      personale: [
        steps.page("Personale"),
        revealSel('[data-rn-table="personale"]'),
        steps.wait(1200),
      ],
      graduatoria: [
        steps.page("Graduatoria"),
        revealSel('[data-rn-table="graduatoria"]'),
        steps.wait(1200),
      ],
    },
  },

  inclusione: {
    doc: "mcp/examples/inclusione.md",
    needs: ["Pyodide, che la prima volta si carica dall'app (13 MB, vendorizzati)"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/inclusione.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/inclusione.md")),
      steps.until("document.querySelectorAll('[data-rn-python]').length > 0"),
      steps.wait(1500),
      runBlocks(["alunni", "modelli", "banca"]),
      runBlocks(["somiglianze", "stato-documenti", "riepilogo"]),
    ],
    // Nessuna figura mostra un elenco di alunni. Esiste, e la tabella c'è nell'app —
    // ma una scheda pubblica che apre con i nomi di dodici minori certificati dice la
    // cosa sbagliata su un'app il cui argomento è che quei dati non escono di qui.
    shots: {
      modelli: [steps.page("Modelli"), revealSel('[data-rn-table="modelli"]'), steps.wait(1200)],
      cruscotto: [
        steps.page("Cruscotto"),
        revealSel('[data-rn-chart-data="stato-documenti"]', 150),
        steps.wait(1500),
      ],
      riepilogo: [steps.page("Cruscotto"), revealSel('[data-rn-table="riepilogo"]'), steps.wait(1200)],
    },
  },

  segreteria: {
    doc: "mcp/examples/segreteria.md",
    needs: ["Pyodide, che la prima volta si carica dall'app (13 MB, vendorizzati)"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/segreteria.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/segreteria.md")),
      steps.until("document.querySelectorAll('[data-rn-python]').length > 0"),
      steps.wait(1500),
      runBlocks(["personale", "tipi-pratica", "adempimenti"]),
      runBlocks(["allarmi", "contatori", "tempi"]),
    ],
    // Il cruscotto e il kanban delle pratiche restano fuori: le pratiche sono di chi
    // usa l'app e su un'installazione appena aperta non ce n'è nessuna. Una figura di
    // un kanban vuoto non mostra la scheda, mostra che non è ancora stata usata.
    shots: {
      scadenzario: [
        steps.page("Scadenzario"),
        revealSel('[data-rn-table="adempimenti"]'),
        steps.wait(1200),
      ],
      personale: [steps.page("Personale"), revealSel('[data-rn-table="personale"]'), steps.wait(1200)],
      contatori: [steps.page("Personale"), revealSel('[data-rn-table="contatori"]'), steps.wait(1200)],
    },
  },

  "scuola-in-cifre": {
    doc: "mcp/examples/scuola-in-cifre.md",
    needs: ["il servizio open data: bun run od"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/scuola-in-cifre.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/scuola-in-cifre.md")),
      steps.until("document.querySelector('.rn-od-status')"),
      odSettled(),
    ],
    shots: {
      comune: [
        steps.page("Il mio comune"),
        odSettled(),
        reveal("Il quadro del tuo territorio"),
        steps.wait(1200),
      ],
      dispersione: [
        steps.page("Dispersione"),
        odSettled(),
        reveal("Il confronto tra regioni"),
        steps.wait(1500),
      ],
      invalsi: [
        steps.page("INVALSI"),
        odSettled(),
        reveal("La tua regione, prova per prova"),
        steps.wait(1500),
      ],
      mappa: [
        steps.page("La mappa"),
        odSettled(),
        mapReady(),
        reveal("L'Italia della scuola"),
        steps.wait(1500),
      ],
      esplora: [
        steps.page("Esplora"),
        odSettled(),
        exploreReady(),
        reveal("Il pivot"),
        steps.wait(1500),
      ],
    },
  },

  "soldi-territorio": {
    doc: "mcp/examples/soldi-territorio.md",
    needs: ["il servizio open data: bun run od"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/soldi-territorio.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/soldi-territorio.md")),
      steps.until("document.querySelector('.rn-od-status')"),
      odSettled(),
    ],
    shots: {
      comune: [
        steps.page("Il mio comune"),
        odSettled(),
        reveal("Il quadro del tuo comune"),
        steps.wait(1200),
      ],
      mappa: [
        steps.page("Il mio comune"),
        odSettled(),
        mapReady(),
        reveal("La regione, comune per comune"),
        steps.wait(1500),
      ],
      appalti: [
        steps.page("Appalti"),
        odSettled(),
        reveal("Le gare e chi le vince"),
        steps.wait(1500),
      ],
    },
  },

  "salute-cittadino": {
    doc: "mcp/examples/salute-cittadino.md",
    needs: ["il servizio open data: bun run od"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/salute-cittadino.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/salute-cittadino.md")),
      steps.until("document.querySelector('.rn-od-status')"),
      odSettled(),
    ],
    shots: {
      territorio: [
        steps.page("La mia sanità"),
        odSettled(),
        reveal("L'azienda che ti serve"),
        steps.wait(1200),
      ],
      ricoveri: [
        steps.page("Chi va in ospedale"),
        odSettled(),
        steps.until("document.querySelectorAll('.rn-markdown canvas').length >= 1", 60000),
        steps.wait(2000),
        reveal("Chi finisce ricoverato"),
        steps.wait(1200),
      ],
      esiti: [
        steps.page("Come vanno le cure"),
        odSettled(),
        reveal("L'unica misura di esito"),
        steps.wait(1500),
      ],
      // Le correlazioni girano in Pyodide senza scaricare pacchetti: si aspetta
      // la loro tabella, non un tempo.
      confronti: [
        steps.page("I confronti"),
        odSettled(),
        steps.until("document.body.innerText.includes('Quanto vanno insieme')", 300000),
        steps.wait(2500),
        reveal("Che cosa si muove insieme"),
        steps.wait(1200),
      ],
      // La coropletica delle province: si aspetta che una FORMA sia disegnata,
      // non che sia passato del tempo — un poligono ci mette piu' di un marker.
      italia: [
        steps.page("L'Italia a confronto"),
        odSettled(),
        mapReady(),
        reveal("La mortalità, a parità di età", 60),
        steps.wait(2000),
      ],
    },
  },

  "come-si-vive": {
    doc: "mcp/examples/come-si-vive.md",
    needs: ["il servizio open data: bun run od"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/come-si-vive.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/come-si-vive.md")),
      steps.until("document.querySelector('.rn-od-status')"),
      odSettled(),
    ],
    shots: {
      ritratto: [
        steps.page("Il ritratto"),
        odSettled(),
        reveal("Com'è, questo posto", 88),
        steps.wait(1200),
      ],
      // La previsione gira in Pyodide: si aspetta che la SECONDA tela esista,
      // non che sia passato abbastanza tempo.
      previsione: [
        steps.page("La strada"),
        odSettled(),
        steps.until("document.querySelectorAll('.rn-markdown canvas').length >= 2", 300000),
        steps.wait(2500),
        reveal("E i prossimi anni"),
        steps.wait(1200),
      ],
      salute: [
        steps.page("La salute"),
        odSettled(),
        reveal("Come vanno a finire le cure"),
        steps.wait(1500),
      ],
      confronti: [
        steps.page("I confronti"),
        odSettled(),
        steps.until("document.body.innerText.includes('Quanto vanno insieme')", 300000),
        steps.wait(2500),
        reveal("Che cosa si muove insieme"),
        steps.wait(1200),
      ],
    },
  },

  "mobilita-comune": {
    doc: "mcp/examples/mobilita-comune.md",
    // La pagina in tempo reale interroga un servizio pubblico dal browser: senza
    // rete la mappa resta vuota, e uno scatto di una mappa vuota è esattamente il
    // finto che questi script esistono per non fare.
    needs: ["il servizio open data: bun run od", "una connessione (i mezzi in condivisione arrivano da un servizio pubblico)"],
    setup: [
      steps.goto("/"),
      seed("mcp/examples/mobilita-comune.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/mobilita-comune.md")),
      steps.until("document.querySelector('.rn-od-status')"),
      odSettled(),
    ],
    shots: {
      sicurezza: [
        steps.page("Sicurezza stradale"),
        odSettled(),
        reveal("Come va a finire"),
        steps.wait(1200),
      ],
      // I tre grafici di questa pagina non finiscono insieme: al primo scatto il
      // riquadro di destra era ancora vuoto, con il suo titolo sopra — una figura
      // che dice «questo dato non c'è» di un dato che c'è. Si aspetta che TUTTE le
      // tele siano state disegnate, non che sia passato abbastanza tempo.
      pendolari: [
        steps.page("Chi si muove"),
        odSettled(),
        steps.until("document.querySelectorAll('.rn-markdown canvas').length >= 3", 60000),
        steps.wait(2000),
        reveal("Chi entra, chi esce"),
        steps.wait(1500),
      ],
      // I punti della mappa arrivano da un'API pubblica, non dal magazzino: si
      // aspetta che ne sia disegnato almeno uno, o si fotografa una tela vuota.
      diretta: [
        steps.page("In tempo reale"),
        odSettled(),
        mapReady(),
        revealSel(".leaflet-container", 150),
        steps.wait(1500),
      ],
    },
  },
};

// ------------------------------------------------------------------ lo scatto

const capture = async (cdp, session) => {
  const { data } = await cdp.send(
    "Page.captureScreenshot",
    { format: "png", captureBeyondViewport: false },
    session,
  );
  // Ripresa a densità doppia e ridotta a quella pubblicata: è il modo di avere il
  // testo nitido sulla variante piccola che la scheda serve alla maggior parte dei
  // lettori, senza pubblicare un file grande il quadruplo.
  return sharp(Buffer.from(data, "base64"))
    .resize({ width: WIDTH })
    .jpeg({ quality: 82, chromaSubsampling: "4:4:4" })
    .toBuffer();
};

// ------------------------------------------------------------------- il giro

const main = async () => {
  if (!(await reachable(BASE))) {
    console.error(`L'app non risponde su ${BASE}. Avvia il dev server: bun run dev`);
    process.exit(1);
  }
  const names = wanted.length > 0 ? wanted : Object.keys(SCHEDE);
  for (const name of names) {
    if (!SCHEDE[name]) {
      console.error(`scheda sconosciuta: ${name} (ce ne sono: ${Object.keys(SCHEDE).join(", ")})`);
      process.exit(1);
    }
  }

  const out = publish ? SHOTS_DIR : STAGE;
  mkdirSync(out, { recursive: true });

  // Il profilo NON si cancella fra un giro e l'altro: è dove restano l'interprete
  // Python e la cache delle tessere, e ributtarli via a ogni ripresa renderebbe
  // questo script inutilizzabile proprio per le schede che li usano.
  const profile = join(tmpdir(), "rn-shot-profile");
  mkdirSync(profile, { recursive: true });
  const chrome = launchChrome(profile, PORT, { width: WIDTH, height: HEIGHT });
  let cdp;
  let failures = 0;
  try {
    cdp = await Cdp.open(await browserSocket(PORT));
    for (const name of names) {
      const scheda = SCHEDE[name];
      for (const need of scheda.needs) console.log(`  ${name}: serve ${need}`);
      const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
      const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
      await cdp.send("Page.enable", {}, sessionId);
      await cdp.send("Runtime.enable", {}, sessionId);
      await cdp.send(
        "Emulation.setDeviceMetricsOverride",
        { width: WIDTH, height: HEIGHT, deviceScaleFactor: 2, mobile: false },
        sessionId,
      );
      const context = { send: cdp.send.bind(cdp), session: sessionId };

      try {
        process.stdout.write(`${name}: preparo… `);
        for (const step of scheda.setup) await step(context);
        console.log("pronto");
        for (const [shot, sequence] of Object.entries(scheda.shots)) {
          const file = join(out, `${name}-${shot}.jpg`);
          try {
            for (const step of sequence) await step(context);
            const image = await capture(cdp, sessionId);
            writeFileSync(file, image);
            console.log(`  ${name}-${shot}.jpg — ${(image.length / 1024).toFixed(0)} kB`);
          } catch (error) {
            failures++;
            console.log(`  ${name}-${shot} FALLITA: ${error.message}`);
          }
        }
      } catch (error) {
        failures++;
        console.log(`\n  ${name} FALLITA in preparazione: ${error.message}`);
      }
      await cdp.send("Target.closeTarget", { targetId });
    }
  } finally {
    cdp?.socket.close();
    chrome.kill();
  }
  if (!publish) console.log(`\nScritte in shots-nuovi/ — guardale, poi --publish.`);
  process.exit(failures > 0 ? 1 : 0);
};

await main();
