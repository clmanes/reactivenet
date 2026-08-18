open BunTest

describe("OdQuery.references", () => {
  test("finds each key once, in order of first mention", () => {
    expect(
      OdQuery.references("SELECT * FROM t WHERE a = {#uno} AND b = {#due} OR a = {#uno}"),
    )->toEqual(["uno", "due"])
  })

  test("reads the quoted form too", () => {
    expect(OdQuery.references("WHERE name = '{#q}'"))->toEqual(["q"])
  })

  test("nothing to find is an empty list", () => {
    expect(OdQuery.references("SELECT 1"))->toEqual([])
  })
})

describe("OdQuery.bind", () => {
  let lookup = key =>
    switch key {
    | "citta" => Some("Roma")
    | "anno" => Some("2026")
    | _ => None
    }

  test("each placeholder becomes ? and carries its value", () => {
    let (sql, params) = OdQuery.bind(
      "SELECT * FROM spese WHERE comune = {#citta} AND anno = {#anno}",
      lookup,
    )
    expect(sql)->toBe("SELECT * FROM spese WHERE comune = ? AND anno = ?")
    expect(params)->toEqual(["Roma", "2026"])
  })

  // The quotes are consumed with the placeholder: left in place, the ? would sit
  // inside a string literal where it stops being a parameter at all.
  test("the quoted form loses its quotes", () => {
    let (sql, params) = OdQuery.bind("WHERE comune = '{#citta}'", lookup)
    expect(sql)->toBe("WHERE comune = ?")
    expect(params)->toEqual(["Roma"])
  })

  // One parameter per ?, not per distinct key: the statement is positional.
  test("a repeated key binds twice", () => {
    let (sql, params) = OdQuery.bind("WHERE a = {#citta} OR b = {#citta}", lookup)
    expect(sql)->toBe("WHERE a = ? OR b = ?")
    expect(params)->toEqual(["Roma", "Roma"])
  })

  test("a key holding nothing binds the empty string", () => {
    let (_, params) = OdQuery.bind("WHERE a = {#manca}", lookup)
    expect(params)->toEqual([""])
  })
})
