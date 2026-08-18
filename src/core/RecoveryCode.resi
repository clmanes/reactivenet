/** The shape of a recovery code: 160 random bits in Crockford base32, eight groups
    of four. The bytes come from the shell; the human form is decided — and tested —
    here. */

/** How many random bytes a code carries. */
let byteLength: int

/** The printable form, or nothing when the input is not exactly that many bytes. */
let format: array<int> => option<string>

/** The bytes a typed code names — case, separators and lookalike characters
    forgiven — or nothing when it is not a code. */
let parse: string => option<array<int>>
