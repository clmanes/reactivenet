// Where a LARGE ::file attachment's content lives: IndexedDB, on the device
// that chose the file. The row carries only {name, local: id} — small files
// (≤300 kB) ride inside the row as a data: URL and sync with it; these stay
// here, so on another device the name shows and the content honestly is not
// available, instead of a sync change no server would accept.

let key = (app, id) => "filestore:" ++ app ++ ":" ++ id

let save = (~app, ~id, dataUrl) => Idb.set(key(app, id), dataUrl)

let load = async (~app, ~id) =>
  switch await Idb.get(key(app, id)) {
  | Value(stored) if stored->String.startsWith("data:") => Some(stored)
  | _ => None
  }
