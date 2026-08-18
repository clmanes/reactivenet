#!/usr/bin/env bun
// ============================================================================
// server.mjs — ReactiveNET's MCP server (Streamable HTTP transport, remote).
//
// What it does: gives a model the tools to WRITE a ReactiveNET app and to
// CHECK it before delivering, then packs it into a share link (`/s#1…`). The
// user clicks the link and the app lands in their gallery — the same road an
// app shared between users takes, no new code on the app side.
//
// What it deliberately does NOT do: it never touches user data, opens no
// channel to any browser, writes nothing to disk. It is a server of PURE
// FUNCTIONS (guide, validation, data-flow analysis, encoding) — plus ONE
// read-only fetch, the open-data catalog, same-machine by default — which is
// why it can sit on the open Internet without authentication: there is
// nothing to protect beyond the availability of the service (a per-address
// rate limit bounds that; MCP_TOKEN turns on bearer auth when wanted).
//
// Everything grammatical is delegated to the app's own compiled core:
//   - the directive catalogue is core/DirectiveRegistry (110 directives,
//     ReactiveNET's own plus the generated Spectrum set),
//   - scanning and snippets are core/DirectiveScan — the SAME scanner and
//     renderer the app's marked pipeline and block editor use,
//   - attribute parsing is core/DirectiveAttributes (quote-aware, so a
//     pattern's own `{5}` does not end the attribute list),
//   - the link is core/ShareLink + shell/SharePayload, byte-identical to
//     what the app itself produces.
// If this server said "ok" about a document the app reads differently, the
// whole tool would be pointless; importing the compiled core is what makes
// that impossible. (`bun run res:build` first — the imports are the emitted
// `.res.mjs`, which is also why this server runs under bun, not node.)
//
// Local use:    bun run mcp             (then http://localhost:8789/mcp)
// Environment (with defaults):
//   MCP_PORT=8789
//   MCP_APP_URL=http://localhost:5173   origin the share links point at
//   MCP_OD_URL=http://127.0.0.1:8788    the open-data service the catalog reads
//   MCP_TOKEN=                          set to require `Authorization: Bearer <token>` on /mcp
//   MCP_RATE=120                        requests per minute per address
// ============================================================================

import { createServer } from "node:http"
import { readFileSync, readdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { z } from "zod"
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js"

// NO top-level await beyond static imports, learned the hard way in the
// previous incarnation of this server: a supervisor loading an async module
// with require() dies with an incomprehensible TypeError. Static ESM imports
// are fine — everything below is synchronous at module level.
import * as DirectiveRegistry from "../src/core/DirectiveRegistry.res.mjs"
import * as DirectiveScan from "../src/core/DirectiveScan.res.mjs"
import * as DirectiveAttributes from "../src/core/DirectiveAttributes.res.mjs"
import * as Frontmatter from "../src/core/Frontmatter.res.mjs"
import * as AppId from "../src/core/AppId.res.mjs"
import * as AppDocument from "../src/core/AppDocument.res.mjs"
import * as Locale from "../src/core/Locale.res.mjs"
import * as ShareLink from "../src/core/ShareLink.res.mjs"
import * as WorkflowTrigger from "../src/core/WorkflowTrigger.res.mjs"
import * as SharePayload from "../src/shell/SharePayload.res.mjs"
// The same lock the browser uses, not a second one: what this seals is exactly what
// the app's own import path opens, and the seam stays the one that is already
// tested. It is WebCrypto and base64 — nothing in it is a browser.
import * as ShareCrypto from "../src/shell/ShareCrypto.res.mjs"
import * as Expr from "../src/core/Expr.res.mjs"
import * as OdQuery from "../src/core/OdQuery.res.mjs"

// --- Configuration ----------------------------------------------------------
const PORT = Number(process.env.MCP_PORT || 8789)
const APP_URL = (process.env.MCP_APP_URL || "http://localhost:5173").replace(/\/$/, "")
const OD_URL = (process.env.MCP_OD_URL || "http://127.0.0.1:8788").replace(/\/$/, "")
// The share server, for the short links. Reached directly here rather than through
// the app's /pb proxy: that proxy exists so a BROWSER stays on one origin, and this
// is not one. What travels is already sealed, so the hop is a blob either way.
const PB_URL = (process.env.MCP_PB_URL || "http://127.0.0.1:8090").replace(/\/$/, "")
// Optional hardening for a server that leaves localhost. MCP_TOKEN turns on
// bearer auth on /mcp (health stays open); MCP_RATE is requests per minute
// per address — generous, because the cost being bounded is availability,
// the one thing this server has to protect.
const TOKEN = process.env.MCP_TOKEN || ""
const RATE = Math.max(1, Number(process.env.MCP_RATE || 120))
const HERE = dirname(fileURLToPath(import.meta.url))

// --- The guide: doc/, split on `## ` headings -------------------------------
// The documentation is ~100KB across nine files: pouring it whole into a
// conversation would waste the model's context, so it is served a section at
// a time, exactly as the previous server served its single guide.
const GUIDE_FILES = [
  ["language", "language.md", "The syntax: directive forms, attributes, #refs, frontmatter"],
  ["authoring", "authoring.md", "From an empty gallery to a working app, step by step"],
  ["directives", "directives.md", "The data directives: forms, lists, views, aggregations"],
  ["storage", "storage.md", "Collections, backups, CSV, what travels and what stays"],
  ["security", "security.md", "The threat model: sanitiser, CSP, Trusted Types"],
  ["accessibility", "accessibility.md", "WCAG 2.2 AA: what is enforced and how"],
  ["rbac", "rbac.md", "Shared spaces: sync, roles, end-to-end encryption"],
  ["architecture", "architecture.md", "How the app itself is built"],
]

const splitSections = (doc, text) => {
  const sections = []
  let current = null
  for (const line of text.split("\n")) {
    const heading = /^## (.+)$/.exec(line)
    if (heading) {
      if (current) sections.push(current)
      current = { doc, title: heading[1].trim(), body: [line] }
    } else if (current) current.body.push(line)
  }
  if (current) sections.push(current)
  return sections.map(s => ({ doc: s.doc, title: s.title, text: s.body.join("\n").trim() }))
}

const guide = GUIDE_FILES.map(([name, file, blurb]) => {
  const text = readFileSync(join(HERE, "..", "doc", file), "utf8")
  return { name, blurb, text, sections: splitSections(name, text) }
})

// Computed once: the index and the catalogue listing never change while the
// server runs, and both are answered on the hot path of every conversation.
const GUIDE_INDEX = guide
  .map(doc =>
    [`${doc.name} — ${doc.blurb}`, ...doc.sections.map(s => `  - ${doc.name}: ${s.title}`)].join("\n"),
  )
  .join("\n")

const findGuide = query => {
  const needle = String(query).trim().toLowerCase()
  const doc = guide.find(d => d.name === needle)
  if (doc) return doc.text
  const section = guide.flatMap(d => d.sections).find(s => s.title.toLowerCase().includes(needle))
  return section ? section.text : null
}

// --- The catalogue, straight from the registry ------------------------------
const COMPONENTS = DirectiveRegistry.all

// The ten inline directives — written `:name{…}` in running text. Everything
// else is a block: `::name{…}` on its own line, a container when a `::/name`
// below closes it (nothing is counted; the close names what it ends).
const INLINE = new Set(["value", "calc", "count", "sum", "avg", "min", "max", "median", "stddev", "mode"])

const isSource = c => c.attributes.some(a => a.name === "value" || a.name === "checked")

// A directive's form, for the catalogue. A source component (one with `value`
// or `checked`) is written `::name[key]` — the brackets are the STORE KEY, not
// a caption — and its visible text goes in the body.
const formOf = c => {
  if (INLINE.has(c.directive)) return "inline"
  if (c.slots.length > 0) return "leaf or container"
  return "leaf"
}

const attrLine = a => {
  const kind =
    a.kind === "Choice"
      ? `one of: ${a.choices.join(" | ")}`
      : a.kind === "Flag"
        ? "flag (present or absent)"
        : a.kind === "Number"
          ? "number"
          : "text"
  return `  ${a.name} — ${kind}${a.description ? ` — ${a.description}` : ""}`
}

const snippetOf = c => {
  const form = formOf(c)
  if (form === "inline") return DirectiveScan.render("Inline", c.directive, "", 'attr="value"')
  const label = isSource(c) ? "storekey" : ""
  const open = DirectiveScan.render("Leaf", c.directive, label, "")
  if (form === "leaf") return open
  return [open, "…body…", DirectiveScan.closing(c.directive)].join("\n")
}

const directiveLine = c =>
  `${c.directive} (${formOf(c)})${c.attributes.length ? ` [${c.attributes.map(a => a.name).join(" ")}]` : ""}${c.description ? ` — ${c.description}` : ""}`

const directiveDetail = c =>
  [
    `${c.directive} — ${formOf(c)}${isSource(c) ? " — SOURCE: [brackets] name the store key it writes to; visible text goes in the body" : ""}`,
    c.description || "",
    c.attributes.length ? `Attributes:\n${c.attributes.map(attrLine).join("\n")}` : "No attributes.",
    `Snippet:\n${snippetOf(c)}`,
  ]
    .filter(Boolean)
    .join("\n\n")

// --- Validation -------------------------------------------------------------
// Everything the compiled core can check without a DOM, each problem with its
// line number. The grammar answers come from the same modules the app uses;
// this function only walks what they return.
const lineOfOffset = (text, offset) => text.slice(0, offset).split("\n").length

// Directives that only mean something inside a given container. `closest()` is
// how the app resolves them, so any ancestor qualifies, not just the parent —
// and an explicit form="id" opts an input or a save out of containment.
const NEEDS_ANCESTOR = {
  input: { inside: ["form"], escape: "form" },
  save: { inside: ["form"], escape: "form" },
  column: { inside: ["table"], escape: null },
  "accordion-item": { inside: ["accordion"], escape: null },
}

// Traps the manifests cannot describe, found by rendering all 92 components:
// each of these validates, renders — and betrays the author at runtime.
const RENDERS_NOTHING = new Set(["grid"]) // described by the manifests, never shipped by the bundle
const FREEZES_OPEN = new Set(["overlay", "dialog-base", "dialog-wrapper", "tray"]) // top layer, no way back
const STORES_NOTHING = {
  switch: 'sp-switch declares no value/checked, so ::switch stores nothing — ::input{type="checkbox"} is the control that does',
  search: 'sp-search declares no value/checked, so ::search stores nothing — ::table{path search} is the search that works',
}

function validate(markdown) {
  const problems = []
  const warnings = []
  const parsed = Frontmatter.parse(markdown)
  const meta = parsed.meta
  // Line numbers are reported against the WHOLE document, so the offset into
  // the body is shifted by however many lines the frontmatter block took.
  const bodyShift = markdown.split("\n").length - parsed.body.split("\n").length

  if (meta === undefined) {
    warnings.push({ line: 1, message: "no frontmatter: the app will get an id derived from its title on import; declare appId/title/description to control it" })
  } else {
    const declared = Frontmatter.get(meta, "appId")
    if (declared === undefined) warnings.push({ line: 1, message: "frontmatter has no appId; one will be derived from the title on import" })
    else if (!AppId.isValid(declared)) problems.push({ line: 1, message: `appId "${declared}" is not valid: lowercase letters, digits and single interior hyphens, up to 64 characters` })
    const lang = Frontmatter.get(meta, "lang")
    if (lang !== undefined && Locale.parse(lang) === undefined)
      warnings.push({ line: 1, message: `lang "${lang}" is not one of the seven supported languages (en fr de es pt zh it); it will be ignored` })
    const icon = Frontmatter.get(meta, "icon")
    if (icon !== undefined && AppDocument.summary("probe", markdown).icon === "")
      warnings.push({ line: 1, message: `icon "${icon}" is not a Spectrum workflow icon name; the default icon will be used` })
  }

  // The scanner reports one level at a time — a container's body is its own to
  // scan — so validation recurses exactly the way the renderer does: check the
  // directives of this level, then descend into each container's body. This is
  // also what puts a line number on an ::input three containers deep.
  const checkLevel = (text, lineBase, ancestors) => {
    const occurrences = DirectiveScan.scan(text)

    for (const occ of occurrences) {
      const line = lineBase + lineOfOffset(text, occ.start)
      const component = DirectiveRegistry.find(occ.name)
      const attrs = DirectiveAttributes.parse(occ.attributes)
      if (component === undefined) {
        problems.push({ line, message: `unknown directive "${occ.name}": it will render as literal text, not as a component` })
      } else {
        const wantsInline = INLINE.has(occ.name)
        if (wantsInline && occ.form !== "Inline")
          problems.push({ line, message: `"${occ.name}" is an inline directive: write it :${occ.name}{…} inside a line of text, not ::${occ.name}` })
        if (!wantsInline && occ.form === "Inline")
          problems.push({ line, message: `"${occ.name}" is a block directive: write ::${occ.name}{…} on its own line` })

        // Containment: a field does not name its form — it sits inside it.
        const containment = NEEDS_ANCESTOR[occ.name]
        if (
          containment &&
          !containment.inside.some(needed => ancestors.includes(needed)) &&
          !(containment.escape && DirectiveAttributes.find(attrs, containment.escape) !== undefined)
        )
          problems.push({ line, message: `::${occ.name} works inside ::${containment.inside[0]} — here it has no ${containment.inside[0]} around it` })

        // The od-* directives render an inline error without these — worth a
        // line number here rather than a red box the model never sees.
        if (occ.name.startsWith("od-")) {
          if (DirectiveAttributes.find(attrs, "into") === undefined)
            problems.push({ line, message: `::${occ.name} needs into="collection" — the rows have to land somewhere a view can read them` })
          if (occ.name === "od-query" && DirectiveAttributes.find(attrs, "sql") === undefined)
            problems.push({ line, message: `::od-query needs sql="SELECT …"` })
        }

        // ::choose renders an inline error without either of these, and the two
        // mistakes are opposite: no brackets and the reader's choice goes nowhere, no
        // path and there is nothing to choose from.
        if (occ.name === "choose") {
          if (occ.label === "")
            problems.push({ line, message: `::choose needs a key, as ::choose[key]{path="…"} — the brackets name the reactive key the choice writes, which is what an ::od-query reads back as {#key}` })
          if (DirectiveAttributes.find(attrs, "path") === undefined)
            problems.push({ line, message: `::choose needs path="collection" — the options are its rows` })
        }

        // A schedule that does not parse leaves the workflow MANUAL, and nothing
        // says so: the attribute is there, the strip draws, the Run button works,
        // and six o'clock never comes. It is the silent-return failure this
        // codebase keeps meeting, so the parser that decides it at runtime — the
        // compiled core, not a second reading of the same string — decides it here.
        if (occ.name === "workflow") {
          const every = DirectiveAttributes.find(attrs, "every")
          if (every !== undefined && WorkflowTrigger.seconds(every) === undefined)
            problems.push({ line, message: `::workflow every="${every}" is not a schedule and would leave this workflow manual — write 15m, 2h, 1d or 90s (anything under 60s is raised to 60s)` })
          const at = DirectiveAttributes.find(attrs, "at")
          if (at !== undefined && WorkflowTrigger.minuteOfDay(at) === undefined)
            problems.push({ line, message: `::workflow at="${at}" is not a time and would leave this workflow manual — write HH:MM in 24 hours, e.g. 18:00 ("18", "6pm" and "18:00:00" are all refused)` })
          const on = DirectiveAttributes.find(attrs, "on")
          if (on !== undefined) {
            const known = WorkflowTrigger.events(on).filter(e =>
              !e.startsWith("save:") && !e.startsWith("change:") && e !== "open")
            if (known.length > 0)
              problems.push({ line, message: `::workflow on="${on}": ${known.join(", ")} is not an event — write save:collection, change:#key or open` })
          }
          // A workflow nobody closed, or one holding nothing that produces data, is
          // a strip that reports on an empty list for ever.
          if (occ.form !== "Container")
            problems.push({ line, message: `::workflow has no steps: it needs a ::/workflow below it with the directives that produce data — ::od-query, ::sql, ::python, ml-* — in between` })
        }

        // The central rule of the language: a leading # marks a reactive
        // reference. :value reads one; a bare store key there never updates.
        if (occ.name === "value") {
          const ref = DirectiveAttributes.find(attrs, "ref")
          if (ref === undefined || !ref.startsWith("#"))
            problems.push({ line, message: `:value reads a reactive reference: ref="#key" with the # — ${ref === undefined ? "there is no ref at all" : `"${ref}" is a bare store key and would never update`}` })
        }

        // :calc evaluates on every keystroke; a malformed expression has no
        // answer at all, which on the page is a directive that shows nothing.
        if (occ.name === "calc") {
          const expr = DirectiveAttributes.find(attrs, "expr")
          if (expr !== undefined && Expr.evaluate(expr, () => "1") === undefined)
            problems.push({ line, message: `:calc expr="${expr}" does not parse (allowed: + - * / parentheses numbers and #keys)` })
        }

        // Traps the manifests cannot describe — each renders fine and betrays
        // the author at runtime, which is exactly what a validator is for.
        if (RENDERS_NOTHING.has(occ.name))
          problems.push({ line, message: `::${occ.name}: sp-${occ.name} is described by Spectrum's manifests but not shipped by the bundle — it never upgrades and draws nothing; use ::columns or ::cards instead` })
        if (FREEZES_OPEN.has(occ.name) && DirectiveAttributes.find(attrs, "open") !== undefined)
          problems.push({ line, message: `::${occ.name} written with \`open\` puts itself in the top layer and freezes the whole app — no click reaches anything and no directive can close it` })
        if (STORES_NOTHING[occ.name]) warnings.push({ line, message: STORES_NOTHING[occ.name] })

        // A Spectrum source written without [brackets] has no store key: the
        // control renders, moves, and writes nowhere.
        if (component.package !== "reactivenet" && isSource(component) && occ.label === "" && !STORES_NOTHING[occ.name])
          warnings.push({ line, message: `::${occ.name} without [storekey] stores nothing: the brackets name the key it writes to` })

        const schema = component.attributes
        for (const attr of attrs) {
          // A `#…` value is a reactive binding and is legal on any attribute —
          // except when it is plainly a hex colour, which the grammar reads as
          // a binding to a key named after the hex digits and silently drops.
          if (/^#[0-9a-fA-F]{3,8}$/.test(attr.value)) {
            problems.push({ line, message: `${occ.name}: "${attr.value}" reads as a reactive #reference, not a colour — hex colours cannot be attribute values; use rgb(…) or a named colour` })
            continue
          }
          if (attr.value.startsWith("#")) continue
          const described = schema.find(a => a.name.toLowerCase() === attr.name.toLowerCase())
          if (!described) {
            problems.push({ line, message: `${occ.name}: unknown attribute "${attr.name}" (it will be ignored). Known: ${schema.map(a => a.name).join(", ") || "none"}` })
            continue
          }
          if (described.kind === "Choice" && !described.choices.includes(attr.value))
            problems.push({ line, message: `${occ.name}: ${attr.name}="${attr.value}" is not allowed; one of: ${described.choices.join(", ")}` })
          if (described.kind === "Number" && (attr.value === "" || Number.isNaN(Number(attr.value))))
            problems.push({ line, message: `${occ.name}: ${attr.name}="${attr.value}" is not a number` })
        }
      }

      // Into the container's body: the span includes its own open and close
      // lines, so the body is what sits between them.
      if (occ.form === "Container") {
        const spanLines = text.slice(occ.start, occ.stop).split("\n")
        const openLine = lineOfOffset(text, occ.start)
        checkLevel(spanLines.slice(1, -1).join("\n"), lineBase + openLine, [...ancestors, occ.name])
      }
    }

    // A close that closes nothing: the scanner treats it as text, which on
    // the page looks like a stray `::/name` line — always a mistake worth a
    // line number. Anything inside a container's span belongs to a deeper
    // level and is judged there by the recursion; at THIS level a close is
    // legitimate only inside some span (its own container's, in particular).
    let offset = 0
    for (const line of text.split("\n")) {
      const close = /^::\/([a-z][a-z0-9-]*)\s*$/.exec(line)
      if (close) {
        const covered = occurrences.some(
          occ => occ.form === "Container" && occ.start <= offset && offset < occ.stop,
        )
        if (!covered)
          problems.push({ line: lineBase + lineOfOffset(text, offset), message: `::/${close[1]} closes nothing: no open ::${close[1]} above it` })
      }
      offset += line.length + 1
    }
  }

  checkLevel(parsed.body, bodyShift, [])
  problems.sort((a, b) => a.line - b.line)
  warnings.sort((a, b) => a.line - b.line)

  return { ok: problems.length === 0, problems, warnings }
}

// The usual conversation validates, fixes, and then asks for the link of the
// SAME text — and the link tool re-validates on principle. The second walk is
// answered from a small insertion-ordered cache instead of re-scanning.
const VALIDATED = new Map()
const validated = markdown => {
  const hit = VALIDATED.get(markdown)
  if (hit) return hit
  const result = validate(markdown)
  VALIDATED.set(markdown, result)
  if (VALIDATED.size > 32) VALIDATED.delete(VALIDATED.keys().next().value)
  return result
}

const problemsText = list => list.map(p => `line ${p.line}: ${p.message}`).join("\n")

const report = ({ ok, problems, warnings }) => {
  const tail = warnings.length ? `\n\nAdvice (does not block):\n${problemsText(warnings)}` : ""
  return ok
    ? `ok — the document is valid.${tail}`
    : `${problems.length} problem(s):\n\n${problemsText(problems)}${tail}`
}

// --- Data-flow analysis -------------------------------------------------------
// validate() judges one directive at a time; analyze() asks whether the pieces
// MEET. Writers and readers of every collection, sources and readers of every
// reactive #key, ids declared and ids pointed at — and the orphans, which are
// the mistakes grammar-level validation cannot see: a ::list over a collection
// nothing writes, a :value over a #key no source feeds, an editform naming a
// form that does not exist. Same recursion as validate(), same compiled core
// underneath; only the read/write semantics of each directive live here.

const COMMA = value => (value || "").split(",").map(s => s.trim()).filter(Boolean)

const SUMMARY_NAMES = ["count", "sum", "avg", "min", "max", "median", "stddev", "mode"]
// path= names a collection these READ. (::geocode also writes it — coordinates
// land back on the rows — and is listed among the writers below.)
const PATH_READERS = new Set([
  "list", "cards", "table", "board", "timetable", "calendar", "if-any", "if-empty",
  "dashboard", "map", "explore", "geocode",
  // ::choose reads a collection to fill its options; that it also WRITES a reactive
  // key is registered among the writers below.
  "choose",
  ...SUMMARY_NAMES,
])
// data= names the collection(s) these read — comma-separated for sql and python.
const DATA_READERS = new Set([
  "python", "sql",
  "ml-cluster", "ml-anomaly", "ml-predict", "ml-correlate", "ml-forecast",
  "chart-bar", "chart-line", "chart-pie", "chart-doughnut", "chart-area", "chart-radar", "chart-scatter",
  // The ai-* family reads its collections by data=, exactly as an engine does.
  // ai-classify is the exception: it names its collection path=, because it works
  // one row at a time the way a view does — and it is a WRITER, listed below.
  "ai-summary", "ai-chat", "ai-agent", "ai-pipeline", "ai-query", "ai-rule",
])
// into= names the collection these WRITE (python spells it writes=).
const INTO_WRITERS = new Set([
  "od-query", "od-search", "od-datasets", "api-query", "sql",
  "ml-cluster", "ml-anomaly", "ml-predict", "ml-correlate", "ml-forecast",
  // ai-query's breakdown and ai-search's hits land in an ordinary collection.
  "ai-query", "ai-search",
])
// A row template can read ANOTHER collection: {who>people.name}.
const RELATION = /\{[A-Za-z0-9_-]+>([a-z0-9][a-z0-9-]*)\.[A-Za-z0-9_-]+\}/g
const TEMPLATED = new Set(["list", "cards", "board", "timetable", "calendar", "map", "table"])
const HEX = /^#[0-9a-fA-F]{3,8}$/

function analyze(markdown) {
  const parsed = Frontmatter.parse(markdown)
  const bodyShift = markdown.split("\n").length - parsed.body.split("\n").length

  const collections = new Map() // name -> {writers: [{dir, line}], readers: [...]}
  const keys = new Map() // key -> {writers, readers}
  const idsDeclared = new Map() // id -> line
  const idRefs = [] // {id, line, directive, attr, wantsForm, savesForm}
  const forms = [] // {path, id, line, saved}
  const bareEditforms = [] // {path, line, directive}

  const edge = (map, name) => {
    let entry = map.get(name)
    if (!entry) {
      entry = { writers: [], readers: [] }
      map.set(name, entry)
    }
    return entry
  }
  const writeC = (name, dir, line) => edge(collections, name).writers.push({ dir, line })
  const readC = (name, dir, line) => edge(collections, name).readers.push({ dir, line })
  const writeK = (name, dir, line) => edge(keys, name).writers.push({ dir, line })
  const readK = (name, dir, line) => edge(keys, name).readers.push({ dir, line })

  const walk = (text, lineBase, formStack) => {
    for (const occ of DirectiveScan.scan(text)) {
      const line = lineBase + lineOfOffset(text, occ.start)
      const attrs = DirectiveAttributes.parse(occ.attributes)
      const get = name => DirectiveAttributes.find(attrs, name)
      const component = DirectiveRegistry.find(occ.name)
      const dir = (occ.form === "Inline" ? ":" : "::") + occ.name

      // A plain #reference on any attribute is a reactive read (a hex colour
      // is validate()'s complaint, not an edge). The attributes that EMBED
      // references in a longer string — a SELECT, a URL, an expression — have
      // their own branch below and are skipped here, or a lone "#a" inside a
      // :calc would be counted twice.
      const embeds = { "od-query": "sql", "api-query": "url", calc: "expr", value: "ref" }
      for (const attr of attrs) {
        if (
          embeds[occ.name] !== attr.name &&
          /^#[A-Za-z0-9_-]+$/.test(attr.value) &&
          !HEX.test(attr.value)
        )
          readK(attr.value.slice(1), dir, line)
        // A view's filter may name a key inside the expression — filter="classe=#sel"
        // — which the binder resolves before it asks RowView anything. It is a read
        // like any other, and only the whole-value case above would have seen it.
        if (attr.name === "filter" && attr.value.includes("#"))
          for (const found of attr.value.matchAll(/#([A-Za-z0-9_-]+)/g)) readK(found[1], dir, line)
      }

      const id = get("id")
      if (id) idsDeclared.set(id, line)
      const path = get("path")
      const plainPath = path !== undefined && path !== "" && !path.startsWith("#") ? path : undefined

      if (PATH_READERS.has(occ.name) && plainPath) readC(plainPath, dir, line)
      if (occ.name === "input" && get("type") === "ref" && plainPath) readC(plainPath, dir, line)
      if (DATA_READERS.has(occ.name))
        for (const p of COMMA(get("data"))) if (!p.startsWith("#")) readC(p, dir, line)
      if (INTO_WRITERS.has(occ.name)) {
        const into = get("into")
        if (into) writeC(into, dir, line)
      }
      if (occ.name === "python") {
        const writes = get("writes")
        if (writes) writeC(writes, dir, line)
      }
      if (occ.name === "geocode" && plainPath) writeC(plainPath, dir, line)
      // ai-classify writes one declared field back into the rows it read; ai-rule
      // and ai-pipeline do the same to the collection in data=. They are writers of
      // that collection, which is what keeps "who owns this" answerable — but they
      // are not its OWNER the way a ::python{writes} is: they change one field of
      // rows that are already there, so a form on the same path is not a conflict.
      if (occ.name === "ai-classify" && plainPath) {
        readC(plainPath, dir, line)
        writeC(plainPath, dir + " field", line)
      }
      if (occ.name === "ai-rule" || occ.name === "ai-pipeline") {
        const data = get("data")
        if (data && !data.startsWith("#")) writeC(data, dir + " field", line)
      }
      // rag= names collection.field pairs the semantic index READS.
      {
        const rag = get("rag")
        if (rag) {
          for (const entry of COMMA(rag)) {
            const dot = entry.indexOf(".")
            if (dot > 0) readC(entry.slice(0, dot), dir + " rag", line)
          }
        }
      }
      // The draft-fillers point at a FORM, which is an id reference like any other.
      if (["ai-assist", "ai-extract", "ai-field", "ai-suggest", "ai-vision",
           "ai-translate", "ai-rewrite"].includes(occ.name)) {
        const form = get("form")
        if (form) idRefs.push({ id: form, line, directive: dir, attr: "form", wantsForm: true })
        if (occ.name === "ai-suggest" && plainPath) readC(plainPath, dir, line)
        const source = get("source")
        if (source && source.startsWith("#")) readK(source.slice(1), dir, line)
      }
      // A timetable READS its forbidden cells and WRITES the two fields it drags —
      // into the same collection it reads, which is why only blocked= is extra here.
      if (occ.name === "timetable") {
        const blocked = get("blocked")
        if (blocked) readC(blocked, dir + " blocked", line)
        if (plainPath) writeC(plainPath, dir + " drag", line)
      }
      // ::python params= names reactive keys the code reads as params["name"].
      if (occ.name === "python")
        for (const k of COMMA(get("params"))) if (!k.startsWith("#")) readK(k, dir, line)
      // A workflow WATCHES what starts it: on="save:spese" is a read of that
      // collection and on="change:#anno" a read of that key. Registering them keeps
      // the graph honest — a collection whose only reader is the trigger of a
      // workflow is read, and reporting it as orphaned would send somebody to fix
      // what is already wired.
      if (occ.name === "workflow") {
        const on = get("on")
        if (on) {
          for (const watched of WorkflowTrigger.saves(on)) readC(watched, dir + " on", line)
          for (const key of WorkflowTrigger.changes(on)) readK(key, dir + " on", line)
        }
      }
      // ::print{repeat} reads that collection and WRITES the key it sets per row.
      if (occ.name === "print") {
        const repeat = get("repeat")
        if (repeat) readC(repeat, dir + " repeat", line)
        const key = get("key")
        if (repeat && key) writeK(key.startsWith("#") ? key.slice(1) : key, dir, line)
      }
      if (occ.name === "form" && plainPath) {
        writeC(plainPath, dir, line)
        // Registered even for a leaf ::form — pointless, but declared, and the
        // no-save finding below is exactly what such a form deserves.
        var formEntry = { path: plainPath, id: id || null, line, saved: false }
        forms.push(formEntry)
      }
      if (occ.name === "save") {
        const formId = get("form")
        if (formId) idRefs.push({ id: formId, line, directive: dir, attr: "form", wantsForm: true, savesForm: true })
        else if (formStack.length > 0) formStack[formStack.length - 1].saved = true
        else if (plainPath) writeC(plainPath, dir, line)
      }

      // Ids pointed at: fields adopted by a form written elsewhere, a
      // calendar's day-click form, a print button's target, an editform.
      if (["input", "file", "geo", "calendar"].includes(occ.name)) {
        const formId = get("form")
        if (formId) idRefs.push({ id: formId, line, directive: dir, attr: "form", wantsForm: true })
      }
      if (occ.name === "print") {
        const target = get("target")
        if (target && !target.startsWith("#"))
          idRefs.push({ id: target, line, directive: dir, attr: "target", wantsForm: false })
      }
      // A bare flag parses as "true", and the binder reads "true" as bare:
      // editform without a value means "the form on this same path".
      const editform = get("editform")
      if (editform !== undefined && editform !== "true" && editform !== "")
        idRefs.push({ id: editform, line, directive: dir, attr: "editform", wantsForm: true })
      if ((editform === "true" || editform === "") && plainPath)
        bareEditforms.push({ path: plainPath, line, directive: dir })

      // Key reads hiding inside strings: SQL text, API urls, expressions.
      if (occ.name === "od-query") for (const k of OdQuery.references(get("sql") || "")) readK(k, dir, line)
      if (occ.name === "api-query") for (const k of OdQuery.references(get("url") || "")) readK(k, dir, line)
      if (occ.name === "calc") for (const k of Expr.references(get("expr") || "")) readK(k, dir, line)
      if (occ.name === "value") {
        const ref = get("ref")
        if (ref && ref.startsWith("#")) readK(ref.slice(1), dir, line)
      }

      // Key writers: a source component with [brackets] writes that key, and
      // so do the two scalar forms of api-query and geocode.
      if (component && component.package !== "reactivenet" && isSource(component) && occ.label)
        writeK(occ.label, dir, line)
      if (occ.name === "api-query" && occ.label && get("into") === undefined) writeK(occ.label, dir, line)
      // ::choose is the one directive of OUR package that is a source, so the rule
      // above — which asks the Spectrum manifest whether a component carries value or
      // checked — cannot see it. Without this line the analyzer would report the key
      // it feeds as written by nobody, which is precisely the finding this directive
      // exists to make impossible.
      if (occ.name === "choose" && occ.label) writeK(occ.label, dir, line)
      if (occ.name === "geocode" && occ.label && get("value") !== undefined) writeK(occ.label, dir, line)

      if (occ.form === "Container") {
        const body = text.slice(occ.start, occ.stop).split("\n").slice(1, -1).join("\n")
        // ::sql reads its keys from the fenced SELECT, not from an attribute.
        if (occ.name === "sql") for (const k of OdQuery.references(body)) readK(k, dir, line)
        if (TEMPLATED.has(occ.name))
          for (const m of body.matchAll(RELATION)) readC(m[1], dir + " row template", line)
        const openLine = lineOfOffset(text, occ.start)
        walk(
          body,
          lineBase + openLine,
          occ.name === "form" && plainPath ? [...formStack, formEntry] : formStack,
        )
      }
    }
  }

  walk(parsed.body, bodyShift, [])

  // chat: true in the frontmatter is a writer nobody spells in the body — the
  // panel stores messages as rows of the collection named "chat".
  if (AppDocument.summary("probe", markdown).chat) writeC("chat", "the chat panel (frontmatter chat: true)", 1)

  // A ::save{form="id"} saves the form carrying that id.
  for (const ref of idRefs)
    if (ref.savesForm) {
      const form = forms.find(f => f.id === ref.id)
      if (form) form.saved = true
    }

  const describe = list => list.map(e => `${e.dir} (line ${e.line})`).join(", ")
  const findings = []

  for (const [name, { writers, readers }] of collections) {
    if (readers.length && !writers.length)
      findings.push({
        line: readers[0].line,
        message: `collection "${name}" is read by ${describe(readers)} but nothing in this document writes it — the view stays empty unless the rows arrive from outside (a CSV/Excel import, a linked space, an earlier version of the app)`,
      })
    if (writers.length && !readers.length && name !== "chat")
      findings.push({
        line: writers[0].line,
        message: `collection "${name}" is written by ${describe(writers)} but nothing reads it — is a view missing, or is the name misspelt in the view that should?`,
      })
  }
  for (const form of forms) {
    const engines = (collections.get(form.path)?.writers || []).filter(
      // A drag is not an engine: ::timetable rewrites two fields of ONE row, the way
      // ::save rewrites the row it is editing. Nor is an ai-* that fills a field —
      // classify, rule and pipeline write ONE declared field of rows that are
      // already there, and are meant to sit on the same collection as the form.
      // What this finding is about is an engine whose into= replaces the whole
      // collection on every run.
      w =>
        w.dir !== "::form" &&
        w.dir !== "::save" &&
        !w.dir.endsWith(" drag") &&
        !w.dir.endsWith(" field") &&
        !w.dir.startsWith("the chat"),
    )
    for (const w of engines)
      findings.push({
        line: w.line,
        message: `${w.dir} writes into "${form.path}", the same collection the ::form at line ${form.line} saves rows to — every run of the engine REPLACES the rows people saved; give the engine its own into=`,
      })
    if (!form.saved)
      findings.push({
        line: form.line,
        message: `the ::form on "${form.path}" has no ::save inside it and no ::save points at it with form= — nothing can ever write the row`,
      })
  }
  for (const [name, { writers, readers }] of keys) {
    if (readers.length && !writers.length)
      findings.push({
        line: readers[0].line,
        // ::choose comes first among the examples because it is the answer whenever
        // the key is read by a query: what steers an od-query is almost always a
        // choice among rows, not a slider.
        message: `#${name} is read by ${describe(readers)} but no source writes it — it will never update (a source is a control written ::name[${name}], e.g. ::choose[${name}]{path="…"} to pick it from a collection, or ::slider[${name}] / ::checkbox[${name}])`,
      })
    if (writers.length && !readers.length)
      findings.push({
        line: writers[0].line,
        message: `${describe(writers)} writes #${name} but nothing reads it — a :value{ref="#${name}"}, a :calc, or a {#${name}} placeholder would`,
      })
  }
  for (const ref of idRefs) {
    if (ref.wantsForm && !forms.some(f => f.id === ref.id))
      findings.push({
        line: ref.line,
        message: `${ref.directive} ${ref.attr}="${ref.id}" names a form id, and no ::form carries id="${ref.id}"`,
      })
    if (!ref.wantsForm && !idsDeclared.has(ref.id))
      findings.push({
        line: ref.line,
        message: `${ref.directive} ${ref.attr}="${ref.id}" points at an id no directive declares`,
      })
  }
  for (const bare of bareEditforms)
    if (!forms.some(f => f.path === bare.path))
      findings.push({
        line: bare.line,
        message: `${bare.directive} has a bare editform, which means "the form on ${bare.path}" — and there is no ::form on that path`,
      })

  findings.sort((a, b) => a.line - b.line)

  const sorted = map => [...map].sort((a, b) => a[0].localeCompare(b[0]))
  const asEdges = list => list.map(e => ({ directive: e.dir, line: e.line }))
  const structured = {
    collections: sorted(collections).map(([name, { writers, readers }]) => ({
      name,
      writers: asEdges(writers),
      readers: asEdges(readers),
    })),
    keys: sorted(keys).map(([name, { writers, readers }]) => ({
      name,
      writers: asEdges(writers),
      readers: asEdges(readers),
    })),
    ids: [...idsDeclared.keys()].sort(),
    findings,
  }

  const lines = ["Collections:"]
  if (collections.size === 0) lines.push("  none — this document stores nothing")
  for (const [name, { writers, readers }] of sorted(collections))
    lines.push(
      `  ${name} — written by: ${writers.length ? describe(writers) : "NOTHING"}; read by: ${readers.length ? describe(readers) : "NOTHING"}`,
    )
  lines.push("", "Reactive keys:")
  if (keys.size === 0) lines.push("  none")
  for (const [name, { writers, readers }] of sorted(keys))
    lines.push(
      `  #${name} — written by: ${writers.length ? describe(writers) : "NOTHING"}; read by: ${readers.length ? describe(readers) : "NOTHING"}`,
    )
  if (idsDeclared.size > 0)
    lines.push("", `Ids declared: ${[...idsDeclared.keys()].sort().join(", ")}`)
  lines.push(
    "",
    findings.length
      ? `${findings.length} finding(s):\n${problemsText(findings)}`
      : "No orphans: every view has a writer, every #ref a source, every id points at something.",
  )
  return { text: lines.join("\n"), structured }
}

// --- Examples ---------------------------------------------------------------
// The two documents the app itself starts people with: the welcome app (a
// working example of every kind of directive, the app's own regression test)
// and the blank starter (a form, a list, and the empty state in between).
const localeOf = tag => Locale.parse(tag || "en") ?? "En"
const today = () => new Date().toISOString().slice(0, 10)

const EXAMPLES = {
  welcome: lang => AppDocument.welcome(localeOf(lang), today()),
  starter: lang => AppDocument.blank("example", "Example", today(), localeOf(lang)),
}

// The task-shaped recipes: complete, validated documents for the apps people
// actually ask for — adapting one beats assembling directives by hand, and
// two examples were too few to adapt from. One file each under mcp/examples/;
// dropping a new .md there adds it to the tool with no code change (the smoke
// test validates and analyzes every one of them).
const RECIPES = Object.fromEntries(
  readdirSync(join(HERE, "examples"))
    .filter(f => f.endsWith(".md"))
    .sort()
    .map(f => [f.slice(0, -3), readFileSync(join(HERE, "examples", f), "utf8")]),
)
const EXAMPLE_NAMES = ["welcome", "starter", ...Object.keys(RECIPES)]

// Every read-only answer ends by saying what to do with it. That sentence is not
// decoration: benched against real models (`scripts/bench-assistant.mjs`), a 4B
// asked for a shopping-list app read the examples, read the catalogue three
// times, and then stopped and talked — nothing in a reference answer says the
// turn is not over, so a small model keeps reading. Delivery is named neutrally
// because who delivers depends on the client: the app's assistant has its own
// reactive_create_app, a connector has reactive_app_link.
const NEXT_STEP =
  "\n\n---\nNext: write the COMPLETE document (frontmatter and body), then deliver it — " +
  "reactive_create_app if you have it, otherwise reactive_app_link. Looking things up is " +
  "not delivering; a turn that ends here has produced nothing. Validation happens at " +
  "delivery and tells you what to fix, so you do not need to be certain first."

// --- The open-data catalog ----------------------------------------------------
// What reactive_analyze cannot know: whether `provincia` is a column of
// `farmacie`. The od service can answer, with one same-machine fetch, and a
// model that consults the catalog writes its SELECT against the columns that
// exist instead of the ones it guesses.
let odCache = { at: 0, datasets: null }
const odDatasets = async () => {
  if (odCache.datasets && Date.now() - odCache.at < 60_000) return odCache.datasets
  const response = await fetch(`${OD_URL}/datasets`, { signal: AbortSignal.timeout(4000) })
  if (!response.ok) throw new Error(`the open-data service answered ${response.status}`)
  const { datasets } = await response.json()
  for (const d of datasets)
    if (typeof d.columns === "string") {
      try {
        d.columns = JSON.parse(d.columns)
      } catch {
        d.columns = []
      }
    }
  odCache = { at: Date.now(), datasets }
  return datasets
}

// Running a query, not just reading the schema. The catalogue answers "is there a
// column called regione"; only this answers "does regione ever hold 'PUGLIA'" — and
// that second question is where od-queries actually die. A SELECT that names real
// columns, parses, runs and returns NOTHING is indistinguishable from success from
// anywhere except here: the app then paints empty cards over a filter nobody can see
// is wrong. It cost a whole regional dashboard once, on `regione='PUGLIA'` against a
// column holding 'Puglia'.
//
// No new power is being handed out: the service already refuses anything but a single
// SELECT (it parses the statement and checks the AST), caps the rows and interrupts on
// a timeout, and any document in any browser can already run od-queries against it.
// What is new is only that the model can look before it writes.
const odRun = async (sql, limit) => {
  let response
  try {
    response = await fetch(`${OD_URL}/query`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sql, limit }),
      signal: AbortSignal.timeout(20000),
    })
  } catch {
    // The fetch itself failed: there is no service to have an opinion about the SQL.
    // Told apart HERE rather than by reading the message afterwards, because the two
    // need different sentences and matching words would classify them by accident.
    return { unreachable: true }
  }
  const body = await response.json().catch(() => null)
  if (!response.ok) return { refused: body?.message || `the service answered ${response.status}` }
  return body
}

// A tool result is read by a model with a finite window, so the answer is a shape and
// a sample, never a dump: the question being asked is "does this return sensible
// rows", and five of them answer it as well as five hundred.
//
// The interesting part is not the sample, it is the two ways a query comes back
// EMPTY, because both look like success and only one of them looks empty:
//
//   - no rows at all, from a plain SELECT whose WHERE matched nothing;
//   - ONE row full of nulls, from an aggregate — `sum()` over nothing is null and
//     `count(*)` over nothing is 0, so `SELECT sum(popolazione), count(*)` answers
//     `{popolazione: null, comuni: 0}` and reports one row.
//
// The second is the one that actually happens, because a dashboard's headline figures
// are exactly that shape. Reported as "1 row" it reads as a working query, and the app
// then paints a card saying "null abitanti in 0 comuni" with nothing anywhere saying
// why. Both get the same diagnosis, because both have the same cause.
const emptyish = value => value === null || value === undefined || value === "" || value === 0 || value === "0"

const odDiagnosis = rows => {
  if (rows.length === 0) return "The query ran and returned NO ROWS."
  const allNull = rows.every(row => Object.values(row).every(v => v === null || v === undefined))
  const oneEmpty = rows.length === 1 && Object.values(rows[0]).every(emptyish)
  if (!allNull && !oneEmpty) return null
  return rows.length === 1 && !allNull
    ? "The query ran and returned ONE ROW IN WHICH EVERYTHING IS NULL OR ZERO — an aggregate over an empty set. It counted nothing."
    : "The query ran and returned rows with nothing in them."
}

const odSample = result => {
  const columns = (result.columns || []).map(c => `${c.name} (${c.type})`).join(", ")
  const rows = result.rows || []
  const empty = odDiagnosis(rows)
  if (empty) {
    return [
      empty,
      "",
      `Columns: ${columns || "(none)"}`,
      // Only this line is conditional; the blank ones around it are the paragraphing.
      ...(rows.length ? [`Row: ${JSON.stringify(rows[0])}`] : []),
      "",
      "THIS IS A BROKEN QUERY, not a result. It is the failure that looks like success:",
      "the app will render cards reading 'null' and charts with nothing in them, and no",
      "error will appear anywhere. Do not write it into the document.",
      "",
      "The cause is almost never the column names — those are checked when the SQL is",
      "parsed, and this parsed. It is a WHERE that matches nothing. Comparisons are",
      "CASE-SENSITIVE, so regione='PUGLIA' finds nothing in a column holding 'Puglia'.",
      "Look at the values themselves before changing anything else:",
      "",
      "  SELECT DISTINCT regione FROM <table> ORDER BY 1",
      "  SELECT max(anno) FROM <table>",
    ].join("\n")
  }
  const shown = rows.map((row, i) => `${i + 1}. ${JSON.stringify(row)}`).join("\n")
  return [
    `The query ran and returned ${rows.length} row${rows.length === 1 ? "" : "s"}` +
      (result.truncated ? " (cut at the limit — there are more)" : "") + ".",
    "",
    `Columns: ${columns}`,
    "",
    shown,
    "",
    "If these values are what the app should show, the SELECT is ready to paste into",
    "::od-query{into=\"…\" sql=\"…\"}. Mind the quoting: the SQL rides inside a directive",
    "attribute, so use single quotes inside it and never a double quote.",
  ].join("\n")
}

const OD_UNREACHABLE =
  `The open-data service is not reachable at ${OD_URL} (locally: bun run od). ` +
  "Apps using ::od-query can still be written and delivered — at runtime the binder " +
  "shows the last fetched rows with a stale notice when the service is away — but " +
  "table and column names cannot be checked from here right now."

const odDatasetLine = d => `${d.table_name} — ${d.title_it || d.title_en} (${d.row_count} rows)`

const odDatasetDetail = d =>
  [
    `${d.table_name} — ${d.title_it || d.title_en}`,
    d.description_it || d.description_en || "",
    `Source: ${d.source}${d.url ? ` — ${d.url}` : ""} — updated ${d.updated} — ${d.row_count} rows.`,
    `Columns:\n${(d.columns || []).map(c => `  ${c.name} (${c.type})`).join("\n")}`,
    `Snippet:\n::od-query{into="${d.table_name}_sel" sql="SELECT * FROM ${d.table_name} LIMIT 100"}`,
  ]
    .filter(Boolean)
    .join("\n\n")

// --- Tool definitions -------------------------------------------------------
// Names and descriptions in ENGLISH: they are text addressed to the MODEL.
function buildMcpServer() {
  const server = new McpServer({ name: "reactivenet", version: "2.0.0" })

  server.registerTool(
    "reactive_guide",
    {
      title: "ReactiveNET documentation",
      description:
        "The authoritative documentation of the ReactiveNET platform and its Markdown directive " +
        "language. Call with no argument first for the index, then request what you need by " +
        "document name (e.g. 'language') or section title (e.g. 'frontmatter'). Always consult " +
        "this before writing an app: the directive syntax is specific and cannot be guessed.",
      annotations: { readOnlyHint: true, openWorldHint: false },
      inputSchema: {
        section: z
          .string()
          .optional()
          .describe("Document name (e.g. 'language') or part of a section title. Omit for the index."),
      },
    },
    async ({ section }) => {
      if (!section)
        return { content: [{ type: "text", text: `ReactiveNET documentation — request a document or a section:\n\n${GUIDE_INDEX}` }] }
      const found = findGuide(section)
      return {
        content: [{ type: "text", text: found ?? `Nothing matches "${section}". Available:\n\n${GUIDE_INDEX}` }],
      }
    },
  )

  server.registerTool(
    "reactive_directives",
    {
      title: "ReactiveNET directive catalogue",
      description:
        `The ${COMPONENTS.length} directives — ReactiveNET's own data directives plus the Adobe ` +
        "Spectrum components — with form (inline / leaf / leaf-or-container) and typed attributes. " +
        "Use `name` for one directive's detail and snippet, `search` to filter, `kind` for one form. " +
        "Blocks open `::name{…}` on their own line; a `::/name` below makes the block a container. " +
        "A leading # in an attribute value binds it to a reactive key.",
      annotations: { readOnlyHint: true, openWorldHint: false },
      inputSchema: {
        name: z.string().optional().describe("Exact directive name, e.g. 'table'."),
        search: z.string().optional().describe("Substring matched against name and description."),
        kind: z.enum(["inline", "leaf", "container"]).optional().describe("Keep only this form."),
      },
    },
    async ({ name, search, kind }) => {
      if (name) {
        const c = COMPONENTS.find(x => x.directive === name)
        return {
          content: [{ type: "text", text: (c ? directiveDetail(c) + NEXT_STEP : `Unknown directive "${name}". Call without arguments for the list.`) }],
        }
      }
      let list = COMPONENTS
      if (kind) list = list.filter(c => formOf(c).includes(kind))
      if (search) {
        const q = search.toLowerCase()
        list = list.filter(c => c.directive.includes(q) || (c.description || "").toLowerCase().includes(q))
      }
      return {
        content: [{ type: "text", text: list.length ? `${list.length} directives:\n\n${list.map(directiveLine).join("\n")}` : "No directive matches." }],
      }
    },
  )

  server.registerTool(
    "reactive_examples",
    {
      title: "Complete example apps",
      description:
        "Complete, working documents to start from — adapting one is far more reliable than " +
        "assembling directives by hand. 'welcome' (the app's own tour — one of every kind of " +
        "directive) and 'starter' (the minimal app: a form, a list, the empty state) come in " +
        "seven languages. The recipes are task-shaped (in Italian; translate as needed): " +
        `${Object.keys(RECIPES).join(", ")}.`,
      annotations: { readOnlyHint: true, openWorldHint: false },
      inputSchema: {
        name: z.enum(EXAMPLE_NAMES).describe("Which example."),
        lang: z.enum(["en", "fr", "de", "es", "pt", "zh", "it"]).optional().describe("Language of welcome/starter (default en); recipes ignore it."),
      },
    },
    async ({ name, lang }) => ({
      content: [{ type: "text", text: (EXAMPLES[name] ? EXAMPLES[name](lang) : RECIPES[name]) + NEXT_STEP }],
    }),
  )

  server.registerTool(
    "reactive_od_catalog",
    {
      title: "Open-data catalog",
      description:
        "The datasets of the open-data service that ::od-query reads — Italian public data: " +
        "ISTAT, schools, pharmacies, vehicles, public contracts and more. Call with no argument " +
        "for the list, `search` to filter it, `table` for one dataset's columns with their " +
        "types and a ready snippet. ALWAYS check the columns here before writing an od-query " +
        "SELECT: a column that does not exist is the most common way an od-query fails.",
      annotations: { readOnlyHint: true, openWorldHint: true },
      inputSchema: {
        table: z.string().optional().describe("Exact table name, e.g. 'farmacie', for its columns and detail."),
        search: z.string().optional().describe("Substring matched against names, titles and descriptions."),
      },
    },
    async ({ table, search }) => {
      let datasets
      try {
        datasets = await odDatasets()
      } catch {
        return { content: [{ type: "text", text: OD_UNREACHABLE }] }
      }
      if (table) {
        const d = datasets.find(x => x.table_name === table)
        return {
          content: [{ type: "text", text: d ? odDatasetDetail(d) : `No dataset is named "${table}". Call without arguments for the list.` }],
        }
      }
      let list = datasets
      if (search) {
        const q = search.toLowerCase()
        list = list.filter(d =>
          [d.table_name, d.title_it, d.title_en, d.description_it, d.description_en]
            .some(s => (s || "").toLowerCase().includes(q)),
        )
      }
      return {
        content: [{
          type: "text",
          text: list.length
            ? `${list.length} datasets:\n\n${list.map(odDatasetLine).join("\n")}`
            : "No dataset matches.",
        }],
      }
    },
  )

  server.registerTool(
    "reactive_od_query",
    {
      title: "Try an open-data query",
      description:
        "RUN a SELECT against the open-data warehouse and see what comes back — the rows, " +
        "not the schema. Use it on every od-query SELECT before writing it into a document, " +
        "and use it to look up the VALUES a column actually holds " +
        "(SELECT DISTINCT regione FROM istat_indicatori) — comparisons are case-sensitive, " +
        "so regione='PUGLIA' matches nothing where the column holds 'Puglia'. A query that " +
        "returns no rows is the one failure the app cannot report: it paints empty cards and " +
        "says nothing is wrong. Only SELECT is accepted, and the answer is a small sample.",
      annotations: { readOnlyHint: true, openWorldHint: true },
      inputSchema: {
        sql: z
          .string()
          .describe("One SELECT, exactly as it will be written in the directive but without the {#key} placeholders — put a literal value in their place to try it."),
        limit: z
          .number()
          .int()
          .min(1)
          .max(20)
          .optional()
          .describe("How many sample rows to return (default 5, max 20)."),
      },
    },
    async ({ sql, limit }) => {
      const result = await odRun(sql, Math.min(Math.max(1, limit ?? 5), 20))
      if (result.unreachable) return { content: [{ type: "text", text: OD_UNREACHABLE }] }
      // The service's own complaint is far more useful than a summary of it: it names
      // the column it could not resolve, or the syntax it choked on.
      if (result.refused) {
        return {
          content: [{
            type: "text",
            // What to do next depends on what was wrong, and only the message above
            // knows — so both ways out are offered rather than one asserted. Telling
            // somebody to check the columns when they wrote a DROP sends them to look
            // in the wrong place, which is worse than saying nothing.
            text: `The query was refused:\n\n${result.refused}\n\n` +
              "If it names a column, call reactive_od_catalog for the table's real ones. " +
              "Only a single SELECT is accepted — no DDL, no multiple statements.",
          }],
        }
      }
      return { content: [{ type: "text", text: odSample(result) }] }
    },
  )

  server.registerTool(
    "reactive_validate",
    {
      title: "Validate a ReactiveNET document",
      description:
        "Checks the document with the app's own compiled grammar — the same scanner, registry and " +
        "attribute parser the app runs — and reports every problem with its line number. ALWAYS " +
        "call this before giving an app to the user, and fix what it reports until it returns ok.",
      annotations: { readOnlyHint: true, openWorldHint: false },
      inputSchema: {
        markdown: z.string().describe("The complete document, frontmatter included."),
      },
      outputSchema: {
        ok: z.boolean(),
        problems: z.array(z.object({ line: z.number(), message: z.string() })),
        warnings: z.array(z.object({ line: z.number(), message: z.string() })),
      },
    },
    async ({ markdown }) => {
      const result = validated(markdown)
      return { content: [{ type: "text", text: report(result) }], structuredContent: result }
    },
  )

  server.registerTool(
    "reactive_analyze",
    {
      title: "Data-flow analysis of a ReactiveNET document",
      description:
        "What validation cannot see one directive at a time: whether the pieces MEET. Reports " +
        "which directives write each collection and which read it, which sources write each " +
        "reactive #key and which views read it, the ids declared and pointed at — and the " +
        "orphans: a view over a collection nothing writes (stays empty), a #ref no source " +
        "feeds (never updates), a form nothing can save, an engine writing over a form's rows, " +
        "an editform/form/target id that does not exist. Call it after reactive_validate on " +
        "any app with forms, engines, charts or #refs, and fix what it reports.",
      annotations: { readOnlyHint: true, openWorldHint: false },
      inputSchema: {
        markdown: z.string().describe("The complete document, frontmatter included."),
      },
      outputSchema: {
        collections: z.array(z.object({
          name: z.string(),
          writers: z.array(z.object({ directive: z.string(), line: z.number() })),
          readers: z.array(z.object({ directive: z.string(), line: z.number() })),
        })),
        keys: z.array(z.object({
          name: z.string(),
          writers: z.array(z.object({ directive: z.string(), line: z.number() })),
          readers: z.array(z.object({ directive: z.string(), line: z.number() })),
        })),
        ids: z.array(z.string()),
        findings: z.array(z.object({ line: z.number(), message: z.string() })),
      },
    },
    async ({ markdown }) => {
      const { text, structured } = analyze(markdown)
      return { content: [{ type: "text", text }], structuredContent: structured }
    },
  )

  server.registerTool(
    "reactive_app_link",
    {
      title: "Build the app link",
      description:
        "Validates the document and turns it into a share link the user opens to add the app to " +
        "their ReactiveNET gallery (it lands as a copy, never overwriting anything). This is how " +
        "you deliver a finished app. Refuses documents that do not validate. A big document does " +
        "not fit in a link's fragment: call again with store=true to seal it and deposit it on " +
        "the share server, which answers with a short link.",
      annotations: { readOnlyHint: true, openWorldHint: false },
      inputSchema: {
        markdown: z.string().describe("The complete document, frontmatter included."),
        store: z
          .boolean()
          .optional()
          .describe(
            "Deposit the ENCRYPTED document on the share server and return a short link. " +
              "Only do this when the plain link is refused for size, or when the user asks " +
              "for a short link: it puts data on a server, and the fragment form does not.",
          ),
      },
    },
    async ({ markdown, store }) => {
      const result = validated(markdown)
      if (!result.ok)
        return {
          isError: true,
          content: [{ type: "text", text: `The document does not validate, so no link was built. Fix these and retry:\n\n${problemsText(result.problems)}` }],
        }
      const payload = await SharePayload.encode(markdown)

      // The short link. The document is sealed HERE and the key never leaves this
      // answer: what reaches the share server is a blob it cannot read, exactly as
      // when a browser makes one. That is the whole reason a short link is allowed
      // to exist at all, and it does not change because the sealing happened in a
      // tool rather than in a tab.
      if (store) {
        const key = await ShareCrypto.generateKey()
        const sealed = await ShareCrypto.encrypt(key, payload)
        if (!ShareLink.fitsStored(sealed))
          return {
            isError: true,
            content: [{
              type: "text",
              text:
                `Sealed, the document is ${sealed.length} characters and the share server accepts ` +
                `${ShareLink.storedCeiling}. Split the app, or hand the user the Markdown to save as ` +
                `a .md file and import from the gallery — a file has no ceiling.`,
            }],
          }
        let id = null
        try {
          const response = await fetch(`${PB_URL}/api/collections/shares/records`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ payload: sealed }),
            signal: AbortSignal.timeout(6000),
          })
          if (response.ok) {
            const record = await response.json()
            if (typeof record.id === "string" && record.id !== "") id = record.id
          }
        } catch {
          // An unreachable server is one answer, not an exception: the caller has a
          // second road, and it is the one that needs no server at all.
        }
        if (id === null)
          return {
            isError: true,
            content: [{
              type: "text",
              text:
                `The share server did not answer at ${PB_URL} (locally: bun run pb), so no short ` +
                `link was made. Hand the user the Markdown to save as a .md file and import from ` +
                `the gallery — that road needs no server.`,
            }],
          }
        return {
          content: [{
            type: "text",
            text:
              `The app is valid and stored. Give the user this link — opening it adds the app to ` +
              `their ReactiveNET gallery:\n\n${ShareLink.shortOf(APP_URL, id, key)}\n\n` +
              `The document is encrypted; the key is the part after the # and is never sent to the ` +
              `server, so the whole link has to travel together. The share is deleted 120 days ` +
              `after it was last opened.`,
          }],
        }
      }

      if (!ShareLink.fits(payload))
        return {
          isError: true,
          content: [{
            type: "text",
            text:
              `The document is valid but too big for a link (${payload.length} characters of payload, ` +
              `ceiling ${ShareLink.ceiling}: past that, messaging apps truncate the URL and a truncated ` +
              `link would import half a document). Call this tool again with store=true to seal the ` +
              `document and deposit it on the share server, which answers with a short link; or hand ` +
              `the user the Markdown to save as a .md file and import from the gallery.`,
          }],
        }
      const link = ShareLink.of_(APP_URL, payload)
      return {
        content: [{ type: "text", text: `The app is valid. Give the user this link — opening it adds the app to their ReactiveNET gallery:\n\n${link}` }],
      }
    },
  )

  // --- Resources: the guide documents, addressable by URI --------------------
  // The same text reactive_guide serves, exposed the way MCP clients browse and
  // pin context: eight documents, stable URIs, markdown.
  for (const doc of guide)
    server.registerResource(
      `guide-${doc.name}`,
      `reactive://guide/${doc.name}`,
      { title: `ReactiveNET guide: ${doc.name}`, description: doc.blurb, mimeType: "text/markdown" },
      async uri => ({ contents: [{ uri: uri.href, mimeType: "text/markdown", text: doc.text }] }),
    )

  // --- Prompts: the two workflows, packaged -----------------------------------
  server.registerPrompt(
    "build-app",
    {
      title: "Write a ReactiveNET app",
      description:
        "Turns a request in plain words into a delivered ReactiveNET app, walking the " +
        "workflow this server's tools are built for.",
      argsSchema: {
        request: z.string().describe("What the app should do, in the user's own words."),
        lang: z.string().optional().describe("Language of the app's text (default: the request's language)."),
      },
    },
    ({ request, lang }) => ({
      messages: [{
        role: "user",
        content: {
          type: "text",
          text: [
            `Write a ReactiveNET app for this request: ${request}`,
            "",
            `Write the document's visible text in ${lang || "the language of the request"}.`,
            "",
            "Follow this workflow, in order:",
            "1. Call reactive_guide with no argument, then read the 'language' document and whatever sections the request needs.",
            "2. Call reactive_examples and start from the closest one (starter, or a recipe) rather than assembling directives by hand.",
            "3. If the app reads Italian open data, call reactive_od_catalog for the table's columns, then RUN each SELECT with reactive_od_query and check it returns rows — a query that returns none renders an app of empty cards and reports nothing.",
            "4. Write the complete document, frontmatter included (appId, title, description, lang).",
            "5. Call reactive_validate and fix every problem until it answers ok.",
            "6. Call reactive_analyze and fix every finding: a view over a collection nothing writes, a #ref no source feeds, a form nothing can save.",
            "7. Call reactive_app_link and give the user the link — opening it adds the app to their gallery.",
          ].join("\n"),
        },
      }],
    }),
  )

  server.registerPrompt(
    "review-app",
    {
      title: "Review a ReactiveNET document",
      description: "Validates and analyzes an existing document and reports what to fix, with line numbers.",
      argsSchema: {
        markdown: z.string().describe("The complete document to review, frontmatter included."),
      },
    },
    ({ markdown }) => ({
      messages: [{
        role: "user",
        content: {
          type: "text",
          text: [
            "Review this ReactiveNET document. Call reactive_validate first (grammar, with line numbers), then reactive_analyze (data flow: orphan collections, unfed #refs, forms nothing saves, dangling ids). Report every problem with its line and the exact fix, then the corrected document if anything had to change.",
            "",
            "```markdown",
            markdown,
            "```",
          ].join("\n"),
        },
      }],
    }),
  )

  return server
}

// --- HTTP (Streamable HTTP, STATELESS) --------------------------------------
// Stateless because no tool has state: every request gets a fresh
// server+transport pair (the SDK's intended pattern for this mode), while the
// guide and the catalogue are module-level and shared.
// Fixed one-minute windows per address: crude on purpose — the goal is that a
// runaway client cannot starve everyone else, not fairness at the margin.
const hits = new Map()
const allowed = ip => {
  const now = Date.now()
  const slot = hits.get(ip)
  if (!slot || now - slot.start >= 60_000) {
    if (hits.size > 4096) for (const [key, v] of hits) if (now - v.start >= 60_000) hits.delete(key)
    hits.set(ip, { start: now, count: 1 })
    return true
  }
  slot.count += 1
  return slot.count <= RATE
}

const readBody = req =>
  new Promise((resolve, reject) => {
    let raw = ""
    req.on("data", chunk => {
      raw += chunk
      if (raw.length > 4_000_000) reject(new Error("body too large"))
    })
    req.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : undefined)
      } catch {
        reject(new Error("invalid JSON"))
      }
    })
    req.on("error", reject)
  })

const http = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`)

  if (url.pathname === "/health") {
    res.writeHead(200, { "content-type": "application/json" })
    res.end(
      JSON.stringify({
        ok: true,
        version: JSON.parse(readFileSync(join(HERE, "..", "package.json"), "utf8")).version,
        directives: COMPONENTS.length,
        guideSections: guide.reduce((n, d) => n + d.sections.length, 0),
      }),
    )
    return
  }

  if (url.pathname !== "/mcp") {
    res.writeHead(404, { "content-type": "text/plain" })
    res.end("not found — the MCP endpoint is /mcp")
    return
  }

  // CORS: browser-side MCP clients preflight and must be able to read the
  // session header. Claude's connector calls server-to-server and needs none
  // of this, but the cost is nil.
  res.setHeader("Access-Control-Allow-Origin", "*")
  res.setHeader("Access-Control-Allow-Headers", "content-type, mcp-session-id, mcp-protocol-version, authorization")
  res.setHeader("Access-Control-Expose-Headers", "mcp-session-id")
  if (req.method === "OPTIONS") {
    res.writeHead(204)
    res.end()
    return
  }

  // The only thing this server has to protect is its availability — and, when
  // MCP_TOKEN is set, who may spend it. Health and CORS preflight stay open.
  const ip =
    String(req.headers["x-forwarded-for"] || "").split(",")[0].trim() ||
    req.socket.remoteAddress ||
    "?"
  if (!allowed(ip)) {
    res.writeHead(429, { "content-type": "application/json", "retry-after": "60" })
    res.end(JSON.stringify({ jsonrpc: "2.0", error: { code: -32000, message: "rate limit: retry in a minute" }, id: null }))
    return
  }
  if (TOKEN && req.headers.authorization !== `Bearer ${TOKEN}`) {
    res.writeHead(401, { "content-type": "application/json" })
    res.end(JSON.stringify({ jsonrpc: "2.0", error: { code: -32000, message: "authorization required" }, id: null }))
    return
  }

  try {
    const body = req.method === "POST" ? await readBody(req) : undefined
    const server = buildMcpServer()
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined })
    // Once the response closes, neither is needed: without this, every
    // request would leave a live McpServer behind.
    res.on("close", () => {
      transport.close()
      server.close()
    })
    await server.connect(transport)
    await transport.handleRequest(req, res, body)
  } catch (error) {
    console.error("[mcp] error:", error?.message || error)
    if (!res.headersSent) {
      res.writeHead(400, { "content-type": "application/json" })
      res.end(JSON.stringify({ jsonrpc: "2.0", error: { code: -32700, message: String(error?.message || error) }, id: null }))
    }
  }
})

http.listen(PORT, () => {
  console.log(`[mcp] listening on :${PORT} — endpoint /mcp, health /health`)
  console.log(`[mcp] ${COMPONENTS.length} directives, links point at ${APP_URL}${ShareLink.path}`)
})
