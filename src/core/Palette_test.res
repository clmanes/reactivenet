open BunTest

describe("Palette", () => {
  test("offers six palettes", () => {
    expect(Palette.all->Array.length)->toBe(6)
  })

  test("every palette round-trips through its tag", () => {
    let broken =
      Palette.all
      ->Array.filter(p => Palette.parse(Palette.toTag(p)) != Some(p))
      ->Array.map(Palette.toTag)
    expect(broken->Array.join(","))->toBe("")
  })

  test("rejects unknown tags", () => {
    expect(Palette.parse("chartreuse")->Option.isNone)->toBe(true)
    expect(Palette.parse("")->Option.isNone)->toBe(true)
  })

  test("tags are unique", () => {
    let tags = Palette.all->Array.map(Palette.toTag)
    let unique =
      tags->Array.reduce([], (acc, t) => acc->Array.includes(t) ? acc : acc->Array.concat([t]))
    expect(unique->Array.length)->toBe(tags->Array.length)
  })

  test("labels are unique and non-empty", () => {
    let labels = Palette.all->Array.map(Palette.label)
    expect(labels->Array.filter(l => l == "")->Array.length)->toBe(0)
    let unique =
      labels->Array.reduce([], (acc, l) => acc->Array.includes(l) ? acc : acc->Array.concat([l]))
    expect(unique->Array.length)->toBe(labels->Array.length)
  })

  test("the fallback is one of the offered palettes", () => {
    expect(Palette.all->Array.includes(Palette.fallback))->toBe(true)
  })
})

// WCAG 2.2 AA is a constraint on this project, so the palettes are held to it here
// rather than in an audit: a colour that drops below threshold fails the build.
describe("Palette contrast (WCAG 2.2 AA)", () => {
  let failures = (~dark) =>
    Palette.all
    ->Array.filter(palette =>
      !Contrast.meets(
        ~foreground=Palette.brandColour(palette, ~dark),
        ~background=Palette.surface(~dark),
        ~threshold=Contrast.normalText,
      )
    )
    ->Array.map(Palette.label)
    ->Array.join(",")

  test("every palette clears 4.5:1 on the light surface", () => {
    expect(failures(~dark=false))->toBe("")
  })

  test("every palette clears 4.5:1 on the dark surface", () => {
    expect(failures(~dark=true))->toBe("")
  })

  // The reason there are two shades at all: one value cannot do both.
  test("the two shades differ for every palette", () => {
    let same =
      Palette.all
      ->Array.filter(p => Palette.brandColour(p, ~dark=false) == Palette.brandColour(p, ~dark=true))
      ->Array.length
    expect(same)->toBe(0)
  })

  test("every shade is a parseable hex colour", () => {
    let bad =
      Palette.all
      ->Array.flatMap(p => [Palette.brandColour(p, ~dark=false), Palette.brandColour(p, ~dark=true)])
      ->Array.filter(hex => Contrast.parseHex(hex)->Option.isNone)
      ->Array.join(",")
    expect(bad)->toBe("")
  })
})

// The stylesheet is where these colours actually take effect, and a comment saying
// the two must stay in step is not a mechanism. This reads the real file: a palette
// renamed here and not there, or a shade edited in one place only, fails the build
// rather than shipping a palette that never re-colours anything.
let stylesheet: unit => string = %raw(`
function () {
  return require("node:fs").readFileSync("src/index.css", "utf8");
}
`)

describe("Palette and index.css agree", () => {
  let css = stylesheet()
  let block = (selector, tag) =>
    switch css->String.indexOf(selector ++ ".rn-palette-" ++ tag ++ " {") {
    | -1 => None
    | start =>
      switch css->String.indexOfFrom("}", start) {
      | -1 => None
      | stop => Some(css->String.slice(~start, ~end=stop))
      }
    }

  test("every palette has a light and a dark rule", () => {
    let missing =
      Palette.all
      ->Array.filter(p =>
        block("", Palette.toTag(p))->Option.isNone ||
          block("[color=\"dark\"]", Palette.toTag(p))->Option.isNone
      )
      ->Array.map(Palette.label)
      ->Array.join(",")
    expect(missing)->toBe("")
  })

  test("both brand shades are the ones the stylesheet declares", () => {
    let wrong =
      Palette.all
      ->Array.filterMap(p => {
        let stated = (selector, dark) =>
          block(selector, Palette.toTag(p))->Option.mapOr(false, text =>
            text->String.includes("--color-brand: " ++ Palette.brandColour(p, ~dark) ++ ";")
          )
        stated("", false) && stated("[color=\"dark\"]", true) ? None : Some(Palette.label(p))
      })
      ->Array.join(",")
    expect(wrong)->toBe("")
  })

  // Aliasing the whole ramp is the point: overriding only the background aliases is
  // exactly the bug this replaced, and it looks like nothing at all until you notice
  // a progress bar that never changes colour.
  test("every palette aliases all sixteen accent stops to its own hue", () => {
    let stops = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600]
    let broken =
      Palette.all
      ->Array.filterMap(p =>
        switch block("", Palette.toTag(p)) {
        | None => Some(Palette.label(p))
        | Some(text) =>
          let missing =
            stops->Array.filter(stop =>
              !(
                text->String.includes(
                  "--spectrum-accent-color-" ++ stop->Int.toString ++ ": var(--spectrum-" ++
                  Palette.hue(p),
                )
              )
            )
          missing->Array.length == 0 ? None : Some(Palette.label(p))
        }
      )
      ->Array.join(",")
    expect(broken)->toBe("")
  })
})
