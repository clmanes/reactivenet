open BunTest

let row = (id, fields): Collection.record => {
  id,
  fields: fields->Array.map(((name, value)): Collection.field => {name, value}),
}

let lessons = [
  row("l1", [("ora", "1"), ("giorno", "lun"), ("disciplina", "Italiano")]),
  row("l2", [("ora", "2"), ("giorno", "lun"), ("disciplina", "Matematica")]),
  row("l3", [("ora", "10"), ("giorno", "mar"), ("disciplina", "Storia")]),
  row("l4", [("ora", "9"), ("giorno", "mar"), ("disciplina", "Fisica")]),
]

let grid = (records, ~rowValues="", ~colValues="", ~rowLabels="", ~colLabels="") =>
  TimeGrid.build(
    records,
    ~rowField="ora",
    ~colField="giorno",
    ~rowValues,
    ~colValues,
    ~rowLabels,
    ~colLabels,
  )

describe("TimeGrid.axis", () => {
  test("the values the data holds, when the author declared none", () => {
    expect(TimeGrid.axis(lessons, ~field="giorno", ~declared="")->Array.join(","))->toBe("lun,mar")
  })

  // The one ordering rule worth a test of its own: an hour is a number, and text
  // ordering would put the tenth hour between the first and the second.
  test("numbers order as numbers", () => {
    expect(TimeGrid.axis(lessons, ~field="ora", ~declared="")->Array.join(","))->toBe("1,2,9,10")
  })

  test("declared values keep the author's order", () => {
    expect(
      TimeGrid.axis(lessons, ~field="giorno", ~declared="lun, mar, mer")->Array.join(","),
    )->toBe("lun,mar,mer")
  })

  // A value nobody predicted is appended rather than hidden — the board's rule, and
  // for the same reason: a lesson that disappears because someone typed an hour the
  // author did not list is the worst failure this view could have.
  test("a value the author did not declare is appended, never dropped", () => {
    expect(TimeGrid.axis(lessons, ~field="ora", ~declared="1,2")->Array.join(","))->toBe("1,2,9,10")
  })

  test("a blank field name has no values at all", () => {
    expect(TimeGrid.axis(lessons, ~field="", ~declared="")->Array.length)->toBe(0)
  })
})

describe("TimeGrid.labelled", () => {
  test("the nth label names the nth value", () => {
    expect(["1", "2"]->TimeGrid.labelled(~labels="Prima, Seconda")->Array.join(","))->toBe(
      "Prima,Seconda",
    )
  })

  test("a value the list does not reach keeps its own text", () => {
    expect(["1", "2", "3"]->TimeGrid.labelled(~labels="Prima")->Array.join(","))->toBe("Prima,2,3")
    expect(["1"]->TimeGrid.labelled(~labels="")->Array.join(","))->toBe("1")
  })
})

describe("TimeGrid.build", () => {
  test("a record lands in the cell its two fields name", () => {
    let built = grid(lessons)
    expect(built.rows->Array.join(","))->toBe("1,2,9,10")
    expect(built.cols->Array.join(","))->toBe("lun,mar")
    let at = (r, c) =>
      built.cells
      ->Array.getUnsafe(r)
      ->Array.getUnsafe(c)
      ->Array.map(record => record.Collection.id)
      ->Array.join(",")
    expect(at(0, 0))->toBe("l1")
    expect(at(1, 0))->toBe("l2")
    expect(at(2, 1))->toBe("l4")
    expect(at(3, 1))->toBe("l3")
    // Every other cell of the grid is empty, which is what an empty slot is.
    expect(at(0, 1))->toBe("")
  })

  test("declared values make cells that hold nothing yet", () => {
    let built = grid(lessons, ~colValues="lun,mar,mer,gio,ven")
    expect(built.cols->Array.join(","))->toBe("lun,mar,mer,gio,ven")
    expect(built.cells->Array.getUnsafe(0)->Array.length)->toBe(5)
    expect(built.cells->Array.getUnsafe(0)->Array.getUnsafe(2)->Array.length)->toBe(0)
  })

  // Half-placed rows are the normal state of a timetable being built: they are handed
  // back so the view can say how many are still waiting, not silently forgotten.
  test("a record missing either value is in no cell", () => {
    let waiting = row("l5", [("ora", "1"), ("disciplina", "Arte")])
    let built = grid(lessons->Array.concat([waiting]))
    expect(built.unplaced->Array.map(record => record.Collection.id)->Array.join(","))->toBe("l5")
    let placed =
      built.cells->Array.reduce(0, (total, line) =>
        line->Array.reduce(total, (count, cell) => count + cell->Array.length)
      )
    expect(placed)->toBe(4)
  })

  test("labels travel with the axes", () => {
    let built = grid(lessons, ~colValues="lun,mar", ~colLabels="Lunedì,Martedì")
    expect(built.colLabels->Array.join(","))->toBe("Lunedì,Martedì")
    // No labels declared: the headings are the values, which is what a grid of hours
    // wants anyway.
    expect(built.rowLabels->Array.join(","))->toBe("1,2,9,10")
  })
})

describe("TimeGrid blocks", () => {
  let forbidden = TimeGrid.blocks([
    row("b1", [("row", "1"), ("col", "lun"), ("why", "Il docente non c'è")]),
    row("b2", [("row", "2"), ("col", "mar"), ("for", "l2")]),
  ])

  test("a block without for forbids the cell to everyone", () => {
    expect(TimeGrid.refusal(forbidden, ~row="1", ~col="lun", ~id="l9"))->toEqual(
      Some("Il docente non c'è"),
    )
  })

  // A refusal with no words is still a refusal: the sentence is the caller's, because
  // it is words and this module has no language.
  test("a block for one row forbids it only to that row", () => {
    expect(TimeGrid.refusal(forbidden, ~row="2", ~col="mar", ~id="l2"))->toEqual(Some(""))
    expect(TimeGrid.refusal(forbidden, ~row="2", ~col="mar", ~id="l7"))->toEqual(None)
  })

  test("a cell nobody spoke about is free", () => {
    expect(TimeGrid.refusal(forbidden, ~row="9", ~col="ven", ~id="l1"))->toEqual(None)
  })

  test("a cell spoken for by another row is a warning, not a refusal", () => {
    expect(TimeGrid.warned(forbidden, ~row="2", ~col="mar", ~id="l7"))->toBe(true)
    expect(TimeGrid.warned(forbidden, ~row="2", ~col="mar", ~id="l2"))->toBe(false)
    expect(TimeGrid.warned(forbidden, ~row="1", ~col="lun", ~id="l7"))->toBe(false)
  })
})

describe("TimeGrid.pinned", () => {
  test("a pinned row is one whose field holds a tick", () => {
    let fixed = row("l6", [("fisso", "true")])
    expect(TimeGrid.pinned(fixed, ~field="fisso"))->toBe(true)
    expect(TimeGrid.pinned(row("l7", [("fisso", "false")]), ~field="fisso"))->toBe(false)
    expect(TimeGrid.pinned(row("l8", []), ~field="fisso"))->toBe(false)
    // No pin attribute at all: nothing is pinned, so everything drags.
    expect(TimeGrid.pinned(fixed, ~field=""))->toBe(false)
  })
})
