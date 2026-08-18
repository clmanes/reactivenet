open BunTest

let render = source =>
  DirectiveAttributes.parse(source)
  ->Array.map(a => a.DirectiveAttributes.name ++ "=" ++ a.value)
  ->Array.join(",")

describe("DirectiveAttributes.parse", () => {
  test("reads double-quoted values", () => {
    expect(render(`ref="#volume"`))->toBe("ref=#volume")
  })

  test("reads several attributes in order", () => {
    expect(render(`min="0" max="100" value="50"`))->toBe("min=0,max=100,value=50")
  })

  test("reads single-quoted values", () => {
    expect(render(`legend='Volume level'`))->toBe("legend=Volume level")
  })

  test("reads bare values without whitespace", () => {
    expect(render("min=0 max=100"))->toBe("min=0,max=100")
  })

  // `{quiet}` and `{quiet="true"}` should mean the same thing.
  test("treats a bare name as a flag", () => {
    expect(render("required"))->toBe("required=true")
  })

  test("keeps spaces inside quoted values", () => {
    expect(render(`legend="Volume  level"`))->toBe("legend=Volume  level")
  })

  test("keeps an empty quoted value", () => {
    expect(render(`legend=""`))->toBe("legend=")
  })

  test("tolerates spaces around the equals sign", () => {
    expect(render(`ref = "#volume"`))->toBe("ref=#volume")
  })

  test("an empty attribute list yields nothing", () => {
    expect(render(""))->toBe("")
    expect(render("   "))->toBe("")
  })
})

describe("DirectiveAttributes.attribute", () => {
  test("finds by name", () => {
    expect(DirectiveAttributes.attribute(`ref="#volume" min="0"`, "ref")->Option.getOr("none"))->toBe(
      "#volume",
    )
  })

  test("matches the name case-insensitively", () => {
    expect(DirectiveAttributes.attribute(`Ref="#volume"`, "ref")->Option.getOr("none"))->toBe(
      "#volume",
    )
  })

  test("answers None for an absent attribute", () => {
    expect(DirectiveAttributes.attribute(`min="0"`, "ref")->Option.getOr("none"))->toBe("none")
  })

  // Parsing must not leak state between calls: a global regex keeps lastIndex.
  test("is repeatable", () => {
    let source = `ref="#volume"`
    expect(DirectiveAttributes.attribute(source, "ref")->Option.getOr("none"))->toBe("#volume")
    expect(DirectiveAttributes.attribute(source, "ref")->Option.getOr("none"))->toBe("#volume")
    expect(DirectiveAttributes.attribute(source, "ref")->Option.getOr("none"))->toBe("#volume")
  })
})
