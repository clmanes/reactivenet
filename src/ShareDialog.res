// Sending an app to somebody.
//
// "Copy link" copies an *address*, and an address only opens something the other
// person already has: every app here lives in one browser. So a shared app travels
// inside the link — `core/ShareLink` decides the shape, `shell/SharePayload` does the
// compressing — and what this dialog does is hand that link over in the ways people
// actually send things.
//
// The platform's own share sheet first, where there is one: it lists the apps that
// are installed on that device, which is a better answer than five hard-coded
// buttons, and it tells this app nothing about which ones they are. Where there is no
// sheet, the link and a mail draft do the same job.
//
// The sentence under the field is not decoration. A link that carries the app but not
// its rows is a surprise unless it is said plainly, and it is the one thing somebody
// sharing a list of expenses needs to know before they press send.

@react.component
let make = (
  ~open_: bool,
  ~locale: Locale.t,
  ~title: string,
  ~link: string,
  ~shortLink: string,
  ~tooBig: bool,
  ~onClose: unit => unit,
) => {
  let t = key => Translations.translate(locale, key)
  let dialog = React.useRef(Nullable.null)
  let (copied, setCopied) = React.useState(() => false)

  React.useEffect1(() => {
    switch dialog.current->Nullable.toOption {
    | Some(element) => NativeDialog.follow(element, ~open_, ~onDismiss=() => onClose())
    | None => None
    }
  }, [open_])

  React.useEffect1(() => {
    setCopied(_ => false)
    None
  }, [link])

  let invitation = ShareLink.message(~title, ~invitation=t(ShareInvitation))

  // What gets copied, mailed and handed to the share sheet: the short link when the
  // server answered, the long one otherwise. The long link never disappears — it is
  // the form that needs no server and works offline — it just stops being the
  // headline when a five-line URL has a one-line alternative.
  let primary = shortLink == "" ? link : shortLink

  let copy = () =>
    Clipboard.copy(primary)->Promise.thenResolve(done => setCopied(_ => done))->ignore

  let copyLong = () =>
    Clipboard.copy(link)->Promise.thenResolve(done => setCopied(_ => done))->ignore

  let sheet = () =>
    Share.share(~title=title == "" ? t(ShareApp) : title, ~text=invitation, ~url=primary)->ignore

  <dialog
    ref={ReactDOM.Ref.domRef(dialog)}
    className="rn-dialog rn-surface"
    ariaLabelledby="rn-share-title">
    <h2 id="rn-share-title" className="rn-dialog-title"> {React.string(t(ShareApp))} </h2>
    {tooBig
      ? <p className="rn-error rn-dialog-message"> {React.string(t(ShareTooBig))} </p>
      : <>
          <p className="rn-dialog-message rn-muted"> {React.string(t(ShareLinkLabel))} </p>
          <div className="rn-share-row">
            // Read-only rather than disabled: the link has to be selectable, and a
            // disabled field is neither selectable nor reachable by keyboard.
            <input
              className="rn-share-link"
              type_="text"
              readOnly=true
              value={primary}
              ariaLabel={t(ShareApp)}
            />
            <Spectrum.Button variant="accent" onClick={_ => copy()}>
              {React.string(copied ? t(LinkCopied) : t(CopyAction))}
            </Spectrum.Button>
          </div>
          {shortLink == ""
            ? React.null
            : <>
                <p className="rn-share-note rn-muted"> {React.string(t(ShareShortInfo))} </p>
                // The serverless form, kept underneath: it is longer, needs nothing,
                // and keeps working when the server — or the network — is gone.
                <div className="rn-share-row">
                  <span className="rn-share-note rn-muted">
                    {React.string(t(ShareLongInfo))}
                  </span>
                  {link == ""
                    ? React.null
                    : <Spectrum.Button variant="secondary" onClick={_ => copyLong()}>
                        {React.string(t(CopyAction))}
                      </Spectrum.Button>}
                </div>
              </>}
          <div className="rn-share-row">
            {Share.available()
              ? <Spectrum.Button variant="secondary" onClick={_ => sheet()}>
                  {React.string(t(ShareNative))}
                </Spectrum.Button>
              : React.null}
            // A mail draft, for the desktops with no sheet of their own. `mailto` is
            // the one destination that needs no third party at all.
            <a
              className="rn-share-mail"
              href={Share.mailto(~subject=invitation, ~body=invitation ++ "\n\n" ++ link)}>
              {React.string(t(ShareByEmail))}
            </a>
          </div>
        </>}
    <div className="rn-dialog-actions">
      <Spectrum.Button variant="secondary" onClick={_ => onClose()}>
        {React.string(t(CancelAction))}
      </Spectrum.Button>
    </div>
  </dialog>
}
