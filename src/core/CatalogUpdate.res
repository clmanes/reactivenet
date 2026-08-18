// Pure. Which of the apps this browser already has the catalogue publishes a newer
// version of.
//
// The catalogue offers what is NOT here, because offering what you have would be
// offering a copy. That left the other half of the question unanswered: an app
// installed six months ago stays as it was for ever, and the only way to get the
// version published since was to delete it and take it again — which is exactly the
// operation nobody dares do, because deleting an app deletes its data with it.
//
// So the answer is here, and it is deliberately just a comparison of two strings the
// two sides already write down. The version lives in the frontmatter, `AppDocument.
// summary` already reads it, and `site/scripts/app-links.mjs` already has the
// document in its hand when it writes the index. Nothing new is stored anywhere for
// this to work.
//
// Two rules decide everything, and both are about not overstating:
//
//   - An update is offered only when BOTH versions are written. A document that
//     declares no version is not claiming to be old, it is claiming nothing, and
//     announcing an update on a comparison with the empty string would be inventing
//     a fact. Silence is the honest answer.
//   - Only strictly newer counts. The same version is not an update, and an older
//     one in the catalogue — which happens while a release is being rolled back —
//     is not something a reader should be invited to install over what they have.

type entry = {id: string, title: string, version: string}

/** An update this browser could take: which app, and between which two versions. The
    titles are both carried because they can differ — the published app may have been
    renamed — and a question that says only one of them cannot be answered honestly. */
type offer = {
  id: string,
  /** The title as this browser has it: what is on the card being offered the update. */
  installedTitle: string,
  /** The title the catalogue publishes, which is what will replace it. */
  publishedTitle: string,
  installed: string,
  published: string,
}

// A version is compared segment by segment, numerically where both segments are
// numbers and as text otherwise. "1.10" is after "1.9", which a plain string compare
// gets backwards, and that is the whole reason this is not `>`. A missing segment is
// zero: "2" and "2.0" are the same version written two ways.
//
// What counts as a number is `Numeric`, and not `Int.fromString`: that one reads a
// numeric PREFIX and stops, so "0-beta" and "0-alpha" both come back as zero and two
// different versions compare equal. It is the same trap the aggregations and the
// sorts already went through once, in the same repository, for the same reason.
let rec compareParts = (left, right, index) => {
  let (a, b) = (Array.length(left), Array.length(right))
  let count = a > b ? a : b
  if index >= count {
    0
  } else {
    let a = left->Array.at(index)->Option.getOr("0")
    let b = right->Array.at(index)->Option.getOr("0")
    let verdict = switch (Numeric.parse(a), Numeric.parse(b)) {
    | (Some(x), Some(y)) => x == y ? 0 : x < y ? -1 : 1
    | _ => a == b ? 0 : a < b ? -1 : 1
    }
    verdict == 0 ? compareParts(left, right, index + 1) : verdict
  }
}

let parts = version => version->String.trim->String.split(".")

/** Negative when the first version is older, zero when they are the same version,
    positive when it is newer. */
let compare = (left, right) => compareParts(parts(left), parts(right), 0)

/** Whether what the catalogue publishes is newer than what is installed. Either one
    unwritten means the question has no answer, and the answer to a question with no
    answer is no. */
let isNewer = (~installed, ~published) =>
  String.trim(installed) != "" &&
  String.trim(published) != "" &&
  compare(published, installed) > 0

/** The updates on offer, in the order the installed apps came in. An app the
    catalogue does not publish, or publishes at the same version, produces nothing —
    so an empty array is the ordinary case and means "everything is current". */
let offers = (~installed: array<AppDocument.summary>, ~published: array<entry>) =>
  installed->Array.filterMap(app =>
    published
    ->Array.find(entry => entry.id == app.id)
    ->Option.flatMap(entry =>
      isNewer(~installed=app.version, ~published=entry.version)
        ? Some({
            id: app.id,
            installedTitle: app.title,
            publishedTitle: entry.title == "" ? app.title : entry.title,
            installed: app.version,
            published: entry.version,
          })
        : None
    )
  )

/** The offer for one app, when there is one. What a card asks about itself. */
let offerFor = (~id, ~offers: array<offer>) => offers->Array.find(offer => offer.id == id)
