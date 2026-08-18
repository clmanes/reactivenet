open BunTest

let row = (id, fields): Collection.record => {
  id,
  fields: fields->Array.map(((name, value)): Collection.field => {name, value}),
}

let marks = {
  Collection.records: [
    row("1", [("name", "Ada"), ("mark", "30")]),
    row("2", [("name", "Bo"), ("mark", "24")]),
    row("3", [("name", "Cy"), ("mark", "")]),
    row("4", [("name", "Ada"), ("mark", "27")]),
  ],
}

let compute = (name, ~field="mark", ~decimals=?) =>
  Aggregate.parse(name)
  ->Option.flatMap(kind => Aggregate.compute(kind, marks, ~field, ~decimals?))
  ->Option.getOr("—")

describe("Aggregate", () => {
  test("counts rows, not values", () => {
    expect(compute("count"))->toBe("4")
  })

  // A blank is not a zero: an average over four rows where one was left empty is an
  // average of three, and the other answer is quietly wrong.
  test("skips values that do not read as numbers", () => {
    expect(compute("sum"))->toBe("81")
    expect(compute("avg"))->toBe("27")
  })

  // A date is not a number that happens to begin with one. Summing a field of dates
  // used to total the years — an answer, just not to any question anyone asked.
  test("a date is not counted as the year it starts with", () => {
    let dated = {
      Collection.records: [
        row("1", [("due", "2026-08-12")]),
        row("2", [("due", "2026-08-13")]),
      ],
    }
    expect(Aggregate.compute(Sum, dated, ~field="due")->Option.getOr("—"))->toBe("0")
    expect(Aggregate.compute(Average, dated, ~field="due")->Option.getOr("—"))->toBe("—")
  })

  test("reports the extremes", () => {
    expect(compute("min"))->toBe("24")
    expect(compute("max"))->toBe("30")
  })

  test("median of an even count is the midpoint", () => {
    expect(compute("median"))->toBe("27")
  })

  test("deviation needs two values", () => {
    expect(compute("stddev"))->toBe("3")
    let single = {Collection.records: [row("1", [("mark", "5")])]}
    expect(
      Aggregate.compute(Deviation, single, ~field="mark")->Option.getOr("—"),
    )->toBe("—")
  })

  test("mode works on text, first seen wins a tie", () => {
    expect(compute("mode", ~field="name"))->toBe("Ada")
  })

  test("an empty collection has no average to report", () => {
    expect(
      Aggregate.compute(Average, Collection.empty, ~field="mark")->Option.getOr("—"),
    )->toBe("—")
  })

  test("formats without the zeros division leaves behind", () => {
    expect(Aggregate.format(27.0))->toBe("27")
    expect(Aggregate.format(27.5))->toBe("27.5")
    expect(Aggregate.format(1.0 /. 3.0))->toBe("0.3333")
    expect(Aggregate.format(1.0 /. 3.0, ~decimals=2))->toBe("0.33")
  })

  test("only the aggregation names parse", () => {
    expect(Aggregate.parse("sum")->Option.isSome)->toBe(true)
    expect(Aggregate.parse("slider")->Option.isSome)->toBe(false)
  })
})

describe("Expr.evaluate", () => {
  let store = key =>
    switch key {
    | "price" => Some("10")
    | "qty" => Some("3")
    | "text" => Some("abc")
    | _ => None
    }
  let value = source => Expr.evaluate(source, store)

  test("applies the precedence everyone expects", () => {
    expect(value("2 + 3 * 4"))->toEqual(Some(14.0))
    expect(value("(2 + 3) * 4"))->toEqual(Some(20.0))
  })

  test("resolves reactive keys", () => {
    expect(value("#price * #qty"))->toEqual(Some(30.0))
    expect(value("#price * #qty * 1.22"))->toEqual(Some(36.6))
  })

  // A total that reads NaN until the last field is typed is worse than one that grows.
  test("a missing or non-numeric key counts as zero", () => {
    expect(value("#unknown + 5"))->toEqual(Some(5.0))
    expect(value("#text + 5"))->toEqual(Some(5.0))
    // A date field is text here too: the alternative is a total that quietly adds
    // the year to itself.
    expect(Expr.evaluate("#due + 5", key => key == "due" ? Some("2026-08-12") : None))
    ->toEqual(Some(5.0))
  })

  test("negation works, including on a key", () => {
    expect(value("-#price + 4"))->toEqual(Some(-6.0))
  })

  test("a typo does not evaluate half the expression", () => {
    // 1.2.3 is a typo, not the number 1.2 — parseFloat would have read the prefix.
    expect(value("1.2.3"))->toEqual(None)
    expect(value("2 +"))->toEqual(None)
    expect(value("2 3"))->toEqual(None)
    expect(value("(2 + 3"))->toEqual(None)
    expect(value("2 $ 3"))->toEqual(None)
    expect(value("#"))->toEqual(None)
  })

  test("division by zero has no answer rather than an infinite one", () => {
    expect(value("5 / 0"))->toEqual(None)
    expect(value("5 / #unknown"))->toEqual(None)
  })

  test("lists the keys a view must subscribe to", () => {
    expect(Expr.references("#price * #qty * 1.22")->Array.join(","))->toBe("price,qty")
  })
})

describe("Stamps", () => {
  test("a new row carries both stamps, equal", () => {
    let fields = Stamps.apply([{name: "name", value: "Ada"}], ~now="2026-08-10T09:00:00Z")
    let record: Collection.record = {id: "1", fields}
    expect(Collection.field(record, Stamps.created))->toEqual(Some("2026-08-10T09:00:00Z"))
    expect(Collection.field(record, Stamps.updated))->toEqual(Some("2026-08-10T09:00:00Z"))
  })

  test("an edit moves the modification time and keeps the creation time", () => {
    let fields = Stamps.apply(
      [{name: "name", value: "Ada"}],
      ~now="2026-08-11T10:00:00Z",
      ~createdAt="2026-08-10T09:00:00Z",
    )
    let record: Collection.record = {id: "1", fields}
    expect(Collection.field(record, Stamps.created))->toEqual(Some("2026-08-10T09:00:00Z"))
    expect(Collection.field(record, Stamps.updated))->toEqual(Some("2026-08-11T10:00:00Z"))
  })

  // The names are reserved, so an author's field of the same name cannot fight the
  // system's — it is dropped rather than duplicated.
  test("an authored stamp field is replaced, not duplicated", () => {
    let fields = Stamps.apply(
      [{name: "createdAt", value: "yesterday"}, {name: "name", value: "Ada"}],
      ~now="2026-08-10T09:00:00Z",
    )
    let named = fields->Array.filter(field => field.Collection.name == Stamps.created)
    expect(named->Array.length)->toBe(1)
    let stamp = named->Array.getUnsafe(0)
    expect(stamp.value)->toBe("2026-08-10T09:00:00Z")
  })
})
