// Pure. Which page the URL is asking for.
//
// Routes live in the *path*: `/a/grade-book`, not `#/a/grade-book`. A hash costs
// nothing to serve — no rewrite, no configuration — and that is why it was here
// first, but it is in every link anyone copies, and a link is the way an app is
// shared. The price is one rewrite rule wherever this is hosted: every unknown URL
// has to answer with `index.html`. `vite dev` and `vite preview` do it out of the
// box, `public/_redirects` says it for the static hosts that read that file, and the
// service worker's navigation fallback says it again for a reader who is offline.
//
// The two forms are deliberately separate URLs rather than one page with a toggle:
// /a/grade-book is the app as its readers see it, /a/grade-book/edit is the same app
// open in the editor. Sending someone the first is sending them the app.

type t =
  | Gallery
  | View(string)
  | Edit(string)
  /** A link somebody sent. `None`: the app itself rides in the fragment. `Some(id)`:
      the app sits encrypted on the server under this id, and the fragment carries
      the key. */
  | Shared(option<string>)
  /** An invitation to a shared space: the invite record's id, with the key in the
      fragment. */
  | Join(string)
  /** An app of the published catalogue, by its id. Nothing rides in this URL: the
      app fetches the document from the catalogue, which is what makes it work for a
      document of any size — a share link stops at the ceiling of an address. */
  | Catalog(string)

let editSuffix = "edit"
let appSegment = "a"

// A leading `#` is still accepted on the way *in*, so a link someone saved while the
// routes lived in the hash still opens the app it named.
let segments = path =>
  path
  ->String.replace("#", "")
  ->String.split("?")
  ->Array.getUnsafe(0)
  ->String.split("/")
  ->Array.filter(segment => segment != "")

// An unknown or malformed route falls back to the gallery rather than erroring: a
// stale link should land somewhere usable. The id is validated here, so no other
// module has to wonder whether the one it holds came from the URL.
let parse = path =>
  switch segments(path) {
  | [only] if only == ShareLink.segment => Shared(None)
  | [first, id] if first == ShareLink.segment && ShareLink.isShortId(id) => Shared(Some(id))
  | [first, id] if first == SpaceLink.segment && SpaceLink.isInviteId(id) => Join(id)
  // The catalogue's id is an `appId`: it becomes a filename on the way out and a
  // storage key on the way back, and it arrives from a link like every other id
  // here, so it goes through the same validator.
  | [first, id] if first == CatalogLink.segment && AppId.isValid(id) => Catalog(id)
  | [segment, id] if segment == appSegment && AppId.isValid(id) => View(id)
  | [segment, id, suffix] if segment == appSegment && suffix == editSuffix && AppId.isValid(id) =>
    Edit(id)
  | _ => Gallery
  }

let toPath = route =>
  switch route {
  | Gallery => "/"
  | Shared(None) => ShareLink.path
  | Shared(Some(id)) => ShareLink.path ++ "/" ++ id
  | Join(id) => SpaceLink.path ++ "/" ++ id
  | View(id) => "/" ++ appSegment ++ "/" ++ id
  | Edit(id) => "/" ++ appSegment ++ "/" ++ id ++ "/" ++ editSuffix
  | Catalog(id) => "/" ++ CatalogLink.segment ++ "/" ++ id
  }

let appId = route =>
  switch route {
  // A catalogue route names an app that is not here yet: the id in it is the
  // catalogue's, and the one it lands under may differ — an id already taken
  // makes it a copy. Answering with it would have the shell open a document
  // nobody has.
  | Gallery | Shared(_) | Join(_) | Catalog(_) => None
  | View(id) | Edit(id) => Some(id)
  }

let isEditing = route =>
  switch route {
  | Edit(_) => true
  | Gallery | View(_) | Shared(_) | Join(_) | Catalog(_) => false
  }
