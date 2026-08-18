open BunTest

// Assert on a rendered string rather than on the result variant: the tests then say
// nothing about how ReScript represents `Ok`/`Error` at runtime.
let render = result =>
  switch result {
  | Ok(url) => "ok:" ++ SafeUrl.toString(url)
  | Error(error) => "rejected:" ++ SafeUrl.errorToString(error)
  }

let parse = raw => SafeUrl.parse(raw)->render

describe("SafeUrl.parse — accepts", () => {
  test("https URLs", () => {
    expect(parse("https://example.com/a?b=1#c"))->toBe("ok:https://example.com/a?b=1#c")
  })

  test("http URLs", () => {
    expect(parse("http://example.com"))->toBe("ok:http://example.com")
  })

  test("mailto links", () => {
    expect(parse("mailto:someone@example.com"))->toBe("ok:mailto:someone@example.com")
  })

  test("site-relative paths", () => {
    expect(parse("/about"))->toBe("ok:/about")
  })

  test("fragments and queries", () => {
    expect(parse("#section"))->toBe("ok:#section")
    expect(parse("?page=2"))->toBe("ok:?page=2")
  })

  test("a path containing a colon, which is not a scheme", () => {
    expect(parse("/notes/10:30"))->toBe("ok:/notes/10:30")
  })

  test("uppercase schemes, matched case-insensitively", () => {
    expect(parse("HTTPS://example.com"))->toBe("ok:HTTPS://example.com")
  })
})

describe("SafeUrl.parse — rejects", () => {
  test("javascript: URLs", () => {
    expect(parse("javascript:alert(1)"))->toBe(`rejected:The "javascript:" scheme is not allowed.`)
  })

  test("javascript: disguised by case", () => {
    expect(parse("JaVaScRiPt:alert(1)"))->toBe(`rejected:The "javascript:" scheme is not allowed.`)
  })

  test("javascript: disguised by leading whitespace", () => {
    expect(parse("   javascript:alert(1)"))->toBe(`rejected:The "javascript:" scheme is not allowed.`)
  })

  // The one browsers actually fall for: control characters inside the scheme are
  // ignored during URL parsing, so this navigates as `javascript:`.
  test("javascript: split by a tab", () => {
    expect(parse("java\tscript:alert(1)"))->toBe(
      `rejected:The "javascript:" scheme is not allowed.`,
    )
  })

  test("javascript: split by a newline", () => {
    expect(parse("java\nscript:alert(1)"))->toBe(
      `rejected:The "javascript:" scheme is not allowed.`,
    )
  })

  test("javascript: split by a NUL byte", () => {
    let nul = String.fromCharCode(0)
    expect(parse("java" ++ nul ++ "script:alert(1)"))->toBe(
      `rejected:The "javascript:" scheme is not allowed.`,
    )
  })

  test("data: URLs", () => {
    expect(parse("data:text/html,<script>alert(1)</script>"))->toBe(
      `rejected:The "data:" scheme is not allowed.`,
    )
  })

  test("vbscript: URLs", () => {
    expect(parse("vbscript:msgbox(1)"))->toBe(`rejected:The "vbscript:" scheme is not allowed.`)
  })

  test("protocol-relative URLs, which leave the origin silently", () => {
    expect(parse("//evil.example/path"))->toBe(
      "rejected:Protocol-relative links are not allowed.",
    )
  })

  test("the empty string", () => {
    expect(parse(""))->toBe("rejected:The link is empty.")
    expect(parse("   "))->toBe("rejected:The link is empty.")
  })
})

describe("SafeUrl.toString", () => {
  // Handing back the caller's original string would return a value that passed the
  // check while still carrying the characters the check removed.
  test("returns the normalised href, not the raw input", () => {
    expect(parse("  https://example.com  "))->toBe("ok:https://example.com")
  })
})
