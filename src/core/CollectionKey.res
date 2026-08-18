// Pure. How an app's collections are addressed inside the single IndexedDB store.
//
// Collections are namespaced by the app id from the frontmatter, so two documents
// open on the same origin cannot read or clobber each other's data. The namespace is
// a key prefix rather than a separate database: one store keeps the repair logic in
// Idb applying to everything, and enumerating an app's collections is a prefix scan.

let separator = "/"
let prefix = "app" ++ separator

/** The storage key for one collection of one app. */
let of_ = (~app, ~path) => prefix ++ app ++ separator ++ path

/** The prefix every key of an app shares. */
let appPrefix = app => prefix ++ app ++ separator

// Returns the collection path only for keys of this app, so a prefix scan cannot
// pick up another app whose id merely starts with the same letters.
let pathOf = (~app, key) => {
  let start = appPrefix(app)
  key->String.startsWith(start)
    ? {
        let path = key->String.slice(~start=String.length(start), ~end=String.length(key))
        path == "" ? None : Some(path)
      }
    : None
}

let isCollection = key => key->String.startsWith(prefix)
