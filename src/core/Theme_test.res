open BunTest

describe("Theme", () => {
  test("toggles between the two polarities", () => {
    expect(Theme.toggle(Light)->Theme.toTag)->toBe("dark")
    expect(Theme.toggle(Dark)->Theme.toTag)->toBe("light")
  })

  test("toggling twice is the identity", () => {
    expect(Theme.toggle(Theme.toggle(Light)))->toEqual(Theme.Light)
    expect(Theme.toggle(Theme.toggle(Dark)))->toEqual(Theme.Dark)
  })

  test("reports polarity", () => {
    expect(Theme.isDark(Dark))->toBe(true)
    expect(Theme.isDark(Light))->toBe(false)
  })

  test("maps the OS preference", () => {
    expect(Theme.fromPrefersDark(true)->Theme.isDark)->toBe(true)
    expect(Theme.fromPrefersDark(false)->Theme.isDark)->toBe(false)
  })

  test("round-trips through its tag", () => {
    expect(Theme.parse(Theme.toTag(Light)))->toEqual(Some(Theme.Light))
    expect(Theme.parse(Theme.toTag(Dark)))->toEqual(Some(Theme.Dark))
  })

  test("rejects unknown tags", () => {
    expect(Theme.parse("darkest")->Option.isNone)->toBe(true)
  })
})
