/** Deposits an encrypted payload; answers with its id, or nothing when there is no
    server to answer. */
let create: string => promise<option<string>>

/** The payload under an id, or nothing — expired, purged, or no server. Reading it
    is what renews the 120 days. */
let fetchPayload: string => promise<option<string>>
