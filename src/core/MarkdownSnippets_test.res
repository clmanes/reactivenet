open BunTest

let labels = snippets => snippets->Array.map(s => s.MarkdownSnippets.label)->Array.join(",")

describe("MarkdownSnippets.matching", () => {
  test("an empty prefix offers every snippet", () => {
    expect(MarkdownSnippets.matching("")->Array.length)->toBe(MarkdownSnippets.all->Array.length)
  })

  test("whitespace counts as empty", () => {
    expect(MarkdownSnippets.matching("   ")->Array.length)->toBe(
      MarkdownSnippets.all->Array.length,
    )
  })

  test("matches on prefix", () => {
    expect(MarkdownSnippets.matching("h")->labels)->toBe("h1,h2,h3,hr")
  })

  test("ignores case", () => {
    expect(MarkdownSnippets.matching("MERM")->labels)->toBe("mermaid")
  })

  test("returns nothing when no snippet matches", () => {
    expect(MarkdownSnippets.matching("zzz")->Array.length)->toBe(0)
  })

  test("matches a prefix, not a substring", () => {
    expect(MarkdownSnippets.matching("ermaid")->Array.length)->toBe(0)
  })
})

describe("MarkdownSnippets.all", () => {
  test("every caret lands inside its own snippet", () => {
    let offenders =
      MarkdownSnippets.all
      ->Array.filter(s => s.caret < 0 || s.caret > String.length(s.insert))
      ->Array.map(s => s.MarkdownSnippets.label)
      ->Array.join(",")
    expect(offenders)->toBe("")
  })

  test("labels are unique", () => {
    let labels = MarkdownSnippets.all->Array.map(s => s.MarkdownSnippets.label)
    let unique = labels->Array.reduce([], (acc, label) =>
      acc->Array.includes(label) ? acc : acc->Array.concat([label])
    )
    expect(unique->Array.length)->toBe(labels->Array.length)
  })
})
