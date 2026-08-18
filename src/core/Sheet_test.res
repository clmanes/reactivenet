open BunTest

let collection: Collection.t = {
  records: [
    {id: "a1", fields: [{Collection.name: "voce", value: "Pane"}, {Collection.name: "importo", value: "2"}]},
    {id: "b2", fields: [{Collection.name: "voce", value: "Latte"}, {Collection.name: "note", value: "bio"}]},
  ],
}

describe("Sheet.encode", () => {
  test("header is id plus the union of fields, rows are rectangular", () => {
    let grid = Sheet.encode(collection)
    expect(grid->Array.getUnsafe(0))->toEqual(["id", "voce", "importo", "note"])
    expect(grid->Array.getUnsafe(1))->toEqual(["a1", "Pane", "2", ""])
    expect(grid->Array.getUnsafe(2))->toEqual(["b2", "Latte", "", "bio"])
  })
})

describe("Sheet.decode", () => {
  let mint = used => "new-" ++ used->Array.length->Int.toString

  test("round-trips, ids and all", () => {
    let records = Sheet.decode(Sheet.encode(collection), ~makeId=mint)
    expect(records->Array.map(r => r.Collection.id))->toEqual(["a1", "b2"])
    expect(
      records
      ->Array.getUnsafe(1)
      ->Collection.field("note"),
    )->toEqual(Some("bio"))
  })

  // The usual spreadsheet has no id column: every row is new.
  test("a file without ids gets fresh ones", () => {
    let records = Sheet.decode([["voce"], ["Pane"], ["Latte"]], ~makeId=mint)
    expect(records->Array.map(r => r.Collection.id))->toEqual(["new-0", "new-1"])
  })

  test("blank rows and blank cells are skipped", () => {
    let records = Sheet.decode([["voce", "note"], ["", ""], ["Pane", ""]], ~makeId=mint)
    expect(records->Array.length)->toBe(1)
    expect(records->Array.getUnsafe(0)->Collection.field("note")->Option.isNone)->toBe(true)
  })

  test("a duplicated id in the file does not collide with itself", () => {
    let records = Sheet.decode([["id", "voce"], ["x", "Pane"], ["x", "Latte"]], ~makeId=mint)
    expect(records->Array.getUnsafe(0)->(r => r.Collection.id))->toBe("x")
    expect(records->Array.getUnsafe(1)->(r => r.Collection.id))->toBe("new-1")
  })
})
