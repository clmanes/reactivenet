/** What an ::api-query answer means: `pick`'s walk into the JSON, and the
    fragment's honest reading as rows — array of objects as rows, object of
    arrays zipped by index, object of scalars as one row or as {key, value}
    pairs, a scalar as no rows at all (the reactive-key form reads those). */

let picked: (JSON.t, string) => option<JSON.t>

/** The scalar the pick landed on, or nothing when it is a structure. */
let scalar: JSON.t => option<string>

/** The fragment as field lists, one per row, or nothing for a bare scalar. */
let rows: (JSON.t, ~pairs: bool) => option<array<array<Collection.field>>>
