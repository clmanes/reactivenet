// Pure. When a workflow is due.
//
// Everything about time that can be decided without a clock is decided here, and the
// shell hands in the two readings it cannot: the epoch milliseconds for an elapsed
// interval, and the *local* day and minute for a wall-clock time. That split is not
// tidiness — it is the rule the calendar already follows. `new Date("2026-08-10")` is
// midnight UTC and lands on the ninth west of Greenwich, so a workflow asked to run
// at 18:00 has to be told what the local 18:00 is rather than parsing an instant and
// hoping.
//
// One promise runs through the whole module, and it is smaller than the word
// *automation* suggests: **a browser tab that is not open runs nothing.** There is no
// server here and the service worker precaches, it does not execute. So a schedule
// cannot mean "at 18:00"; it means "the first time the app is open at or after 18:00
// on a day it has not already run". `catchup` is how the author says which of the two
// readings of *that* they want — the whole evening, or the hour after.
//
// Hence the floor, too: a background tab is throttled to about one timer a minute and
// a discarded one to none at all, so `every="10s"` would be a promise the browser
// refuses to keep. It is raised to a minute rather than accepted and quietly missed,
// which is the same decision `::api-query{every}` already made about rate limits.

let floor = 60

let ceilingOfDay = 1440

// "15m", "2h", "1d", "90s", or bare seconds. Anything else is not a schedule, and a
// schedule nobody can read is better refused than guessed at — an unparsed attribute
// leaves the workflow manual, which is the safe half.
let seconds = (given: string): option<int> => {
  let text = given->String.trim->String.toLowerCase
  let size = text->String.length
  if size == 0 {
    None
  } else {
    let unit = text->String.slice(~start=size - 1, ~end=size)
    let (digits, factor) = switch unit {
    | "s" => (text->String.slice(~start=0, ~end=size - 1), 1)
    | "m" => (text->String.slice(~start=0, ~end=size - 1), 60)
    | "h" => (text->String.slice(~start=0, ~end=size - 1), 3600)
    | "d" => (text->String.slice(~start=0, ~end=size - 1), 86400)
    | _ => (text, 1)
    }
    switch Numeric.parse(digits->String.trim) {
    | Some(value) if value > 0.0 =>
      let asked = value *. Int.toFloat(factor)
      // A year of seconds is not a schedule anybody meant; refusing it beats holding
      // a timer nothing will ever fire.
      if asked > 31536000.0 {
        None
      } else {
        Some(Math.Int.max(floor, Float.toInt(asked)))
      }
    | _ => None
    }
  }
}

// "18:00" as minutes since local midnight. Strict on purpose: "18" alone, "6pm" and
// "18:00:00" are all things somebody might mean and none of them is what this reads,
// so each is refused rather than turned into a time that is nearly right.
let minuteOfDay = (given: string): option<int> => {
  let text = given->String.trim
  switch text->String.split(":") {
  | [hours, minutes] =>
    let whole = value =>
      String.length(value) == 2 || String.length(value) == 1
        ? Numeric.parse(value)->Option.flatMap(number =>
            number >= 0.0 && Math.trunc(number) == number ? Some(Float.toInt(number)) : None
          )
        : None
    switch (whole(hours), whole(minutes)) {
    | (Some(hour), Some(minute)) if hour < 24 && minute < 60 => Some(hour * 60 + minute)
    | _ => None
    }
  | _ => None
  }
}

// `on="save:spese, change:#regione, open"` — one attribute carrying the events,
// because they are one question ("what starts this") asked once. The prefixes are
// what keep a collection and a reactive key apart, which is the `#ref`-versus-bare-id
// rule of the whole app written for events.
let events = (given: string): array<string> =>
  given
  ->String.split(",")
  ->Array.map(String.trim)
  ->Array.filter(entry => entry != "")

let prefixed = (given: string, prefix: string): array<string> =>
  events(given)
  ->Array.filter(entry => entry->String.startsWith(prefix))
  ->Array.map(entry =>
    entry->String.slice(~start=String.length(prefix), ~end=String.length(entry))->String.trim
  )
  ->Array.filter(entry => entry != "")

/** The collections whose saved rows start this. */
let saves = (given: string): array<string> => prefixed(given, "save:")

/** The reactive keys that start this. The `#` is optional in the event because the
    prefix already says which of the two it is; both spellings arrive as the bare key,
    which is what `ReactiveStore.subscribe` reports. */
let changes = (given: string): array<string> =>
  prefixed(given, "change:")->Array.map(key =>
    key->String.startsWith("#") ? key->String.slice(~start=1, ~end=String.length(key)) : key
  )

let opens = (given: string): bool =>
  events(given)->Array.some(entry => entry == "open")

// `last` is epoch milliseconds and zero means never. A float, not an int: ReScript's
// int is JavaScript's 32-bit one and an epoch in milliseconds passed 2^31 in 1970 + 25
// days — the overflow would be silent and the workflow would think it had never run.
let dueEvery = (~last: float, ~now: float, ~seconds: int): bool =>
  // Never run, or the clock moved backwards under us — a time-zone change, an NTP
  // correction, a laptop waking with a wrong clock. Running once is the recoverable
  // answer; waiting for a deadline that has moved out of reach is not.
  last <= 0.0 || now < last || now -. last >= Int.toFloat(seconds) *. 1000.0

let remainingEvery = (~last: float, ~now: float, ~seconds: int): int => {
  let elapsed = (now -. last) /. 1000.0
  let left = Int.toFloat(seconds) -. elapsed
  last <= 0.0 || now < last || left <= 0.0 ? 0 : Float.toInt(Math.ceil(left))
}

/** `lastDay` and `today` are local written days, "YYYY-MM-DD" — compared as text,
    which is what makes this free of any parsed instant.

    Without `catchup` the workflow fires only in the hour after its time: opening the
    app at eleven at night and watching last evening's update run is surprising, and
    surprise is the one thing a schedule may not produce. With it, any time that day
    still counts — which is what somebody who leaves the app closed all morning
    actually wants. */
let dueAt = (
  ~lastDay: string,
  ~today: string,
  ~nowMinutes: int,
  ~atMinutes: int,
  ~catchup: bool,
): bool =>
  if lastDay == today || nowMinutes < atMinutes {
    false
  } else {
    catchup || nowMinutes - atMinutes <= 60
  }

/** Minutes until the next firing — today's if it has not passed and the workflow has
    not already run, otherwise tomorrow's. */
let remainingAt = (~ranToday: bool, ~nowMinutes: int, ~atMinutes: int): int =>
  !ranToday && nowMinutes < atMinutes
    ? atMinutes - nowMinutes
    : ceilingOfDay - nowMinutes + atMinutes
