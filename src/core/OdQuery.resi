/** The `{#key}` placeholders an od-query's SQL carries. They become PREPARED
    parameters, never text pasted into the statement — the values come from
    reactive keys, which is to say from readers. */

/** Every reactive key the SQL mentions, once each, in order of first mention. */
let references: string => array<string>

/** The prepared statement and its parameters: each placeholder — bare or
    written '{#key}' between quotes, which are consumed with it — becomes `?`,
    and its key is read through the lookup, in order, duplicates included. A
    key holding nothing binds the empty string. */
let bind: (string, string => option<string>) => (string, array<string>)
