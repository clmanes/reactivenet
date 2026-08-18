// Pure. The calendar arithmetic a month view needs, without a Date in sight.
//
// `new Date("2026-08-10")` is midnight UTC, which is the ninth of August in every
// time zone west of Greenwich — the bug this app already fixed once when showing a
// stored day. A grid built from parsed instants would bring it straight back, so the
// arithmetic is done on the written fields: a year, a month and a day are three
// integers, and the rules connecting them have not changed since 1582.

type day = {
  /** The day as it is stored and compared: `YYYY-MM-DD`. */
  date: string,
  number: int,
  /** False for the days either side that fill the first and last weeks. */
  inMonth: bool,
}

let isLeap = year => mod(year, 4) == 0 && (mod(year, 100) != 0 || mod(year, 400) == 0)

let daysInMonth = (~year, ~month) =>
  switch month {
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
  | 4 | 6 | 9 | 11 => 30
  | 2 => isLeap(year) ? 29 : 28
  | _ => 0
  }

// Sakamoto's method: 0 is Sunday. Small, exact, and it needs nothing but the three
// numbers it is given.
let weekdayTable = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]

let weekday = (~year, ~month, ~day) => {
  let y = month < 3 ? year - 1 : year
  let shift = weekdayTable->Array.get(month - 1)->Option.getOr(0)
  mod(y + y / 4 - y / 100 + y / 400 + shift + day, 7)
}

let pad = value => value < 10 ? "0" ++ value->Int.toString : value->Int.toString

let iso = (~year, ~month, ~day) =>
  year->Int.toString ++ "-" ++ pad(month) ++ "-" ++ pad(day)

/** The month `by` months away, as a year and a month. */
let shift = (~year, ~month, ~by) => {
  let total = year * 12 + (month - 1) + by
  let wrapped = mod(total, 12)
  let normalised = wrapped < 0 ? wrapped + 12 : wrapped
  ((total - normalised) / 12, normalised + 1)
}

/** The month as six weeks of seven days, the first and last padded with the days
    either side. Six always, so the grid does not change height as the reader moves
    through the year — a calendar that reflows every month is a calendar you have to
    find your place in again.

    `startsMonday` is the week most of this app's languages begin with; Sunday is
    offered because some of them do not. */
let weeks = (~year, ~month, ~startsMonday=true) => {
  let first = weekday(~year, ~month, ~day=1)
  // How many days of the previous month the first row shows.
  let lead = startsMonday ? mod(first + 6, 7) : first
  let (previousYear, previousMonth) = shift(~year, ~month, ~by=-1)
  let (nextYear, nextMonth) = shift(~year, ~month, ~by=1)
  let inThis = daysInMonth(~year, ~month)
  let inPrevious = daysInMonth(~year=previousYear, ~month=previousMonth)

  Array.make(~length=6, 0)->Array.mapWithIndex((_, week) =>
    Array.make(~length=7, 0)->Array.mapWithIndex((_, index) => {
      let offset = week * 7 + index - lead
      if offset < 0 {
        let number = inPrevious + offset + 1
        {
          date: iso(~year=previousYear, ~month=previousMonth, ~day=number),
          number,
          inMonth: false,
        }
      } else if offset < inThis {
        let number = offset + 1
        {date: iso(~year, ~month, ~day=number), number, inMonth: true}
      } else {
        let number = offset - inThis + 1
        {date: iso(~year=nextYear, ~month=nextMonth, ~day=number), number, inMonth: false}
      }
    })
  )
}

/** The year and month a stored value falls in, when it is a date at all. Only the
    written prefix is read, so a timestamp lands on the day it was written in — the
    same rule `DateValue` follows. */
let monthOf = value =>
  switch DateValue.classify(value) {
  | None => None
  | Some(_) =>
    switch (
      value->String.slice(~start=0, ~end=4)->Int.fromString,
      value->String.slice(~start=5, ~end=7)->Int.fromString,
    ) {
    | (Some(year), Some(month)) => Some((year, month))
    | _ => None
    }
  }

/** The day a stored value falls on, as the grid writes days. */
let dayOf = value =>
  switch DateValue.classify(value) {
  | None => None
  | Some(_) => Some(value->String.slice(~start=0, ~end=10))
  }

/** Whether a day falls inside a span, ends included. Written days compare as text —
    that is the whole reason they are stored `YYYY-MM-DD` — so this needs no
    arithmetic and no iteration: a span of ten years costs the same as a span of one
    day. A span whose end is before its start covers only its start, because the other
    reading is that somebody typed the dates the wrong way round and lost the row. */
let covers = (~day, ~from, ~until) =>
  until == "" || until < from ? day == from : from <= day && day <= until

// Written days as plain counts, for the week view's arithmetic: the civil
// algorithm (Howard Hinnant's), pure integer work with no Date and no zone —
// `new Date("2026-08-10")` is midnight UTC and lands on the ninth west of
// Greenwich, which is the bug this module exists to avoid.
let serialOf = date =>
  switch dayOf(date) {
  | None => None
  | Some(written) => {
      let year = written->String.slice(~start=0, ~end=4)->Int.fromString->Option.getOr(0)
      let month = written->String.slice(~start=5, ~end=7)->Int.fromString->Option.getOr(1)
      let d = written->String.slice(~start=8, ~end=10)->Int.fromString->Option.getOr(1)
      let y = month <= 2 ? year - 1 : year
      let era = (y >= 0 ? y : y - 399) / 400
      let yoe = y - era * 400
      let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + d - 1
      let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
      Some(era * 146097 + doe - 719468)
    }
  }

let dateOf = serial => {
  let shifted = serial + 719468
  let era = (shifted >= 0 ? shifted : shifted - 146096) / 146097
  let doe = shifted - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = mp + (mp < 10 ? 3 : -9)
  let year = m <= 2 ? y + 1 : y
  iso(~year, ~month=m, ~day=d)
}

/** The day `by` days away from a written day. */
let shiftDays = (~day, ~by) =>
  switch serialOf(day) {
  | None => day
  | Some(serial) => dateOf(serial + by)
  }

/** The seven days of the week `anchor` falls in. All `inMonth`: a week view has
    no padding days. */
let weekDays = (~anchor, ~startsMonday=true) =>
  switch serialOf(anchor) {
  | None => []
  | Some(serial) => {
      // Serial 0 is 1970-01-01, a Thursday: weekday 4, with 0 as Sunday.
      let weekdayOf = s => mod(mod(s + 4, 7) + 7, 7)
      let start = startsMonday
        ? serial - mod(weekdayOf(serial) + 6, 7)
        : serial - weekdayOf(serial)
      Array.fromInitializer(~length=7, offset => {
        let date = dateOf(start + offset)
        {
          date,
          number: date->String.slice(~start=8, ~end=10)->Int.fromString->Option.getOr(1),
          inMonth: true,
        }
      })
    }
  }
