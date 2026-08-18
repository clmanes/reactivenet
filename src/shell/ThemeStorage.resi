/** The OS preference, read synchronously so it can seed the first render. */
let systemPreference: unit => Theme.t

/** The persisted choice, if any. Async because IndexedDB is. */
let load: unit => promise<option<Theme.t>>

let save: Theme.t => unit
