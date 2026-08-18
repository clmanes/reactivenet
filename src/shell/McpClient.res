// The MCP server, spoken to from the browser. Plain fetch, no SDK — the same
// argument ShareServer makes: a client library earns its place when there are
// sessions, retries and subscriptions, and here there are two calls.
//
// `mcp/server.mjs` runs the Streamable HTTP transport STATELESS: every request gets
// a fresh server, so there is no session to open, no `initialize` handshake to keep
// and no `mcp-session-id` to carry. What the transport does do is answer in SSE
// framing even for a single request — `event: message` and a `data:` line — so the
// body is read whole and the last `data:` line is the answer. A streaming parser
// would buy nothing: one request, one response, and the stream closes behind it.
//
// It is reached as `/mcp` on this app's own origin, exactly as `/pb` and `/od` are:
// the proxy answers in dev and preview, a rewrite in production, and `connect-src
// 'self'` keeps holding. Reaching http://localhost:8789 directly would be both a
// cross-origin request and a blocked one.
//
// Every failure is `ok: false` with a sentence, never an exception. There is one
// failure that matters and it is the ordinary one — the server is not running — and
// the panel says so rather than pretending the assistant has tools it does not.

type tool = {
  name: string,
  description: string,
  /** The JSON Schema the server publishes for the tool's arguments. */
  schema: JSON.t,
}

type answer = {ok: bool, text: string}

/** POSTs one JSON-RPC request and gives back the parsed `result`, or nothing.
    Shared by both calls below; the SSE unwrapping lives here alone. */
let request: (string, JSON.t) => promise<Nullable.t<JSON.t>> = %raw(`
async function (method, params) {
  try {
    const response = await fetch("/mcp", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // Both, because the transport chooses its framing from this header and
        // refuses a request that accepts neither.
        Accept: "application/json, text/event-stream",
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params: params || {} }),
    });
    if (!response.ok) return null;
    const body = await response.text();
    // Either framing: a bare JSON body, or SSE where the answer is the last data line.
    const payload = body.trimStart().startsWith("{")
      ? body
      : body
          .split("\n")
          .filter(line => line.startsWith("data:"))
          .map(line => line.slice(5).trim())
          .pop();
    if (!payload) return null;
    const message = JSON.parse(payload);
    return message && message.result !== undefined ? message.result : null;
  } catch (error) {
    return null;
  }
}
`)

let noParams: JSON.t = %raw(`{}`)

let toolsOf: Nullable.t<JSON.t> => array<tool> = %raw(`
function (result) {
  if (!result || !Array.isArray(result.tools)) return [];
  return result.tools.map(tool => ({
    name: String(tool.name || ""),
    description: String(tool.description || ""),
    schema: tool.inputSchema || { type: "object", properties: {} },
  }));
}
`)

let tools = () => request("tools/list", noParams)->Promise.thenResolve(toolsOf)

/** The model wrote the arguments, so they are not necessarily JSON at all. Nothing
    is None: an unparseable list is a mistake the model can correct, and it can only
    correct what it is told — the sentence goes back as the tool's own answer. */
let callParams: (~name: string, ~arguments: string) => option<JSON.t> = %raw(`
function (name, argumentsJson) {
  try {
    return { name, arguments: argumentsJson ? JSON.parse(argumentsJson) : {} };
  } catch (error) {
    return undefined;
  }
}
`)

let answerOf: Nullable.t<JSON.t> => answer = %raw(`
function (result) {
  if (!result)
    return {
      ok: false,
      text:
        "The ReactiveNET documentation server did not answer. It may not be running: " +
        "the user can start it with 'bun run mcp'. Do not guess the answer this tool would have given.",
    };
  const text = Array.isArray(result.content)
    ? result.content.filter(part => part && part.type === "text").map(part => part.text).join("\n")
    : "";
  return { ok: !result.isError, text: text || "(the tool answered with nothing)" };
}
`)

let call = (~name, ~arguments) =>
  switch callParams(~name, ~arguments) {
  | None =>
    Promise.resolve({
      ok: false,
      text: "The arguments were not valid JSON. Send them again as a JSON object.",
    })
  | Some(params) => request("tools/call", params)->Promise.thenResolve(answerOf)
  }

/** The server's tools as OpenAI function declarations. The schema it publishes is
    already JSON Schema, which is what the `parameters` field wants, so this is a
    rename and nothing more — deliberately: a translation step here would be a place
    for the two descriptions of one tool to drift apart. */
let declarations: array<tool> => array<JSON.t> = %raw(`
function (tools) {
  return tools.map(tool => ({
    type: "function",
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.schema,
    },
  }));
}
`)
