// The bar is read left to right as three answers to three different questions, and
// they are kept apart because mixing them is what made it hard to scan:
//
//   left    — where am I, and how do I get back
//   right   — what can I do with *this app*: share it, save it, open it for editing
//
// How the *interface* looks — language, palette, polarity — used to sit here too and
// is now in the footer. It is chosen once and then left alone, while everything in
// this bar is about the app currently open; a control you touch twice a year does not
// belong beside the ones you use every minute, and moving it left the bar with one
// question in it instead of two.
//
// An icon that changes names the *destination*, never the current state: the eye
// means "view this", the moon means "go dark". Naming the state instead makes every
// toggle in a bar ambiguous, because there is no way to tell which convention any
// one of them is following.

@react.component
let make = (
  ~locale: Locale.t,
  ~route: Route.t,
  ~canEdit: bool,
  ~copied: bool,
  ~onToggleEditing,
  ~onHome,
  ~onCopyLink,
  ~onShare,
  ~onSync,
  ~onExport,
  ~onImport,
  ~assistantOpen: bool,
  ~onAssistant,
) => {
  let t = key => Translations.translate(locale, key)
  let onApp = route != Route.Gallery

  // The bar is sticky below the breakpoint, and what sits under it — the pane's
  // toolbar, then the page menu — needs its height. It is not a constant: at 320 px
  // the controls wrap under the wordmark and the bar is nearly twice as tall.
  let barRef = React.useRef(Nullable.null)
  React.useEffect0(() =>
    switch barRef.current->Nullable.toOption {
    | None => None
    | Some(node) => Some(BarMetrics.track(node, "--rn-navbar-height"))
    }
  )

  <nav
    ref={ReactDOM.Ref.domRef(barRef)}
    className="rn-navbar rn-surface flex shrink-0 flex-wrap items-center justify-between gap-x-4 gap-y-1 border-b px-4 py-1.5">
    <div className="flex items-center gap-3">
      // Inline, not an <img>: nothing outside an image can reach its colours, and
      // the mark was the one thing on screen that did not follow the palette.
      <Brand />
      <span className="text-base font-semibold tracking-tight">
        {React.string("Reactive")}
        <span className="text-brand"> {React.string("NET")} </span>
      </span>
      // Shown only away from the gallery: a button that goes where you already are
      // is a control the reader has to think about for nothing.
      {onApp
        ? <Spectrum.ActionButton label={t(BackToGallery)} onClick={_ => onHome()}>
            Icons.gallery
          </Spectrum.ActionButton>
        : React.null}
    </div>
    <div className="flex items-center gap-1">
      // The app: the three things you can do with the one that is open. On the
      // gallery there is no open app, so the group is the one thing that adds to
      // the gallery from outside.
      {onApp
        ? <>
            <Spectrum.ActionButton
              label={copied ? t(LinkCopied) : t(CopyLink)}
              selected={copied}
              onClick={_ => onCopyLink()}>
              Icons.link
            </Spectrum.ActionButton>
            // Copying the address is for me — a bookmark, another tab. Sharing is for
            // somebody else, and needs the app to travel with the link, so it is a
            // second action rather than a second meaning for the first.
            <Spectrum.ActionButton label={t(ShareApp)} onClick={_ => onShare()}>
              Icons.share
            </Spectrum.ActionButton>
            // Sharing hands somebody a copy; syncing keeps everyone's copy the
            // same. Two verbs, two buttons — folding them together would make
            // the common act (send someone the app) carry the rare one's weight.
            <Spectrum.ActionButton label={t(SyncPanel)} onClick={_ => onSync()}>
              Icons.sync
            </Spectrum.ActionButton>
            <Spectrum.ActionButton label={t(ExportApp)} onClick={_ => onExport()}>
              Icons.download
            </Spectrum.ActionButton>
            // One control, and it changes the URL: an app is either being read or
            // being edited, and which one it is has to be visible in the address bar.
            {canEdit
              ? <Spectrum.ActionButton
                  label={Route.isEditing(route) ? t(ViewApp) : t(EditApp)}
                  onClick={_ => onToggleEditing()}>
                  {Route.isEditing(route) ? Icons.eye : Icons.pencil}
                </Spectrum.ActionButton>
              : React.null}
          </>
        : <Spectrum.ActionButton label={t(ImportApp)} onClick={_ => onImport()}>
            Icons.upload
          </Spectrum.ActionButton>}
      // The assistant is the one control in this bar that is about neither the open
      // app nor the gallery but about making one, so it is on both and it is last:
      // in the gallery it writes a new app, beside an open one it changes that app.
      <Spectrum.ActionButton
        label={t(AiPanel)} selected={assistantOpen} onClick={_ => onAssistant()}>
        Icons.sparkle
      </Spectrum.ActionButton>
    </div>
  </nav>
}
