// Pure. The arithmetic of semantic search: how a document is cut into passages, and
// which passages a question is nearest to.
//
// Everything effectful about `::ai-search` — reading the rows, decoding an
// attachment, asking the model for vectors, keeping the index in IndexedDB — is the
// binder's. What is here is the part that must be the same on every device and is
// worth a test: the chunking, the cosine, and the ranking.
//
// Two decisions worth stating, because both are visible in the answers:
//
//   - **A passage is a few hundred characters, cut at a sentence.** Embedding a
//     whole document gives one vector for twenty different things and finds none of
//     them; embedding a line at a time gives a hundred vectors that each say too
//     little. The overlap is deliberate: a sentence answering a question is often
//     the one straddling a cut.
//   - **The vectors are normalised once, when they are stored.** A cosine is then a
//     dot product, and a search over a few thousand passages is arithmetic nobody
//     notices — which is what makes an index that lives in the browser tenable.

type item = {
  /** Which row and field the passage came from: "documenti/abc123/allegato". */
  key: string,
  /** What a citation says — the name of the file, or of the row. */
  label: string,
  text: string,
  vector: array<float>,
}

type hit = {item: item, score: float}

/** A document as the passages it will be searched by. `size` is in characters; the
    overlap is a fifth of it. A text shorter than one passage is one passage. */
let chunks: (string, int) => array<string> = %raw(`
function (text, size) {
  const source = String(text || "").replace(/\s+/g, " ").trim();
  if (source === "") return [];
  const width = Math.max(120, size || 600);
  if (source.length <= width) return [source];
  const overlap = Math.floor(width / 5);
  const out = [];
  let at = 0;
  while (at < source.length) {
    let end = Math.min(source.length, at + width);
    if (end < source.length) {
      // Back up to the last sentence end, then to the last space: a passage cut
      // mid-word is a passage that reads as a mistake in every citation.
      const window = source.slice(at, end);
      const stop = Math.max(window.lastIndexOf(". "), window.lastIndexOf("? "), window.lastIndexOf("! "));
      const space = window.lastIndexOf(" ");
      const cut = stop > width / 2 ? stop + 1 : space > width / 2 ? space : -1;
      if (cut > 0) end = at + cut;
    }
    const piece = source.slice(at, end).trim();
    if (piece !== "") out.push(piece);
    if (end >= source.length) break;
    at = Math.max(end - overlap, at + 1);
  }
  return out;
}
`)

/** A vector of length one. Stored this way so that a cosine is a dot product. */
let normalise: array<float> => array<float> = %raw(`
function (vector) {
  let sum = 0;
  for (const n of vector) sum += n * n;
  const length = Math.sqrt(sum);
  if (!Number.isFinite(length) || length === 0) return vector.map(() => 0);
  return vector.map((n) => n / length);
}
`)

/** The cosine of two vectors — a dot product, since both are normalised. Vectors of
    different lengths are two different models' work and have no angle between them:
    that answers zero rather than the nonsense of comparing the first n numbers. */
let cosine: (array<float>, array<float>) => float = %raw(`
function (a, b) {
  if (a.length !== b.length) return 0;
  let sum = 0;
  for (let i = 0; i < a.length; i++) sum += a[i] * b[i];
  return sum;
}
`)

/** The nearest passages, best first, dropping anything below `floor` — a search that
    always answers something answers nonsense when the index holds nothing relevant,
    and "no match" is a better answer than the least bad one. */
let rank: (array<float>, array<item>, ~many: int, ~floor: float) => array<hit> = %raw(`
function (question, items, many, floor) {
  const hits = [];
  for (const item of items) {
    const score = cosineOf(question, item.vector);
    if (score >= floor) hits.push({ item, score });
  }
  hits.sort((a, b) => b.score - a.score);
  // One passage per source: five chunks of the same file are one answer, and they
  // would push every other document off a list of five.
  const seen = new Set();
  const kept = [];
  for (const hit of hits) {
    const source = hit.item.key.split("#")[0];
    if (seen.has(source)) continue;
    seen.add(source);
    kept.push(hit);
    if (kept.length >= many) break;
  }
  return kept;
}
`)

%%raw(`const cosineOf = cosine;`)

/** The passages as a model should receive them: named, so it can cite them, and in
    the order they were ranked. */
let context: array<hit> => string = %raw(`
function (hits) {
  return hits.map((hit) => "[" + hit.item.label + "] " + hit.item.text).join("\n\n");
}
`)
