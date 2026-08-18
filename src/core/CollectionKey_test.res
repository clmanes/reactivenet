open BunTest

describe("CollectionKey", () => {
  test("namespaces a collection by its app", () => {
    expect(CollectionKey.of_(~app="grade-book", ~path="grades"))->toBe("app/grade-book/grades")
  })

  test("reads the path back", () => {
    let key = CollectionKey.of_(~app="grade-book", ~path="grades")
    expect(CollectionKey.pathOf(~app="grade-book", key)->Option.getOr("none"))->toBe("grades")
  })

  // The reason the separator is part of the prefix: without it "grade" would match
  // every key of "grade-book" and one app would read another's data.
  test("an app does not match another whose id merely starts the same", () => {
    let key = CollectionKey.of_(~app="grade-book", ~path="grades")
    expect(CollectionKey.pathOf(~app="grade", key)->Option.isNone)->toBe(true)
  })

  test("rejects keys of a different app", () => {
    let key = CollectionKey.of_(~app="other", ~path="grades")
    expect(CollectionKey.pathOf(~app="grade-book", key)->Option.isNone)->toBe(true)
  })

  test("rejects keys that are not collections at all", () => {
    expect(CollectionKey.pathOf(~app="grade-book", "theme")->Option.isNone)->toBe(true)
    expect(CollectionKey.isCollection("theme"))->toBe(false)
    expect(CollectionKey.isCollection("locale"))->toBe(false)
  })

  test("recognises its own keys", () => {
    expect(CollectionKey.isCollection(CollectionKey.of_(~app="a", ~path="b")))->toBe(true)
  })

  test("a path with slashes survives", () => {
    let key = CollectionKey.of_(~app="a", ~path="nested/path")
    expect(CollectionKey.pathOf(~app="a", key)->Option.getOr("none"))->toBe("nested/path")
  })
})
