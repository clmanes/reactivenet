open BunTest

let record = (id, pairs) => {
  Collection.id,
  fields: pairs->Array.map(((name, value)) => {Collection.name, value}),
}

let sample =
  Collection.empty
  ->Collection.insert(record("r1", [("student", "Ada"), ("grade", "9")]))
  ->Collection.insert(record("r2", [("student", "Grace"), ("grade", "8")]))

let names = collection =>
  collection.Collection.records
  ->Array.map(r => Collection.field(r, "student")->Option.getOr("?"))
  ->Array.join(",")

describe("Collection", () => {
  test("inserts in order", () => {
    expect(names(sample))->toBe("Ada,Grace")
    expect(Collection.size(sample))->toBe(2)
  })

  test("finds a record by id", () => {
    expect(sample->Collection.find("r2")->Option.isSome)->toBe(true)
    expect(sample->Collection.find("nope")->Option.isNone)->toBe(true)
  })

  test("looks up fields case-insensitively", () => {
    let ada = sample->Collection.find("r1")->Option.getOrThrow
    expect(Collection.field(ada, "STUDENT")->Option.getOr(""))->toBe("Ada")
    expect(Collection.field(ada, "absent")->Option.isNone)->toBe(true)
  })

  // Deleting must not renumber: a reference to r2 has to keep meaning r2.
  test("removing a record leaves the others addressable", () => {
    let after = sample->Collection.remove("r1")
    expect(names(after))->toBe("Grace")
    expect(after->Collection.find("r2")->Option.isSome)->toBe(true)
  })

  test("removing an unknown id changes nothing", () => {
    expect(sample->Collection.remove("nope")->Collection.size)->toBe(2)
  })

  test("updating replaces only the named fields", () => {
    let after = sample->Collection.update("r1", [{Collection.name: "grade", value: "10"}])
    let ada = after->Collection.find("r1")->Option.getOrThrow
    expect(Collection.field(ada, "grade")->Option.getOr(""))->toBe("10")
    expect(Collection.field(ada, "student")->Option.getOr(""))->toBe("Ada")
  })

  test("updating adds a field the record did not have", () => {
    let after = sample->Collection.update("r2", [{Collection.name: "note", value: "late"}])
    let grace = after->Collection.find("r2")->Option.getOrThrow
    expect(Collection.field(grace, "note")->Option.getOr(""))->toBe("late")
    expect(grace.fields->Array.length)->toBe(3)
  })

  test("updating an unknown id changes nothing", () => {
    let after = sample->Collection.update("nope", [{Collection.name: "grade", value: "0"}])
    expect(names(after))->toBe("Ada,Grace")
  })

  test("an empty collection reports itself as such", () => {
    expect(Collection.empty->Collection.isEmpty)->toBe(true)
    expect(sample->Collection.isEmpty)->toBe(false)
  })
})
