/** A short, stable fingerprint of a text. Not a security primitive: it answers "is
    this still the text I wrote?", nothing more. */
let of_: string => string

/** Whether the text is the one recorded. An empty record never matches. */
let matches: (string, ~recorded: string) => bool
