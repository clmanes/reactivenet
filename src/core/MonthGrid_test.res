open BunTest

describe("MonthGrid arithmetic", () => {
  test("knows its leap years, exceptions included", () => {
    expect(MonthGrid.isLeap(2024))->toBe(true)
    expect(MonthGrid.isLeap(2026))->toBe(false)
    expect(MonthGrid.isLeap(1900))->toBe(false)
    expect(MonthGrid.isLeap(2000))->toBe(true)
    expect(MonthGrid.daysInMonth(~year=2024, ~month=2))->toBe(29)
    expect(MonthGrid.daysInMonth(~year=2026, ~month=2))->toBe(28)
  })

  test("names the weekday of a known day", () => {
    // 11 August 2026 is a Tuesday; 1 January 2000 was a Saturday.
    expect(MonthGrid.weekday(~year=2026, ~month=8, ~day=11))->toBe(2)
    expect(MonthGrid.weekday(~year=2000, ~month=1, ~day=1))->toBe(6)
  })

  test("moves through the year, and over its edges", () => {
    expect(MonthGrid.shift(~year=2026, ~month=8, ~by=1))->toEqual((2026, 9))
    expect(MonthGrid.shift(~year=2026, ~month=12, ~by=1))->toEqual((2027, 1))
    expect(MonthGrid.shift(~year=2026, ~month=1, ~by=-1))->toEqual((2025, 12))
    expect(MonthGrid.shift(~year=2026, ~month=3, ~by=-14))->toEqual((2025, 1))
  })
})

describe("MonthGrid.weeks", () => {
  let grid = MonthGrid.weeks(~year=2026, ~month=8)

  // Six always: a grid that changed height as the reader moved through the year
  // would move everything under it every month.
  test("is always six weeks of seven days", () => {
    expect(grid->Array.length)->toBe(6)
    expect(grid->Array.every(week => week->Array.length == 7))->toBe(true)
  })

  test("starts the week on Monday and fills the edges from the months either side", () => {
    let first = grid->Array.getUnsafe(0)
    // 1 August 2026 is a Saturday, so the row opens on 27 July.
    expect((first->Array.getUnsafe(0)).date)->toBe("2026-07-27")
    expect((first->Array.getUnsafe(0)).inMonth)->toBe(false)
    expect((first->Array.getUnsafe(5)).date)->toBe("2026-08-01")
    expect((first->Array.getUnsafe(5)).inMonth)->toBe(true)
  })

  test("a Sunday-first week moves the whole grid by one", () => {
    let sunday = MonthGrid.weeks(~year=2026, ~month=8, ~startsMonday=false)
    expect(((sunday->Array.getUnsafe(0))->Array.getUnsafe(0)).date)->toBe("2026-07-26")
  })

  test("carries every day of the month exactly once", () => {
    let inMonth =
      grid->Array.flat->Array.filter(day => day.MonthGrid.inMonth)->Array.map(day => day.date)
    expect(inMonth->Array.length)->toBe(31)
    expect(inMonth->Array.getUnsafe(0))->toBe("2026-08-01")
    expect(inMonth->Array.getUnsafe(30))->toBe("2026-08-31")
  })

  test("a February that ends on a Sunday still gets six rows", () => {
    let february = MonthGrid.weeks(~year=2026, ~month=2)
    expect(february->Array.length)->toBe(6)
    expect(february->Array.flat->Array.length)->toBe(42)
  })
})

describe("MonthGrid.monthOf and dayOf", () => {
  test("reads the written fields, not a parsed instant", () => {
    expect(MonthGrid.monthOf("2026-08-11"))->toEqual(Some((2026, 8)))
    expect(MonthGrid.dayOf("2026-08-11"))->toEqual(Some("2026-08-11"))
  })

  // The reason: `new Date("2026-08-10")` is midnight UTC, which is the ninth of
  // August anywhere west of Greenwich.
  test("a timestamp lands on the day it was written in", () => {
    expect(MonthGrid.dayOf("2026-08-11T00:30:00.000Z"))->toEqual(Some("2026-08-11"))
    expect(MonthGrid.monthOf("2026-08-11T00:30:00.000Z"))->toEqual(Some((2026, 8)))
  })

  test("what is not a date is not a day", () => {
    expect(MonthGrid.dayOf("next tuesday"))->toEqual(None)
    expect(MonthGrid.monthOf(""))->toEqual(None)
  })
})

describe("MonthGrid.covers", () => {
  test("a span covers its ends and everything between", () => {
    let over = day => MonthGrid.covers(~day, ~from="2026-08-10", ~until="2026-08-12")
    expect(over("2026-08-09"))->toBe(false)
    expect(over("2026-08-10"))->toBe(true)
    expect(over("2026-08-11"))->toBe(true)
    expect(over("2026-08-12"))->toBe(true)
    expect(over("2026-08-13"))->toBe(false)
  })

  test("crossing a month, and a year, is the same comparison", () => {
    expect(MonthGrid.covers(~day="2026-09-01", ~from="2026-08-28", ~until="2026-09-03"))->toBe(true)
    expect(MonthGrid.covers(~day="2027-01-02", ~from="2026-12-30", ~until="2027-01-04"))->toBe(true)
  })

  test("no end is one day", () => {
    expect(MonthGrid.covers(~day="2026-08-10", ~from="2026-08-10", ~until=""))->toBe(true)
    expect(MonthGrid.covers(~day="2026-08-11", ~from="2026-08-10", ~until=""))->toBe(false)
  })

  // Dates the wrong way round are a typo, and the row still has to appear somewhere.
  test("an end before its start covers the start alone", () => {
    expect(MonthGrid.covers(~day="2026-08-10", ~from="2026-08-10", ~until="2026-08-01"))->toBe(true)
    expect(MonthGrid.covers(~day="2026-08-05", ~from="2026-08-10", ~until="2026-08-01"))->toBe(false)
  })
})

describe("MonthGrid day arithmetic", () => {
  test("shiftDays crosses months and years without a Date anywhere", () => {
    expect(MonthGrid.shiftDays(~day="2026-08-31", ~by=1))->toBe("2026-09-01")
    expect(MonthGrid.shiftDays(~day="2026-01-01", ~by=-1))->toBe("2025-12-31")
    expect(MonthGrid.shiftDays(~day="2024-02-28", ~by=1))->toBe("2024-02-29")
    expect(MonthGrid.shiftDays(~day="2026-08-12", ~by=7))->toBe("2026-08-19")
  })

  test("weekDays returns the Monday-first week the anchor falls in", () => {
    let days = MonthGrid.weekDays(~anchor="2026-08-12")
    expect(days->Array.map(day => day.MonthGrid.date)->Array.at(0))->toEqual(Some("2026-08-10"))
    expect(days->Array.length)->toBe(7)
    expect(days->Array.map(day => day.MonthGrid.date)->Array.at(6))->toEqual(Some("2026-08-16"))
  })

  test("weekDays honours Sunday starts", () => {
    let days = MonthGrid.weekDays(~anchor="2026-08-12", ~startsMonday=false)
    expect(days->Array.map(day => day.MonthGrid.date)->Array.at(0))->toEqual(Some("2026-08-09"))
  })
})
