open BunTest

let document = (~id, ~title) =>
  "---\nappId: " ++ id ++ "\ntitle: " ++ title ++ "\n---\n\n# " ++ title ++ "\n"

describe("AiPlan.unfence", () => {
  test("a fence wrapping the whole answer comes off", () => {
    expect(AiPlan.unfence("```markdown\n# Hello\n```"))->toBe("# Hello")
  })

  test("a bare fence comes off too", () => {
    expect(AiPlan.unfence("```\n# Hello\n```"))->toBe("# Hello")
  })

  // A document that contains a code block is not a document inside a code block.
  test("a fence in the middle is left where it is", () => {
    let source = "# Title\n\n::python\n```python\nresult = []\n```\n::/python\n"
    expect(AiPlan.unfence(source))->toBe(source->String.trim)
  })
})

// The seam with the MCP server's report(). scripts/test-mcp.mjs asserts the other
// half — that a valid document still comes back beginning with "ok".
describe("AiPlan.validates", () => {
  test("the validator's ok is an ok", () => {
    expect(AiPlan.validates("ok — the document is valid."))->toBe(true)
  })

  test("a report of problems is not", () => {
    expect(AiPlan.validates("2 problem(s):\n\nline 4: unknown directive"))->toBe(false)
  })

  // Delivery calls this to decide whether to write; nothing at all has to read as no,
  // or an unreachable validator would wave everything through.
  test("nothing is not an ok", () => {
    expect(AiPlan.validates(""))->toBe(false)
  })
})

describe("AiPlan.connects", () => {
  test("a report with no orphans is a yes", () => {
    expect(
      AiPlan.connects(
        "Collections:\n  spese — written by ::save (line 8), read by ::list (line 12)\n\nNo orphans: every view has a writer, every #ref a source, every id points at something.",
      ),
    )->toBe(true)
  })

  test("a report of findings is not", () => {
    expect(
      AiPlan.connects(
        "2 finding(s):\n  line 12: ::list reads \"uscite\" but nothing in this document writes it",
      ),
    )->toBe(false)
  })

  // The same rule as `validates`, for the same reason: an analyzer that did not answer
  // must not be read as one that found nothing.
  test("nothing is not a clean bill", () => {
    expect(AiPlan.connects(""))->toBe(false)
  })
})

describe("AiPlan.odQueries", () => {
  let doc = body => "---\nappId: x\ntitle: X\n---\n\n" ++ body

  test("collects the SELECT of a runnable od-query", () => {
    let found = AiPlan.odQueries(
      doc("::od-query{into=\"c\" sql=\"SELECT comune FROM istat_indicatori WHERE regione='Puglia'\"}"),
    )
    expect(found)->toEqual(["SELECT comune FROM istat_indicatori WHERE regione='Puglia'"])
  })

  // A parameterised query selects what a reader asks for, so there is no honest value
  // to try in its place — and a false verdict about a query that is fine is the worst
  // kind, because it sends somebody to change the one thing that was right.
  test("leaves a query carrying a reactive key alone", () => {
    expect(
      AiPlan.odQueries(
        doc("::od-query{into=\"c\" sql=\"SELECT nome FROM farmacie WHERE comune = '{#comune}'\"}"),
      ),
    )->toEqual([])
  })

  test("a document with no od-query has nothing to run", () => {
    expect(AiPlan.odQueries(doc("::list{path=\"spese\"}\n{voce}\n::/list")))->toEqual([])
  })
})

describe("AiPlan.queryFails", () => {
  test("an empty result is a failure", () => {
    expect(
      AiPlan.queryFails("The query ran and returned NO ROWS.\n\nTHIS IS A BROKEN QUERY, not a result."),
    )->toBe(true)
  })

  test("a refusal is a failure", () => {
    expect(AiPlan.queryFails("The query was refused:\n\nBinder Error"))->toBe(true)
  })

  test("rows are not a failure", () => {
    expect(AiPlan.queryFails("The query ran and returned 3 rows.\n\nColumns: comune"))->toBe(false)
  })

  // Deliberately the opposite of the other two gates: this one reaches a network
  // service, and a warehouse being away must not stop delivery.
  test("an unreachable service does not block", () => {
    expect(AiPlan.queryFails("The open-data service is not reachable at http://127.0.0.1:8788"))->toBe(false)
  })
})

describe("AiPlan.create", () => {
  test("a free id is the id the document asked for", () => {
    switch AiPlan.create(~markdown=document(~id="spese", ~title="Spese"), ~taken=[], ~fallback="app") {
    | AiPlan.Deliver({id, title, renamed, source}) => {
        expect(id)->toBe("spese")
        expect(title)->toBe("Spese")
        expect(renamed)->toBe(false)
        expect(source->String.includes("appId: spese"))->toBe(true)
      }
    | AiPlan.Refused(_) => expect(false)->toBe(true)
    }
  })

  // The rule an import already follows: a delivery never replaces an app that is
  // there, because a replaced app cannot be recovered and a copy can be deleted.
  test("a taken id lands as a copy, never over the app that has it", () => {
    switch AiPlan.create(
      ~markdown=document(~id="spese", ~title="Spese"),
      ~taken=["spese"],
      ~fallback="app",
    ) {
    | AiPlan.Deliver({id, renamed, source}) => {
        expect(id == "spese")->toBe(false)
        expect(renamed)->toBe(true)
        // Stored under the id it actually got, so document, key and URL agree.
        expect(source->String.includes("appId: " ++ id))->toBe(true)
      }
    | AiPlan.Refused(_) => expect(false)->toBe(true)
    }
  })

  test("an empty document is refused rather than written", () => {
    switch AiPlan.create(~markdown="  \n ", ~taken=[], ~fallback="app") {
    | AiPlan.Refused(_) => expect(true)->toBe(true)
    | AiPlan.Deliver(_) => expect(false)->toBe(true)
    }
  })
})

describe("AiPlan.replace", () => {
  // Being asked for a button must not move the app: collections, URL and identity
  // all hang off the id, and a rename is something the author does deliberately.
  test("the open app's id survives an appId the model changed", () => {
    switch AiPlan.replace(~markdown=document(~id="altro", ~title="Spese"), ~id="spese") {
    | AiPlan.Deliver({id, source}) => {
        expect(id)->toBe("spese")
        expect(source->String.includes("appId: spese"))->toBe(true)
        expect(source->String.includes("appId: altro"))->toBe(false)
      }
    | AiPlan.Refused(_) => expect(false)->toBe(true)
    }
  })

  test("with no app open there is nothing to rewrite", () => {
    switch AiPlan.replace(~markdown=document(~id="x", ~title="X"), ~id="") {
    | AiPlan.Refused(_) => expect(true)->toBe(true)
    | AiPlan.Deliver(_) => expect(false)->toBe(true)
    }
  })
})
