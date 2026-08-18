/** The loop: ask the model, run the tools it asks for, ask again, until it answers
    without asking for anything.

    It knows nothing about apps. `dispatch` is handed a tool name and the model's own
    argument string and gives back whatever the model should be told, which is what
    makes the MCP server's grammatical tools and the browser's own gallery tools the
    same shape from inside the loop. */

type turn = {
  /** "user" | "assistant" | "tool" | "error" | "created" | "proposal" */
  role: string,
  text: string,
  /** The app a "created" or "proposal" turn is about; empty for every other turn. */
  app: string,
}

type outcome = {
  ok: bool,
  /** The provider's own words; empty when nothing failed and when the person
      stopped it. */
  error: string,
  /** The loop hit its own ceiling with the model still asking for tools — this
      app's sentence to say, not the provider's. */
  stalled: bool,
  history: array<JSON.t>,
}

/** How many model turns one question may take, and no further: every extra turn is a
    paid request or a minute of somebody's laptop. Sized for the long run rather than
    the ordinary one — a refused delivery sends the model back to the catalogue before
    it writes the document again, and an app over open data now owes a `reactive_od_query`
    per SELECT, which for a dashboard of a dozen figures is a dozen turns before a line
    of the document is written. Past this the model is not converging and more turns
    only buy a more expensive way to fail.

    The cost is not linear: the run's own messages are never compacted — `AiHistory`
    only touches what a run INHERITS — so every turn re-sends all the turns before it,
    and a run near this ceiling is what will meet a small model's context window
    first. */
let maxSteps: int

let run: (
  ~settings: AiSettings.t,
  ~system: string,
  ~history: array<JSON.t>,
  ~question: string,
  ~tools: array<JSON.t>,
  ~onText: string => unit,
  ~onThinking: string => unit,
  ~onCall: (~name: string, ~arguments: string) => unit,
  ~dispatch: (~name: string, ~arguments: string) => promise<string>,
  ~signal: option<OpenAiClient.signal>,
) => promise<outcome>
