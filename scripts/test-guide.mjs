// Ogni direttiva che l'app conosce ha la sua pagina nella guida del sito, nelle due
// lingue. Fallisce se non è vero.
//
// Esiste perché la deriva era già successa e nessuno se ne era accorto: il
// 16 agosto 2026 `doc/` documentava 57 direttive su 57 e la guida del sito 20 —
// mancavano tutte le `ai-*`, le `ml-*`, le `od-*`, i sette `chart-*`, `map`, `geo`,
// `geocode`, `api-query`, `choose`, `dashboard`, `explore`. Il modello sapeva
// scrivere `::ml-forecast` e una persona che leggeva il sito no.
//
// La fonte è il REGISTRO COMPILATO, non un elenco scritto a mano qui dentro: un
// secondo elenco sarebbe una terza copia da tenere in passo, che è il difetto che
// questa prova esiste per impedire.
//
//   bun scripts/test-guide.mjs
//
// La ricerca è per NOME NUDO, non per `::nome`: una direttiva può comparire in una
// tabella di attributi o in una frase, e pretendere la forma con i due punti
// segnalerebbe come mancante una pagina che la documenta benissimo. Il rovescio è
// che un nome citato di sfuggita conta come documentato — questa prova dice che il
// buco non c'è, non che la pagina è buona.

import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..");
const LINGUE = ["it", "en"];

// Le direttive proprie di ReactiveNET. I 92 componenti Spectrum non sono qui
// dentro di proposito: sono generati da un manifest e la loro pagina li descrive
// come insieme, perché elencarli a mano vorrebbe dire riscriverla a ogni upgrade
// della libreria — di nuovo una copia che divarica.
const registro = () => {
  const testo = readFileSync(join(REPO, "src/core/DirectiveRegistry.res"), "utf8");
  const dopo = testo.slice(testo.indexOf("let reactive"));
  const trovate = dopo.match(/directive: "[a-z0-9-]+"/g) || [];
  return [...new Set(trovate.map((s) => s.slice(12, -1)))].sort();
};

const guida = (lingua) => {
  const dove = join(REPO, "site/content", lingua, "guida");
  return readdirSync(dove)
    .filter((f) => f.endsWith(".md"))
    .map((f) => readFileSync(join(dove, f), "utf8"))
    .join("\n");
};

const cita = (testo, nome) =>
  new RegExp("(^|[^a-zA-Z0-9-])" + nome + "([^a-zA-Z0-9-]|$)").test(testo);

const nomi = registro();
let rotto = false;

for (const lingua of LINGUE) {
  const testo = guida(lingua);
  const fuori = nomi.filter((n) => !cita(testo, n));
  if (fuori.length) {
    rotto = true;
    console.error(
      `✗ guida ${lingua}: ${nomi.length - fuori.length}/${nomi.length} direttive documentate.\n` +
        `  Senza pagina: ${fuori.join(", ")}`,
    );
  } else {
    console.log(`✓ guida ${lingua}: tutte e ${nomi.length} le direttive sono documentate`);
  }
}

// E la guida che il server MCP serve all'assistente, che è l'altra copia: se
// diverge, il modello e la persona leggono due linguaggi diversi.
const doc = readdirSync(join(REPO, "doc"))
  .filter((f) => f.endsWith(".md"))
  .map((f) => readFileSync(join(REPO, "doc", f), "utf8"))
  .join("\n");
const fuoriDoc = nomi.filter((n) => !cita(doc, n));
if (fuoriDoc.length) {
  rotto = true;
  console.error(`✗ doc/: senza documentazione: ${fuoriDoc.join(", ")}`);
} else {
  console.log(`✓ doc/: tutte e ${nomi.length} le direttive sono documentate`);
}

if (rotto) {
  console.error(
    "\nUna direttiva non è finita finché la sua documentazione non la segue:\n" +
      "  doc/directives.md e site/content/{it,en}/guida/, nello stesso lavoro.",
  );
  process.exit(1);
}
console.log("\n✓ registro, doc/ e guida del sito parlano dello stesso linguaggio");
