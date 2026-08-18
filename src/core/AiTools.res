// Pure. Which tools this browser answers itself, and what they look like on the
// wire.
//
// The assistant's tools come from two places and the split is the whole design.
// Everything *grammatical* — the guide, the catalogue, validation, the data-flow
// analysis, the share link — is the MCP server's, reached over /mcp, because that
// server already answers those questions by importing this app's own compiled core:
// a second implementation here could disagree with the app about what a directive
// means, which is precisely the failure `mcp/server.mjs` exists to make impossible.
//
// What the MCP server cannot answer is anything about *this browser*. It custodies
// nothing, opens no channel to anybody's gallery, and that is deliberate — so the
// four tools that read and write the apps stored here are answered locally, by the
// panel, against IndexedDB. `isLocal` is the only place that split is written down.

let listApps = "reactive_list_apps"
let readApp = "reactive_read_app"
let createApp = "reactive_create_app"
let editApp = "reactive_edit_app"

let local = [listApps, readApp, createApp, editApp]

let isLocal = name => local->Array.includes(name)

/** The four local tools as OpenAI function declarations. The MCP server's own tools
    are converted from the JSON Schema it publishes; these are written out because
    they exist nowhere else.

    The descriptions are in English and addressed to the model, exactly as the MCP
    server's are — they are not interface text and are not translated. */
let declarations: array<JSON.t> = %raw(`[
  {
    type: "function",
    function: {
      name: "reactive_list_apps",
      description:
        "The apps stored in this browser's gallery: id, title and description of each. " +
        "Call it before creating an app the user refers to as an existing one, and " +
        "before choosing an id.",
      parameters: { type: "object", properties: {}, additionalProperties: false },
    },
  },
  {
    type: "function",
    function: {
      name: "reactive_read_app",
      description:
        "The complete Markdown source of an app stored here, frontmatter included. " +
        "With no id it reads the app currently open. ALWAYS read an app before " +
        "proposing an edit to it: reactive_edit_app replaces the whole document, so " +
        "anything you did not carry across is deleted.",
      parameters: {
        type: "object",
        properties: {
          id: {
            type: "string",
            description: "The app's id. Omit for the app the user currently has open.",
          },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "reactive_create_app",
      description:
        "Creates a NEW app in this browser's gallery from a complete Markdown document. " +
        "THIS IS THE STEP THAT GIVES THE USER THEIR APP — call it as soon as you have a " +
        "complete document; do not stop after researching, and do not ask permission " +
        "first. It validates the document itself and REFUSES anything that does not " +
        "pass, handing back the problems with line numbers, so you do not need to be " +
        "certain before calling it: when it refuses, fix what it reports and call it " +
        "again straight away. It never overwrites — a document whose appId is already " +
        "in use lands as a copy under a free id.",
      parameters: {
        type: "object",
        properties: {
          markdown: {
            type: "string",
            description:
              "The complete document, frontmatter included, unfenced. Not a fragment: " +
              "what you pass here is stored verbatim as the whole app.",
          },
        },
        required: ["markdown"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "reactive_edit_app",
      description:
        "Proposes a rewrite of an app stored in this browser — the one the user has " +
        "open when id is omitted, or any app by its id (find ids with " +
        "reactive_list_apps). The rewrite is not applied: it is shown to the user with " +
        "a diff, and they apply or discard it — so say in your reply what you changed. " +
        "Pass the COMPLETE new document, not a patch: anything you leave out is " +
        "deleted, so ALWAYS reactive_read_app first and carry everything else across. " +
        "The appId is kept as it is: an edit never moves an app.",
      parameters: {
        type: "object",
        properties: {
          markdown: {
            type: "string",
            description: "The complete new document, frontmatter included, unfenced.",
          },
          id: {
            type: "string",
            description: "The app to rewrite. Omit for the app the user currently has open.",
          },
          note: {
            type: "string",
            description: "One line naming what changed, shown to the user beside the proposal.",
          },
        },
        required: ["markdown"],
        additionalProperties: false,
      },
    },
  },
]`)
