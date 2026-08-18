/** Publishes `node`'s height as the CSS custom property `property` on the document
    element, keeping it current while the node changes shape. Returns the function
    that stops observing and removes the property. */
let track: (Dom.element, string) => unit => unit
