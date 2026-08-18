/// <reference path="../pb_data/types.d.ts" />
//
// The users collection, reshaped for end-to-end encryption and minimal identity.
//
// An account here is a pseudonym and a key bundle, nothing more. The identity field
// is a username — email stays on the collection (PocketBase requires the system
// field) but is optional, invisible, and never used to sign in. The keyBundle holds
// the user's public key and their private key sealed twice: once by a key derived
// from the password, once by the recovery code. The server can open neither — it
// stores a vault it has no key to.
//
// Rules: anyone may register (create), and a record is visible to its owner alone.
// Nobody lists users — there is no directory to enumerate, so the server never
// answers "who is here". A member's public key travels on the membership record
// instead, written by the member themselves when they join a space.

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");

    users.fields.add(
      new Field({
        name: "username",
        type: "text",
        required: true,
        min: 3,
        max: 32,
        pattern: "^[a-z0-9][a-z0-9-]*$",
      }),
    );
    users.fields.add(
      new Field({
        name: "keyBundle",
        type: "json",
        maxSize: 20000,
      }),
    );

    // Email becomes what it says on the form: optional, and only ever a recovery
    // channel. PocketBase keeps the system field either way; requiring it would put
    // an address in every account for no reason the design has.
    const email = users.fields.getByName("email");
    email.required = false;

    // The identity field needs a unique index, and the existing indexes (tokenKey,
    // email) must survive — so the list is copied, not replaced.
    const indexes = [];
    for (let i = 0; i < users.indexes.length; i++) indexes.push(users.indexes[i]);
    indexes.push("CREATE UNIQUE INDEX `idx_users_username` ON `users` (`username`)");

    unmarshal(
      {
        indexes: indexes,
        passwordAuth: { enabled: true, identityFields: ["username"] },
        listRule: null,
        viewRule: "id = @request.auth.id",
        createRule: "",
        updateRule: "id = @request.auth.id",
        deleteRule: "id = @request.auth.id",
      },
      users,
    );

    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.fields.removeByName("username");
    users.fields.removeByName("keyBundle");
    const indexes = [];
    for (let i = 0; i < users.indexes.length; i++) {
      if (users.indexes[i].indexOf("idx_users_username") === -1) indexes.push(users.indexes[i]);
    }
    unmarshal(
      {
        indexes: indexes,
        passwordAuth: { enabled: true, identityFields: ["email"] },
      },
      users,
    );
    app.save(users);
  },
);
