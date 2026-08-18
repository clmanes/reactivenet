/// <reference path="../pb_data/types.d.ts" />
//
// The four collections behind shared spaces. What the server holds is deliberately
// unreadable to it: a space is an id, an owner, an epoch number and an encrypted
// snapshot; a change is an encrypted blob; the only cleartext anywhere is *who* may
// touch *what* — which is exactly the part the server has to know to enforce it.
//
// The rules carry the coarse RBAC: read what you are a member of, append only what
// the create-hooks allow (the editor/owner check lives in pb_hooks/spaces.pb.js,
// because a rule joining members twice cannot bind role and user to the same row),
// manage only what you own. The fine-grained story — who can decrypt — is not here
// at all: it is key distribution, and the server never holds a key.

migrate(
  (app) => {
    const spaces = new Collection({
      name: "spaces",
      type: "base",
      fields: [
        {
          name: "owner",
          type: "relation",
          required: true,
          collectionId: app.findCollectionByNameOrId("users").id,
          maxSelect: 1,
          // The space outlives nothing: when the account goes, its spaces go.
          cascadeDelete: true,
        },
        // Which generation of the space key current changes are sealed under.
        // Bumped on every revocation; members hold one wrapped key per epoch.
        { name: "epoch", type: "number", required: true, min: 1 },
        // An encrypted Automerge document, so a new member does not replay the
        // whole log. ~2 MB of base64 — the same order as a large app's data.
        { name: "snapshot", type: "text", max: 2000000 },
        // The `created` cursor of the last change folded into the snapshot.
        { name: "snapshotUntil", type: "date" },
        { name: "created", type: "autodate", onCreate: true },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      listRule: null,
      // The membership-based view rule is set below, once `members` exists — a
      // back-relation cannot be named before the collection it points from.
      viewRule: null,
      createRule: "@request.auth.id != '' && owner = @request.auth.id",
      updateRule: "owner = @request.auth.id",
      deleteRule: "owner = @request.auth.id",
    });
    app.save(spaces);

    const members = new Collection({
      name: "members",
      type: "base",
      fields: [
        {
          name: "space",
          type: "relation",
          required: true,
          collectionId: app.findCollectionByNameOrId("spaces").id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "user",
          type: "relation",
          required: true,
          collectionId: app.findCollectionByNameOrId("users").id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "role",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["owner", "editor", "reader"],
        },
        // What the member calls themselves, written by them at join. It exists
        // because the users collection is deliberately unreadable: inside a space
        // the people who share it see each other's chosen name, and nobody else
        // sees anything.
        { name: "label", type: "text", max: 64 },
        // The member's public key, copied here at join by the member themselves:
        // it is what lets the owner wrap a *new* epoch key for them without any
        // user directory existing.
        { name: "pub", type: "json", maxSize: 2000 },
        // One wrapped space key per epoch, sealed to this member's public key.
        { name: "keys", type: "json", maxSize: 20000 },
        { name: "created", type: "autodate", onCreate: true },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      // Any member sees the member list: the sharing panel shows it, and the owner
      // needs it to rotate keys. This is the one piece of social metadata the
      // design accepts — who shares a space with whom — and it is visible only
      // from inside that space.
      listRule: "@request.auth.id != '' && space.members_via_space.user ?= @request.auth.id",
      viewRule: "@request.auth.id != '' && space.members_via_space.user ?= @request.auth.id",
      // Creating yourself as a member: the invite (or being the owner) is checked
      // in the hook — a rule cannot bind "this user's row has this role".
      createRule: "@request.auth.id != '' && user = @request.auth.id",
      // Only the owner rewrites membership records: that is what key rotation is.
      updateRule: "space.owner = @request.auth.id",
      // The owner removes anyone; anyone may leave.
      deleteRule: "space.owner = @request.auth.id || user = @request.auth.id",
    });
    app.save(members);

    const savedSpaces = app.findCollectionByNameOrId("spaces");
    savedSpaces.viewRule =
      "@request.auth.id != '' && members_via_space.user ?= @request.auth.id";
    app.save(savedSpaces);

    const invites = new Collection({
      name: "invites",
      type: "base",
      fields: [
        {
          name: "space",
          type: "relation",
          required: true,
          collectionId: app.findCollectionByNameOrId("spaces").id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "role",
          type: "select",
          required: true,
          maxSelect: 1,
          // Ownership is not something a link hands out.
          values: ["editor", "reader"],
        },
        // The current space key, sealed with the invite key — which rides in the
        // invitation link's fragment and never reaches this server.
        { name: "sealedKey", type: "text", required: true, max: 2000 },
        { name: "epoch", type: "number", required: true, min: 1 },
        { name: "created", type: "autodate", onCreate: true },
      ],
      listRule: null,
      // Fetched by id, signed in: the id plus the fragment key *is* the invitation.
      viewRule: "@request.auth.id != ''",
      createRule: "@request.auth.id != '' && space.owner = @request.auth.id",
      updateRule: null,
      deleteRule: "space.owner = @request.auth.id",
    });
    app.save(invites);

    const changes = new Collection({
      name: "changes",
      type: "base",
      fields: [
        {
          name: "space",
          type: "relation",
          required: true,
          collectionId: app.findCollectionByNameOrId("spaces").id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "author",
          type: "relation",
          required: true,
          collectionId: app.findCollectionByNameOrId("users").id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        { name: "epoch", type: "number", required: true, min: 1 },
        // An encrypted Automerge change batch, base64. The server relays blobs it
        // cannot read; AES-GCM means it cannot forge one either.
        { name: "payload", type: "text", required: true, max: 2000000 },
        { name: "created", type: "autodate", onCreate: true },
      ],
      listRule: "@request.auth.id != '' && space.members_via_space.user ?= @request.auth.id",
      viewRule: "@request.auth.id != '' && space.members_via_space.user ?= @request.auth.id",
      // Membership with a writing role is checked in the hook; the rule carries
      // what a rule can say soundly.
      createRule: "@request.auth.id != '' && author = @request.auth.id",
      // Append-only from outside: compaction deletes server-side, in the hook.
      updateRule: null,
      deleteRule: null,
    });
    app.save(changes);
  },
  (app) => {
    for (const name of ["changes", "invites", "members", "spaces"]) {
      const collection = app.findCollectionByNameOrId(name);
      app.delete(collection);
    }
  },
);
