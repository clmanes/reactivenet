// Pure. What the assistant needs before it can say anything, and what is wrong when
// it cannot say it.
//
// There is no account here and no server of ours in the middle: the key is the
// user's own, the browser calls the provider directly, and the settings are
// therefore three plain strings rather than a session.
//
// `baseUrl` takes two shapes, and which one it is decides everything else:
//
//   - an **https** URL is a provider somewhere else — OpenAI, or any of the several
//     services that speak the same wire format. It needs a key, and it is a third
//     party this app contacts, which is why it is named in the privacy policy.
//   - **http on the loopback host** is a model running on this machine: Ollama on
//     11434, or whatever else is listening. It needs no key, and nothing leaves the
//     computer.
//
// The second is the reason `connect-src` grants `http://localhost:*` and
// `http://127.0.0.1:*` — a real widening of the policy, and a deliberate one: the
// alternative was to proxy the daemon through this app's own origin, which works
// only where this app is served by something that can proxy, i.e. not on the static
// hosts it is built for. The grant is bounded to the loopback host, which is the one
// place a browser will not carry a request off the machine. Anything else in http is
// refused here rather than by the policy, which would block it with an error in the
// console at a moment when the person is looking at a chat that will not answer.

type t = {key: string, model: string, baseUrl: string}

// Named rather than derived: a wrong model name comes back from the provider as a
// 404 with its own sentence, which is a better error than anything guessed here.
let defaultModel = "gpt-4.1"
let hostedBaseUrl = "https://api.openai.com/v1"

/** Ollama's own default, spoken to directly. */
let localBaseUrl = "http://localhost:11434/v1"

/** Only a starting point: which models exist is asked of the daemon, because a name
    typed from memory is the commonest way this ends in a 404. */
let defaultLocalModel = "qwen3.5:4b"

let blank = {key: "", model: defaultModel, baseUrl: hostedBaseUrl}

let onOllama = {key: "", model: defaultLocalModel, baseUrl: localBaseUrl}

let trimSlashes = url => url->String.replaceRegExp(%re("/\/+$/"), "")

// Empty means "whatever the default is", for both fields that have one: a settings
// form the user cleared should go back to working, not stop working.
let normalize = settings => {
  key: settings.key->String.trim,
  model: switch settings.model->String.trim {
  | "" => defaultModel
  | model => model
  },
  baseUrl: switch settings.baseUrl->String.trim->trimSlashes {
  | "" => hostedBaseUrl
  | url => url
  },
}

// The loopback host, on any port. Exactly the two spellings `connect-src` grants and
// no more: CSP's host grammar has no way to write an IPv6 literal, so accepting
// `http://[::1]` here would accept an endpoint the policy then blocks — which is the
// failure with no explanation that this check exists to prevent. Anything else in
// http is another machine on a network somebody else may be on.
let loopback = %re("/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?(\/|$)/")

/** Whether the endpoint is a model on this machine. Nothing is sent anywhere, and no
    key is asked for. */
let isLocal = settings => loopback->RegExp.test(normalize(settings).baseUrl)

type problem =
  | NoKey
  | NotHttps

let check = settings => {
  let normalized = normalize(settings)
  if loopback->RegExp.test(normalized.baseUrl) {
    // A model on this machine authenticates nobody: asking for a key here would be
    // asking for a secret that does not exist.
    None
  } else if !(normalized.baseUrl->String.startsWith("https://")) {
    NotHttps->Some
  } else if normalized.key == "" {
    NoKey->Some
  } else {
    None
  }
}

let isReady = settings => check(settings) == None

/** The endpoint a remote provider is called at. Chat Completions rather than the
    newer Responses API because it is the shape every OpenAI-compatible provider
    speaks, and an endpoint that can be changed is worth nothing if only one host
    answers at it. */
let completionsUrl = settings => normalize(settings).baseUrl ++ "/chat/completions"

/** The endpoint a local model is called at: Ollama's own `/api/chat`, beside the
    `/v1` layer rather than under it. The native protocol is not a preference but a
    measured one: benched over the same models and tasks (`scripts/bench-assistant`),
    the OpenAI-compat layer 500s when its tool-call parser meets a malformed call —
    two or three runs in every twelve — while the native path had zero errors and
    took the 27B and 35B models to full scores. */
let nativeChatUrl = settings =>
  normalize(settings).baseUrl->String.replaceRegExp(%re("/\/v1$/"), "") ++ "/api/chat"

// ---------------------------------------------------------------- embeddings
//
// Semantic search needs vectors, and vectors need a model of their own — a chat
// model cannot produce them. The default is the smallest one that is actually good
// at this: **Qwen3-Embedding-0.6B**, about 600 MB, which runs on any laptop that
// already runs a chat model and is what `::ai-search` and `rag=` index with.
//
// It is not a setting. One more field in this record is one more thing to get wrong
// in a form, and the choice only has two honest answers: the small local model
// everywhere, and OpenAI's own where the endpoint is OpenAI's own — because that is
// the one host that will not serve Qwen whatever you ask it for. An endpoint that
// is neither (vLLM, SGLang, an OpenAI-compatible gateway) is asked for Qwen, which
// is what such a deployment would be serving.

let defaultEmbedModel = "qwen3-embedding:0.6b"

let hostedEmbedModel = "text-embedding-3-small"

let embedModel = settings =>
  normalize(settings).baseUrl->String.includes("api.openai.com")
    ? hostedEmbedModel
    : defaultEmbedModel

/** Where vectors are asked for: Ollama's native `/api/embed` for a model on this
    machine, the OpenAI-compatible `/embeddings` for everything else. */
let embeddingsUrl = settings =>
  isLocal(settings)
    ? normalize(settings).baseUrl->String.replaceRegExp(%re("/\/v1$/"), "") ++ "/api/embed"
    : normalize(settings).baseUrl ++ "/embeddings"
