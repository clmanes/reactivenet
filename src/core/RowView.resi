type direction =
  | Ascending
  | Descending

/** Anything but "desc" is ascending: an unrecognised value should order the rows,
    not refuse to. */
let directionOf: string => direction

/** One field's value, or the empty string when the row has no such field. */
let valueOf: (Collection.record, string) => string

/** Numbers as numbers, everything else as text. */
let compare: (string, string) => int

/** Ordered by one field, stably. An empty field name leaves the order alone. */
let sort: (
  array<Collection.record>,
  ~field: string,
  ~direction: direction,
) => array<Collection.record>

/** Every row containing all the words of the query, in any of `fields`. */
let search: (
  array<Collection.record>,
  ~query: string,
  ~fields: array<string>,
) => array<Collection.record>

/** `field=value`, exact and case-insensitive. */
let filter: (array<Collection.record>, ~expression: string) => array<Collection.record>

/** Every filter applied in turn: two filters mean both, not either. */
let filterAll: (array<Collection.record>, ~expressions: array<string>) => array<Collection.record>

/** The distinct values a field holds, ordered, blanks left out — what a reader is
    offered when a column can be filtered. */
let values: (array<Collection.record>, ~field: string) => array<string>

/** At most `count` rows; zero or less means all. */
let limit: (array<Collection.record>, ~count: int) => array<Collection.record>

/** How many pages of `size` rows. Never fewer than one. */
let pageCount: (int, ~size: int) => int

/** One page, with the index clamped into range. */
let page: (array<Collection.record>, ~size: int, ~index: int) => array<Collection.record>

/** Rows gathered by the value of one field, in first-appearance order. */
let groups: (
  array<Collection.record>,
  ~field: string,
) => array<(string, array<Collection.record>)>
