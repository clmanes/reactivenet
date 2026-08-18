// The loop: ask the model, run the tools it asks for, ask it again, until it answers
// without asking for anything. Everything an assistant is, once the streaming and
// the storage are elsewhere.
//
// It knows nothing about apps. Which tools exist and what a call to one *does* are
// both the caller's — `dispatch` is handed a name and the model's own argument
// string and gives back whatever the model should be told. That is what keeps the
// two kinds of tool interchangeable here: the MCP server's grammatical ones and the
// four this browser answers about its own gallery are the same shape from inside the
// loop, and the panel is the one place that knows the difference.
//
// The ceiling is the part worth defending. A model that misreads a tool's answer can
// call it again with the same arguments for ever, and every turn of that loop is a
// paid request to somebody's API or a minute of somebody's laptop. Past it the person
// is told it stopped, rather than being left watching a spinner that will never end.
//
// Thirty-two, and the number comes from watching runs rather than from taste. The
// honest straight run is read the guide → look up three or four directives → write →
// validate → analyse → deliver, which is eight. What needs the rest is a REFUSED
// delivery: a document that does not validate is not written, and a model that has
// just been refused goes back to the catalogue, sometimes several times, before
// writing again — at twelve, a 35B model refused once ran out mid-recovery and then
// *said* it had delivered. Three full recoveries fit in thirty-two, which is as much
// patience as this is worth: past that the model is not converging, and more turns
// only buy a more expensive way to fail.

/** What the panel draws. The roles are strings rather than a variant because these
    are stored as JSON and read back on the next visit: a variant would need an
    encoder and a decoder, and both would have to be kept in step with a shape whose
    only reader is a `switch` in one component. */
type turn = {
  /** "user" | "assistant" | "tool" | "error" | "created" | "proposal" */
  role: string,
  text: string,
  /** The app a "created" or "proposal" turn is about; empty for every other turn. */
  app: string,
}

type outcome = {
  ok: bool,
  /** The provider's own words. Empty when nothing failed, and empty when the person
      stopped it — stopping is not a failure anybody needs told about. */
  error: string,
  /** The loop hit its own ceiling with the model still asking for tools. Kept apart
      from `error` because it is not the provider's failure and it is not the
      provider's sentence: it is this app's, and it has to be translated. */
  stalled: bool,
  /** The wire history including this exchange, to be kept for the next question. */
  history: array<JSON.t>,
}

let maxSteps = 96

let userMessage: string => JSON.t = %raw(`function (text) { return { role: "user", content: text }; }`)

let systemMessage: string => JSON.t = %raw(`function (text) { return { role: "system", content: text }; }`)

// The tool-result message is the client's to build (OpenAiClient.toolMessage):
// its shape depends on which wire the conversation runs on, and this loop is the
// one place that must not know there are two.

let run = async (
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
) => {
  // The inherited history is compacted before the new question joins it: old tool
  // answers and delivery arguments are kilobytes the model no longer needs verbatim
  // (it can call the tool again), and on small local contexts they are what
  // eventually crowds out the conversation itself.
  let wire = ref(AiHistory.compact(history)->Array.concat([userMessage(question)]))
  let failure = ref("")
  let finished = ref(false)
  let steps = ref(0)
  // How many times a silent turn has been nudged, and how many times a 5xx has
  // been retried. One each, per question.
  let nudges = ref(0)
  let retries = ref(0)

  while !finished.contents && steps.contents < maxSteps {
    steps := steps.contents + 1
    let reply = await OpenAiClient.complete(
      // The system prompt is prepended on every request rather than kept in the
      // history: it says which app is open, and which app is open changes while the
      // conversation is still going.
      ~settings,
      ~messages=[systemMessage(system)]->Array.concat(wire.contents),
      ~tools,
      ~onText,
      ~onThinking,
      ~signal,
    )
    if !reply.ok {
      // A 5xx gets one retry before it becomes the answer. It is usually not the
      // provider being down but the provider tripping over one sample: Ollama's
      // tool-call parser 500s on a malformed call ("XML syntax error … element
      // <function> closed by </parameter>"), and the next sample is fine. Two in a
      // row is a real failure and is reported as one. A 4xx is never retried — the
      // request itself is wrong, and the same bytes will fail the same way.
      if reply.error->String.startsWith("HTTP 5") && retries.contents == 0 {
        retries := 1
      } else {
        failure := reply.error
        finished := true
      }
    } else {
      wire := wire.contents->Array.concat([reply.message])
      let calls = reply.calls
      if calls->Array.length == 0 {
        // Two ways a small model stops without having answered, both seen on the
        // bench, both worth exactly one nudge — one, so a model that has genuinely
        // finished is not badgered:
        //
        //   - **Silence.** The thinking models spend the whole turn in the
        //     reasoning channel and emit an empty `content`. Before the nudge a 4B
        //     did this on every task and delivered nothing at all.
        //   - **The document in the chat.** The model writes the whole app —
        //     frontmatter and all — into its reply and stops, satisfied. The user
        //     is shown a wall of markdown and the gallery is unchanged. A reply
        //     carrying `appId:` is a document, not an answer: answers about the
        //     language quote directives, but nobody quotes frontmatter.
        let text = reply.text->String.trim
        let pastedDocument = %re("/^appId:/m")->RegExp.test(reply.text)
        if (text == "" || pastedDocument) && nudges.contents == 0 {
          nudges := 1
          wire :=
            wire.contents->Array.concat([
              userMessage(
                text == ""
                  ? "You ended your turn without saying anything and without calling a tool. If you have enough to write the app, write the complete document now and deliver it with reactive_create_app. If something is genuinely missing, ask one short question."
                  : "You wrote the document into the chat instead of delivering it. A document in a message is not an app in the gallery — the user cannot open it. Call reactive_create_app now with that complete document, then tell the user in one sentence what you built.",
              ),
            ])
        } else {
          finished := true
        }
      } else {
        // Run in order rather than together: a model that writes an app usually
        // validates it in the same breath, and the second call is about the answer
        // to the first often enough that overlapping them buys confusion, not speed.
        for index in 0 to calls->Array.length - 1 {
          switch calls->Array.get(index) {
          | None => ()
          | Some(call) => {
              onCall(~name=call.name, ~arguments=call.arguments)
              let answer = await dispatch(~name=call.name, ~arguments=call.arguments)
              wire :=
                wire.contents->Array.concat([
                  OpenAiClient.toolMessage(~settings, ~id=call.id, ~name=call.name, ~text=answer),
                ])
            }
          }
        }
      }
    }
  }

  {
    ok: failure.contents == "" && finished.contents,
    error: failure.contents,
    // Saying so is the difference between an assistant that stopped and one that hung.
    stalled: failure.contents == "" && !finished.contents,
    history: wire.contents,
  }
}
