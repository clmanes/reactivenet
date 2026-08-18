open BunTest

let document = `---
appId: grade-book
title: Grade Book
description: Class grades.
version: "1.0"
date: "2026-06-27"
---

# Body
`

describe("AppDocument.summary", () => {
  test("reads the card from the frontmatter", () => {
    let card = AppDocument.summary(~id="grade-book", ~source=document)
    expect(card.title)->toBe("Grade Book")
    expect(card.description)->toBe("Class grades.")
    expect(card.version)->toBe("1.0")
  })

  // An untitled app is still addressable, and the id is the one thing it has.
  test("falls back to the id when there is no title", () => {
    let card = AppDocument.summary(~id="untitled-one", ~source="# Just a heading")
    expect(card.title)->toBe("untitled-one")
    expect(card.description)->toBe("")
  })
})

describe("AppDocument.declaredId", () => {
  test("reads the id the document claims", () => {
    expect(AppDocument.declaredId(document))->toEqual(Some("grade-book"))
  })

  test("refuses an id this app would not address", () => {
    expect(AppDocument.declaredId("---\nappId: Not An Id\n---\n"))->toEqual(None)
    expect(AppDocument.declaredId("no frontmatter"))->toEqual(None)
  })
})

describe("AppDocument.withId", () => {
  test("sets the id without disturbing the other fields", () => {
    let renamed = AppDocument.withId(document, "registro")
    expect(AppDocument.declaredId(renamed))->toEqual(Some("registro"))
    let card = AppDocument.summary(~id="registro", ~source=renamed)
    expect(card.title)->toBe("Grade Book")
    expect(card.date)->toBe("2026-06-27")
  })

  test("adds a frontmatter block to a document without one", () => {
    let stamped = AppDocument.withId("# Bare", "bare-app")
    expect(AppDocument.declaredId(stamped))->toEqual(Some("bare-app"))
    expect(Frontmatter.parse(stamped).body->String.includes("# Bare"))->toBe(true)
  })
})

describe("AppDocument.blank", () => {
  test("starts an app that already carries its own identity", () => {
    let fresh = AppDocument.blank(~id="new-app", ~title="New app", ~date="2026-08-10", ~locale=Locale.En)
    expect(AppDocument.declaredId(fresh))->toEqual(Some("new-app"))
    let card = AppDocument.summary(~id="new-app", ~source=fresh)
    expect(card.title)->toBe("New app")
    expect(card.date)->toBe("2026-08-10")
  })
})

describe("AppDocument.summary icon", () => {
  let of_ = source => AppDocument.summary(~id="a", ~source).AppDocument.icon

  test("takes the icon the document names", () => {
    expect(of_("---\nicon: calendar\n---\n\nText"))->toBe("calendar")
  })

  // The name arrives from a document, which is to say from outside. One that is not
  // an icon would draw nothing and leave a gap nobody can explain, so it is refused
  // here and the card falls back to the default.
  test("refuses a name Spectrum does not have", () => {
    expect(of_("---\nicon: unicorn\n---\n\nText"))->toBe("")
    expect(of_("---\ntitle: No icon\n---\n\nText"))->toBe("")
    expect(of_("Text with no frontmatter at all"))->toBe("")
  })

  test("the default is an icon Spectrum actually has", () => {
    expect(SpectrumIcons.all->Array.includes(AppDocument.defaultIcon))->toBe(true)
  })
})

describe("AppDocument.summary chat", () => {
  let of_ = source => AppDocument.summary(~id="a", ~source).AppDocument.chat

  test("only the explicit yeses enable it", () => {
    expect(of_("---\nchat: true\n---\n\nText"))->toBe(true)
    expect(of_("---\nchat: yes\n---\n\nText"))->toBe(true)
    expect(of_("---\nchat: on\n---\n\nText"))->toBe(true)
    expect(of_("---\nchat: \"1\"\n---\n\nText"))->toBe(true)
    expect(of_("---\nchat: TRUE\n---\n\nText"))->toBe(true)
  })

  // The value arrives from a document; anything unrecognised — including the
  // field's absence — must not enable a panel by accident.
  test("everything else is no", () => {
    expect(of_("---\nchat: false\n---\n\nText"))->toBe(false)
    expect(of_("---\nchat: maybe\n---\n\nText"))->toBe(false)
    expect(of_("---\ntitle: No chat\n---\n\nText"))->toBe(false)
    expect(of_("Text with no frontmatter at all"))->toBe(false)
  })
})

describe("AppDocument.order", () => {
  test("newest first, then by title", () => {
    let card = (id, title, date): AppDocument.summary => {
      icon: "",
      chat: false,
      id,
      title,
      description: "",
      author: "",
      date,
      version: "",
    }
    let ordered =
      AppDocument.order([
        card("b", "Beta", "2026-01-01"),
        card("c", "Alpha", "2026-05-01"),
        card("a", "Zeta", "2026-05-01"),
      ])->Array.map(summary => summary.id)
    expect(ordered->Array.join(","))->toBe("c,a,b")
  })
})

describe("DocumentKey", () => {
  test("addresses a document without colliding with a collection", () => {
    expect(DocumentKey.of_("grade-book"))->toBe("doc/grade-book")
    expect(DocumentKey.isDocument(CollectionKey.of_(~app="grade-book", ~path="voti")))->toBe(false)
    expect(DocumentKey.isDocument(DocumentKey.of_("grade-book")))->toBe(true)
  })

  test("reads back only keys carrying a valid id", () => {
    expect(DocumentKey.idOf("doc/grade-book"))->toEqual(Some("grade-book"))
    expect(DocumentKey.idOf("doc/Not An Id"))->toEqual(None)
    expect(DocumentKey.idOf("preferences"))->toEqual(None)
  })
})

// The two documents every author sees first follow the interface language. In a
// project where a missing translation is a compile error, leaving these in English
// was the last place it silently was not.
describe("Starter", () => {
  test("the welcome app is written in the chosen language", () => {
    Locale.all->Array.forEach(locale => {
      let text = Starter.of_(locale)
      let document = AppDocument.welcome(~locale, ~date="2026-08-10")
      expect(document->String.includes(text.Starter.welcomeTitle))->toBe(true)
      expect(document->String.includes(text.Starter.saveButton))->toBe(true)
      expect(Frontmatter.parse(document).meta->Option.isSome)->toBe(true)
    })
  })

  test("a new app is written in the chosen language", () => {
    Locale.all->Array.forEach(locale => {
      let text = Starter.of_(locale)
      let document = AppDocument.blank(~id="x", ~title="X", ~date="2026-08-10", ~locale)
      expect(document->String.includes(text.Starter.addHeading))->toBe(true)
      expect(document->String.includes(text.Starter.addButton))->toBe(true)
    })
  })

  test("the document declares the language it was written in", () => {
    let document = AppDocument.welcome(~locale=Locale.It, ~date="2026-08-10")
    let meta = Frontmatter.parse(document).meta->Option.getOrThrow
    expect(Frontmatter.get(meta, "lang"))->toEqual(Some("it"))
  })

  // An icon outside Spectrum's set draws nothing and leaves a gap the author cannot
  // see. The welcome app named one that does not exist, and only the running app
  // said so — this is the check that says it at build time.
  test("every icon the welcome app names exists", () => {
    let body = Frontmatter.parse(AppDocument.welcome(~locale=Locale.En, ~date="2026-08-10")).body
    let named =
      DirectiveScan.scan(body)->Array.filterMap(occurrence =>
        DirectiveAttributes.attribute(occurrence.DirectiveScan.attributes, "icon")
      )
    expect(named->Array.length)->toBe(2)
    named->Array.forEach(icon => expect(SpectrumIcons.all->Array.includes(icon))->toBe(true))
  })

  // The welcome app is two pages holding an accordion holding items; every fence in
  // it has to obey the rule it teaches, or the app that explains nesting is broken.
  test("every container in the welcome app is terminated", () => {
    Locale.all->Array.forEach(locale => {
      let body = Frontmatter.parse(AppDocument.welcome(~locale, ~date="2026-08-10")).body
      let containers =
        DirectiveScan.scan(body)->Array.filter(occurrence =>
          occurrence.DirectiveScan.form == DirectiveScan.Container
        )
      // Two pages at the top level: anything unterminated would fall through as text.
      expect(containers->Array.length)->toBe(2)
    })
  })
})
