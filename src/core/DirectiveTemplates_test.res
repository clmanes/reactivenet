open BunTest

let formName = form =>
  switch form {
  | DirectiveScan.Inline => "inline"
  | DirectiveScan.Leaf => "leaf"
  | DirectiveScan.Container => "container"
  }

describe("DirectiveTemplates", () => {
  // The property worth testing: an offered template must parse back into exactly the
  // directive it claims to be, or the "add" button inserts something inert.
  test("every template scans back to its own form and name", () => {
    let broken =
      DirectiveTemplates.all
      ->Array.filter(template => {
        switch DirectiveScan.scan(template.snippet)->Array.at(0) {
        | Some(found) => found.DirectiveScan.name != template.name || found.form != template.form
        | None => true
        }
      })
      ->Array.map(template => template.DirectiveTemplates.label)
      ->Array.join(",")
    expect(broken)->toBe("")
  })

  test("every template yields exactly one directive", () => {
    let wrong =
      DirectiveTemplates.all
      ->Array.filter(t => DirectiveScan.scan(t.snippet)->Array.length != 1)
      ->Array.length
    expect(wrong)->toBe(0)
  })

  test("labels are unique", () => {
    let labels = DirectiveTemplates.all->Array.map(t => t.DirectiveTemplates.label)
    let unique =
      labels->Array.reduce([], (acc, l) => acc->Array.includes(l) ? acc : acc->Array.concat([l]))
    expect(unique->Array.length)->toBe(labels->Array.length)
  })

  test("covers all three directive forms", () => {
    expect(
      DirectiveTemplates.all->Array.map(t => formName(t.DirectiveTemplates.form))->Array.join(","),
    )->toBe("inline,leaf,container")
  })
})

describe("DirectiveTemplates.append", () => {
  let slider = DirectiveTemplates.all->Array.getUnsafe(1)

  test("separates the snippet from existing content", () => {
    expect(DirectiveTemplates.append("# Title", slider))->toBe("# Title\n\n" ++ slider.snippet ++ "\n")
  })

  test("does not open an empty document with blank lines", () => {
    expect(DirectiveTemplates.append("", slider))->toBe(slider.snippet ++ "\n")
  })

  test("the appended directive is findable", () => {
    let source = DirectiveTemplates.append("# Title", slider)
    expect(DirectiveScan.scan(source)->Array.length)->toBe(1)
  })
})
