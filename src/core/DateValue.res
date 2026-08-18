// Pure. Which stored strings are dates.
//
// A collection stores strings and nothing else — a row has no types — so the only
// way to know that `2026-08-10T13:10:34.324Z` is a moment and `2026 rows` is not is
// to look at the shape. The recogniser is deliberately strict: it accepts exactly
// what this app writes (`Clock.timestamp`) and what an `<input type="date">` or
// `type="datetime-local"` produces, and nothing else. Anything looser would start
// reformatting text an author typed on purpose.
//
// Formatting itself is not here: it depends on the reader's time zone and on the
// runtime's locale data, neither of which belongs in a total function.

type t =
  /** A whole day: no time, so no time zone can shift it. */
  | Day
  /** A moment. */
  | Moment

let dayPattern = "^\\d{4}-\\d{2}-\\d{2}$"
let momentPattern = "^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}(?::\\d{2}(?:\\.\\d{1,6})?)?(?:Z|[+-]\\d{2}:\\d{2})?$"

let inRange = (value, ~from, ~to_) =>
  switch value->Int.fromString {
  | Some(number) => number >= from && number <= to_
  | None => false
  }

// The shape is not enough: `2026-13-40` matches the pattern and is not a date. The
// check is on the written fields rather than on `Date`, which silently rolls a
// thirteenth month over into January.
let plausible = value => {
  let month = value->String.slice(~start=5, ~end=7)
  let day = value->String.slice(~start=8, ~end=10)
  month->inRange(~from=1, ~to_=12) && day->inRange(~from=1, ~to_=31)
}

/** What this value is, if it is a date at all. */
let classify = value => {
  let trimmed = value->String.trim
  if !plausible(trimmed) {
    None
  } else if RegExp.test(RegExp.fromString(dayPattern), trimmed) {
    Some(Day)
  } else if RegExp.test(RegExp.fromString(momentPattern), trimmed) {
    Some(Moment)
  } else {
    None
  }
}

let isDate = value => classify(value)->Option.isSome
