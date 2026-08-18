// The chat between the people using an app, opened by the speech-bubble button the
// document asks for with `chat: true` in its frontmatter.
//
// The messages are rows of an ordinary collection, `chat`, and that is the whole
// design: they are stored like every other row (reserved stamps included), they
// travel with the data backup, and when the app is linked to a shared space they
// sync — end-to-end encrypted — exactly the way every other collection does,
// arriving live over the same `rn:data` event this panel already listens for. A
// reader's messages stay local, which is what read-only means here; nothing in this
// component needs to know any of that.

@val @scope("window") external listen: (string, unit => unit) => unit = "addEventListener"
@val @scope("window") external unlisten: (string, unit => unit) => unit = "removeEventListener"

type fieldTarget = {value: string}
@get external fieldValue: JsxEvent.Form.t => fieldTarget = "target"
@get external keyOf: JsxEvent.Keyboard.t => string = "key"

// Written for the same reason DataPanel writes it: the preview is bound by
// `CollectionBinder`, and a document that also renders `::list{path="chat"}` has no
// other way of hearing that the rows moved.
let announce: unit => unit = %raw(`
function () { window.dispatchEvent(new Event("rn:data")); }
`)

// The list scrolls itself to the newest message: a chat that opens on its oldest
// line, or sits still while messages arrive below the fold, reads as silent.
let scrollToEnd: Nullable.t<Dom.element> => unit = %raw(`
function (node) { if (node) node.scrollTop = node.scrollHeight; }
`)

let path = "chat"

// The attachment ceiling, in bytes of the file itself. A message travels inside a
// sync change, and the server refuses a change past 2,000,000 characters — by the
// time a file has become base64 in a data: URL, then part of an Automerge change,
// then AES-GCM output, then base64 again, 700 kB of file is about 1.3M characters
// of payload. Refusing here, in words, beats a sync that silently never delivers.
let maxAttachmentBytes = 700_000

@react.component
let make = (~app: option<string>, ~locale: Locale.t, ~author: option<string>, ~clock: unit => string) => {
  let t = key => Translations.translate(locale, key)
  let (messages, setMessages) = React.useState((): array<Collection.record> => [])
  let (draft, setDraft) = React.useState(() => "")
  let (notice, setNotice) = React.useState(() => "")
  let list = React.useRef(Nullable.null)

  let refresh = app =>
    CollectionStore.read(~app, ~path)
    ->Promise.thenResolve(found => {
      // Ordered by when they were said. The stamp is ISO, so text order is time
      // order; a row imported without one falls back to its id, which is minted
      // from the same clock.
      let saidAt = record =>
        Stamps.createdOf(record)->Option.getOr(record.Collection.id)
      setMessages(_ =>
        found.Collection.records->Array.toSorted((a, b) => String.compare(saidAt(a), saidAt(b)))
      )
    })
    ->ignore

  React.useEffect1(() => {
    switch app {
    | Some(app) => refresh(app)
    | None => setMessages(_ => [])
    }
    None
  }, [app->Option.getOr("")])

  // Messages moved by anybody — this panel, a remote member via the sync engine, a
  // restore from the data panel — all announce the same event.
  React.useEffect1(() => {
    let update = () =>
      switch app {
      | Some(app) => refresh(app)
      | None => ()
      }
    listen("rn:data", update)
    Some(() => unlisten("rn:data", update))
  }, [app->Option.getOr("")])

  React.useEffect1(() => {
    scrollToEnd(list.current)
    None
  }, [messages->Array.length])

  // One writer for both kinds of message. A file rides in the same row as its
  // caption: `file` is the whole content as a data: URL, `filename` what to call
  // it on the way back out.
  let deliver = (app, ~file: option<FileTransfer.picked>) => {
    let text = draft->String.trim
    setDraft(_ => "")
    setNotice(_ => "")
    CollectionStore.read(~app, ~path)
    ->Promise.then(current => {
      let now = clock()
      let taken = current.Collection.records->Array.map(record => record.Collection.id)
      let fields = [
        {Collection.name: "author", value: author->Option.getOr("")},
        {Collection.name: "text", value: text},
      ]
      let fields = switch file {
      | Some(chosen) =>
        fields->Array.concat([
          {Collection.name: "file", value: chosen.FileTransfer.dataUrl},
          {Collection.name: "filename", value: chosen.FileTransfer.name},
        ])
      | None => fields
      }
      let record: Collection.record = {
        id: RecordId.make(~stamp=now, ~taken),
        fields: Stamps.apply(fields, ~now),
      }
      CollectionStore.write(~app, ~path, Collection.insert(current, record))
    })
    ->Promise.thenResolve(() => {
      announce()
      refresh(app)
    })
    ->ignore
  }

  let send = () =>
    switch app {
    | Some(app) if draft->String.trim != "" => deliver(app, ~file=None)
    | _ => ()
    }

  let attach = () =>
    switch app {
    | Some(app) =>
      FileTransfer.readAttachment(~maxBytes=maxAttachmentBytes)
      ->Promise.thenResolve(picked =>
        switch picked {
        | Some(chosen) if chosen.FileTransfer.tooBig => setNotice(_ => t(ChatFileTooBig))
        | Some(chosen) => deliver(app, ~file=Some(chosen))
        | None => ()
        }
      )
      ->ignore
    | None => ()
    }

  switch app {
  | None =>
    <aside className="rn-info rn-divider border-b px-6 py-3 text-sm">
      <p className="rn-muted"> {React.string(t(NoAppId))} </p>
    </aside>
  | Some(_) =>
    <aside className="rn-info rn-divider border-b px-6 py-3 text-sm">
      <h2 className="rn-muted mb-2 text-xs font-semibold tracking-wide uppercase">
        {React.string(t(ChatPanel))}
      </h2>
      {messages->Array.length == 0
        ? <p className="rn-muted"> {React.string(t(ChatEmpty))} </p>
        : <ol ref={ReactDOM.Ref.domRef(list)} className="rn-chat-list">
            {messages
            ->Array.map(record => {
              let who = Collection.field(record, "author")->Option.getOr("")
              let mine = who != "" && author == Some(who)
              <li
                key={record.Collection.id}
                className={mine ? "rn-chat-message rn-chat-mine" : "rn-chat-message"}>
                <div className="rn-chat-meta">
                  <span className="rn-chat-author">
                    {React.string(who == "" ? t(ChatGuest) : who)}
                  </span>
                  <span className="rn-muted">
                    {React.string(
                      Stamps.createdOf(record)
                      ->Option.getOr("")
                      ->Clock.localize(~locale=Locale.toTag(locale)),
                    )}
                  </span>
                </div>
                {switch Collection.field(record, "text")->Option.getOr("") {
                | "" => React.null
                // Markdown, and from somebody else: the links are re-checked and the
                // directives are not parsed at all — a message is not an app.
                | text => <MessageText text locale className="rn-chat-text" />
                }}
                {{
                  // The value comes from a row, which is to say from anybody in the
                  // space: only a data: URL is ever rendered, so a stored
                  // `javascript:` never becomes a link — same allowlist thinking as
                  // SafeUrl, enforced where the untrusted value meets the DOM.
                  let stored = Collection.field(record, "file")->Option.getOr("")
                  let fileUrl = stored->String.startsWith("data:") ? stored : ""
                  let filename = Collection.field(record, "filename")->Option.getOr("")
                  switch fileUrl {
                  | "" => React.null
                  | url if url->String.startsWith("data:image/") =>
                    // An image is shown, and is also its own download link.
                    <a href={url} download={filename} className="rn-chat-file">
                      <img
                        src={url}
                        alt={filename}
                        className="rn-chat-image"
                        loading={#lazy}
                      />
                    </a>
                  | url =>
                    <a href={url} download={filename} className="rn-chat-file">
                      {React.string(filename == "" ? "file" : filename)}
                    </a>
                  }
                }}
              </li>
            })
            ->React.array}
          </ol>}
      {notice == "" ? React.null : <p className="rn-error mt-2"> {React.string(notice)} </p>}
      <div className="rn-share-row mt-2">
        <input
          className="rn-share-link"
          type_="text"
          value={draft}
          placeholder={t(ChatPlaceholder)}
          ariaLabel={t(ChatPlaceholder)}
          onChange={event => {
            let next = fieldValue(event).value
            setDraft(_ => next)
          }}
          onKeyDown={event =>
            if keyOf(event) == "Enter" {
              send()
            }}
        />
        <Spectrum.ActionButton label={t(ChatAttach)} onClick={_ => attach()}>
          Icons.paperclip
        </Spectrum.ActionButton>
        <Spectrum.Button variant="accent" onClick={_ => send()}>
          {React.string(t(ChatSend))}
        </Spectrum.Button>
      </div>
    </aside>
  }
}
