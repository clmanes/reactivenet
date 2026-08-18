type t =
  | En
  | Fr
  | De
  | Es
  | Pt
  | Zh
  | It

let fallback: t

/** Every supported locale, in the order the picker should list them. */
let all: array<t>

let toTag: t => string

/** The language's own name, e.g. "Deutsch" rather than "German". */
let nativeName: t => string

/** Accepts full BCP-47 tags: only the primary subtag is significant. */
let parse: string => option<t>

/** Picks the first supported entry from a preference-ordered list, else [fallback]. */
let fromPreferred: array<string> => t
