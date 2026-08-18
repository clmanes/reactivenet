// Effectful edge of the palette feature, mirroring ThemeStorage.

let storageKey = "palette"

let load = async () =>
  switch await Idb.get(storageKey) {
  | Value(stored) => Palette.parse(stored)
  | Null | Undefined => None
  }

let save = palette => Idb.set(storageKey, Palette.toTag(palette))->ignore
