open BunTest

let name = value =>
  switch DateValue.classify(value) {
  | Some(Day) => "day"
  | Some(Moment) => "moment"
  | None => "-"
  }

describe("DateValue.classify", () => {
  test("recognises what this app writes", () => {
    expect(name("2026-08-10T13:10:34.324Z"))->toBe("moment")
    expect(name("2026-08-10"))->toBe("day")
  })

  test("recognises what a date input produces", () => {
    // `type="datetime-local"` has no seconds and no zone.
    expect(name("2026-08-10T13:10"))->toBe("moment")
    expect(name("2026-08-10T13:10:34"))->toBe("moment")
    expect(name("2026-08-10T13:10:34+02:00"))->toBe("moment")
  })

  // The point of the recogniser: text an author typed is left alone.
  test("leaves prose alone", () => {
    expect(name("2026 rows"))->toBe("-")
    expect(name("10/08/2026"))->toBe("-")
    expect(name("version 2026-08"))->toBe("-")
    expect(name(""))->toBe("-")
  })

  // The shape alone would accept these; a thirteenth month is not a date, and
  // `Date` would silently roll it into the next year.
  test("refuses an impossible month or day", () => {
    expect(name("2026-13-01"))->toBe("-")
    expect(name("2026-00-10"))->toBe("-")
    expect(name("2026-08-32"))->toBe("-")
    expect(name("2026-08-00"))->toBe("-")
  })
})
