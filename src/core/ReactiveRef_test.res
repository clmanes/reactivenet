open BunTest

let describe_ = raw =>
  switch ReactiveRef.parse(raw) {
  | Some(ReactiveRef.Reactive(key)) => "reactive:" ++ key
  | Some(ReactiveRef.StoreKey(key)) => "store:" ++ key
  | None => "none"
  }

describe("ReactiveRef.parse", () => {
  test("a leading # marks a reactive reference", () => {
    expect(describe_("#volume"))->toBe("reactive:volume")
  })

  test("a bare id is the store key a source writes to", () => {
    expect(describe_("volume"))->toBe("store:volume")
  })

  test("ignores surrounding whitespace", () => {
    expect(describe_("  #volume  "))->toBe("reactive:volume")
    expect(describe_("  volume  "))->toBe("store:volume")
  })

  test("a lone # references nothing", () => {
    expect(describe_("#"))->toBe("none")
    expect(describe_("#   "))->toBe("none")
  })

  test("an empty reference is nothing", () => {
    expect(describe_(""))->toBe("none")
    expect(describe_("   "))->toBe("none")
  })

  test("keeps dotted paths intact", () => {
    expect(describe_("#settings.volume"))->toBe("reactive:settings.volume")
  })
})

describe("ReactiveRef.reactiveKey", () => {
  // The point of the boundary: only a reactive reference may drive a live view.
  test("answers only for reactive references", () => {
    expect(ReactiveRef.reactiveKey("#volume")->Option.getOr("none"))->toBe("volume")
    expect(ReactiveRef.reactiveKey("volume")->Option.getOr("none"))->toBe("none")
    expect(ReactiveRef.reactiveKey("#")->Option.getOr("none"))->toBe("none")
  })
})

describe("ReactiveRef round-trip", () => {
  test("toString restores what was parsed", () => {
    let cases = ["#volume", "volume", "#settings.volume"]
    let broken =
      cases
      ->Array.filter(raw =>
        switch ReactiveRef.parse(raw) {
        | Some(reference) => ReactiveRef.toString(reference) != raw
        | None => true
        }
      )
      ->Array.join(",")
    expect(broken)->toBe("")
  })

  test("key strips the marker, isReactive keeps the distinction", () => {
    let reactive = ReactiveRef.parse("#volume")->Option.getOrThrow
    let store = ReactiveRef.parse("volume")->Option.getOrThrow
    expect(ReactiveRef.key(reactive))->toBe("volume")
    expect(ReactiveRef.key(store))->toBe("volume")
    expect(ReactiveRef.isReactive(reactive))->toBe(true)
    expect(ReactiveRef.isReactive(store))->toBe(false)
  })
})
