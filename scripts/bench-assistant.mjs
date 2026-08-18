#!/usr/bin/env bun
// ============================================================================
// bench-assistant.mjs — how well does a model build an app here?
//
// The assistant's quality is a property of three things: the model, the tools
// the MCP server offers, and the prompt. Two of those are ours, and neither can
// be improved by staring at it — so this runs the real loop against real models
// and scores what comes out.
//
// What it reuses, rather than reimplements: the app's own system prompt
// (`core/AiPrompt`), its own local tool declarations (`core/AiTools`), its own
// delivery rules and validation gate (`core/AiPlan`), and the same MCP server
// over the same endpoint. Only the agent loop is written again here, because
// the real one lives inside a React panel. If this bench and the app disagree
// about what a directive means, this bench is wrong.
//
// Use:
//   bun run mcp                                  # the tools must be up
//   bun scripts/bench-assistant.mjs <model>...   # e.g. qwen3.5:4b qwen3.6:27b
//   BENCH_LEVELS=low,medium bun scripts/bench-assistant.mjs qwen3.5:4b
//
// Environment (with defaults):
//   BENCH_BASE_URL=http://127.0.0.1:11434/v1   any OpenAI-compatible endpoint
//   BENCH_API_KEY=                             sent as a bearer when set
//   BENCH_MCP=http://127.0.0.1:8789/mcp
//   BENCH_LEVELS=low,medium,high
//   BENCH_RUNS=1                               repeats per model × level
//   BENCH_SCHEMA=1                             constrained-decoding loop: no native
//                                              tool calling; every turn is one JSON
//                                              action forced by Ollama's `format`
//   BENCH_NATIVE=1                             speak Ollama's native /api/chat
//                                              instead of the OpenAI layer — for
//                                              measuring whether the 500s from the
//                                              compat layer's tool-call parser
//                                              disappear on the native path
//
// Anthropic's models are deliberately NOT reachable here: their API is the
// Messages API, not this wire format, and the app's assistant speaks this one.
// Benching Claude means either a translating proxy or a second client — both
// are decisions to make on purpose, not to smuggle in through a bench script.
// ============================================================================

import * as AiPrompt from "../src/core/AiPrompt.res.mjs"
import * as AiTools from "../src/core/AiTools.res.mjs"
import * as AiPlan from "../src/core/AiPlan.res.mjs"

const BASE_URL = (process.env.BENCH_BASE_URL || "http://127.0.0.1:11434/v1").replace(/\/$/, "")
const API_KEY = process.env.BENCH_API_KEY || ""
const MCP = process.env.BENCH_MCP || "http://127.0.0.1:8789/mcp"
const RUNS = Number(process.env.BENCH_RUNS || 1)
const NATIVE = process.env.BENCH_NATIVE === "1"
// Schema mode: Ollama's native constrained decoding (`format`) drives the whole
// loop. Tool calling and grammar constraints cannot coexist — the grammar would
// forbid the tool-call template's own tokens — so in this mode there is no
// `tools` parameter at all: the tool catalog rides in the system prompt, and
// every turn the model MUST emit one JSON action, either a tool call or the
// reply. What that buys, by construction rather than by prompting: no malformed
// tool call can exist (the parser 500s become impossible), no silent turn (the
// schema requires an action), and no document pasted as an answer that the
// nudge cannot see. Implies the native protocol.
const SCHEMA = process.env.BENCH_SCHEMA === "1"
const NATIVE_OR_SCHEMA = NATIVE || SCHEMA
const MAX_STEPS = 96 // AiAgent.maxSteps
const TIMEOUT_MS = 600_000

// --- The tasks ---------------------------------------------------------------
// Three levels, and the levels are about *how many pieces have to meet*, not
// about how long the document is. `must` is checked against the delivered
// document: it is what the person asked for, expressed as the directives that
// would have to be there for the app to do it.
const TASKS = {
  low: {
    prompt: "Fai un'app per la lista della spesa.",
    must: {
      "a form": /::form\b/,
      "fields in it": /::input\b/,
      "a save button": /::(save|add-form)\b/,
      "a list of the rows": /::list\b|::cards\b|::table\b/,
    },
  },
  medium: {
    prompt:
      "Fai un'app per registrare le spese di casa: data, categoria, importo. Voglio vedere il totale speso e poter filtrare per categoria.",
    must: {
      "a form": /::form\b/,
      "a save button": /::(save|add-form)\b/,
      "a view of the rows": /::list\b|::cards\b|::table\b/,
      "the total": /:sum\{/,
      "a way to filter": /filters?=|::table\b[^\n]*search/,
    },
  },
  high: {
    prompt:
      "Fai un'app per gestire i soci di un'associazione: una pagina con l'anagrafica dei soci (nome, email) e una pagina con le quote pagate (socio, importo, data). Nella seconda pagina voglio un grafico degli importi e il totale.",
    must: {
      "two pages": /(::page\b[\s\S]*){2,}/,
      "two collections": /::form\{[^}]*path="([a-z0-9_-]+)"[\s\S]*::form\{[^}]*path="(?!\1)[a-z0-9_-]+"/,
      "a chart": /::chart-\w+/,
      "the total": /:sum\{/,
      "a relation or a reference field": /\{[a-z0-9_]+>[a-z0-9_]+\.|type="ref"/,
    },
  },
  // Everything at once, which is its own difficulty: not one hard directive but
  // many pieces that all have to meet. The checks accept anything with a `test`
  // method, so the ones a regex cannot express are small functions.
  ultra: {
    prompt:
      "Fai un'app completa per gestire una palestra, su più pagine: una pagina Iscritti con l'anagrafica (nome, email, tipo di abbonamento) dove posso cercare e filtrare per abbonamento; una pagina Corsi (nome del corso, giorno della settimana, ora, istruttore); una pagina Pagamenti (iscritto, importo, data) con il totale incassato, la media dei pagamenti, un grafico degli importi per iscritto e un calendario dei pagamenti; e una pagina Riepilogo con il conteggio di iscritti, corsi e pagamenti e un grafico a torta degli abbonamenti. Nei pagamenti l'iscritto deve essere scelto dall'anagrafica, non riscritto a mano.",
    must: {
      "four pages": { test: s => (s.match(/::page\{/g) || []).length >= 4 },
      "three collections": {
        test: s => new Set([...s.matchAll(/::form\{[^}]*path="([^"]+)"/g)].map(m => m[1])).size >= 3,
      },
      "a reference field into the roster": /type="ref"/,
      "a relation token in a view": /\{[a-z0-9_]+>[a-z0-9_]+\./,
      "two kinds of chart": { test: s => new Set([...s.matchAll(/::chart-(\w+)/g)].map(m => m[1])).size >= 2 },
      "the total": /:sum\{/,
      "the average": /:avg\{/,
      "counts": /:count\{/,
      "a calendar": /::calendar\b/,
      "search or filters": /filters?=|search/,
    },
  },
}

// --- The MCP server ----------------------------------------------------------
const mcp = async (method, params) => {
  const response = await fetch(MCP, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params: params || {} }),
  })
  const body = await response.text()
  const payload = body.trimStart().startsWith("{")
    ? body
    : body.split("\n").filter(l => l.startsWith("data:")).map(l => l.slice(5).trim()).pop()
  const message = JSON.parse(payload)
  if (message.error) throw new Error(message.error.message)
  return message.result
}

const callMcp = async (name, args) => {
  const result = await mcp("tools/call", { name, arguments: args })
  return (result.content || []).filter(part => part && part.type === "text").map(part => part.text).join("\n")
}

// --- One run -----------------------------------------------------------------
const run = async (model, level) => {
  const task = TASKS[level]
  const started = Date.now()
  const mcpTools = (await mcp("tools/list", {})).tools
  const tools = [
    ...mcpTools.map(t => ({
      type: "function",
      function: { name: t.name, description: t.description, parameters: t.inputSchema },
    })),
    ...AiTools.declarations,
  ]

  // Schema mode: the action grammar. `action` is a closed enum of the real tool
  // names plus "reply", so the model cannot invent a tool any more than it can
  // emit broken syntax.
  const toolNames = tools.map(t => t.function.name)
  const actionSchema = {
    type: "object",
    properties: {
      action: { type: "string", enum: [...toolNames, "reply"] },
      arguments: { type: "object", description: "The tool's arguments, when action is a tool." },
      text: { type: "string", description: "The answer to the user, when action is 'reply'." },
    },
    required: ["action"],
  }
  const schemaPreamble =
    "\n\n# Output protocol (STRICT)\n" +
    "Every turn you emit exactly ONE JSON object and nothing else:\n" +
    '- to use a tool: {"action": "<tool name>", "arguments": {…}}\n' +
    '- to answer the user: {"action": "reply", "text": "…"}\n' +
    "One action per turn. After a tool answer arrives, choose the next action.\n\n" +
    "# The tools\n" +
    tools
      .map(t => `## ${t.function.name}\n${t.function.description}\nArguments schema: ${JSON.stringify(t.function.parameters)}`)
      .join("\n\n")

  const messages = [
    {
      role: "system",
      content: AiPrompt.system("It", undefined, true) + (SCHEMA ? schemaPreamble : ""),
    },
    { role: "user", content: task.prompt },
  ]
  const steps = []
  let delivered = null
  let refusals = 0
  let pasted = false
  let nudges = 0

  for (let step = 0; step < MAX_STEPS; step++) {
    const headers = { "Content-Type": "application/json" }
    if (API_KEY) headers.Authorization = "Bearer " + API_KEY
    // Native mode talks to Ollama's own /api/chat beside the /v1 layer. The body is
    // the same shape; the answer differs in two ways that matter here: the message
    // rides at .message rather than .choices[0].message, and tool-call arguments
    // arrive as an OBJECT already parsed by the server, not as a JSON string.
    const url = NATIVE ? BASE_URL.replace(/\/v1$/, "") + "/api/chat" : BASE_URL + "/chat/completions"
    const body = SCHEMA
      ? NATIVE
        ? { model, messages, format: actionSchema, stream: false }
        : {
            model,
            messages,
            stream: false,
            response_format: {
              type: "json_schema",
              json_schema: { name: "action", schema: actionSchema, strict: true },
            },
          }
      : { model, messages, tools, stream: false }
    const ask = () =>
      fetch(url, {
        method: "POST",
        headers,
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      })
    let response = await ask()
    // AiAgent's own rule, mirrored: one retry on a 5xx, which is usually the
    // provider tripping over one sample (Ollama's tool-call parser 500s on a
    // malformed call), not the provider being down.
    if (response.status >= 500) response = await ask()
    if (!response.ok)
      return { model, level, error: `HTTP ${response.status}: ${(await response.text()).slice(0, 200)}` }
    const answer = await response.json()
    const message = NATIVE ? answer.message : answer.choices[0].message
    messages.push(message)

    // Schema mode: the JSON action IS the message. Decode it into the same
    // shape the tool-calling path produces, so everything below is shared.
    let calls = message.tool_calls || []
    if (SCHEMA) {
      let act = null
      try {
        const raw = message.content || "{}"
        act = JSON.parse(raw.slice(Math.max(0, raw.indexOf("{"))))
      } catch {
        act = null // constrained decoding makes this near-impossible; treat as reply
      }
      if (act && act.action && act.action !== "reply") {
        calls = [{ function: { name: act.action, arguments: act.arguments || {} } }]
      } else {
        calls = []
        // The reply text takes the pasted/empty checks below, as content.
        message.content = act && typeof act.text === "string" ? act.text : ""
      }
    }
    if (calls.length === 0) {
      // The agent's own nudges (shell/AiAgent), mirrored exactly: one for a
      // silent turn (the whole answer went to the reasoning channel), one for a
      // document pasted into the chat instead of delivered. One nudge total.
      const text = (message.content || "").trim()
      const pastedDocument = /^appId:/m.test(message.content || "")
      if ((!text || pastedDocument) && nudges === 0) {
        nudges++
        messages.push({
          role: "user",
          content: !text
            ? "You ended your turn without saying anything and without calling a tool. If you have enough to write the app, write the complete document now and deliver it with reactive_create_app. If something is genuinely missing, ask one short question."
            : "You wrote the document into the chat instead of delivering it. A document in a message is not an app in the gallery — the user cannot open it. Call reactive_create_app now with that complete document, then tell the user in one sentence what you built.",
        })
        continue
      }
      // A model that writes the document into its reply instead of delivering
      // it has failed in a way worth counting separately: the app is nowhere.
      if (/::form|::list|appId:/.test(message.content || "")) pasted = true
      break
    }

    for (const call of calls) {
      const name = call.function.name
      const raw = call.function.arguments
      let args = {}
      try {
        args = typeof raw === "string" ? JSON.parse(raw || "{}") : raw || {}
      } catch {
        messages.push(
          SCHEMA
            ? { role: "user", content: `TOOL RESULT ${name}:\nThe arguments were not valid JSON.` }
            : NATIVE
              ? { role: "tool", tool_name: name, content: "The arguments were not valid JSON." }
              : { role: "tool", tool_call_id: call.id, content: "The arguments were not valid JSON." },
        )
        steps.push(name + "!")
        continue
      }
      steps.push(name)

      let result
      if (name === "reactive_create_app" || name === "reactive_edit_app") {
        // Exactly the panel's gate: unfence, settle the id, validate, refuse.
        const plan = AiPlan.create(args.markdown || "", ["welcome"], "app")
        if (plan.TAG === "Refused") {
          refusals++
          result = plan._0
        } else {
          const report = await callMcp("reactive_validate", { markdown: plan.source })
          if (AiPlan.validates(report)) {
            delivered = { id: plan.id, title: plan.title, source: plan.source }
            result = `The app was created in the user's gallery with the id "${plan.id}". The user has a button to open it; do not repeat the document back to them.`
          } else {
            refusals++
            // The panel's escalating refusal, mirrored: from the third attempt
            // the instruction narrows to the one strategy that converges.
            const advice =
              refusals >= 2
                ? `This is refusal number ${refusals}. Stop rewriting the document from scratch — each rewrite breaks something new. Take the EXACT document you just sent, change ONLY the lines named in the report below, drop any feature you cannot fix, and resend it.`
                : "Fix every problem below and call this tool again with the corrected document."
            result =
              "REFUSED: the document does not validate, so nothing was written. " + advice + "\n\n" + report
          }
        }
      } else if (name === "reactive_list_apps") {
        result = "- welcome — Benvenuto in ReactiveNET"
      } else if (name === "reactive_read_app") {
        result = "No app is open and no id was given, so there is nothing to read."
      } else {
        result = await callMcp(name, args)
      }
      messages.push(
        SCHEMA
          ? { role: "user", content: `TOOL RESULT ${name}:\n${result}` }
          : NATIVE
            ? { role: "tool", tool_name: name, content: result }
            : { role: "tool", tool_call_id: call.id, content: result },
      )
    }
  }

  // --- Scoring ---------------------------------------------------------------
  const source = delivered ? delivered.source : ""
  const met = Object.entries(task.must).filter(([, pattern]) => pattern.test(source)).map(([name]) => name)
  const missing = Object.keys(task.must).filter(name => !met.includes(name))
  const analysis = delivered ? await callMcp("reactive_analyze", { markdown: source }) : ""
  const orphans = delivered
    ? analysis.includes("No orphans")
      ? 0
      : Number((analysis.match(/(\d+) finding\(s\)/) || [, 0])[1])
    : null

  return {
    model,
    level,
    seconds: Math.round((Date.now() - started) / 1000),
    delivered: Boolean(delivered),
    // Delivered documents always validate — the gate refuses the rest — so the
    // score is about whether the app does what was asked, not whether it parses.
    features: `${met.length}/${Object.keys(task.must).length}`,
    missing,
    orphans,
    refusals,
    pastedInsteadOfDelivering: pasted,
    steps: steps.length,
    lookedUp: steps.filter(s => s.startsWith("reactive_directives") || s.startsWith("reactive_guide")).length,
    validatedFirst: steps.indexOf("reactive_validate") !== -1 && steps.indexOf("reactive_validate") < steps.indexOf("reactive_create_app"),
    trace: steps.join(" → "),
    lines: source ? source.split("\n").length : 0,
    // What it said when it stopped. The most useful field on a failed run: a
    // model that stops without delivering is always saying *something* instead.
    reply: ((messages.filter(m => m.role === "assistant").pop() || {}).content || "").slice(0, 300),
  }
}

// --- Main --------------------------------------------------------------------
const models = process.argv.slice(2)
if (models.length === 0) {
  console.error("Use: bun scripts/bench-assistant.mjs <model>...")
  process.exit(1)
}
const levels = (process.env.BENCH_LEVELS || "low,medium,high").split(",").map(l => l.trim())

const results = []
for (const model of models) {
  for (const level of levels) {
    for (let attempt = 0; attempt < RUNS; attempt++) {
      let outcome
      try {
        outcome = await run(model, level)
      } catch (error) {
        outcome = { model, level, error: String(error).slice(0, 200) }
      }
      results.push(outcome)
      console.error(JSON.stringify(outcome))
    }
  }
}

// The table is the point: a column per thing that can go wrong, so a change to
// the prompt or the server can be read as a column moving.
const pad = (value, width) => String(value).padEnd(width)
console.log("")
console.log(
  pad("model", 16) + pad("level", 8) + pad("del", 5) + pad("features", 10) +
  pad("orph", 6) + pad("ref", 5) + pad("steps", 7) + pad("look", 6) + pad("val1st", 8) + pad("secs", 6) + "missing",
)
for (const r of results) {
  if (r.error) {
    console.log(pad(r.model, 16) + pad(r.level, 8) + "ERROR " + r.error)
    continue
  }
  console.log(
    pad(r.model, 16) + pad(r.level, 8) + pad(r.delivered ? "yes" : (r.pastedInsteadOfDelivering ? "PASTE" : "no"), 5) +
    pad(r.features, 10) + pad(r.orphans === null ? "-" : r.orphans, 6) + pad(r.refusals, 5) +
    pad(r.steps, 7) + pad(r.lookedUp, 6) + pad(r.validatedFirst ? "yes" : "no", 8) + pad(r.seconds, 6) +
    r.missing.join(", "),
  )
}
