// One place where an ai-* directive talks to a model, so that every one of them
// talks to the SAME model — the one configured once in the assistant's settings.
//
// Three things follow from that and are the whole point of the module:
//
//   - **"Is it configured" is a question with one answer.** A document full of
//     ai-* directives on a browser with no model must say so once, calmly, and keep
//     working; each directive asking the question its own way would give a page of
//     different-looking failures for one missing setting.
//   - **The wire is the assistant's wire.** `OpenAiClient` already speaks Ollama's
//     native chat for a local endpoint and Chat Completions for everything else,
//     and already knows that reasoning is not content. None of that is worth a
//     second implementation living in a binder.
//   - **Where the data goes is a property of the endpoint, not of the directive.**
//     A model on this machine sends nothing anywhere; a remote provider receives
//     whatever the directive put in the prompt. `AiSettings.isLocal` is the only
//     place that distinction is decided, and the panel and the privacy policy read
//     the same function.
//
// Nothing here streams. A directive's answer is a category, a plan or a paragraph
// that replaces what was there before, and painting a category one character at a
// time would only make it flicker. The one exception is the chat directives, which
// hand `onText` straight through.

type outcome = {
  ok: bool,
  /** The provider's own words, or this app's when the settings are the problem. */
  error: string,
  text: string,
}

/** Whether a model is configured at all. Every binder asks this before drawing
    anything, and draws the one banner instead when the answer is no. */
let ready = async () => {
  let settings = await AiStore.loadSettings()
  AiSettings.isReady(settings)
}

/** Whether the configured endpoint is a model on this machine. What the directives
    show the reader about where their data goes comes from here. */
let isLocal = async () => {
  let settings = await AiStore.loadSettings()
  AiSettings.isLocal(settings)
}

// An image travels differently on the two wires: Chat Completions carries it as a
// content part, Ollama's native chat as a base64 string beside the text. The seam
// is here rather than in the binder, which must not know there are two wires.
let visionMessage: (~text: string, ~images: array<string>, ~native: bool) => JSON.t = %raw(`
function (text, images, native) {
  if (images.length === 0) return { role: "user", content: text };
  if (native) {
    return {
      role: "user",
      content: text,
      images: images.map((url) => String(url).replace(/^data:[^,]*,/, "")),
    };
  }
  return {
    role: "user",
    content: [
      { type: "text", text },
      ...images.map((url) => ({ type: "image_url", image_url: { url } })),
    ],
  };
}
`)

let systemMessage: string => JSON.t = %raw(`function (text) { return { role: "system", content: text }; }`)

/** One question, one answer. `system` is what the directive is; `user` is what the
    document and the reader put in it. */
let ask = async (~system: string, ~user: string, ~images: array<string>=[]) => {
  let settings = await AiStore.loadSettings()
  if !AiSettings.isReady(settings) {
    {ok: false, error: "not-configured", text: ""}
  } else {
    let native = AiSettings.isLocal(settings)
    let messages = system == ""
      ? [visionMessage(~text=user, ~images, ~native)]
      : [systemMessage(system), visionMessage(~text=user, ~images, ~native)]
    let reply = await OpenAiClient.complete(
      ~settings,
      ~messages,
      ~tools=[],
      ~onText=_ => (),
      ~onThinking=_ => (),
      ~signal=None,
    )
    {ok: reply.ok, error: reply.error, text: reply.text->String.trim}
  }
}

/** The same, streamed: the chat directives paint the answer as it arrives, because
    there a wait with nothing moving reads as a failure. */
let stream = async (~system: string, ~history: array<JSON.t>, ~user: string, ~onText: string => unit) => {
  let settings = await AiStore.loadSettings()
  if !AiSettings.isReady(settings) {
    {ok: false, error: "not-configured", text: ""}
  } else {
    let messages =
      [systemMessage(system)]
      ->Array.concat(history)
      ->Array.concat([visionMessage(~text=user, ~images=[], ~native=false)])
    let reply = await OpenAiClient.complete(
      ~settings,
      ~messages,
      ~tools=[],
      ~onText,
      ~onThinking=_ => (),
      ~signal=None,
    )
    {ok: reply.ok, error: reply.error, text: reply.text->String.trim}
  }
}

/** The agent loop, with the tools the document declared. It is the assistant's own
    loop — `AiAgent.run` — because an agent that behaved differently here would be a
    second agent to keep in step with the first. */
let agent = async (
  ~system: string,
  ~history: array<JSON.t>,
  ~question: string,
  ~tools: array<JSON.t>,
  ~onText: string => unit,
  ~onCall: (~name: string, ~arguments: string) => unit,
  ~dispatch: (~name: string, ~arguments: string) => promise<string>,
) => {
  let settings = await AiStore.loadSettings()
  if !AiSettings.isReady(settings) {
    ({ok: false, error: "not-configured", text: ""}, history)
  } else {
    let result = await AiAgent.run(
      ~settings,
      ~system,
      ~history,
      ~question,
      ~tools,
      ~onText,
      ~onThinking=_ => (),
      ~onCall,
      ~dispatch,
      ~signal=None,
    )
    (
      {
        ok: result.ok,
        error: result.stalled ? "stalled" : result.error,
        text: "",
      },
      result.history,
    )
  }
}

// ---------------------------------------------------------------- embeddings
//
// Vectors, for `::ai-search` and for the `rag=` of the chat directives. A separate
// endpoint and a separate model from everything above — a chat model cannot produce
// them — and the same rule about where the data goes: with a model on this machine
// the passages never leave it, and with a remote provider they are sent exactly as
// a question would be.

let request: (~url: string, ~key: string, ~body: string) => promise<option<JSON.t>> = %raw(`
function (url, key, body) {
  const headers = { "content-type": "application/json" };
  if (key !== "") headers.authorization = "Bearer " + key;
  return fetch(url, { method: "POST", headers, body })
    .then((response) => (response.ok ? response.json() : null))
    .then((json) => (json === null ? undefined : json))
    .catch(() => undefined);
}
`)

// Ollama answers {embeddings: [[...]]}, the OpenAI shape {data: [{embedding: [...]}]}.
// One reading of both, because the caller must not know which wire it is on.
let vectorsOf: JSON.t => array<array<float>> = %raw(`
function (json) {
  if (json === null || typeof json !== "object") return [];
  if (Array.isArray(json.embeddings)) return json.embeddings.filter(Array.isArray);
  if (Array.isArray(json.data)) {
    return json.data.map((entry) => (entry && Array.isArray(entry.embedding) ? entry.embedding : null)).filter(Boolean);
  }
  return [];
}
`)

let body: (~model: string, ~texts: array<string>) => string = %raw(`
function (model, texts) { return JSON.stringify({ model, input: texts }); }
`)

/** Vectors for a batch of passages, normalised, or nothing when the endpoint has no
    embedding model. An empty answer is not an error to shout about: semantic search
    simply is not available, and `::ai-search` says so in one sentence. */
let embed = async (texts: array<string>) => {
  if texts->Array.length == 0 {
    Some([])
  } else {
    let settings = await AiStore.loadSettings()
    if !AiSettings.isReady(settings) {
      None
    } else {
      let answered = await request(
        ~url=AiSettings.embeddingsUrl(settings),
        ~key=AiSettings.isLocal(settings) ? "" : settings.key,
        ~body=body(~model=AiSettings.embedModel(settings), ~texts),
      )
      switch answered {
      | None => None
      | Some(json) =>
        let vectors = vectorsOf(json)
        vectors->Array.length == texts->Array.length
          ? Some(vectors->Array.map(AiIndex.normalise))
          : None
      }
    }
  }
}
