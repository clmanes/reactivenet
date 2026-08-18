/** The merge engine — Automerge behind a boundary of strings, in its own chunk,
    reached only by dynamic import from SyncEngine. Documents and changes travel as
    base64, materialised state as JSON `{source, collections}`. */

let init: unit => promise<unit>

let open_: (~app: string, ~saved: option<string>) => unit

let close: (~app: string) => unit

let save: (~app: string) => string

/** Brings the document to match local reality; the incremental change, or None
    when nothing differed. */
let applyLocal: (~app: string, ~snapshot: string) => option<string>

/** Applies changes from the log; duplicates are free. True when the document moved. */
let applyRemote: (~app: string, ~changes: array<string>) => bool

/** Merges a server snapshot into the held document — a merge, not a replacement. */
let mergeSaved: (~app: string, ~saved: string) => bool

/** The current state as JSON, the same shape applyLocal reads. */
let materialize: (~app: string) => string
