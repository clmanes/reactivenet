open BunTest

let t = (locale, key) => Translations.translate(locale, key)

// The catalogue is exhaustive by construction — the compiler rejects a missing arm —
// so these tests guard the things the type system cannot see: empty strings, and
// copy-paste that leaves one language showing another's text.
describe("Translations", () => {
  test("no message is empty in any language", () => {
    let empty =
      Locale.all
      ->Array.flatMap(locale =>
        Translations.allKeys
        ->Array.filter(key => t(locale, key)->String.trim == "")
        ->Array.map(_ => Locale.toTag(locale))
      )
      ->Array.join(",")
    expect(empty)->toBe("")
  })

  test("translates the panes", () => {
    expect(t(En, PreviewPane))->toBe("Preview")
    expect(t(Fr, PreviewPane))->toBe("Aperçu")
    expect(t(De, PreviewPane))->toBe("Vorschau")
    expect(t(Es, PreviewPane))->toBe("Vista previa")
    expect(t(Pt, PreviewPane))->toBe("Pré-visualização")
    expect(t(Zh, PreviewPane))->toBe("预览")
    expect(t(It, PreviewPane))->toBe("Anteprima")
  })

  // Some strings are legitimately identical to English. Declared per (language, key)
  // rather than per key, so an exception granted to one language cannot hide a
  // genuinely untranslated string in another:
  //   - "Editor" is the same loanword in German, Spanish, Portuguese and Italian.
  //   - "Palette" and "Directives" are simply the French words.
  let sharedEverywhere: array<Translations.key> = []
  let sharedInSomeLanguages = [
    (Locale.De, Translations.EditorPane),
    (Locale.Es, Translations.EditorPane),
    (Locale.Pt, Translations.EditorPane),
    (Locale.It, Translations.EditorPane),
    (Locale.Fr, Translations.PaletteLabel),
    (Locale.Fr, Translations.Directives),
    // "App" is the same borrowed abbreviation in German as in English.
    (Locale.De, Translations.Gallery),
    // "Pages" is spelt the same in French.
    (Locale.Fr, Translations.Pages),
    // "Account" and "Password" are the loanwords everyday Italian actually uses;
    // "Profilo" or "Parola d'ordine" would be translation for its own sake.
    (Locale.It, Translations.AccountLabel),
    (Locale.It, Translations.PasswordLabel),
    // "Chat" is the loanword German, Spanish and Italian actually use for the thing.
    (Locale.De, Translations.ChatPanel),
    (Locale.Es, Translations.ChatPanel),
    (Locale.It, Translations.ChatPanel),
    // "Assistant" is simply the French word.
    (Locale.Fr, Translations.AiPanel),
  ]

  test("non-English locales differ from English where they should", () => {
    let translatable =
      Translations.allKeys->Array.filter(key => !(sharedEverywhere->Array.includes(key)))
    let untranslated =
      Locale.all
      ->Array.filter(locale => locale != Locale.En)
      ->Array.flatMap(locale =>
        translatable
        ->Array.filter(key =>
          // Structural comparison, not Array.includes: ReScript tuples compile to
          // arrays, and includes compares by reference, so a tuple literal never
          // matches one built elsewhere.
          t(locale, key) == t(En, key) &&
            !(sharedInSomeLanguages->Array.some(((l, k)) => l == locale && k == key))
        )
        ->Array.map(key => Locale.toTag(locale) ++ ":" ++ Translations.translate(En, key))
      )
      ->Array.join(",")
    expect(untranslated)->toBe("")
  })

  // WCAG 2.2 §2.4.6: the accessible name has to say what the control does, so these
  // read "Markdown editor" rather than just naming the format — while still carrying
  // the proper noun, which is not translated in any language.
  test("the editor labels name the format and describe the control", () => {
    let missing =
      Locale.all
      ->Array.filter(locale => !(t(locale, MarkdownEditor)->String.includes("Markdown")))
      ->Array.map(Locale.toTag)
      ->Array.join(",")
    expect(missing)->toBe("")
  })

  test("the editor labels are more than the bare format name", () => {
    let bare =
      Locale.all
      ->Array.filter(locale => t(locale, MarkdownEditor) == "Markdown")
      ->Array.map(Locale.toTag)
      ->Array.join(",")
    expect(bare)->toBe("")
  })

  // The two routes an app has are named differently in every language: the control
  // that moves between them is a single button whose label is the only thing saying
  // which way it goes.
  test("viewing and editing are distinct in every language", () => {
    let same =
      Locale.all->Array.filter(locale => t(locale, ViewApp) == t(locale, EditApp))->Array.length
    expect(same)->toBe(0)
  })
})
