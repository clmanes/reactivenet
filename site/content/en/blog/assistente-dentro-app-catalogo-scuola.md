---
title: "The assistant moves inside the app, and the school catalogue reaches five"
seotitle: "ai-* directives: the assistant inside the app"
description: "Fifteen ai-* directives put the assistant inside the app — summaries, semantic search, rules in plain words — plus three new school apps."
date: 2026-08-13
author: "Cosimo Luigi Manes"
translationKey: "assistente-dentro-app-catalogo-scuola"
---

Until yesterday ReactiveNET's assistant sat **beside** the app: you asked it for an
app, it wrote one, you used it. From today it also sits **inside**. Fifteen new `ai-*`
directives put the same model — the one configured once in the chat settings — at the
service of the people using an app, not only the people writing one.

Three new apps land in the school catalogue at the same time, and they are the best
explanation I have of what these directives are actually for.

## The one rule that holds them together

There is a single sentence to remember, and it is what makes these directives safe to
put in a document somebody else wrote:

> **The model never produces anything that is executed.**

It produces a word from a list the document wrote. Or an object whose keys the document
declared. Or a *query plan*, whose every field name is checked against the ones the
collection actually has — and the plan then runs here, over rows this device already
holds.

Everything else is refused before it can become a row. There is no point at which a
model's text becomes code, SQL or markup: the same choice that makes `::python` blocks
receive their data in a separate channel instead of pasted into the source, and `::sql`
use prepared parameters.

## What you can do with them

**Ask.** `::ai-query` turns a question in plain words — "how much did I spend on
transport in June?" — into filters, a group-by and one aggregation. The widget shows
the answer **and the plan**, because an answer whose question you cannot see is an
answer you cannot check. The breakdown lands in a collection, and a table or a chart
draws it like any other.

**Summarise.** `::ai-summary` rewrites itself whenever the rows change. A sample
travels, never the whole collection.

**Talk to your own data.** `::ai-chat` answers from the declared collections and says
so when the answer is not in them. `::ai-agent` is the same with two tools: `query`,
which reads, and `insert`, which **proposes** a row — written only when the person
presses confirm, with every step logged.

**Fill a form.** `::ai-assist` reads "Mario, Thursday at 3pm" and fills the draft;
`::ai-field` picks a category from the ones you listed; `::ai-suggest` proposes the next
row from the ones already there. None of them writes a row: they fill the draft, and
the save button is the same one as always, pressed by a person.

**Work through a collection.** `::ai-classify` sorts the rows that do not have a
category yet. `::ai-pipeline` processes the new rows — the ones whose first declared
field is empty — twenty-five at a time.

**Write a rule once.** `::ai-rule` is my favourite. You write the condition and the
action in words; the model compiles them **once** into a checked plan kept in
IndexedDB; from then on the rule runs with no model at all, on every data change,
deterministic — and idempotent, because it only touches rows whose value would actually
change. The model was useful for a second, not for ever.

**Search by meaning.** `::ai-search` indexes the fields you name, including the **text
content of `::file` attachments**, and searches by sense. The index is built on this
device, rebuilt only when the text really changes, and never leaves. The default
embedding model is **Qwen3-Embedding-0.6B** — six hundred megabytes,
`ollama pull qwen3-embedding:0.6b` — and it is deliberately not a setting: the choice
has two honest answers and the endpoint decides between them.

PDFs and scans are **not** indexed. That would need a parser and an OCR, and a search
that quietly indexed a file's *name* while looking as though it had read the file would
be worse than not offering it.

## Where the data goes

Where it goes is a property of the endpoint, not of the directive. With a model running
on your own machine — Ollama — nothing leaves: not the sample rows, not the text you
are rewriting, not the questions. With a remote provider, whatever the directive put in
the prompt reaches that provider, exactly as it does for the chat.

The same `AiSettings.isLocal` decides, and it is the same function the panel and the
privacy policy read. If no model is configured, each directive writes one sentence and
**the app keeps working**: a document written for a model must not become a page of
broken widgets on a browser that has none.

## Three new apps, and why these

The school catalogue goes from two to five. The three new ones are jobs a school does
every year, always the same way, always with the same mistakes.

**[Internal seniority lists](/en/app/scuola/graduatorie-interne/)** forms the lists used
to identify surplus staff. The decision everything rests on is that **the scoring table
is data**: it is rewritten by every renewal of the national agreement, and software
that carried it inside would be scrap by the first one. Continuity of service is not
declared but derived from the date of establishment — the most frequent error, removed
by construction. And every point awarded has a statement that justifies it, with the
legal reference: that is what you print when an appeal arrives.

**[Inclusion](/en/app/scuola/inclusione/)** covers individual education plans. It
handles health data about minors, and that decided everything else: nothing leaves the
device, **there is no field anywhere to write a diagnosis**, school-wide summaries count
instead of listing, and the extract for the class council carries measures and
assessment criteria and nothing more. The only two AI directives present rewrite text a
teacher has already written and search the bank of phrasings. None classifies, predicts
or assesses a pupil — and that is not an omission.

**[School office](/en/app/scuola/segreteria/)** is the back-office dashboard: cases with
configurable types and deadlines, kanban by state, an obligations calendar, leave
counters, fixed-term contracts, purchasing and inventory. It opens by saying what it is
**not** — it replaces neither the ministry's systems nor the official register, nor
preservation, nor accounting — because that is the first thing to settle before handing
software to an administrative office.

All three end with a **Decisions** page: the choices made where the rules are ambiguous,
written as choices rather than as readings of the law, and the line to change to change
them.

## What none of the three does

None has per-role access control inside the document. Whoever opens the app sees all of
it. Where roles must truly be separated the answer is the platform's **shared spaces** —
reader or editor, with reading held by cryptography and writing by the server — or,
more simply, two apps.

That is the kind of thing I would rather write on the app's opening page than let
somebody discover after putting real data in.

## Trying them

Each of the three opens from the catalogue and lands in your gallery with a sample
school already inside: you press *Run* on the seeding blocks and there is something to
look at straight away, instead of an empty shell to fill before you can tell whether it
helps.

The apps are Markdown documents: read them, change them, take them away.
