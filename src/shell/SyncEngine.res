// The orchestrator of a shared space, and the only module that touches all the
// pieces: the CRDT (AutomergeImpl), the crypto (ShareCrypto for the symmetric
// log, SpaceCrypto for handing keys to members), the server (SpaceServer), and
// the local stores.
//
// This module is itself the heavy chunk: it statically imports AutomergeImpl and
// its 3.9 MB of wasm, and is reached only through the dynamic imports in
// SpaceSync.res — a browser that never syncs never fetches any of it.
//
// One discipline carries the correctness: per app, everything runs through one
// promise chain, and every cycle applies the server's changes *before* diffing
// local state into the document. Broken, the diff would read a remotely deleted
// row still sitting in the local store as a local addition and resurrect it —
// state-sync against a log has exactly one safe order, and this is it.
//
// The engine never talks to React. Local data announces itself through the
// rn:collection-write event CollectionStore dispatches; remote arrivals go back
// out as rn:data (which the binder already listens for) and a callback for the
// document source, which is App's to route around the editor.

type timeoutId

@val external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"
@val external clearTimeout: timeoutId => unit = "clearTimeout"

type callbacks = {onDocument: string => unit}

type state = {
  mutable link: SpaceStore.link,
  mutable session: Session.t,
  mutable stopped: bool,
  mutable applying: bool,
  mutable chain: promise<unit>,
  mutable unsubscribe: option<unit => unit>,
  mutable pokeTimer: option<timeoutId>,
  callbacks: callbacks,
}

let active: Dict.t<state> = Dict.make()

// --- Small seams -------------------------------------------------------------

let announceData: unit => unit = %raw(`
function () {
  globalThis.dispatchEvent(new Event("rn:data"));
}
`)

// A function, not a value: anything time-varying read at module load is frozen —
// the Router.fragment lesson, applied before it bites twice.
let origin: unit => string = %raw(`
function () {
  return location.origin;
}
`)

/** The engine's snapshot of local reality, in the impl's shape. */
let buildSnapshot: (string, array<(string, Collection.t)>) => string = %raw(`
function (source, collections) {
  const held = {};
  for (const [path, collection] of collections) {
    const rows = {};
    for (const record of collection.records) {
      const fields = {};
      for (const field of record.fields) fields[field.name] = field.value;
      rows[record.id] = fields;
    }
    held[path] = rows;
  }
  return JSON.stringify({ source, collections: held });
}
`)

type materialized = {source: string, collections: array<(string, Collection.t)>}

let parseSnapshot: string => materialized = %raw(`
function (text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = {};
  }
  const collections = [];
  for (const [path, rows] of Object.entries(parsed.collections || {})) {
    const records = [];
    for (const [id, fields] of Object.entries(rows || {})) {
      records.push({
        id,
        fields: Object.entries(fields || {}).map(([name, value]) => ({
          name,
          value: String(value),
        })),
      });
    }
    collections.push([path, { records }]);
  }
  return { source: typeof parsed.source === "string" ? parsed.source : "", collections };
}
`)

let currentEpoch: SpaceStore.link => int = %raw(`
function (link) {
  let highest = 1;
  try {
    for (const epoch of Object.keys(JSON.parse(link.keys))) {
      const parsed = Number(epoch);
      if (parsed > highest) highest = parsed;
    }
  } catch {}
  return highest;
}
`)

let singleKeyJson: (int, string) => string = %raw(`
function (epoch, value) {
  const keys = {};
  keys[String(epoch)] = value;
  return JSON.stringify(keys);
}
`)

let addKeyJson: (string, int, string) => string = %raw(`
function (keys, epoch, value) {
  let parsed;
  try {
    parsed = JSON.parse(keys);
  } catch {
    parsed = {};
  }
  parsed[String(epoch)] = value;
  return JSON.stringify(parsed);
}
`)

// --- The serial chain --------------------------------------------------------

// Every operation for one app queues behind the previous one; a task that throws
// must not wedge the chain, so each is fenced.
let locked = (state, task: unit => promise<unit>) => {
  let next =
    state.chain->Promise.then(() =>
      state.stopped ? Promise.resolve() : task()->Promise.catch(_ => Promise.resolve())
    )
  state.chain = next
  next
}

// --- Materialising the document into the local stores ------------------------

// The engine's boundary translates ids. The space's document declares the
// *canonical* appId; locally the same app may live under another id, because
// every browser already holds a `welcome` and an id is only unique per browser.
// What syncs carries the canonical id, what lands locally carries the local one
// — which is also what keeps a local rename local instead of renaming the app
// for every member.
let toLocalSource = (link: SpaceStore.link, app, source) =>
  link.canonical == "" || link.canonical == app ? source : AppDocument.withId(source, app)

let toCanonicalSource = (link: SpaceStore.link, app, source) =>
  link.canonical == "" || link.canonical == app
    ? source
    : AppDocument.withId(source, link.canonical)

let materializeToLocal = async (app, state) => {
  let parsed = parseSnapshot(AutomergeImpl.materialize(~app))
  // The engine's own writes must not be read back as local edits.
  state.applying = true
  let held = await CollectionStore.paths(~app)
  let carried = parsed.collections->Array.map(((path, _)) => path)
  // Derived collections (::api-query, ::sql, ml-*) are this device's own work:
  // no snapshot carries them, and their absence there must not delete them.
  let derived = await DerivedPaths.list(~app)
  let _ = await Promise.all(
    held
    ->Array.filter(path => !(carried->Array.includes(path)) && !(derived->Array.includes(path)))
    ->Array.map(path => CollectionStore.remove(~app, ~path)),
  )
  await CollectionStore.importAll(~app, parsed.collections)
  if parsed.source != "" {
    let localSource = toLocalSource(state.link, app, parsed.source)
    switch await DocumentStore.load(app) {
    | Some(stored) if stored == localSource => ()
    | _ => {
        await DocumentStore.save(~id=app, ~source=localSource)
        state.callbacks.onDocument(localSource)
      }
    }
  }
  state.applying = false
  // The binder redraws every bound view; this is the same event the data panel
  // and ::python use for the same reason.
  announceData()
}

// --- Pull and push -----------------------------------------------------------

let pullOnce = async (app, state) => {
  let token = state.session.token
  switch await SpaceServer.listChangesSince(
    ~token,
    ~space=state.link.spaceId,
    ~since=state.link.cursor,
  ) {
  | None => () // No server here; the queue keeps local edits until there is.
  | Some([]) => ()
  | Some(changes) => {
      let opened = []
      for index in 0 to Array.length(changes) - 1 {
        let change = changes->Array.getUnsafe(index)
        switch SpaceStore.keyForEpoch(state.link, change.epoch) {
        | None => () // An epoch this member has no key for: after their removal.
        | Some(key) =>
          switch await ShareCrypto.decrypt(~key, ~payload=change.payload) {
          | None => () // Tampered or foreign; GCM already said so.
          | Some(decoded) => opened->Array.push(decoded)
          }
        }
      }
      let moved = AutomergeImpl.applyRemote(~app, ~changes=opened)
      switch changes->Array.at(-1) {
      | Some(last) => {
          state.link = {...state.link, cursor: last.created}
          await SpaceStore.saveLink(~app, state.link)
        }
      | None => ()
      }
      if moved {
        await SpaceStore.saveDoc(~app, AutomergeImpl.save(~app))
        await materializeToLocal(app, state)
      }
    }
  }
}

/** A compaction gap: the server folded changes this member never pulled into a
    snapshot. The snapshot is merged — not loaded over — so unsent local edits
    survive the gap. */
let catchUp = async (app, state) => {
  let token = state.session.token
  switch await SpaceServer.getSpace(~token, ~id=state.link.spaceId) {
  | None => ()
  | Some(space) =>
    if space.snapshotUntil != "" && space.snapshotUntil > state.link.cursor {
      switch SpaceStore.keyForEpoch(state.link, space.epoch) {
      | None => ()
      | Some(key) =>
        switch await ShareCrypto.decrypt(~key, ~payload=space.snapshot) {
        | None => ()
        | Some(saved) => {
            let _ = AutomergeImpl.mergeSaved(~app, ~saved)
            state.link = {...state.link, cursor: space.snapshotUntil}
            await SpaceStore.saveLink(~app, state.link)
            await SpaceStore.saveDoc(~app, AutomergeImpl.save(~app))
            await materializeToLocal(app, state)
          }
        }
      }
    }
  }
}

let flushQueue = async (app, state) => {
  let pending = await SpaceStore.loadQueue(~app)
  if Array.length(pending) > 0 {
    let remaining = []
    for index in 0 to Array.length(pending) - 1 {
      let (epoch, payload) = pending->Array.getUnsafe(index)
      let sent = await SpaceServer.createChange(
        ~token=state.session.token,
        ~space=state.link.spaceId,
        ~author=state.session.userId,
        ~epoch,
        ~payload,
      )
      if !sent {
        remaining->Array.push((epoch, payload))
      }
    }
    await SpaceStore.saveQueue(~app, remaining)
  }
}

let pushLocal = async (app, state) => {
  let source = switch await DocumentStore.load(app) {
  | Some(text) => toCanonicalSource(state.link, app, text)
  | None => ""
  }
  // Derived collections stay local: a fetched exchange rate or a model's
  // output is not a shared fact — every member computes their own.
  let derived = await DerivedPaths.list(~app)
  let collections =
    (await CollectionStore.exportAll(~app))
    ->Array.filter(((path, _)) => !(derived->Array.includes(path)))
  let snapshot = buildSnapshot(source, collections)
  switch AutomergeImpl.applyLocal(~app, ~snapshot) {
  | None => ()
  | Some(change) => {
      await SpaceStore.saveDoc(~app, AutomergeImpl.save(~app))
      // A reader's local edits stay local by design: they merge with what
      // arrives, and the server would refuse the append anyway.
      if state.link.role != "reader" {
        let epoch = currentEpoch(state.link)
        switch SpaceStore.keyForEpoch(state.link, epoch) {
        | None => ()
        | Some(key) => {
            let sealed = await ShareCrypto.encrypt(~key, ~text=change)
            let sent = await SpaceServer.createChange(
              ~token=state.session.token,
              ~space=state.link.spaceId,
              ~author=state.session.userId,
              ~epoch,
              ~payload=sealed,
            )
            if !sent {
              let pending = await SpaceStore.loadQueue(~app)
              pending->Array.push((epoch, sealed))
              await SpaceStore.saveQueue(~app, pending)
            }
          }
        }
      }
    }
  }
}

/** One full cycle, in the only safe order: catch up past any compaction, apply
    the log, flush what waited, then diff local state in. */
let cycle = (app, state) =>
  locked(state, async () => {
    await catchUp(app, state)
    await pullOnce(app, state)
    await flushQueue(app, state)
    await pushLocal(app, state)
  })

// --- Realtime ----------------------------------------------------------------

// PocketBase realtime without the SDK: one EventSource, one subscription POST.
// The topic is the whole changes collection — the list rule already narrows the
// events to this member's spaces, server-side. On anything, the engine pulls;
// deciding relevance client-side would reimplement the rule, worse.
let subscribe: (~token: string, ~onPing: unit => unit) => (unit => unit) = %raw(`
function (token, onPing) {
  let source = null;
  let stopped = false;
  let retry = 1000;
  const connect = () => {
    if (stopped) return;
    try {
      source = new EventSource("/pb/api/realtime");
    } catch (error) {
      return;
    }
    source.addEventListener("PB_CONNECT", (event) => {
      let clientId = "";
      try {
        clientId = JSON.parse(event.data).clientId;
      } catch {
        clientId = event.lastEventId || "";
      }
      retry = 1000;
      fetch("/pb/api/realtime", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: token },
        body: JSON.stringify({ clientId, subscriptions: ["changes"] }),
      }).catch(() => {});
    });
    source.addEventListener("changes", () => onPing());
    source.onerror = () => {
      if (source) source.close();
      if (!stopped) {
        setTimeout(connect, retry);
        retry = Math.min(retry * 2, 30000);
      }
    };
  };
  connect();
  return () => {
    stopped = true;
    if (source) source.close();
  };
}
`)

// --- Lifecycle ---------------------------------------------------------------

let pokeSoon = (app, state) => {
  switch state.pokeTimer {
  | Some(timer) => clearTimeout(timer)
  | None => ()
  }
  state.pokeTimer = Some(
    setTimeout(() => {
      state.pokeTimer = None
      cycle(app, state)->ignore
    }, 500),
  )
}

/** Local data or the document changed; fold it in and push, debounced. */
let localChanged = (~app) =>
  switch active->Dict.get(app) {
  | Some(state) if !state.applying => pokeSoon(app, state)
  | _ => ()
  }

// One listener for the module's lifetime: CollectionStore announces every
// durable write, whoever made it, and the engine only reacts for apps it runs.
%%raw(`
globalThis.addEventListener("rn:collection-write", (event) => {
  const app = event && event.detail && event.detail.app;
  if (typeof app === "string" && app !== "") localChanged(app);
})
`)

let stop = (~app) =>
  switch active->Dict.get(app) {
  | None => ()
  | Some(state) => {
      state.stopped = true
      switch state.unsubscribe {
      | Some(close) => close()
      | None => ()
      }
      switch state.pokeTimer {
      | Some(timer) => clearTimeout(timer)
      | None => ()
      }
      AutomergeImpl.close(~app)
      active->Dict.delete(app)
    }
  }

/** Starts the engine for an app, if that app is linked to a space. Loads the
    wasm, restores the held document, runs a first cycle and subscribes. */
let start = async (~app, ~session: Session.t, ~onDocument) => {
  stop(~app)
  switch await SpaceStore.loadLink(~app) {
  | None => ()
  | Some(link) => {
      await AutomergeImpl.init()
      let saved = await SpaceStore.loadDoc(~app)
      AutomergeImpl.open_(~app, ~saved)
      let state = {
        link,
        session,
        stopped: false,
        applying: false,
        chain: Promise.resolve(),
        unsubscribe: None,
        pokeTimer: None,
        callbacks: {onDocument: onDocument},
      }
      active->Dict.set(app, state)
      state.unsubscribe = Some(
        subscribe(~token=session.token, ~onPing=() =>
          switch active->Dict.get(app) {
          | Some(held) if !held.stopped => cycle(app, held)->ignore
          | _ => ()
          }
        ),
      )
      await cycle(app, state)
    }
  }
}

let isActive = (~app) => active->Dict.get(app)->Option.isSome

let roleOf = async (~app) =>
  switch active->Dict.get(app) {
  | Some(state) => Some(state.link.role)
  | None => (await SpaceStore.loadLink(~app))->Option.map(link => link.role)
  }

// --- Creating, inviting, joining, leaving ------------------------------------

/** Turns an app's data into a shared space, with this account as owner. The
    space key is minted here and reaches the server only wrapped to the owner's
    own public key; the first cycle pushes the current state as the first change. */
let create = async (~app, ~session: Session.t) => {
  let token = session.token
  switch await SpaceServer.createSpace(~token, ~owner=session.userId) {
  | None => false
  | Some(spaceId) => {
      let spaceKey = await ShareCrypto.generateKey()
      let wrapped = await SpaceCrypto.wrapForMember(~pub=session.pub, ~secret=spaceKey)
      let joined = await SpaceServer.createMember(
        ~token,
        ~space=spaceId,
        ~user=session.userId,
        ~role="owner",
        ~label=session.username,
        ~pub=session.pub,
        ~keys=singleKeyJson(1, wrapped),
        ~invite="",
      )
      if !joined {
        false
      } else {
        let link: SpaceStore.link = {
          spaceId,
          role: "owner",
          keys: singleKeyJson(1, spaceKey),
          cursor: "",
          canonical: app,
        }
        await SpaceStore.saveLink(~app, link)
        true
      }
    }
  }
}

/** An invitation link for this app's space. The invite key is minted here, seals
    the space key, and leaves only inside the returned link's fragment. */
let invite = async (~app, ~session: Session.t, ~role) =>
  switch await SpaceStore.loadLink(~app) {
  | None => None
  | Some(link) => {
      let epoch = currentEpoch(link)
      switch SpaceStore.keyForEpoch(link, epoch) {
      | None => None
      | Some(spaceKey) => {
          let inviteKey = await ShareCrypto.generateKey()
          let sealedKey = await ShareCrypto.encrypt(~key=inviteKey, ~text=spaceKey)
          switch await SpaceServer.createInvite(
            ~token=session.token,
            ~space=link.spaceId,
            ~role,
            ~sealedKey,
            ~epoch,
          ) {
          | None => None
          | Some(id) => Some(SpaceLink.of_(~origin=origin(), ~id, ~key=inviteKey))
          }
        }
      }
    }
  }

// Join builds the document under a throwaway key first: the app id is not known
// until the source has been read out of the space.
let joinScratch = "@join"

/** Accepts an invitation. Returns the local app id to open, or None — an
    invalid, used or stale invitation, or a server that is not there. */
let join = async (~inviteId, ~key, ~session: Session.t, ~taken, ~fallback) => {
  let token = session.token
  switch await SpaceServer.getInvite(~token, ~id=inviteId) {
  | None => None
  | Some(found) =>
    switch await ShareCrypto.decrypt(~key, ~payload=found.sealedKey) {
    | None => None
    | Some(spaceKey) => {
        // Membership first: the space record is visible to members alone, so
        // reading it before joining answers 404 for exactly the person trying
        // to join. The server hook validates and burns the invite in the same
        // request that creates the membership.
        let wrapped = await SpaceCrypto.wrapForMember(~pub=session.pub, ~secret=spaceKey)
        let member = await SpaceServer.createMember(
          ~token,
          ~space=found.space,
          ~user=session.userId,
          ~role=found.role,
          ~label=session.username,
          ~pub=session.pub,
          ~keys=singleKeyJson(found.epoch, wrapped),
          ~invite=inviteId,
        )
        if !member {
          None
        } else {
          switch await SpaceServer.getSpace(~token, ~id=found.space) {
          | None => None
          | Some(space) if space.epoch != found.epoch => {
              // The key was rotated after this invitation was written: its key
              // opens nothing current. Backing out beats joining someone into a
              // space they cannot read.
              let rows = await SpaceServer.listMembers(~token, ~space=found.space)
              switch rows->Array.find(row => row.user == session.userId) {
              | Some(own) => {
                  let _ = await SpaceServer.deleteMember(~token, ~id=own.id)
                }
              | None => ()
              }
              None
            }
          | Some(space) => {
            await AutomergeImpl.init()
            AutomergeImpl.open_(~app=joinScratch, ~saved=None)
            // Snapshot first, then the log after it — the same order a member
            // catching up after compaction follows.
            let cursor = ref("")
            if space.snapshotUntil != "" && space.snapshot != "" {
              switch await ShareCrypto.decrypt(~key=spaceKey, ~payload=space.snapshot) {
              | None => ()
              | Some(saved) => {
                  let _ = AutomergeImpl.mergeSaved(~app=joinScratch, ~saved)
                  cursor := space.snapshotUntil
                }
              }
            }
            switch await SpaceServer.listChangesSince(
              ~token,
              ~space=found.space,
              ~since=cursor.contents,
            ) {
            | None => ()
            | Some(changes) => {
                let opened = []
                for index in 0 to Array.length(changes) - 1 {
                  let change = changes->Array.getUnsafe(index)
                  if change.epoch == found.epoch {
                    switch await ShareCrypto.decrypt(~key=spaceKey, ~payload=change.payload) {
                    | None => ()
                    | Some(decoded) => opened->Array.push(decoded)
                    }
                  }
                }
                let _ = AutomergeImpl.applyRemote(~app=joinScratch, ~changes=opened)
                switch changes->Array.at(-1) {
                | Some(last) => cursor := last.created
                | None => ()
                }
              }
            }
            let parsed = parseSnapshot(AutomergeImpl.materialize(~app=joinScratch))
            let canonical = AppFile.idFor(~source=parsed.source, ~taken=[], ~fallback)
            // The canonical id is free locally in the lucky case; when it is
            // taken — every browser already has a `welcome` — the same space
            // rejoins under its old local id, and an unrelated app keeps its id
            // while this one lands as a neighbour. Never a refusal, never an
            // overwrite, and never a rename that would sync to everyone.
            let sameSpace = switch await SpaceStore.loadLink(~app=canonical) {
            | Some(existing) => existing.spaceId == found.space
            | None => false
            }
            let localId =
              !(taken->Array.includes(canonical)) || sameSpace
                ? canonical
                : AppId.unique(~desired=canonical, ~taken)
            let link: SpaceStore.link = {
              spaceId: found.space,
              role: found.role,
              keys: singleKeyJson(found.epoch, spaceKey),
              cursor: cursor.contents,
              canonical,
            }
            let localSource =
              canonical == localId
                ? parsed.source
                : AppDocument.withId(parsed.source, localId)
            await DocumentStore.save(~id=localId, ~source=localSource)
            await CollectionStore.clear(~app=localId)
            await CollectionStore.importAll(~app=localId, parsed.collections)
            await SpaceStore.saveDoc(~app=localId, AutomergeImpl.save(~app=joinScratch))
            AutomergeImpl.close(~app=joinScratch)
            await SpaceStore.saveLink(~app=localId, link)
            Some(localId)
          }
        }
      }
    }
  }
}
}

let members = async (~app, ~session: Session.t) =>
  switch await SpaceStore.loadLink(~app) {
  | None => []
  | Some(link) => await SpaceServer.listMembers(~token=session.token, ~space=link.spaceId)
  }

/** Removes a member, then turns the key: a new epoch key wrapped for everyone
    who remains, the space's epoch bumped, and a fresh snapshot sealed under the
    new key — so someone joining tomorrow never needs the old one. What the
    removed member already read, they keep; nothing after this, they can open. */
let removeMember = async (~app, ~session: Session.t, ~memberId) =>
  switch await SpaceStore.loadLink(~app) {
  | None => false
  | Some(link) => {
      let token = session.token
      let removed = await SpaceServer.deleteMember(~token, ~id=memberId)
      if !removed {
        false
      } else {
        let newEpoch = currentEpoch(link) + 1
        let newKey = await ShareCrypto.generateKey()
        let remaining = await SpaceServer.listMembers(~token, ~space=link.spaceId)
        for index in 0 to Array.length(remaining) - 1 {
          let row = remaining->Array.getUnsafe(index)
          let sealed = await SpaceCrypto.wrapForMember(~pub=row.pub, ~secret=newKey)
          let _ = await SpaceServer.updateMemberKeys(
            ~token,
            ~id=row.id,
            ~keys=addKeyJson(row.keys, newEpoch, sealed),
          )
        }
        let updated = SpaceStore.withEpochKey(link, newEpoch, newKey)
        // The engine may be running on the old link; retire the old state and
        // let the caller restart it on the new one.
        let snapshot = switch active->Dict.get(app) {
        | Some(state) => {
            state.link = updated
            AutomergeImpl.save(~app)
          }
        | None => ""
        }
        await SpaceStore.saveLink(~app, updated)
        let sealedSnapshot = snapshot == ""
          ? ""
          : await ShareCrypto.encrypt(~key=newKey, ~text=snapshot)
        let body = `{"epoch": ${newEpoch->Int.toString}` ++ (
          sealedSnapshot == ""
            ? "}"
            : `, "snapshot": ${JSON.stringifyAny(sealedSnapshot)->Option.getOr("\"\"")}, "snapshotUntil": ${JSON.stringifyAny(
                updated.cursor,
              )->Option.getOr("\"\"")}}`
        )
        let _ = await SpaceServer.updateSpace(~token, ~id=link.spaceId, ~body)
        true
      }
    }
  }
