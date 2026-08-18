/** Every call a shared space makes against PocketBase, as plain fetches on /pb.
    Failures are None / false / empty — except listChangesSince, whose None means
    "no server here" as distinct from "nothing new". */

type space = {
  id: string,
  owner: string,
  epoch: int,
  snapshot: string,
  snapshotUntil: string,
}

type member = {
  id: string,
  user: string,
  role: string,
  label: string,
  pub: string,
  keys: string,
}

type invite = {
  id: string,
  space: string,
  role: string,
  sealedKey: string,
  epoch: int,
}

type change = {
  id: string,
  epoch: int,
  payload: string,
  created: string,
}

let createSpace: (~token: string, ~owner: string) => promise<option<string>>

let getSpace: (~token: string, ~id: string) => promise<option<space>>

/** PATCH with a raw JSON body — snapshot writes and epoch bumps. */
let updateSpace: (~token: string, ~id: string, ~body: string) => promise<bool>

let createMember: (
  ~token: string,
  ~space: string,
  ~user: string,
  ~role: string,
  ~label: string,
  ~pub: string,
  ~keys: string,
  ~invite: string,
) => promise<bool>

let listMembers: (~token: string, ~space: string) => promise<array<member>>

let updateMemberKeys: (~token: string, ~id: string, ~keys: string) => promise<bool>

let deleteMember: (~token: string, ~id: string) => promise<bool>

let createInvite: (
  ~token: string,
  ~space: string,
  ~role: string,
  ~sealedKey: string,
  ~epoch: int,
) => promise<option<string>>

let getInvite: (~token: string, ~id: string) => promise<option<invite>>

let createChange: (
  ~token: string,
  ~space: string,
  ~author: string,
  ~epoch: int,
  ~payload: string,
) => promise<bool>

/** Everything after a cursor, oldest first; None means the server is unreachable. */
let listChangesSince: (
  ~token: string,
  ~space: string,
  ~since: string,
) => promise<option<array<change>>>
