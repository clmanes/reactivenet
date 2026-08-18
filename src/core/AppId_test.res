open BunTest

describe("AppId.of_", () => {
  test("slugs a title", () => {
    expect(AppId.of_("Grade Book"))->toBe("grade-book")
    expect(AppId.of_("Registro   voti 2026"))->toBe("registro-voti-2026")
  })

  test("never yields an id the validator would reject", () => {
    ["", "---", "!!!", "  ", "-leading", "trailing-", "a--b", "ÀÈÌ"]->Array.forEach(raw =>
      expect(AppId.isValid(AppId.of_(raw)))->toBe(true)
    )
  })

  test("falls back rather than returning nothing", () => {
    expect(AppId.of_("???"))->toBe("app")
  })
})

describe("AppId.isValid", () => {
  test("accepts what a link can carry", () => {
    expect(AppId.isValid("grade-book"))->toBe(true)
    expect(AppId.isValid("a1"))->toBe(true)
  })

  // An id arrives from the URL and becomes an IndexedDB key, so the shapes that could
  // reach past their own namespace are the ones that matter.
  test("refuses anything that could escape its namespace", () => {
    expect(AppId.isValid("../other"))->toBe(false)
    expect(AppId.isValid("app/one"))->toBe(false)
    expect(AppId.isValid("Grade"))->toBe(false)
    expect(AppId.isValid(""))->toBe(false)
    expect(AppId.isValid("-x"))->toBe(false)
    expect(AppId.isValid("x-"))->toBe(false)
    expect(AppId.isValid("a--b"))->toBe(false)
  })

  test("refuses an id longer than the limit", () => {
    expect(AppId.isValid(String.repeat("a", AppId.maxLength)))->toBe(true)
    expect(AppId.isValid(String.repeat("a", AppId.maxLength + 1)))->toBe(false)
  })
})

describe("AppId.unique", () => {
  test("keeps the plain id when it is free", () => {
    expect(AppId.unique(~desired="Grade Book", ~taken=["other"]))->toBe("grade-book")
  })

  test("counts up past every id already taken", () => {
    expect(AppId.unique(~desired="Grade Book", ~taken=["grade-book"]))->toBe("grade-book-2")
    expect(
      AppId.unique(~desired="Grade Book", ~taken=["grade-book", "grade-book-2"]),
    )->toBe("grade-book-3")
  })
})
