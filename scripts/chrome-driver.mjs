// Pilota Chrome via CDP: la meccanica che le riprese e le schermate hanno in comune.
//
// Esiste perché ce n'erano due che facevano la stessa cosa. `record-clips.mjs` era il
// primo, e quando è arrivato `record-shots.mjs` la scelta era copiarne metà o
// estrarla: copiarla vuol dire che il giorno in cui la semina cambia — la chiave di
// IndexedDB, il modo di aspettare una pagina — una delle due va avanti e l'altra
// resta indietro, e chi se ne accorge è chi guarda il sito.
//
// **Nessuna dipendenza npm.** Chrome si pilota via WebSocket, e bun ha già il client.
// Aggiungere puppeteer significherebbe portarsi dietro un Chromium intero per una
// cosa che il Chrome già installato sa fare da sé.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { spawn } from "node:child_process";

export const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// --------------------------------------------------------------------------- CDP

export class Cdp {
  constructor(socket) {
    this.socket = socket;
    this.next = 1;
    this.pending = new Map();
    this.listeners = [];
    socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        message.error ? reject(new Error(message.error.message)) : resolve(message.result);
        return;
      }
      for (const listener of this.listeners) listener(message);
    });
  }

  static async open(url) {
    const socket = new WebSocket(url);
    await new Promise((resolve, reject) => {
      socket.addEventListener("open", resolve, { once: true });
      socket.addEventListener("error", reject, { once: true });
    });
    return new Cdp(socket);
  }

  send(method, params = {}, sessionId) {
    const id = this.next++;
    const message = { id, method, params };
    if (sessionId) message.sessionId = sessionId;
    this.socket.send(JSON.stringify(message));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }

  on(listener) {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener);
    };
  }
}

export const launchChrome = (profile, port, { width = 1280, height = 720 } = {}) =>
  spawn(
    "google-chrome",
    [
      "--headless=new",
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${profile}`,
      `--window-size=${width},${height}`,
      "--force-device-scale-factor=1",
      "--hide-scrollbars",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--autoplay-policy=no-user-gesture-required",
      "about:blank",
    ],
    { stdio: "ignore" },
  );

export const browserSocket = async (port) => {
  for (let attempt = 0; attempt < 50; attempt++) {
    try {
      const info = await fetch(`http://127.0.0.1:${port}/json/version`).then((r) => r.json());
      if (info.webSocketDebuggerUrl) return info.webSocketDebuggerUrl;
    } catch {
      /* non ancora in ascolto */
    }
    await wait(200);
  }
  throw new Error("Chrome non risponde sulla porta di debug");
};

export const reachable = async (url) => {
  try {
    const response = await fetch(url, { redirect: "manual" });
    return response.status < 500;
  } catch {
    return false;
  }
};

// ------------------------------------------------------------------- i passi

// Un passo è una funzione del contesto. Tenerli piccoli e dichiarativi è ciò che
// rende una ripresa leggibile come una sceneggiatura invece che come uno script.
export const driver = (base, repo) => {
  const steps = {
    goto: (path) => async (c) => {
      await c.send("Page.navigate", { url: base + path }, c.session);
      await wait(1200);
    },
    wait: (ms) => async () => wait(ms),
    eval: (source) => async (c) => {
      const result = await c.send(
        "Runtime.evaluate",
        { expression: source, awaitPromise: true, returnByValue: true },
        c.session,
      );
      if (result.exceptionDetails) {
        // `text` è quasi sempre la parola «Uncaught» e basta: il messaggio vero sta
        // nella descrizione dell'eccezione, ed è l'unica cosa utile quando una ripresa
        // di venti minuti si ferma su un selettore sbagliato.
        const detail =
          result.exceptionDetails.exception?.description ||
          result.exceptionDetails.exception?.value ||
          result.exceptionDetails.text;
        throw new Error("passo eval fallito: " + detail);
      }
      return result.result?.value;
    },
    click: (selector) => async (c) => {
      await steps.eval(
        `(() => { const n = document.querySelector(${JSON.stringify(selector)});
          if (!n) throw new Error("nessun elemento " + ${JSON.stringify(selector)});
          n.scrollIntoView({block:"center"}); n.click(); })()`,
      )(c);
      await wait(400);
    },
    // Testo battuto davvero: CodeMirror ascolta gli eventi di input, non il valore.
    type: (text, perChar = 45) => async (c) => {
      for (const ch of text) {
        await c.send("Input.insertText", { text: ch }, c.session);
        await wait(perChar);
      }
    },
    focus: (selector) => async (c) => {
      await steps.eval(
        `(() => { const n = document.querySelector(${JSON.stringify(selector)});
          if (!n) throw new Error("nessun elemento " + ${JSON.stringify(selector)});
          n.scrollIntoView({block:"center"}); n.focus(); })()`,
      )(c);
      await wait(300);
    },
    scroll: (selector, top) => async (c) => {
      await steps.eval(
        `(() => { const n = document.querySelector(${JSON.stringify(selector)})
            || document.querySelector(".rn-preview") || document.scrollingElement;
          n.scrollTo({ top: ${top}, behavior: "smooth" }); })()`,
      )(c);
      await wait(900);
    },
    // Apre una pagina dell'app per nome: il menu è un <nav> di bottoni, e cliccare
    // quello giusto è esattamente quello che farebbe una persona.
    page: (title) => async (c) => {
      await steps.eval(
        `(() => { const button = [...document.querySelectorAll(".rn-page-list button")]
            .find(b => b.textContent.trim().toLowerCase().startsWith(${JSON.stringify(title.toLowerCase())}));
          if (!button) throw new Error("nessuna pagina " + ${JSON.stringify(title)});
          button.click(); })()`,
      )(c);
      await wait(900);
    },
    // Aspetta che una condizione sia vera, invece di indovinare quanto ci mette.
    until: (source, timeout = 60000) => async (c) => {
      const deadline = Date.now() + timeout;
      while (Date.now() < deadline) {
        if (await steps.eval(`!!(${source})`)(c)) return;
        await wait(400);
      }
      throw new Error("condizione mai vera: " + source);
    },
  };

  // L'appId che il documento dichiara: è anche la chiave sotto cui va seminato e
  // l'indirizzo a cui l'app si apre. Sono la stessa cosa, e devono restarlo.
  const appIdOf = (file) => {
    const source = readFileSync(join(repo, file), "utf8");
    const found = source.match(/^appId:\s*(.+)$/m);
    if (!found) throw new Error(`${file} non dichiara appId`);
    return found[1].trim().replace(/^["']|["']$/g, "");
  };

  // Semina un documento in IndexedDB con la chiave che DocumentKey produce, e poi lo
  // RILEGGE. Una scrittura che non ha attecchito — il database ancora in riparazione,
  // la pagina non ancora pronta — produrrebbe la ripresa di un'app vuota, cioè
  // esattamente il genere di finto che questi script esistono per non fare.
  const seed = (file) => async (c) => {
    const appId = appIdOf(file);
    const source = readFileSync(join(repo, file), "utf8");
    const key = "doc/" + appId;

    const write = async () =>
      steps.eval(
        `(async () => {
          const open = (version) => new Promise((resolve, reject) => {
            const request = version ? indexedDB.open("reactivenet", version) : indexedDB.open("reactivenet");
            request.onupgradeneeded = () => {
              if (!request.result.objectStoreNames.contains("preferences")) {
                request.result.createObjectStore("preferences");
              }
            };
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
          });
          let db = await open();
          if (!db.objectStoreNames.contains("preferences")) {
            const version = db.version + 1;
            db.close();
            db = await open(version);
          }
          await new Promise((resolve, reject) => {
            const tx = db.transaction("preferences", "readwrite");
            tx.objectStore("preferences").put(${JSON.stringify(source)}, ${JSON.stringify(key)});
            tx.oncomplete = resolve;
            tx.onerror = () => reject(tx.error);
            tx.onabort = () => reject(tx.error);
          });
          const held = await new Promise((resolve) => {
            const tx = db.transaction("preferences", "readonly");
            const get = tx.objectStore("preferences").get(${JSON.stringify(key)});
            get.onsuccess = () => resolve(get.result);
            get.onerror = () => resolve(undefined);
          });
          db.close();
          return typeof held === "string" ? held.length : -1;
        })()`,
      )(c);

    let written = await write();
    if (written !== source.length) {
      await wait(2500);
      written = await write();
    }
    if (written !== source.length) {
      throw new Error(`semina di ${appId} non attecchita (${written} invece di ${source.length})`);
    }
  };

  // Riempie i campi di un modulo come li riempirebbe una persona: scrivendo il valore
  // e annunciandolo, che è l'unica cosa che il binder ascolta.
  const fillForm = (values) =>
    steps.eval(
      `(() => { const form = document.querySelector("[data-rn-form]");
        if (!form) throw new Error("nessun modulo in pagina");
        for (const [name, value] of Object.entries(${JSON.stringify(values)})) {
          const input = form.querySelector('[data-rn-field="' + name + '"]');
          if (!input) continue;
          input.value = value;
          input.dispatchEvent(new Event("input", { bubbles: true }));
        } })()`,
    );

  return { steps, appIdOf, seed, fillForm };
};
