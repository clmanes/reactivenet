// Pure. The set of supported languages and how a browser tag maps onto it.

type t =
  | En
  | Fr
  | De
  | Es
  | Pt
  | Zh
  | It

let fallback = En

// Order shown in the picker: English first, then the rest alphabetically by their
// own name, which is how a reader scans a language list.
let all = [En, Fr, De, Es, It, Pt, Zh]

let toTag = locale =>
  switch locale {
  | En => "en"
  | Fr => "fr"
  | De => "de"
  | Es => "es"
  | Pt => "pt"
  | Zh => "zh"
  | It => "it"
  }

// Endonyms, not English names: someone looking for their language recognises
// "Deutsch" faster than "German", and does not need to read English to find it.
let nativeName = locale =>
  switch locale {
  | En => "English"
  | Fr => "Français"
  | De => "Deutsch"
  | Es => "Español"
  | Pt => "Português"
  | Zh => "中文"
  | It => "Italiano"
  }

// A BCP-47 tag carries region and script subtags: "en-GB", "zh-Hans-CN", "pt-BR".
// Only the primary subtag decides the language, so everything after the first "-"
// is dropped rather than failing to match.
let parse = tag =>
  switch tag->String.trim->String.toLowerCase->String.split("-")->Array.at(0) {
  | Some("en") => Some(En)
  | Some("fr") => Some(Fr)
  | Some("de") => Some(De)
  | Some("es") => Some(Es)
  | Some("pt") => Some(Pt)
  | Some("zh") => Some(Zh)
  | Some("it") => Some(It)
  | _ => None
  }

// `navigator.languages` is ordered by preference, so the first supported entry wins
// — not the first entry, which may well be a language we do not carry.
let fromPreferred = tags =>
  tags
  ->Array.reduce(None, (found, tag) =>
    switch found {
    | Some(_) => found
    | None => parse(tag)
    }
  )
  ->Option.getOr(fallback)
