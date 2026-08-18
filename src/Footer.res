// The bar along the bottom: what this is, and how you want it to look.
//
// The three interface controls — language, palette, polarity — used to sit in the
// navbar beside the app's own actions. They are chosen once and then left alone,
// which is exactly what the bottom of a window is for; the navbar is about the app
// currently open, and mixing the two made it a bar with two questions in it.

type pickerTarget = {value: string}
@get external pickerValue: JsxEvent.Form.t => pickerTarget = "target"

@react.component
let make = (
  ~theme: Theme.t,
  ~palette: Palette.t,
  ~locale: Locale.t,
  ~accountName: option<string>,
  ~onAccount,
  ~onToggleTheme,
  ~onSelectPalette,
  ~onSelectLocale,
) => {
  let t = key => Translations.translate(locale, key)

  <footer
    className="rn-footer rn-surface flex shrink-0 flex-wrap items-center justify-end gap-x-3 gap-y-0.5 border-t px-4 py-0.5 text-xs">
    // The name and the version are what the bar says about itself, so they sit
    // together at the left and let the controls own the right-hand end — the corner a
    // pointer reaches without crossing anything.
    <span className="mr-auto flex items-center gap-2">
      // Both are dropped on a handset, which is why they are one element rather than
      // two: the name is already the navbar's wordmark, two lines up, and the version
      // is a diagnostic — something to read out when reporting a problem, not while
      // using the app. The room they take is what makes the bar wrap into two rows.
      <span className="rn-footer-brand flex items-center gap-2">
        {React.string("ReactiveNET")}
        <span className="rn-muted font-mono"> {React.string("v" ++ BuildInfo.version)} </span>
      </span>
      // The legal notices stay at every width: they are an obligation, not a
      // decoration, and a link nobody can reach on a phone is one that is not offered.
      // They live on the website, which is bilingual: Italian at the root, everything
      // else reads the English translation.
      <a
        className="rn-muted underline"
        href={switch locale {
        | Locale.It => "https://reactivenet.ai/note-legali/"
        | _ => "https://reactivenet.ai/en/note-legali/"
        }}
        target="_blank"
        rel="noopener noreferrer">
        {React.string(t(LegalNotices))}
      </a>
    </span>
    <div className="flex items-center gap-2">
      // The interface: three choices about how it looks, in the same order everywhere
      // — what it says, what colour it says it in, and how bright.
      <Spectrum.Picker
        value={Locale.toTag(locale)}
        label={t(Language)}
        size="s"
        onChange={event =>
          // The `next != locale` guard is load-bearing, not defensive tidiness.
          // React writes `value` back to the element on every render, and sp-picker
          // dispatches `change` from its value setter — so without it, selecting a
          // language starts a set-value → change → setState → set-value loop that
          // pegs the main thread.
          switch Locale.parse(pickerValue(event).value) {
          | Some(next) if next != locale => onSelectLocale(next)
          | _ => ()
          }}>
        {Locale.all
        ->Array.map(option =>
          <Spectrum.MenuItem
            key={Locale.toTag(option)}
            value={Locale.toTag(option)}
            selected={option == locale}>
            {React.string(Locale.nativeName(option))}
          </Spectrum.MenuItem>
        )
        ->React.array}
      </Spectrum.Picker>
      <Spectrum.Picker
        value={Palette.toTag(palette)}
        label={t(PaletteLabel)}
        size="s"
        onChange={event =>
          switch Palette.parse(pickerValue(event).value) {
          | Some(next) if next != palette => onSelectPalette(next)
          | _ => ()
          }}>
        {Palette.all
        ->Array.map(option =>
          <Spectrum.MenuItem
            key={Palette.toTag(option)} value={Palette.toTag(option)} selected={option == palette}>
            {React.string(Palette.label(option))}
          </Spectrum.MenuItem>
        )
        ->React.array}
      </Spectrum.Picker>
      // A switch, because dark is on or off — a two-state setting, which is what a
      // switch means and what a button pretending to be one never quite says. The
      // accessible name is the state it turns on, since that is what flipping it
      // does; `aria-label` because the visible label would be a fourth word in a bar
      // that is deliberately short.
      <Spectrum.Switch
        checked={Theme.isDark(theme)}
        size="s"
        ariaLabel={t(DarkMode)}
        onChange={_ => onToggleTheme()}
      />
      // The account sits with the other once-in-a-while choices. The accessible
      // name says who is signed in when somebody is — the state a returning user
      // actually checks — and "Account" when nobody is.
      <Spectrum.ActionButton
        label={switch accountName {
        | Some(name) => t(SignedInAs) ++ " " ++ name
        | None => t(AccountLabel)
        }}
        quiet=true
        onClick={_ => onAccount()}>
        Icons.person
      </Spectrum.ActionButton>
    </div>
  </footer>
}
