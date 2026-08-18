open BunTest

describe("SpaceLink", () => {
  test("builds and reads an invitation", () => {
    let link = SpaceLink.of_(~origin="https://apps.example", ~id="a1b2c3d4e5f6g7h", ~key="KEY")
    expect(link)->toBe("https://apps.example/j/a1b2c3d4e5f6g7h#kKEY")
    let fragment = link->String.sliceToEnd(~start=link->String.indexOf("#"))
    expect(SpaceLink.keyOf(fragment))->toEqual(Some("KEY"))
  })

  test("accepts a fragment with or without its hash", () => {
    expect(SpaceLink.keyOf("#kXYZ"))->toEqual(Some("XYZ"))
    expect(SpaceLink.keyOf("kXYZ"))->toEqual(Some("XYZ"))
  })

  // A truncated link must read as "not an invitation", never as an empty key that
  // then fails one step later with a worse sentence.
  test("refuses a fragment that is not an invitation", () => {
    expect(SpaceLink.keyOf(""))->toEqual(None)
    expect(SpaceLink.keyOf("#"))->toEqual(None)
    expect(SpaceLink.keyOf("#k"))->toEqual(None)
    expect(SpaceLink.keyOf("#1payload"))->toEqual(None)
  })

  test("recognises what can be an invite id", () => {
    expect(SpaceLink.isInviteId("a1b2c3d4e5f6g7h"))->toBe(true)
    expect(SpaceLink.isInviteId("short"))->toBe(false)
    expect(SpaceLink.isInviteId("has/slash-in-it"))->toBe(false)
    expect(SpaceLink.isInviteId(""))->toBe(false)
  })
})
