let prefix: string

/** The storage key for one app's document. */
let of_: string => string

/** The app id a key addresses, for keys of this kind carrying a valid id. */
let idOf: string => option<string>

let isDocument: string => bool
