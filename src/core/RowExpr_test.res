open BunTest

let row = key =>
  switch key {
  | "qta" => Some("3")
  | "prezzo" => Some("2.50")
  | "vuoto" => Some("")
  | _ => None
  }

describe("RowExpr", () => {
  test("multiplies the row's own fields", () => {
    expect(RowExpr.evaluate("qta*prezzo", row))->toEqual(Some(7.5))
  })

  test("a missing field is zero", () => {
    expect(RowExpr.evaluate("qta + manca", row))->toEqual(Some(3.0))
  })

  test("constants mix in", () => {
    expect(RowExpr.evaluate("qta*prezzo*1.22", row))->toEqual(Some(9.15))
  })

  // Hyphens are legal in field names, so `a-b` must stay a name: subtraction
  // needs spaces, and the cheap test is what enforces it.
  test("a-b is a field name, not a subtraction", () => {
    expect(RowExpr.looksLike("qta-prezzo"))->toBe(false)
    expect(RowExpr.looksLike("qta - prezzo"))->toBe(true)
    expect(RowExpr.evaluate("qta - prezzo", row))->toEqual(Some(0.5))
  })

  test("prose with braces does not parse", () => {
    expect(RowExpr.parses("display: block"))->toBe(false)
    expect(RowExpr.parses("qta*prezzo"))->toBe(true)
  })
})

describe("RowTemplate row arithmetic", () => {
  let record: Collection.record = {
    id: "r1",
    fields: [
      {Collection.name: "voce", value: "Viti"},
      {Collection.name: "qta", value: "4"},
      {Collection.name: "prezzo", value: "1.50"},
    ],
  }

  test("computes per row, two decimals", () => {
    expect(RowTemplate.fill("{voce}: {qta*prezzo}", record))->toBe("Viti: 6.00")
  })

  test("what is not arithmetic stays as written", () => {
    expect(RowTemplate.fill("{a b c} testo", record))->toBe("{a b c} testo")
  })
})

describe("Aggregate over an expression field", () => {
  let collection: Collection.t = {
    records: [
      {id: "a", fields: [{Collection.name: "qta", value: "2"}, {Collection.name: "prezzo", value: "10"}]},
      {id: "b", fields: [{Collection.name: "qta", value: "3"}, {Collection.name: "prezzo", value: "5"}]},
      {id: "c", fields: [{Collection.name: "qta", value: "1"}]},
    ],
  }

  test("sums qta*prezzo across the rows", () => {
    // 20 + 15 + 0 (the row without a price counts its missing field as zero).
    expect(Aggregate.compute(Sum, collection, ~field="qta*prezzo"))->toEqual(Some("35"))
  })

  test("a plain field still behaves as before", () => {
    expect(Aggregate.compute(Sum, collection, ~field="qta"))->toEqual(Some("6"))
  })
})
