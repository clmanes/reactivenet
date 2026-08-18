/** The orchestrator of a shared space: Automerge, the crypto, the server and the
    local stores, behind one serial chain per app. This module is the heavy chunk
    — reach it only through SpaceSync's dynamic imports. */

let start: (~app: string, ~session: Session.t, ~onDocument: string => unit) => promise<unit>

let stop: (~app: string) => unit

/** Local data or the document changed; fold it in and push, debounced. */
let localChanged: (~app: string) => unit

let isActive: (~app: string) => bool

let roleOf: (~app: string) => promise<option<string>>

/** Turns an app's data into a shared space owned by this account. */
let create: (~app: string, ~session: Session.t) => promise<bool>

/** An invitation link, or None. The invite key leaves only inside the link. */
let invite: (~app: string, ~session: Session.t, ~role: string) => promise<option<string>>

/** Accepts an invitation; answers the local app id to open. */
let join: (
  ~inviteId: string,
  ~key: string,
  ~session: Session.t,
  ~taken: array<string>,
  ~fallback: string,
) => promise<option<string>>

let members: (~app: string, ~session: Session.t) => promise<array<SpaceServer.member>>

/** Removes a member and turns the key: new epoch, rewrapped for who remains,
    fresh snapshot sealed under the new key. */
let removeMember: (~app: string, ~session: Session.t, ~memberId: string) => promise<bool>
