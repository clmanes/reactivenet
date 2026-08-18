type day = {
  /** `YYYY-MM-DD`, the way days are stored and compared. */
  date: string,
  number: int,
  /** False for the days either side that fill the first and last weeks. */
  inMonth: bool,
}

let isLeap: int => bool

let daysInMonth: (~year: int, ~month: int) => int

/** 0 is Sunday. */
let weekday: (~year: int, ~month: int, ~day: int) => int

/** The month `by` months away. */
let shift: (~year: int, ~month: int, ~by: int) => (int, int)

/** Six weeks of seven days, padded either side, so the grid keeps its height as the
    reader moves through the year. */
let weeks: (~year: int, ~month: int, ~startsMonday: bool=?) => array<array<day>>

/** The year and month a stored value falls in, when it is a date at all. */
let monthOf: string => option<(int, int)>

/** The day a stored value falls on, written as the grid writes days. */
let dayOf: string => option<string>

/** Whether a day falls inside a span, ends included. */
let covers: (~day: string, ~from: string, ~until: string) => bool

/** The day `by` days away from a written day — pure arithmetic, no Date. */
let shiftDays: (~day: string, ~by: int) => string

/** The seven days of the week `anchor` falls in, all `inMonth`. */
let weekDays: (~anchor: string, ~startsMonday: bool=?) => array<day>
