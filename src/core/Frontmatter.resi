type field = {
  key: string,
  value: string,
}

type t = {fields: array<field>}

type document = {
  meta: option<t>,
  /** The markdown with the frontmatter block removed. */
  body: string,
}

/** Reads a `---` delimited block from the very top of the document. Anything that is
    not a well-formed, terminated block is left untouched as body. */
let parse: string => document

/** Case-insensitive field lookup. */
let get: (t, string) => option<string>

let empty: t

/** Updates a field in place, or appends it. Existing keys keep their position. */
let setField: (t, ~key: string, ~value: string) => t

let removeField: (t, ~key: string) => t

/** Renders the block back to markdown, quoting values that YAML would otherwise
    read as a number, date or boolean. An empty block is omitted. */
let serialize: (t, string) => string
