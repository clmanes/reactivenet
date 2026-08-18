// Pure. No DOM, no side effects — deliberately does NOT use the `URL` global, so the
// result depends only on the input string and can be reasoned about (and tested)
// without a browser.

type t = Safe(string)

type error =
  | Empty
  | ProtocolRelative
  | DisallowedScheme(string)

// Allowlist, never a blocklist: anything not named here is rejected, so a scheme
// nobody thought about (`vbscript:`, `blob:`, `filesystem:`) fails closed.
let allowedSchemes = ["http", "https", "mailto"]

// Browsers strip ASCII control characters while parsing a scheme, so `java\tscript:`
// and `java\nscript:` navigate exactly like `javascript:`. Remove them before
// looking at anything, otherwise the allowlist check reads a scheme the browser won't.
let controlCharacters = RegExp.fromString("[\\u0000-\\u001f\\u007f]", ~flags="g")

let normalise = raw => raw->String.replaceRegExp(controlCharacters, "")->String.trim

// The scheme is whatever precedes the first ":", but only if that colon comes before
// any "/", "?" or "#" — otherwise the colon belongs to a path or query, not a scheme.
let rec schemeAt = (input, index) =>
  if index >= String.length(input) {
    None
  } else {
    switch String.charAt(input, index) {
    | ":" => Some(input->String.slice(~start=0, ~end=index)->String.toLowerCase)
    | "/" | "?" | "#" => None
    | _ => schemeAt(input, index + 1)
    }
  }

let parse = raw => {
  let input = normalise(raw)

  if input == "" {
    Error(Empty)
  } else if input->String.startsWith("//") {
    // "//evil.example" inherits the current scheme and silently leaves our origin
    Error(ProtocolRelative)
  } else {
    switch schemeAt(input, 0) {
    // No scheme at all: a same-document path, query or fragment. Safe by construction.
    | None => Ok(Safe(input))
    | Some(scheme) =>
      if allowedSchemes->Array.includes(scheme) {
        Ok(Safe(input))
      } else {
        Error(DisallowedScheme(scheme))
      }
    }
  }
}

// Returns the *normalised* string, not the caller's original: handing back the raw
// input would give away a value that passed validation but still carries the
// control characters the check removed.
let toString = (Safe(value)) => value

let errorToString = error =>
  switch error {
  | Empty => "The link is empty."
  | ProtocolRelative => "Protocol-relative links are not allowed."
  | DisallowedScheme(scheme) => `The "${scheme}:" scheme is not allowed.`
  }
