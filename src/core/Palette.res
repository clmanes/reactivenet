// Pure. The colour axis, independent of light/dark.
//
// Spectrum's `sp-theme` `color` attribute picks a shade of the neutral scale, not a
// hue — so a palette cannot be expressed through it. A palette is instead a pair of
// hex values applied as `--color-brand`, selected by an `rn-palette-*` class.
//
// *Two* values, not one, because no single colour can satisfy WCAG AA on both
// polarities: 4.5:1 against white caps relative luminance at 0.178, while 3:1
// against the lightest dark surface demands at least 0.182. The shades below were
// computed against those surfaces and are asserted in Palette_test.
//
// Spectrum's components follow the palette too, and the mechanism is aliasing rather
// than invention: each palette names one of Spectrum's *own* hue ramps, and index.css
// points the whole accent ramp at it. Adobe calibrated those ramps against both
// polarities — including the label colour paired with a filled accent — so nothing
// here has to re-derive a contrast pairing that already exists. The shades below are
// stops from the same ramp, which is what makes the wordmark and a filled button read
// as one colour rather than two that nearly match.

type t =
  | Teal
  | Indigo
  | Violet
  | Amber
  | Rose
  | Slate

let fallback = Teal

let all = [Teal, Indigo, Violet, Amber, Rose, Slate]

let toTag = palette =>
  switch palette {
  | Teal => "teal"
  | Indigo => "indigo"
  | Violet => "violet"
  | Amber => "amber"
  | Rose => "rose"
  | Slate => "slate"
  }

// Colour names, not translated: they name a specific hue in this product's
// vocabulary, the way a paint chart does.
let label = palette =>
  switch palette {
  | Teal => "Teal"
  | Indigo => "Indigo"
  | Violet => "Violet"
  | Amber => "Amber"
  | Rose => "Rose"
  | Slate => "Slate"
  }

// The worst-case surfaces, measured from Spectrum rather than assumed. Brand text
// appears on gray-50, gray-100 and gray-200; contrast is lowest against whichever of
// those is nearest the text's own luminance — so gray-200 in both polarities, not
// pure white, which would have overstated every ratio by about a point.
let lightSurface = "#e1e1e1"
let darkSurface = "#323232"

/** The Spectrum hue ramp this palette is. index.css points the accent ramp at it. */
let hue = palette =>
  switch palette {
  | Teal => "seafoam"
  | Indigo => "indigo"
  | Violet => "purple"
  | Amber => "orange"
  | Rose => "magenta"
  // The neutral one. Its ramp stops at 900 and that stop is pure black, so it is the
  // one palette index.css shifts rather than aliases straight through.
  | Slate => "gray"
  }

/** The brand colour for a polarity: stop 1000 of the palette's ramp in light, 900 in
    dark. Both clear 4.5:1 against their surface, which the test asserts — Adobe's
    calibration is a good reason to expect it, not a reason to stop checking. */
let brandColour = (palette, ~dark) =>
  switch (palette, dark) {
  | (Teal, false) => "#00635f"
  | (Teal, true) => "#36c5bd"
  | (Indigo, false) => "#4046ca"
  | (Indigo, true) => "#a7aaff"
  | (Violet, false) => "#7326d3"
  | (Violet, true) => "#ca9ffc"
  | (Amber, false) => "#953d00"
  | (Amber, true) => "#fe9a2e"
  | (Rose, false) => "#ad0955"
  | (Rose, true) => "#ff8fb9"
  // Slate's ramp is shifted, so its brand is gray-700 in both polarities.
  | (Slate, false) => "#464646"
  | (Slate, true) => "#d1d1d1"
  }

let surface = (~dark) => dark ? darkSurface : lightSurface

let parse = value =>
  switch value {
  | "teal" => Some(Teal)
  | "indigo" => Some(Indigo)
  | "violet" => Some(Violet)
  | "amber" => Some(Amber)
  | "rose" => Some(Rose)
  | "slate" => Some(Slate)
  | _ => None
  }
