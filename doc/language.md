# The language

A ReactiveNET document is Markdown. Everything Markdown does — headings, emphasis,
tables, links, fenced code, KaTeX between `$$`, Mermaid in a ```` ```mermaid ````
block — works unchanged. On top of it sit **directives**, which are the parts that do
something.

## Two forms

There are two ways to write a directive, and they differ in where they sit.

**Inline**, inside a paragraph, with one colon:

```markdown
The volume is now :value[v]{ref="#volume"}.
```

**Block**, alone on its line, with two:

```markdown
::slider[volume]{min="0" max="100" value="50"}
```

That is the whole syntax. There is no third form.

## A block with a body

A block that has content is written exactly like one that does not — and a line that
names it closes it:

```markdown
::form{path="items"}
::input{field="what" legend="Item"}
::save{label="Add"}
::/form
```

`::/form` ends the `::form` above it. Everything between the two is the form's body.
A block nobody closes stands alone.

**Nothing is counted.** Two blocks written identically still nest, because each close
says what it ends:

```markdown
::if-any{path="items"}
::list{path="items"}
{what}
::/list
::/if-any
```

The close is matched by name, and by depth within that name, so a form inside a form
still ends at its own `::/form`.

> **The earlier syntax is gone.** Documents written before the close was named used a
> run of three or more colons, closed by a line of the same length, which forced an
> outer container to carry *more* colons than the ones it held (`::::accordion` around
> `:::accordion-item`). That form is **no longer read**: three colons on a line are
> now ordinary text, so such a document renders its directives as the text they are
> written as rather than as components. Rewriting one means changing each opening to
> `::` and each closing line to `::/name`.

## Attributes

Attributes go in braces after the name, as `name="value"` pairs separated by spaces.
An attribute with no value is a flag, and is on:

```markdown
::list{path="items" deletable editform}
::accordion-item{label="First" open}
```

Quotes are required around a value and may be single or double. Everything after the
first `=` up to the closing quote is the value, so a value may contain spaces, colons
and slashes.

A directive is checked against what its component actually accepts. An attribute the
component does not have, or a value outside the list a choice attribute allows, is
reported next to the rendered element rather than dropped in silence.

## The label in brackets

Some directives take a bracketed label before the attributes. What it means depends
on the directive:

```markdown
::slider[volume]{min="0" max="100"}   ← "volume" is the store key it writes to
::badge[Draft]{variant="neutral"}     ← "Draft" is the badge's text
:value[v]{ref="#volume"}              ← "v" is a name for the reader; the ref does the work
```

For a component that carries a value — a slider, a checkbox, a text field — the label
is the **store key**. For one that does not, it is the content.

## `#ref` versus a bare id

This is the rule that catches people out, and it is worth reading twice.

- A **bare id** is a store key that a control *writes to*: `::slider[volume]`.
- A leading **`#`** is a *reference*: a view that reads that key and follows it.

```markdown
::slider[volume]{min="0" max="100" value="50"}

The volume is :value[v]{ref="#volume"}.

::progress-bar{label="Volume" progress="#volume"}
```

`volume` is where the slider writes. `#volume` is what the text and the progress bar
read. Writing `ref="volume"` without the `#` binds a view to nothing: it would never
update, and nothing would report an error — so `:value` with a non-reactive ref is
rendered as an error instead.

Any attribute of any component can take a `#key` as its value, and it then follows
that key as it changes.

## Frontmatter

A document may open with a block delimited by `---`:

```markdown
---
appId: shopping
title: Shopping list
description: What to buy
lang: it
version: "1.0"
author: Ada
date: 2026-08-10
---
```

Rules worth knowing:

- **`appId` is the app's identity.** It is the storage key, the namespace its data
  lives under, and the addressable part of its URL (`#/a/shopping`). Changing it
  *moves* the app: the data goes with it and the URL follows.
- It must be lowercase letters, digits and single interior hyphens, up to 64
  characters.
- **`lang` outranks the interface language** while that document is open, and is not
  remembered afterwards: the language belongs to the document, not to you.
- **`chat: true` gives the app a chat panel**, opened from the speech-bubble button
  in the toolbar above it. The messages are rows of an ordinary collection named
  `chat`, so they back up with the rest of the data and — when the app is synced —
  travel end-to-end encrypted between its members like every other row. Only
  `true`, `yes`, `on` and `1` count as yes.
- Values are kept as written. Quote anything YAML would otherwise read as a number,
  a date or a boolean — `version: "1.0"` stays a string, `version: 1.0` becomes a
  number in some readers.
- Keys this app has never heard of are kept and shown in the info panel exactly as
  they were written.
- A block that is not properly closed is left alone as ordinary text. A stray `---`
  never swallows the rest of a document.

The parsed body, not the raw source, is what gets rendered.

## What an unknown directive does

Nothing is ever lost. A directive the app does not recognise is rendered **as
written** — you see the text you typed, not a blank space. That is deliberate: an
unimplemented directive must never make a document lose content.

## URLs

Routes live in the hash, so the app works from any static host with no server
configuration:

| URL | |
| --- | --- |
| `#/` | the gallery of apps this browser has |
| `#/a/<id>` | the app, as its readers see it |
| `#/a/<id>/edit` | the same app, open in the editor |

Reading and editing are two URLs rather than one page with a toggle: sending someone
the first is sending them the app.

On a handset the editor is not offered at all, and `#/a/<id>/edit` is rewritten to
`#/a/<id>`.
