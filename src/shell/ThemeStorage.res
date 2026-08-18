// Effectful edge of the theme feature. Everything that touches the browser lives
// here; the decisions themselves are in the pure `Theme` module, which is why they
// can be tested without stubbing matchMedia or a database.

type mediaQueryList = {matches: bool}

@val @scope("window") external matchMedia: string => mediaQueryList = "matchMedia"

let storageKey = "theme"

// Synchronous, so React state can be seeded with it on the very first render.
let systemPreference = () =>
  Theme.fromPrefersDark(matchMedia("(prefers-color-scheme: dark)").matches)

// IndexedDB is async, so the stored choice cannot participate in the initial render.
// The app starts on the OS preference and hydrates from here in an effect.
let load = async () =>
  switch await Idb.get(storageKey) {
  | Value(stored) => Theme.parse(stored)
  | Null | Undefined => None
  }

let save = theme => Idb.set(storageKey, Theme.toTag(theme))->ignore
