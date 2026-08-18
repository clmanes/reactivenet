/** The name an exported app is saved under. */
let name: string => string

/** What the file picker offers, as an `accept` attribute. */
let accept: string

/** Whether a filename is one this app can read. */
let isDocument: string => bool

/** The id an imported document takes: its own when free, a fresh one when that id is
    already in use — an import never overwrites an app that is already there. */
let idFor: (~source: string, ~taken: array<string>, ~fallback: string) => string

/** Whether the import had to land under a different id from the one the file
    declared. */
let isCopy: (~source: string, ~id: string) => bool
