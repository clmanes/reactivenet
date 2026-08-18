open BunTest

// The rule this whole module exists for: a model's answer is data, and data that
// does not fit the shape the document declared never becomes a row.

describe("AiDirective.json", () => {
  test("a bare object", () => {
    expect(AiDirective.json("{\"a\":1}")->Option.isSome)->toBe(true)
  })

  // Models fence what they are asked for, apologise before it and explain after.
  test("an object inside a fence, with prose around it", () => {
    let fence = String.repeat("`", 3)
    let answer = "Ecco il piano:\n" ++ fence ++ "json\n{\"metric\":\"count\"}\n" ++ fence ++ "\nSpero vada bene."
    switch AiDirective.json(answer) {
    | Some(value) => expect(JSON.stringify(value))->toBe("{\"metric\":\"count\"}")
    | None => expect("parsed")->toBe("nothing")
    }
  })

  test("an answer with no JSON in it at all", () => {
    expect(AiDirective.json("Non lo so.")->Option.isNone)->toBe(true)
  })
})

describe("AiDirective.fields", () => {
  test("a name is text, a name with a type is that type", () => {
    expect(AiDirective.fields("voce,importo:number"))->toEqual([
      {AiDirective.name: "voce", kind: "text"},
      {AiDirective.name: "importo", kind: "number"},
    ])
  })

  test("a type nobody has heard of is text, not a refusal", () => {
    expect(AiDirective.fields("x:colore")->Array.getUnsafe(0))->toEqual({
      AiDirective.name: "x",
      kind: "text",
    })
  })
})

describe("AiDirective.clamp", () => {
  test("the word itself", () => {
    expect(AiDirective.clamp("casa", ["cibo", "casa"]))->toBe(Some("casa"))
  })

  // "Casa." is casa: a model that adds a full stop has still chosen.
  test("case, accents and punctuation do not make it a different word", () => {
    expect(AiDirective.clamp("Casa.", ["cibo", "casa"]))->toBe(Some("casa"))
  })

  // An answer that names two of the values has chosen neither, and guessing which
  // would be inventing the classification this module exists to prevent.
  test("an answer that is not one of the values is nothing", () => {
    expect(AiDirective.clamp("cibo o casa", ["cibo", "casa"])->Option.isNone)->toBe(true)
  })
})

describe("AiDirective.record", () => {
  let declared = AiDirective.fields("voce,importo:number,quando:date")

  test("only the declared fields survive", () => {
    let answered = JSON.parseOrThrow("{\"voce\":\"pane\",\"altro\":\"x\"}")
    expect(AiDirective.record(answered, declared))->toEqual([
      {Collection.name: "voce", value: "pane"},
    ])
  })

  // A number written the Italian way is a number; a number that is prose is not,
  // and storing it would put text in a column everything else sums.
  test("a decimal comma is a number, a sentence is not", () => {
    let answered = JSON.parseOrThrow("{\"importo\":\"3,50\"}")
    expect(AiDirective.record(answered, declared))->toEqual([
      {Collection.name: "importo", value: "3.5"},
    ])
    let prose = JSON.parseOrThrow("{\"importo\":\"circa tre euro\"}")
    expect(AiDirective.record(prose, declared))->toEqual([])
  })

  test("a date keeps only the day it names", () => {
    let answered = JSON.parseOrThrow("{\"quando\":\"2026-08-13T10:00:00Z\"}")
    expect(AiDirective.record(answered, declared))->toEqual([
      {Collection.name: "quando", value: "2026-08-13"},
    ])
  })
})

describe("AiDirective.plan", () => {
  let allowed = ["categoria", "importo"]

  test("a field the collection does not have is refused, by name", () => {
    let answered = JSON.parseOrThrow("{\"groupBy\":\"inventata\"}")
    switch AiDirective.plan(answered, allowed) {
    | Error(why) => expect(why)->toBe("unknown field: inventata")
    | Ok(_) => expect("refused")->toBe("accepted")
    }
  })

  test("a metric nobody has heard of falls back to count rather than failing", () => {
    let answered = JSON.parseOrThrow("{\"metric\":\"mediana\"}")
    switch AiDirective.plan(answered, allowed) {
    | Ok(plan) => expect(plan.metric)->toBe("count")
    | Error(_) => expect("accepted")->toBe("refused")
    }
  })

  test("the plan runs here, over the rows this device holds", () => {
    let answered = JSON.parseOrThrow(
      "{\"groupBy\":\"categoria\",\"metric\":\"sum\",\"field\":\"importo\",\"sort\":\"desc\"}",
    )
    let rows = [
      Dict.fromArray([("categoria", "cibo"), ("importo", "10")]),
      Dict.fromArray([("categoria", "cibo"), ("importo", "5")]),
      Dict.fromArray([("categoria", "casa"), ("importo", "20")]),
    ]
    switch AiDirective.plan(answered, allowed) {
    | Ok(plan) =>
      let answer = AiDirective.run(plan, rows)
      expect(answer.rows)->toEqual([
        {AiDirective.label: "casa", value: "20"},
        {AiDirective.label: "cibo", value: "15"},
      ])
    | Error(_) => expect("accepted")->toBe("refused")
    }
  })

  // The rule the aggregations already follow: a value that does not read as a
  // number is not counted, rather than counted as zero.
  test("a blank is not a zero", () => {
    let answered = JSON.parseOrThrow("{\"metric\":\"avg\",\"field\":\"importo\"}")
    let rows = [
      Dict.fromArray([("importo", "10")]),
      Dict.fromArray([("importo", "")]),
      Dict.fromArray([("importo", "20")]),
    ]
    switch AiDirective.plan(answered, allowed) {
    | Ok(plan) => expect(AiDirective.run(plan, rows).scalar)->toBe("15")
    | Error(_) => expect("accepted")->toBe("refused")
    }
  })
})

describe("AiDirective.rule", () => {
  let allowed = ["importo", "controllo"]
  let compiled = () =>
    AiDirective.rule(
      JSON.parseOrThrow(
        "{\"field\":\"importo\",\"op\":\"gt\",\"value\":\"100\",\"setField\":\"controllo\",\"setValue\":\"da verificare\"}",
      ),
      allowed,
    )

  test("a rule that writes a field the collection does not have is refused", () => {
    let answered = JSON.parseOrThrow(
      "{\"field\":\"importo\",\"setField\":\"inventata\",\"setValue\":\"x\"}",
    )
    switch AiDirective.rule(answered, allowed) {
    | Error(why) => expect(why)->toBe("unknown field: inventata")
    | Ok(_) => expect("refused")->toBe("accepted")
    }
  })

  // Running it twice is running it once: a row already carrying the value is not a
  // row the rule changes, so there is nothing to write and nothing to sync.
  test("only the rows it would actually change", () => {
    switch compiled() {
    | Ok(rule) =>
      let rows = [
        Dict.fromArray([("importo", "120"), ("controllo", "")]),
        Dict.fromArray([("importo", "10"), ("controllo", "")]),
        Dict.fromArray([("importo", "200"), ("controllo", "da verificare")]),
      ]
      expect(AiDirective.applies(rule, rows)->Array.length)->toBe(1)
    | Error(_) => expect("compiled")->toBe("refused")
    }
  })
})
