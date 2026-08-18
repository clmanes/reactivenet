open BunTest

let app = (~id, ~title="", ~version=""): AppDocument.summary => {
  id,
  title: title == "" ? id : title,
  description: "",
  author: "",
  date: "",
  version,
  icon: "",
  chat: false,
}

let entry = (~id, ~title="", ~version=""): CatalogUpdate.entry => {
  id,
  title: title == "" ? id : title,
  version,
}

describe("CatalogUpdate.compare", () => {
  test("orders the segments as numbers, not as text", () => {
    // The whole reason this is not a string comparison: "1.10" sorts before "1.9"
    // as text, and after it as a version.
    expect(CatalogUpdate.compare("1.10", "1.9") > 0)->toBe(true)
    expect(CatalogUpdate.compare("2.0", "10.0") < 0)->toBe(true)
  })

  test("a missing segment is zero", () => {
    expect(CatalogUpdate.compare("2", "2.0"))->toBe(0)
    expect(CatalogUpdate.compare("2.0.0", "2"))->toBe(0)
    expect(CatalogUpdate.compare("2.0.1", "2") > 0)->toBe(true)
  })

  test("segments that are not numbers compare as text", () => {
    expect(CatalogUpdate.compare("1.0-beta", "1.0-alpha") > 0)->toBe(true)
    expect(CatalogUpdate.compare("1.0", "1.0"))->toBe(0)
  })

  test("surrounding space does not make two versions different", () => {
    expect(CatalogUpdate.compare(" 3.1 ", "3.1"))->toBe(0)
  })
})

describe("CatalogUpdate.isNewer", () => {
  test("only strictly newer counts", () => {
    expect(CatalogUpdate.isNewer(~installed="1.0", ~published="1.1"))->toBe(true)
    expect(CatalogUpdate.isNewer(~installed="1.1", ~published="1.1"))->toBe(false)
    // A catalogue rolled back is not an invitation to install the older one.
    expect(CatalogUpdate.isNewer(~installed="2.0", ~published="1.9"))->toBe(false)
  })

  test("an unwritten version on either side answers no", () => {
    // Not "false because older" — false because the question has no answer, and
    // announcing an update on a comparison with the empty string invents a fact.
    expect(CatalogUpdate.isNewer(~installed="", ~published="1.0"))->toBe(false)
    expect(CatalogUpdate.isNewer(~installed="1.0", ~published=""))->toBe(false)
    expect(CatalogUpdate.isNewer(~installed="", ~published=""))->toBe(false)
  })
})

describe("CatalogUpdate.offers", () => {
  let installed = [
    app(~id="orario-scolastico", ~title="Orario", ~version="2.0"),
    app(~id="segreteria", ~version="1.4"),
    app(~id="mia-app", ~version="1.0"),
    app(~id="senza-versione"),
  ]
  let published = [
    entry(~id="orario-scolastico", ~title="Orario Scolastico", ~version="3.0"),
    entry(~id="segreteria", ~version="1.4"),
    entry(~id="inclusione", ~version="2.0"),
    entry(~id="senza-versione", ~version="1.0"),
  ]
  let found = CatalogUpdate.offers(~installed, ~published)

  test("offers only what is here and published newer", () => {
    expect(found->Array.map(o => o.id)->Array.join(","))->toBe("orario-scolastico")
  })

  test("carries both titles, because the app may have been renamed", () => {
    let offer = found->Array.getUnsafe(0)
    expect(offer.installedTitle)->toBe("Orario")
    expect(offer.publishedTitle)->toBe("Orario Scolastico")
    expect(offer.installed ++ " → " ++ offer.published)->toBe("2.0 → 3.0")
  })

  test("an app the catalogue does not publish is left alone", () => {
    expect(CatalogUpdate.offerFor(~id="mia-app", ~offers=found)->Option.isNone)->toBe(true)
  })

  test("everything current is an empty answer, not an error", () => {
    expect(CatalogUpdate.offers(~installed, ~published=[])->Array.length)->toBe(0)
  })

  test("the published title falls back to the installed one when it is empty", () => {
    let offer =
      CatalogUpdate.offers(
        ~installed=[app(~id="x", ~title="Mia", ~version="1.0")],
        ~published=[{id: "x", title: "", version: "2.0"}],
      )->Array.getUnsafe(0)
    expect(offer.publishedTitle)->toBe("Mia")
  })
})
