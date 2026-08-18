open BunTest

describe("ShareLink", () => {
  test("builds a link with the document in the fragment", () => {
    let link = ShareLink.of_(~origin="https://apps.example", ~payload="AAAA")
    expect(link)->toBe("https://apps.example/s#1AAAA")
    // The fragment is never sent to a server: a shared document does not end up in
    // anybody's access log, and no static host has to route it.
    expect(link->String.includes("#"))->toBe(true)
  })

  test("reads back what it wrote", () => {
    let link = ShareLink.of_(~origin="https://apps.example", ~payload="AAAA")
    let fragment = link->String.sliceToEnd(~start=link->String.indexOf("#"))
    expect(ShareLink.payloadOf(fragment))->toEqual(Some("AAAA"))
  })

  test("accepts a fragment with or without its hash", () => {
    expect(ShareLink.payloadOf("#1xyz"))->toEqual(Some("xyz"))
    expect(ShareLink.payloadOf("1xyz"))->toEqual(Some("xyz"))
  })

  // A marker this version does not know is a link from a version that does. Refusing
  // it is how the app says so, instead of decoding nonsense.
  test("refuses a fragment that is not one of ours", () => {
    expect(ShareLink.payloadOf(""))->toEqual(None)
    expect(ShareLink.payloadOf("#"))->toEqual(None)
    expect(ShareLink.payloadOf("#1"))->toEqual(None)
    expect(ShareLink.payloadOf("#9abc"))->toEqual(None)
    expect(ShareLink.payloadOf("#/a/spesa"))->toEqual(None)
  })

  test("has a ceiling, above which a file is the honest answer", () => {
    expect(ShareLink.fits("x"))->toBe(true)
    expect(ShareLink.fits(String.repeat("x", ShareLink.ceiling)))->toBe(true)
    expect(ShareLink.fits(String.repeat("x", ShareLink.ceiling + 1)))->toBe(false)
  })

  test("builds and reads the short form", () => {
    let link = ShareLink.shortOf(~origin="https://apps.example", ~id="a1b2c3d4e5f6g7h", ~key="KEY")
    expect(link)->toBe("https://apps.example/s/a1b2c3d4e5f6g7h#kKEY")
    expect(ShareLink.keyOf("#kKEY"))->toEqual(Some("KEY"))
    expect(ShareLink.keyOf("kKEY"))->toEqual(Some("KEY"))
  })

  // The key marker and the payload marker must not read as each other: a long link's
  // fragment is not a key, and a bare marker is a truncated link.
  test("a key fragment is not a payload and vice versa", () => {
    expect(ShareLink.keyOf("#1zpayload"))->toEqual(None)
    expect(ShareLink.keyOf("#k"))->toEqual(None)
    expect(ShareLink.payloadOf("#kKEY"))->toEqual(None)
  })

  test("a short id is a path segment and nothing more", () => {
    expect(ShareLink.isShortId("a1b2c3d4e5f6g7h"))->toBe(true)
    expect(ShareLink.isShortId("../etc"))->toBe(false)
    expect(ShareLink.isShortId("x"))->toBe(false)
    expect(ShareLink.isShortId(""))->toBe(false)
  })

  test("the stored ceiling is the server's, checked before the round trip", () => {
    expect(ShareLink.fitsStored(String.repeat("x", ShareLink.storedCeiling)))->toBe(true)
    expect(ShareLink.fitsStored(String.repeat("x", ShareLink.storedCeiling + 1)))->toBe(false)
  })

  test("the message names the app when it has a name", () => {
    expect(ShareLink.message(~title="Spesa", ~invitation="open it here"))->toBe(
      "Spesa — open it here",
    )
    expect(ShareLink.message(~title="", ~invitation="open it here"))->toBe("open it here")
  })
})
