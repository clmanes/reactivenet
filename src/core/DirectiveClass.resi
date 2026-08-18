type t =
  | Structure
  | Data
  | Ai
  | Views
  | Values
  | Status
  | Controls
  | Navigation
  | Layout
  | Overlays
  | Colour
  | TableParts

/** Every class with the directives filed under it, in the order a menu should list
    them: ours first, because they are what makes a document an app. */
let members: array<(t, array<string>)>

/** Every class, in that order. */
let all: array<t>

/** Where a directive's class sits in `all`, or -1 when nobody has filed it. Items
    have to be sorted by this before a grouped menu draws them. */
let order: string => int

/** The class a directive belongs to, or nothing when nobody has filed it. */
let of_: string => option<t>

/** The heading to show for a class, as a translation key. */
let label: t => Translations.key

/** How the directive is written: `::name`, or `:name` for the inline ones. It is the
    only name it should be shown under. */
let written: string => string

/** A glyph for the class: the `d` of one SVG path on a 24×24 grid. */
let glyph: t => string
