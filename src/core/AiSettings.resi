/** Pure. The three strings the assistant needs — a key, a model, and an endpoint
    that speaks the OpenAI wire format — and what is wrong when one of them is
    missing.

    The endpoint takes two shapes. An https URL is a provider somewhere else: it needs
    a key and it is a third party this app contacts. http on the loopback host is a
    model running on this machine — Ollama, or anything else listening there: no key,
    and nothing leaves the computer. That second shape is why `connect-src` grants
    `http://localhost:*`. Any other http endpoint is refused here rather than by the
    policy, which would block it with no explanation anywhere near the form that
    caused it. */

type t = {key: string, model: string, baseUrl: string}

let defaultModel: string

/** OpenAI's own endpoint. */
let hostedBaseUrl: string

/** Ollama's own default, spoken to directly. */
let localBaseUrl: string

let defaultLocalModel: string

/** The remote provider, with no key yet. */
let blank: t

/** A model on this machine, which needs no key. */
let onOllama: t

/** Trims, and reads an empty model or endpoint as "the default" rather than as a
    setting that stops the assistant working. */
let normalize: t => t

/** Whether the endpoint is a model on this machine — the loopback host, on any port
    — which sends nothing anywhere and needs no key. */
let isLocal: t => bool

type problem =
  | NoKey
  /** The endpoint is neither https nor http on the loopback host, so `connect-src`
      would block it. */
  | NotHttps

let check: t => option<problem>

let isReady: t => bool

/** The Chat Completions endpoint a remote provider is called at: the shape every
    OpenAI-compatible provider speaks, which is what makes a changeable endpoint
    worth having. */
let completionsUrl: t => string

/** Ollama's native `/api/chat`, used for local endpoints instead of the `/v1`
    layer: measurably more reliable with tools — the compat layer's parser 500s on
    malformed calls, the native path does not. */
let nativeChatUrl: t => string

/** The embedding model semantic search indexes with. Qwen3-Embedding-0.6B: the
    smallest model that is actually good at this, and deliberately not a setting —
    the choice has two honest answers and the endpoint decides between them. */
let defaultEmbedModel: string

/** OpenAI's own, used only where the endpoint is OpenAI's own: it is the one host
    that will not serve Qwen whatever you ask it for. */
let hostedEmbedModel: string

let embedModel: t => string

/** Ollama's native `/api/embed` for a model on this machine, the OpenAI-compatible
    `/embeddings` for everything else. */
let embeddingsUrl: t => string
