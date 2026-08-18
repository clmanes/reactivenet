/** The stored source of one app, or nothing when it was never saved. */
let load: string => promise<option<string>>

let save: (~id: string, ~source: string) => promise<unit>

/** Every stored app, newest first. Storage failures resolve to an empty list. */
let list: unit => promise<array<AppDocument.summary>>

let ids: unit => promise<array<string>>

/** Deletes the document *and* the app's collections: leaving them would orphan data
    under a namespace nothing can reach, and hand it to the next app with that id. */
let remove: string => promise<unit>

/** Moves a document to a new id, carrying its collections across. */
let rename: (~from: string, ~to_: string, ~source: string) => promise<unit>

/** Copies an app under a free id and answers with it. The document only: the rows
    belong to the app that collected them. */
let duplicate: string => promise<option<string>>
