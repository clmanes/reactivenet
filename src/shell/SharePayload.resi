/** A document, compressed and base64url-encoded, small enough to ride in a link. */
let encode: string => promise<string>

/** The document a payload carries, or nothing when the link was truncated or is not
    in a format this version reads. */
let decode: string => promise<option<string>>
