/** The persisted palette, if any. Async because IndexedDB is. */
let load: unit => promise<option<Palette.t>>

let save: Palette.t => unit
