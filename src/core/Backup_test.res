open BunTest

let record = (id, pairs) => {
  Collection.id,
  fields: pairs->Array.map(((name, value)) => {Collection.name, value}),
}

let grades =
  Collection.empty
  ->Collection.insert(record("r1", [("student", "Ada"), ("grade", "9")]))
  ->Collection.insert(record("r2", [("student", "Grace"), ("grade", "8")]))

let file = Backup.encode("grade-book", "2026-06-27T10:00:00Z", [("grades", grades)])

let decoded = () => Backup.decode(file)

describe("Backup round-trip", () => {
  test("restores the app it came from", () => {
    switch decoded() {
    | Ok(backup) => expect(backup.app)->toBe("grade-book")
    | Error(_) => expect("decoded")->toBe("failed")
    }
  })

  test("restores every collection and record", () => {
    switch decoded() {
    | Ok(backup) =>
      expect(Backup.paths(backup)->Array.join(","))->toBe("grades")
      let restored = Backup.collection(backup, "grades")->Option.getOrThrow
      expect(Collection.size(restored))->toBe(2)
      let ada = restored->Collection.find("r1")->Option.getOrThrow
      expect(Collection.field(ada, "student")->Option.getOr(""))->toBe("Ada")
      expect(Collection.field(ada, "grade")->Option.getOr(""))->toBe("9")
    | Error(_) => expect("decoded")->toBe("failed")
    }
  })

  test("keeps the timestamp it was given", () => {
    switch decoded() {
    | Ok(backup) => expect(backup.exportedAt)->toBe("2026-06-27T10:00:00Z")
    | Error(_) => expect("decoded")->toBe("failed")
    }
  })

  test("an empty app round-trips to an empty backup", () => {
    switch Backup.decode(Backup.encode("empty", "now", [])) {
    | Ok(backup) => expect(Backup.paths(backup)->Array.length)->toBe(0)
    | Error(_) => expect("decoded")->toBe("failed")
    }
  })
})

let errorOf = text =>
  switch Backup.decode(text) {
  | Error(error) => Backup.errorToString(error)
  | Ok(_) => "unexpectedly ok"
  }

describe("Backup.decode — refusals", () => {
  // Every one of these would otherwise look like "the app has no data".
  test("rejects text that is not JSON", () => {
    expect(errorOf("not json at all"))->toBe("The file is not valid JSON.")
  })

  test("rejects JSON that is not a backup", () => {
    expect(errorOf(`{"hello":"world"}`))->toBe("The file is not a ReactiveNET backup.")
  })

  test("rejects a future or missing format version", () => {
    expect(errorOf(`{"app":"x","collections":{},"formatVersion":99}`))->toBe(
      "Backup format 99 is not supported (expected 1).",
    )
    expect(errorOf(`{"app":"x","collections":{}}`))->toBe(
      "Backup format 0 is not supported (expected 1).",
    )
  })
})

describe("Backup.belongsTo", () => {
  // Restoring one app's data into another corrupts both, so the caller is forced to
  // ask rather than being handed a silent merge.
  test("reports whether the backup matches the target app", () => {
    switch decoded() {
    | Ok(backup) =>
      expect(Backup.belongsTo(backup, "grade-book"))->toBe(true)
      expect(Backup.belongsTo(backup, "another-app"))->toBe(false)
    | Error(_) => expect("decoded")->toBe("failed")
    }
  })
})
