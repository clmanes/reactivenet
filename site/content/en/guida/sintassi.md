---
title: "Directive syntax"
description: "The three forms of a directive, the block that closes by name, the attributes and the difference between #ref and an id."
weight: 10
translationKey: "sintassi"
---

A directive is written in three forms, and they are the three standard forms of
Markdown directives.

| Form | How it is written | What it is |
| --- | --- | --- |
| Inline | `:name[text]{attributes}` | Inside a paragraph |
| Block | `::name[text]{attributes}` | On a line of its own |
| Container | `::name{…}` … `::/name` | A block with a body |

## There is one block form, and the close names what it ends

`::name{…}` on a line opens a block. If `::/name` appears below it, that block
becomes a **container** and everything in between is its body. A block nobody
closes is a **leaf**.

The two are written identically on purpose: nothing is counted, and two
containers written the same way still nest, because each close says which
opening it is ending.

```markdown
::accordion{density="compact"}
::accordion-item{label="First" open}
The content of the first item.
::/accordion-item
::accordion-item{label="Second"}
The content of the second.
::/accordion-item
::/accordion
```

Depth is counted per name, so a form inside a form ends at its own `::/form`.

> **The old colon rule is no longer read.** A container used to open with three
> or more `:` and close with a line of exactly the same length, which forced the
> outer container to carry *more* colons than the ones it held. It worked, but
> it made nesting — the thing everybody does — the one thing you had to count.
> Three colons on a line are text today.

## The attributes

In braces, separated by spaces. An attribute with no value is a flag.

```markdown
::input{field="price" type="number" min="0" required}
```

The quotes matter more than they look: the scanner reads them as one unit, so a
regular expression carrying its own braces survives.

```markdown
::input{field="postcode" pattern="^[0-9]{5}$" message="Five digits"}
```

Without that rule the `{5}` would close the attribute list and the line would
stop being a directive at all: the field simply would not appear.

> **A hex colour cannot go in an attribute.** `#` belongs to the reactive
> references, so `color="#65c3c8"` is read as a binding to the key `65c3c8`.
> Write the name of the colour, or `rgb(101 195 200)`.

## `#ref` versus a bare id

It is the central rule, and confusing it produces no visible error.

- A **bare id** is the key a control *writes* to: `::slider[volume]` stores its
  value under `volume`.
- A **`#ref`** is a view that *reads* that key and follows it:
  `:value[v]{ref="#volume"}`.

A view bound to a store key rather than to a reactive reference simply never
updates, and nothing reports anything — which is why the two are kept apart from
the grammar up, and why `:value` with a non-reactive `ref` renders as an error
instead of as an inert span.

## When the square brackets are a key

For most directives `[text]` is a label. For a **source control** — a component
that carries `value` or `checked` — the brackets are the *storage key*, and the
visible text goes in the body:

```markdown
::checkbox[done]{}
Done
::/checkbox
```

Two consequences worth knowing before wondering why nothing happens:
`::switch` and `::search` declare neither `value` nor `checked`, so they store
nothing at all (`::input{type="checkbox"}` and `::table{search}` do those two
jobs); and a tick box has to be read through `checked`, not `value`, because its
value is what a form would submit — the empty string.

## A directive that does not exist stays written

The registry does not know every possible name, and a name it does not know is
rendered **as it was written**. An unimplemented directive must never make a
document lose text.

## The frontmatter

A document may open with a block delimited by `---`:

```markdown
---
appId: expenses
title: Shared expenses
description: Who paid for what
icon: receipt
lang: en
version: "1.0"
author: First Last
date: 2026-08-11
---
```

`appId` is three things at once: the storage key, the namespace of the
collections and the addressable part of the URL. Changing it *moves* the app.

The parser is a deliberately small YAML subset: ordered `key: value` lines,
matched surrounding quotes removed, and everything after the **first** colon
kept, so URLs and timestamps survive. A key this app has never heard of is still
shown in the info panel, exactly as it was written. A block that is not well
formed — or that nobody closes — stays body of the document: swallowing the rest
of a file because someone typed `---` would be far worse than ignoring it.
