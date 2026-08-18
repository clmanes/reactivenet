// What this browser remembers about an app's shared space, in IndexedDB like
// everything else. Three keys per app, updated at three different rates:
//
//   space:<app>      the link — space id, own role, the space keys by epoch, and
//                    the pull cursor. Written at join and after each pull.
//   spacedoc:<app>   the Automerge document, saved binary as base64. Written after
//                    every local or remote change — it is the durable copy that
//                    makes offline edits mergeable later instead of lost.
//   spacequeue:<app> changes made offline, encrypted and waiting to be pushed.
//
// The space keys live here in the clear for the same reason the session's private
// key does: this device is one of the user's devices. Leaving a space deletes all
// three keys — after that the server's copy is a blob this browser can no longer
// even name.

type link = {
  spaceId: string,
  role: string,
  /** JSON object, epoch → space key (base64url). */
  keys: string,
  /** The `created` of the last change applied from the server. */
  cursor: string,
  /** The appId the *space* declares. Locally the app may live under another id —
      every browser already has a `welcome`, so collisions are the common case,
      not the edge — and the engine translates between the two at its boundary:
      what syncs carries the canonical id, what lands locally carries the local
      one, and a local rename stays local. */
  canonical: string,
}

let linkKey = app => "space:" ++ app
let docKey = app => "spacedoc:" ++ app
let queueKey = app => "spacequeue:" ++ app

let encodeLink: link => string = %raw(`
function (link) {
  return JSON.stringify({
    v: 1,
    spaceId: link.spaceId,
    role: link.role,
    keys: link.keys,
    cursor: link.cursor,
    canonical: link.canonical,
  });
}
`)

let decodeLink: string => option<link> = %raw(`
function (text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return undefined;
  }
  if (!parsed || typeof parsed !== "object" || parsed.v !== 1) return undefined;
  if (typeof parsed.spaceId !== "string" || parsed.spaceId === "") return undefined;
  return {
    spaceId: parsed.spaceId,
    role: typeof parsed.role === "string" ? parsed.role : "reader",
    keys: typeof parsed.keys === "string" ? parsed.keys : "{}",
    cursor: typeof parsed.cursor === "string" ? parsed.cursor : "",
    canonical: typeof parsed.canonical === "string" ? parsed.canonical : "",
  };
}
`)

/** The key for one epoch out of the link's keys, or nothing — which for a member
    removed before that epoch is not an error but the design working. */
let keyForEpoch: (link, int) => option<string> = %raw(`
function (link, epoch) {
  try {
    const keys = JSON.parse(link.keys);
    const found = keys[String(epoch)];
    return typeof found === "string" && found !== "" ? found : undefined;
  } catch {
    return undefined;
  }
}
`)

let withEpochKey: (link, int, string) => link = %raw(`
function (link, epoch, key) {
  let keys;
  try {
    keys = JSON.parse(link.keys);
  } catch {
    keys = {};
  }
  keys[String(epoch)] = key;
  return {
    spaceId: link.spaceId,
    role: link.role,
    keys: JSON.stringify(keys),
    cursor: link.cursor,
    canonical: link.canonical,
  };
}
`)

let saveLink = (~app, link) => Idb.set(linkKey(app), encodeLink(link))

let loadLink = async (~app) =>
  switch await Idb.get(linkKey(app)) {
  | Value(stored) => decodeLink(stored)
  | Null | Undefined => None
  }

let saveDoc = (~app, encoded) => Idb.set(docKey(app), encoded)

let loadDoc = async (~app) =>
  switch await Idb.get(docKey(app)) {
  | Value(stored) if stored != "" => Some(stored)
  | _ => None
  }

let encodeQueue: array<(int, string)> => string = %raw(`
function (entries) {
  return JSON.stringify(entries.map(([epoch, payload]) => ({ epoch, payload })));
}
`)

let decodeQueue: string => array<(int, string)> = %raw(`
function (text) {
  try {
    const parsed = JSON.parse(text);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((entry) => entry && typeof entry.payload === "string")
      .map((entry) => [Number(entry.epoch || 1), entry.payload]);
  } catch {
    return [];
  }
}
`)

let loadQueue = async (~app) =>
  switch await Idb.get(queueKey(app)) {
  | Value(stored) => decodeQueue(stored)
  | Null | Undefined => []
  }

let saveQueue = (~app, entries) => Idb.set(queueKey(app), encodeQueue(entries))

/** Leaving: the link, the document and the queue go together — a space this
    browser is no longer in must leave nothing behind that could still open it. */
let clear = async (~app) => {
  await Idb.remove(linkKey(app))
  await Idb.remove(docKey(app))
  await Idb.remove(queueKey(app))
}

/** A rename moves the link with the app, the same way DocumentStore.rename moves
    the collections — a link left under the old id would be an orphaned key. */
let rename = async (~from, ~to_) => {
  let carry = async make => {
    switch await Idb.get(make(from)) {
    | Value(stored) => {
        await Idb.set(make(to_), stored)
        await Idb.remove(make(from))
      }
    | Null | Undefined => ()
    }
  }
  await carry(linkKey)
  await carry(docKey)
  await carry(queueKey)
}
