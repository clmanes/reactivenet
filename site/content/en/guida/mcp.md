---
title: "The MCP server"
description: "Connecting a model to ReactiveNET: eight tools to write an app, check it and deliver it, with the guarantee that the real grammar is what answers."
weight: 50
translationKey: "mcp"
---

The previous pages are the reference for whoever writes the directives by hand.
This one is for whoever wants a model to write them — their own model, in any
client that speaks **MCP**.

The server gives the model what it lacks to do useful work here: the
documentation, the directive catalogue with typed attributes, the example apps,
the open-data catalogue, a **validator**, a **data-flow analyser**, and the
builder of the delivery link.

## The address

```
https://mcp.reactivenet.ai/mcp
```

**Streamable HTTP** transport, no authentication. An MCP client is usually
configured with an object like this:

```json
{
  "mcpServers": {
    "reactivenet": {
      "type": "http",
      "url": "https://mcp.reactivenet.ai/mcp"
    }
  }
}
```

Locally, with the repository to hand: `bun run mcp`, and the address becomes
`http://localhost:8789/mcp`.

> The assistant **inside the app** uses the same server, reached as `/mcp` on
> its own origin. That is not a convenience: the model's endpoint is
> configurable and the tools' endpoint is not, so no setting and no document can
> point it elsewhere.

## Why it asks for no password

Because there is nothing to protect. The server **touches nobody's data**, opens
no channel to any browser, writes nothing to disk. It is a server of **pure
functions** — guide, catalogue, validation, analysis, encoding — plus a single
read towards the outside, the open-data catalogue.

What is left to defend is the availability of the service, and for that there is
a per-address rate limit (`MCP_RATE`, 120 requests a minute). `MCP_TOKEN` turns
on bearer authentication for anyone who wants it.

## The guarantee that matters

**Every grammatical answer comes from the app's own compiled core.** The
directive catalogue is the same `DirectiveRegistry` the renderer reads; the
scanner is the same `DirectiveScan` that runs in the Markdown pipeline and the
block editor; the attribute parser is the same one, quotes included, so a
regular expression's own `{5}` does not end the attribute list here any more
than it does there; the link is the one the app itself produces, byte for byte.

If this server said "ok" about a document the app reads differently, the whole
tool would be pointless. Importing the compiled core is what makes that
disagreement impossible.

## The eight tools

| Tool | What it answers |
| --- | --- |
| `reactive_guide` | The documentation, a section at a time. With no argument, the index |
| `reactive_directives` | The directive catalogue with the form (inline, leaf, container) and typed attributes |
| `reactive_examples` | Complete apps to start from: `welcome` and `starter` in seven languages, plus task-shaped recipes |
| `reactive_od_catalog` | The datasets of the open-data service: tables, columns and types |
| `reactive_od_query` | **Runs** the SELECT instead of reading its schema: the catalogue says the column `regione` exists, only running it says it holds `'Puglia'` and not `'PUGLIA'` |
| `reactive_validate` | Checks the document with the real grammar and reports every problem **with its line number** |
| `reactive_analyze` | The data flow: who writes each collection and who reads it, and what does not meet |
| `reactive_app_link` | Validates and builds the link that puts the app in the recipient's gallery |

They are **all read-only**. `reactive_validate` and `reactive_analyze` also
return `structuredContent` beside the text, for anyone who would rather read an
object than a report.

### The difference between validating and analysing

`reactive_validate` looks at **one directive at a time**: the name exists, the
attributes are the right ones, the value is allowed, the container is closed. It
also flags the traps that validate and then betray at runtime — a field outside
a form, a `:value` with a bare key, a hex colour read as a `#reference`, and a
`::workflow` whose schedule does not parse: `every="10 minuti"` or `at="18"`
leaves the workflow **manual** with nothing saying so, which is exactly the class
of failure a validator exists to catch.

`reactive_analyze` looks at whether **the pieces meet**, which is what the
grammar cannot see on its own: a view over a collection nothing writes will stay
empty for ever; a `#ref` no source feeds will never update; a form with no
`::save` will save nothing; an `editform` naming a form that does not exist will
open nothing. These are the failures that raise no error — the app opens and
does not do what it should.

## The resources and the two prompts

The **eight guide documents** are also MCP resources, with stable URIs
(`reactive://guide/<name>`): `language`, `authoring`, `directives`, `storage`,
`security`, `accessibility`, `rbac`, `architecture`. A client that browses or
pins them will find them there.

Two **prompts** package the two jobs:

- **`build-app`** — from a request in plain words to a delivered app, following
  the order the tools are built for.
- **`review-app`** — validates and analyses an existing document and says what
  to fix, with line numbers.

## The workflow

It is the one `build-app` dictates, and it is worth knowing even when writing by
hand:

1. `reactive_guide` with no argument for the index, then the `language` document
   and whichever sections the request needs.
2. `reactive_examples`: start from the closest one. **Adapting an example that
   works is far more reliable than assembling directives one by one.**
3. If the app reads Italian open data, `reactive_od_catalog` **before** writing
   the SELECT: you check that `provincia` really is a column of `farmacie`
   instead of finding out afterwards.
4. Write the complete document, frontmatter included.
5. `reactive_validate`, and fix until it answers `ok`.
6. `reactive_analyze`, and fix every finding.
7. `reactive_app_link`, and give the person the link.

Steps 5 and 6 are not advice: **`reactive_app_link` validates for itself and
refuses**. A document that does not pass never becomes a link, and the report
comes back instead of one. The same holds for the tools the assistant inside the
app uses to create and edit an app.

The reason was observed, not imagined: small models simply do not validate when
you ask them to in words. The first app written here was created *and then*
validated, which put a broken `::list` in somebody's gallery.

## Running it yourself

```sh
bun run res:build   # the imports are the compiled .res.mjs
bun run mcp         # port 8789
```

It runs under **bun** and not node, because it imports the app's compiled core.
The environment variables, with their defaults:

| | |
| --- | --- |
| `MCP_PORT` | `8789` |
| `MCP_APP_URL` | `http://localhost:5173` — the origin the links point at |
| `MCP_OD_URL` | `http://127.0.0.1:8788` — the open-data service the catalogue reads |
| `MCP_TOKEN` | empty; set, it requires `Authorization: Bearer <token>` on `/mcp` |
| `MCP_RATE` | `120` requests a minute per address |

The health check stays open even with `MCP_TOKEN` set: it is there for a
supervisor, and it custodies nothing.
