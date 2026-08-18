open BunTest

let row = (id, fields): Collection.record => {
  id,
  fields: fields->Array.map(((name, value)): Collection.field => {name, value}),
}

let collection = {
  Collection.records: [
    row("r1", [("what", "Bread"), ("price", "2.50")]),
    row("r2", [("what", "Milk"), ("price", "1.20"), ("note", "half a litre")]),
  ],
}

let counter = ref(0)
let makeId = taken => {
  counter := counter.contents + 1
  let candidate = "new-" ++ counter.contents->Int.toString
  taken->Array.includes(candidate) ? candidate ++ "-x" : candidate
}

describe("Csv.encode", () => {
  // A collection has no schema, so the header is the union of what the rows actually
  // carry — a field only the second row uses still gets a column.
  test("the header is every field any row has, ids first", () => {
    expect(Csv.columns(collection.records)->Array.join(","))->toBe("what,price,note")
    expect(Csv.encode(collection)->String.split("\r\n")->Array.getUnsafe(0))->toBe(
      "id,what,price,note",
    )
  })

  test("a row with nothing in a column leaves it empty", () => {
    let line = Csv.encode(collection)->String.split("\r\n")->Array.getUnsafe(1)
    expect(line)->toBe("r1,Bread,2.50,")
  })

  test("quotes what would otherwise break the grid", () => {
    let awkward = {
      Collection.records: [
        row("r1", [("what", "Bread, sliced"), ("note", "he said \"hello\""), ("more", "two\nlines")]),
      ],
    }
    let line = Csv.encode(awkward)->String.split("\r\n")->Array.getUnsafe(1)
    expect(line)->toBe("r1,\"Bread, sliced\",\"he said \"\"hello\"\"\",\"two\nlines\"")
  })
})

describe("Csv.decode", () => {
  test("round-trips a collection, ids and all", () => {
    let back = Csv.decode(Csv.encode(collection), ~makeId)
    expect(back->Array.map(r => r.Collection.id)->Array.join(","))->toBe("r1,r2")
    let first = back->Array.getUnsafe(0)
    expect(Collection.field(first, "what"))->toEqual(Some("Bread"))
    expect(Collection.field(first, "price"))->toEqual(Some("2.50"))
    // The empty cell is kept as an empty value rather than dropped: a column that
    // exists and is blank is different from a field the row never had.
    expect(Collection.field(first, "note"))->toEqual(Some(""))
  })

  test("a file with no id column gets fresh ids", () => {
    let rows = Csv.decode("what,price\r\nBread,2.50\r\nMilk,1.20\r\n", ~makeId)
    expect(rows->Array.length)->toBe(2)
    expect(rows->Array.every(r => r.Collection.id->String.startsWith("new-")))->toBe(true)
    expect(Collection.field(rows->Array.getUnsafe(1), "what"))->toEqual(Some("Milk"))
  })

  test("reads what an editor produces: LF endings and no final newline", () => {
    let rows = Csv.decode("what\nBread\nMilk", ~makeId)
    expect(rows->Array.length)->toBe(2)
    expect(Collection.field(rows->Array.getUnsafe(1), "what"))->toEqual(Some("Milk"))
  })

  test("a comma inside quotes is a comma, not a column", () => {
    let rows = Csv.decode("what,note\r\n\"Bread, sliced\",\"he said \"\"hi\"\"\"\r\n", ~makeId)
    let first = rows->Array.getUnsafe(0)
    expect(Collection.field(first, "what"))->toEqual(Some("Bread, sliced"))
    expect(Collection.field(first, "note"))->toEqual(Some("he said \"hi\""))
  })

  test("a line break inside quotes stays inside the value", () => {
    let rows = Csv.decode("what\r\n\"two\nlines\"\r\n", ~makeId)
    expect(rows->Array.length)->toBe(1)
    expect(Collection.field(rows->Array.getUnsafe(0), "what"))->toEqual(Some("two\nlines"))
  })

  // A quoted nothing is a value somebody wrote; a bare blank line is how files end.
  test("a quoted empty cell is a row, a blank line is not", () => {
    let rows = Csv.decode("what\r\n\"\"\r\n\r\n", ~makeId)
    expect(rows->Array.length)->toBe(1)
    expect(Collection.field(rows->Array.getUnsafe(0), "what"))->toEqual(Some(""))
  })

  test("an empty file is no rows, not one empty row", () => {
    expect(Csv.decode("", ~makeId)->Array.length)->toBe(0)
    expect(Csv.decode("what,price\r\n", ~makeId)->Array.length)->toBe(0)
  })

  test("two rows claiming the same id do not become one", () => {
    let rows = Csv.decode("id,what\r\nr1,Bread\r\nr1,Milk\r\n", ~makeId)
    let ids = rows->Array.map(r => r.Collection.id)
    expect(ids->Array.length)->toBe(2)
    expect((ids->Array.getUnsafe(0)) == (ids->Array.getUnsafe(1)))->toBe(false)
  })
})
