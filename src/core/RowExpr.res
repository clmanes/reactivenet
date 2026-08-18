// Pure. Bare-name arithmetic over a row's own fields: what `{qta*prezzo}` means
// in a list template, and what `field="qta*prezzo"` means in an aggregation.
//
// It is `core/Expr` wearing different names: every bare identifier is prefixed
// with `#` and the same tiny parser evaluates it, so there is exactly one
// arithmetic in this app and it is the tested one. Two consequences an author
// feels:
//
//   - A missing field counts as zero — an invoice line without a quantity is
//     a line worth nothing, not a NaN spreading through the totals.
//   - `a-b` is a FIELD NAME, not a subtraction: hyphens are legal in field
//     names, so telling them apart is impossible without spaces. Subtraction
//     is written `a - b`; anything with `+ * / (` or a space is arithmetic.

let withRefs: string => string = %raw(`
function (source) {
  return source.replace(/[A-Za-z_][A-Za-z0-9_-]*/g, (name) => "#" + name);
}
`)

/** Whether a template token even smells like arithmetic — the cheap test run
    before parsing, and the rule that keeps `{a-b}` a plain field token. */
let looksLike: string => bool = %raw(`
function (candidate) {
  return /[+*\/()]|\s/.test(candidate.trim()) && /[+*\/()\s]/.test(candidate);
}
`)

let evaluate = (source, lookup) => Expr.evaluate(withRefs(source), lookup)

/** Whether the candidate parses as an expression at all — asked with every
    field pretending to be 1, so a division by an empty field does not make a
    well-formed expression look like prose. */
let parses = source => evaluate(source, _ => Some("1"))->Option.isSome

/** The field names the expression reads, for a search to look in. */
let references = source => Expr.references(withRefs(source))
