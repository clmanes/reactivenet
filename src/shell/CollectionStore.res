// Per-app collection storage, on IndexedDB like everything else in this project.
//
// Every operation is scoped by the app id from the frontmatter: listing, reading,
// writing, deleting and backing up all go through CollectionKey, so one document
// cannot see or clear another's data even though they share one object store.

let encode: Collection.t => string = %raw(`
function (collection) {
  return JSON.stringify(
    collection.records.map((record) => ({
      id: record.id,
      fields: Object.fromEntries(record.fields.map((f) => [f.name, f.value])),
    }))
  );
}
`)

let decode: string => Collection.t = %raw(`
function (text) {
  try {
    const parsed = JSON.parse(text);
    if (!Array.isArray(parsed)) return { records: [] };
    return {
      records: parsed.map((record) => ({
        id: String(record && record.id !== undefined ? record.id : ""),
        fields: Object.entries((record && record.fields) || {}).map(([name, value]) => ({
          name,
          value: String(value),
        })),
      })),
    };
  } catch {
    // A collection that will not parse is reported as empty rather than throwing:
    // one corrupt key must not take the whole app down.
    return { records: [] };
  }
}
`)

let read = async (~app, ~path) =>
  switch await Idb.get(CollectionKey.of_(~app, ~path)) {
  | Value(stored) => decode(stored)
  | Null | Undefined => Collection.empty
  }

// Announced after the write is durable, naming the app AND the collection: the sync
// engine listens for this to learn that local data moved — one hook that catches every
// writer (forms, board drags, CSV imports, Python) instead of one call in each.
//
// The path was added for `::workflow{on="save:spese"}`, which has to tell one
// collection from another; the sync engine reads only the app and is untouched by it.
// Announcing the app alone would have meant a workflow watching one form re-running on
// every write anywhere in the document — which is not a trigger, it is a coincidence.
let notify: (string, string) => unit = %raw(`
function (app, path) {
  globalThis.dispatchEvent(new CustomEvent("rn:collection-write", { detail: { app, path } }));
}
`)

let write = async (~app, ~path, collection) => {
  await Idb.set(CollectionKey.of_(~app, ~path), encode(collection))
  notify(app, path)
}

/** The collection paths this app has stored. */
let paths = async (~app) => {
  let keys = await Idb.keys()
  keys->Array.filterMap(key => CollectionKey.pathOf(~app, key))
}

let remove = async (~app, ~path) => {
  await Idb.remove(CollectionKey.of_(~app, ~path))
  notify(app, path)
}

/** Clears every collection of one app, leaving other apps and the preferences
    untouched. */
let clear = async (~app) => {
  let stored = await paths(~app)
  let _ = await Promise.all(stored->Array.map(path => remove(~app, ~path)))
}

/** Reads every collection, for a backup. */
let exportAll = async (~app) => {
  let stored = await paths(~app)
  let collections = await Promise.all(
    stored->Array.map(async path => (path, await read(~app, ~path))),
  )
  collections
}

/** Writes a backup's collections in. Replaces what is there for the paths the backup
    carries and leaves any others alone — the caller decides whether to clear first. */
let importAll = async (~app, collections) => {
  let _ = await Promise.all(
    collections->Array.map(((path, collection)) => write(~app, ~path, collection)),
  )
}
