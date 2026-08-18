// Registra le clip del sito guidando l'app VERA in Chrome.
//
//   bun scripts/record-clips.mjs               # tutte quelle che si possono fare
//   bun scripts/record-clips.mjs editor        # una sola
//   bun scripts/record-clips.mjs --url http://localhost:4173   # su una build
//
// Perché esiste, e perché è fatto così.
//
// Le clip della home mostrano il prodotto, non un mockup: è scritto nel commento di
// `site/layouts/home.html` e va difeso, perché una finta ripresa è la prima cosa che
// toglie credibilità a tutto il resto della pagina. Finora erano registrate a mano,
// e questo significava che a ogni cambiamento dell'app o restavano vecchie o non si
// rifacevano. Questo script le rifà in un comando.
//
// **Nessuna dipendenza npm.** Chrome si pilota via CDP su WebSocket — bun ha già il
// client — e i fotogrammi li assembla ffmpeg. Aggiungere puppeteer per fare questo
// significherebbe portarsi dietro un Chromium intero per una cosa che il Chrome già
// installato sa fare da sé.
//
// Le app si seminano scrivendo il documento direttamente in IndexedDB, sotto la
// chiave che `DocumentKey` produce: è la stessa cosa che fa l'import di un file,
// senza dover pilotare la galleria. Le collezioni si lasciano vuote — una clip che
// parte da un'app appena arrivata è anche la prova che l'app parte.
//
// Serve: google-chrome, ffmpeg, e il dev server dell'app in ascolto (bun run dev).
// La clip `soldi` vuole anche il servizio open data (bun run od), la clip `orario`
// scarica Pyodide alla prima esecuzione: sono dichiarate in `needs` e lo script lo
// dice invece di produrre un video di una schermata di errore.

import { readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { Cdp, launchChrome, browserSocket, reachable, driver } from "./chrome-driver.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..");
const CLIPS_DIR = join(REPO, "site", "static", "clip");

const args = process.argv.slice(2);
const urlFlag = args.indexOf("--url");
const BASE = urlFlag === -1 ? "http://localhost:5173" : args[urlFlag + 1];
const publish = args.includes("--publish");
const wanted = args.filter((a, i) => !a.startsWith("--") && !(urlFlag !== -1 && i === urlFlag + 1));

// Le clip nuove NON sovrascrivono quelle in linea finché non lo si chiede. Una
// ripresa sbagliata è la cosa più facile da produrre con questo script — un
// selettore cambiato, un servizio spento — e sostituire una clip buona con una
// pagina vuota è un errore che si vede solo in produzione. Si guarda quello che è
// uscito, e poi si pubblica con --publish.
// Fuori da site/static/, che Hugo copia com'è: una clip di prova finita là dentro
// verrebbe pubblicata insieme al sito senza che nessuno l'abbia scelta.
const STAGE = join(REPO, "clip-nuove");

const PORT = 9333;

const { steps, appIdOf, seed, fillForm } = driver(BASE, REPO);

// ------------------------------------------------------------------ le clip

const CLIPS = {
  // Scrivere e vedere: il documento a sinistra, l'app a destra.
  editor: {
    seconds: 18,
    needs: [],
    steps: [
      steps.goto("/"),
      seed("scripts/clip-docs/spesa.md"),
      steps.goto("/a/" + appIdOf("scripts/clip-docs/spesa.md") + "/edit"),
      steps.until("document.querySelector('.cm-content')"),
      steps.wait(1500),
      // Prima due righe dal modulo, perché il totale che compare dopo deve avere
      // qualcosa da sommare: è la promessa della clip, non un dettaglio.
      fillForm({ cosa: "Pane", prezzo: "3.50" }),
      steps.wait(700),
      steps.click("[data-rn-add]"),
      steps.wait(1100),
      fillForm({ cosa: "Latte", prezzo: "1.20" }),
      steps.wait(700),
      steps.click("[data-rn-add]"),
      steps.wait(1600),
      // Poi la riga che fa comparire il totale, battuta davvero.
      steps.click(".cm-content"),
      steps.eval(
        `(() => { const view = document.querySelector(".cm-content");
          const range = document.createRange(); range.selectNodeContents(view);
          range.collapse(false); const sel = getSelection();
          sel.removeAllRanges(); sel.addRange(range); })()`,
      ),
      steps.type("\nTotale: :sum{path=\"voci\" field=\"prezzo\" decimals=\"2\"} euro.\n", 50),
      steps.wait(3000),
    ],
  },

  // Il solver: cattedre e vincoli da una parte, l'orario dall'altra.
  orario: {
    seconds: 24,
    needs: ["Pyodide: la PRIMA ripresa lo scarica (13 MB), le successive no"],
    steps: [
      steps.goto("/"),
      seed("mcp/examples/orario-scolastico.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/orario-scolastico.md")),
      steps.until("document.querySelectorAll('[data-rn-python] button').length > 0"),
      steps.wait(1500),
      // I cinque blocchi di semina, in ordine: le cattedre citano gli id degli altri.
      steps.eval(
        `(async () => { const run = () => [...document.querySelectorAll("[data-rn-python]")]
            .map(n => [...n.querySelectorAll("button")].find(b => !/codice|code/i.test(b.textContent)))
            .filter(Boolean);
          const buttons = run().slice(0, 5);
          for (const b of buttons) { b.click(); await new Promise(r => setTimeout(r, 300)); } })()`,
      ),
      // Il quinto blocco è quello delle cattedre: quando ha stampato, le cinque
      // anagrafiche ci sono tutte. La frase è quella che il documento scrive.
      steps.until("document.body.innerText.includes('ore disciplinari da collocare')", 420000),
      steps.wait(1500),
      steps.page("Controlli"),
      steps.wait(1500),
      steps.scroll(null, 900),
      steps.wait(1200),
      // Genera: è il momento che la clip esiste per mostrare.
      steps.eval(
        `(() => { const blocks = [...document.querySelectorAll("[data-rn-python]")];
          const target = blocks.find(n => n.getAttribute("data-rn-python-writes") === "lezioni");
          const button = [...(target || blocks[0]).querySelectorAll("button")]
            .find(b => !/codice|code/i.test(b.textContent));
          if (!button) throw new Error("nessun pulsante Esegui"); button.click(); })()`,
      ),
      steps.until("document.body.innerText.includes('Ore collocate')", 420000),
      steps.wait(2000),
      steps.page("Orario"),
      steps.until("document.querySelector('.rn-timetable-card')", 60000),
      steps.wait(1500),
      steps.scroll(".rn-preview", 700),
      steps.wait(3000),
      steps.scroll(".rn-preview", 1100),
      steps.wait(3000),
    ],
  },

  // Gli open data al lavoro: si sceglie un comune e il cruscotto si riempie.
  soldi: {
    seconds: 20,
    needs: ["il servizio open data in ascolto: bun run od"],
    steps: [
      steps.goto("/"),
      seed("mcp/examples/soldi-territorio.md"),
      steps.goto("/a/" + appIdOf("mcp/examples/soldi-territorio.md")),
      steps.until("document.querySelector('.rn-od-status')"),
      // Il cruscotto si riempie da solo: la clip aspetta che ci sia davvero
      // qualcosa da vedere, invece di riprendere una pagina di spinner.
      steps.until("document.querySelectorAll('canvas').length > 0", 120000),
      steps.wait(3500),
      steps.scroll(null, 600),
      steps.wait(3500),
      steps.scroll(null, 1300),
      steps.wait(3500),
    ],
  },

};

// ------------------------------------------------------------- registrazione

const record = async (cdp, session, name, clip) => {
  // Tutte le clip stanno dentro una scheda del sito, quindi una misura sola.
  const size = { width: 1280, height: 720 };
  await cdp.send(
    "Emulation.setDeviceMetricsOverride",
    { width: size.width, height: size.height, deviceScaleFactor: 1, mobile: false },
    session,
  );
  const frames = [];
  const off = cdp.on((message) => {
    if (message.method !== "Page.screencastFrame" || message.sessionId !== session) return;
    frames.push({ data: message.params.data, at: message.params.metadata.timestamp });
    cdp.send("Page.screencastFrameAck", { sessionId: message.params.sessionId }, session);
  });

  await cdp.send(
    "Page.startScreencast",
    { format: "jpeg", quality: 82, maxWidth: size.width, maxHeight: size.height, everyNthFrame: 1 },
    session,
  );

  const context = { send: cdp.send.bind(cdp), session };
  for (const step of clip.steps) await step(context);

  await cdp.send("Page.stopScreencast", {}, session);
  off();
  return frames;
};

const encode = (name, frames, clip) => {
  if (frames.length < 2) throw new Error("nessun fotogramma raccolto");
  const work = join(tmpdir(), "rn-clip-" + name);
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });

  const lines = [];
  frames.forEach((frame, i) => {
    const file = join(work, String(i).padStart(5, "0") + ".jpg");
    writeFileSync(file, Buffer.from(frame.data, "base64"));
    // La durata vera fra un fotogramma e il successivo: lo screencast emette solo
    // quando la pagina cambia, quindi una pausa è un fotogramma che dura di più.
    const next = frames[i + 1];
    // Un fotogramma dura quanto è rimasto sullo schermo, con un tetto: lo
    // screencast emette solo quando la pagina cambia, quindi un'attesa lunga
    // diventerebbe un fermo immagine di mezzo minuto.
    const seconds = next ? Math.min(0.8, Math.max(0.033, next.at - frame.at)) : 1.5;
    lines.push(`file '${file}'`, `duration ${seconds.toFixed(3)}`);
  });
  // ffmpeg ignora la durata dell'ultimo: si ripete il file per farla valere.
  lines.push(`file '${join(work, String(frames.length - 1).padStart(5, "0") + ".jpg")}'`);
  const list = join(work, "frames.txt");
  writeFileSync(list, lines.join("\n"));

  // Da pubblicate vanno nella cartella delle clip; in prova tutte nello stesso
  // posto, che è il punto.
  const out = publish ? CLIPS_DIR : STAGE;
  mkdirSync(out, { recursive: true });
  const mp4 = join(out, name + ".mp4");
  const run = (args) => {
    const done = spawnSync("ffmpeg", ["-y", "-loglevel", "error", ...args], { stdio: "inherit" });
    if (done.status !== 0) throw new Error("ffmpeg è uscito con " + done.status);
  };
  const larghezza = 1280;
  run([
    "-f", "concat", "-safe", "0", "-i", list,
    "-vf", "scale=" + larghezza + ":-2:flags=lanczos,format=yuv420p",
    "-r", "30", "-c:v", "libx264", "-preset", "slow", "-crf", "26",
    "-movflags", "+faststart", "-an", mp4,
  ]);
  // Il poster è l'ULTIMO fotogramma: è il momento in cui si vede la cosa che la
  // clip esisteva per mostrare. Prenderlo dall'inizio significa mettere in home la
  // schermata di caricamento — che è precisamente quello che è successo la prima
  // volta che questo script è girato.
  const poster = frames[frames.length - 1];
  writeFileSync(join(out, name + "-poster.jpg"), Buffer.from(poster.data, "base64"));

  rmSync(work, { recursive: true, force: true });
  const size = readFileSync(mp4).length;
  return { mp4, size, out };
};

// ------------------------------------------------------------------- il giro

const main = async () => {
  if (!(await reachable(BASE))) {
    console.error(`L'app non risponde su ${BASE}. Avvia il dev server: bun run dev`);
    process.exit(1);
  }
  const names = wanted.length > 0 ? wanted : Object.keys(CLIPS);
  for (const name of names) {
    if (!CLIPS[name]) {
      console.error(`clip sconosciuta: ${name} (ce ne sono: ${Object.keys(CLIPS).join(", ")})`);
      process.exit(1);
    }
  }

  const profile = join(tmpdir(), "rn-clip-profile");
  mkdirSync(profile, { recursive: true });
  const chrome = launchChrome(profile, PORT);
  let cdp;
  try {
    cdp = await Cdp.open(await browserSocket(PORT));
    for (const name of names) {
      const clip = CLIPS[name];
      for (const need of clip.needs) console.log(`  ${name}: serve ${need}`);
      const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
      const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
      await cdp.send("Page.enable", {}, sessionId);
      await cdp.send("Runtime.enable", {}, sessionId);
      process.stdout.write(`${name}: registro… `);
      try {
        const frames = await record(cdp, sessionId, name, clip);
        const { size } = encode(name, frames, clip);
        console.log(`${frames.length} fotogrammi → ${(size / 1024).toFixed(0)} kB`);
        if (!publish) console.log(`  scritta in clip-nuove/ — guardala, poi --publish`);
      } catch (error) {
        console.log(`\n  ${name} FALLITA: ${error.message}`);
      }
      await cdp.send("Target.closeTarget", { targetId });
    }
  } finally {
    cdp?.socket.close();
    chrome.kill();
    // Il profilo NON si cancella: è dove restano l'interprete Python e i pacchetti
    // che una clip scarica, e ributtarli via a ogni ripresa renderebbe questo
    // script inutilizzabile per le clip che li usano.
  }
};

await main();
