// Effectful edge of the language feature, mirroring ThemeStorage: the browser talk
// lives here, the decisions live in the pure Locale module.

@val @scope("navigator") external languages: array<string> = "languages"

let storageKey = "locale"

// Synchronous, so the first render is already in the right language rather than
// flashing English while IndexedDB answers.
let browserPreference = () => Locale.fromPreferred(languages)

let load = async () =>
  switch await Idb.get(storageKey) {
  | Value(stored) => Locale.parse(stored)
  | Null | Undefined => None
  }

let save = locale => Idb.set(storageKey, Locale.toTag(locale))->ignore
