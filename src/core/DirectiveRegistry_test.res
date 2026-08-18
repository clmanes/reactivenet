open BunTest

describe("DirectiveRegistry", () => {
  // Ours plus Spectrum's, less the names that appear in both — where ours wins,
  // because it is the one the renderer actually handles.
  let ours = DirectiveRegistry.reactive->Array.map(c => c.SpectrumRegistry.directive)
  let shadowed =
    SpectrumRegistry.all->Array.filter(c => ours->Array.includes(c.SpectrumRegistry.directive))

  test("carries every generated component, plus this app's own", () => {
    expect(DirectiveRegistry.all->Array.length)->toBe(
      SpectrumRegistry.all->Array.length +
      DirectiveRegistry.reactive->Array.length -
      shadowed->Array.length,
    )
    // Every name still resolves; the shadowed ones resolve to ours.
    let missing =
      SpectrumRegistry.all
      ->Array.filter(component =>
        DirectiveRegistry.find(component.SpectrumRegistry.directive)->Option.isNone
      )
      ->Array.length
    expect(missing)->toBe(0)
  })

  // Stated rather than discovered: `::table` is the rows of a collection, and it
  // takes the name from `sp-table`, which is a layout component nobody hand-writes
  // one row at a time. A new collision is a decision, so it should fail here first.
  test("exactly the expected names shadow a Spectrum component", () => {
    expect(shadowed->Array.map(c => c.SpectrumRegistry.directive)->Array.join(","))->toBe("table")
  })

  // The page menu offers Spectrum's icons and nothing else: a name outside the set
  // would upgrade to no element and leave a gap the author cannot see.
  test("the page icon is chosen from Spectrum's own set", () => {
    let page = DirectiveRegistry.find("page")->Option.getOrThrow
    let icon =
      page.attributes
      ->Array.find(a => a.SpectrumRegistry.name == "icon")
      ->Option.getOrThrow
    expect(icon.kind == Choice)->toBe(true)
    expect(icon.choices->Array.length)->toBe(SpectrumIcons.all->Array.length)
    expect(icon.choices->Array.includes("data"))->toBe(true)
  })

  test("the data directives are described where every consumer reads", () => {
    ["form", "input", "save", "list", "if-any", "if-empty", "count", "sum", "calc"]
    ->Array.forEach(name => expect(DirectiveRegistry.find(name)->Option.isSome)->toBe(true))
  })

  test("directive names stay unique", () => {
    let names = DirectiveRegistry.all->Array.map(c => c.SpectrumRegistry.directive)
    let unique =
      names->Array.reduce([], (acc, n) => acc->Array.includes(n) ? acc : acc->Array.concat([n]))
    expect(unique->Array.length)->toBe(names->Array.length)
  })

  // Spectrum composes an accordion as a wrapper around items, so both are ordinary
  // registry components and the source nests one inside the other. The app renders
  // neither by hand.
  test("the accordion is Spectrum's, not a hand-rolled details element", () => {
    let accordion = DirectiveRegistry.find("accordion")->Option.getOrThrow
    expect(accordion.tag)->toBe("sp-accordion")
    let item = DirectiveRegistry.find("accordion-item")->Option.getOrThrow
    expect(item.tag)->toBe("sp-accordion-item")
    let names = item.attributes->Array.map(a => a.SpectrumRegistry.name)
    expect(names->Array.includes("label"))->toBe(true)
    expect(names->Array.includes("open"))->toBe(true)
  })

  // Every element can be pointed at, so `id` has to be offered on every one of them —
  // the manifests describe each component's own API and stop there.
  test("id is available on every component", () => {
    let without =
      DirectiveRegistry.all
      ->Array.filter(c => !(c.attributes->Array.some(a => a.SpectrumRegistry.name == "id")))
      ->Array.map(c => c.SpectrumRegistry.directive)
      ->Array.join(",")
    expect(without)->toBe("")
  })

  test("a global attribute never displaces a component's own", () => {
    let slider = DirectiveRegistry.find("slider")->Option.getOrThrow
    let ids = slider.attributes->Array.filter(a => a.SpectrumRegistry.name == "id")
    expect(ids->Array.length)->toBe(1)
  })

  // ::choose is the only directive of our own package that is a SOURCE: the brackets
  // are the reactive key it writes, and the rest of the machinery already knows what
  // to do with one. Two things elsewhere depend on the shape asserted here and would
  // fail silently if it drifted — the renderer refuses the directive without `path`,
  // and the MCP analyzer registers `choose` as a key writer by name, so a rename here
  // would make it report every key this feeds as written by nobody.
  test("choose reads a collection and stores a field of the chosen row", () => {
    let choose = DirectiveRegistry.find("choose")->Option.getOrThrow
    expect(choose.tag)->toBe("select")
    expect(choose.package)->toBe("reactivenet")
    let names = choose.attributes->Array.map(a => a.SpectrumRegistry.name)
    // path is where the options come from; field and label are what is stored and
    // what is shown, which are almost never the same column.
    expect(["path", "field", "label"]->Array.every(n => names->Array.includes(n)))->toBe(true)
  })

  // The two controls that produce the two sides of the central rule: ::input fills a
  // form's DRAFT, ::choose writes a REACTIVE KEY. Merging them into one directive with
  // a flag is the change this test exists to make somebody argue for out loud.
  test("choose is not a form field: it has no field-of-a-form attributes", () => {
    let choose = DirectiveRegistry.find("choose")->Option.getOrThrow
    let names = choose.attributes->Array.map(a => a.SpectrumRegistry.name)
    expect(names->Array.includes("form"))->toBe(false)
    expect(names->Array.includes("required"))->toBe(false)
  })

  test("a component is otherwise passed through unchanged", () => {
    let slider = DirectiveRegistry.find("slider")->Option.getOrThrow
    expect(slider.tag)->toBe("sp-slider")
    expect(slider.attributes->Array.length > 15)->toBe(true)
  })
})
