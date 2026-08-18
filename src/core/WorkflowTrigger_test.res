open BunTest

let minute = 60000.0

describe("WorkflowTrigger.seconds", () => {
  test("the units an author writes", () => {
    expect(WorkflowTrigger.seconds("15m"))->toEqual(Some(900))
    expect(WorkflowTrigger.seconds("2h"))->toEqual(Some(7200))
    expect(WorkflowTrigger.seconds("1d"))->toEqual(Some(86400))
    expect(WorkflowTrigger.seconds("90s"))->toEqual(Some(90))
  })

  test("bare digits are seconds", () => {
    expect(WorkflowTrigger.seconds("300"))->toEqual(Some(300))
  })

  // The floor is the feature, not a nuisance: a background tab is throttled to about
  // one timer a minute, so anything faster is a promise the browser will not keep.
  test("anything under a minute is raised to one", () => {
    expect(WorkflowTrigger.seconds("10s"))->toEqual(Some(60))
    expect(WorkflowTrigger.seconds("1"))->toEqual(Some(60))
  })

  test("what is not a schedule is refused rather than guessed at", () => {
    expect(WorkflowTrigger.seconds(""))->toEqual(None)
    expect(WorkflowTrigger.seconds("presto"))->toEqual(None)
    expect(WorkflowTrigger.seconds("0"))->toEqual(None)
    expect(WorkflowTrigger.seconds("-5m"))->toEqual(None)
    expect(WorkflowTrigger.seconds("100y"))->toEqual(None)
  })

  test("spacing and case do not change the answer", () => {
    expect(WorkflowTrigger.seconds("  15M "))->toEqual(Some(900))
  })
})

describe("WorkflowTrigger.minuteOfDay", () => {
  test("a written time as minutes since local midnight", () => {
    expect(WorkflowTrigger.minuteOfDay("18:00"))->toEqual(Some(1080))
    expect(WorkflowTrigger.minuteOfDay("00:00"))->toEqual(Some(0))
    expect(WorkflowTrigger.minuteOfDay("8:05"))->toEqual(Some(485))
  })

  // Each of these is something somebody might mean and none is what this reads, so
  // each is refused rather than turned into a time that is nearly right.
  test("what is nearly a time is not one", () => {
    expect(WorkflowTrigger.minuteOfDay("18"))->toEqual(None)
    expect(WorkflowTrigger.minuteOfDay("6pm"))->toEqual(None)
    expect(WorkflowTrigger.minuteOfDay("18:00:00"))->toEqual(None)
    expect(WorkflowTrigger.minuteOfDay("24:00"))->toEqual(None)
    expect(WorkflowTrigger.minuteOfDay("18:60"))->toEqual(None)
    expect(WorkflowTrigger.minuteOfDay(""))->toEqual(None)
  })
})

describe("WorkflowTrigger events", () => {
  test("the collections a save starts it from", () => {
    expect(WorkflowTrigger.saves("save:spese, save:fatture")->Array.join(","))->toBe(
      "spese,fatture",
    )
  })

  // The prefix already says which of the two it is, so both spellings arrive as the
  // bare key — which is what ReactiveStore.subscribe reports.
  test("a key is bare whether or not it was written with its hash", () => {
    expect(WorkflowTrigger.changes("change:#regione, change:anno")->Array.join(","))->toBe(
      "regione,anno",
    )
  })

  test("open is its own event", () => {
    expect(WorkflowTrigger.opens("open"))->toBe(true)
    expect(WorkflowTrigger.opens("save:spese"))->toBe(false)
  })

  test("events of one kind do not answer for another", () => {
    expect(WorkflowTrigger.saves("change:#regione")->Array.length)->toBe(0)
  })
})

describe("WorkflowTrigger.dueEvery", () => {
  test("never run is due", () => {
    expect(WorkflowTrigger.dueEvery(~last=0.0, ~now=1000.0, ~seconds=900))->toBe(true)
  })

  test("due once the interval has passed", () => {
    let last = 1000000.0
    expect(WorkflowTrigger.dueEvery(~last, ~now=last +. 14.0 *. minute, ~seconds=900))->toBe(false)
    expect(WorkflowTrigger.dueEvery(~last, ~now=last +. 15.0 *. minute, ~seconds=900))->toBe(true)
  })

  // A time-zone change, an NTP correction, a laptop waking with a wrong clock. Running
  // once is recoverable; waiting for a deadline that has moved out of reach is not.
  test("a clock that moved backwards is due rather than stuck", () => {
    expect(WorkflowTrigger.dueEvery(~last=1000000.0, ~now=500000.0, ~seconds=900))->toBe(true)
  })
})

describe("WorkflowTrigger.remainingEvery", () => {
  test("what is left of the interval", () => {
    let last = 1000000.0
    expect(WorkflowTrigger.remainingEvery(~last, ~now=last +. 5.0 *. minute, ~seconds=900))->toBe(
      600,
    )
  })

  test("nothing left when it is due", () => {
    expect(WorkflowTrigger.remainingEvery(~last=0.0, ~now=1000.0, ~seconds=900))->toBe(0)
  })
})

describe("WorkflowTrigger.dueAt", () => {
  let today = "2026-08-17"

  test("due at its time on a day it has not run", () => {
    expect(
      WorkflowTrigger.dueAt(
        ~lastDay="2026-08-16",
        ~today,
        ~nowMinutes=1080,
        ~atMinutes=1080,
        ~catchup=false,
      ),
    )->toBe(true)
  })

  test("not before its time", () => {
    expect(
      WorkflowTrigger.dueAt(
        ~lastDay="2026-08-16",
        ~today,
        ~nowMinutes=1079,
        ~atMinutes=1080,
        ~catchup=false,
      ),
    )->toBe(false)
  })

  test("not twice in one day", () => {
    expect(
      WorkflowTrigger.dueAt(
        ~lastDay=today,
        ~today,
        ~nowMinutes=1200,
        ~atMinutes=1080,
        ~catchup=false,
      ),
    )->toBe(false)
  })

  // Opening the app at eleven at night and watching the evening update run is
  // surprising, and surprise is the one thing a schedule may not produce.
  test("without catchup the window closes after an hour", () => {
    let late = (~catchup) =>
      WorkflowTrigger.dueAt(
        ~lastDay="2026-08-16",
        ~today,
        ~nowMinutes=1380,
        ~atMinutes=1080,
        ~catchup,
      )
    expect(late(~catchup=false))->toBe(false)
    expect(late(~catchup=true))->toBe(true)
  })
})

describe("WorkflowTrigger.remainingAt", () => {
  test("today's, when it has not passed", () => {
    expect(WorkflowTrigger.remainingAt(~ranToday=false, ~nowMinutes=1000, ~atMinutes=1080))->toBe(
      80,
    )
  })

  test("tomorrow's, once it has run", () => {
    expect(WorkflowTrigger.remainingAt(~ranToday=true, ~nowMinutes=1100, ~atMinutes=1080))->toBe(
      1420,
    )
  })

  test("tomorrow's, once the time has passed", () => {
    expect(WorkflowTrigger.remainingAt(~ranToday=false, ~nowMinutes=1200, ~atMinutes=1080))->toBe(
      1320,
    )
  })
})
