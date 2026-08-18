open BunTest

let field = (
  ~field="what",
  ~label="What",
  ~value="",
  ~kind="text",
  ~ticked=false,
  ~required=false,
  ~min="",
  ~max="",
  ~pattern="",
  ~patternMessage="",
  (),
): Draft.control => {
  field,
  label,
  value,
  kind,
  ticked,
  required,
  min,
  max,
  pattern,
  patternMessage,
}

let problems = controls => Draft.check(controls)->Array.map(c => c.Draft.problem)

describe("Draft.blank", () => {
  test("a draft with nothing in it is blank", () => {
    expect(Draft.blank([field(~value="  ", ()), field(~field="who", ())]))->toBe(true)
  })

  // The bug this answers: a checkbox reads "false", which is a value, so a form with
  // one in it was never blank and every press of the button saved an empty row.
  test("an unticked box does not make a draft worth saving", () => {
    expect(Draft.blank([field(~kind="checkbox", ()), field(~field="who", ())]))->toBe(true)
    expect(Draft.blank([field(~kind="checkbox", ~ticked=true, ())]))->toBe(false)
  })

  test("anything typed makes it worth saving", () => {
    expect(Draft.blank([field(~value="Bread", ())]))->toBe(false)
  })
})

describe("Draft.reading", () => {
  test("a tick stores true or false, like everywhere else", () => {
    expect(Draft.reading(field(~kind="checkbox", ~ticked=true, ())))->toBe("true")
    expect(Draft.reading(field(~kind="checkbox", ())))->toBe("false")
  })

  test("anything else stores what was typed", () => {
    expect(Draft.reading(field(~value=" Bread ", ())))->toBe(" Bread ")
  })
})

describe("Draft.check", () => {
  test("an empty optional field is not a mistake", () => {
    expect(problems([field()]))->toEqual([])
  })

  test("required means required, ticks included", () => {
    expect(problems([field(~required=true, ())]))->toEqual([Draft.Missing])
    expect(problems([field(~kind="checkbox", ~required=true, ())]))->toEqual([Draft.Missing])
    expect(problems([field(~kind="checkbox", ~required=true, ~ticked=true, ())]))->toEqual([])
  })

  test("a number is a number all the way through", () => {
    expect(problems([field(~kind="number", ~value="12.5", ())]))->toEqual([])
    expect(problems([field(~kind="number", ~value="12 euro", ())]))->toEqual([Draft.NotANumber])
  })

  test("min and max compare as numbers", () => {
    let bounded = value => problems([field(~kind="number", ~value, ~min="1", ~max="10", ())])
    expect(bounded("0.5"))->toEqual([Draft.Below("1")])
    expect(bounded("11"))->toEqual([Draft.Above("10")])
    expect(bounded("1"))->toEqual([])
  })

  test("a date is what a date input writes, and its bounds sort as text", () => {
    expect(problems([field(~kind="date", ~value="2026-08-12", ())]))->toEqual([])
    expect(problems([field(~kind="date", ~value="12/08/2026", ())]))->toEqual([Draft.NotADate])
    expect(
      problems([field(~kind="date", ~value="2026-08-12", ~min="2026-09-01", ())]),
    )->toEqual([Draft.Below("2026-09-01")])
  })

  test("a time is HH:MM, with or without seconds", () => {
    expect(problems([field(~kind="time", ~value="09:30", ())]))->toEqual([])
    expect(problems([field(~kind="time", ~value="09:30:15", ())]))->toEqual([])
    expect(problems([field(~kind="time", ~value="25:00", ())]))->toEqual([Draft.NotATime])
  })

  test("an address needs an @ and a domain", () => {
    expect(problems([field(~kind="email", ~value="ada@example.org", ())]))->toEqual([])
    expect(problems([field(~kind="email", ~value="ada@example", ())]))->toEqual([
      Draft.NotAnEmail,
    ])
    expect(problems([field(~kind="email", ~value="ada example.org", ())]))->toEqual([
      Draft.NotAnEmail,
    ])
  })

  // The same allowlist the rest of the app holds hrefs to, so a stored URL is one the
  // preview would have been willing to render.
  test("a url is one SafeUrl would accept", () => {
    expect(problems([field(~kind="url", ~value="https://example.org", ())]))->toEqual([])
    expect(problems([field(~kind="url", ~value="javascript:alert(1)", ())]))->toEqual([
      Draft.NotAUrl,
    ])
  })

  test("the author's pattern must match the whole value", () => {
    let postcode = value =>
      problems([field(~value, ~pattern="[0-9]{5}", ~patternMessage="Five digits", ())])
    expect(postcode("20121"))->toEqual([])
    expect(postcode("2012"))->toEqual([Draft.NotMatching("Five digits")])
    // Anchored at both ends: a rule that matched anywhere would take this and look
    // like it was working.
    expect(postcode("20121 Milano"))->toEqual([Draft.NotMatching("Five digits")])
  })

  test("a pattern nobody can compile refuses nothing", () => {
    expect(problems([field(~value="anything", ~pattern="[unclosed", ())]))->toEqual([])
  })

  test("the type is complained about before the author's rule", () => {
    expect(
      problems([field(~kind="number", ~value="twelve", ~pattern="[0-9]+", ())]),
    )->toEqual([Draft.NotANumber])
  })

  test("an empty field is never matched against a pattern", () => {
    expect(problems([field(~value="", ~pattern="[0-9]{5}", ())]))->toEqual([])
  })

  test("a complaint names the field the way the reader sees it", () => {
    let complaints = Draft.check([field(~field="cap", ~label="Postcode", ~required=true, ())])
    expect(complaints->Array.map(c => c.Draft.label)->Array.join(","))->toBe("Postcode")
    let unlabelled = Draft.check([field(~field="cap", ~label="", ~required=true, ())])
    expect(unlabelled->Array.map(c => c.Draft.label)->Array.join(","))->toBe("cap")
  })
})
