// Pure. What an app is called, everywhere it is called that.
//
// The same string is three things at once: the `appId` in the frontmatter, the
// namespace its collections live under (`CollectionKey`), and the part of the URL
// that addresses it. Because the last of those means the id arrives from outside —
// anyone can type a hash — it is validated rather than trusted: only lowercase
// letters, digits and single hyphens. That closes the path from a crafted URL to an
// IndexedDB key, and keeps ids readable in a link, which is the point of having them.

let maxLength = 64

let isAllowed = character =>
  (character >= "a" && character <= "z") ||
  (character >= "0" && character <= "9") ||
  character == "-"

let isValid = candidate =>
  candidate != "" &&
  String.length(candidate) <= maxLength &&
  !(candidate->String.startsWith("-")) &&
  !(candidate->String.endsWith("-")) &&
  !(candidate->String.includes("--")) &&
  candidate->String.split("")->Array.every(isAllowed)

// Accents are stripped rather than transliterated: "Registro Città" becomes
// "registro-citt", not "registro-citta". Guessing at transliteration across seven
// languages would be worse than a short id, and the title is what the reader sees.
let slug = raw => {
  let lowered = raw->String.toLowerCase
  let replaced =
    lowered
    ->String.split("")
    ->Array.map(character => isAllowed(character) ? character : "-")
    ->Array.join("")

  replaced
  ->String.split("-")
  ->Array.filter(part => part != "")
  ->Array.join("-")
  ->String.slice(~start=0, ~end=maxLength)
  ->String.split("-")
  ->Array.filter(part => part != "")
  ->Array.join("-")
}

let fallback = "app"

/** A slug for a title, never empty: a title of punctuation alone still needs an id. */
let of_ = raw =>
  switch slug(raw) {
  | "" => fallback
  | value => value
  }

// Uniqueness is decided against a set the caller passes in, so choosing an id stays
// a pure function of what already exists rather than a query against storage.
let unique = (~desired, ~taken) => {
  let base = of_(desired)
  let rec attempt = suffix => {
    let candidate = suffix == 1 ? base : base ++ "-" ++ suffix->Int.toString
    taken->Array.includes(candidate) ? attempt(suffix + 1) : candidate
  }
  attempt(1)
}
