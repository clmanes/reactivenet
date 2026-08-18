/** Reads one collection of one app. Missing or corrupt data reads as empty. */
let read: (~app: string, ~path: string) => promise<Collection.t>

let write: (~app: string, ~path: string, Collection.t) => promise<unit>

/** The collection paths this app has stored. */
let paths: (~app: string) => promise<array<string>>

let remove: (~app: string, ~path: string) => promise<unit>

/** Clears every collection of one app, leaving other apps and preferences alone. */
let clear: (~app: string) => promise<unit>

/** Every collection, for a backup. */
let exportAll: (~app: string) => promise<array<(string, Collection.t)>>

/** Writes a backup's collections in, replacing the paths it carries. */
let importAll: (~app: string, array<(string, Collection.t)>) => promise<unit>
