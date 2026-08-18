open BunTest

let describe_ = line =>
  switch DirectiveCompletion.analyse(line) {
  | Directive({prefix, colons}) => "directive/" ++ colons->Int.toString ++ ":" ++ prefix
  | Attribute({directive, prefix}) => "attribute/" ++ directive ++ ":" ++ prefix
  | Value({directive, attribute, prefix}) => "value/" ++ directive ++ "." ++ attribute ++ ":" ++ prefix
  | Prose(prefix) => "prose:" ++ prefix
  }

describe("DirectiveCompletion.analyse", () => {
  // The colons are counted, not classified: one is inline and two is a block, but
  // whether that block is completed with a close is the component's business.
  test("counts the colons that were typed", () => {
    expect(describe_(":val"))->toBe("directive/1:val")
    expect(describe_("::sli"))->toBe("directive/2:sli")
  })

  // Three colons are not the grammar any more, so they are not a directive.
  test("a run of three or more colons is prose", () => {
    expect(describe_(":::acc"))->toBe("prose:acc")
    expect(describe_("::::acc"))->toBe("prose:acc")
  })

  test("recognises a directive with no name yet", () => {
    expect(describe_("::"))->toBe("directive/2:")
  })

  test("recognises a directive typed mid-sentence", () => {
    expect(describe_("Volume is :val"))->toBe("directive/1:val")
  })

  test("offers attributes inside an open brace", () => {
    expect(describe_(`::slider[v]{`))->toBe("attribute/slider:")
    expect(describe_(`::slider[v]{mi`))->toBe("attribute/slider:mi")
  })

  test("offers the next attribute after one is written", () => {
    expect(describe_(`::slider[v]{min="0" ma`))->toBe("attribute/slider:ma")
  })

  test("offers values once past the equals sign", () => {
    expect(describe_(`::slider[v]{label-visibility="`))->toBe("value/slider.label-visibility:")
    expect(describe_(`::slider[v]{label-visibility="te`))->toBe("value/slider.label-visibility:te")
  })

  // The cases that must NOT look like a directive.
  test("a closed brace is no longer an attribute list", () => {
    expect(describe_(`::slider[v]{min="0"} and then`))->toBe("prose:then")
  })

  // What matters is that it is prose; "30" is simply the word prefix a snippet
  // search would use.
  test("a time of day is not a directive", () => {
    expect(describe_("Meeting at 10:30"))->toBe("prose:30")
  })

  test("a brace with no directive before it is prose", () => {
    expect(describe_("a set {"))->toBe("prose:")
  })

  test("plain text is prose", () => {
    expect(describe_("just writing here"))->toBe("prose:here")
  })
})

let registry = DirectiveRegistry.all
let labels = context =>
  DirectiveCompletion.completions(context, registry)
  ->Array.map(c => c.DirectiveCompletion.label)

describe("DirectiveCompletion.completions", () => {
  test("offers matching directives", () => {
    let found = labels(DirectiveCompletion.analyse("::slid"))
    expect(found->Array.includes("slider"))->toBe(true)
  })

  test("offers every component when nothing is typed yet", () => {
    expect(labels(DirectiveCompletion.analyse("::"))->Array.length)->toBe(registry->Array.length)
  })

  test("offers the attributes of that component only", () => {
    let found = labels(DirectiveCompletion.analyse(`::slider[v]{`))
    expect(found->Array.includes("min"))->toBe(true)
    expect(found->Array.includes("label-visibility"))->toBe(true)
    // sp-badge's attribute, which a slider does not have.
    expect(found->Array.includes("fixed"))->toBe(false)
  })

  test("offers the allowed values of a choice attribute", () => {
    let found = labels(DirectiveCompletion.analyse(`::slider[v]{label-visibility="`))
    expect(found->Array.join(","))->toBe("text,value,none")
  })

  test("offers true and false for a flag", () => {
    let found = labels(DirectiveCompletion.analyse(`::slider[v]{disabled="`))
    expect(found->Array.join(","))->toBe("true,false")
  })

  test("offers nothing for an unknown component", () => {
    expect(labels(DirectiveCompletion.analyse(`::nonesuch{`))->Array.length)->toBe(0)
  })

  // A flag carries no value, so its insertion must not open a pair of quotes.
  test("inserts a flag without an empty value", () => {
    let inserts =
      DirectiveCompletion.completions(DirectiveCompletion.analyse(`::slider[v]{disab`), registry)
      ->Array.map(c => c.DirectiveCompletion.insert)
    expect(inserts->Array.join(","))->toBe("disabled")
  })

  test("falls back to markdown snippets in prose", () => {
    expect(labels(DirectiveCompletion.analyse("h"))->Array.join(","))->toBe("h1,h2,h3,hr")
  })
})

// One block form: the author types `::` for everything, and what comes back depends
// on whether the component can hold content.
describe("DirectiveCompletion blocks", () => {
  let registry = DirectiveRegistry.all

  let insertFor = (line, directive) =>
    DirectiveCompletion.completions(DirectiveCompletion.analyse(line), registry)
    ->Array.find(c => c.DirectiveCompletion.label == directive)
    ->Option.getOrThrow

  test("closes a container with its own name", () => {
    expect(insertFor("::acc", "accordion").insert)->toBe("::accordion{}\n\n::/accordion")
    expect(insertFor("::for", "form").insert)->toBe("::form{}\n\n::/form")
  })

  test("leaves a component that holds nothing unclosed", () => {
    expect(insertFor("::sli", "slider").insert)->toBe("::slider[]{}")
    expect(insertFor("::sav", "save").insert)->toBe("::save[]{}")
  })

  // The snippet carries its own colons, so the ones already typed are part of what it
  // replaces — otherwise accepting it writes them twice.
  test("reports the colons the editor must replace", () => {
    expect(insertFor("::acc", "accordion").back)->toBe(2)
    expect(insertFor("::sli", "slider").back)->toBe(2)
    expect(insertFor(":sli", "slider").back)->toBe(1)
  })

  test("the caret lands in the attribute list, not in the colons", () => {
    let accordion = insertFor("::acc", "accordion")
    expect(accordion.insert->String.charAt(accordion.caret))->toBe("}")
  })
})
