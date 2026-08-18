let themeName: Theme.t => string

/** Renders every unprocessed `pre.mermaid` inside the container. Safe to call on
    every preview update — already-rendered diagrams are skipped. */
let run: (Dom.element, ~theme: Theme.t) => unit
