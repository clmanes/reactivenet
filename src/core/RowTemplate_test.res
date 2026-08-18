open BunTest

let row = (fields): Collection.record => {
  id: "r1",
  fields: fields->Array.map(((name, value)): Collection.field => {name, value}),
}

describe("RowTemplate.tokens", () => {
  test("lists the fields a template refers to, in order", () => {
    expect(RowTemplate.fields("{name} — {mark} ({name})")->Array.join(","))->toBe("name,mark")
  })

  test("ignores braces that are not field names", () => {
    expect(RowTemplate.tokens("a { b } c")->Array.length)->toBe(0)
    expect(RowTemplate.fields("${total}")->Array.join(","))->toBe("total")
    expect(RowTemplate.tokens("{}")->Array.length)->toBe(0)
    expect(RowTemplate.tokens("{2fast}")->Array.length)->toBe(0)
  })

  // A relation is written where it is read: the token names the collection, so a list
  // far from the form that made the reference still says what it is pointing at.
  test("reads a reference token", () => {
    expect(RowTemplate.tokens("{who>people.name}"))->toEqual([
      RowTemplate.Ref({field: "who", path: "people", label: "name"}),
    ])
    expect(RowTemplate.fields("{who>people.name} {what}")->Array.join(","))->toBe("who,what")
    expect(RowTemplate.referenced("{who>people.name} {what}")->Array.join(","))->toBe("people")
  })

  test("half a reference is not a token", () => {
    expect(RowTemplate.tokens("{who>people}")->Array.length)->toBe(0)
    expect(RowTemplate.tokens("{who>.name}")->Array.length)->toBe(0)
    expect(RowTemplate.tokens("{>people.name}")->Array.length)->toBe(0)
  })
})

describe("RowTemplate.fill", () => {
  test("substitutes each field", () => {
    let record = row([("name", "Ada"), ("mark", "30")])
    expect(RowTemplate.fill("{name}: {mark}", record))->toBe("Ada: 30")
  })

  test("a field the row does not have becomes the fallback", () => {
    expect(RowTemplate.fill("{missing}", row([]), ~fallback="—"))->toBe("—")
    expect(RowTemplate.fill("{missing}", row([])))->toBe("")
  })

  test("leaves unrecognised braces exactly as written", () => {
    expect(RowTemplate.fill("a { b } c", row([])))->toBe("a { b } c")
    expect(RowTemplate.fill("{ name }", row([("name", "Ada")])))->toBe("{ name }")
  })

  // The value is substituted as text and the binder writes it into a text node, so a
  // row carrying markup is a row that displays those characters.
  test("does not interpret a value as markup", () => {
    let record = row([("name", "<script>alert(1)</script>")])
    expect(RowTemplate.fill("{name}", record))->toBe("<script>alert(1)</script>")
  })

  test("an unterminated token ends the substitution rather than eating the text", () => {
    expect(RowTemplate.fill("ok {name", row([("name", "Ada")])))->toBe("ok {name")
  })

  test("a reference is resolved through the collection it names", () => {
    let record = row([("what", "Bread"), ("who", "p1")])
    let resolve = (~path, ~id, ~label) =>
      path == "people" && id == "p1" && label == "name" ? Some("Ada") : None
    expect(RowTemplate.fill("{what} — {who>people.name}", record, ~resolve))->toBe("Bread — Ada")
  })

  // A row someone deleted leaves an id nobody can read behind. The fallback is a
  // better answer than the id.
  test("a reference whose row has gone becomes the fallback", () => {
    let record = row([("who", "p9")])
    let resolve = (~path as _, ~id as _, ~label as _) => None
    expect(RowTemplate.fill("{who>people.name}", record, ~fallback="—", ~resolve))->toBe("—")
  })

  test("an empty reference field is not looked up at all", () => {
    let asked = ref(0)
    let resolve = (~path as _, ~id as _, ~label as _) => {
      asked := asked.contents + 1
      Some("never")
    }
    expect(RowTemplate.fill("{who>people.name}", row([("who", "")]), ~fallback="—", ~resolve))->toBe("—")
    expect(asked.contents)->toBe(0)
  })
})

describe("RecordId.make", () => {
  test("uses the clock's reading, stripped to id characters", () => {
    expect(RecordId.make(~stamp="2026-08-10T09:15:00.000Z", ~taken=[]))->toBe(
      "20260810T091500000Z",
    )
  })

  test("counts up when the same instant is used twice", () => {
    let first = RecordId.make(~stamp="2026-08-10T09:15:00.000Z", ~taken=[])
    let second = RecordId.make(~stamp="2026-08-10T09:15:00.000Z", ~taken=[first])
    expect(second)->toBe(first ++ "-1")
  })
})
