type labels = {
  showCode: string,
  hideCode: string,
  running: string,
  loading: string,
  /** What the button of a `manual` block says. */
  run: string,
  /** What the button that kills a run in flight says. */
  stop: string,
  /** What the bar says while a run has not told it anything better. */
  progress: string,
}

/** Runs every `::python` block in the container against this app's collections and
    the reactive keys it named in `params`, and writes what comes back underneath it.
    Safe to call after every render: a block whose code, data, packages and parameters
    are unchanged is not run again, and a `manual` block is not run at all until its
    button is pressed. */
let bind: (Dom.element, ~app: string, ~labels: labels) => unit
