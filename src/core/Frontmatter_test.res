open BunTest

let sample = `---
appId: grade-book
title: Grade Book
description: Class grades, with per-student and per-subject averages.
lang: en
version: "1.0"
author: Ada
date: "2026-06-27"
---

# Grades

Body text.`

let field = (source, name) =>
  switch Frontmatter.parse(source).meta {
  | Some(meta) => Frontmatter.get(meta, name)->Option.getOr("(absent)")
  | None => "(no frontmatter)"
  }

let keys = source =>
  switch Frontmatter.parse(source).meta {
  | Some(meta) => meta.fields->Array.map(f => f.Frontmatter.key)->Array.join(",")
  | None => "(no frontmatter)"
  }

describe("Frontmatter.parse", () => {
  test("reads every field of the documented block", () => {
    expect(keys(sample))->toBe("appId,title,description,lang,version,author,date")
  })

  test("keeps values as written", () => {
    expect(field(sample, "appId"))->toBe("grade-book")
    expect(field(sample, "title"))->toBe("Grade Book")
    expect(field(sample, "author"))->toBe("Ada")
  })

  // Quoting is how YAML keeps "1.0" a string; the quotes are syntax, not content.
  test("removes matched surrounding quotes", () => {
    expect(field(sample, "version"))->toBe("1.0")
    expect(field(sample, "date"))->toBe("2026-06-27")
  })

  test("looks up fields case-insensitively", () => {
    expect(field(sample, "APPID"))->toBe("grade-book")
  })

  test("strips the block from the body", () => {
    expect(Frontmatter.parse(sample).body)->toBe("# Grades\n\nBody text.")
  })

  test("keeps colons inside values", () => {
    expect(field("---\nhome: https://example.com/a:b\n---\n", "home"))->toBe(
      "https://example.com/a:b",
    )
  })

  test("keeps an unmatched quote", () => {
    expect(field("---\nauthor: it's Ada\n---\n", "author"))->toBe("it's Ada")
  })

  test("ignores blank lines and comments", () => {
    expect(keys("---\n\n# a comment\ntitle: T\n\n---\n"))->toBe("title")
  })

  test("handles CRLF documents", () => {
    expect(field("---\r\ntitle: T\r\n---\r\nbody", "title"))->toBe("T")
  })
})

describe("Frontmatter.parse — documents without usable frontmatter", () => {
  test("a plain document is left alone", () => {
    let source = "# Title\n\nNo frontmatter here."
    expect(Frontmatter.parse(source).body)->toBe(source)
    expect(keys(source))->toBe("(no frontmatter)")
  })

  // Swallowing the rest of the document would be far worse than ignoring the block.
  test("an unterminated block is treated as body", () => {
    let source = "---\ntitle: T\n\n# Heading"
    expect(Frontmatter.parse(source).body)->toBe(source)
    expect(keys(source))->toBe("(no frontmatter)")
  })

  test("a --- that is not on the first line is not frontmatter", () => {
    let source = "# Title\n\n---\ntitle: T\n---\n"
    expect(Frontmatter.parse(source).body)->toBe(source)
  })

  test("an empty block yields no fields but still strips", () => {
    expect(keys("---\n---\nbody"))->toBe("")
    expect(Frontmatter.parse("---\n---\nbody").body)->toBe("body")
  })

  test("an empty document is left alone", () => {
    expect(Frontmatter.parse("").body)->toBe("")
  })
})

describe("Frontmatter.serialize", () => {
  let roundTrip = source => {
    let parsed = Frontmatter.parse(source)
    switch parsed.meta {
    | Some(meta) => Frontmatter.serialize(meta, parsed.body)
    | None => parsed.body
    }
  }

  // The property that matters: editing a field through the panel must not quietly
  // rewrite the rest of the document.
  test("round-trips the documented block unchanged", () => {
    expect(roundTrip(sample))->toBe(sample)
  })

  test("re-quotes values YAML would read as a number or date", () => {
    let meta = Frontmatter.empty->Frontmatter.setField(~key="version", ~value="1.0")
    expect(Frontmatter.serialize(meta, "body"))->toBe("---\nversion: \"1.0\"\n---\n\nbody")
  })

  test("leaves ordinary strings unquoted", () => {
    let meta = Frontmatter.empty->Frontmatter.setField(~key="title", ~value="Grade Book")
    expect(Frontmatter.serialize(meta, "body"))->toBe("---\ntitle: Grade Book\n---\n\nbody")
  })

  test("quotes booleans and empty values so they stay strings", () => {
    let meta =
      Frontmatter.empty
      ->Frontmatter.setField(~key="draft", ~value="true")
      ->Frontmatter.setField(~key="note", ~value=" padded ")
    expect(Frontmatter.serialize(meta, "b"))->toBe("---\ndraft: \"true\"\nnote: \" padded \"\n---\n\nb")
  })

  test("omits an empty block entirely", () => {
    expect(Frontmatter.serialize(Frontmatter.empty, "# Just body"))->toBe("# Just body")
  })
})

describe("Frontmatter round trips its own escaping", () => {
  let cycle = value => {
    let written = Frontmatter.serialize(
      Frontmatter.empty->Frontmatter.setField(~key="description", ~value),
      "Body",
    )
    Frontmatter.parse(written).meta->Option.flatMap(meta => Frontmatter.get(meta, "description"))
  }

  // The bug: quote() escaped the quotes but unquote() never unescaped them, so every
  // edit-save cycle grew the value a layer of backslashes.
  test("a value with quotes in it comes back unchanged", () => {
    expect(cycle("a \"big\" release"))->toEqual(Some("a \"big\" release"))
    // And a second cycle changes nothing more.
    let once = cycle("a \"big\" release")->Option.getOr("")
    expect(cycle(once))->toEqual(Some(once))
  })

  test("backslashes survive too", () => {
    expect(cycle("C:\\Users\\ada"))->toEqual(Some("C:\\Users\\ada"))
  })

  // A raw newline would end the field mid-value — or, carrying ---, close the block
  // and swallow the body.
  test("a value with a newline neither truncates nor eats the body", () => {
    expect(cycle("two\nlines"))->toEqual(Some("two\nlines"))
    expect(cycle("sneaky\n---\nnot a delimiter"))->toEqual(Some("sneaky\n---\nnot a delimiter"))
  })

  test("a value that merely looks quoted is not stripped", () => {
    expect(cycle("\"already quoted\""))->toEqual(Some("\"already quoted\""))
  })
})

describe("Frontmatter.setField", () => {
  let meta = Frontmatter.parse(sample).meta->Option.getOr(Frontmatter.empty)

  test("updates in place without reordering", () => {
    let updated = meta->Frontmatter.setField(~key="title", ~value="Register")
    expect(updated.fields->Array.map(f => f.Frontmatter.key)->Array.join(","))->toBe(
      "appId,title,description,lang,version,author,date",
    )
    expect(Frontmatter.get(updated, "title")->Option.getOr(""))->toBe("Register")
  })

  test("appends an unknown key", () => {
    let updated = meta->Frontmatter.setField(~key="reviewer", ~value="Grace")
    expect(updated.fields->Array.length)->toBe(meta.fields->Array.length + 1)
    expect(Frontmatter.get(updated, "reviewer")->Option.getOr(""))->toBe("Grace")
  })

  test("matches existing keys case-insensitively rather than duplicating", () => {
    let updated = meta->Frontmatter.setField(~key="TITLE", ~value="Register")
    expect(updated.fields->Array.length)->toBe(meta.fields->Array.length)
  })

  test("removes a field", () => {
    let updated = meta->Frontmatter.removeField(~key="author")
    expect(Frontmatter.get(updated, "author")->Option.isNone)->toBe(true)
    expect(updated.fields->Array.length)->toBe(meta.fields->Array.length - 1)
  })
})
