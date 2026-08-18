/** Re-checks every `<a href>` in a container against [SafeUrl] and adds
    `target="_blank" rel="noopener noreferrer"`. A link that does not pass keeps its
    text and loses its href, titled with `removed` — the words are the caller's,
    because they are the reader's language. */
let harden: (Dom.element, ~removed: string) => unit

/** Wraps every table in a scrollable, keyboard-reachable, named region, so a wide one
    scrolls inside itself instead of pushing the page sideways. Idempotent: a table
    already wrapped is left alone. */
let wrapWideTables: (Dom.element, string) => unit
