# ReactiveNET's MCP server

A connector that lets Claude **write ReactiveNET apps and check them before
delivering**. The user describes the app in words; Claude builds it consulting
the documentation and the directive catalogue, validates it against the app's
own grammar, and hands back a **share link**: opening it adds the app to the
user's gallery, through the same never-overwrite road an app shared between
users takes.

Nothing to install on the user's side: the server is remote and is added to
Claude by pasting a URL.

## What it does (and deliberately does not)

Five tools, all **pure functions**, all marked read-only:

| Tool | What for |
|---|---|
| `reactive_guide` | The documentation under `doc/`, served a section at a time (whole: ~100 KB — pouring it into a conversation would waste the model's context) |
| `reactive_directives` | The 115 directives — ReactiveNET's own plus the generated Spectrum set — with form, typed attributes and a snippet built by the app's own `DirectiveScan.render` |
| `reactive_examples` | Two complete working documents: the welcome app (one of every kind of directive, in any of the seven languages) and the blank starter |
| `reactive_validate` | Checks the document with the compiled core and reports every problem **with its line number** |
| `reactive_app_link` | Validates and produces the `/s#…` share link; refuses to build one for a document that does not validate |

It **never** touches user data, opens no channel to any browser, writes
nothing to disk and keeps no sessions. That is why it can sit on the open
Internet without authentication: it custodies nothing. The only thing to
protect is the availability of the service.

## Why the answers can be trusted

Every grammatical question is answered by importing the **app's own compiled
core** (`src/**/*.res.mjs`): the same scanner (`DirectiveScan`), the same
registry (`DirectiveRegistry`), the same quote-aware attribute parser
(`DirectiveAttributes`), the same link codec (`ShareLink` + `SharePayload`).
There is no second implementation to drift. `bun run res:build` first — and
the server runs under **bun**, like everything in this repo.

The real value is `reactive_validate`. Beyond the grammar (unknown directives,
attribute types, Choice values, closes that close nothing — checked
recursively through container bodies, the way the renderer reads them), it
knows the traps that *validate and then betray at runtime*:

- a field or a save with **no form around it** (and `form="id"` opts out,
  exactly as in the app);
- `:value` bound to a **bare store key** — the view that never updates;
- a `:calc` expression that does not parse;
- a **hex colour** read as a `#reference` and silently dropped;
- `::grid`, described by the manifests and never shipped;
- an overlay written `open`, which freezes the whole app;
- `::switch` / `::search`, which store nothing (advice, with the controls
  that actually do).

## The link ceiling

`reactive_app_link` refuses payloads past `ShareLink.ceiling` — the same
constant the app enforces — because messaging channels truncate long URLs and
a truncated link would import half a document. Past the ceiling the tool says
so and suggests splitting the app or delivering the `.md` to import from the
gallery.

## Development

```sh
bun run mcp                 # http://localhost:8789/mcp  (health on /health)
bun scripts/test-mcp.mjs    # smoke test: starts a real server, talks MCP to it
```

Environment (with defaults): `MCP_PORT` (8789), `MCP_APP_URL`
(`http://localhost:5173`) — the origin the share links point at.

The app itself is one of the clients. ReactiveNET's own assistant panel talks to
this server over `/mcp` on the app's origin — the Vite proxy in dev and preview,
a host rewrite in production — and answers four tools of its own about the
browser's gallery, which this server cannot know anything about. Two
consequences when editing here: the assistant reads the leading `ok` of
`reactive_validate`'s report to decide whether an app may be written at all, so
that wording is a contract (`core/AiPlan.validates`, and the assertion in
`scripts/test-mcp.mjs`); and a browser client preflights, which is why the CORS
headers exist even though Claude's connector calls server-to-server.

The transport is Streamable HTTP, **stateless**: no tool has state, so every
request gets a fresh server+transport pair while the guide and catalogue stay
shared at module level. Statelessness is also what lets a plain `fetch` be a
client: there is no `initialize` handshake to keep and no session id to carry. Validation results are memoised (the usual
conversation validates, fixes, then links the same text).
