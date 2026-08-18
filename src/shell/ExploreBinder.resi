/** Binds `::explore`: an interactive pivot/chart view (Perspective, a lazy
    WASM chunk) the reader drives without touching the document. The reader's
    configuration survives edits; the view follows the store live. */

let bind: (Dom.element, ~app: string) => unit
