// The assistant: a chat that writes apps.
//
// It is deliberately NOT `ChatPanel`. That one is the people using an app talking to
// each other, and its messages are rows of an ordinary collection because they
// belong to the app and travel with it. This one is one person talking to a model
// about the *platform*: it belongs to the browser, not to any app, which is why it
// opens from the navbar in the gallery and beside an open app alike, and why its
// history is one value in IndexedDB rather than a collection.
//
// Two things this component owns that nothing else can:
//
//   - **The four local tools.** The MCP server answers everything grammatical and
//     custodies nothing; the tools that read and write *this browser's* gallery have
//     to be answered where the storage is. `dispatch` is where the split from
//     `AiTools.isLocal` is acted on, and it is the only place in the app that acts
//     on it.
//   - **The difference between creating and editing.** A new app is written and the
//     person is handed a button to open it: nothing of theirs was at risk. A rewrite
//     of the app they have open is *proposed* — shown, with what the model says it
//     changed, and applied only when they say so. An assistant that edited the
//     document under an author's cursor would be a worse version of the editor they
//     already have.

@get external fieldValue: JsxEvent.Form.t => {"value": string} = "target"
@get external keyOf: JsxEvent.Keyboard.t => string = "key"
@get external shiftKey: JsxEvent.Keyboard.t => bool = "shiftKey"
@send external preventDefault: JsxEvent.Keyboard.t => unit = "preventDefault"

let scrollToEnd: Nullable.t<Dom.element> => unit = %raw(`
function (node) { if (node) node.scrollTop = node.scrollHeight; }
`)

/** One string field out of the arguments the model wrote. Missing is the empty
    string and so is unparseable JSON: every caller here already has something
    sensible to say about an empty value, and none of them is improved by an
    exception. */
let argument: (~arguments: string, ~name: string) => string = %raw(`
function (json, name) {
  try {
    const parsed = JSON.parse(json || "{}");
    const value = parsed[name];
    if (value === undefined || value === null) return "";
    return typeof value === "string" ? value : String(value);
  } catch (error) {
    return "";
  }
}
`)

// The conversation as it is stored: the wire history the provider is sent, and the
// turns drawn here. Plain JS objects on both sides — a ReScript record IS one — so
// this is a shape assertion rather than a decoder.
let packHistory: (~wire: array<JSON.t>, ~turns: array<AiAgent.turn>) => JSON.t = %raw(`
function (wire, turns) { return { wire, turns }; }
`)

let unpackWire: JSON.t => array<JSON.t> = %raw(`
function (stored) { return stored && Array.isArray(stored.wire) ? stored.wire : []; }
`)

let unpackTurns: JSON.t => array<AiAgent.turn> = %raw(`
function (stored) {
  if (!stored || !Array.isArray(stored.turns)) return [];
  return stored.turns
    .filter(turn => turn && typeof turn.role === "string" && typeof turn.text === "string")
    .map(turn => ({ role: turn.role, text: turn.text, app: typeof turn.app === "string" ? turn.app : "" }));
}
`)

/** A rewrite waiting for the person's word. The diff is computed here, from the
    stored document and the proposed one — not taken from the model's account of
    itself, which is exactly the witness the decision must not rest on. */
type proposal = {
  id: string,
  source: string,
  note: string,
  changes: array<LineDiff.change>,
}

@react.component
let make = (
  ~locale: Locale.t,
  ~app: option<string>,
  ~question: option<string>,
  ~onQuestionTaken: unit => unit,
  ~onCreated: string => unit,
  ~onOpen: string => unit,
  ~onApply: (~id: string, ~source: string) => unit,
  ~onClose: unit => unit,
) => {
  let t = key => Translations.translate(locale, key)

  let (settings, setSettings) = React.useState(() => AiSettings.blank)
  // Whether the stored settings have arrived. Until they have, "not configured" is
  // not yet true — it is merely unknown, and a question asked in that moment must
  // wait rather than be treated as one nobody can answer.
  let (loaded, setLoaded) = React.useState(() => false)
  let (settingsOpen, setSettingsOpen) = React.useState(() => false)
  let (models, setModels) = React.useState((): array<AiModels.model> => [])
  let (turns, setTurns) = React.useState((): array<AiAgent.turn> => [])
  let (draft, setDraft) = React.useState(() => "")
  let (busy, setBusy) = React.useState(() => false)
  let (live, setLive) = React.useState(() => "")
  let (thinking, setThinking) = React.useState(() => "")
  let (failure, setFailure) = React.useState(() => "")
  let (mcp, setMcp) = React.useState((): array<McpClient.tool> => [])
  let (proposal, setProposal) = React.useState((): option<proposal> => None)

  // Refs beside the state for everything the streaming callbacks touch: they are
  // called dozens of times a second from inside a promise that closed over the
  // render it started in, and reading state there reads whatever it was then.
  let wire = React.useRef([])
  // The drawn turns, mirrored: what gets written to storage, and what the run's own
  // callbacks append to.
  let drawn = React.useRef([])
  let liveText = React.useRef("")
  let running = React.useRef(None)
  let scroller = React.useRef(Nullable.null)
  // The open app, as the tools see it. The dispatch closure outlives the render that
  // made it, and "which app is open" changes while a run is still going.
  let openApp = React.useRef(app)
  openApp.current = app
  // Refusals in the current run, for the escalating message above. Reset per ask.
  let refused = React.useRef(0)
  // Which conversation is the current one. Clearing starts a new session, and a run
  // in flight belongs to the old one: aborting the fetch is not enough, because an
  // aborted run still *resolves* — with an empty error — and its callbacks then write
  // the deleted conversation back into the wire, into the panel and into IndexedDB.
  // Every callback of a run carries the number it was started under and does nothing
  // once that number is stale. It is the same guard the Python binder and the
  // open-data fetches use against a superseded answer.
  let session = React.useRef(0)
  // Whether the run that is ending was stopped on purpose. An aborted run and a run
  // that went round in circles reach the same place — no error, never finished — so
  // without this the Stop button answered "the assistant stopped after too many
  // steps, ask again more simply", which blames the model for what the person just
  // chose and tells them to rewrite a question that was fine.
  let stopped = React.useRef(false)
  // The server's tools beside the state, for the same reason as everything else in
  // this block: the dispatch closure outlives the render that made it, and on a cold
  // start the list arrives *after* that render. Read from the state there, the
  // delivery gate would see no tools and let an unchecked document through.
  let mcpTools = React.useRef(([]: array<McpClient.tool>))

  React.useEffect0(() => {
    AiStore.loadSettings()
    ->Promise.thenResolve(stored => {
      setSettings(_ => stored)
      setLoaded(_ => true)
    })
    ->ignore
    AiStore.loadHistory()
    ->Promise.thenResolve(stored =>
      switch stored {
      | None => ()
      | Some(value) => {
          wire.current = unpackWire(value)
          drawn.current = unpackTurns(value)
          setTurns(_ => drawn.current)
        }
      }
    )
    ->ignore
    McpClient.tools()
    ->Promise.thenResolve(found => {
      mcpTools.current = found
      setMcp(_ => found)
    })
    ->ignore
    None
  })

  // Only the local daemon publishes what it has. A hosted provider's catalogue is
  // hundreds of names that change weekly and the account decides which of them
  // answer, so there the field stays a field.
  React.useEffect1(() => {
    if AiSettings.isLocal(settings) {
      AiModels.installed(~baseUrl=AiSettings.normalize(settings).baseUrl)
      ->Promise.thenResolve(found => setModels(_ => found))
      ->ignore
    } else {
      setModels(_ => [])
    }
    None
  }, [AiSettings.normalize(settings).baseUrl])

  React.useEffect2(() => {
    scrollToEnd(scroller.current)
    None
  }, (turns->Array.length, live))

  // The conversation is written from the refs, never from the state. Two reasons, and
  // the first one cost a conversation to find: an effect that saved whenever the run
  // ended also ran on mount, where it wrote an empty conversation over the stored one
  // while the asynchronous load of that same conversation was still in flight. And
  // the run's callbacks outlive the render that made them, so state read inside them
  // is whatever it was when the question was asked.
  let remember = () =>
    AiStore.saveHistory(packHistory(~wire=wire.current, ~turns=drawn.current))->ignore

  let addTurn = turn => {
    drawn.current = drawn.current->Array.concat([turn])
    setTurns(_ => drawn.current)
    remember()
  }

  // Whatever has streamed in so far becomes a turn of its own. Called before a tool
  // runs and at the end of a run, so a model that says what it is about to do, does
  // it, and then reports back reads as three things rather than one run-on line.
  let commitLive = () => {
    let text = liveText.current->String.trim
    liveText.current = ""
    setLive(_ => "")
    if text != "" {
      addTurn({AiAgent.role: "assistant", text, app: ""})
    }
  }

  // --- The four tools this browser answers itself ---------------------------

  let describeApps = async () => {
    let stored = await DocumentStore.list()
    if stored->Array.length == 0 {
      "The gallery is empty: this browser has no apps yet."
    } else {
      stored
      ->Array.map(card =>
        "- " ++
        card.AppDocument.id ++
        " — " ++
        card.AppDocument.title ++
        (card.AppDocument.description == "" ? "" : " — " ++ card.AppDocument.description)
      )
      ->Array.join("\n")
    }
  }

  let readApp = async (~arguments) => {
    let asked = argument(~arguments, ~name="id")
    let wanted = asked == "" ? openApp.current->Option.getOr("") : asked
    if wanted == "" {
      "No app is open and no id was given, so there is nothing to read. Call reactive_list_apps to see what is stored here."
    } else {
      switch await DocumentStore.load(wanted) {
      | Some(source) => source
      | None => "There is no app with the id \"" ++ wanted ++ "\" in this browser."
      }
    }
  }

  // Delivery validates for itself, with the app's own grammar, and refuses a document
  // that does not pass. The tools' descriptions already tell the model to validate
  // first and the small models simply do not: the one that wrote the first app here
  // created it and validated it *afterwards*, which put a document with a broken
  // ::list in somebody's gallery. An instruction nothing enforces is a suggestion.
  //
  // With no documentation server there is nothing to check against, and refusing
  // everything would leave the assistant unable to deliver at all — so the gate opens
  // and the panel has already said, at the top, that nothing can be checked.
  let refuseUnlessValid = async source =>
    if mcpTools.current->Array.length == 0 {
      None
    } else {
      let payload = JSON.stringifyAny({"markdown": source})->Option.getOr("{}")
      let report = await McpClient.call(~name="reactive_validate", ~arguments=payload)
      // Grammar first, and only then whether the pieces meet: "this is not a
      // directive" beats "this list has no writer", the same way Draft complains
      // about the type before the pattern. A document that does not parse has no
      // data flow worth reporting on.
      let complaint = if !AiPlan.validates(report.McpClient.text) {
        Some(("the document does not validate", report.McpClient.text))
      } else {
        // The workflow has told the model to analyze since the day the tool existed,
        // and an instruction nothing enforces is a suggestion — the same argument
        // that made validation a gate. Left unchecked this is the failure that
        // *renders*: the app opens, the pages are there, the forms are there, and
        // the list under them is empty for ever because nothing writes what it reads.
        // Somebody has to find that by using the app; the analyzer finds it in a
        // second. The recipes prove the bar is reachable — `scripts/test-mcp.mjs`
        // already asserts every one of them is delivered with no orphans.
        let flow = await McpClient.call(~name="reactive_analyze", ~arguments=payload)
        if !AiPlan.connects(flow.McpClient.text) {
          Some(("the document's pieces do not meet", flow.McpClient.text))
        } else {
          // And the third: the queries are RUN. Grammar says the directive is written
          // correctly and the flow says the collection has a writer; neither can say
          // the SELECT returns anything, and a SELECT that matches nothing renders an
          // app of empty cards with no error anywhere. It is the one runtime failure
          // that can be checked without running the app, because a SELECT is
          // read-only and costs a request.
          let broken = ref(None)
          let queries = AiPlan.odQueries(source)
          for index in 0 to queries->Array.length - 1 {
            if broken.contents == None {
              switch queries->Array.get(index) {
              | None => ()
              | Some(sql) =>
                let answer = await McpClient.call(
                  ~name="reactive_od_query",
                  ~arguments=JSON.stringifyAny({"sql": sql, "limit": 3})->Option.getOr("{}"),
                )
                if AiPlan.queryFails(answer.McpClient.text) {
                  broken :=
                    Some((
                      "one of its open-data queries returns nothing usable",
                      "The query:\n\n" ++ sql ++ "\n\n" ++ answer.McpClient.text,
                    ))
                }
              }
            }
          }
          broken.contents
        }
      }
      switch complaint {
      | None => None
      | Some((what, detail)) =>
        // The message escalates, because on the bench a 4B was refused
        // twenty-five times in a row: each refusal it rewrote the document from
        // scratch, breaking something new, and the fixed wording never told it
        // to stop doing that. From the third attempt the instruction narrows to
        // the one strategy that converges — touch only the reported lines.
        refused.current = refused.current + 1
        let advice =
          refused.current >= 2
            ? "This is refusal number " ++
              Int.toString(refused.current) ++
              ". Stop rewriting the document from scratch — each rewrite breaks something new. Take the EXACT document you just sent, change ONLY the lines named in the report below, drop any feature you cannot fix, and resend it."
            : "Fix every problem below and call this tool again with the corrected document."
        Some(
          "REFUSED: " ++ what ++ ", so nothing was written. " ++ advice ++ "\n\n" ++ detail,
        )
      }
    }

  let createApp = async (~arguments) => {
    let markdown = argument(~arguments, ~name="markdown")
    let taken = await DocumentStore.ids()
    switch AiPlan.create(~markdown, ~taken, ~fallback=AppId.fallback) {
    | AiPlan.Refused(reason) => reason
    | AiPlan.Deliver({id, source, title, renamed}) =>
      switch await refuseUnlessValid(source) {
      | Some(complaint) => complaint
      | None => {
        await DocumentStore.save(~id, ~source)
        onCreated(id)
        commitLive()
        addTurn({AiAgent.role: "created", text: title, app: id})
        "The app was created in the user's gallery with the id \"" ++
        id ++
        "\"" ++
        (renamed
          ? " (the id the document asked for was already taken here, so it landed under a free one)"
          : "") ++
        ". The user has a button to open it; do not repeat the document back to them."
        }
      }
    }
  }

  let editApp = async (~arguments) => {
    let markdown = argument(~arguments, ~name="markdown")
    let note = argument(~arguments, ~name="note")
    let asked = argument(~arguments, ~name="id")
    // By id when one is given, else the open app: "change the expenses app" is
    // asked from the gallery at least as often as from inside the app.
    let wanted = asked == "" ? openApp.current->Option.getOr("") : asked
    if wanted == "" {
      "No app is open and no id was given, so there is nothing to rewrite. Find the id with reactive_list_apps and pass it, or use reactive_create_app for a new app."
    } else {
      // The app must exist: an edit of nothing would be a create wearing the wrong
      // name, and applying it would write an app the user never chose to have.
      switch await DocumentStore.load(wanted) {
      | None =>
        "There is no app with the id \"" ++
        wanted ++ "\" in this browser. Find the real id with reactive_list_apps, or create a new app with reactive_create_app."
      | Some(stored) =>
        switch AiPlan.replace(~markdown, ~id=wanted) {
        | AiPlan.Refused(reason) => reason
        | AiPlan.Deliver({id, source}) =>
          switch await refuseUnlessValid(source) {
          | Some(complaint) => complaint
          | None => {
              let changes = LineDiff.changesOnly(stored, source)
              if changes->Array.length == 0 {
                "The document you sent is identical to what is already stored — there is nothing to propose. If you meant to change something, it is not in what you sent."
              } else {
                commitLive()
                setProposal(_ => Some({id, source, note, changes}))
                addTurn({AiAgent.role: "proposal", text: note, app: id})
                "The rewrite was shown to the user with its diff; they have not applied it yet — it is their decision. Say briefly what you changed."
              }
            }
          }
        }
      }
    }
  }

  let dispatch = async (~name, ~arguments) =>
    if name == AiTools.listApps {
      await describeApps()
    } else if name == AiTools.readApp {
      await readApp(~arguments)
    } else if name == AiTools.createApp {
      await createApp(~arguments)
    } else if name == AiTools.editApp {
      await editApp(~arguments)
    } else {
      let answer = await McpClient.call(~name, ~arguments)
      answer.McpClient.text
    }

  // --- Asking -----------------------------------------------------------------

  let ask = asked => {
    let question = asked->String.trim
    if question != "" && !busy && AiSettings.isReady(settings) {
      setDraft(_ => "")
      setFailure(_ => "")
      setThinking(_ => "")
      setProposal(_ => None)
      refused.current = 0
      stopped.current = false
      addTurn({AiAgent.role: "user", text: question, app: ""})
      setBusy(_ => true)
      // The conversation this run belongs to. Everything below checks it before
      // touching anything, so a cleared session cannot be written into by the answer
      // it was cleared in the middle of.
      let generation = session.current
      let current = () => session.current == generation
      // How many turns actually *say* something, counted before the run so its end
      // can tell whether anything came of it. Tool steps do not count: a run that
      // called five tools and then stopped without a word produced nothing, and the
      // steps are what make that look like work rather than silence.
      let said = () =>
        drawn.current
        ->Array.filter(turn => turn.AiAgent.role != "tool" && turn.AiAgent.role != "user")
        ->Array.length
      let before = said()
      // The run waits for the tool list instead of taking whatever the last render
      // happened to hold. A question typed in the gallery's opening box starts a run
      // in the same commit that mounts this panel, so the mount's probe was still in
      // flight: the model got the four local tools and none of the grammar, wrote a
      // document with no directives in it, and then apologised for a server that was
      // running the whole time — which is the failure the offline banner exists to
      // prevent, arriving by the one door the banner cannot cover.
      //
      // Asking again per question rather than remembering the first answer is
      // deliberate: it costs one small request, and it is what lets a server started
      // after the app was opened be found without a reload.
      McpClient.tools()
      ->Promise.thenResolve(found => {
        // Cleared while the probe was in flight: the run never starts, rather than
        // starting into a conversation nobody is having any more.
        if current() {
        mcpTools.current = found
        setMcp(_ => found)
        let controller = OpenAiClient.controller()
        running.current = Some(controller)
        AiAgent.run(
          ~settings,
          ~system=AiPrompt.system(
            ~locale,
            ~openApp=openApp.current,
            ~mcp=found->Array.length > 0,
          ),
          ~history=wire.current,
          ~question,
          ~tools=McpClient.declarations(found)->Array.concat(AiTools.declarations),
          ~onText=delta =>
            if current() {
              liveText.current = liveText.current ++ delta
              setLive(_ => liveText.current)
            },
          // A thinking model is silent in `content` for as long as it thinks — a
          // minute is ordinary locally. Only the tail is kept: this is a sign of
          // life, not a transcript.
          ~onThinking=delta =>
            if current() {
              setThinking(shown => {
                let next = shown ++ delta
                next->String.length > 240
                  ? next->String.slice(~start=next->String.length - 240, ~end=next->String.length)
                  : next
              })
            },
          ~onCall=(~name, ~arguments as _) =>
            if current() {
              commitLive()
              setThinking(_ => "")
              addTurn({AiAgent.role: "tool", text: name, app: ""})
            },
          ~dispatch,
          ~signal=Some(OpenAiClient.signalOf(controller)),
        )
        ->Promise.thenResolve(outcome =>
          // The end of a run that has been cleared away is not an event: its history
          // is not the wire any more, its last words are not a turn, and it has no
          // failure to report — the person did not stop it, they deleted it.
          if current() {
            wire.current = outcome.AiAgent.history
            running.current = None
            setBusy(_ => false)
            setThinking(_ => "")
            commitLive()
            if stopped.current {
              // Stopped on purpose: whatever was produced is already on screen, and
              // there is nothing to report about a thing that did what was asked.
              stopped.current = false
            } else if outcome.AiAgent.stalled {
              setFailure(_ => t(Translations.AiStalled))
            } else if outcome.AiAgent.error != "" {
              setFailure(_ => outcome.AiAgent.error)
            } else if said() == before {
              // A run that produced nothing at all. It happens with the small local
              // models: they call a tool, read a long answer, and stop with an empty
              // message — and a panel that says nothing about it looks broken rather
              // than finished. Saying so is also the one honest place to suggest a
              // bigger model.
              setFailure(_ => t(Translations.AiNoAnswer))
            }
            // The wire history only exists once the run is over, so this is the save
            // that makes the next question a continuation rather than a first one.
            remember()
          }
        )
        ->ignore
        }
      })
      ->ignore
    }
  }

  // A question asked from the gallery box. It is taken in either case — a question
  // that arrived twice would be asked twice — but it is only *sent* when there is
  // something to send it to: unconfigured, it lands in the composer with the settings
  // form open above it, which is the one place the person can do anything about it.
  React.useEffect3(() => {
    switch question {
    | Some(text) if text->String.trim != "" && !busy =>
      if AiSettings.isReady(settings) {
        onQuestionTaken()
        ask(text)
      } else if loaded {
        // Configured with nothing to answer from: the question waits in the composer
        // with the settings form open above it, which is the one place the person can
        // do anything about it. Before the settings have loaded it simply waits — the
        // effect runs again the moment they arrive.
        onQuestionTaken()
        setDraft(_ => text)
      }
    | _ => ()
    }
    None
  }, (question->Option.getOr(""), AiSettings.isReady(settings), loaded))

  let stop = () =>
    switch running.current {
    | Some(controller) => {
        stopped.current = true
        OpenAiClient.abort(controller)
        running.current = None
      }
    | None => ()
    }

  // Clearing starts a NEW conversation, which is more than emptying the list: the
  // wire is what the model is replayed on the next question, so a panel that looked
  // empty while the wire still held the old exchange would answer as though nothing
  // had been deleted. Bumping the session is what makes it true even mid-run — an
  // aborted run resolves anyway, and without this its callbacks put everything back.
  let clear = () => {
    stop()
    session.current = session.current + 1
    wire.current = []
    drawn.current = []
    liveText.current = ""
    refused.current = 0
    stopped.current = false
    setLive(_ => "")
    setTurns(_ => [])
    setProposal(_ => None)
    setFailure(_ => "")
    // The run that was going belongs to the old session and will never report back
    // here, so nothing else is going to lower these two.
    setBusy(_ => false)
    setThinking(_ => "")
    AiStore.clearHistory()->ignore
  }

  let applyProposal = () =>
    switch proposal {
    | Some(pending) => {
        onApply(~id=pending.id, ~source=pending.source)
        setProposal(_ => None)
      }
    | None => ()
    }

  // --- Settings ---------------------------------------------------------------

  let saveSettings = next => {
    setSettings(_ => next)
    AiStore.saveSettings(next)->ignore
  }

  let usePreset = preset => {
    saveSettings(preset)
    setFailure(_ => "")
    // The form shows itself while there is nothing to answer with and hides again the
    // moment there is — and choosing the local model makes it ready in one click, so
    // without this the form vanishes from under somebody who has not yet picked which
    // model they meant.
    setSettingsOpen(_ => true)
  }

  let settingsForm = {
    let local = AiSettings.isLocal(settings)
    <div className="rn-ai-settings">
      <div className="rn-ai-presets">
        <Spectrum.ActionButton
          label="OpenAI"
          selected={!local}
          onClick={_ => usePreset({...AiSettings.blank, key: settings.AiSettings.key})}>
          {React.string("OpenAI")}
        </Spectrum.ActionButton>
        <Spectrum.ActionButton
          label="Ollama"
          selected={local}
          onClick={_ => usePreset(AiSettings.onOllama)}>
          {React.string("Ollama")}
        </Spectrum.ActionButton>
      </div>
      {local
        ? React.null
        : <>
            <Spectrum.FieldLabel for_="rn-ai-key"> {React.string(t(AiKeyLabel))} </Spectrum.FieldLabel>
            <input
              id="rn-ai-key"
              className="rn-ai-field"
              type_="password"
              autoComplete="off"
              value={settings.AiSettings.key}
              placeholder="sk-…"
              onChange={event => {
                let next = fieldValue(event)["value"]
                setSettings(current => {...current, AiSettings.key: next})
              }}
              onBlur={_ => saveSettings(settings)}
            />
            <p className="rn-muted rn-ai-help"> {React.string(t(AiKeyHelp))} </p>
          </>}
      <Spectrum.FieldLabel for_="rn-ai-model"> {React.string(t(AiModelLabel))} </Spectrum.FieldLabel>
      {switch (local, models) {
      | (true, []) => <p className="rn-error rn-ai-help"> {React.string(t(AiNoModels))} </p>
      | (true, found) =>
        <Spectrum.Picker
          value={settings.AiSettings.model}
          label={t(AiModelLabel)}
          // Guarded like the navbar's pickers: sp-picker dispatches `change` from its
          // own value setter, and React writes `value` back on every render, so an
          // unguarded handler is a set-value → change → setState loop.
          onChange={event => {
            let next = fieldValue(event)["value"]
            if next != settings.AiSettings.model && next != "" {
              saveSettings({...settings, AiSettings.model: next})
            }
          }}>
          {found
          ->Array.map(model =>
            <Spectrum.MenuItem
              key={model.AiModels.name}
              value={model.AiModels.name}
              selected={model.AiModels.name == settings.AiSettings.model}>
              {React.string(
                model.AiModels.tools
                  ? model.AiModels.name
                  : model.AiModels.name ++ " — " ++ t(AiModelNoTools),
              )}
            </Spectrum.MenuItem>
          )
          ->React.array}
        </Spectrum.Picker>
      | (false, _) =>
        <input
          id="rn-ai-model"
          className="rn-ai-field"
          type_="text"
          value={settings.AiSettings.model}
          onChange={event => {
            let next = fieldValue(event)["value"]
            setSettings(current => {...current, AiSettings.model: next})
          }}
          onBlur={_ => saveSettings(settings)}
        />
      }}
      <Spectrum.FieldLabel for_="rn-ai-endpoint">
        {React.string(t(AiEndpointLabel))}
      </Spectrum.FieldLabel>
      <input
        id="rn-ai-endpoint"
        className="rn-ai-field"
        type_="text"
        value={settings.AiSettings.baseUrl}
        onChange={event => {
          let next = fieldValue(event)["value"]
          setSettings(current => {...current, AiSettings.baseUrl: next})
        }}
        onBlur={_ => saveSettings(settings)}
      />
      {switch AiSettings.check(settings) {
      | Some(AiSettings.NoKey) => <p className="rn-error rn-ai-help"> {React.string(t(AiNeedsKey))} </p>
      | Some(AiSettings.NotHttps) =>
        <p className="rn-error rn-ai-help"> {React.string(t(AiNeedsHttps))} </p>
      | None => React.null
      }}
      <Spectrum.Button variant="accent" onClick={_ => {
        saveSettings(settings)
        setSettingsOpen(_ => false)
      }}>
        {React.string(t(AiSaveSettings))}
      </Spectrum.Button>
    </div>
  }

  // --- Drawing ----------------------------------------------------------------

  let drawTurn = (turn: AiAgent.turn, index) =>
    switch turn.role {
    | "user" =>
      <li key={Int.toString(index)} className="rn-ai-turn rn-ai-user">
        <MessageText text={turn.text} locale />
      </li>
    | "tool" =>
      <li key={Int.toString(index)} className="rn-ai-turn rn-ai-tool">
        <span className="rn-ai-tool-name" title={t(AiUsedTool)}>
          {React.string(turn.text)}
        </span>
      </li>
    | "created" =>
      <li key={Int.toString(index)} className="rn-ai-turn rn-ai-created">
        <span> {React.string(t(AiCreated) ++ ": " ++ turn.text)} </span>
        <Spectrum.Button variant="accent" size="s" onClick={_ => onOpen(turn.app)}>
          {React.string(t(OpenApp))}
        </Spectrum.Button>
      </li>
    | "proposal" =>
      <li key={Int.toString(index)} className="rn-ai-turn rn-ai-note">
        {React.string(turn.text == "" ? t(AiProposal) : t(AiProposal) ++ ": " ++ turn.text)}
      </li>
    | _ =>
      <li key={Int.toString(index)} className="rn-ai-turn rn-ai-assistant">
        <MessageText text={turn.text} locale />
      </li>
    }

  <aside className="rn-ai-panel" ariaLabel={t(AiPanel)}>
    <header className="rn-ai-header">
      <h2 className="rn-ai-title"> {React.string(t(AiPanel))} </h2>
      <Spectrum.ActionButton
        label={t(AiClear)}
        onClick={_ => clear()}
        disabled={turns->Array.length == 0}>
        Icons.trash
      </Spectrum.ActionButton>
      <Spectrum.ActionButton
        label={t(AiSettingsAction)}
        selected={settingsOpen}
        onClick={_ => setSettingsOpen(shown => !shown)}>
        Icons.settings
      </Spectrum.ActionButton>
      <Spectrum.ActionButton label={t(CancelAction)} onClick={_ => onClose()}>
        Icons.close
      </Spectrum.ActionButton>
    </header>
    // The settings open by themselves while there is nothing to answer with: the
    // first thing anybody needs here is the form, not an empty conversation.
    {settingsOpen || !AiSettings.isReady(settings) ? settingsForm : React.null}
    {mcp->Array.length == 0
      ? <p className="rn-ai-warning"> {React.string(t(AiMcpOffline))} </p>
      : React.null}
    <ol ref={ReactDOM.Ref.domRef(scroller)} className="rn-ai-turns">
      {turns->Array.length == 0 && live == ""
        ? <li className="rn-muted rn-ai-empty"> {React.string(t(AiEmpty))} </li>
        : React.null}
      {turns->Array.mapWithIndex(drawTurn)->React.array}
      {live == ""
        ? React.null
        : <li className="rn-ai-turn rn-ai-assistant">
            <MessageText text={live} locale />
          </li>}
      // Something has to be moving for as long as this is working. A run is minutes
      // of tool calls and silence, and a still panel with a static line in it is what
      // a broken one looks like; the dots are the difference between waiting and
      // wondering. They are dropped while text is streaming, because the text is
      // already the motion — two things moving at once is fidgeting, not progress.
      {busy && live == ""
        ? <li className="rn-ai-thinking" role="status" ariaLive={#polite}>
            <span className="rn-ai-dots" ariaHidden={true}>
              <i /> <i /> <i />
            </span>
            <span className="rn-ai-thinking-label"> {React.string(t(AiThinking))} </span>
            // A thinking model's reasoning, as a sign of life rather than as an
            // answer — and never announced: a screen reader reading a minute of
            // somebody's working-out over the top of everything else is worse than
            // silence. The status above says the one thing worth saying.
            {thinking == ""
              ? React.null
              : <span className="rn-ai-thinking-tail" ariaHidden={true}>
                  {React.string(thinking)}
                </span>}
          </li>
        : React.null}
    </ol>
    {switch proposal {
    | None => React.null
    | Some(pending) => {
        let counts = LineDiff.count(pending.changes)
        // Two hundred changed lines fill several screens of a narrow panel; past
        // that the person is not reading a diff any more, and the honest thing is
        // to say how much was cut rather than to scroll for ever.
        let shown = pending.changes->Array.slice(~start=0, ~end=200)
        let hidden = pending.changes->Array.length - shown->Array.length
        <div className="rn-ai-proposal">
          <div className="rn-ai-proposal-header">
            <span>
              {React.string(t(AiProposal) ++ " — " ++ pending.id)}
              <span className="rn-ai-diff-counts" ariaHidden={true}>
                {React.string(
                  " +" ++ Int.toString(counts.LineDiff.added) ++ " −" ++ Int.toString(counts.LineDiff.removed),
                )}
              </span>
            </span>
            <div className="rn-ai-proposal-actions">
              <Spectrum.Button variant="accent" size="s" onClick={_ => applyProposal()}>
                {React.string(t(AiApply))}
              </Spectrum.Button>
              <Spectrum.Button
                variant="secondary" size="s" onClick={_ => setProposal(_ => None)}>
                {React.string(t(AiDiscard))}
              </Spectrum.Button>
            </div>
          </div>
          // The changed lines themselves, from the two documents — not from the
          // model's description of what it did. Text nodes only, like every other
          // place a document's content reaches this DOM.
          <pre className="rn-ai-diff">
            {shown
            ->Array.mapWithIndex((line, index) =>
              <span
                key={Int.toString(index)}
                className={line.LineDiff.sign == "+" ? "rn-ai-diff-add" : "rn-ai-diff-del"}>
                {React.string(line.LineDiff.sign ++ " " ++ line.LineDiff.text ++ "\n")}
              </span>
            )
            ->React.array}
            {hidden > 0
              ? <span className="rn-muted"> {React.string("… +" ++ Int.toString(hidden))} </span>
              : React.null}
          </pre>
        </div>
      }
    }}
    {failure == ""
      ? React.null
      : <p className="rn-error rn-ai-help"> {React.string(t(AiFailed) ++ " " ++ failure)} </p>}
    <div className="rn-ai-composer">
      <textarea
        className="rn-ai-input"
        rows={1}
        value={draft}
        placeholder={t(AiPlaceholder)}
        ariaLabel={t(AiPlaceholder)}
        disabled={!AiSettings.isReady(settings)}
        onChange={event => {
          let next = fieldValue(event)["value"]
          setDraft(_ => next)
        }}
        // Enter sends and shift+Enter breaks the line, which is what every chat does
        // and therefore what everyone's fingers already do.
        onKeyDown={event =>
          if keyOf(event) == "Enter" && !shiftKey(event) {
            preventDefault(event)
            ask(draft)
          }}
      />
      <div className="rn-ai-composer-actions">
        // Accanto a Ferma, per tutto il tempo del lavoro. Quello nella lista sparisce
        // appena il testo comincia a scorrere — è giusto che sparisca, il testo è già
        // movimento — ma allora resta un pulsante Ferma da solo, e un pulsante non
        // dice se c'è ancora qualcosa da fermare. Questo lo dice sempre.
        //
        // I puntini però solo quando sono gli unici a muoversi. Con l'indicatore
        // della lista in scena sarebbero due animazioni identiche nello stesso
        // pannello, che è la stessa cosa che quel codice evita già mentre il testo
        // scorre: due cose in movimento sono agitazione, non avanzamento. Qui resta
        // la scritta, che è quello che serve accanto a un pulsante.
        //
        // È `aria-hidden`: lo stesso stato è già annunciato dal `role="status"` della
        // lista, e due regioni vive che dicono la stessa cosa la fanno leggere due
        // volte. Qui serve agli occhi, e Ferma è l'appiglio di tutti gli altri.
        {busy
          ? <span className="rn-ai-working" ariaHidden={true}>
              {live == ""
                ? React.null
                : <span className="rn-ai-dots"> <i /> <i /> <i /> </span>}
              <span className="rn-ai-working-label"> {React.string(t(AiWorking))} </span>
            </span>
          : React.null}
        {busy
          ? <Spectrum.Button variant="secondary" size="s" onClick={_ => stop()}>
              {React.string(t(AiStop))}
            </Spectrum.Button>
          : <Spectrum.Button
              variant="accent"
              size="s"
              disabled={draft->String.trim == "" || !AiSettings.isReady(settings)}
              onClick={_ => ask(draft)}>
              {React.string(t(ChatSend))}
            </Spectrum.Button>}
      </div>
    </div>
  </aside>
}
