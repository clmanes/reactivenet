/** The light doorway to the sync engine: every reference to SyncEngine (and so to
    Automerge's wasm) is a dynamic import, fetched the first time an account
    actually syncs. Linkage questions are answered from SpaceStore, cheaply. */

let start: (~app: string, ~session: Session.t, ~onDocument: string => unit) => promise<unit>

let stop: (~app: string) => unit

let localChanged: (~app: string) => unit

let isLinked: (~app: string) => promise<bool>

let roleOf: (~app: string) => promise<option<string>>

let create: (~app: string, ~session: Session.t) => promise<bool>

let invite: (~app: string, ~session: Session.t, ~role: string) => promise<option<string>>

let join: (
  ~inviteId: string,
  ~key: string,
  ~session: Session.t,
  ~taken: array<string>,
  ~fallback: string,
) => promise<option<string>>

let members: (~app: string, ~session: Session.t) => promise<array<SpaceServer.member>>

let leave: (~app: string, ~session: Session.t) => promise<unit>

let removeMember: (~app: string, ~session: Session.t, ~memberId: string) => promise<bool>
