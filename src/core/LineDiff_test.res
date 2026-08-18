open BunTest

describe("LineDiff", () => {
  test("identical documents have no changes", () => {
    expect(LineDiff.changesOnly("a\nb\nc", "a\nb\nc"))->toEqual([])
  })

  test("an added line is a plus where it was added", () => {
    expect(LineDiff.changesOnly("a\nc", "a\nb\nc"))->toEqual([{LineDiff.sign: "+", text: "b"}])
  })

  test("a removed line is a minus", () => {
    expect(LineDiff.changesOnly("a\nb\nc", "a\nc"))->toEqual([{LineDiff.sign: "-", text: "b"}])
  })

  // The shape every proposal produces: one line replaced reads as the old line
  // going and the new arriving, deletion first.
  test("a changed line is a minus then a plus", () => {
    expect(LineDiff.changesOnly("title: Vecchio\nbody", "title: Nuovo\nbody"))->toEqual([
      {LineDiff.sign: "-", text: "title: Vecchio"},
      {LineDiff.sign: "+", text: "title: Nuovo"},
    ])
  })

  test("counts tally the two signs", () => {
    let counts = LineDiff.count(LineDiff.changesOnly("a\nb\nc", "a\nx\ny\nc"))
    expect(counts.LineDiff.added)->toBe(2)
    expect(counts.LineDiff.removed)->toBe(1)
  })

  // A repeated line must not confuse the alignment: only the copy that actually
  // moved shows up.
  test("repeated lines stay aligned", () => {
    expect(LineDiff.changesOnly("x\na\nx", "x\nb\nx"))->toEqual([
      {LineDiff.sign: "-", text: "a"},
      {LineDiff.sign: "+", text: "b"},
    ])
  })

  test("an empty old document is all pluses", () => {
    expect(LineDiff.count(LineDiff.changesOnly("", "a\nb")).LineDiff.added > 0)->toBe(true)
  })
})
