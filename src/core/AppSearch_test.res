open BunTest

let app = (~id, ~title, ~description="", ~author=""): AppDocument.summary => {
  id,
  title,
  description,
  author,
  date: "",
  version: "",
  icon: "",
  chat: false,
}

let apps = [
  app(~id="registro-voti", ~title="Registro voti", ~description="Medie per studente"),
  app(~id="grade-book", ~title="Grade Book", ~description="Class grades", ~author="Ada"),
  app(~id="spese", ~title="Spese"),
]

let ids = query => AppSearch.filter(apps, query)->Array.map(a => a.id)->Array.join(",")

describe("AppSearch.filter", () => {
  test("an empty query keeps everything", () => {
    expect(ids(""))->toBe("registro-voti,grade-book,spese")
    expect(ids("   "))->toBe("registro-voti,grade-book,spese")
  })

  test("matches the title, whatever the case", () => {
    expect(ids("SPESE"))->toBe("spese")
  })

  // The id is on the card, so it has to be searchable — and from the middle, since
  // that is where the distinguishing word usually is.
  test("matches inside the id", () => {
    expect(ids("voti"))->toBe("registro-voti")
  })

  test("matches the description and the author", () => {
    expect(ids("studente"))->toBe("registro-voti")
    expect(ids("Ada"))->toBe("grade-book")
  })

  test("every word must match, so typing narrows", () => {
    expect(ids("grade class"))->toBe("grade-book")
    expect(ids("grade spese"))->toBe("")
  })

  test("keeps the order it was given", () => {
    expect(ids("e"))->toBe("registro-voti,grade-book,spese")
  })
})
