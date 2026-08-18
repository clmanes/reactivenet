/** Writes a value and updates every bound view. */
let set: (string, string) => unit

let get: string => Nullable.t<string>

/** Binds `[data-reactive-key]` elements inside the container. Safe to call after
    every render; nodes from a previous render of the same container are dropped. */
let bind: Dom.element => unit

/** Forgets every key. Called when another app is opened, so one document's live
    values do not arrive as the starting values of the next. */
let reset: unit => unit

/** Hears every write, told which key moved. Module-level and permanent — it
    survives `reset` on purpose, so subscribe once at load and filter by what is
    actually on the page. */
let subscribe: (string => unit) => unit
