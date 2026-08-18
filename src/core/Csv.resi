/** Every field name any row uses, in first-appearance order — a collection has no
    schema, so the header is the union of what is there. */
let columns: array<Collection.record> => array<string>

/** The collection as CSV: header first, ids in their own column so an export can be
    read back as an update of the same rows. */
let encode: Collection.t => string

/** The raw grid a CSV describes, quotes resolved. */
let parse: string => array<array<string>>

/** The rows a CSV describes. A file carrying an `id` column keeps those ids; a file
    without one — the usual spreadsheet — is given fresh ones by `makeId`, which is
    handed the ids already used so it can avoid them. */
let decode: (string, ~makeId: array<string> => string) => array<Collection.record>
