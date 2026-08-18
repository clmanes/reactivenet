// One call to a provider that speaks the OpenAI Chat Completions wire format:
// OpenAI itself, or Ollama on this machine, or anything else the endpoint points at.
// Plain fetch and a hand-written SSE reader, for the reason ShareServer gives — and
// one more: the official SDK is written for a server, warns loudly about running in
// a browser with a key, and would add a megabyte to do what forty lines do here.
//
// Three details decide whether this works at all:
//
//   - **The request carries no `temperature` and no token ceiling.** Not laziness:
//     the newer OpenAI models refuse a `temperature` other than 1 and renamed
//     `max_tokens`, so a request that sets either works on one model and fails on
//     another. Sending neither works everywhere, provider defaults and all.
//   - **Tool call fragments are accumulated by index.** OpenAI streams a call across
//     many deltas — the name in the first, the arguments a few characters at a time;
//     Ollama sends the whole call in one. Concatenating per index is the shape that
//     reads both, and it is why the arguments stay a string here rather than parsed
//     JSON: half a JSON object does not parse.
//   - **`reasoning` is not `content`.** A thinking model streams its reasoning in its
//     own field and stays silent in `content` for as long as it takes — a minute is
//     ordinary for a local one. Shown as the answer it would be nonsense; dropped,
//     the panel sits still looking broken. It goes to its own callback.

/** An AbortController, and its signal. They are here rather than in the panel
    because this is the module that hands the signal to `fetch`: stopping a stream is
    the client's own vocabulary, not something a component should have to know how
    to spell. */
type controller

type signal

let controller: unit => controller = %raw(`function () { return new AbortController(); }`)

let signalOf: controller => signal = %raw(`function (controller) { return controller.signal; }`)

let abort: controller => unit = %raw(`function (controller) { controller.abort(); }`)

type call = {
  id: string,
  name: string,
  /** The arguments as the model wrote them: a JSON string, not necessarily valid. */
  arguments: string,
}

type reply = {
  ok: bool,
  /** The provider's own words when something went wrong; empty when nothing did —
      and empty on a stop, which is not a failure the user needs told about. */
  error: string,
  text: string,
  calls: array<call>,
  /** The assistant message exactly as it must go back into the history — tool calls
      included, or the next request refers to calls the model never made. */
  message: JSON.t,
}

// The URL, key and model are worked out in ReScript and passed in, deliberately: a
// %raw block that called AiSettings itself would compile to a reference with no
// import behind it, because types are erased and nothing else would have named the
// module. It is a ReferenceError at runtime and nothing at all at compile time.
let send: (
  ~url: string,
  ~key: string,
  ~model: string,
  ~messages: array<JSON.t>,
  ~tools: array<JSON.t>,
  ~onText: string => unit,
  ~onThinking: string => unit,
  ~signal: option<signal>,
) => promise<reply> = %raw(`
async function (url, key, model, messages, tools, onText, onThinking, signal) {
  const failure = message => ({ ok: false, error: message, text: "", calls: [], message: null });
  let response;
  try {
    const headers = { "Content-Type": "application/json" };
    // No key, no header: the local model authenticates nobody, and an empty bearer
    // token is a 401 waiting to happen at a provider that does.
    if (key) headers.Authorization = "Bearer " + key;
    response = await fetch(url, {
      method: "POST",
      headers,
      signal: signal || undefined,
      body: JSON.stringify({
        model,
        stream: true,
        messages,
        ...(tools.length ? { tools } : {}),
      }),
    });
  } catch (error) {
    if (error && error.name === "AbortError") return failure("");
    return failure(String((error && error.message) || error));
  }

  if (!response.ok || !response.body) {
    // The provider's own sentence, when it sent one: "model not found" and "incorrect
    // api key" are the two failures that actually happen, and both are actionable
    // only if they are repeated verbatim.
    let detail = "";
    try {
      const body = await response.text();
      const parsed = JSON.parse(body);
      detail = (parsed && parsed.error && (parsed.error.message || parsed.error)) || body;
    } catch (error) {
      detail = "";
    }
    return failure("HTTP " + response.status + (detail ? ": " + String(detail).slice(0, 400) : ""));
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let text = "";
  const calls = [];

  const consume = payload => {
    if (payload === "[DONE]") return;
    let chunk;
    try {
      chunk = JSON.parse(payload);
    } catch (error) {
      return;
    }
    const choice = chunk.choices && chunk.choices[0];
    const delta = (choice && choice.delta) || {};
    if (delta.content) {
      text += delta.content;
      onText(delta.content);
    }
    // Two spellings of the same thing across providers, neither of them the answer.
    const thinking = delta.reasoning || delta.reasoning_content;
    if (thinking) onThinking(thinking);
    if (Array.isArray(delta.tool_calls)) {
      for (const fragment of delta.tool_calls) {
        const index = typeof fragment.index === "number" ? fragment.index : 0;
        if (!calls[index]) calls[index] = { id: "", name: "", arguments: "" };
        const slot = calls[index];
        if (fragment.id) slot.id = fragment.id;
        const fn = fragment.function || {};
        if (fn.name) slot.name += fn.name;
        if (fn.arguments) slot.arguments += fn.arguments;
      }
    }
  };

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      // A chunk can end mid-line, so only whole lines are consumed and the tail
      // stays in the buffer for the next read.
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith("data:")) consume(trimmed.slice(5).trim());
      }
    }
  } catch (error) {
    // Stopping is not a failure: the person asked for it and already knows.
    if (error && error.name === "AbortError") return failure("");
    return failure(String((error && error.message) || error));
  }

  // The id is settled here, once, for both the calls handed to the caller and the
  // calls written into the message: a tool result is matched to its call by that id,
  // and a provider that streams none would otherwise get one spelling in the history
  // and another in the answer.
  const made = calls
    .filter(Boolean)
    .filter(call => call.name)
    .map((call, index) => ({ ...call, id: call.id || "call_" + index }));
  return {
    ok: true,
    error: "",
    text,
    calls: made,
    message: {
      role: "assistant",
      content: text,
      ...(made.length
        ? {
            tool_calls: made.map(call => ({
              id: call.id,
              type: "function",
              function: { name: call.name, arguments: call.arguments || "{}" },
            })),
          }
        : {}),
    },
  };
}
`)

// Ollama's native /api/chat, spoken to a local model instead of the /v1 compat
// layer. Not a preference — a measurement: over the same models and tasks the
// compat layer 500s when its tool-call parser meets a malformed sample (two or
// three runs in every twelve), while the native path had zero errors and lifted
// every model (`scripts/bench-assistant.mjs`, BENCH_NATIVE=1). The wire differs in
// four ways this function absorbs so nothing outside can tell the two apart:
//
//   - the stream is NDJSON — one bare JSON object per line, no `data:` prefix and
//     no [DONE]; the final line says `done: true`.
//   - `thinking` is its own field on the message, not a delta spelling.
//   - a tool call arrives WHOLE in one chunk, with `arguments` already an object.
//     The contract upstream is "arguments is the string the model wrote", so it is
//     re-serialised here — dispatch parses it back, and that indirection is the
//     price of one contract instead of two.
//   - the assistant message echoed into history must carry the calls in native
//     shape (object arguments), or the next request's template rendering breaks.
let sendNative: (
  ~url: string,
  ~model: string,
  ~messages: array<JSON.t>,
  ~tools: array<JSON.t>,
  ~onText: string => unit,
  ~onThinking: string => unit,
  ~signal: option<signal>,
) => promise<reply> = %raw(`
async function (url, model, messages, tools, onText, onThinking, signal) {
  const failure = message => ({ ok: false, error: message, text: "", calls: [], message: null });
  let response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: signal || undefined,
      body: JSON.stringify({
        model,
        stream: true,
        messages,
        ...(tools.length ? { tools } : {}),
      }),
    });
  } catch (error) {
    if (error && error.name === "AbortError") return failure("");
    return failure(String((error && error.message) || error));
  }

  if (!response.ok || !response.body) {
    let detail = "";
    try {
      const body = await response.text();
      const parsed = JSON.parse(body);
      detail = (parsed && parsed.error) || body;
    } catch (error) {
      detail = "";
    }
    return failure("HTTP " + response.status + (detail ? ": " + String(detail).slice(0, 400) : ""));
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let text = "";
  const nativeCalls = [];

  const consume = payload => {
    let chunk;
    try {
      chunk = JSON.parse(payload);
    } catch (error) {
      return;
    }
    const message = chunk.message || {};
    if (message.content) {
      text += message.content;
      onText(message.content);
    }
    if (message.thinking) onThinking(message.thinking);
    if (Array.isArray(message.tool_calls)) nativeCalls.push(...message.tool_calls);
  };

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed) consume(trimmed);
      }
    }
  } catch (error) {
    if (error && error.name === "AbortError") return failure("");
    return failure(String((error && error.message) || error));
  }
  if (buffer.trim()) consume(buffer.trim());

  const made = nativeCalls
    .filter(call => call && call.function && call.function.name)
    .map((call, index) => ({
      id: call.id || "call_" + index,
      name: call.function.name,
      arguments: JSON.stringify(call.function.arguments || {}),
    }));
  return {
    ok: true,
    error: "",
    text,
    calls: made,
    message: {
      role: "assistant",
      content: text,
      ...(nativeCalls.length ? { tool_calls: nativeCalls } : {}),
    },
  };
}
`)

// The bool is worked out in ReScript and passed in — the same %raw-cannot-see-
// modules rule as `send` above.
let toolMessageRaw: (bool, string, string, string) => JSON.t = %raw(`
function (native, id, name, text) {
  return native
    ? { role: "tool", tool_name: name, content: text }
    : { role: "tool", tool_call_id: id, content: text };
}
`)

/** The tool-result message, in the shape the wire this conversation runs on
    expects. It lives here and not in the agent because it is protocol: the OpenAI
    format matches a result to its call by `tool_call_id`, Ollama's native template
    renders it by `tool_name`, and the loop should not know there are two. */
let toolMessage = (~settings, ~id, ~name, ~text) =>
  toolMessageRaw(AiSettings.isLocal(settings), id, name, text)

let complete = (
  ~settings: AiSettings.t,
  ~messages,
  ~tools,
  ~onText,
  ~onThinking,
  ~signal,
) => {
  let normalized = AiSettings.normalize(settings)
  AiSettings.isLocal(settings)
    ? sendNative(
        ~url=AiSettings.nativeChatUrl(settings),
        ~model=normalized.model,
        ~messages,
        ~tools,
        ~onText,
        ~onThinking,
        ~signal,
      )
    : send(
        ~url=AiSettings.completionsUrl(settings),
        ~key=normalized.key,
        ~model=normalized.model,
        ~messages,
        ~tools,
        ~onText,
        ~onThinking,
        ~signal,
      )
}
