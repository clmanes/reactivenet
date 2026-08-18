# ReactiveNET documentation

ReactiveNET turns a Markdown document into a working app. The document *is* the app:
it has a URL, it is stored in the browser, and the interactive parts are written as
**directives** in the text alongside ordinary prose.

Two audiences, two halves.

**Writing apps**

| | |
| --- | --- |
| [Language](language.md) | The syntax: inline, block, and the close that names what it ends. Attributes, `#refs`, frontmatter. |
| [Directives](directives.md) | Every directive, what it takes and what it does — pages, forms, lists, conditionals, arithmetic, and the 92 Spectrum components. |
| [Authoring an app](authoring.md) | From an empty app to one that stores data, in order. |

**Working on the platform**

| | |
| --- | --- |
| [Architecture](architecture.md) | How the pieces are arranged and why the boundaries are where they are. |
| [Storage](storage.md) | IndexedDB, key namespaces, backups, and what deleting an app takes with it. |
| [Security](security.md) | The threat model and the layers that answer it. |
| [Accessibility](accessibility.md) | What WCAG 2.2 AA means here, what is in scope, and what is enforced by tests. |

`CLAUDE.md` at the repository root is a separate document: it records the decisions
and the traps for whoever is changing the code next. These pages describe the system
as it is; that one describes why it is that way.

## The shortest possible example

```markdown
---
appId: shopping
title: Shopping list
---

::form{path="items"}
::input{field="what" legend="Item"}
::save{label="Add"}
::/form

::if-empty{path="items"}
Nothing on the list yet.
::/if-empty

::list{path="items" deletable}
{what}
::/list
```

That is an app. It stores rows in this browser, under this app's own namespace, and
nowhere else.
