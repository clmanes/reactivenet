// Scarica una copertina da Openverse per ogni post del blog e la registra nel
// frontmatter con la sua attribuzione. Eseguire con:
//   bun scripts/blog-covers.mjs            # solo i post senza copertina
//   bun scripts/blog-covers.mjs --force    # riscarica tutto
//
// L'attribuzione non è cortesia: CC BY e CC BY-SA la richiedono, quindi ogni
// copertina porta autore, licenza e link alla pagina d'origine, e il layout li
// mostra sotto l'immagine. Le immagini finiscono in static/img/blog/ e vengono
// committate: un post non deve dipendere da un host di terzi per essere visto.

import { readdir, readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";

const ROOT = new URL("..", import.meta.url).pathname;
// Sotto assets/, non static/: Hugo le ridimensiona e converte in WebP a build
// time, e gli originali di Openverse arrivano a 750 kB l'uno.
const OUT_DIR = `${ROOT}assets/img/blog`;
const FORCE = process.argv.includes("--force");
const UA = "reactivenet-site/1.0 (+https://reactivenet.ai)";

// Una query per post, scelta a mano: cercare il titolo darebbe risultati a caso.
// La chiave è la translationKey, così i due articoli di una coppia condividono
// la copertina e il sito resta coerente fra le lingue.
const QUERIES = {
  "cos-e-reactive": "notebook writing desk",
  "micro-app-componibili": "building blocks",
  "app-componibili-spazi-condivisi": "teamwork collaboration",
  "editor-a-blocchi": "printing press type",
  "design-with-ai": "architect blueprint drawing",
  "bi-in-the-browser": "business charts analytics",
  "ml-nel-browser": "neural network abstract",
  "iot-nel-browser": "circuit board sensor",
  "pezzi-3d-nel-browser": "3d printer",
  "dati-open-nelle-app": "open data archive",
  "tre-app-open-data": "public records archive",
  "opencup": "construction site public works",
  "five-school-datasets": "school classroom",
  "six-new-datasets": "statistics library",
  "parliament-and-justice": "courthouse columns",
};

const LICENCE_NAMES = {
  cc0: "CC0",
  pdm: "Public Domain Mark",
  by: "CC BY",
  "by-sa": "CC BY-SA",
  "by-nd": "CC BY-ND",
  "by-nc": "CC BY-NC",
};

const licenceUrl = (licence, version) =>
  licence === "cc0"
    ? "https://creativecommons.org/publicdomain/zero/1.0/"
    : licence === "pdm"
      ? "https://creativecommons.org/publicdomain/mark/1.0/"
      : `https://creativecommons.org/licenses/${licence}/${version || "4.0"}/`;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Openverse risponde 500 a intermittenza su query del tutto valide, quindi si
// riprova invece di lasciare che un post resti senza copertina per un guasto
// altrui.
async function searchOnce(query) {
  // Solo licenze che consentono l'uso commerciale e la modifica: un sito è un
  // uso commerciale, e ritagliare la copertina è una modifica.
  const url =
    "https://api.openverse.org/v1/images/?" +
    new URLSearchParams({
      q: query,
      license_type: "commercial,modification",
      page_size: "8",
      mature: "false",
    });
  const res = await fetch(url, { headers: { "User-Agent": UA } });
  if (!res.ok) throw new Error(`Openverse ${res.status}`);
  const { results = [] } = await res.json();
  // Preferisce le licenze senza obbligo di attribuzione, poi CC BY, poi il resto.
  const rank = (r) => (["cc0", "pdm"].includes(r.license) ? 0 : r.license === "by" ? 1 : 2);
  return results.filter((r) => r.url).sort((a, b) => rank(a) - rank(b))[0];
}

async function search(query) {
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const hit = await searchOnce(query);
      if (hit) return hit;
      console.log(`  … nessun risultato per "${query}"`);
      return null;
    } catch (err) {
      if (attempt === 4) {
        console.log(`  ✗ "${query}": ${err.message}, rinuncio`);
        return null;
      }
      await sleep(attempt * 1500);
    }
  }
  return null;
}

async function download(url, dest) {
  const res = await fetch(url, { headers: { "User-Agent": UA } });
  if (!res.ok) throw new Error(`download ${res.status}`);
  await writeFile(dest, Buffer.from(await res.arrayBuffer()));
}

function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error("frontmatter mancante");
  return { head: m[1], body: m[2] };
}

const field = (head, key) => head.match(new RegExp(`^${key}:\\s*"?(.*?)"?\\s*$`, "m"))?.[1];

function setFields(head, fields) {
  let out = head;
  for (const [key, value] of Object.entries(fields)) {
    const line = `${key}: ${JSON.stringify(value)}`;
    out = new RegExp(`^${key}:.*$`, "m").test(out)
      ? out.replace(new RegExp(`^${key}:.*$`, "m"), line)
      : `${out}\n${line}`;
  }
  return out;
}

await mkdir(OUT_DIR, { recursive: true });

const picked = new Map(); // translationKey -> dati della copertina, condivisi fra lingue
let written = 0;
let skipped = 0;

for (const lang of ["it", "en"]) {
  const dir = `${ROOT}content/${lang}/blog`;
  if (!existsSync(dir)) continue;
  for (const name of (await readdir(dir)).filter((f) => f.endsWith(".md") && f !== "_index.md")) {
    const path = `${dir}/${name}`;
    const text = await readFile(path, "utf8");
    const { head, body } = frontmatter(text);
    const key = field(head, "translationKey") || name.replace(/\.md$/, "");

    if (field(head, "cover") && !FORCE) {
      skipped++;
      continue;
    }

    let cover = picked.get(key);
    if (!cover) {
      const query = QUERIES[key];
      if (!query) {
        console.log(`· nessuna query per "${key}" — saltato`);
        continue;
      }
      const hit = await search(query);
      if (!hit) {
        console.log(`✗ ${key}: nessuna copertina`);
        continue;
      }
      const ext = (hit.url.match(/\.(jpe?g|png|webp)(\?|$)/i)?.[1] || "jpg").toLowerCase();
      const file = `${key}.${ext === "jpeg" ? "jpg" : ext}`;
      try {
        await download(hit.url, `${OUT_DIR}/${file}`);
      } catch (err) {
        console.log(`✗ ${key}: download fallito (${err.message})`);
        continue;
      }
      cover = {
        cover: `/img/blog/${file}`,
        coverAlt: hit.title || query,
        coverAuthor: hit.creator || "sconosciuto",
        coverAuthorUrl: hit.creator_url || hit.foreign_landing_url,
        coverSource: hit.foreign_landing_url,
        coverLicense: LICENCE_NAMES[hit.license] || hit.license.toUpperCase(),
        coverLicenseUrl: licenceUrl(hit.license, hit.license_version),
      };
      picked.set(key, cover);
      console.log(`✓ ${key}: ${cover.coverLicense} — ${cover.coverAuthor}`);
    }

    await writeFile(path, `---\n${setFields(head, cover)}\n---\n${body}`);
    written++;
  }
}

console.log(`\n${written} post aggiornati, ${skipped} già con copertina.`);
