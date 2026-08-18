/** The path a shared link points at. The document itself rides in the fragment. */
let path: string

/** The segment of that path, for the router. */
let segment: string

/** How long a payload may be before a link stops being a sensible way to send it. */
let ceiling: int

/** The whole link: where this app is served from, the path, and the encoded
    document in the fragment. */
let of_: (~origin: string, ~payload: string) => string

/** The payload a fragment carries, or nothing when it is not one of ours. */
let payloadOf: string => option<string>

/** Whether a payload is small enough to send as a link. */
let fits: string => bool

/** The line that goes with the link in a mail or a share sheet. */
let message: (~title: string, ~invitation: string) => string

/** What a server-stored payload may grow to; the server enforces the same ceiling. */
let storedCeiling: int

let fitsStored: string => bool

/** Whether a path segment is plausibly a stored share's id. */
let isShortId: string => bool

/** The short link: the encrypted document on the server under `id`, the key in the
    fragment the server never sees. */
let shortOf: (~origin: string, ~id: string, ~key: string) => string

/** The key a short link's fragment carries, or nothing. */
let keyOf: string => option<string>
