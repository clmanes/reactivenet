/** The longest id accepted; longer titles are cut rather than rejected. */
let maxLength: int

/** Lowercase letters, digits and single interior hyphens. Anything else is refused:
    an id reaches this app from the URL, and it becomes a storage key. */
let isValid: string => bool

/** A valid id derived from arbitrary text, never empty. */
let of_: string => string

/** `of_`, then a numeric suffix until the id is not in `taken`. */
let unique: (~desired: string, ~taken: array<string>) => string

/** The id used when a title yields nothing usable. */
let fallback: string
