/***
Key/value access to the project's IndexedDB store.

This is the only persistence API in the app: `localStorage` and `sessionStorage` are
not used anywhere. Both operations swallow storage failures — a blocked database
resolves to "no value" rather than rejecting.
*/

let databaseName: string
let storeName: string

let get: string => promise<Nullable.t<string>>

let set: (string, string) => promise<unit>

/** Every key in the store. Resolves to an empty array when storage is unavailable. */
let keys: unit => promise<array<string>>

let remove: string => promise<unit>
