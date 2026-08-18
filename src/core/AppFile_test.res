open BunTest

let document = (~id=?, ~title=?, ()) => {
  let fields =
    Frontmatter.empty
    ->(
      meta =>
        switch id {
        | Some(value) => Frontmatter.setField(meta, ~key="appId", ~value)
        | None => meta
        }
    )
    ->(
      meta =>
        switch title {
        | Some(value) => Frontmatter.setField(meta, ~key="title", ~value)
        | None => meta
        }
    )
  Frontmatter.serialize(fields, "# Body\n")
}

describe("AppFile.name", () => {
  test("is the id, which is already safe for a filename", () => {
    expect(AppFile.name("registro-voti"))->toBe("registro-voti.md")
  })
})

describe("AppFile.isDocument", () => {
  test("accepts markdown, whatever the case", () => {
    expect(AppFile.isDocument("app.md"))->toBe(true)
    expect(AppFile.isDocument("App.MARKDOWN"))->toBe(true)
  })

  test("refuses anything else", () => {
    expect(AppFile.isDocument("app.json"))->toBe(false)
    expect(AppFile.isDocument("app"))->toBe(false)
  })
})

describe("AppFile.idFor", () => {
  // A file exported from here and brought straight back keeps its URL.
  test("keeps the declared id when nothing else has it", () => {
    let source = document(~id="shopping", ())
    expect(AppFile.idFor(~source, ~taken=["welcome"], ~fallback="app"))->toBe("shopping")
    expect(AppFile.isCopy(~source, ~id="shopping"))->toBe(false)
  })

  // An import that replaced an app would destroy work with no way back; a duplicate
  // can simply be deleted.
  test("becomes a copy rather than overwriting", () => {
    let source = document(~id="shopping", ())
    let id = AppFile.idFor(~source, ~taken=["shopping"], ~fallback="app")
    expect(id == "shopping")->toBe(false)
    expect(AppId.isValid(id))->toBe(true)
    expect(AppFile.isCopy(~source, ~id))->toBe(true)
  })

  test("falls back to the title when the file declares no id", () => {
    let source = document(~title="Registro voti", ())
    expect(AppFile.idFor(~source, ~taken=[], ~fallback="app"))->toBe("registro-voti")
  })

  test("falls back to the given name when there is nothing to go on", () => {
    let source = "# Just a heading\n"
    expect(AppFile.idFor(~source, ~taken=[], ~fallback="untitled"))->toBe("untitled")
  })

  // A crafted `appId` arrives from outside like any other untrusted string, so it
  // goes through the same validation as one typed into the editor.
  test("refuses an id that is not a valid one", () => {
    let source = document(~id="../../etc", ~title="Escape", ())
    let id = AppFile.idFor(~source, ~taken=[], ~fallback="app")
    expect(AppId.isValid(id))->toBe(true)
    expect(id)->toBe("escape")
  })
})
