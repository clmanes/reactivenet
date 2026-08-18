/** The MCP server (`mcp/server.mjs`), spoken to from the browser over `/mcp` on this
    app's own origin — the arrangement `/pb` and `/od` already use, so `connect-src
    'self'` keeps holding.

    Plain fetch: the transport runs stateless, so there is no handshake to keep and
    no session to carry, and one request gets one answer. Every failure is
    `ok: false` with a sentence the model can act on; the ordinary one is that the
    server is not running. */

type tool = {
  name: string,
  description: string,
  /** The JSON Schema the server publishes for the tool's arguments. */
  schema: JSON.t,
}

type answer = {ok: bool, text: string}

/** Every tool the server offers, or an empty list when it does not answer. */
let tools: unit => promise<array<tool>>

/** Calls one tool. `arguments` is the JSON string the model produced, passed on
    unchanged — an unparseable one comes back as the tool's own complaint. */
let call: (~name: string, ~arguments: string) => promise<answer>

/** The server's tools as OpenAI function declarations: a rename of what it already
    publishes, never a second description that could drift from it. */
let declarations: array<tool> => array<JSON.t>
