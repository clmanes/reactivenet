open BunTest

let step = (name, ~reads=[], ~writes=[]): WorkflowGraph.step => {name, reads, writes}

// The chain of the documentation: open data in, SQL over it and what the forms hold,
// a forecast over that. Written in the order it runs, which is the easy case.
let chain = [
  step("od-query", ~writes=["listino"]),
  step("sql", ~reads=["spese", "listino"], ~writes=["scostamenti"]),
  step("ml-forecast", ~reads=["scostamenti"], ~writes=["previsione"]),
]

describe("WorkflowGraph.feeds", () => {
  test("one collection written above and read below", () => {
    expect(
      WorkflowGraph.feeds(chain->Array.getUnsafe(0), chain->Array.getUnsafe(1)),
    )->toBe(true)
  })

  test("and not the other way round", () => {
    expect(
      WorkflowGraph.feeds(chain->Array.getUnsafe(1), chain->Array.getUnsafe(0)),
    )->toBe(false)
  })

  // A step with no into= produces nothing. Reading "" as a shared collection would
  // make every such step feed every other and the order would be nonsense.
  test("a blank name is not an edge", () => {
    let mute = step("ai-chat", ~reads=[""], ~writes=[""])
    expect(WorkflowGraph.feeds(mute, mute))->toBe(false)
  })
})

describe("WorkflowGraph.plan", () => {
  test("a chain written in order keeps it", () => {
    let plan = WorkflowGraph.plan(chain)
    expect(plan.order->Array.map(index => Int.toString(index))->Array.join(","))->toBe("0,1,2")
    expect(plan.cycle->Array.length)->toBe(0)
  })

  // The point of the module: the document's order is not the running order, and an
  // author who writes the forecast at the top is not writing a bug.
  test("a chain written backwards is reordered", () => {
    let plan = WorkflowGraph.plan([
      step("ml-forecast", ~reads=["scostamenti"], ~writes=["previsione"]),
      step("sql", ~reads=["spese", "listino"], ~writes=["scostamenti"]),
      step("od-query", ~writes=["listino"]),
    ])
    expect(plan.order->Array.map(index => Int.toString(index))->Array.join(","))->toBe("2,1,0")
  })

  // Stability. Two steps that do not feed each other run in the order they were
  // written, every time — the same promise RowView.sort makes.
  test("independent steps keep the author's order", () => {
    let plan = WorkflowGraph.plan([
      step("od-query", ~writes=["a"]),
      step("api-query", ~writes=["b"]),
      step("sql", ~writes=["c"]),
    ])
    expect(plan.order->Array.map(index => Int.toString(index))->Array.join(","))->toBe("0,1,2")
  })

  test("a diamond runs its two middles in the order they were written", () => {
    let plan = WorkflowGraph.plan([
      step("od-query", ~writes=["grezzi"]),
      step("sql", ~reads=["grezzi"], ~writes=["destra"]),
      step("sql", ~reads=["grezzi"], ~writes=["sinistra"]),
      step("python", ~reads=["destra", "sinistra"], ~writes=["unione"]),
    ])
    expect(plan.order->Array.map(index => Int.toString(index))->Array.join(","))->toBe("0,1,2,3")
  })

  // The failure this module exists for. Nothing on the page would say why a workflow
  // never settles, and the signature guard does not save a step whose output carries
  // a timestamp.
  test("a circle is reported, not ordered", () => {
    let plan = WorkflowGraph.plan([
      step("sql", ~reads=["b"], ~writes=["a"]),
      step("sql", ~reads=["a"], ~writes=["b"]),
    ])
    expect(plan.order->Array.length)->toBe(0)
    expect(plan.cycle->Array.map(index => Int.toString(index))->Array.join(","))->toBe("0,1")
  })

  // What can run still runs. Refusing the whole workflow because two steps at the end
  // disagree would throw away the ones that were fine.
  test("what can be placed is placed even when part of the graph loops", () => {
    let plan = WorkflowGraph.plan([
      step("od-query", ~writes=["grezzi"]),
      step("sql", ~reads=["b"], ~writes=["a"]),
      step("sql", ~reads=["a"], ~writes=["b"]),
    ])
    expect(plan.order->Array.map(index => Int.toString(index))->Array.join(","))->toBe("0")
    expect(plan.cycle->Array.map(index => Int.toString(index))->Array.join(","))->toBe("1,2")
  })

  test("no steps is a plan with nothing in it", () => {
    let plan = WorkflowGraph.plan([])
    expect(plan.order->Array.length)->toBe(0)
    expect(plan.cycle->Array.length)->toBe(0)
  })
})

describe("WorkflowGraph.downstream", () => {
  test("everything a failed step was feeding, however far down", () => {
    expect(WorkflowGraph.downstream(chain, 0)->Array.map(index => Int.toString(index))->Array.join(","))->toBe("1,2")
  })

  test("the last step feeds nothing", () => {
    expect(WorkflowGraph.downstream(chain, 2)->Array.length)->toBe(0)
  })

  test("a step is not downstream of itself", () => {
    expect(WorkflowGraph.downstream(chain, 1)->Array.map(index => Int.toString(index))->Array.join(","))->toBe("2")
  })
})

describe("WorkflowGraph.outputs", () => {
  test("the collections produced, once each, in first-written order", () => {
    expect(WorkflowGraph.outputs(chain)->Array.join(","))->toBe("listino,scostamenti,previsione")
  })

  test("a collection two steps write is named once", () => {
    expect(
      WorkflowGraph.outputs([
        step("sql", ~writes=["esito"]),
        step("python", ~writes=["esito"]),
      ])->Array.join(","),
    )->toBe("esito")
  })
})
