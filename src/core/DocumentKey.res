// Pure. How a stored app document is addressed inside the single IndexedDB store.
//
// The same store holds preferences and collections, so documents take a prefix of
// their own. It has to be one no collection key can produce: `CollectionKey` writes
// `app/<id>/<path>`, this writes `doc/<id>`, and neither can be mistaken for the
// other by a prefix scan.

let separator = "/"
let prefix = "doc" ++ separator

let of_ = id => prefix ++ id

let idOf = key =>
  key->String.startsWith(prefix)
    ? {
        let id = key->String.slice(~start=String.length(prefix), ~end=String.length(key))
        AppId.isValid(id) ? Some(id) : None
      }
    : None

let isDocument = key => idOf(key)->Option.isSome
