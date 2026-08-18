/** The browser's preferred language, read synchronously to seed the first render. */
let browserPreference: unit => Locale.t

/** The persisted choice, if any. Async because IndexedDB is. */
let load: unit => promise<option<Locale.t>>

let save: Locale.t => unit
