// Pure. What a reactive source should hold after a render.
//
// The store keeps two values per key: the one the document *declares* and the one a
// reader produced by working the control. Conflating them breaks one case or the
// other — taking the stored value always meant editing a `value` attribute in the
// block editor did nothing, and taking the authored value always meant a dragged
// slider snapped back on every unrelated keystroke, because the preview re-renders
// and re-binds on each one.
//
// Three cases, and the rule is only readable when they are written down together.

type decision =
  /** Take what the document says, and remember it as what it said. */
  | Adopt(string)
  /** Leave the live value alone: the document has not changed its mind. */
  | Keep(string)

let decide = (~known, ~authored, ~seen) =>
  switch known {
  // Nothing stored yet: the document is the only opinion there is.
  | None => Adopt(authored)
  // The document changed it since the last bind: the author overrode the live value
  // on purpose, which is the whole point of editing the attribute.
  | Some(_) if seen != Some(authored) => Adopt(authored)
  // The document is unchanged, so re-rendering the preview must not move the control.
  | Some(live) => Keep(live)
  }

/** How a tick box is stored, and read back. Its `value` is the form value it would
    submit — the empty string for a control written `::checkbox[done]` — so the state
    has to come from `checked`, and `"true"`/`"false"` is what the same tick is stored
    as in a collection. */
let ticked = value => value == "true"

let ofTick = checked => checked ? "true" : "false"
