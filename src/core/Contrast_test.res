open BunTest

let round = value => Math.round(value *. 100.0) /. 100.0
let ratioOf = (a, b) => Contrast.between(a, b)->Option.map(round)->Option.getOr(-1.0)

describe("Contrast.parseHex", () => {
  test("reads a full hex colour with or without the hash", () => {
    expect(Contrast.parseHex("#ffffff")->Option.isSome)->toBe(true)
    expect(Contrast.parseHex("ffffff")->Option.isSome)->toBe(true)
  })

  test("is case-insensitive", () => {
    expect(ratioOf("#FFFFFF", "#000000"))->toBe(21.0)
  })

  // Guessing a shorthand would hide a typo in a palette definition.
  test("rejects shorthand and malformed values", () => {
    expect(Contrast.parseHex("#fff")->Option.isNone)->toBe(true)
    expect(Contrast.parseHex("#gggggg")->Option.isNone)->toBe(true)
    expect(Contrast.parseHex("")->Option.isNone)->toBe(true)
  })
})

describe("Contrast.ratio", () => {
  // The two anchors the specification itself fixes.
  test("black on white is 21:1", () => {
    expect(ratioOf("#000000", "#ffffff"))->toBe(21.0)
  })

  test("a colour against itself is 1:1", () => {
    expect(ratioOf("#65c3c8", "#65c3c8"))->toBe(1.0)
  })

  test("is symmetric", () => {
    expect(ratioOf("#2f8084", "#ffffff"))->toBe(ratioOf("#ffffff", "#2f8084"))
  })

  // Mid grey is the standard worked example: #767676 is the lightest grey that
  // still clears 4.5:1 on white.
  test("agrees with the known 4.5:1 grey", () => {
    expect(ratioOf("#767676", "#ffffff") >= 4.5)->toBe(true)
    expect(ratioOf("#777777", "#ffffff") >= 4.5)->toBe(false)
  })
})

describe("Contrast.meets", () => {
  test("accepts and rejects against the AA threshold", () => {
    expect(Contrast.meets(~foreground="#767676", ~background="#ffffff", ~threshold=Contrast.normalText))->toBe(true)
    expect(Contrast.meets(~foreground="#999999", ~background="#ffffff", ~threshold=Contrast.normalText))->toBe(false)
  })

  test("an unparseable colour never passes", () => {
    expect(Contrast.meets(~foreground="nope", ~background="#ffffff", ~threshold=1.0))->toBe(false)
  })
})
