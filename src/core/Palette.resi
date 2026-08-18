type t =
  | Teal
  | Indigo
  | Violet
  | Amber
  | Rose
  | Slate

let fallback: t

/** Every palette, in picker order. Each needs a matching `.rn-palette-*` block in
    index.css. */
let all: array<t>

/** The surfaces the brand colour must survive: white, and the lightest dark grey. */
let lightSurface: string
let darkSurface: string
let surface: (~dark: bool) => string

/** The brand colour for a polarity; both clear 4.5:1 against their surface. */
/** The Spectrum hue ramp this palette aliases; index.css points the accent ramp at
    it, which is what makes every component follow the palette. */
let hue: t => string

/** The brand colour for a polarity — the app's own surfaces. Both clear 4.5:1
    against their surface. */
let brandColour: (t, ~dark: bool) => string

let toTag: t => string

/** Colour name; not translated. */
let label: t => string

let parse: string => option<t>
