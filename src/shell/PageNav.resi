type labels = {pages: string}

/** Builds the menu for the `:::page` containers inside the element, shows one of
    them, and remembers which across re-renders. Does nothing when the document has
    fewer than two pages. */
let bind: (Dom.element, ~labels: labels) => unit
