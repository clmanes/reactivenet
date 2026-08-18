open BunTest

let roundTrip = route => Route.parse(Route.toPath(route))

describe("Route.parse", () => {
  test("reads the two forms of an app link", () => {
    expect(Route.parse("/a/grade-book"))->toEqual(Route.View("grade-book"))
    expect(Route.parse("/a/grade-book/edit"))->toEqual(Route.Edit("grade-book"))
  })

  // A link copied when the routes lived in the hash still names an app, and refusing
  // it would break exactly the thing the URL is for.
  test("still reads a link written with a hash", () => {
    expect(Route.parse("#/a/grade-book"))->toEqual(Route.View("grade-book"))
    expect(Route.parse("#/a/grade-book/edit"))->toEqual(Route.Edit("grade-book"))
  })

  // A link that carries an app. Long form: the document rides in the fragment and
  // never reaches a server. Short form: the encrypted document sits on the server
  // under the id, and the fragment carries the key instead.
  test("reads a shared link, long and short", () => {
    expect(Route.parse("/s"))->toEqual(Route.Shared(None))
    expect(Route.toPath(Route.Shared(None)))->toBe("/s")
    expect(Route.parse("/s/a1b2c3d4e5f6g7h"))->toEqual(Route.Shared(Some("a1b2c3d4e5f6g7h")))
    expect(Route.toPath(Route.Shared(Some("a1b2c3d4e5f6g7h"))))->toBe("/s/a1b2c3d4e5f6g7h")
  })

  test("a short id that is not one falls to the gallery", () => {
    expect(Route.parse("/s/../etc"))->toBe(Route.Gallery)
    expect(Route.parse("/s/x"))->toBe(Route.Gallery)
  })

  test("a query string is not part of the route", () => {
    expect(Route.parse("/a/grade-book?from=mail"))->toEqual(Route.View("grade-book"))
  })

  test("an empty or absent path is the gallery", () => {
    expect(Route.parse(""))->toBe(Route.Gallery)
    expect(Route.parse("#"))->toBe(Route.Gallery)
    expect(Route.parse("/"))->toBe(Route.Gallery)
  })

  test("tolerates a missing or doubled slash", () => {
    expect(Route.parse("a/grade-book"))->toEqual(Route.View("grade-book"))
    expect(Route.parse("//a//grade-book//"))->toEqual(Route.View("grade-book"))
  })

  // The id becomes a storage key, so a hash that is not a valid id must not reach it.
  test("refuses an id the validator would not accept", () => {
    expect(Route.parse("/a/../other"))->toBe(Route.Gallery)
    expect(Route.parse("/a/Grade Book"))->toBe(Route.Gallery)
    expect(Route.parse("/a/grade-book/delete"))->toBe(Route.Gallery)
    expect(Route.parse("/unknown/thing"))->toBe(Route.Gallery)
  })
})

describe("Route.toPath", () => {
  test("round-trips every route", () => {
    [Route.Gallery, Route.View("grade-book"), Route.Edit("grade-book")]->Array.forEach(route =>
      expect(roundTrip(route))->toEqual(route)
    )
  })

  test("addresses the reader's view and the editor separately", () => {
    expect(Route.toPath(View("grade-book")))->toBe("/a/grade-book")
    expect(Route.toPath(Edit("grade-book")))->toBe("/a/grade-book/edit")
  })
})

describe("Route.parse — the catalogue", () => {
  test("reads /c/<id> as a catalogue app", () => {
    expect(Route.parse("/c/soldi-territorio"))->toEqual(Route.Catalog("soldi-territorio"))
  })

  test("refuses an id the validator refuses", () => {
    // The id arrives from outside exactly like the one in /a/<id>, so it goes
    // through the same gate: what it is not is the gallery, never a fetch.
    expect(Route.parse("/c/../etc/passwd"))->toEqual(Route.Gallery)
    expect(Route.parse("/c/"))->toEqual(Route.Gallery)
  })

  test("round-trips", () => {
    expect(Route.toPath(Catalog("scuola-in-cifre")))->toBe("/c/scuola-in-cifre")
    expect(Route.parse(Route.toPath(Catalog("scuola-in-cifre"))))->toEqual(
      Route.Catalog("scuola-in-cifre"),
    )
  })

  test("names no app of this browser", () => {
    // The id is the catalogue's; what it lands under here may differ, because a
    // taken id makes it a copy. Answering with it would open a document nobody has.
    expect(Route.appId(Catalog("scuola-in-cifre")))->toEqual(None)
    expect(Route.isEditing(Catalog("scuola-in-cifre")))->toBe(false)
  })
})
