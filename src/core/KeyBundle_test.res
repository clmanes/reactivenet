open BunTest

describe("KeyBundle", () => {
  let bundle: KeyBundle.t = {
    pub: "{\"kty\":\"EC\"}",
    salt: "c2FsdA",
    iterations: 600000,
    vault: "sealed-by-password",
    recoveryVault: "sealed-by-code",
  }

  test("round-trips through encode and decode", () => {
    expect(KeyBundle.decode(KeyBundle.encode(bundle)))->toEqual(Some(bundle))
  })

  test("refuses what is not a bundle", () => {
    expect(KeyBundle.decode(""))->toEqual(None)
    expect(KeyBundle.decode("{}"))->toEqual(None)
    expect(KeyBundle.decode("not json"))->toEqual(None)
    // A future version is recognised and refused, not half-read.
    expect(KeyBundle.decode("{\"v\":2,\"pub\":\"x\"}"))->toEqual(None)
  })

  test("refuses a bundle with an empty seal", () => {
    let hollow = KeyBundle.encode({...bundle, vault: ""})
    expect(KeyBundle.decode(hollow))->toEqual(None)
  })
})
