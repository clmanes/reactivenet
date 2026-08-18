/** One streamed call to a provider speaking the OpenAI Chat Completions format —
    OpenAI, Ollama on this machine, or whatever the endpoint points at. Plain fetch:
    the official SDK is written for a server, warns about running in a browser with a
    key, and would add a megabyte to do this.

    The request deliberately sets no `temperature` and no token ceiling, because the
    spellings of both differ between models and sending neither works everywhere. */

type controller

type signal

let controller: unit => controller

let signalOf: controller => signal

let abort: controller => unit

type call = {
  id: string,
  name: string,
  /** The arguments as the model wrote them: a JSON string, not necessarily valid. */
  arguments: string,
}

type reply = {
  ok: bool,
  /** The provider's own words when something went wrong; empty when nothing did, and
      empty on a stop, which is not a failure anybody needs told about. */
  error: string,
  text: string,
  calls: array<call>,
  /** The assistant message as it must go back into the history — tool calls
      included, or the next request refers to calls the model never made. */
  message: JSON.t,
}

/** The tool-result message in the shape this conversation's wire expects: the
    OpenAI format matches a result to its call by `tool_call_id`, Ollama's native
    template renders it by `tool_name` — and the agent loop should not know there
    are two. */
let toolMessage: (~settings: AiSettings.t, ~id: string, ~name: string, ~text: string) => JSON.t

/** Streams one completion — Ollama's native `/api/chat` for a local endpoint
    (measurably more reliable with tools than the compat layer), Chat Completions
    for everything else. `onText` receives the answer as it arrives; `onThinking`
    receives a thinking model's reasoning, which is a different thing and must never
    be shown as the answer. */
let complete: (
  ~settings: AiSettings.t,
  ~messages: array<JSON.t>,
  ~tools: array<JSON.t>,
  ~onText: string => unit,
  ~onThinking: string => unit,
  ~signal: option<signal>,
) => promise<reply>
