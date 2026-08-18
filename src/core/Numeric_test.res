open BunTest

describe("Numeric.parse", () => {
  test("reads a value that is a number all the way through", () => {
    expect(Numeric.parse("42"))->toEqual(Some(42.0))
    expect(Numeric.parse("  2.50 "))->toEqual(Some(2.5))
    expect(Numeric.parse("-0.5"))->toEqual(Some(-0.5))
    expect(Numeric.parse("+3"))->toEqual(Some(3.0))
    expect(Numeric.parse(".5"))->toEqual(Some(0.5))
    expect(Numeric.parse("7."))->toEqual(Some(7.0))
    expect(Numeric.parse("1e3"))->toEqual(Some(1000.0))
  })

  // The whole reason this module exists. `Float.fromString` is `parseFloat`, which
  // reads a numeric prefix and stops: every ISO timestamp became the year 2026, so
  // a column of them compared equal and a sort left the rows exactly as stored.
  test("a numeric prefix is not a number", () => {
    expect(Numeric.parse("2026-08-10T17:50:45.880Z"))->toEqual(None)
    expect(Numeric.parse("2026-08-10"))->toEqual(None)
    expect(Numeric.parse("10 items"))->toEqual(None)
    expect(Numeric.parse("3, please"))->toEqual(None)
    expect(Numeric.parse("12:30"))->toEqual(None)
  })

  test("refuses what nobody types into a form", () => {
    expect(Numeric.parse(""))->toEqual(None)
    expect(Numeric.parse("   "))->toEqual(None)
    expect(Numeric.parse("Infinity"))->toEqual(None)
    expect(Numeric.parse("NaN"))->toEqual(None)
    expect(Numeric.parse("0x10"))->toEqual(None)
    // A comma is a decimal separator in most of the languages this app speaks, and
    // reading it as one would silently change 1,5 into 15 somewhere else.
    expect(Numeric.parse("1,5"))->toEqual(None)
  })

  test("isNumber answers what parse would", () => {
    expect(Numeric.isNumber("7"))->toBe(true)
    expect(Numeric.isNumber("7 days"))->toBe(false)
  })
})
