// Which of an app's collections are DERIVED — produced on this device by
// ::api-query, ::sql or the ml-* directives rather than typed by anybody.
//
// The one consequence, and the reason this module exists: the sync engine
// leaves them alone in both directions. They are not pushed (a fetched exchange
// rate is not a shared fact, and every member can fetch their own), and a
// remote snapshot that does not carry them must not delete them locally. The
// set lives in IndexedDB beside everything else and moves with a renamed app.

let key = app => "derived:" ++ app

let decode: string => array<string> = %raw(`
function (text) {
  try {
    const parsed = JSON.parse(text);
    return Array.isArray(parsed) ? parsed.filter((p) => typeof p === "string") : [];
  } catch {
    return [];
  }
}
`)

let list = async (~app) =>
  switch await Idb.get(key(app)) {
  | Value(stored) => decode(stored)
  | Null | Undefined => []
  }

let mark = async (~app, ~path) => {
  let held = await list(~app)
  if !(held->Array.includes(path)) {
    held->Array.push(path)
    await Idb.set(key(app), JSON.stringifyAny(held)->Option.getOr("[]"))
  }
}

/** Follows a renamed app, the way the space link does. */
let rename = async (~from, ~to_) => {
  switch await Idb.get(key(from)) {
  | Value(stored) => {
      await Idb.set(key(to_), stored)
      await Idb.remove(key(from))
    }
  | Null | Undefined => ()
  }
}
