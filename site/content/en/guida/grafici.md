---
title: "Charts and exploratory views"
description: "The seven charts that draw a collection, the dashboard with its cross-filter, and the pivot the reader builds for themselves."
weight: 21
translationKey: "grafici"
---

A chart draws **a collection**, directly. There is no preparation step, no
Python, no intermediate format: you name the collection and the fields, and the
chart redraws itself whenever those rows change — whether that is somebody
saving a form, an `::od-query` answering, or a sensor writing.

The engine is a chunk loaded **only if the document has a chart**. A document
with none never downloads it.

## The seven

```markdown
::chart-bar{data="expenses" x="item" y="amount"}
::chart-line{data="readings" x="ts" y="temperature,humidity"}
::chart-area{data="sales" x="month" y="online,shop" stacked}
::chart-pie{data="expenses" label="category" value="amount"}
::chart-doughnut{data="expenses" label="category" value="amount"}
::chart-radar{data="profiles" x="item" y="a,b"}
::chart-scatter{data="towns" x="income" y="age"}
```

They fall into two families according to how they name the data, and that is the
only thing to remember.

**Bars, lines, areas, radar and scatter** take `x` and `y`:

| Attribute | |
| --- | --- |
| `data` | The collection to draw |
| `x` | The label field |
| `y` | One or **more** numeric fields, comma-separated: one series each |
| `height` | A CSS height; without it, `18rem` |

`::chart-bar` also takes `horizontal` — bars left to right, which is what you
want when the labels are people's or towns' names — and `stacked`, which piles
the series instead of grouping them. `::chart-area` takes `stacked`: stacked,
the series add up to their total, which is the right shape when the sum means
something.

**Pie and doughnut** take `label` and `value` instead, because a slice is a
category and a quantity and has no axis:

| Attribute | |
| --- | --- |
| `data` | The collection |
| `label` | The category field |
| `value` | The numeric field |
| `height` | A CSS height |

```markdown
::chart-bar{data="towns" x="town" y="spending" horizontal height="30rem"}
```

## What counts as a number

Stored values are **strings** — that is how a row is saved — and a chart has to
decide which of those strings are numbers. The rule is that it is the **whole**
string, not its beginning: `2026-08-10` is not the year 2026 and `10 items` is
not ten. The **decimal comma is accepted**, because chart data often comes from
a CSV or a public dataset, and there `1.234,50` is how it is written.

A row that does not read as a number **is left out**, not drawn as zero. The
difference shows: an average over four rows where one is blank is an average of
three, and a bar at zero would say that town spent nothing rather than "we do
not know".

## The colours

The palette is fixed, and it is **Okabe-Ito**, in order: eight colours chosen so
they stay apart for someone who cannot tell red from green. It is deliberately
not configurable — a chart with hand-picked colours is a chart somebody will
have to re-check, and the first series of every chart in the app being the same
colour is half of what makes a dashboard readable.

## `::dashboard` … `::/dashboard` — the cross-filter

A dashboard ties together the views it contains. Clicking a bar or a slice of a
nested chart narrows **all the other views** — tables, lists, cards, calendars,
maps — to the rows carrying that value. A second click on the same bar clears
it, and a chip at the top shows the filter with its ✕.

```markdown
::dashboard{path="expenses"}
::chart-bar{data="expenses" x="category" y="amount"}

::table{path="expenses" search}
::column{field="item" label="Item"}
::column{field="amount" label="Amount" align="end"}
::/table
::/dashboard
```

Three rules, taken from the tools that do this for a living:

- **The chart you clicked never filters itself.** It dims the other bars and
  keeps them. A chart that collapsed to a single bar would remove exactly the
  context you were looking at it for.
- **A view over another collection filters only the rows that HAVE that field.**
  Rows without it stay.
- **The selection belongs to this device**, is never synced, and survives edits
  to the data. What I am looking at is not a fact about the app, it is a fact
  about this session.

## `::explore` … `::/explore` — the reader's pivot

```markdown
::explore{path="expenses" view="bar" group-by="category"}
::/explore
```

An interactive pivot table: the reader drags columns, groups, switches chart and
filters — **even in reading mode**, without touching the document. This is the
directive for when you do not know in advance what question will be asked of the
data.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `view` | The initial chart: `datagrid`, `bar`, `line`, `area`, `scatter`, `heatmap`, `treemap`, `sunburst` |
| `group-by` | The fields that become the pivot's rows, comma-separated |
| `split-by` | The fields that become its columns |
| `columns` | The fields shown as values |
| `height` | A CSS height; without it, `24rem` |

Column types are **inferred from the data** — a string that is wholly a number
goes in as a number — so aggregations really sum instead of concatenating. The
configuration the reader builds **survives edits to the document**: somebody is
typing beside it, the preview redraws on every keystroke, and the pivot stays as
it was.

The optional fenced body is the viewer's native JSON configuration and **wins
over the attributes**, for anyone who already has a saved configuration to paste
in.

> A column name the rows do not have is dropped before the configuration is
> applied, and that is not fussiness: that viewer restores all or nothing, so
> one wrong name would cost the whole configuration — the chart included — and
> the reader would get a datagrid where the document asked for a chart, with
> nothing saying why.

## On a page that is not showing

A chart and a pivot **measure themselves**: they need to know how wide they are
in order to draw. A `::page` that is not the one showing has no size at all, so
a view built there would draw inside a box of zero pixels. It is not something
to handle: the app waits for the page to appear and builds then. It is worth
knowing only so that a chart on a page nobody has opened not having done
anything yet is not a surprise.
