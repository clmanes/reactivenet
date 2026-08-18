// Pure. An app as a file on disk.
//
// The exported format is the document itself — plain Markdown, frontmatter and all.
// Not a wrapper, not JSON with the source inside a string: the source *is* the app,
// so a file someone opens in any editor is a file they can read, change and bring
// back. It is also what makes an app diffable and storable in a repository.
//
// What is deliberately *not* in the file is the app's stored rows. A document is
// what the author wrote; the rows are what its readers produced, they can be far
// larger, and they are backed up separately from the data panel. Putting them in
// would mean opening a shared app quietly replaced your own data with someone
// else's.

let extension = ".md"

/** What the file is called. The id, not the title: it is the app's identity, it is
    already safe for a filename, and it is what the document will be imported under
    if nothing else claims it. */
let name = id => id ++ extension

let accept = ".md,.markdown,text/markdown"

/** Whether this is a file this app can read at all. A name is the only thing
    available before reading, and refusing early is a better answer than parsing a
    binary and showing an empty document. */
let isDocument = filename => {
  let lower = filename->String.toLowerCase
  lower->String.endsWith(".md") || lower->String.endsWith(".markdown")
}

/** The id an imported document takes.

    Its own `appId` when nothing else has that id, so a file exported from here and
    brought straight back keeps its identity and its URL. When the id is already
    taken the import becomes a *copy* under a free id rather than overwriting: an
    import that silently replaced an app would destroy work with no way back, and a
    duplicate can simply be deleted. */
let idFor = (~source, ~taken, ~fallback) => {
  let declared = AppDocument.declaredId(source)
  switch declared {
  | Some(id) if !(taken->Array.includes(id)) => id
  | Some(id) => AppId.unique(~desired=id, ~taken)
  | None =>
    let title =
      Frontmatter.parse(source).meta
      ->Option.flatMap(meta => Frontmatter.get(meta, "title"))
      ->Option.getOr("")
    AppId.unique(~desired=title == "" ? fallback : title, ~taken)
  }
}

/** True when the import landed somewhere other than where the file said, which is
    the one thing worth telling the person who asked for it. */
let isCopy = (~source, ~id) =>
  switch AppDocument.declaredId(source) {
  | Some(declared) => declared != id
  | None => false
  }
