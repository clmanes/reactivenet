type t = {
  name: string,
  value: string,
}

/** Parses `name="value"` pairs. A bare `name` is a flag and reads as "true". */
let parse: string => array<t>

/** Case-insensitive lookup, like an HTML attribute. */
let find: (array<t>, string) => option<string>

/** Parse and look up in one step. */
let attribute: (string, string) => option<string>

/** Renders the pairs back, always double-quoted. */
let serialize: array<t> => string

/** Updates in place or appends, preserving order. */
let set: (array<t>, ~name: string, ~value: string) => array<t>
