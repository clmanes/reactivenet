open BunTest

let document = `# Title

::slider[volume]{min="0" max="100" value="50" legend="Volume"}

Current: :value[v]{ref="#volume"} now.

::accordion{id="a1" title="One" name="faq"}
Body of one.
::/accordion

Tail.`

let summary = source =>
  DirectiveScan.scan(source)
  ->Array.map(o => {
    let form = switch o.DirectiveScan.form {
    | Inline => "inline"
    | Leaf => "leaf"
    | Container => "container"
    }
    form ++ ":" ++ o.name
  })
  ->Array.join(",")

describe("DirectiveScan and braces in a value", () => {
  // A regular expression's own quantifier is a closing brace, and scanning up to the
  // first one ended the attribute list mid-value: the whole line stopped being a
  // directive and the field simply never appeared.
  test("a quoted value may contain a closing brace", () => {
    let found = DirectiveScan.scan("::input{field=\"cap\" pattern=\"[0-9]{5}\" required}")
    expect(found->Array.length)->toBe(1)
    let one = found->Array.getUnsafe(0)
    expect(one.name)->toBe("input")
    expect(one.attributes)->toBe("field=\"cap\" pattern=\"[0-9]{5}\" required")
  })

  test("an unquoted brace still ends the list, so a directive stays one line", () => {
    let found = DirectiveScan.scan("::input{field=cap} }")
    expect(found->Array.length)->toBe(0)
  })

  test("the same holds inline", () => {
    let found = DirectiveScan.scan("Total :calc{expr=\"#a\" pattern=\"{2}\"} here")
    expect(found->Array.length)->toBe(1)
    expect((found->Array.getUnsafe(0)).attributes)->toBe("expr=\"#a\" pattern=\"{2}\"")
  })
})

describe("DirectiveScan.scan", () => {
  test("finds all three forms in document order", () => {
    expect(summary(document))->toBe("leaf:slider,inline:value,container:accordion")
  })

  test("captures label and attributes", () => {
    let first = DirectiveScan.scan(document)->Array.getUnsafe(0)
    expect(first.label)->toBe("volume")
    expect(DirectiveAttributes.attribute(first.attributes, "max")->Option.getOr(""))->toBe("100")
  })

  // The offsets are the whole point: an edit is spliced back by them.
  test("offsets delimit exactly the directive text", () => {
    let inline = DirectiveScan.scan(document)->Array.getUnsafe(1)
    expect(document->String.slice(~start=inline.start, ~end=inline.stop))->toBe(
      `:value[v]{ref="#volume"}`,
    )
  })

  test("a container spans through its close", () => {
    let container = DirectiveScan.scan(document)->Array.getUnsafe(2)
    let text = document->String.slice(~start=container.start, ~end=container.stop)
    expect(text->String.startsWith("::accordion"))->toBe(true)
    expect(text->String.endsWith("::/accordion"))->toBe(true)
    expect(text->String.includes("Body of one."))->toBe(true)
  })

  test("does not rescan a container body as top level", () => {
    let nested = "::accordion{id=\"a\"}\n::slider[v]{}\n::/accordion"
    expect(summary(nested))->toBe("container:accordion")
  })

  test("ignores colons that are not directives", () => {
    expect(summary("Meeting at 10:30, see https://example.com — ratio 3:4."))->toBe("")
  })

  test("finds nothing in a plain document", () => {
    expect(summary("# Just a heading\n\nSome text."))->toBe("")
  })
})

// The grammar: `::name{…}` opens a block, and a `::/name` below it — if there is one
// — makes that block a container. The two are written identically, which is what
// removes the need to count anything.
describe("DirectiveScan blocks", () => {
  test("a block nobody closes is a leaf", () => {
    expect(summary("::slider[v]{min=\"0\"}"))->toBe("leaf:slider")
  })

  test("a block its own close ends is a container", () => {
    let source = "::form{path=\"items\"}\n::input{field=\"name\"}\n::/form"
    expect(summary(source))->toBe("container:form")
    let form = DirectiveScan.scan(source)->Array.getUnsafe(0)
    expect(source->String.slice(~start=form.start, ~end=form.stop))->toBe(source)
  })

  // The case a colon fence could not express: two containers written the same way,
  // one inside the other. Naming the close is what makes it unambiguous.
  test("two containers written alike still nest", () => {
    let source = "::if-any{path=\"p\"}\n::list{path=\"p\"}\n{name}\n::/list\n::/if-any"
    expect(summary(source))->toBe("container:if-any")
    let outer = DirectiveScan.scan(source)->Array.getUnsafe(0)
    expect(source->String.slice(~start=outer.start, ~end=outer.stop))->toBe(source)
  })

  test("a close of the same name is counted by depth", () => {
    let source = "::form{path=\"a\"}\n::form{path=\"b\"}\nx\n::/form\ninside\n::/form\nafter"
    let outer = DirectiveScan.scan(source)->Array.getUnsafe(0)
    let text = source->String.slice(~start=outer.start, ~end=outer.stop)
    expect(text->String.includes("inside"))->toBe(true)
    expect(text->String.includes("after"))->toBe(false)
  })

  test("siblings of the same name each end at their own close", () => {
    let source = "::page{title=\"A\"}\nOne.\n::/page\n\n::page{title=\"B\"}\nTwo.\n::/page"
    expect(summary(source))->toBe("container:page,container:page")
  })

  test("a close with nothing open is not a directive", () => {
    expect(summary("::/form"))->toBe("")
  })

  // Colon fences were the earlier grammar and are not read as one any more: three or
  // more colons on a line are text, like any other punctuation.
  test("a colon fence is not a container", () => {
    expect(summary("::::card{id=\"c\"}\nBody.\n::::"))->toBe("")
    expect(summary(":::accordion{}\nx\n:::"))->toBe("")
  })

  // Written back exactly as it was read, which is what lets the block editor
  // round-trip a document nobody edited.
  test("renders open and close as a pair", () => {
    let open_ = DirectiveScan.render(
      ~form=Container,
      ~name="list",
      ~label="",
      ~attributes=`path="items"`,
    )
    expect(open_ ++ "\nrow\n" ++ DirectiveScan.closing(~name="list"))->toBe(
      "::list{path=\"items\"}\nrow\n::/list",
    )
  })

  // Not a duplication to fold away: a container and a leaf open with the same text,
  // and that is the grammar.
  test("a container and a leaf open identically", () => {
    let of_ = form => DirectiveScan.render(~form, ~name="card", ~label="", ~attributes="")
    expect(of_(Container))->toBe(of_(Leaf))
  })
})

describe("DirectiveScan.replace and remove", () => {
  let scanOne = source => DirectiveScan.scan(source)->Array.getUnsafe(0)

  test("re-rendering an untouched directive leaves the document identical", () => {
    let source = `::slider[volume]{min="0" max="100"}`
    let found = scanOne(source)
    let rendered = DirectiveScan.render(
      ~form=found.form,
      ~name=found.name,
      ~label=found.label,
      ~attributes=found.attributes,
    )
    expect(DirectiveScan.replace(source, found, rendered))->toBe(source)
  })

  test("replaces only the directive, leaving the rest alone", () => {
    let source = "before\n\n::slider[volume]{min=\"0\"}\n\nafter"
    let found = scanOne(source)
    let updated = DirectiveScan.replace(
      source,
      found,
      DirectiveScan.render(~form=Leaf, ~name="slider", ~label="gain", ~attributes=`min="5"`),
    )
    expect(updated)->toBe("before\n\n::slider[gain]{min=\"5\"}\n\nafter")
  })

  test("removing a leaf takes its line with it", () => {
    let source = "before\n::slider[volume]{}\nafter"
    expect(DirectiveScan.remove(source, scanOne(source)))->toBe("before\nafter")
  })

  test("removing an inline directive keeps the surrounding sentence", () => {
    let source = "Volume is :value[v]{ref=\"#volume\"} today."
    expect(DirectiveScan.remove(source, scanOne(source)))->toBe("Volume is  today.")
  })

  test("removing a container removes the body it wrapped", () => {
    let source = "a\n::accordion{id=\"x\"}\ninside\n::/accordion\nb"
    expect(DirectiveScan.remove(source, scanOne(source)))->toBe("a\nb")
  })
})

// Un blocco fenced è codice, e il codice non si scandisce. Il renderer si comporta
// già così — marked tokenizza la fence prima che qualsiasi tokenizer inline guardi
// dentro — quindi questi test dicono che lo scanner e il renderer sono d'accordo,
// che è la sola cosa che li tiene una grammatica sola.
describe("DirectiveScan.scan and fenced code", () => {
  test("a slice that looks like an inline directive stays code", () => {
    // Il caso vero: dentro un ::python una fetta `[:nome]` veniva letta come la
    // direttiva inline `:nome`, e il validatore segnalava del codice corretto.
    let source =
      "::python{writes=\"x\"}\n" ++
      "```python\n" ++
      "giorni = disponibili[:tetto_giorni]\n" ++
      "```\n" ++
      "::/python"
    expect(summary(source))->toBe("container:python")
  })

  test("a block directive inside a fence is not a directive", () => {
    let source = "prima\n```\n::slider[volume]{}\n:count{path=\"x\"}\n```\ndopo"
    expect(summary(source))->toBe("")
  })

  test("a close inside a fence does not end the container", () => {
    // Se la chiudesse, il contenitore finirebbe in mezzo al programma di qualcuno
    // e la seconda metà tornerebbe testo. Lo scanner riporta un livello per volta,
    // quindi qui si vede il contenitore; che dentro ci sia ancora l'input lo dice
    // il corpo, scandito a parte come fa il validatore.
    let source =
      "::form{path=\"p\"}\n```\n::/form\n```\n::input{field=\"a\"}\n::/form\ndopo"
    expect(summary(source))->toBe("container:form")
    let corpo = "```\n::/form\n```\n::input{field=\"a\"}"
    expect(summary(corpo))->toBe("leaf:input")
  })

  test("the fence has to be closed by the same character, at least as long", () => {
    // Tre tilde non chiudono tre backtick, e due backtick non chiudono niente:
    // è così che un blocco di codice riesce a mostrare una fence.
    let source = "````\n```\n::slider[v]{}\n````\n::switch{}"
    expect(summary(source))->toBe("leaf:switch")
  })

  test("backticks in running text do not open a fence", () => {
    let source = "Scrivi `a` e `b`.\n\n::slider[volume]{}"
    expect(summary(source))->toBe("leaf:slider")
  })

  test("a fence nobody closes swallows the rest, exactly as marked does", () => {
    // Il documento è sbagliato, e i due devono essere d'accordo anche su dove
    // finisce il danno: altrimenti si convaliderebbe una cosa e se ne
    // renderizzerebbe un'altra.
    let source = "::switch{}\n```\n::slider[v]{}\ntesto\n:count{path=\"x\"}"
    expect(summary(source))->toBe("leaf:switch")
  })

  test("a tilde fence works like a backtick one", () => {
    let source = "~~~\n::slider[v]{}\n~~~\n::switch{}"
    expect(summary(source))->toBe("leaf:switch")
  })

  test("what comes after a closed fence is scanned again", () => {
    let source = "```\n::slider[v]{}\n```\n\nTesto :count{path=\"c\"} qui.\n\n::switch{}"
    expect(summary(source))->toBe("inline:count,leaf:switch")
  })
})
