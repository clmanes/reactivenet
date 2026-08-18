---
title: "Developer guide"
description: "The complete ReactiveNET language reference: syntax, data directives, charts, maps, open data, the assistant, components and the block editor."
translationKey: "guida-index"
---

A ReactiveNET app is a Markdown document. Not a project, not a bundle: a text
file any editor reads, in which some lines — the **directives** — become
fields, lists, tables, charts and calculations.

This guide is the reference for whoever writes them by hand. Anyone who would
rather describe the app in words can leave the writing to the assistant and
come back here only to understand what it produced.

## Where to start

1. **[Syntax](sintassi/)** — the three forms of a directive, how they nest,
   and the central rule: `#ref` versus a bare id.
2. **[Data directives](direttive/)** — forms, lists, tables, boards,
   calendars, aggregations and Python: what gives an app its data.
3. **[Charts and exploratory views](grafici/)** — the seven charts, the
   dashboard with its cross-filter, and the pivot the reader builds themselves.
4. **[Maps and coordinates](mappe/)** — a collection drawn on a map, the
   position collected by whoever fills the form, addresses resolved.
5. **[Data from outside](dati-esterni/)** — open data, any public API, a SQL
   engine in the browser, and the `::workflow` that puts them in order with a
   schedule and a single status line.
6. **[The assistant inside the app](assistente/)** — the fifteen `ai-*`
   directives, and the rule that makes them safe in somebody else's document.
7. **[Machine learning](apprendimento/)** — groups, anomalies, regression,
   correlations and forecasts, with scikit-learn in the browser.
8. **[Components](componenti/)** — the 92 Adobe Spectrum components, available
   without writing a line of code.
9. **[Block editor](editor-blocchi/)** — the same directives edited as blocks,
   with the slash menu and drag and drop.
10. **[The MCP server](mcp/)** — connecting a model: seven tools to write an
    app, check it and deliver it.

The ReactiveNET directives documented here are **58**, and that is all of them:
a test compares this guide against the registry the app itself reads, in both
languages, so a new directive cannot be left without its page.

## A complete app

```markdown
---
appId: expenses
title: Shared expenses
icon: receipt
---

::form{path="expenses"}
::input{field="what" legend="Item" required}
::input{field="price" legend="Price" type="number" min="0"}
::save{label="Add"}
::/form

::if-empty{path="expenses"}
Nothing yet. Add the first item above.
::/if-empty

::table{path="expenses" search page-size="10" deletable editform}
::column{field="what" label="Item"}
::column{field="price" label="Price" align="end"}
::column{field="createdAt" label="Added"}
::/table

Total: :sum{path="expenses" field="price" decimals="2"}
```

The form writes rows into the `expenses` collection, the table reads them back
with search, sorting and paging, the aggregation sums the column. There is
nothing else to configure: the document *is* the app.
