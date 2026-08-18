/** The one place an ai-* directive talks to a model — the same model, on the same
    wire, as the assistant in the navbar. Where the data goes is a property of the
    endpoint (`AiSettings.isLocal`), not of the directive. */

type outcome = {ok: bool, error: string, text: string}

/** Whether a model is configured at all. `error: "not-configured"` is what every
    call answers when it is not, and the binders draw one banner for it. */
let ready: unit => promise<bool>

let isLocal: unit => promise<bool>

/** One question, one answer. `images` are data URLs, carried the way the configured
    wire carries them. */
let ask: (~system: string, ~user: string, ~images: array<string>=?) => promise<outcome>

/** The same, painted as it arrives — for the chat directives, where a still screen
    reads as a failure. */
let stream: (
  ~system: string,
  ~history: array<JSON.t>,
  ~user: string,
  ~onText: string => unit,
) => promise<outcome>

/** The assistant's own loop with the tools a document declared. Answers the outcome
    and the history to keep for the next question. */
let agent: (
  ~system: string,
  ~history: array<JSON.t>,
  ~question: string,
  ~tools: array<JSON.t>,
  ~onText: string => unit,
  ~onCall: (~name: string, ~arguments: string) => unit,
  ~dispatch: (~name: string, ~arguments: string) => promise<string>,
) => promise<(outcome, array<JSON.t>)>

/** Normalised vectors for a batch of passages, or nothing when the endpoint has no
    embedding model — in which case semantic search is simply not available, which
    `::ai-search` says in one sentence rather than as an error. */
let embed: array<string> => promise<option<array<array<float>>>>
