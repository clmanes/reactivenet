// The project's only client-side storage mechanism. localStorage and sessionStorage
// are not used anywhere, by rule.
//
// IndexedDB's API is event-based and pre-Promise, so the plumbing lives in raw blocks
// with a typed ReScript signature over them. Everything here is effectful and
// failure-tolerant by design: a blocked or corrupted database resolves to `null`
// rather than rejecting, because a stored preference is never worth taking the app
// down for. Callers therefore only handle "value" or "no value", not "storage error".

let databaseName = "reactivenet"
let storeName = "preferences"

// Opening at a hard-coded version and assuming the store exists is the obvious
// implementation, and it is wrong: a database can end up at that version with the
// store missing (an upgrade that never completed, an older schema, a half-written
// database from development). `open()` then succeeds, and every transaction fails
// with NotFoundError — which, because failures resolve to null here, looks exactly
// like "nothing was ever saved".
//
// So: open whatever exists, and if the store is missing, reopen one version higher
// to get an upgrade transaction and create it. That repairs such a database in place
// instead of requiring the user to clear site data.
%%raw(`
const DB_NAME = "reactivenet";
const STORE = "preferences";

function withStore(mode, run) {
  return new Promise((resolve) => {
    if (!globalThis.indexedDB) return resolve(null);

    const runIn = (db) => {
      try {
        const transaction = db.transaction(STORE, mode);
        run(transaction, transaction.objectStore(STORE), db, resolve);
      } catch {
        db.close();
        resolve(null);
      }
    };

    let opened;
    try {
      opened = indexedDB.open(DB_NAME);
    } catch {
      return resolve(null);
    }
    opened.onerror = () => resolve(null);
    opened.onblocked = () => resolve(null);
    opened.onsuccess = () => {
      const db = opened.result;
      if (db.objectStoreNames.contains(STORE)) return runIn(db);

      const nextVersion = db.version + 1;
      db.close();

      let upgrade;
      try {
        upgrade = indexedDB.open(DB_NAME, nextVersion);
      } catch {
        return resolve(null);
      }
      upgrade.onupgradeneeded = () => {
        const upgraded = upgrade.result;
        if (!upgraded.objectStoreNames.contains(STORE)) upgraded.createObjectStore(STORE);
      };
      upgrade.onerror = () => resolve(null);
      upgrade.onblocked = () => resolve(null);
      upgrade.onsuccess = () => runIn(upgrade.result);
    };
  });
}
`)

let get: string => promise<Nullable.t<string>> = %raw(`
function (key) {
  return withStore("readonly", (transaction, store, db, resolve) => {
    const request = store.get(key);
    request.onerror = () => { db.close(); resolve(null); };
    request.onsuccess = () => {
      const value = request.result;
      db.close();
      resolve(value === undefined ? null : value);
    };
  });
}
`)

// Enumerating and deleting are what make per-app collections manageable: an app's
// data has to be listable to be backed up, and removable to be cleared.
let keys: unit => promise<array<string>> = %raw(`
function () {
  return withStore("readonly", (transaction, store, db, resolve) => {
    const request = store.getAllKeys();
    request.onerror = () => { db.close(); resolve([]); };
    request.onsuccess = () => {
      const found = request.result || [];
      db.close();
      resolve(found.map(String));
    };
  }).then((value) => value === null ? [] : value);
}
`)

let remove: string => promise<unit> = %raw(`
function (key) {
  return withStore("readwrite", (transaction, store, db, resolve) => {
    store.delete(key);
    transaction.oncomplete = () => { db.close(); resolve(); };
    transaction.onerror = () => { db.close(); resolve(); };
    transaction.onabort = () => { db.close(); resolve(); };
  });
}
`)

let set: (string, string) => promise<unit> = %raw(`
function (key, value) {
  return withStore("readwrite", (transaction, store, db, resolve) => {
    store.put(value, key);
    // Resolve on the transaction, not the request: only completion means the write
    // is durable.
    transaction.oncomplete = () => { db.close(); resolve(); };
    transaction.onerror = () => { db.close(); resolve(); };
    transaction.onabort = () => { db.close(); resolve(); };
  });
}
`)
