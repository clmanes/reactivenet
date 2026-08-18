/// <reference path="../pb_data/types.d.ts" />
//
// The one collection the server holds: shared documents, encrypted before they ever
// leave the browser. The server cannot read them — the key rides in the link's
// fragment, which is never sent — so what sits here is a blob, an id, and the date it
// was last opened.
//
// The rules are the API: anyone may deposit one (create) and fetch one by id (view);
// nobody may list, update or delete from outside. lastUsed is written by the hooks,
// server-side, so a client can neither skip the touch nor forge the clock.

migrate(
  (app) => {
    const collection = new Collection({
      name: "shares",
      type: "base",
      fields: [
        {
          name: "payload",
          type: "text",
          required: true,
          // ~100 KB of encrypted, base64-encoded document. The client checks the
          // same ceiling before posting; this is the copy that cannot be bypassed.
          max: 140000,
        },
        {
          name: "lastUsed",
          type: "date",
        },
        {
          name: "created",
          type: "autodate",
          onCreate: true,
        },
      ],
      listRule: null,
      viewRule: "",
      createRule: "",
      updateRule: null,
      deleteRule: null,
    });
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("shares");
    app.delete(collection);
  },
);
