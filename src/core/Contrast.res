// Pure. WCAG 2.1/2.2 relative luminance and contrast ratio.
//
// Here so that the palettes can be *checked* rather than eyeballed: every colour the
// app ships is asserted against these thresholds in the tests, which turns a
// contrast regression into a failing build instead of something an audit finds later.

type rgb = {
  red: int,
  green: int,
  blue: int,
}

// AA thresholds, from WCAG 2.2 §1.4.3 and §1.4.11.
let normalText = 4.5
let largeText = 3.0
let nonText = 3.0

let hexDigits = "0123456789abcdef"

let digitValue = character =>
  switch hexDigits->String.indexOf(character->String.toLowerCase) {
  | -1 => None
  | value => Some(value)
  }

let channel = (value, offset) =>
  switch (
    digitValue(value->String.charAt(offset)),
    digitValue(value->String.charAt(offset + 1)),
  ) {
  | (Some(high), Some(low)) => Some(high * 16 + low)
  | _ => None
  }

/** Accepts `#rrggbb` or `rrggbb`. Shorthand `#rgb` is deliberately not accepted:
    the project writes full hex, and silently guessing would hide a typo. */
let parseHex = raw => {
  let value = raw->String.trim->String.startsWith("#")
    ? raw->String.trim->String.slice(~start=1, ~end=String.length(raw->String.trim))
    : raw->String.trim

  if String.length(value) != 6 {
    None
  } else {
    switch (channel(value, 0), channel(value, 2), channel(value, 4)) {
    | (Some(red), Some(green), Some(blue)) => Some({red, green, blue})
    | _ => None
    }
  }
}

// The sRGB transfer function: the 0.03928 knee and the 2.4 exponent are the
// specification's, not an approximation of it.
let linearise = value => {
  let channel = Int.toFloat(value) /. 255.0
  channel <= 0.03928 ? channel /. 12.92 : Math.pow((channel +. 0.055) /. 1.055, ~exp=2.4)
}

let relativeLuminance = colour =>
  0.2126 *. linearise(colour.red) +.
  0.7152 *. linearise(colour.green) +.
  0.0722 *. linearise(colour.blue)

let ratio = (a, b) => {
  let first = relativeLuminance(a)
  let second = relativeLuminance(b)
  let lighter = Math.max(first, second)
  let darker = Math.min(first, second)
  (lighter +. 0.05) /. (darker +. 0.05)
}

/** Contrast between two hex colours, or None if either is unparseable. */
let between = (foreground, background) =>
  switch (parseHex(foreground), parseHex(background)) {
  | (Some(a), Some(b)) => Some(ratio(a, b))
  | _ => None
  }

let meets = (~foreground, ~background, ~threshold) =>
  switch between(foreground, background) {
  | Some(measured) => measured >= threshold
  | None => false
  }
