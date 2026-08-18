---
title: "The assistant inside the app"
description: "The fifteen ai-* directives: summarising, asking, filling a form, working through a collection, searching by meaning — and the rule that makes them safe."
weight: 24
translationKey: "assistente"
---

These directives put the model to work **inside** the app rather than beside it.
They all use the one model configured once in the assistant's settings: a model
on this machine (Ollama), or an OpenAI-compatible endpoint with its key.

**Where the data goes is a property of the endpoint, not of the directive.**
With a local model nothing leaves the computer. With a remote provider, whatever
the directive puts in the prompt is sent to it. That is one sentence and it
holds for all fifteen; there is no directive more careful than another, there is
a setting.

If no model is configured, **each of them draws one line saying so** and the app
keeps working. A document written for a model must not become a page of broken
widgets on a browser that has none.

## The rule that makes them safe

These are directives you will meet inside documents other people wrote, so the
right question is not what they can do but what they cannot. The answer is one
sentence:

> **The model never produces anything that is executed.**

It produces a word from a closed list the document wrote, or an object whose
keys the document declared, or a **query plan** in which every field name was
checked against the ones the collection actually has — and that plan is then run
here, on rows this device already holds. Everything else is refused before it
can become a row.

It is the same argument as `::python` and `::sql`: the data travels in a channel
of its own and is never pasted into code.

## Reading, and asking

```markdown
::ai-summary{data="expenses"}
Summarise the expenses: how much, on what, and what changed.
::/ai-summary

::ai-chat{data="workouts"}
You are the coach. Answer briefly.
::/ai-chat

::ai-query{data="expenses" into="answer" placeholder="How much did I spend on transport in June?"}
```

**`::ai-summary`** writes a summary and **rewrites it whenever the rows change**.
The body — or `prompt=` — says what to look at. Only a sample of the rows
travels, never the whole collection. It also takes `rag=`.

**`::ai-chat`** answers from the collections in `data=`, and **says when the
answer is not in them** instead of inventing it. The body is the persona (or
`persona=`), `placeholder` is what the empty box says. The conversation stays on
this device.

**`::ai-query`** is the interesting one. The question becomes a **plan** —
filters, a `group-by`, one aggregation — and the widget shows **the plan as well
as the answer**, because a reader who cannot see what was asked cannot tell a
right answer from a plausible one. The single number appears in the widget; the
breakdown lands in `into=`, ready for a `::table` or a `::chart-bar`.

| | `data` | `into` | `placeholder` | body |
| --- | --- | --- | --- | --- |
| `::ai-summary` | the collection | — | — | what to say about it |
| `::ai-chat` | the readable collections | — | ✓ | the persona |
| `::ai-query` | the collection | the breakdown | ✓ | — |

## Filling a form

```markdown
::form{path="expenses" id="f1"}
::input{field="item" legend="Item"}
::input{field="amount" type="number" legend="Amount"}
::input{field="category" legend="Category"}

::ai-assist{form="f1" placeholder="Pizza with Mario, Thursday, 24 euro"}
::ai-field{form="f1" field="category" values="food,home,transport"}
::ai-suggest{form="f1" path="expenses" fields="item,amount:number"}
::save{label="Save"}
::/form
```

**None of these writes a row.** They fill the form's **draft**, and the person
saves by pressing the form's own button. It is the same distinction the agent
below makes, and it is deliberate: a model that writes rows on its own is a
model whose whole output has to be re-checked.

| Directive | What it does | Attributes |
| --- | --- | --- |
| `::ai-assist` | Fills the form from **one sentence**, reading the fields the form actually has | `form`, `label`, `placeholder` |
| `::ai-field` | Suggests **one** field from the others already filled, choosing from `values` | `form`, `field`, `values`, `label` |
| `::ai-suggest` | Proposes the next plausible row from what the collection already holds | `form`, `path`, `fields`, `label` |
| `::ai-extract` | Reads free text and fills the draft with what it finds there | `form`, `fields`, `source`, `label` |
| `::ai-vision` | Describes the image in a `::file` field into another field | `form`, `field`, `target`, `prompt`, `label` |
| `::ai-translate` | Translates the text of a key or a field into `to=`, **in place** | `to`, `form`, `field`, `label` |
| `::ai-rewrite` | Rewrites the text of a key or a field in the style asked for | `style`, `form`, `field`, `label` |

`fields=` is written `name:type` — `text` (the default), `number`, `date`,
`boolean` — and **a value that is not of that type is left out** rather than
stored as prose. `::ai-field` chooses from `values=` and from nothing else: an
answer outside the list is dropped, never added to it.

`::ai-extract` without `source` draws a box of its own; with `source="#dictated"`
it reads a reactive key. `::ai-translate[note]{to="it"}` works on a key when the
brackets name one, on a field when `form`/`field` say so.

`::ai-vision` needs a model that reads images: Ollama with a multimodal model,
or OpenAI.

## Working through a whole collection

```markdown
::ai-classify{path="expenses" field="category" values="food,home,transport" label="Classify"}

::ai-rule{data="expenses" when="amount above 100" do="set review to 'to check'"}

::ai-pipeline{data="tickets" fields="office,urgency,summary"}
Classify the ticket by office and urgency, and write a one-line summary.
::/ai-pipeline
```

**`::ai-classify`** looks **only at rows where that field is still empty**,
unless you write `overwrite`. Attributes: `path`, `field`, `values`,
`overwrite`, `label`.

**`::ai-pipeline`** looks only at rows where the **first** declared field is
empty — that is what "the new rows" means here — and does at most 25 at a time.
Attributes: `data`, `fields`, `label`.

**`::ai-rule`** is the one that **stops needing the model**. It is compiled
**once** into a checked plan — a field, a comparison, a value, a field to write
— kept in IndexedDB; from then on it runs on every data change **with no request
at all**. Deterministic, and idempotent because it only touches rows whose value
would actually change. Attributes: `data`, `when`, `do`, `label`.

## The agent

```markdown
::ai-agent{data="bookings,rooms" tools="query,insert"}
You are the bookings assistant: check availability with a query before proposing
an insertion.
::/ai-agent
```

Two tools and no others. `query` reads the collections named in `data=`;
`insert` **proposes** a row, which appears with a confirm button and is written
only when somebody presses it. Attributes: `data`, `tools`, `placeholder`; the
body is the persona.

Every call leaves a line in the visible log, because **an agent whose steps are
invisible is one nobody can check**.

## Search by meaning

```markdown
::ai-search{rag="documents.attachment,documents.notes" placeholder="Search the documents"}

::ai-chat{data="documents" rag="documents.attachment,documents.notes"}
Answer citing the documents in square brackets.
::/ai-chat
```

`rag=` names the fields as `collection.field`. Their text — including the
**content** of a `::file` attachment, when it is text this browser can read on
its own — is cut into passages, embedded, and kept in IndexedDB. The index is
**rebuilt only when the text it was built from has actually changed**, and it
never leaves the device except as a request to whatever endpoint is configured.
Attributes: `rag`, `placeholder`, `into`.

The embedding model is **Qwen3-Embedding-0.6B**
(`ollama pull qwen3-embedding:0.6b`, about 600 MB), and it is deliberately not a
setting: the choice has two honest answers and the endpoint decides between
them. Where the endpoint is OpenAI's own, `text-embedding-3-small` is used
instead, because that is the one host that will not serve Qwen whatever you ask
it for.

> **PDFs and scans are not indexed.** Extracting those needs a parser and an
> OCR. Such a file is indexed **by its name**, and a search that quietly indexed
> the name while looking as though it had read the file would be worse than not
> offering it: the citation could point at nothing else.
