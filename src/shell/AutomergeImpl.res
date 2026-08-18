// The merge engine, kept in its own module for the same reason BlockNoteImpl is:
// the static imports below — Automerge's wasm is 3.9 MB — land in a separate chunk,
// reachable only through the dynamic import in SyncEngine.res. A browser that never
// opens a shared space never loads a byte of it.
//
// Everything Automerge crosses this module's boundary as strings: documents and
// changes as base64, materialised state as JSON. That is not squeamishness about
// types — it is what lets the engine treat the CRDT as a black box that three other
// modules (store, crypto, server) already speak: strings in, strings out, and the
// wasm object graph never leaks into code that might hold it across a reload.
//
// The document shape is fixed:
//   { source: <the markdown document>, collections: { path: { rowId: { field: value } } } }
//
// Rows are maps, so two people editing different fields of the same row merge
// cleanly; the source is a text CRDT (updateText), so two edits of different
// paragraphs merge instead of one replacing the other. What cannot merge — the
// same field, the same moment — resolves last-writer-wins, which for rows of
// strings is the honest answer.

%%raw(`
import * as Automerge from "@automerge/automerge/slim";
import wasmUrl from "@automerge/automerge/automerge.wasm?url";

let ready = null;
const docs = new Map();

const toB64 = (bytes) => {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
};
const fromB64 = (encoded) => {
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
};
const headsOf = (doc) => Automerge.getHeads(doc).join(",");
`)

/** Compiles the wasm once; every other call may assume it. */
let init: unit => promise<unit> = %raw(`
function () {
  if (!ready) {
    ready = Automerge.initializeWasm(fetch(wasmUrl));
  }
  return ready;
}
`)

/** Opens an app's document from a saved copy, or fresh. */
let open_: (~app: string, ~saved: option<string>) => unit = %raw(`
function (app, saved) {
  if (saved !== undefined && saved !== "") {
    try {
      docs.set(app, Automerge.load(fromB64(saved)));
      return;
    } catch (error) {
      // A copy that will not load is dropped, not fatal: the log on the server
      // still holds the history, and the next pull rebuilds from it.
    }
  }
  docs.set(app, Automerge.init());
}
`)

let close: (~app: string) => unit = %raw(`
function (app) {
  docs.delete(app);
}
`)

let save: (~app: string) => string = %raw(`
function (app) {
  const doc = docs.get(app);
  return doc ? toB64(Automerge.save(doc)) : "";
}
`)

/** Brings the document to match local reality — the stored collections and the
    markdown source — and answers the incremental change that says so, or None
    when nothing differed. */
let applyLocal: (~app: string, ~snapshot: string) => option<string> = %raw(`
function (app, snapshot) {
  const before = docs.get(app);
  if (!before) return undefined;
  const wanted = JSON.parse(snapshot);
  const after = Automerge.change(before, (d) => {
    if (typeof wanted.source === "string") {
      if (d.source === undefined) {
        d.source = wanted.source;
      } else if (d.source !== wanted.source) {
        Automerge.updateText(d, ["source"], wanted.source);
      }
    }
    if (d.collections === undefined) d.collections = {};
    const target = wanted.collections || {};
    for (const path of Object.keys(d.collections)) {
      if (!(path in target)) delete d.collections[path];
    }
    for (const path of Object.keys(target)) {
      if (!d.collections[path]) d.collections[path] = {};
      const rows = target[path];
      const held = d.collections[path];
      for (const id of Object.keys(held)) {
        if (!(id in rows)) delete held[id];
      }
      for (const id of Object.keys(rows)) {
        if (!held[id]) held[id] = {};
        const fields = rows[id];
        const row = held[id];
        for (const name of Object.keys(row)) {
          if (!(name in fields)) delete row[name];
        }
        for (const name of Object.keys(fields)) {
          if (row[name] !== fields[name]) row[name] = fields[name];
        }
      }
    }
  });
  if (headsOf(after) === headsOf(before)) return undefined;
  docs.set(app, after);
  const change = Automerge.getLastLocalChange(after);
  return change ? toB64(change) : undefined;
}
`)

/** Applies changes from the log. Duplicates cost nothing — Automerge deduplicates
    by hash, which is what lets the pull cursor overlap instead of gap. Answers
    whether the document actually moved. */
let applyRemote: (~app: string, ~changes: array<string>) => bool = %raw(`
function (app, changes) {
  const before = docs.get(app);
  if (!before) return false;
  const decoded = [];
  for (const encoded of changes) {
    try {
      decoded.push(fromB64(encoded));
    } catch (error) {
      // One undecodable blob must not stop the ones behind it.
    }
  }
  if (decoded.length === 0) return false;
  let after = before;
  try {
    [after] = Automerge.applyChanges(before, decoded);
  } catch (error) {
    return false;
  }
  const moved = headsOf(after) !== headsOf(before);
  docs.set(app, after);
  return moved;
}
`)

/** Merges a saved document — a server snapshot — into the one held. A merge and
    not a replacement, so a member who was offline past a compaction keeps their
    own unsent edits: the CRDT reconciles the two histories instead of choosing. */
let mergeSaved: (~app: string, ~saved: string) => bool = %raw(`
function (app, saved) {
  const before = docs.get(app);
  if (!before || saved === "") return false;
  let other;
  try {
    other = Automerge.load(fromB64(saved));
  } catch (error) {
    return false;
  }
  const after = Automerge.merge(before, other);
  const moved = headsOf(after) !== headsOf(before);
  docs.set(app, after);
  return moved;
}
`)

/** The document's current state as JSON — the same shape applyLocal reads. */
let materialize: (~app: string) => string = %raw(`
function (app) {
  const doc = docs.get(app);
  if (!doc) return JSON.stringify({ source: "", collections: {} });
  const plain = JSON.parse(JSON.stringify(doc));
  return JSON.stringify({
    source: typeof plain.source === "string" ? plain.source : "",
    collections: plain.collections && typeof plain.collections === "object" ? plain.collections : {},
  });
}
`)
