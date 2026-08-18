// The platform's own share sheet, where there is one.
//
// It is the honest way to reach the apps somebody actually uses: the sheet lists what
// is installed on that device — mail, messages, whichever social apps are there — and
// nothing about which ones those are ever reaches this app. The alternative, a row of
// hand-written buttons for five services, is a guess about the reader and a set of
// third-party URLs baked into a page that otherwise talks to nobody.
//
// Where there is no sheet (most desktops), the dialog falls back to the link itself
// and a mail draft, which is the same act with two more clicks.

let available: unit => bool = %raw(`
function () { return typeof navigator !== "undefined" && typeof navigator.share === "function"; }
`)

/** Resolves true when the sheet was used, false when it was dismissed or refused.
    A dismissal is the ordinary path, not an error: somebody opened the sheet and
    changed their mind. */
let share: (~title: string, ~text: string, ~url: string) => promise<bool> = %raw(`
function (title, text, url) {
  try {
    return navigator.share({ title, text, url }).then(() => true, () => false);
  } catch (error) {
    return Promise.resolve(false);
  }
}
`)

/** A `mailto:` with the subject and body already written. Built here rather than in a
    component because the escaping is the whole job: a link inside a mail body has to
    survive being a query parameter. */
let mailto = (~subject, ~body) =>
  "mailto:?subject=" ++ encodeURIComponent(subject) ++ "&body=" ++ encodeURIComponent(body)
