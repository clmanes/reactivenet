open BunTest

let row = (id, fields) => {
  Collection.id,
  fields: fields->Array.map(((name, value)) => {Collection.name, value}),
}

let rows = [
  row("1", [("who", "Ada"), ("price", "9"), ("what", "Cavo USB")]),
  row("2", [("who", "Bo"), ("price", "10"), ("what", "Tastiera")]),
  row("3", [("who", "Ada"), ("price", "2"), ("what", "Cavo HDMI")]),
]

let names = found => found->Array.map(r => r.Collection.id)->Array.join(",")

describe("RowView.sort", () => {
  // The reason numbers are not compared as text: "10" sorts before "9" and a column
  // of prices comes out wrong in a way nobody reads as a bug.
  test("orders numbers as numbers", () => {
    expect(names(RowView.sort(rows, ~field="price", ~direction=Ascending)))->toBe("3,1,2")
    expect(names(RowView.sort(rows, ~field="price", ~direction=Descending)))->toBe("2,1,3")
  })

  test("orders text as text, case-insensitively", () => {
    expect(names(RowView.sort(rows, ~field="what", ~direction=Ascending)))->toBe("3,1,2")
  })

  // Stability is what keeps a table from shuffling on every refresh.
  test("rows that tie keep the order they were stored in", () => {
    expect(names(RowView.sort(rows, ~field="who", ~direction=Ascending)))->toBe("1,3,2")
  })

  // Every ISO timestamp starts with the same four digits. A parser that reads a
  // numeric prefix made them all the number 2026, so the rows tied, the stable sort
  // kept them as stored, and `dir="desc"` looked like it had never been read.
  test("orders timestamps as text, not as the year they start with", () => {
    let stamped = [
      row("1", [("createdAt", "2026-08-10T17:50:45.880Z")]),
      row("2", [("createdAt", "2026-08-10T17:50:46.264Z")]),
      row("3", [("createdAt", "2026-08-10T17:50:46.664Z")]),
    ]
    expect(names(RowView.sort(stamped, ~field="createdAt", ~direction=Descending)))->toBe("3,2,1")
  })

  // The comparator has to be a total order or the sort's behaviour is undefined:
  // text-compare for mixed pairs made "10" < "5" < numbers-land inconsistent
  // depending on what each was measured against.
  test("numbers sort before text, whatever the order of comparison", () => {
    let mixed = [
      row("1", [("v", "abc")]),
      row("2", [("v", "10")]),
      row("3", [("v", "5")]),
      row("4", [("v", "zz")]),
    ]
    expect(names(RowView.sort(mixed, ~field="v", ~direction=Ascending)))->toBe("3,2,1,4")
  })

  test("no field means no reordering", () => {
    expect(names(RowView.sort(rows, ~field="", ~direction=Descending)))->toBe("1,2,3")
  })
})

describe("RowView.search", () => {
  let over = query => names(RowView.search(rows, ~query, ~fields=["who", "what"]))

  test("matches from the middle of a value", () => {
    expect(over("dmi"))->toBe("3")
  })

  test("every word must match, so a second word narrows", () => {
    expect(over("cavo"))->toBe("1,3")
    expect(over("cavo hdmi"))->toBe("3")
  })

  test("only the fields it was given", () => {
    expect(names(RowView.search(rows, ~query="9", ~fields=["who", "what"])))->toBe("")
  })

  test("an empty query is not a filter", () => {
    expect(over("   "))->toBe("1,2,3")
  })
})

describe("RowView.filter", () => {
  test("matches one field exactly, ignoring case", () => {
    expect(names(RowView.filter(rows, ~expression="who=ada")))->toBe("1,3")
  })

  test("a partial value does not match", () => {
    expect(names(RowView.filter(rows, ~expression="who=Ad")))->toBe("")
  })

  test("something that is not field=value filters nothing", () => {
    expect(names(RowView.filter(rows, ~expression="who")))->toBe("1,2,3")
    expect(names(RowView.filter(rows, ~expression="=Ada")))->toBe("1,2,3")
  })
})

describe("RowView.filterAll and values", () => {
  test("two filters narrow to the rows that satisfy both", () => {
    expect(names(RowView.filterAll(rows, ~expressions=["who=ada", "price=2"])))->toBe("3")
  })

  // A column nobody has chosen a value for is not a filter, so an empty expression
  // has to pass everything through rather than match the rows with no value.
  test("an empty filter narrows nothing", () => {
    expect(names(RowView.filterAll(rows, ~expressions=["", "who=ada"])))->toBe("1,3")
    expect(names(RowView.filterAll(rows, ~expressions=[])))->toBe("1,2,3")
  })

  test("the values offered are the distinct ones, ordered", () => {
    expect(RowView.values(rows, ~field="who")->Array.join(","))->toBe("Ada,Bo")
    // Numbers as numbers: 10 after 9 is the whole reason `compare` exists.
    expect(RowView.values(rows, ~field="price")->Array.join(","))->toBe("2,9,10")
  })

  test("a blank is not something to choose", () => {
    let withBlank = rows->Array.concat([row("4", [("who", "")])])
    expect(RowView.values(withBlank, ~field="who")->Array.join(","))->toBe("Ada,Bo")
  })
})

describe("RowView.limit and page", () => {
  test("limit takes the first rows, and zero means all", () => {
    expect(names(RowView.limit(rows, ~count=2)))->toBe("1,2")
    expect(names(RowView.limit(rows, ~count=0)))->toBe("1,2,3")
  })

  test("pages are counted with the remainder", () => {
    expect(RowView.pageCount(3, ~size=2))->toBe(2)
    expect(RowView.pageCount(4, ~size=2))->toBe(2)
  })

  // Never zero: an empty collection is one empty page, or the pager has nothing to
  // say and disappears at the moment it is most needed.
  test("there is always at least one page", () => {
    expect(RowView.pageCount(0, ~size=10))->toBe(1)
  })

  test("a page beyond the end lands on the last one", () => {
    expect(names(RowView.page(rows, ~size=2, ~index=9)))->toBe("3")
    expect(names(RowView.page(rows, ~size=2, ~index=-4)))->toBe("1,2")
  })

  test("no page size means no paging", () => {
    expect(names(RowView.page(rows, ~size=0, ~index=3)))->toBe("1,2,3")
  })
})

describe("RowView.groups", () => {
  test("gathers by a field, in first-appearance order", () => {
    let gathered =
      RowView.groups(rows, ~field="who")->Array.map(((name, found)) =>
        name ++ ":" ++ names(found)
      )
    expect(gathered->Array.join(" | "))->toBe("Ada:1,3 | Bo:2")
  })

  test("rows with no such field gather under the empty name", () => {
    let gathered = RowView.groups(rows, ~field="missing")->Array.map(((name, _)) => name)
    expect(gathered->Array.join(","))->toBe("")
  })

  test("no field is one group of everything", () => {
    expect(RowView.groups(rows, ~field="")->Array.length)->toBe(1)
  })
})
