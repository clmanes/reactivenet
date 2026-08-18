type rgb = {
  red: int,
  green: int,
  blue: int,
}

/** WCAG 2.2 AA thresholds. */
let normalText: float
let largeText: float
let nonText: float

/** Accepts `#rrggbb` or `rrggbb`; shorthand is rejected rather than guessed. */
let parseHex: string => option<rgb>

let relativeLuminance: rgb => float
let ratio: (rgb, rgb) => float

/** Contrast between two hex colours, None if either is unparseable. */
let between: (string, string) => option<float>

let meets: (~foreground: string, ~background: string, ~threshold: float) => bool
