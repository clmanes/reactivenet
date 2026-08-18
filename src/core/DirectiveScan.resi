type form =
  | Inline
  | Leaf
  | Container

type occurrence = {
  form: form,
  name: string,
  label: string,
  attributes: string,
  /** Absolute offsets into the scanned source. */
  start: int,
  stop: int,
}

/** Finds every directive, in document order. A container reports its whole span,
    body included, and its body is not scanned again as top level.

    A block is a container when a `::/name` closes it and a leaf when nothing does —
    the two are written identically, which is what removes the need to count. */
let scan: string => array<occurrence>

/** Renders a directive's opening in the shape it was read. A container also needs
    `closing`. */
let render: (~form: form, ~name: string, ~label: string, ~attributes: string) => string

/** The line that closes a container `render` opened. */
let closing: (~name: string) => string

let replace: (string, occurrence, string) => string

/** Removes the directive. For a container this removes the body it wrapped. */
let remove: (string, occurrence) => string
