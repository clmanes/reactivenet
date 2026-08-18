/** Pure. When a workflow is due.

    Everything about time that can be decided without a clock is decided here; the
    shell hands in the readings it cannot — epoch milliseconds for an elapsed
    interval, the local written day and minute for a wall-clock time.

    A tab that is not open runs nothing, so a schedule never means "at 18:00": it
    means the first time the app is open at or after 18:00 on a day it has not
    already run. */

/** The smallest interval a browser will honour. A background tab is throttled to
    about one timer a minute. */
let floor: int

/** "15m", "2h", "1d", "90s", or bare seconds — raised to `floor`. Anything else is
    refused rather than guessed at, which leaves the workflow manual. */
let seconds: string => option<int>

/** "18:00" as minutes since local midnight. Strict. */
let minuteOfDay: string => option<int>

/** The `on=` attribute split into the events it lists. */
let events: string => array<string>

/** The collections whose saved rows start this. */
let saves: string => array<string>

/** The reactive keys that start this, bare — written with or without the `#`. */
let changes: string => array<string>

let opens: string => bool

/** `last` is epoch milliseconds; zero means never. A clock that moved backwards
    counts as due, because waiting for a deadline that has moved out of reach is not
    recoverable. */
let dueEvery: (~last: float, ~now: float, ~seconds: int) => bool

/** Seconds until the next firing; zero when it is due now. */
let remainingEvery: (~last: float, ~now: float, ~seconds: int) => int

/** Local written days, compared as text. Without `catchup`, only within the hour
    after the time. */
let dueAt: (
  ~lastDay: string,
  ~today: string,
  ~nowMinutes: int,
  ~atMinutes: int,
  ~catchup: bool,
) => bool

/** Minutes until the next firing — today's, or tomorrow's. */
let remainingAt: (~ranToday: bool, ~nowMinutes: int, ~atMinutes: int) => int
