type summary = {
  id: string,
  /** The frontmatter title, or the id when there is none. */
  title: string,
  description: string,
  author: string,
  date: string,
  version: string,
  /** A Spectrum workflow icon name the document declared, or the empty string when it
      declared none — or one that is not an icon. */
  icon: string,
  /** Whether the document asks for the chat panel (`chat: true` in the frontmatter).
      Only the explicit yeses count — true, yes, on, 1 — so a stray value from a
      document cannot enable it by accident. */
  chat: bool,
}

/** What an app with no icon of its own is drawn with. */
let defaultIcon: string

let summary: (~id: string, ~source: string) => summary

/** The `appId` the document declares, when it is one this app would accept. */
let declaredId: string => option<string>

/** The document with `appId` set, preserving the order of the other fields. */
let withId: (string, string) => string

/** The id of the welcome app, which is re-seeded whenever it is missing. */
let welcomeId: string

/** The welcome app: a working example of every kind of directive. */
let welcome: (~locale: Locale.t, ~date: string) => string

/** A starting document for a new app. */
let blank: (~id: string, ~title: string, ~date: string, ~locale: Locale.t) => string

/** Newest first, then alphabetical. */
let order: array<summary> => array<summary>
