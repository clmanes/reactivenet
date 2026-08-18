// Pure. What a view shows of a collection, and in what order.
//
// A list and a table differ in how they draw a row, not in which rows they draw, so
// searching, filtering, sorting, grouping and paging are decided once here and both
// binders ask the same questions. Everything works on the *stored strings*, because
// that is all a row has — a collection carries no types.

type direction =
  | Ascending
  | Descending

let directionOf = value =>
  switch value->String.trim->String.toLowerCase {
  | "desc" | "descending" => Descending
  | _ => Ascending
  }

let valueOf = (record: Collection.record, field) =>
  Collection.field(record, field)->Option.getOr("")

// Numbers compare as numbers and everything else as text, because "10" before "9" is
// wrong in a column of prices and right in nothing. A value that is not a number is
// not coerced to one: the comparison simply falls back to text for that pair — and
// "number" means the whole value, or a column of ISO timestamps would compare as the
// year they all share. See `Numeric`.
let compare = (left, right) =>
  switch (Numeric.parse(left), Numeric.parse(right)) {
  | (Some(a), Some(b)) => a < b ? -1 : a > b ? 1 : 0
  // Numbers sort before everything that is not one. Falling back to text for a
  // mixed pair — the previous rule — was not transitive: "10" < "5" as text but
  // 10 > 5 as numbers, so which won depended on what each was compared against,
  // and an unstable comparator hands the sort undefined behaviour.
  | (Some(_), None) => -1
  | (None, Some(_)) => 1
  | (None, None) =>
    let a = left->String.toLowerCase
    let b = right->String.toLowerCase
    a < b ? -1 : a > b ? 1 : 0
  }

/** Ordered by one field. Stable, so rows that tie keep the order they were stored
    in — which for a collection is the order they were created. */
let sort = (records, ~field, ~direction) =>
  field == ""
    ? records
    : records->Array.toSorted((a, b) => {
        let result = compare(valueOf(a, field), valueOf(b, field))
        (direction == Descending ? -result : result)->Int.toFloat
      })

/** Every row containing all the words of the query, in any of `fields`. Matching from
    the middle is what makes "voti" find "registro-voti", and every word must match
    something so a second word narrows rather than widens. */
let search = (records, ~query, ~fields) => {
  let words =
    query->String.toLowerCase->String.split(" ")->Array.filter(word => word->String.trim != "")
  words->Array.length == 0
    ? records
    : records->Array.filter(record => {
        let haystack =
          fields->Array.map(field => valueOf(record, field)->String.toLowerCase)->Array.join(" ")
        words->Array.every(word => haystack->String.includes(word))
      })
}

/** `field=value`, matched exactly and case-insensitively. Deliberately not an
    expression language: a filter that needed parsing would be a second `Expr`, and
    what a view needs is to show one person's rows or one category's. */
let filter = (records, ~expression) =>
  switch expression->String.indexOf("=") {
  | -1 => records
  | at =>
    let field = expression->String.slice(~start=0, ~end=at)->String.trim
    let wanted =
      expression
      ->String.slice(~start=at + 1, ~end=String.length(expression))
      ->String.trim
      ->String.toLowerCase
    field == ""
      ? records
      : records->Array.filter(record => valueOf(record, field)->String.toLowerCase == wanted)
  }

/** Every filter, one after another: a reader narrowing by two columns means both,
    not either. An empty expression narrows nothing, so a filter nobody has set is
    simply not a filter. */
let filterAll = (records, ~expressions) =>
  expressions->Array.reduce(records, (rows, expression) => filter(rows, ~expression))

/** The distinct values a field holds, in the order a reader would look for them:
    numbers as numbers, everything else as text. Blanks are left out — "no value" is
    not a value to choose, it is what choosing nothing already means. */
let values = (records, ~field) =>
  records
  ->Array.reduce([], (found, record) => {
    let value = valueOf(record, field)
    value == "" || found->Array.includes(value) ? found : found->Array.concat([value])
  })
  ->Array.toSorted((a, b) => compare(a, b)->Int.toFloat)

/** At most this many rows. Zero or less means all of them. */
let limit = (records, ~count) =>
  count <= 0 ? records : records->Array.slice(~start=0, ~end=count)

/** How many pages `size` rows make. Always at least one: an empty collection is one
    empty page, not zero pages, or the pager would have nothing to say. */
let pageCount = (total, ~size) =>
  if size <= 0 {
    1
  } else {
    let whole = total / size
    let counted = total > whole * size ? whole + 1 : whole
    counted < 1 ? 1 : counted
  }

/** One page, clamped: a page index left over from a longer list lands on the last
    page rather than on nothing. */
let page = (records, ~size, ~index) =>
  if size <= 0 {
    records
  } else {
    let last = pageCount(records->Array.length, ~size) - 1
    let wanted = index < 0 ? 0 : index > last ? last : index
    records->Array.slice(~start=wanted * size, ~end=(wanted + 1) * size)
  }

/** Rows gathered under the value of one field, in the order those values first
    appear. Rows with no value for it are grouped under the empty string, which the
    caller renders however it names "the rest". */
let groups = (records, ~field) =>
  field == ""
    ? [("", records)]
    : records->Array.reduce([], (gathered, record) => {
        let key = valueOf(record, field)
        switch gathered->Array.findIndex(((name, _)) => name == key) {
        | -1 => gathered->Array.concat([(key, [record])])
        | at =>
          gathered->Array.mapWithIndex(((name, rows), index) =>
            index == at ? (name, rows->Array.concat([record])) : (name, rows)
          )
        }
      })
