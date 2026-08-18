#!/usr/bin/env bun
// Smoke test of the MCP server: actually starts it and talks to it with the
// SDK's own client — the same road Claude's connector takes.
//
// It covers the three failures that would otherwise be silent:
//   1. tool wiring (an SDK drift only shows when a client really calls
//      `tools/list`);
//   2. the shared grammar (if `reactive_validate` stopped seeing directives it
//      would answer "ok" to anything — the worst defect, silent and in the
//      wrong direction);
//   3. the link: the payload must decode back IDENTICAL, or the user would
//      import a different document from the one that was validated.
//
// Use: bun scripts/test-mcp.mjs   (needs a compiled tree: bun run res:build)

import { readdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { Client } from "@modelcontextprotocol/sdk/client/index.js"
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js"
import * as SharePayload from "../src/shell/SharePayload.res.mjs"
import * as ShareLink from "../src/core/ShareLink.res.mjs"

const HERE = dirname(fileURLToPath(import.meta.url))
const PORT = 8800 + Math.floor(Math.random() * 90)
const BASE = `http://localhost:${PORT}`

const GREEN = s => `\x1b[32m${s}\x1b[0m`
const RED = s => `\x1b[31m${s}\x1b[0m`

let fails = 0
const check = (name, cond, detail = "") => {
  if (cond) console.log(`${GREEN("✓")} ${name}`)
  else {
    fails++
    console.log(`${RED("✗")} ${name}${detail ? ` — ${detail}` : ""}`)
  }
}

const GOOD = `---
appId: officina
title: Officina
lang: it
version: "1.0"
---

# Officina

::form{path="schede"}
::input{field="cliente" legend="Cliente"}
::input{field="targa" legend="Targa"}
::save{label="Salva"}
::/form

::if-any{path="schede"}
:count{path="schede"} schede:

::list{path="schede" deletable editform}
**{cliente}** — {targa}
::/list
::/if-any
`

// A broken document: an invalid appId, a directive that does not exist, a
// Choice attribute with a value outside its list, a hex colour read as a
// #reference, and a close that closes nothing.
const BROKEN = `---
appId: Not Valid
title: Rotto
---

::tabel{path="x"}

::accordion{density="wrong"}
Testo.
::/accordion

::badge{variant="#65c3c8"}

::/form
`

// The runtime traps: a field with no form around it, a :value bound to a bare
// store key (it would never update), an overlay that freezes the app, and the
// two controls that store nothing.
const TRAPS = `---
appId: profondo
title: Profondo
---

::input{field="x" legend="X"}

:value[v]{ref="volume"}

:calc{expr="#a ** #b"}

::overlay{open}
Testo.
::/overlay

::switch
Acceso
::/switch

::workflow{every="10 minuti" at="18" on="quando:serve"}
::od-query{into="x" sql="SELECT 1"}
::/workflow

::workflow{every="15m"}
`

// A document whose every piece is grammatically fine and whose pieces do not
// meet: analyze() is what sees this, validate() cannot. A slider nobody reads,
// a :value nobody writes, a list over a collection nothing writes with an
// editform naming a form that does not exist, a form with no save, and an
// engine writing over the collection a form saves into.
const FLOW = `---
appId: flusso
title: Flusso
---

::slider[vol]

:value[v]{ref="#totale"}

::form{path="spese"}
::input{field="importo" type="number" legend="Importo"}
::save{label="Salva"}
::/form

::form{path="note"}
::input{field="testo" legend="Testo"}
::/form

::list{path="uscite" editform="manca"}
{importo}
::/list

::sql{data="spese" into="spese"}
\`\`\`
SELECT importo FROM spese WHERE importo > {#soglia}
\`\`\`
::/sql
`

const proc = Bun.spawn(["bun", "mcp/server.mjs"], {
  env: { ...process.env, MCP_PORT: String(PORT) },
  stdout: "pipe",
  stderr: "pipe",
})

const ready = async () => {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`${BASE}/health`)
      if (r.ok) return await r.json()
    } catch {}
    await Bun.sleep(250)
  }
  return null
}

let client
try {
  const health = await ready()
  if (!health) {
    console.log(RED("The server did not come up within 10s."))
    console.log(await new Response(proc.stderr).text())
    proc.kill()
    process.exit(1)
  }
  check("health answers", health.ok === true)
  check("catalogue loaded", health.directives > 100, `directives=${health.directives}`)
  check("guide split into sections", health.guideSections > 20, `sections=${health.guideSections}`)

  client = new Client({ name: "test-mcp", version: "1.0.0" })
  await client.connect(new StreamableHTTPClientTransport(new URL(`${BASE}/mcp`)))

  const { tools } = await client.listTools()
  const names = tools.map(t => t.name).sort()
  check(
    "the eight tools are exposed",
    names.join(",") ===
      "reactive_analyze,reactive_app_link,reactive_directives,reactive_examples,reactive_guide,reactive_od_catalog,reactive_od_query,reactive_validate",
    names.join(","),
  )
  check("every tool has a description", tools.every(t => (t.description || "").length > 40))

  const call = async (name, args = {}) => {
    const r = await client.callTool({ name, arguments: args })
    return { text: r.content.map(c => c.text).join("\n"), isError: !!r.isError, structured: r.structuredContent }
  }

  const index = await call("reactive_guide")
  check("guide: no argument gives the index", index.text.includes("language —"))
  const section = await call("reactive_guide", { section: "frontmatter" })
  check("guide: a section by title", section.text.startsWith("## Frontmatter"), section.text.slice(0, 40))
  const wholeDoc = await call("reactive_guide", { section: "rbac" })
  check("guide: a whole document by name", wholeDoc.text.includes("# Shared spaces"))

  const detail = await call("reactive_directives", { name: "table" })
  check("directives: detail of table", detail.text.includes("table —") && detail.text.includes("Snippet:"))
  const inline = await call("reactive_directives", { kind: "inline" })
  check("directives: inline filter", inline.text.includes("calc") && !inline.text.includes("(leaf"))
  const slider = await call("reactive_directives", { name: "slider" })
  check("directives: a source names its store key", slider.text.includes("SOURCE"))

  const welcome = await call("reactive_examples", { name: "welcome", lang: "it" })
  check("examples: the welcome app in Italian", welcome.text.includes("appId: welcome"))
  const starter = await call("reactive_examples", { name: "starter" })
  check("examples: the starter has the form and the list", starter.text.includes("::form") && starter.text.includes("::/list"))

  const bad = await call("reactive_validate", { markdown: BROKEN })
  check("validate: rejects the broken document", bad.text.includes("problem"))
  check("validate: invalid appId is caught", bad.text.includes("appId"))
  check("validate: unknown directive is caught", bad.text.includes("tabel"))
  check("validate: wrong Choice value is caught", bad.text.includes("density"))
  check("validate: hex colour read as #reference is caught", bad.text.includes("#65c3c8"))
  check("validate: stray close is caught", bad.text.includes("::/form"))
  check("validate: every problem carries a line number", /line \d+:/.test(bad.text))

  const traps = await call("reactive_validate", { markdown: TRAPS })
  check("validate: an input with no form around it is caught", traps.text.includes("::input works inside ::form"))
  check("validate: a :value bound to a bare store key is caught", traps.text.includes("would never update"))
  check("validate: a malformed :calc expression is caught", traps.text.includes("does not parse"))
  check("validate: an overlay written open is caught", traps.text.includes("freezes"))
  check("validate: the controls that store nothing get advice", traps.text.includes("::switch stores nothing") || traps.text.includes("sp-switch"))
  // A schedule that does not parse leaves the workflow MANUAL and says nothing: the
  // attribute is there, the strip draws, six o'clock never comes. Checked by the same
  // compiled parser the binder uses, so the two cannot drift.
  check("validate: an unparseable every= is caught", traps.text.includes('every="10 minuti"'))
  check("validate: a time written 18 rather than 18:00 is caught", traps.text.includes('at="18"'))
  check("validate: an event nobody implements is caught", traps.text.includes("quando:serve"))
  check("validate: a workflow nobody closed is caught", traps.text.includes("::workflow has no steps"))

  // The leading "ok" is a contract, not a pleasantry: the in-app assistant reads it
  // to decide whether a document may be written to the gallery at all (core/AiPlan
  // `validates`, which has the other half of this assertion). Change the wording here
  // and delivery starts refusing every valid app.
  const good = await call("reactive_validate", { markdown: GOOD })
  check("validate: promotes the good document", good.text.startsWith("ok"), good.text.slice(0, 80))

  // The strongest guard against false positives: the welcome app exercises one
  // of every kind of directive and is what every browser opens first — if the
  // validator complains about it, the validator is wrong.
  const tour = await call("reactive_validate", { markdown: welcome.text })
  check("validate: the welcome app validates clean", tour.text.startsWith("ok"), tour.text.slice(0, 120))

  // The FLOW document validates clean by construction — every finding below is
  // one grammar-level validation cannot make.
  const flowValid = await call("reactive_validate", { markdown: FLOW })
  check("analyze: the flow document validates clean (the findings are analyze's alone)", flowValid.text.startsWith("ok"), flowValid.text.slice(0, 120))
  const flow = await call("reactive_analyze", { markdown: FLOW })
  check("analyze: a collection read but never written", flow.text.includes('"uscite"') && flow.text.includes("nothing in this document writes it"))
  check("analyze: a #ref no source feeds", flow.text.includes("#totale is read") && flow.text.includes("never update"))
  check("analyze: a source key nothing reads", flow.text.includes("#vol but nothing reads it"))
  check("analyze: an editform naming a missing form", flow.text.includes('editform="manca"'))
  check("analyze: a form nothing can save", flow.text.includes('"note"') && flow.text.includes("no ::save"))
  check("analyze: an engine writing over a form's rows", flow.text.includes("REPLACES the rows"))
  check("analyze: the sql body's {#key} is a tracked read", flow.text.includes("#soglia"))
  check("analyze: every finding carries a line number", /line \d+:/.test(flow.text))

  // The seam the app's delivery gate reads (core/AiPlan.connects): a clean document
  // says "No orphans", and one with findings must NOT. Asserted on this side too,
  // because the two are separate programs and the words are the whole contract —
  // lose them here and every app is delivered as though its pieces met.
  check("analyze: a report with findings carries no clean marker", !flow.text.includes("No orphans"))
  const clean = await call("reactive_analyze", { markdown: GOOD })
  check("analyze: a sound document says No orphans", clean.text.includes("No orphans"), clean.text.slice(-90))
  const flowGood = await call("reactive_analyze", { markdown: GOOD })
  check("analyze: the good document has no orphans", flowGood.text.includes("No orphans"), flowGood.text.split("\n").slice(-3).join(" | "))

  // Structured output rides beside the text: the same result, processable
  // without parsing prose.
  const goodStructured = await call("reactive_validate", { markdown: GOOD })
  check("structured: validate returns structuredContent", goodStructured.structured?.ok === true)
  const flowStructured = await call("reactive_analyze", { markdown: FLOW })
  check(
    "structured: analyze returns the graph",
    Array.isArray(flowStructured.structured?.collections) &&
      flowStructured.structured.findings.length >= 6 &&
      flowStructured.structured.collections.some(c => c.name === "spese" && c.writers.length > 0),
    JSON.stringify(flowStructured.structured?.findings?.length),
  )

  // The recipes: every file under mcp/examples/ must validate clean and
  // analyze with no orphans — a recipe with a defect teaches the defect.
  //
  // Read from the directory rather than listed by hand: the server picks the
  // recipes up by reading that same directory, so a name written here was a
  // name that could fall out of step with it — and did, silently, the first
  // time a recipe was added.
  const recipes = readdirSync(join(HERE, "..", "mcp", "examples"))
    .filter(f => f.endsWith(".md"))
    .map(f => f.slice(0, -3))
    .sort()
  check("recipes: the directory has recipes to check", recipes.length > 0, String(recipes.length))
  for (const recipe of recipes) {
    const doc = await call("reactive_examples", { name: recipe })
    const valid = await call("reactive_validate", { markdown: doc.text })
    const flow2 = await call("reactive_analyze", { markdown: doc.text })
    check(
      `recipes: ${recipe} is served, validates clean and has no orphans`,
      doc.text.startsWith("---") && valid.text.startsWith("ok") && flow2.text.includes("No orphans"),
      `${valid.text.split("\n")[0]} | ${flow2.text.split("\n").at(-1)}`,
    )
  }

  // The open-data catalog answers either with datasets (service up) or with
  // the honest unreachable message — never with a stack trace.
  const catalog = await call("reactive_od_catalog", {})
  const odUp = catalog.text.includes("datasets:")
  check("od catalog: lists datasets or degrades honestly", odUp || catalog.text.includes("not reachable"), catalog.text.slice(0, 80))
  if (odUp) {
    const farmacie = await call("reactive_od_catalog", { table: "farmacie" })
    check("od catalog: a table's columns with types", farmacie.text.includes("Columns:") && farmacie.text.includes("(VARCHAR)"))
    check("od catalog: the detail carries a snippet", farmacie.text.includes("::od-query{into="))

    // Running one, which is the half the catalogue cannot do. Three shapes matter and
    // the last two are the reason the tool exists at all.
    const ran = await call("reactive_od_query", { sql: "SELECT 1 AS uno, 'due' AS testo", limit: 3 })
    check("od query: runs a SELECT and samples it", ran.text.includes("returned 1 row") && ran.text.includes('"uno"'))

    const refused = await call("reactive_od_query", { sql: "DROP TABLE farmacie" })
    check("od query: refuses anything that is not a SELECT", refused.text.includes("refused"))

    // A SELECT matching nothing. This is what a wrong WHERE looks like, and it must
    // never read as a result — the app renders it as empty cards and says nothing.
    const none = await call("reactive_od_query", { sql: "SELECT comune FROM farmacie WHERE comune='@@nessuno@@'" })
    check("od query: no rows is reported as a broken query", none.text.includes("NO ROWS") && none.text.includes("BROKEN"))

    // The same emptiness wearing a result's clothes: an aggregate over nothing is one
    // row of nulls, which is the shape every dashboard headline has. Reported as "1
    // row" it reads as success, and that is exactly how a regional dashboard shipped
    // showing "null abitanti in 0 comuni".
    const hollow = await call("reactive_od_query", { sql: "SELECT count(*) AS n, sum(1) AS s FROM farmacie WHERE comune='@@nessuno@@'" })
    check("od query: an aggregate over nothing is reported as broken too", hollow.text.includes("NULL OR ZERO") && hollow.text.includes("BROKEN"))
  }

  // Resources and prompts: the other two MCP surfaces clients browse.
  const { resources } = await client.listResources()
  check(
    "resources: the eight guide documents",
    resources.length === 8 && resources.some(r => r.uri === "reactive://guide/language"),
    `${resources.length}`,
  )
  const resource = await client.readResource({ uri: "reactive://guide/language" })
  check("resources: a guide document reads back", (resource.contents?.[0]?.text || "").length > 1000)
  const { prompts } = await client.listPrompts()
  check(
    "prompts: build-app and review-app",
    prompts.map(p => p.name).sort().join(",") === "build-app,review-app",
    prompts.map(p => p.name).join(","),
  )
  const prompt = await client.getPrompt({ name: "build-app", arguments: { request: "una lista della spesa" } })
  check(
    "prompts: build-app walks the workflow",
    prompt.messages[0].content.text.includes("reactive_validate") &&
      prompt.messages[0].content.text.includes("una lista della spesa"),
  )

  const noLink = await call("reactive_app_link", { markdown: BROKEN })
  check("app_link: no link for a document that fails", noLink.isError === true)
  const okLink = await call("reactive_app_link", { markdown: GOOD })
  const link = (okLink.text.match(/https?:\/\/\S+/) || [])[0]
  check("app_link: produces the link", !!link && link.includes("/s#"))
  // The same two steps the app takes on /s: strip the fragment marker, decode.
  const payload = link ? ShareLink.payloadOf(link.slice(link.indexOf("#"))) : undefined
  const decoded = payload ? await SharePayload.decode(payload) : undefined
  check("app_link: the link decodes back to the validated document", decoded === GOOD, (decoded || "").slice(0, 60))

  // MCP_TOKEN: a second server, this one guarded. Health stays open, /mcp
  // refuses the bare request and accepts the bearer.
  const PORT2 = PORT + 1
  const guarded = Bun.spawn(["bun", "mcp/server.mjs"], {
    env: { ...process.env, MCP_PORT: String(PORT2), MCP_TOKEN: "segreto" },
    stdout: "pipe",
    stderr: "pipe",
  })
  try {
    let health2 = null
    for (let i = 0; i < 40 && !health2; i++) {
      try {
        const r = await fetch(`http://localhost:${PORT2}/health`)
        if (r.ok) health2 = await r.json()
      } catch {}
      if (!health2) await Bun.sleep(250)
    }
    check("token: health stays open", health2?.ok === true)
    const bare = await fetch(`http://localhost:${PORT2}/mcp`, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json, text/event-stream" },
      body: JSON.stringify({ jsonrpc: "2.0", method: "ping", id: 1 }),
    })
    check("token: /mcp refuses the bare request", bare.status === 401, String(bare.status))
    const bearer = await fetch(`http://localhost:${PORT2}/mcp`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        accept: "application/json, text/event-stream",
        authorization: "Bearer segreto",
      },
      body: JSON.stringify({ jsonrpc: "2.0", method: "ping", id: 1 }),
    })
    check("token: the bearer passes", bearer.status !== 401, String(bearer.status))
  } finally {
    guarded.kill()
  }
} finally {
  try {
    await client?.close()
  } catch {}
  proc.kill()
}

console.log("")
if (fails > 0) {
  console.log(RED(`${fails} checks failed`))
  process.exit(1)
}
console.log(GREEN("✓ MCP server: tools, validation and link verified end to end"))
