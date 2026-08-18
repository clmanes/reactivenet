// The catalogue's two reads, against the site that publishes it.
//
// Plain fetch, no client library, for the same reason ShareServer has none: there
// is a document and a list, and two fetches keep the bundle exactly as heavy as it
// was. Every failure is `None` rather than an exception — an unreachable site, a
// 404 for an id nobody published and an answer that is not a document all mean the
// same thing to the caller, which is that nothing arrived, and each already has its
// own sentence where it lands.
//
// The catalogue is reached as `/catalog/*` on THIS app's own origin, which is the
// arrangement `/pb`, `/od`, `/mcp` and `/pa` already have and it is the same
// argument every time: connect-src 'self' keeps holding, no CORS is involved, and
// nothing — no document, no setting, no attribute — can point the app at a
// catalogue of somebody else's choosing. The Vite proxy answers in development and
// a host rewrite in production; where neither exists every call resolves to
// nothing, which the caller reads as "the catalogue did not answer".

let prefix = "/catalog"

/* Both reads are made with `cache: "no-cache"`, and it is not a precaution — it is
   the difference between the catalogue working and the catalogue lying.

   These two answers are the ones that MUST be allowed to change from one minute to
   the next: the index says which version of each app is published, and the document
   is that version. The site serves them with an ETag and a Last-Modified and no
   `Cache-Control` at all, and a browser given no directive applies its own heuristic
   — a fraction of the age since the file last changed — and reuses what it holds
   WITHOUT ASKING. So an app published five minutes ago is invisible for hours: the
   gallery offers no update, because the index it read still carries the old version,
   and `/c/<id>` installs the copy the cache kept. Nothing looks broken from either
   side; the server is right and the reader is served yesterday.

   `no-cache` is not `no-store`: the copy is kept and the request still carries its
   validators, so an unchanged document costs a 304 rather than 166 kB. What it buys
   is that the question is always asked. Doing it here rather than only in the server
   means it holds wherever the catalogue is served from — and it is served through a
   proxy to another host, whose headers are one deploy further away than this line. */

/** The document of one catalogue app. `missing` tells the two failures apart: an
    id the catalogue does not publish is a wrong link and says so, while nothing at
    all is a connection and says that instead — guessing between them would put the
    wrong sentence in front of the reader half the time. */
let fetchDocument: string => promise<{"text": option<string>, "missing": bool}> = %raw(`
async function (id) {
  try {
    const response = await fetch("/catalog/app/" + encodeURIComponent(id) + ".md",
                                 { cache: "no-cache" });
    // 404 is the catalogue answering: it is there, and it does not have this.
    if (response.status === 404) return { text: undefined, missing: true };
    if (!response.ok) return { text: undefined, missing: false };
    const text = await response.text();
    // A site that answers every unknown address with its own HTML would otherwise
    // hand back a page and call it a document. A document opens with frontmatter.
    return text.startsWith("---")
      ? { text, missing: false }
      : { text: undefined, missing: true };
  } catch (error) {
    return { text: undefined, missing: false };
  }
}
`)

/** What the catalogue holds: one entry per app, as the site wrote it. Nothing when
    the site cannot be reached — the gallery simply does not show the section.

    `version` is what tells an app already installed here that a newer one has been
    published; an index written before that field existed simply has none, and
    `CatalogUpdate` reads an unwritten version as "no answer" rather than as old. */
let fetchIndex: unit => promise<
  array<{"id": string, "title": string, "description": string, "version": string}>,
> = %raw(`
async function () {
  try {
    const response = await fetch(
      "/catalog/app/index.json",
      { cache: "no-cache" }
    );
    if (!response.ok) return [];
    const entries = await response.json();
    if (!Array.isArray(entries)) return [];
    return entries
      .filter((entry) => entry && typeof entry.id === "string" && entry.id !== "")
      // The fields are read from somebody else's file, so each is given a type
      // here rather than trusted: a version that arrives as a number would be
      // compared against a string and never match.
      .map((entry) => ({
        id: entry.id,
        title: typeof entry.title === "string" ? entry.title : "",
        description: typeof entry.description === "string" ? entry.description : "",
        version: typeof entry.version === "string" ? entry.version : "",
      }));
  } catch (error) {
    return [];
  }
}
`)
