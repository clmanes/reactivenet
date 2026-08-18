// Pure. Polarity only: light or dark. The colour *palette* is a separate axis, in
// [Palette] — Spectrum's `color` attribute selects a shade of grey scale, not a hue,
// so the two cannot be folded into one type.

type t =
  | Light
  | Dark

let toggle = theme =>
  switch theme {
  | Light => Dark
  | Dark => Light
  }

/* The `color` attribute of `sp-theme`. */
let toSpectrumColor = theme =>
  switch theme {
  | Light => "light"
  | Dark => "dark"
  }

let isDark = theme => theme == Dark

let toTag = toSpectrumColor

let parse = value =>
  switch value {
  | "light" => Some(Light)
  | "dark" => Some(Dark)
  | _ => None
  }

// The shell passes the result of `prefers-color-scheme: dark`; keeping the mapping
// here means the decision is testable without a matchMedia stub.
let fromPrefersDark = prefersDark => prefersDark ? Dark : Light
