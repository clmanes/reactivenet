// Pure. Summarising one field of a collection.
//
// Everything here works on the *stored* strings, because that is what a collection
// holds: a value that does not read as a number is not counted rather than counted as
// zero. Those are different answers — an average over three rows where one field was
// left blank is an average of two — and the second is the one people mean.

type kind =
  | Count
  | Sum
  | Average
  | Minimum
  | Maximum
  | Median
  | Deviation
  | Mode

let parse = name =>
  switch name {
  | "count" => Some(Count)
  | "sum" => Some(Sum)
  | "avg" => Some(Average)
  | "min" => Some(Minimum)
  | "max" => Some(Maximum)
  | "median" => Some(Median)
  | "stddev" => Some(Deviation)
  | "mode" => Some(Mode)
  | _ => None
  }

let values = (collection: Collection.t, field) =>
  collection.records->Array.filterMap(record => Collection.field(record, field))

// `field` may also be row arithmetic — `field="qta*prezzo"` totals an invoice
// with no Python anywhere. Same rules as the `{qta*prezzo}` template token:
// missing fields are zero, a row whose expression has no answer is not counted.
let numbers = (collection: Collection.t, field) =>
  RowExpr.looksLike(field) && RowExpr.parses(field)
    ? collection.records->Array.filterMap(record =>
        RowExpr.evaluate(field, name => Collection.field(record, name))
      )
    : values(collection, field)->Array.filterMap(Numeric.parse)

let sorted = numbers => numbers->Array.toSorted(Float.compare)

let sum = numbers => numbers->Array.reduce(0.0, (total, value) => total +. value)

let average = numbers =>
  Array.length(numbers) == 0 ? None : Some(sum(numbers) /. Int.toFloat(Array.length(numbers)))

let median = numbers => {
  let ordered = sorted(numbers)
  let size = Array.length(ordered)
  if size == 0 {
    None
  } else if mod(size, 2) == 1 {
    ordered->Array.at(size / 2)
  } else {
    switch (ordered->Array.at(size / 2 - 1), ordered->Array.at(size / 2)) {
    | (Some(low), Some(high)) => Some((low +. high) /. 2.0)
    | _ => None
    }
  }
}

// Sample deviation, the n-1 form Excel's STDEV uses: with fewer than two values there
// is no spread to report, and zero would claim there was.
let deviation = numbers => {
  let size = Array.length(numbers)
  switch (size < 2, average(numbers)) {
  | (true, _) | (_, None) => None
  | (false, Some(mean)) =>
    let total =
      numbers->Array.reduce(0.0, (acc, value) => acc +. (value -. mean) *. (value -. mean))
    Some(Math.sqrt(total /. Int.toFloat(size - 1)))
  }
}

// Works on text too — "the best-selling product" is a mode, not a number. Ties go to
// whichever was seen first, which keeps the answer stable as rows are added.
let mode = strings =>
  strings->Array.reduce(None, (best, candidate) => {
    let count = value => strings->Array.filter(other => other == value)->Array.length
    switch best {
    | None => Some(candidate)
    | Some(current) => count(candidate) > count(current) ? Some(candidate) : Some(current)
    }
  })

// Numbers are shown the way they were meant rather than the way floating point stores
// them: an integer prints without a decimal point, and anything else is trimmed of the
// zeros that division leaves behind.
let format = (value, ~decimals=?) =>
  switch decimals {
  | Some(places) => value->Float.toFixed(~digits=places)
  | None =>
    let rounded = value->Float.toFixed(~digits=4)
    let trimmed =
      rounded->String.includes(".")
        ? rounded
          ->String.replaceRegExp(RegExp.fromString("0+$"), "")
          ->String.replaceRegExp(RegExp.fromString("\\.$"), "")
        : rounded
    trimmed == "-0" ? "0" : trimmed
  }

/** The value to display, already formatted. `None` when there is nothing to say —
    an empty collection has no average, and an em dash is more honest than a zero. */
let compute = (kind, collection, ~field="", ~decimals=?) =>
  switch kind {
  | Count => Some(collection.Collection.records->Array.length->Int.toString)
  | Mode => mode(values(collection, field))
  | Sum => Some(format(sum(numbers(collection, field)), ~decimals?))
  | Average => average(numbers(collection, field))->Option.map(v => format(v, ~decimals?))
  | Median => median(numbers(collection, field))->Option.map(v => format(v, ~decimals?))
  | Deviation => deviation(numbers(collection, field))->Option.map(v => format(v, ~decimals?))
  | Minimum =>
    sorted(numbers(collection, field))->Array.at(0)->Option.map(v => format(v, ~decimals?))
  | Maximum =>
    sorted(numbers(collection, field))->Array.last->Option.map(v => format(v, ~decimals?))
  }
