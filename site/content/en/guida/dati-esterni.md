---
title: "Data from outside"
description: "Open data, public APIs and a SQL engine in the browser: three ways to bring in rows nobody typed — and the workflow that puts them in order."
weight: 23
translationKey: "dati-esterni"
---

The data directives assume somebody writes the rows. These do not: they bring
rows from a service, a public API or a query, and put them in an **ordinary
collection**.

That is the decision that matters, and it holds for all three. What arrives is
not a special type: it is a collection like any other, so `::list`, `::table`,
`::chart-bar`, `:sum` and a `::python` block read it **exactly** as they read
hand-saved rows, without knowing where it came from. And the collection is also
the **offline copy**: when the service stops answering, the view shows the last
rows received with a status beside them saying they are stale, rather than an
error over data that looks live.

> A collection filled by one of these is **derived**: it is never pushed into a
> shared space, and a remote update cannot delete it. An exchange rate this
> browser downloaded is not a shared fact — it is a copy, and every device takes
> its own.

## Open data: `::od-query`, `::od-search`, `::od-datasets`

Three directives read the open-data service — hundreds of public datasets in one
warehouse, reached as `/od` **on the app's own origin**. There is no address to
configure, and no document can point the app at a host of its own choosing.

### `::od-query`

One SELECT into a collection.

```markdown
::textfield[town]{label="Town" value="TAORMINA"}

::od-query{into="pharmacies" sql="SELECT nome, indirizzo FROM farmacie WHERE comune = '{#town}' LIMIT 8"}

::list{path="pharmacies"}
**{nome}** — {indirizzo}
::/list
```

| Attribute | |
| --- | --- |
| `into` | The collection the rows land in |
| `sql` | The SELECT to run; `{#key}` binds a reactive key |
| `limit` | At most this many rows |

`{#key}` placeholders become **prepared parameters**, never text pasted into the
SQL. That is the difference between an app and a hole: those values come from
whoever is reading, and concatenating them would be SQL injection into the
service. The quoted form `'{#key}'` is accepted and the quotes are consumed with
the placeholder.

The query **re-runs by itself**, debounced, when a key it mentions changes. A
text field above and a query below are a complete application.

### `::od-search`

A search box over the catalogue in plain language — or, with `table=`, over the
rows of a searchable table. The results land in `into`.

```markdown
::od-search{into="results" placeholder="Search the datasets"}

::list{path="results"}
**{table_name}** {title_it}
::/list
```

It takes `into`, `placeholder` and `table`.

### `::od-datasets`

The catalogue itself — every dataset with its table name, row count and
description — into a collection: `::od-datasets{into="catalogue"}`. It is for
writing the document: you look at what columns a table really has before writing
the SELECT that names them.

## `::choose` — a dropdown that drives a query

```markdown
::od-query{into="towns" sql="SELECT DISTINCT codice_istat, comune FROM istat_sezioni ORDER BY comune"}
::choose[town]{path="towns" field="codice_istat" label="comune" legend="Town"}

::od-query{into="districts" sql="SELECT * FROM istat_sezioni WHERE codice_istat = '{#town}'"}
::map{path="districts" geojson="geojson" fill="popolazione"}
::/map
```

A dropdown built **from a collection's rows**. Choosing one writes a **reactive
key** — the brackets name it, exactly as on `::slider[volume]` — so everything
reading `#key` follows, and any `::od-query` whose SQL mentions it runs again.

| Attribute | |
| --- | --- |
| `path` | The collection whose rows are the options |
| `field` | The field whose value is **stored**; omit it to store the row id |
| `label` | The field the reader **sees**; without it, `field`, then the id |
| `legend` | The visible label |
| `placeholder` | The text of the blank first option, which is a real choice |
| `sort` / `dir` | Order by another field instead of by what is shown |
| `value` | The value chosen at the start |
| `help` | A line of guidance under the control |

That is the whole shape: one query fills the dropdown, the dropdown writes the
key, the second query reads it back. Before this directive existed **nothing
could write a reactive key from data**: a document over the 7,896 comuni had to
fix one in the SQL, or ask the reader to type `058091` from memory.

It steers a local collection just as well, with no query anywhere — the key goes
into a view's `filter`:

```markdown
::choose[who]{path="expenses" field="who" label="who" legend="Who"}

::list{path="expenses" filter="who=#who"}
{item} — {amount}
::/list
```

Two things it does that are decisions, not accidents:

- **It stores one thing and shows another**, because those are almost never the
  same field. A town is chosen by its name and queried by its ISTAT code.
- **The options are sorted by what the reader reads**, not by the order the rows
  arrived in — the opposite of `::list`, which keeps insertion order because a
  list is a record of what happened. A dropdown is for *finding*, and 7,896
  comuni in fetch order cannot be found at all.

> `::choose` is not `::input{type="ref"}` with a flag, and the difference is the
> central rule of the language: `::input` fills a **form's draft**, `::choose`
> writes a **reactive key**. Bare id versus `#ref`, in the two controls that
> produce each.

## `::api-query` — any public API

```markdown
::input[base]{value="EUR"}
::api-query{url="https://api.frankfurter.dev/v1/latest?base={#base}" into="rates" pick="rates" as="pairs"}

::chart-bar{data="rates" x="key" y="value"}
```

| Attribute | |
| --- | --- |
| `url` | The **https** address; `{#key}` placeholders are percent-encoded reactive parameters |
| `into` | The collection the rows land in |
| `pick` | The path into the JSON, by dots and indices: `results.0.series` |
| `as` | `pairs`, to turn an object of scalars into `{key, value}` rows |
| `every` | Poll every this many seconds; the minimum is 60 |

The JSON shapes are decided once and for all: an **array of objects** is the
rows; an **object of arrays** is zipped by column (Open-Meteo's shape); an
**object of scalars** is one row, or `{key, value}` pairs with `as="pairs"`.
With `::api-query[key]` and a `pick` pointing at a scalar, it writes a reactive
key instead of a collection.

A refresh button always exists, `every` or not. In a URL the placeholders are
**percent-encoded**, which in an address *is* the correct form of quoting — the
same care prepared parameters take in SQL.

## `::sql` — a SQL engine in the browser

````markdown
::sql{data="customers,orders" into="revenue"}
```sql
SELECT c.name, sum(o.amount) AS total
FROM orders o JOIN customers c ON c.name = o.customer
GROUP BY 1 ORDER BY 2 DESC
```
::/sql
````

A full SQL engine — DuckDB — inside the page. The collections named in `data=`
become **tables of the same name**, with types inferred (numbers are numbers),
and the fenced body is **one** SELECT: JOINs, GROUP BY, window functions.

| Attribute | |
| --- | --- |
| `data` | The collections that become tables, comma-separated |
| `into` | The collection the result lands in |
| `limit` | At most this many rows; the ceiling is 1000 |

`{#key}` placeholders are the same reactive prepared parameters as
`::od-query`'s. A remote https Parquet or CSV reads straight from its URL.

The **very first run** downloads the engine — about ten megabytes, then cached —
and waits behind a *Run* button, which is the rule for everything heavy: no
document makes somebody download ten megabytes for opening it without asking.


## `::workflow` — putting the engines in order

The directives on this page, plus `::python` and the `ml-*`, are already a
chain: `::od-query` fills a collection, `::sql` reads it and writes another, an
`ml-forecast` reads that one. What is missing is not the computation — it is all
there — but **an order, a moment to start, and one line saying where it has
got to**.

````markdown
::workflow[Evening update]{at="18:00" on="save:expenses" label="Update"}

::od-query{into="prices" sql="SELECT code, price FROM average_prices"}

::sql{data="expenses,prices" into="gaps"}
```sql
SELECT e.item, e.amount - p.price AS delta
FROM expenses e JOIN prices p ON e.code = p.code
```
::/sql

::ml-forecast{data="gaps" x="month" y="delta" into="projection" horizon="6"}

::/workflow

## Trend
::chart-line{data="projection" x="month" y="delta"}
````

**Inside goes what produces data; what shows it stays outside.** A `::sql` or an
`::od-query` draws nothing: it writes a collection, and what draws that is a view
elsewhere on the page, which updates by itself when the collection changes.

**There is no new language to learn and no wiring to write.** The steps are the
ordinary directives and **the edges are the collection names they already
carry**: a step whose `into=` appears in another's `data=` runs before it. The
order they were written in is only the tie-break, so two independent steps stay
where the author put them. A closed loop — A writing what B reads and back again
— is reported and not run, instead of spinning with nothing on the page saying
why.

| Attribute | |
| --- | --- |
| `every` | This often: `15m`, `2h`, `1d`, `90s` — at least 60 seconds |
| `at` | Once a day at this local time, e.g. `18:00` |
| `catchup` | With `at=`, catch up any time that day rather than only within the hour |
| `on` | What else starts it: `save:collection`, `change:#key`, `open` |
| `label` | What the button says |
| `show` | Show each step's own body and controls, not only the strip |
| `quiet` | Run with nothing on screen |

**It runs while the app is open, and the strip says so.** There is no server here
and no background execution: `at="18:00"` means *the first time the app is open
at or after 18:00 on a day it has not already run*. A missed evening is picked up
when somebody opens the app — at once with `catchup`, within the hour without it.
Nothing goes below a minute, because a background tab is throttled to about one
timer a minute and promising more would be promising what the browser will not
keep.

Without any of those attributes a workflow is as reactive as the loose
directives are: it re-runs when the data moves, and each engine's own signature
makes an unchanged step cost nothing.

**Every step reports what it already reports.** The strip shows the engine's own
status — the same words, in the same language. What the workflow adds is the line
after it: everything that step was feeding is marked *skipped* and does not run,
because a number computed from an input that never arrived is worse than no
number — on the page the two are indistinguishable.

What a step keeps is **its own controls**: the first-run button of `::sql` and of
the `ml-*` packages, and a `::python{manual}` block's own, all stay where they
are. A step waiting for somebody to press something is reported as waiting, never
silently skipped. *Stop* takes effect **between** steps: a request already in
flight finishes, and a Python block keeps its own Stop.
