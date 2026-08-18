// Rigenera site/data/applinks.json — i link «apri nella piattaforma» delle
// schede del catalogo.
//
// Un link di condivisione porta l'app INTERA nel frammento dell'indirizzo:
// chi lo apre se la ritrova nella propria galleria, senza server e senza
// account, e senza sovrascrivere nulla (un id già preso diventa una copia).
// È l'unico modo perché una pagina statica consegni un'applicazione.
//
// Il link lo costruisce il SERVER MCP LOCALE (`bun run mcp`, porta 8789):
// è lo stesso programma che valida le app, e valida anche questa — un
// documento che non passa non diventa un link. Il risultato è committato,
// così `hugo` non dipende da un servizio in ascolto: lo script si rilancia
// quando cambia un'app.
//
//   bun run mcp &                      (in un'altra shell)
//   bun site/scripts/app-links.mjs
//
// L'origine dei link è quella di produzione, non quella del server MCP, che
// per default punta al dev server.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..", "..");
const MCP = process.env.MCP_URL || "http://127.0.0.1:8789/mcp";
const APP = process.env.APP_URL || "https://app.reactivenet.ai";

// slug della scheda → documento dell'app
const APPS = {
  "scuola-in-cifre": "mcp/examples/scuola-in-cifre.md",
  "soldi-territorio": "mcp/examples/soldi-territorio.md",
  "orario-scolastico": "mcp/examples/orario-scolastico.md",
  "graduatorie-interne": "mcp/examples/graduatorie-interne.md",
  "inclusione": "mcp/examples/inclusione.md",
  "segreteria": "mcp/examples/segreteria.md",
  "mobilita-comune": "mcp/examples/mobilita-comune.md",
  "come-si-vive": "mcp/examples/come-si-vive.md",
  "salute-cittadino": "mcp/examples/salute-cittadino.md",
};

let session = null;
const rpc = async (method, params) => {
  const headers = {
    "content-type": "application/json",
    accept: "application/json, text/event-stream",
  };
  if (session) headers["mcp-session-id"] = session;
  const response = await fetch(MCP, {
    method: "POST",
    headers,
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const id = response.headers.get("mcp-session-id");
  if (id) session = id;
  const body = await response.text();
  // Streamable HTTP: la risposta può arrivare come evento SSE.
  const line = body.split("\n").find((l) => l.startsWith("data: "));
  return JSON.parse(line ? line.slice(6) : body);
};

try {
  await rpc("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "app-links", version: "1" },
  });
} catch {
  console.error(
    `nessun server MCP su ${MCP}: avvialo con \`bun run mcp\`.\n` +
      `site/data/applinks.json resta com'è — il sito si costruisce lo stesso.`,
  );
  process.exit(1);
}
await fetch(MCP, {
  method: "POST",
  headers: {
    "content-type": "application/json",
    accept: "application/json, text/event-stream",
    "mcp-session-id": session,
  },
  body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
});

const links = {};
mkdirSync(join(REPO, "site", "static", "app"), { recursive: true });

for (const [slug, path] of Object.entries(APPS)) {
  const markdown = readFileSync(join(REPO, path), "utf8");
  // Il documento viene pubblicato comunque: è la via che vale per ogni app,
  // quale che sia la sua taglia — si scarica e si importa dalla galleria.
  writeFileSync(join(REPO, "site", "static", "app", `${slug}.md`), markdown);

  const answer = await rpc("tools/call", {
    name: "reactive_app_link",
    arguments: { markdown },
  });
  const text = (answer.result?.content || []).map((c) => c.text).join("\n");
  const url = text.match(/https?:\/\/\S+/)?.[0];
  if (url) {
    links[slug] = url.replace(/^https?:\/\/[^/]+/, APP);
    console.log(`${slug}: link di ${links[slug].length} caratteri`);
    continue;
  }
  // Nessun link. Due casi diversi, e confonderli sarebbe grave: un documento
  // che NON valida è un errore da correggere, uno che valida ma eccede il
  // tetto del frammento è una app grande — legittima, e che si consegna come
  // file invece che come indirizzo.
  if (!/too big/i.test(text)) throw new Error(`${slug}: ${text}`);
  console.log(`${slug}: troppo grande per un link, resta il file .md`);
}

// L'indice: quello che l'app legge per sapere cosa c'è nel catalogo senza
// scaricare ogni documento. I campi vengono dalla frontmatter, che è l'unico
// posto dove quei valori sono già scritti una volta sola.
const field = (markdown, name) => {
  const line = markdown.match(new RegExp(`^${name}:\\s*(.*)$`, "m"));
  if (!line) return "";
  return line[1].trim().replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");
};
const index = Object.entries(APPS).map(([slug, path]) => {
  const markdown = readFileSync(join(REPO, path), "utf8");
  return {
    id: slug,
    title: field(markdown, "title"),
    description: field(markdown, "description"),
    icon: field(markdown, "icon"),
    // La versione è quello che permette all'app di sapere se quella che ha già
    // è vecchia, senza scaricare il documento per scoprirlo. Sta nella
    // frontmatter come tutto il resto di questa riga: un secondo posto dove
    // scriverla sarebbe un secondo posto da tenere aggiornato a mano.
    version: field(markdown, "version"),
  };
});
writeFileSync(
  join(REPO, "site", "static", "app", "index.json"),
  JSON.stringify(index, null, 2) + "\n",
);

mkdirSync(join(REPO, "site", "data"), { recursive: true });
writeFileSync(
  join(REPO, "site", "data", "applinks.json"),
  JSON.stringify(links, null, 2) + "\n",
);
console.log(
  `scritto site/data/applinks.json (${Object.keys(links).length} link) ` +
    `e ${Object.keys(APPS).length} documenti in site/static/app/`,
);
