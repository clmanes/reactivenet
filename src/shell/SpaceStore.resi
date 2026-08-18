/** What this browser remembers about an app's shared space: the link (space id,
    role, keys by epoch, pull cursor), the persisted Automerge document, and the
    offline queue. All in IndexedDB; leaving clears all three together. */

type link = {
  spaceId: string,
  role: string,
  keys: string,
  cursor: string,
  /** The appId the space declares; locally the app may live under another id. */
  canonical: string,
}

let keyForEpoch: (link, int) => option<string>

let withEpochKey: (link, int, string) => link

let saveLink: (~app: string, link) => promise<unit>

let loadLink: (~app: string) => promise<option<link>>

let saveDoc: (~app: string, string) => promise<unit>

let loadDoc: (~app: string) => promise<option<string>>

let loadQueue: (~app: string) => promise<array<(int, string)>>

let saveQueue: (~app: string, array<(int, string)>) => promise<unit>

let clear: (~app: string) => promise<unit>

/** Moves the link, document and queue with a renamed app. */
let rename: (~from: string, ~to_: string) => promise<unit>
