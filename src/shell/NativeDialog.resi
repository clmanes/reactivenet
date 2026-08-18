/** Keeps a native `<dialog>` in step with `open_`, and returns the cleanup. */
let follow: (Dom.element, ~open_: bool, ~onDismiss: unit => unit) => option<unit => unit>
