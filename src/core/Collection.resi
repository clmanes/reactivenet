type field = {
  name: string,
  value: string,
}

type record = {
  id: string,
  fields: array<field>,
}

type t = {records: array<record>}

let empty: t

/** Case-insensitive field lookup within a record. */
let field: (record, string) => option<string>

let find: (t, string) => option<record>

/** Ids come from the caller: generating one needs a clock or randomness, which would
    make this module non-deterministic. */
let insert: (t, record) => t

let remove: (t, string) => t

/** Replaces only the named fields, leaving the rest of the record intact. */
let update: (t, string, array<field>) => t

let size: t => int
let isEmpty: t => bool
