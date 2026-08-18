// The app's stored collections: what is there, and the three things you can do to it.
//
// Destructive actions confirm in a modal, the same one the gallery uses to delete an
// app: dropping rows is irreversible and a button that only repeats its own label
// cannot say so. `ConfirmDialog` is the native <dialog>, so this is not
// `window.confirm` — it is named, translated and dismissible the ways a dialog should
// be.

@val @scope("window") external listen: (string, unit => unit) => unit = "addEventListener"
@val @scope("window") external unlisten: (string, unit => unit) => unit = "removeEventListener"

type pending =
  | Nothing
  | DeleteCollection(string)
  | DeleteEverything

// Written here rather than plumbed through props: the preview is bound by
// `CollectionBinder`, which is not a React component and has no way of being told.
// One event, and every view of these collections reads them again.
let announce: unit => unit = %raw(`
function () { window.dispatchEvent(new Event("rn:data")); }
`)

@react.component
let make = (~app: option<string>, ~locale: Locale.t, ~clock: unit => string) => {
  let t = key => Translations.translate(locale, key)
  let (collections, setCollections) = React.useState(() => [])
  let (pending, setPending) = React.useState(() => Nothing)
  let (message, setMessage) = React.useState(() => "")
  // The collection to import into when it is not in the list below, which is the
  // case that matters: the list holds what has been WRITTEN, and an app nobody has
  // typed into yet has written nothing. So the one moment a spreadsheet is most
  // wanted — a school starting from the file it already has — was the one moment
  // there was no button for it. The name is typed rather than chosen for the same
  // reason: what is not there cannot be offered.
  let (into, setInto) = React.useState(() => "")

  let refresh = app =>
    CollectionStore.exportAll(~app)
    ->Promise.thenResolve(found => setCollections(_ => found))
    ->ignore

  React.useEffect1(() => {
    switch app {
    | Some(app) => refresh(app)
    | None => setCollections(_ => [])
    }
    None
  }, [app->Option.getOr("")])

  // The panel's counts follow the rows, whoever moved them: its own writes announce
  // `rn:data` for the preview's sake, and a `::python` block with `writes` announces
  // it for everyone — this panel included, which otherwise sat on stale numbers.
  React.useEffect1(() => {
    let update = () =>
      switch app {
      | Some(app) => refresh(app)
      | None => ()
      }
    listen("rn:data", update)
    Some(() => unlisten("rn:data", update))
  }, [app->Option.getOr("")])

  switch app {
  | None =>
    <aside className="rn-info rn-divider border-b px-6 py-3 text-sm">
      <p className="rn-muted"> {React.string(t(NoAppId))} </p>
    </aside>
  | Some(app) =>
    let backup = () => {
      CollectionStore.exportAll(~app)
      ->Promise.thenResolve(found =>
        FileTransfer.download(app ++ "-backup.json", Backup.encode(app, clock(), found))
      )
      ->ignore
    }

    let restore = () =>
      FileTransfer.readTextFile(text =>
        switch Backup.decode(text) {
        | Error(error) => setMessage(_ => Backup.errorToString(error))
        // Restoring one app's data into another corrupts both, so a foreign backup is
        // refused outright rather than merged.
        | Ok(found) if !Backup.belongsTo(found, app) =>
          setMessage(_ => t(BackupFromOtherApp) ++ " (" ++ found.app ++ ")")
        | Ok(found) =>
          CollectionStore.importAll(~app, found.collections)
          ->Promise.thenResolve(() => {
            setMessage(_ => "")
            refresh(app)
            announce()
          })
          ->ignore
        }
      )

    // One collection, in the shape other things read. The backup above is the whole
    // app in the app's own shape and is for putting it back; this is for taking the
    // rows somewhere else — and bringing somebody else's in.
    let exportCollection = (path, collection) =>
      FileTransfer.download(app ++ "-" ++ path ++ ".csv", Csv.encode(collection))

    // The same rows as a real .xlsx — the codec is a lazy chunk, loaded the
    // first time either button is pressed and never before.
    let exportExcel = (path, collection) =>
      import(XlsxImpl.toBytes)
      ->Promise.thenResolve(toBytes =>
        FileTransfer.downloadBinary(app ++ "-" ++ path ++ ".xlsx", toBytes(Sheet.encode(collection)))
      )
      ->ignore

    let importExcel = path =>
      FileTransfer.readBinaryFile(
        ~accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        buffer =>
          import(XlsxImpl.parse)
          ->Promise.then(parse => {
            let grid = parse(buffer)
            CollectionStore.read(~app, ~path)->Promise.thenResolve(current => {
              // Ids the file does not carry are minted against the ones already
              // stored — the same line the CSV import draws, because it is about
              // spreadsheets, not about commas.
              let taken = current.records->Array.map(record => record.Collection.id)
              let arriving = Sheet.decode(
                grid,
                ~makeId=used => RecordId.make(~stamp=clock(), ~taken=taken->Array.concat(used)),
              )
              if arriving->Array.length == 0 {
                setMessage(_ => t(NotACollectionFile))
              } else {
                let merged = arriving->Array.reduce(current, (into, record) =>
                  Collection.find(into, record.Collection.id)->Option.isSome
                    ? Collection.update(into, record.id, record.fields)
                    : Collection.insert(into, record)
                )
                CollectionStore.write(~app, ~path, merged)
                ->Promise.thenResolve(() => {
                  setMessage(_ =>
                    t(RowsImported)->String.replace("{n}", arriving->Array.length->Int.toString)
                  )
                  refresh(app)
                  announce()
                })
                ->ignore
              }
            })
          })
          ->ignore,
      )

    let importCollection = path =>
      FileTransfer.readTextFile(~accept=".csv,text/csv", text => {
        let existing = CollectionStore.read(~app, ~path)
        existing
        ->Promise.thenResolve(current => {
          // Ids the file does not carry are minted against the ones already stored,
          // so importing twice adds rows rather than overwriting the ones it hits.
          let taken = current.records->Array.map(record => record.Collection.id)
          let arriving = Csv.decode(
            text,
            ~makeId=used =>
              RecordId.make(~stamp=clock(), ~taken=taken->Array.concat(used)),
          )
          if arriving->Array.length == 0 {
            setMessage(_ => t(NotACollectionFile))
          } else {
            // A row the file claims by id replaces that row; everything else is added.
            let merged = arriving->Array.reduce(current, (into, record) =>
              Collection.find(into, record.Collection.id)->Option.isSome
                ? Collection.update(into, record.id, record.fields)
                : Collection.insert(into, record)
            )
            CollectionStore.write(~app, ~path, merged)
            ->Promise.thenResolve(() => {
              setMessage(_ =>
                t(RowsImported)->String.replace("{n}", arriving->Array.length->Int.toString)
              )
              refresh(app)
              announce()
            })
            ->ignore
          }
        })
        ->ignore
      })

    let runPending = () =>
      switch pending {
      | Nothing => ()
      | DeleteEverything =>
        CollectionStore.clear(~app)
        ->Promise.thenResolve(() => {
          refresh(app)
          announce()
        })
        ->ignore
      | DeleteCollection(path) =>
        CollectionStore.remove(~app, ~path)
        ->Promise.thenResolve(() => {
          refresh(app)
          announce()
        })
        ->ignore
      }

    <aside className="rn-info rn-divider border-b px-6 py-3 text-sm">
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <h2 className="rn-muted text-xs font-semibold tracking-wide uppercase">
          {React.string(t(DataPanel) ++ " · " ++ app)}
        </h2>
        <div className="flex items-center gap-2">
          <Spectrum.ActionButton label={t(BackupAction)} onClick={_ => backup()}>
            {React.string(t(BackupAction))}
          </Spectrum.ActionButton>
          <Spectrum.ActionButton label={t(RestoreAction)} onClick={_ => restore()}>
            {React.string(t(RestoreAction))}
          </Spectrum.ActionButton>
          <Spectrum.ActionButton
            label={t(DeleteData)}
            onClick={_ => setPending(_ => DeleteEverything)}>
            {React.string(t(DeleteData))}
          </Spectrum.ActionButton>
        </div>
      </div>
      {message == "" ? React.null : <p className="rn-error mb-2"> {React.string(message)} </p>}
      // The two buttons appear only once there is a name: a control that cannot act
      // says nothing about why, and there is nothing here to disable it *for*.
      <div className="mb-2 flex flex-wrap items-center gap-2">
        <Spectrum.FieldLabel for_="rn-import-into" size="s">
          {React.string(t(ImportIntoCollection))}
        </Spectrum.FieldLabel>
        <Spectrum.Textfield
          id="rn-import-into"
          value={into}
          placeholder={t(CollectionName)}
          size="s"
          onInput={event => {
            let value: string = (event->JsxEvent.Form.target)["value"]
            setInto(_ => value)
          }}
        />
        {into->String.trim == ""
          ? React.null
          : <>
              <Spectrum.ActionButton
                label={t(ImportCollection) ++ ": " ++ into->String.trim}
                onClick={_ => importCollection(into->String.trim)}>
                {React.string("CSV ↑")}
              </Spectrum.ActionButton>
              <Spectrum.ActionButton
                label={t(ImportCollection) ++ " (Excel): " ++ into->String.trim}
                onClick={_ => importExcel(into->String.trim)}>
                {React.string("XLSX ↑")}
              </Spectrum.ActionButton>
            </>}
      </div>
      {collections->Array.length == 0
        ? <p className="rn-muted"> {React.string(t(NoCollections))} </p>
        : <ul className="flex flex-col gap-1">
            {collections
            ->Array.map(((path, collection)) =>
              <li key={path} className="flex items-center justify-between gap-3">
                <span className="font-mono text-xs"> {React.string(path)} </span>
                <span className="rn-muted text-xs">
                  {React.string(Collection.size(collection)->Int.toString)}
                </span>
                <div className="flex items-center gap-1">
                  <Spectrum.ActionButton
                    label={t(ExportCollection) ++ ": " ++ path}
                    onClick={_ => exportCollection(path, collection)}>
                    {React.string("CSV ↓")}
                  </Spectrum.ActionButton>
                  <Spectrum.ActionButton
                    label={t(ImportCollection) ++ ": " ++ path}
                    onClick={_ => importCollection(path)}>
                    {React.string("CSV ↑")}
                  </Spectrum.ActionButton>
                  <Spectrum.ActionButton
                    label={t(ExportCollection) ++ " (Excel): " ++ path}
                    onClick={_ => exportExcel(path, collection)}>
                    {React.string("XLSX ↓")}
                  </Spectrum.ActionButton>
                  <Spectrum.ActionButton
                    label={t(ImportCollection) ++ " (Excel): " ++ path}
                    onClick={_ => importExcel(path)}>
                    {React.string("XLSX ↑")}
                  </Spectrum.ActionButton>
                  <Spectrum.ActionButton
                    label={t(DeleteData) ++ ": " ++ path}
                    onClick={_ => setPending(_ => DeleteCollection(path))}>
                    {React.string("×")}
                  </Spectrum.ActionButton>
                </div>
              </li>
            )
            ->React.array}
          </ul>}
      // Always mounted and driven by `open_`, for the reason in ConfirmDialog: the
      // dialog cannot be opened in the same commit that first puts it in the document.
      <ConfirmDialog
        open_={pending != Nothing}
        title={t(DeleteDataQuestion)}
        message={switch pending {
        | DeleteCollection(path) => path ++ " — " ++ t(DeleteDataWarning)
        | Nothing | DeleteEverything => t(DeleteDataWarning)
        }}
        confirmLabel={t(DeleteData)}
        cancelLabel={t(CancelAction)}
        onConfirm={() => {
          runPending()
          setPending(_ => Nothing)
        }}
        onCancel={() => setPending(_ => Nothing)}
      />
    </aside>
  }
}
