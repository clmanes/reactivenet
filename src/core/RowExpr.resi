/** Bare-name arithmetic over a row's fields — `{qta*prezzo}` in a template,
    `field="qta*prezzo"` in an aggregation. core/Expr with the `#` implied on
    every identifier: one arithmetic, the tested one. A missing field is zero;
    `a-b` is a field name, and subtraction needs spaces. */

/** Cheap first test: contains `+ * / (` or whitespace. */
let looksLike: string => bool

/** Full test: tokenizes and parses, with every field pretending to be 1. */
let parses: string => bool

let evaluate: (string, string => option<string>) => option<float>

/** The field names the expression mentions. */
let references: string => array<string>
