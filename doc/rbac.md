# Shared spaces: RBAC and encryption architecture

How collections sync between users, who may do what, and — first — who enforces
which promise. Everything here is end-to-end encrypted: the server stores blobs it
cannot read, so the access model has to be honest about what each layer can
actually guarantee.

## The three enforcement layers

RBAC over encrypted data splits into three layers, and every promise the system
makes belongs to exactly one of them:

| Promise | Enforced by | Holds against |
| --- | --- | --- |
| *Reading* — who can decrypt | **Cryptography.** No key, no plaintext. | A compromised or malicious server, a database dump, anyone on the wire. |
| *Writing* — who may append | **The server.** Rules and hooks check the author's role before accepting a change. | Honest-but-unauthorised clients. AES-GCM adds a second wall: a non-member cannot even *forge* a valid ciphertext, so a malicious server cannot inject changes either. |
| *Fine grain* — "only your own rows", field-level rules | **The client**, advisory. Inside an encrypted blob the server cannot distinguish rows. | Normal use only — not a hostile client that already holds the read key. Not offered as a security boundary, and deliberately not offered in the UI. |

And one physical limit, stated rather than papered over: **revocation cannot
un-read the past.** A removed member held the key; what they saw, they could have
copied. What revocation guarantees is the *future* — see epochs, below.

## Roles

Three, spartan on purpose:

| Role | May |
| --- | --- |
| `owner` | Everything: invite, remove members, rotate keys, write snapshots, delete the space. One per space, named on the space record — which is what keeps the server rules simple and sound. |
| `editor` | Read and append changes. |
| `reader` | Read. The server refuses their appends (hook, not rule — see below). Their *local* edits still work and merge with what arrives; they simply never upload, which is the honest meaning of read-only in a local-first system. |

Ownership is not invitable and not transferable by a link; a member cannot change
their own role (`members.updateRule` is owner-only, verified: self-promotion
answers 404).

## Identity and keys

- **An account is a pseudonym and a key bundle.** Username + password; email
  optional and never used to sign in. No user directory exists: `users` has
  `listRule: null` and a view rule of `id = @request.auth.id` — the server never
  answers "who is here".
- **Per user**: a P-256 ECDH keypair. The private half is stored on the server
  sealed twice — under PBKDF2-SHA256 (600k rounds) of the password, and under a
  160-bit recovery code (Crockford base32, shown exactly once at registration).
  The server holds a vault it has no key to; **a forgotten password without the
  recovery code is unrecoverable, by design**.
- **Per space, per epoch**: one AES-GCM-256 key. Every change and every snapshot
  is sealed under the epoch key current when it was written.
- **Key transport**: a member's copy of the space key travels ECIES-wrapped
  (ephemeral ECDH → AES-GCM) to their public key, on their own membership record.
  The member's public key sits on that record too, written by them at join — it is
  what lets the owner wrap a *new* epoch key for everyone who remains, with no
  directory anywhere.

On this device, the opened private key and space keys live in IndexedDB — the same
trust every end-to-end client extends to the device it runs on. Leaving a space
deletes the link, the keys, the queue and the document copy together.

## Invitations

An invitation is a link, and the link is the capability:

    /j/<inviteId>#k<inviteKey>

The invite record on the server holds the space key sealed under the invite key —
which rides in the fragment and **is never sent**. Whoever has the whole link can
join, with the role the invite names, exactly once: the server hook burns the
invite in the same request that creates the membership, and a failed join does not
consume it. Role escalation (presenting a reader invite while claiming editor) is
refused server-side. Unaccepted invites are purged after 14 days by cron, and an
invite written before a key rotation is refused as stale rather than admitting
someone to a space they cannot read.

Joining is never silent: it requires a signed-in account and one explicit
confirmation in a modal, because joining writes a membership and downloads a
space — not something visiting a URL should do by itself.

## The server (PocketBase)

Four collections beyond `users`; everything a rule can say soundly is a rule, and
the two decisions a rule *cannot* express soundly live in hooks
(`pb/pb_hooks/spaces.pb.js`):

- `spaces` — owner, epoch number, encrypted snapshot, snapshot cursor. Visible to
  members only (which is why joining creates the membership *before* reading the
  space).
- `members` — space, user, role, chosen display name, public key, wrapped keys by
  epoch. Listable only from inside the space.
- `invites` — space, role, sealed key, epoch. Fetched by id; never listed.
- `changes` — space, author, epoch, encrypted payload. Append-only from outside;
  members read, the compaction hook deletes.

The hook pitfall the rules cannot cover: a filter like
`members_via_space.user ?= @request.auth.id && members_via_space.role != "reader"`
is satisfied when *any* row matches each condition separately — a reader passes as
long as somebody else is an editor. Binding "this user's row has this role" needs
a query, so member-creation (invite validity, owner bootstrap, no duplicates) and
change-creation (author's own role is editor or owner, epoch is current) are
hooks.

## Sync: an encrypted log, merged by Automerge

The server is an append-only relay of opaque blobs. Merging happens only in
clients — the server could not merge what it cannot read.

- **One Automerge document per space**: `{ source, collections: { path: { rowId:
  { field: value } } } }`. Rows are maps, so concurrent edits of different fields
  of the same row merge; the markdown source is a text CRDT (`updateText`), so
  edits to different paragraphs merge. Same field, same moment: last writer wins,
  which for rows of strings is the honest answer.
- **A change** is an Automerge change batch, base64, sealed with the epoch key,
  appended to the log with its epoch number. Applying a change twice is free
  (Automerge deduplicates by hash), so the pull cursor may overlap and never gap.
- **Realtime** is PocketBase's SSE, no SDK: the client subscribes to the `changes`
  topic and the list rule filters events to its spaces server-side. Offline
  appends queue in IndexedDB and flush on the next cycle.
- **Order is the correctness**: per app, one serial chain, and every cycle applies
  the server's changes *before* diffing local state into the document. Reversed,
  a remotely deleted row still sitting in the local store would read as a local
  addition and resurrect itself.
- **Compaction**: the owner writes the whole document, sealed, onto the space
  record with a cursor; the hook deletes the changes it folded in. A member who
  was offline past a compaction *merges* the snapshot (CRDT merge, not
  replacement), so their unsent edits survive the gap.
- **The engine is a lazy chunk.** Automerge's wasm is 3.9 MB; it is excluded from
  the PWA precache and fetched the first time an account actually syncs. A
  browser that never syncs never loads a byte of it — and nothing else in the app
  needs an account at all.

The unit of sharing is the app's whole dataset, and the document travels with it —
an invitation delivers a working app, not naked rows. The chat panel (`chat: true`
in the frontmatter) rides the same machinery unchanged: its messages are rows of
an ordinary collection, so members converse end-to-end encrypted with no chat
server anywhere — and a reader's messages stay local, refused like any other
append. Ids are translated at the
engine's boundary: the space carries the canonical `appId`, the local copy may
live under another id (every browser already has a `welcome`), and a local rename
stays local.

## What the server sees, and what it cannot

Cannot, ever: row contents, the document, collection names, space names, any key.
Verified against the stored records: no plaintext of any synced word appears
anywhere.

Does see, necessarily: that a pseudonym is a member of a space (with role), when
changes are appended and how large they are, IP addresses, and the chosen display
names members show each other. That is the metadata floor of this design —
minimised, then named, rather than denied.

## Verified end to end

Two browsers, two accounts: registration with recovery code; invite → confirm →
join (id collision landing as a neighbour); bidirectional row sync over SSE within
seconds; server-side ciphertext-only storage; reader append refused (403) while an
editor's is accepted; invite burned on use and surviving a failed attempt;
anonymous and non-member reads answering nothing; removal rotating to epoch 2,
rewrapping for the remaining member, snapshotting and compacting the log — after
which the removed member receives nothing further.
