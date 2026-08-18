/** Every icon's drawing, as one lazily loaded chunk. Kept, so asking twice costs
    once. */
let all: unit => promise<Dict.t<array<string>>>

/** Draws the named icon into the host element when the chunk arrives. A name outside
    Spectrum's set draws nothing. */
let draw: (Dom.element, string) => unit
