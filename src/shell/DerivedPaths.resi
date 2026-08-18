/** The collections of an app that are DERIVED — written by ::api-query, ::sql
    or ml-* on this device. The sync engine neither pushes them nor lets a
    remote snapshot delete them. */

let list: (~app: string) => promise<array<string>>

let mark: (~app: string, ~path: string) => promise<unit>

/** Follows a renamed app. */
let rename: (~from: string, ~to_: string) => promise<unit>
