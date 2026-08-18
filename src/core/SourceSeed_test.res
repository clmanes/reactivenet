open BunTest

describe("SourceSeed.decide", () => {
  test("nothing stored yet takes what the document says", () => {
    expect(SourceSeed.decide(~known=None, ~authored="50", ~seen=None))->toEqual(
      SourceSeed.Adopt("50"),
    )
  })

  // The slider case: the reader dragged it to 80, then typed a letter somewhere else
  // and the preview re-rendered. The document still says 50, and the control must
  // stay where it was put.
  test("an unchanged document leaves the live value alone", () => {
    expect(SourceSeed.decide(~known=Some("80"), ~authored="50", ~seen=Some("50")))->toEqual(
      SourceSeed.Keep("80"),
    )
  })

  // The block editor case: the author edited the `value` attribute, which used to do
  // nothing at all because the stored value always won.
  test("a document that changed its mind wins", () => {
    expect(SourceSeed.decide(~known=Some("80"), ~authored="60", ~seen=Some("50")))->toEqual(
      SourceSeed.Adopt("60"),
    )
  })

  test("a first bind of a key that is already stored adopts, having nothing to compare", () => {
    expect(SourceSeed.decide(~known=Some("80"), ~authored="50", ~seen=None))->toEqual(
      SourceSeed.Adopt("50"),
    )
  })
})

describe("SourceSeed ticks", () => {
  test("round-trips through the string a collection stores", () => {
    expect(SourceSeed.ofTick(true))->toBe("true")
    expect(SourceSeed.ofTick(false))->toBe("false")
    expect(SourceSeed.ticked("true"))->toBe(true)
    expect(SourceSeed.ticked("false"))->toBe(false)
  })

  // Anything else is not a tick: the empty string is what an unbound checkbox's
  // `value` used to hand the store, and reading it as "on" would be the same bug
  // wearing a different hat.
  test("anything else is not ticked", () => {
    expect(SourceSeed.ticked(""))->toBe(false)
    expect(SourceSeed.ticked("on"))->toBe(false)
    expect(SourceSeed.ticked("TRUE"))->toBe(false)
  })
})
