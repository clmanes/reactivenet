// Pure. Whether a stored value is a number, and which one.
//
// A collection carries no types: every value is the string somebody typed. So "is
// this a number" gets asked constantly — by the aggregations, by a sort, by an
// expression reading a key — and the obvious answer is wrong. `Float.fromString` is
// `parseFloat`, which reads a numeric *prefix* and stops: it makes
// "2026-08-10T17:50:45.880Z" the number 2026 and "10 items" the number 10.
//
// The cost of that was silent. `::list{sort="createdAt" dir="desc"}` compared every
// row as the year 2026, found them all equal and left them in the order they were
// stored — a sort that looked like it had simply not been applied. An aggregation
// over a date field would have averaged years the same way.
//
// A stored value is a number only when the whole of it is one.

// Deliberately not `Infinity` or `NaN`: those are JavaScript spellings, not values
// anyone types into a form, and neither belongs in a total.
let pattern = RegExp.fromString("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$")

let parse = value => {
  let trimmed = value->String.trim
  RegExp.test(pattern, trimmed) ? Float.fromString(trimmed) : None
}

let isNumber = value => parse(value)->Option.isSome
