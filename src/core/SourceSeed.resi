type decision =
  | Adopt(string)
  | Keep(string)

/** What a source control should hold after a bind, given what the store has (`known`),
    what the document declares now (`authored`) and what it declared at the last bind
    (`seen`). */
let decide: (~known: option<string>, ~authored: string, ~seen: option<string>) => decision

/** Whether a stored value means a ticked box. */
let ticked: string => bool

/** How a ticked box is stored. */
let ofTick: bool => string
