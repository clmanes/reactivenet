# Directives

Two vocabularies, one syntax.

**ReactiveNET's own** directives describe an app's relationship with stored data —
pages, forms, lists, conditionals, arithmetic. There is no HTML element that means
"the rows of this collection", so these are ours.

**Spectrum's** directives are the 92 Adobe Spectrum web components, generated from
the library's own manifests. The directive name is the tag without `sp-`: the slider
is `::slider`, the badge is `::badge`, the accordion is `::accordion`. Adding a
component is a library upgrade, not a code change.

Where the two would collide, ours wins.

---

## Pages

### `::page` … `::/page`

Splits an app into pages with a sticky menu. A document with **one** page gets no
menu — a control with a single entry does nothing.

| Attribute | |
| --- | --- |
| `title` | The name shown in the menu |
| `icon` | A Spectrum workflow icon by name; a name outside the set is refused rather than drawn as nothing |

```markdown
::page{title="Today" icon="calendar"}
## Today
::/page

::page{title="Archive" icon="folder"}
## Archive
::/page
```

### `::columns` … `::/columns`

Lays its content out in columns that reflow by themselves. The document says how
narrow a column may get; how many fit is the grid's business.

| Attribute | |
| --- | --- |
| `min` | The narrowest a column may get — `18rem` by default |
| `gap` | `s`, `m` or `l` |

```markdown
::columns{min="16rem" gap="m"}
### Today
:count{path="spesa"} expenses.

### This month
:sum{path="spesa" field="price" decimals="2"}
::/columns
```

There is **no breakpoint**, and the question it does ask is about the *pane*, not the
window: at `/a/<id>` the preview is the whole window and beside an editor it is half
of one, so a media query would put three columns where there is room for one. Below a
narrow floor it is one column whatever `min` said.

---

## Data

A **collection** is a named list of rows belonging to one app. `path` names it. Rows
are stored in this browser only, under this app's namespace, and go when the app
goes.

### `::form` … `::/form`

Groups fields. Renders a `<div>`, never a `<form>` element — nothing here submits
anywhere.

| Attribute | |
| --- | --- |
| `path` | The collection its save button writes to |
| `id` | Only needed when two forms share a path, or when a field lives outside the form |

### `::input`

One field of a form.

| Attribute | |
| --- | --- |
| `field` | The name the value is stored under — **required** |
| `legend` | The visible label; falls back to the field name |
| `type` | `text` `number` `date` `time` `email` `tel` `url` `color` `checkbox` |
| `placeholder`, `value`, `min`, `max`, `step`, `required` | as on an HTML input |
| `pattern` | A regular expression the **whole** value must match |
| `message` | What to say when `pattern` refuses — without it the reader is told no by an expression they cannot see |
| `help` | A line of guidance under the field, before anyone gets it wrong |
| `form` | Only when the field is *not* inside its form |

`type="ref"` makes the field a choice of rows from another collection: `path` says
which, `label` says which of its fields to show. What is stored is the **row's id**,
so the reference survives that row being renamed — and a list shows it with the
`{field>path.label}` token.

```markdown
::input{field="who" legend="Paid by" type="ref" path="people" label="name"}
```

**Saving checks the draft.** `required` refuses a blank, `type` refuses a value that
is not one of those things, `min`/`max` refuse a value out of range and `pattern`
refuses one out of shape. Each complaint appears under its field, the field carries
`aria-invalid`, and the focus goes to the first one. Nothing is written until they are
all gone. A form nobody has filled in at all saves nothing and says nothing: that is
a mis-click, not a mistake.

### `::choose`

A dropdown of a collection's rows. Choosing one **writes a reactive key** — the
brackets name it, exactly as they do on `::slider[volume]` — so everything that reads
`#key` follows, and any `::od-query` whose SQL mentions `{#key}` runs again.

| Attribute | |
| --- | --- |
| `path` | The collection whose rows are the options |
| `field` | The field whose value is **stored**; omit it to store the row id |
| `label` | The field the reader **sees**; defaults to `field`, then the row id |
| `legend` | The visible label |
| `placeholder` | The text of the blank first option, which is a real choice |
| `sort`, `dir` | Order by another field instead of by what is shown |
| `value` | The value chosen at the start |
| `help` | A line of guidance under the control |

```markdown
::od-query{into="comuni" sql="SELECT DISTINCT codice_istat, comune FROM istat_sezioni ORDER BY comune"}
::choose[comune]{path="comuni" field="codice_istat" label="comune" legend="Comune"}

::od-query{into="sezioni" sql="SELECT * FROM istat_sezioni WHERE codice_istat = '{#comune}'"}
::map{path="sezioni" geojson="geojson" fill="popolazione"}
```

That is the whole shape: one query fills the dropdown, the dropdown writes the key,
the second query reads it back. Before this directive existed nothing could write a
reactive key *from data* — a document over the 7896 comuni had to fix one in the SQL
or ask the reader to type `058091` from memory.

It steers a **local** collection just as well, with no query anywhere — the key goes
into a view's `filter`:

```markdown
::choose[chi]{path="spese" field="chi" label="chi" legend="Chi"}

::list{path="spese" filter="chi=#chi"}
{cosa} — {importo}
::/list
```

Two things it does that are decisions, not accidents:

- **It is stored and shown separately**, because those are almost never the same
  field. A comune is chosen by its name and queried by its ISTAT code.
- **The options are sorted by what the reader reads**, not by the order the rows
  arrived in — the opposite of `::list`, which keeps insertion order because a list is
  a record of what happened. A dropdown is for *finding*, and 7896 comuni in fetch
  order cannot be found at all. `sort=` names another field when the alphabet is the
  wrong answer.

`::choose` is not `::input{type="ref"}` with a flag, and the difference is the central
rule of the language: `::input` fills a **form's draft**, `::choose` writes a
**reactive key**. Bare id versus `#ref` — the same distinction, in the two controls
that produce each.

### `::save`

Saves the form it is in as a new row — or updates the row being edited, if a list
put one there.

| Attribute | |
| --- | --- |
| `label` | The button's text |
| `form`, `path` | Only when the button is not inside the form it saves |

`::add-form` is the name this had before a form became the thing you write it inside.
It still works.

### `::cards` … `::/cards`

The same rows as `::list`, drawn as cards in a grid that reflows by itself — the
`::columns` mechanism, so "how narrow may a column be" is answered in one place.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `min` | The narrowest a card may get — `18rem` by default |
| everything `::list` takes | `sort`, `dir`, `filter`, `limit`, `group-by`, `deletable`, `editform` |

```markdown
::cards{path="spesa" min="16rem" deletable editform}
**{what}**

{who} · {price}
::/cards
```

### `::board` … `::/board`

The rows in columns, one per value of a field. **Dragging a card into another column
writes that field on that row** — that is the whole reason a board is worth more than
a grouped list.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `group-by` | The field whose values are the columns |
| `columns` | The columns to show, in order — keeps an empty one on screen |
| `min`, `sort`, `dir`, `filter`, `deletable`, `editform` | as elsewhere |

```markdown
::board{path="tasks" group-by="status" columns="todo,doing,done" min="14rem" editform}
**{what}**
{who}
::/board
```

A value that turns up and was not named still gets a column: a card is never hidden
because nobody predicted it. The drag is the browser's own, so it works with a mouse
and not on touch — which is why the card keeps its edit button.

### `::timetable` … `::/timetable`

The rows on a **grid of two fields at once** — one down the side, one across the top —
where dragging a card writes *both*. `::board` drags, but on one dimension; `::calendar
view="matrix"` draws two dimensions, but only reads them. A timetable is the two
together, and that is the only reason the directive exists.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `rows` | The field that says which row a record is in |
| `cols` | The field that says which column |
| `row-values` / `col-values` | The values of that axis, in order, comma separated |
| `row-labels` / `col-labels` | Headings shown instead of those values, in the same order |
| `pin` | A tick field marking a record that may not be dragged |
| `blocked` | A collection of forbidden cells, below |
| `colour` | Colour the cards by this field's values |
| `filter`, `deletable`, `editform` | as elsewhere |

```markdown
::timetable{path="lezioni" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" col-values="lun,mar,mer,gio,ven" colour="disciplina" pin="fisso" blocked="violazioni" deletable editform="modLezione"}
**{disciplina}**
{docente} · {aula}
::/timetable
```

The body is the **cell template**, substituted into text nodes exactly as `::list`
does — a cell shows what somebody typed, so it shows it as characters. An axis without
its `*-values` is the values the data actually holds, sorted; a value the data holds
and the list did not name still gets its line, so a lesson is never hidden because
nobody predicted its hour. A drop writes `rows` and `cols` on the dragged record, moves
`updatedAt` and leaves `createdAt` — the same arithmetic as `::board`. A record whose
`pin` field is ticked carries a flag and cannot be dragged at all: it is the lesson
somebody fixed by hand.

**The forbidden cells come from a collection, not from a function.** `blocked` names an
ordinary collection whose rows carry `row` and `col`, and optionally `for` — the id of
the one record the ban applies to — and `why`, the sentence to show. Without `for` the
cell is closed to everyone. So whatever decides what is legal is something that *writes
rows*: a `::python` block, a `::sql` query, a form somebody fills in. The grid enforces
and never computes, which is what keeps the rule visible: the reasons are rows you can
list, sort and count like any others. During a drag the cells say which they are —
allowed, warned, refused — and a drop on a refused cell is rejected with that row's
`why`. The colour is never the only signal: a closed cell carries its mark too.

### `::calendar` … `::/calendar`

The rows on a month grid, placed by their dates.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `from` | The date field a row starts on |
| `to` | The date field it runs to; without one a row is a single day |
| `sunday` | Start the week on Sunday rather than Monday |
| `sort`, `dir`, `filter` | as elsewhere |

```markdown
::calendar{path="tasks" from="start" to="end" sort="start"}
{what} · {who}
::/calendar
```

A row with a `to` is a **span**: it appears on every day between the two, drawn as one
bar across them, and named on the day it starts. The month always has six weeks, so
the grid does not change height as you move through the year, and the arithmetic is
done on the written `YYYY-MM-DD` — never on a parsed instant, which is midnight UTC
and lands on the day before west of Greenwich.

### `::list` … `::/list`

The rows of a collection. The body is a **row template**: `{field}` is replaced with
that row's value.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `deletable` | Give every row a delete button, confirmed in a dialog |
| `editform` | Give every row an edit button. Bare, it fills the form on this same path; with a value, it names another form by id |

```markdown
::list{path="items" deletable editform}
**{what}** — {who} · {createdAt}
::/list
```

A token may reach into another collection: `{who>people.name}` reads `who` as the id
of a row of `people` and shows that row's `name`. The token names the collection
itself, because a list is often nowhere near the form that made the reference, and a
token you cannot read on its own is a token nobody can check. A reference whose row
has gone shows the placeholder rather than an id nobody can read.

A value reaches the page as **text, never as markup**: a row containing `<script>` is
a row that displays those characters.

### `::table` … `::/table`

The same rows as a table, with a column per `::column` in its body. The header of
each column sorts by it; clicking the one already sorted turns it around.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `search` | A search box above the table, matching every column shown |
| `page-size` | Rows per page; omit for no paging |
| `sort` / `dir` | The column it opens sorted by, and which way (`asc`, `desc`) |
| `filter` | Show only rows matching `field=value` |
| `deletable`, `editform` | as on `::list` |

`::column` takes `field`, an optional `label` (defaults to the field name) and an
optional `align` — `start`, `center` or `end`.

```markdown
::table{path="spesa" search page-size="10" sort="price" dir="desc" deletable editform}
::column{field="what" label="Item"}
::column{field="who" label="For"}
::column{field="price" label="Price" align="end"}
::column{field="createdAt" label="Added"}
::/table
```

Numbers sort as numbers and everything else as text, so a column of prices comes out
in the order you meant. Values reach the cells as **text**, like every other stored
value, and dates are shown in your own format.

> `::table` takes the name from Spectrum's `sp-table`, which is a layout component
> composed one row and one cell at a time. Where the two vocabularies collide, ours
> wins — and a test asserts that `table` is the only name where they do.

### Choosing what a view shows

`::list` and `::table` differ in how a row is drawn, not in which rows they draw, so
they take the same questions:

| | on `::list` | on `::table` |
| --- | --- | --- |
| `sort` / `dir` | ✓ | ✓, and clickable headers |
| `filter="field=value"` | ✓ | ✓ |
| `limit` | ✓ | — use `page-size` |
| `group-by="field"` | ✓ | — |
| `search` | — | ✓ |
| `filters="a,b"` | — | ✓, one control per column |

`filters` is the reader's version of `filter`: it names the columns they may narrow
by, and the binder offers the values those columns actually hold — narrowed by
whatever else is already chosen, so a choice that would show nothing is not offered.
Two filters mean both.

`filter` is deliberately not an expression language: what a view needs is to show one
person's rows or one category's, and anything more is a query, not a view.

**A filter may name a reactive key** — `filter="who=#chi"` — and the view then follows
whatever that key holds: pair it with a `::choose`, a `::slider` or a `::textfield`
and the reader steers the view. Every row-reading view takes it, because they all ask
the same `RowView` the same questions.

An unset key filters for the *blank* value, and that is deliberate rather than a
quirk: it is what makes the master–detail shape work. Before anyone has chosen, the
detail shows nothing.

Only the views that name the key are redrawn, and only once the writes stop — a
`::textfield[k]` writes on every keystroke, and redrawing every table in the document
per character is how a preview stops responding.

### `::if-any` / `::if-empty` … `::/if-any`

Shows the body according to whether the collection has rows. Both start hidden and
appear once the collection has actually been read, so neither flashes the wrong
answer.

```markdown
::if-empty{path="items"}
Nothing here yet.
::/if-empty
```

### Every row carries two stamps

`createdAt` and `updatedAt` are ordinary fields with reserved names, so `{createdAt}`
works in a template and `field="updatedAt"` works in an aggregation with nothing
extra. An edit moves `updatedAt` and leaves `createdAt` alone.

They are **stored** as ISO 8601 and **shown** in the reader's own format. A field of
yours with either name is dropped rather than allowed to fight the stamp.

### `::python` … `::/python`

Real CPython, in the browser: the interpreter runs on WebAssembly in a worker, so a
loop somebody wrote by mistake cannot take the editor with it. The code goes in a
**fenced block inside the directive** — a fence is the one place markdown keeps
indentation exactly as written, and indentation is Python's syntax.

| Attribute | |
| --- | --- |
| `data` | Collections to pass in, comma separated. In Python they are `data["name"]`, lists of dicts of **strings** |
| `packages` | Packages to load: `numpy`, `pandas`, `scipy`, `matplotlib`, `scikit-learn`, `sympy`… names only, comma separated |
| `writes` | A collection to store the rows in `result` as |
| `params` | Reactive keys to pass in, comma separated. In Python they are `params["name"]`, strings like everything else |
| `manual` | Never run by itself: wait for the Run button |
| `show` | Show the code from the start rather than behind its button |

````markdown
::python{data="grades"}
```python
grades = [int(g["grade"]) for g in data["grades"] if g["grade"]]
if grades:
    passed = sum(1 for x in grades if x >= 6)
    print(f"Passed: {passed} of {len(grades)}")
    print(f"Average: {sum(grades) / len(grades):.1f}")
```
::/python
````

What is shown is what the code **printed**, then the value of its last expression, then
any matplotlib figures — and the traceback instead of all three when it fails. The code
itself is hidden behind a *Show code* button, because a document full of Python reads
as its results.

> Values from a collection are **strings**. `int(...)` or `float(...)` them before
> doing arithmetic, exactly as above.

**A block re-runs when what it depends on changes** — its code, its data, its packages
— and not otherwise: the preview re-renders on every keystroke, and a run per keystroke
would make the editor unusable.

**`writes` sends rows back.** Assign a list of dicts to `result` and they are stored as
a collection of this app, which a `::list` or a `::table` can then read:

````markdown
::python{data="spesa" writes="totals" packages="numpy"}
```python
import numpy as np
prices = np.array([float(r["price"]) for r in data["spesa"] if r["price"]])
result = [{"what": "average", "value": f"{prices.mean():.2f}"}] if len(prices) else []
```
::/python

::list{path="totals"}
{what}: {value}
::/list
````

A row that carries an `id` updates that row; one that does not gets a fresh id, so
running twice does not double the rows. A block cannot write to a collection it also
reads — that would re-run itself for ever, and it is refused rather than left to spin.

**`params` brings the controls in.** The weights of a model live on sliders, and
`data=` carries collections only: `params="weight,freeDay"` hands the block the current
value of those reactive keys — the ones `::slider`, `::input{type="checkbox"}` and
friends write, and `:value` reads — as `params["weight"]`. They are part of what the
block re-runs on, debounced 400 ms, so moving a slider re-runs it and moving it back
does not run it twice.

**`manual` means the block waits for its button.** A simulated annealing must not
restart because somebody corrected a surname, so a `manual` block never starts by
itself: its data and its parameters may move freely, and it runs on the Run button and
on nothing else — offered before the first run and again after every one. That is also
what buys it time: a run nobody asked for is killed after two minutes, a run somebody
asked for after ten.

**A long run can report, and can be stopped.** Two functions exist inside the code:
`progress(done, total, message)` draws the bar and says what it is doing — a call with
no total leaves the bar indeterminate, which is the honest shape of "no idea how long"
— and `partial(rows)` publishes the best answer so far, in the same shape as `result`.
While a block runs there is a **Stop** button; it terminates the interpreter and stores
the last `partial` it received, which is what makes "stop and keep the best answer so
far" a promise rather than a phrase. **A block that never calls `partial` gives Stop
nothing to keep**: the run ends and writes nothing at all. Publish one every time the
answer improves — the id rule is the same, so a partial updates its rows rather than
doubling them.

````markdown
::slider[weight]{label="Gap penalty" min="0" max="100" value="60"}

::python{data="lessons" params="weight" writes="clashes" manual}
```python
weight = float(params["weight"] or 0)
lessons = data["lessons"]
best = []
for i, lesson in enumerate(lessons):
    progress(i + 1, len(lessons), "checking constraints")
    if lesson.get("room") == "":
        best.append({"row": lesson["hour"], "col": lesson["day"], "why": "no room"})
    partial(best)
result = best
```
::/python
````

**The first run is slow.** It fetches the interpreter (13 MB, from this origin, cached
afterwards); a package is several megabytes more and comes from Pyodide's own CDN — the
only third party this app ever talks to, and only for documents that ask for one.

---

## Open data

Three directives read the open-data service — hundreds of public datasets in one
warehouse, reached as `/od` on this app's own origin. What comes back lands in an
**ordinary collection** (the `into` attribute), so every view, aggregation and
Python block above draws fetched rows exactly as it draws saved ones. The
collection is also the offline copy: when the service stops answering, the
status line shows the last rows received and says they are stale.

### `::od-query` — leaf

One SELECT into a collection.

```markdown
::textfield[comune]{value="TAORMINA"}

::od-query{into="farmacie" sql="SELECT nome, indirizzo FROM farmacie WHERE comune = '{#comune}' LIMIT 8"}

::list{path="farmacie"}
**{nome}** — {indirizzo}
::/list
```

`{#key}` placeholders bind reactive keys as **prepared parameters** — never text
pasted into the SQL, so nothing a reader types can change the query's shape —
and the query re-runs by itself, debounced, when a key it mentions changes. The
quoted form `'{#key}'` is accepted and the quotes are consumed with it. `limit`
caps the rows.

**Run the SELECT before you write it in — `reactive_od_query` does exactly that.**
The way an od-query fails is not the way you expect. A wrong column name is caught
immediately and says so; a wrong *value* is caught by nobody. String comparisons are
**case-sensitive**, so `WHERE regione = 'PUGLIA'` matches nothing at all in a column
that holds `Puglia`, and the app then renders empty cards and blank charts with no
error anywhere.

Worse, that failure often does not even look empty: `sum()` over no rows is `null`
and `count(*)` is `0`, so a headline query answers with **one row** —
`{popolazione: null, comuni: 0}` — which reads like a result. Check the values
themselves whenever a filter is on a name rather than a code:

```sql
SELECT DISTINCT regione FROM istat_indicatori ORDER BY 1
SELECT max(anno) FROM istat_indicatori WHERE regione = 'Puglia'
```

### `::od-datasets` — leaf

The catalogue itself — every dataset with its table name, row count and
description — into a collection: `::od-datasets{into="catalogo"}`.

### `::od-search` — leaf

A search box over the catalogue in natural language, or — with
`table="lex_atti"` and friends — over the rows of a searchable table. Results
land in `into`, ready for a `::list` to draw:

```markdown
::od-search{into="risultati" placeholder="Cerca nei dataset"}

::list{path="risultati"}
**{table_name}** {title_it}
::/list
```

---

## Charts

Seven leaves draw a collection directly — no Python, no packages; the engine is
a light chunk loaded only when a document has charts, and they redraw when the
collection changes:

```markdown
::chart-bar{data="spese" x="voce" y="importo"}
::chart-line{data="letture" x="ts" y="temperatura,umidita"}
::chart-pie{data="spese" label="categoria" value="importo"}
::chart-doughnut{data="spese" label="categoria" value="importo"}
::chart-area{data="vendite" x="mese" y="online,negozio" stacked}
::chart-radar{data="profili" x="voce" y="a,b"}
::chart-scatter{data="comuni" x="reddito" y="eta"}
```

`y` takes one or MORE numeric fields (a series each, colour-blind-safe fixed
palette); bars take `horizontal` and `stacked`. Stored values are strings and
convert with the decimal comma accepted; rows that do not parse are left out.
`height` is a CSS length (default 18rem), and a bare number means pixels —
`height="320"` and `height="320px"` are the same thing. Writing the number alone
used to do nothing at all: the CSS parser refuses a length without a unit and
refuses it *silently*, so the chart kept its default and the attribute looked
inert. The same holds for `::map`.

## Map

`::map{path}` shows a geolocated collection: a row is a marker, the body is the
popup template. `coords="posizione"` reads the `"lat, lon"` string `::geo`
writes; `lat=`/`lon=` read two columns. With `geojson=` each row is an AREA,
and `fill=` colours areas as a blue-quantile choropleth. `center`, `zoom`,
`height`, `tiles`+`attribution` for another basemap. Rows without valid
coordinates simply have no marker; the reader's view survives edits.

`::geo{field}` collects the position on a click; `::geocode{path from to}`
turns addresses into coordinates (max 50 per click, idempotent — a second click
resumes what is left). The scalar form `::geocode[key]{value="#indirizzo"}`
resolves one address into a reactive key.

**Two resolvers, local first.** An Italian address is looked up in ANNCSU — the
national archive of street numbers, twenty million of them with coordinates, held
by the open-data service on this app's own origin. That answer is instant,
unmetered, and never tells anybody what was searched. Only when it finds nothing
does the request go out to Nominatim, at its one-request-a-second policy.

It falls through for two honest reasons, and both are the reader's to know: ANNCSU
is Italy only, and 2.402 of 7.890 comuni have no coordinates in it at all. An
address abroad, or in one of those comuni, still resolves — just not from here.
With no open-data service on the origin, every address goes to Nominatim, exactly
as before.

Which one answered is visible in the network panel and nowhere else, deliberately:
a reader asking «where is this address» should get the same answer either way.

## Dashboard

`::dashboard{path}` ties nested views together with a cross-filter: clicking a
bar or slice of a nested chart narrows the sibling views — tables, lists,
cards, calendars, maps — to matching rows; the chart itself only highlights,
and a chip shows the filter with its ✕. The selection is this device's alone.

## World APIs: ::api-query

```markdown
::input[base]{value="EUR"}
::api-query{url="https://api.frankfurter.dev/v1/latest?base={#base}" into="cambi" pick="rates" as="pairs"}
::chart-bar{data="cambi" x="key" y="value"}
```

Any public https JSON API into a collection: `{#key}` URL placeholders are
reactive; `pick` walks by dots and indices; arrays of objects are rows, an
object of arrays zips by column (Open-Meteo's shape), an object of scalars is
one row or `{key, value}` pairs with `as="pairs"`. The form
`::api-query[key]{url pick}` with a scalar pick writes a reactive key. `every=`
polls (minimum 60 s); a refresh button always exists. The collection is local
to the device, out of the sync.

## Local SQL: ::sql

````markdown
::sql{data="clienti,ordini" into="fatturato"}
```sql
SELECT c.nome, sum(o.importo) AS totale
FROM ordini o JOIN clienti c ON c.nome = o.cliente
GROUP BY 1 ORDER BY 2 DESC
```
::/sql
````

A full SQL engine (DuckDB) in the browser: the collections in `data=` become
tables of the same name, types inferred, and the fenced body is one SELECT —
JOINs, GROUP BY, window functions. `{#key}` placeholders are reactive prepared
parameters; remote https Parquet/CSV read directly. The result is a derived,
device-local collection (max 1000 rows). The very first run downloads the
engine (~10 MB, then cached) behind a Run button.

## Machine learning: the ml-* directives

```markdown
::range[k]{min="2" max="10" value="4" legend="Numero di gruppi"}
::ml-cluster{data="comuni" features="reddito,eta" k="#k" into="gruppi"}
```

Five leaves run scikit-learn in the browser (the ::python runtime): `ml-cluster`
(K-means, adds `cluster`), `ml-anomaly` (Isolation Forest, adds `anomalia` 0–1
and `flag`), `ml-predict` (regression, adds `previsione`, R² in the status),
`ml-correlate` (Pearson `{a, b, r}` pairs, no download needed), `ml-forecast`
(time series: `x` numeric or ISO date, `y` value; `model=` linear/arima/sarima/
holt with a declared linear fallback; writes the fit plus `horizon` future
rows). `features` are NUMERIC fields, decimal comma accepted; unusable rows are
dropped and counted in the status. Numeric parameters accept `#keys`. The
executed code is a fixed template — the data never enters the code. Results are
derived, device-local collections; the first package download waits behind Run.

For `ml-forecast` whether a download is needed at all is the READER's choice —
the linear trend needs nothing, `arima`/`sarima`/`holt` need statsmodels — so
writing `model="#key"` and offering a picker is supported and the Run button
appears when the model that needs it is chosen, not when the block is drawn. The
status names the model actually used, and says why if the asked-for one failed
and the linear fallback ran instead. A differenced model has no in-sample fit for
its first observations: those rows carry no `previsione` (the projection line
starts where the model does) and the R² is measured only over what was fitted.

## The ai-* directives

The assistant, put to work **inside** the app rather than beside it. They all use the
one model configured once in the assistant's settings — a model on this machine
(Ollama), or an OpenAI-compatible endpoint with a key. **Where the data goes is a
property of that endpoint, not of the directive**: with a local model nothing leaves
the computer; with a remote provider, whatever the directive puts in the prompt is
sent to it. If no model is configured, each of these draws one sentence saying so and
the app keeps working.

The rule that makes them safe to put in a document somebody else wrote is that **the
model never produces anything that is executed**. It produces a word from a list the
document wrote, or an object whose keys the document declared, or a *query plan*
whose every field name was checked against the collection's own — and that plan is
then run here, on rows this device already has. Everything else is refused in
`core/AiDirective`, before it can become a row.

### Reading, and asking

```markdown
::ai-summary{data="spese"}
Riassumi le spese: quanto, in che cosa, e che cosa è cambiato.
::/ai-summary

::ai-chat{data="allenamenti"}
Sei il coach. Rispondi corto e in italiano.
::/ai-chat

::ai-query{data="spese" into="risposta" placeholder="Quanto ho speso in trasporti a giugno?"}

::table{path="risposta"}
::column{field="categoria" label="Categoria"}
::column{field="valore" label="Valore"}
::/table
```

`::ai-summary` rewrites itself whenever the rows change; only a sample of them
travels, never the whole collection. `::ai-chat` answers from the collections in
`data=` and says so when they do not contain the answer.

`::ai-query` is the interesting one. The question becomes a plan — filters, a
`group-by`, one aggregation — and the widget shows **the plan as well as the
answer**, because a reader who cannot see what was asked cannot tell a right answer
from a plausible one. A single number appears in the widget; a breakdown lands in
`into=`, ready for a `::table` or a `::chart-bar`.

### Filling a form

```markdown
::form{path="spese" id="f1"}
::input{field="voce" legend="Voce"}
::input{field="importo" type="number" legend="Importo"}
::input{field="categoria" legend="Categoria"}
::ai-assist{form="f1" placeholder="Pizza con Mario, giovedì, 24 euro"}
::ai-field{form="f1" field="categoria" values="cibo,casa,trasporti"}
::ai-suggest{form="f1" path="spese" fields="voce,importo:number"}
::save{label="Salva"}
::/form
```

None of these writes a row: they fill the **draft**, and the person presses the form's
own save button. `fields=` is `name:type` — `text` (the default), `number`, `date`,
`boolean` — and a value that is not of that type is left out rather than stored as
prose. `::ai-field` and `::ai-classify` choose from `values=` and nothing else: an
answer outside the list is dropped, never added to it.

`::ai-extract{form fields source}` is the same with the text coming from somewhere
else: `source="#dettato"` reads a reactive key, and without `source` it draws a box of
its own. `::ai-translate[nota]{to="en"}` and `::ai-rewrite{form="f1" field="testo"
style="più formale"}` work on one piece of text in place — a reactive key when the
brackets name one, a form field when `form`/`field` do.

`::ai-vision{form="f1" field="foto" target="descrizione"}` describes the image held by
a `::file` field into another field. It needs a model that reads images: Ollama with a
multimodal model, or OpenAI.

### Working through a collection

```markdown
::ai-classify{path="spese" field="categoria" values="cibo,casa,trasporti" label="Classifica"}

::ai-rule{data="spese" when="importo sopra 100" do="segna controllo a 'da verificare'"}

::ai-pipeline{data="segnalazioni" fields="ufficio,urgenza,sintesi"}
Classifica la segnalazione per ufficio e urgenza, e scrivi una sintesi di una riga.
::/ai-pipeline
```

`::ai-classify` only looks at rows where the field is still empty, unless you write
`overwrite`. `::ai-pipeline` only looks at rows where the **first** declared field is
empty — that is what "new rows" means here — and does at most 25 in a batch.

`::ai-rule` is the one that stops needing the model. It is compiled **once** into a
checked plan (a field, a comparison, a value, a field to write) kept in IndexedDB;
from then on it runs on every data change with no request at all — deterministic, and
idempotent because it only touches rows whose value would actually change.

### The agent

```markdown
::ai-agent{data="prenotazioni,stanze" tools="query,insert"}
Sei l'assistente prenotazioni: verifica la disponibilità con una query prima di
proporre un inserimento.
::/ai-agent
```

Two tools and no others. `query` reads the collections named in `data=`; `insert`
**proposes** a row, which appears with a confirm button and is written only when the
reader presses it. Every call leaves a line in the transcript, because an agent whose
steps are invisible is one nobody can check.

### Semantic search

```markdown
::ai-search{rag="documenti.allegato,documenti.note" placeholder="Cerca nei documenti"}

::ai-chat{data="documenti" rag="documenti.allegato,documenti.note"}
Rispondi citando i documenti fra parentesi quadre.
::/ai-chat
```

`rag=` names fields as `collection.field`. Their text — including the **content** of a
`::file` attachment, when it is text this browser can read on its own — is cut into
passages, embedded, and kept in IndexedDB. The index is rebuilt only when the text it
was built from has actually changed, and it never leaves the device except as a
request to whatever endpoint is configured.

The embedding model is **Qwen3-Embedding-0.6B** (`qwen3-embedding:0.6b`, about 600 MB
— `ollama pull qwen3-embedding:0.6b`), deliberately not a setting: the choice has two
honest answers, and the endpoint decides between them. Where the endpoint is OpenAI's
own, `text-embedding-3-small` is used instead, because that is the one host that will
not serve Qwen whatever you ask it for.

PDFs and scans are **not** indexed. Extracting those needs a parser and an OCR, and a
search that quietly indexed a file's *name* while looking as though it had read the
file would be worse than not offering it: such a file is indexed by its name, and the
citation can point at nothing else.

> The syntax of a container is `::name{…}` … `::/name`. Three colons on a line are
> plain text: the colon-fence form was removed, and the close says which directive it
> ends, which is what lets these nest without anybody counting.

---

## Workflow: ::workflow

````markdown
::workflow[Aggiornamento serale]{at="18:00" on="save:spese" label="Aggiorna"}

::od-query{into="listino" sql="SELECT codice, prezzo FROM prezzi_medi WHERE regione = '{#regione}'"}

::sql{data="spese,listino" into="scostamenti"}
```sql
SELECT s.voce, s.importo - l.prezzo AS delta
FROM spese s JOIN listino l ON s.codice = l.codice
```
::/sql

::ml-forecast{data="scostamenti" x="mese" y="delta" into="previsione" horizon="6"}

::/workflow

## Andamento
::chart-line{data="previsione" x="mese" y="delta"}
````

A container that runs the engines inside it **in dependency order**, with one
status line for the lot, a Run button, a schedule, and the rule that nothing
downstream of a failed step runs.

**Put inside it the directives that PRODUCE data and leave outside the views
that show it.** `::od-query`, `::od-datasets`, `::api-query`, `::sql`,
`::python`, the `ml-*`, and the four `ai-*` that work through a collection on
their own (`ai-summary`, `ai-classify`, `ai-rule`, `ai-pipeline`). Everything
else — a `::table`, a `::chart-*`, a form, a chat — belongs outside: those draw
what the workflow produced, and they update by themselves when it does.

**There is nothing new to write inside.** The steps are the ordinary directives
and **the edges are the collection names they already carry**: a step whose
`into=` another step names in `data=` runs before it. Order in the document is
only the tie-break, so two steps that do not feed each other stay where they
were written. A circle is reported and not run — the strip says which steps and
why, instead of spinning with nothing on screen saying so.

| attribute | what it does |
| --- | --- |
| `every` | `15m`, `2h`, `1d`, `90s` — at least 60 s. |
| `at` | `18:00`, local, once a day. |
| `catchup` | With `at=`, count any time later that day rather than only the hour after. |
| `on` | `save:collection`, `change:#key`, `open` — comma separated. |
| `label` | What the Run button says. |
| `show` | Show each step's own code and status rather than only the strip. |
| `quiet` | Run with no strip at all. |

**A workflow runs while the app is open, and the strip says so.** There is no
server here and no background execution: a schedule means *the first time the
app is open at or after that moment on a day it has not already run*, and the
missed evening is picked up when somebody opens the app — at once with
`catchup`, within the hour without it. Anything faster than a minute is raised
to one, because a background tab is throttled to about one timer a minute.

Without any of those attributes a workflow is exactly as reactive as the loose
directives are: it re-runs when the data moves, and every step's own signature
makes an unchanged one a no-op.

**Each step reports what it already reports.** The strip shows the engine's own
status — the same words, in the same language — so a step that failed says the
thing that engine says about failing. What the workflow adds is the line after
it: everything that step was feeding is marked *skipped* and does not run,
because a number computed from an input that never arrived is worse than no
number.

**What a step keeps is its own controls.** The first-run gate of `::sql` and the
`ml-*` packages, and a manual `::python` block's button, all stay where they
are: a step waiting for somebody to press something is reported as waiting, and
never silently skipped. Stop takes effect *between* steps — a request already in
flight finishes, and a Python block keeps its own Stop.

## Exploratory view: ::explore

```markdown
::explore{path="spese" view="bar" group-by="categoria"}
::/explore
```

An interactive pivot (Perspective, loaded only when used): the reader drags
columns, groups, switches chart and filters — even in reading mode, without
touching the document. Types are inferred from the data, so aggregations really
sum; the configuration the reader builds survives document edits. The optional
fenced body is the viewer's native JSON configuration and wins over attributes.

## Print, files, row arithmetic, Excel

`::print{target="fattura" label="Stampa fattura"}` prints only the container
with that id (give a `::card` an id); the print dialog also saves to PDF.

**`repeat` prints one page per row.** "A page per class" and "a page per teacher" are
the same request repeated, and twenty classes is not something anybody writes out by
hand. `repeat` names a collection, `key` the reactive key to set to each row in turn,
`field` which field of the row that key takes — the row's id when it is omitted, which
is what `::input{type="ref"}` stores:

```markdown
::list{path="lessons" filter="class=#class" id="classTimetable"}
{day} · {hour} — {subject}
::/list

::print{target="classTimetable" repeat="classes" key="class" field="name" label="Print one page per class"}
```

For each row the key is set, the views are given a moment to catch up, and the target
is *photographed* into a print container, one sheet per row with a page break between
them. The copies are dead HTML and nothing has to stay live; charts are frozen as the
picture they were showing, because a canvas copied without its pixels prints blank. The
key goes back to what it held when the run is over, so the screen before and after says
the same thing.

**The target has to depend on the key**, and nothing enforces that: a section that
does not read `#class` — no `filter="class=#class"`, no `:value{ref="#class"}` — is
photographed unchanged twenty times, and what comes out of the printer is twenty
identical pages. The button says nothing is wrong, because from where it stands
nothing is.

`::file{field="allegato" accept="image/*" maxkb="300"}` holds a file in a form
field: views show an image preview or a named download. Up to 300 kB the file
lives inside the row and syncs; larger files (up to `maxkb`, default 10 MB)
stay on the device that chose them — elsewhere the name shows without content.

Row templates compute arithmetic per row — `{qta*prezzo}` with missing fields
as zero and two decimals (`a-b` is a field name; subtraction needs spaces) —
and `:sum`/`:avg`/`:min`/`:max` accept the same expressions in `field=`:

```markdown
::table{path="righe"}
::column{field="voce" label="Voce"}
::column{field="qta*prezzo" label="Subtotale"}
::/table

Totale: :sum{path="righe" field="qta*prezzo" decimals="2"}
```

The data panel moves one collection as CSV — and as a real `.xlsx`, with the
same id rules: an id column updates the rows it came from, a plain spreadsheet
gets fresh ids.

## Calendar views

`::calendar{path field end by time form view tooltip}`: `view=month` (default),
`week` (one taller week, arrows step weeks), `agenda` (the month's busy days as
a list), `matrix` (rows are days, columns the values of `by=` — the planner).
`by=` colours events per value with a legend; `time=` orders inside the day;
`form="id"` makes days clickable — the click fills that form's date field;
`end=` makes multi-day spans with rounded corners only at the ends; every event
carries its row as a tooltip (`tooltip="false"` off, or a `{field}` template).
A Today button sits between the arrows.

---

## Values and arithmetic

### `:value` — inline

Reads a reactive key and follows it.

```markdown
The volume is :value[v]{ref="#volume"}.
```

`ref` must be a `#key`. See [`#ref` versus a bare id](language.md#ref-versus-a-bare-id).

### `:calc` — inline

Live arithmetic over reactive keys: `+ - * /`, parentheses, numbers and `#keys`.

```markdown
Total: :calc{expr="#price * #qty * 1.22" decimals="2"}
```

A missing or non-numeric key counts as zero, so a half-filled form shows a total that
grows as it is filled. A malformed expression or a division by zero has no answer at
all and renders as `—` rather than printing `NaN`.

`:calc` reads the keys `:value` reads — the ones controls write to. It is a bound
view, not a query over stored rows.

### Aggregations — inline

Over a stored collection. All take `path`; all but `count` take `field`; all take an
optional `decimals`.

| | |
| --- | --- |
| `:count{path}` | how many rows |
| `:sum{path field}` | the total |
| `:avg{path field}` | the average |
| `:min` / `:max` | the extremes |
| `:median` | the typical value |
| `:stddev` | the sample standard deviation |
| `:mode` | the most frequent value — works on text too |

They work on the *stored strings*, and a value that does not read as a number is
**not counted** rather than counted as zero: an average over four rows where one was
left blank is an average of three.

An empty collection has a count and a sum (both 0) but no average, minimum or median.
Those render as `—`, not as a zero that would claim otherwise.

---

## Spectrum components

Every component is available under its tag without `sp-`, as a block:

```markdown
::badge[Draft]{variant="neutral"}
::progress-bar{label="Volume" progress="#volume"}
::divider{size="m"}
```

…and, where it has content, as a block with a body:

```markdown
::accordion{density="compact"}
::accordion-item{label="How does nesting work?" open}
Each close names what it ends.
::/accordion-item
::/accordion
```

Composition follows Spectrum's own: an accordion holds accordion items, a tabs holds
tabs, a menu holds menu items. There are no per-component special cases here.

**The editor knows the whole set.** Typing `::` offers every directive; typing `{`
offers that component's attributes with their types and defaults; typing `="` offers
the values a choice attribute allows. The list comes from the same registry the
renderer validates against, so what is offered is what works.

**A component's attributes are documented by the component.** The registry carries
482 of them across 92 components, generated from the manifests, and the editor is the
place to read them — this page would go stale the day the library is upgraded.
