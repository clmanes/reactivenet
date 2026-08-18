open BunTest

describe("DirectiveClass", () => {
  // The rule this file exists to keep: a directive nobody filed would fall into no
  // menu group at all, and a menu group nobody notices is missing is a directive
  // nobody can find.
  test("every directive in the registry has a class", () => {
    let unfiled =
      DirectiveRegistry.all
      ->Array.filter(component => DirectiveClass.of_(component.SpectrumRegistry.directive)->Option.isNone)
      ->Array.map(component => component.SpectrumRegistry.directive)
    expect(unfiled->Array.join(", "))->toBe("")
  })

  test("no directive is filed twice", () => {
    let counted =
      DirectiveClass.members->Array.reduce([], (all, (_, names)) => all->Array.concat(names))
    let duplicated =
      counted->Array.filter(name =>
        counted->Array.filter(other => other == name)->Array.length > 1
      )
    expect(duplicated->Array.join(", "))->toBe("")
  })

  test("each class has a heading of its own", () => {
    let labels = DirectiveClass.all->Array.map(class => Translations.translate(En, DirectiveClass.label(class)))
    expect(labels->Array.length)->toBe(12)
    let unique =
      labels->Array.reduce([], (all, one) => all->Array.includes(one) ? all : all->Array.concat([one]))
    expect(unique->Array.length)->toBe(labels->Array.length)
  })

  test("a directive is named the way it is written", () => {
    expect(DirectiveClass.written("accordion-item"))->toBe("::accordion-item")
    expect(DirectiveClass.written("board"))->toBe("::board")
    // One colon for the inline ones, because that is how they are typed.
    expect(DirectiveClass.written("value"))->toBe(":value")
    expect(DirectiveClass.written("sum"))->toBe(":sum")
  })
})
