type t =
  | Gallery
  /** An app as its readers see it: preview only. */
  | View(string)
  /** The same app open in the editor. */
  | Edit(string)
  /** A link somebody sent: the app in the fragment, or on the server under an id
      with the key in the fragment. */
  | Shared(option<string>)
  /** An invitation to a shared space: the invite record's id, with the key in the
      fragment. */
  | Join(string)
  /** An app of the published catalogue, by its id. Nothing rides in this URL: the
      app fetches the document from the catalogue, which is what makes it work for
      a document of any size — a share link stops at the ceiling of an address. */
  | Catalog(string)

/** Reads a `location.pathname`. A leading `#` is tolerated so a link saved when the
    routes lived in the hash still resolves. Anything unrecognised — including an id
    the validator refuses — is the gallery, so a stale link lands somewhere usable. */
let parse: string => t

/** The path that addresses this route, from the root. */
let toPath: t => string

let appId: t => option<string>

let isEditing: t => bool
