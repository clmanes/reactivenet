// Sincronizza la normativa (legal/) dentro il sito (site/content/*/note-legali/).
//
// legal/ è la fonte di verità — italiano testo di riferimento, inglese
// traduzione — e il sito ne pubblica una COPIA GENERATA: questo script è
// l'unico scrittore di site/content/*/note-legali/*.md (tranne _index.md,
// che è del sito). Si rilancia dopo ogni modifica a legal/ e il deploy lo
// esegue sempre prima della build di Hugo, così le due copie non possono
// divergere sul sito pubblicato.
//
//   bun site/scripts/sync-legal.mjs        (da qualunque cwd del repo)
//
// Cosa fa, per ciascun documento pubblicabile:
//   - rinomina il file sullo slug italiano della tabella di legal/README.md
//     (stesso nome in EN: la convenzione del sito è il percorso italiano
//     anche sotto /en/, e nomi uguali danno URL gemelli senza override);
//   - toglie il primo H1 del corpo: il layout stampa già .Title, e un H1
//     doppio è un H1 doppio anche per uno screen reader;
//   - aggiunge un commento "GENERATO" e un `weight` per l'ordine dell'indice.
//
// L'atto di nomina ex art. 28 (nomina-responsabile-art28 / data-processing-
// agreement) non è una pagina web: è un modello di contratto, e resta fuori.

import { readFileSync, writeFileSync, readdirSync, mkdirSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..", "..");

// slug → sorgente per lingua. L'ordine è l'ordine dell'indice (weight).
const DOCS = [
  { slug: "privacy", it: "informativa-privacy.md", en: "privacy-policy.md" },
  { slug: "cookie", it: "cookie-policy.md", en: "cookie-policy.md" },
  { slug: "termini", it: "termini-di-servizio.md", en: "terms-of-service.md" },
  { slug: "accessibilita", it: "dichiarazione-accessibilita.md", en: "accessibility-statement.md" },
  { slug: "licenze", it: "licenze-e-attribuzioni.md", en: "licences-and-attributions.md" },
  { slug: "sicurezza", it: "politica-di-sicurezza.md", en: "security-policy.md" },
];

const transform = (raw, source, weight) => {
  // Frontmatter: il blocco `---` iniziale resta com'è, con un `weight` in coda
  // per l'ordine dell'indice di sezione.
  const m = raw.match(/^---\n([\s\S]*?)\n---\n/);
  if (!m) throw new Error(`${source}: frontmatter mancante`);
  const front = `---\n${m[1]}\nweight: ${weight}\n---\n`;
  let body = raw.slice(m[0].length);
  // Il primo H1 se ne va: il titolo lo stampa il layout, dalla frontmatter.
  body = body.replace(/^\s*# .*\n+/, "\n");
  const banner =
    `<!-- GENERATO da site/scripts/sync-legal.mjs — non modificare qui.\n` +
    `     La fonte è ${source}: modifica quella e rilancia lo script. -->\n`;
  return front + "\n" + banner + body;
};

for (const lang of ["it", "en"]) {
  const target = join(REPO, "site", "content", lang, "note-legali");
  mkdirSync(target, { recursive: true });
  // Via i .md generati non più prodotti (uno slug rinominato non deve
  // lasciare una pagina orfana); _index.md è del sito e resta.
  for (const f of readdirSync(target)) {
    if (f.endsWith(".md") && f !== "_index.md") rmSync(join(target, f));
  }
  DOCS.forEach((doc, i) => {
    const source = join("legal", lang, doc[lang]);
    const raw = readFileSync(join(REPO, source), "utf8");
    writeFileSync(join(target, `${doc.slug}.md`), transform(raw, source, (i + 1) * 10));
  });
  console.log(`${lang}: ${DOCS.length} documenti → site/content/${lang}/note-legali/`);
}
