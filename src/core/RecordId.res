// Pure. The id a new row gets.
//
// `Collection.insert` deliberately takes an id rather than making one, because
// generating one needs a clock. This is the other half: given the clock's reading and
// the ids already in the collection, it decides the id — so the decision is testable
// and only the timestamp is effectful.

let separator = "-"

/** A timestamp, made unique against the ids already present. */
let make = (~stamp, ~taken) => {
  let base = stamp->String.replaceAllRegExp(RegExp.fromStringWithFlags("[^A-Za-z0-9]", ~flags="g"), "")
  let rec attempt = suffix => {
    let candidate = suffix == 0 ? base : base ++ separator ++ suffix->Int.toString
    taken->Array.includes(candidate) ? attempt(suffix + 1) : candidate
  }
  attempt(0)
}
