// The light doorway to the heavy engine.
//
// SyncEngine statically imports Automerge — 3.9 MB of wasm — so nothing in the
// app's main graph may import it statically; every reference here is a dynamic
// `import()`, which Vite splits into a chunk fetched the first time an account
// actually syncs something. Whether an app is linked at all is answered from
// SpaceStore directly: that question must stay cheap, because App asks it on
// every app open, and the answer is usually no.

let engineLoaded = ref(false)

let start = async (~app, ~session, ~onDocument) => {
  switch await SpaceStore.loadLink(~app) {
  | None => () // Not linked: the engine is neither needed nor fetched.
  | Some(_) => {
      let go = await import(SyncEngine.start)
      engineLoaded := true
      await go(~app, ~session, ~onDocument)
    }
  }
}

let stop = (~app) => {
  // Only an engine that ever started has anything to stop; loading 4 MB to call
  // a no-op would be absurd, so the flag guards the import.
  if engineLoaded.contents {
    import(SyncEngine.stop)
    ->Promise.thenResolve(halt => halt(~app))
    ->ignore
  }
}

/** The document was saved locally; let the engine fold it in, if one runs. */
let localChanged = (~app) => {
  if engineLoaded.contents {
    import(SyncEngine.localChanged)
    ->Promise.thenResolve(poke => poke(~app))
    ->ignore
  }
}

/** Whether this app is linked to a space, from the light store alone. */
let isLinked = async (~app) => (await SpaceStore.loadLink(~app))->Option.isSome

let roleOf = async (~app) => (await SpaceStore.loadLink(~app))->Option.map(link => link.role)

let create = async (~app, ~session) => {
  let go = await import(SyncEngine.create)
  engineLoaded := true
  await go(~app, ~session)
}

let invite = async (~app, ~session, ~role) => {
  let go = await import(SyncEngine.invite)
  await go(~app, ~session, ~role)
}

let join = async (~inviteId, ~key, ~session, ~taken, ~fallback) => {
  let go = await import(SyncEngine.join)
  engineLoaded := true
  await go(~inviteId, ~key, ~session, ~taken, ~fallback)
}

let members = async (~app, ~session) => {
  let go = await import(SyncEngine.members)
  await go(~app, ~session)
}

// Leaving needs no CRDT — a membership row deleted, three local keys removed —
// so it deliberately does not touch the engine: deleting an app must not fetch
// 4 MB of wasm on its way out.
let leave = async (~app, ~session: Session.t) =>
  switch await SpaceStore.loadLink(~app) {
  | None => ()
  | Some(link) => {
      stop(~app)
      let rows = await SpaceServer.listMembers(~token=session.token, ~space=link.spaceId)
      switch rows->Array.find(row => row.user == session.userId) {
      | Some(own) => {
          let _ = await SpaceServer.deleteMember(~token=session.token, ~id=own.id)
        }
      | None => ()
      }
      await SpaceStore.clear(~app)
    }
  }

let removeMember = async (~app, ~session, ~memberId) => {
  let go = await import(SyncEngine.removeMember)
  await go(~app, ~session, ~memberId)
}
