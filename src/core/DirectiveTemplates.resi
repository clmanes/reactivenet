type t = {
  label: string,
  form: DirectiveScan.form,
  name: string,
  snippet: string,
}

let all: array<t>

/** Appends the snippet as its own block. */
let append: (string, t) => string
