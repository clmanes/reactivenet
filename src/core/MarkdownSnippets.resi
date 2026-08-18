type t = {
  label: string,
  detail: string,
  insert: string,
  /** Caret position inside `insert`, in characters from its start. */
  caret: int,
}

let all: array<t>

/** Case-insensitive prefix match; an empty prefix returns everything. */
let matching: string => array<t>
