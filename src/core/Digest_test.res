open BunTest

describe("Digest", () => {
  test("the same text always gives the same fingerprint", () => {
    expect(Digest.of_("# Welcome"))->toBe(Digest.of_("# Welcome"))
  })

  test("a changed text gives a different one", () => {
    expect(Digest.of_("# Welcome") == Digest.of_("# Welcome!"))->toBe(false)
    // The cases that matter here are small edits: a word, a space, a line.
    expect(Digest.of_("a b") == Digest.of_("a  b"))->toBe(false)
    expect(Digest.of_("one\ntwo") == Digest.of_("one\ntwo\n"))->toBe(false)
  })

  test("the empty text has a fingerprint too", () => {
    expect(Digest.of_("") != "")->toBe(true)
  })

  test("it is readable text whatever the document contains", () => {
    let odd = Digest.of_("ÿĀ – a document with punctuation, emoji 🌍 and a tab\t")
    expect(odd->String.startsWith("-"))->toBe(false)
    expect(odd != "")->toBe(true)
    // Hexadecimal, so it is short enough to keep beside the document it describes.
    expect(RegExp.test(RegExp.fromString("^[0-9a-f]+$"), odd))->toBe(true)
  })

  // The bug this guards: ReScript ints are 32-bit and `*` wraps, so a modulus chosen
  // for its size made every document longer than a few characters hash negative —
  // and a fingerprint that changes on its own vouches for nothing.
  test("a whole document still hashes to plain hexadecimal", () => {
    let long = Array.make(~length=400, "The quick brown fox. ")->Array.join("")
    let value = Digest.of_(long)
    expect(RegExp.test(RegExp.fromString("^[0-9a-f]+$"), value))->toBe(true)
    expect(Digest.of_(long) == Digest.of_(long ++ "."))->toBe(false)
  })

  // The rule the welcome app depends on: replace what you wrote, leave what somebody
  // changed, and leave anything you never vouched for.
  test("matches only what was recorded", () => {
    let text = "# Welcome"
    expect(Digest.matches(text, ~recorded=Digest.of_(text)))->toBe(true)
    expect(Digest.matches(text ++ " edited", ~recorded=Digest.of_(text)))->toBe(false)
    expect(Digest.matches(text, ~recorded=""))->toBe(false)
  })
})
