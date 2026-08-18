/** The storage key for one collection of one app. */
let of_: (~app: string, ~path: string) => string

let appPrefix: string => string

/** The collection path, but only for keys belonging to that exact app. */
let pathOf: (~app: string, string) => option<string>

let isCollection: string => bool
