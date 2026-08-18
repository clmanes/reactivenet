open BunTest

let name = locale => Locale.toTag(locale)
let parsed = tag => Locale.parse(tag)->Option.map(name)->Option.getOr("none")

describe("Locale.parse", () => {
  test("accepts bare language tags", () => {
    expect(parsed("fr"))->toBe("fr")
    expect(parsed("zh"))->toBe("zh")
  })

  // The common case: browsers send a region, never a bare language.
  test("ignores the region subtag", () => {
    expect(parsed("en-GB"))->toBe("en")
    expect(parsed("pt-BR"))->toBe("pt")
    expect(parsed("de-AT"))->toBe("de")
  })

  test("ignores script and region together", () => {
    expect(parsed("zh-Hans-CN"))->toBe("zh")
  })

  test("ignores case and surrounding whitespace", () => {
    expect(parsed("  IT-it  "))->toBe("it")
  })

  test("rejects unsupported languages", () => {
    expect(parsed("ja"))->toBe("none")
    expect(parsed(""))->toBe("none")
  })
})

describe("Locale.fromPreferred", () => {
  test("takes the first supported entry, not the first entry", () => {
    expect(Locale.fromPreferred(["ja", "ko", "de-AT", "fr"])->name)->toBe("de")
  })

  test("falls back when nothing matches", () => {
    expect(Locale.fromPreferred(["ja", "ko"])->name)->toBe(Locale.toTag(Locale.fallback))
  })

  test("falls back on an empty list", () => {
    expect(Locale.fromPreferred([])->name)->toBe(Locale.toTag(Locale.fallback))
  })
})

describe("Locale.all", () => {
  test("every locale round-trips through its tag", () => {
    let broken =
      Locale.all
      ->Array.filter(locale => Locale.parse(Locale.toTag(locale)) != Some(locale))
      ->Array.map(Locale.toTag)
      ->Array.join(",")
    expect(broken)->toBe("")
  })

  test("lists all seven supported languages", () => {
    expect(Locale.all->Array.length)->toBe(7)
  })

  test("has a native name for each", () => {
    let missing = Locale.all->Array.filter(l => Locale.nativeName(l) == "")->Array.length
    expect(missing)->toBe(0)
  })
})
