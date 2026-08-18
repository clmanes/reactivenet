// Persistence for app documents, on top of the one IndexedDB store.
//
// Everything here is a thin composition of `Idb` and the pure key modules; the
// decisions — what an id may be, what a card shows — are made in `core/`. Failures
// resolve to "nothing" the same way `Idb`'s do: a gallery that cannot read storage
// shows no apps rather than an error page.

let load = id => Idb.get(DocumentKey.of_(id))->Promise.thenResolve(Nullable.toOption)

let save = (~id, ~source) => Idb.set(DocumentKey.of_(id), source)

let ids = () =>
  Idb.keys()->Promise.thenResolve(keys => keys->Array.filterMap(DocumentKey.idOf))

// One read per document. The alternative — a separate index of summaries — would be
// a second source of truth for the title, and the number of apps one person keeps in
// a browser does not justify it.
let list = () =>
  ids()
  ->Promise.then(found =>
    found
    ->Array.map(id =>
      load(id)->Promise.thenResolve(source =>
        source->Option.map(text => AppDocument.summary(~id, ~source=text))
      )
    )
    ->Promise.all
  )
  ->Promise.thenResolve(summaries => summaries->Array.filterMap(summary => summary)->AppDocument.order)

// Deleting an app deletes its data with it. Leaving the collections behind would
// orphan them under a namespace nothing can reach any more — and a later app with
// the same id would silently inherit them.
let remove = id =>
  Idb.keys()
  ->Promise.then(keys => {
    let mine =
      keys->Array.filter(key =>
        key == DocumentKey.of_(id) || key->String.startsWith(CollectionKey.appPrefix(id))
      )
    mine->Array.map(Idb.remove)->Promise.all
  })
  ->Promise.thenResolve(_ => ())

/** Moves a document to a new id, taking its collections with it. */
let rename = (~from, ~to_, ~source) =>
  from == to_
    ? save(~id=to_, ~source)
    : Idb.keys()
      ->Promise.then(keys => {
        let collections = keys->Array.filterMap(key =>
          CollectionKey.pathOf(~app=from, key)->Option.map(path => (key, path))
        )
        collections
        ->Array.map(((key, path)) =>
          Idb.get(key)->Promise.then(value =>
            switch Nullable.toOption(value) {
            | None => Promise.resolve()
            | Some(stored) =>
              Idb.set(CollectionKey.of_(~app=to_, ~path), stored)->Promise.then(() =>
                Idb.remove(key)
              )
            }
          )
        )
        ->Promise.all
      })
      ->Promise.then(_ => Idb.remove(DocumentKey.of_(from)))
      ->Promise.then(() => save(~id=to_, ~source))

/** Copies an app under a free id: the document, and not the rows.
    That is the same line a file draws. A document is what the author wrote and a
    copy of it is a new app to change; the rows are what its readers produced, they
    can be far larger than the document, and duplicating a shopping list to start
    next week's should not hand you last week's shopping. */
let duplicate = from =>
  load(from)->Promise.then(stored =>
    switch stored {
    | None => Promise.resolve(None)
    | Some(source) =>
      ids()->Promise.then(taken => {
        let id = AppId.unique(~desired=from, ~taken)
        // The document carries its own id, so the copy has to be told what it is —
        // otherwise the frontmatter, the storage key and the URL disagree the moment
        // it is opened.
        save(~id, ~source=AppDocument.withId(source, id))->Promise.thenResolve(() => Some(id))
      })
    }
  )
