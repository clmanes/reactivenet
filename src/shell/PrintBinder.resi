type labels = {
  /** What a print button with no label of its own says. */
  print: string,
  /** What one that repeats says. */
  printEach: string,
}

/** Wires every `::print` button in the container: one prints the section whose id it
    names, one with `repeat=` prints that section once per row of a collection, having
    set the named reactive key to each row in turn. `app` may be empty — a document
    opened outside an app can still print a section, and simply has no collections to
    repeat over. */
let bind: (Dom.element, ~app: string, ~labels: labels) => unit
