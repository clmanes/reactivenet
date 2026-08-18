# Directive test page

Every directive this app knows, with something concrete to paste and a line saying
what it should produce. It is a test page in the literal sense: a directive that
stops working is meant to be visible by reading the result, not by debugging.

The check is **manual**, and deliberately so: what a directive does is what it looks
like on the page, and nothing in a test runner sees that. What is written down here
instead is what to paste and what should come back, so the reading takes minutes and
does not depend on remembering how any of it is supposed to behave.

**115 directives**: 24 of ReactiveNET's own, 91 Spectrum components. Every one of
them appears in the app in §1, and again on its own in the appendix.

## Running it

1. Gallery → the first tile → the app opens in the editor.
2. Replace the source with §1, or with the one section you are checking.
3. Read the right-hand pane against the *Expected* table below it, page by page.

Everything here is a document, so it can be pasted into the Markdown editor as it is.
Nothing on this page needs a server, an account or a network.

Once it is in, the **Share** button turns the whole thing into one link: the document
rides in the URL's fragment, so somebody who has never opened this app gets a copy by
following it. That is also the quickest way to put the test app on a phone — which is
where the burger menu, the sticky bars and the one-column reflow are worth looking at.

## Reading the examples

Four rules cover every example below.

**One block form, and the close names what it ends.** `::form{…}` on its own line
opens a block; a `::/form` below it makes it a container and everything between them
its body. A block nobody closes is a leaf. Nothing is counted, so a form inside a
form still ends at its own `::/form`.

**A component that carries a value is a source, and its brackets are the store key.**
`::slider[volume]` writes to `volume`; the brackets are not a caption. Anything with
a `value` or `checked` attribute reads this way — checkbox, radio, menu-item, tab,
card, picker — so their visible text goes in the *body*:

```markdown
::checkbox[done]{emphasized}
Done
::/checkbox
```

Everything else takes its text in the brackets: `::badge[Draft]{variant="neutral"}`.
The appendix marks which is which.

**`#ref` reads, a bare id writes.** `::slider[volume]` writes to the key `volume`;
`:value[v]{ref="#volume"}` subscribes to it. A view bound to a bare id never updates
and says nothing about it, which is why the two are different things.

**An attribute the component does not have is reported, not ignored.** A wrong value
for a closed list is reported too. If an example renders as red text, that is the
renderer refusing it — read the message.

---

## 1. The app

One document, one page per class of directive, and every directive in the registry
somewhere inside it. Each page is something someone would actually build — shared
expenses, a bill to split, a dashboard — because a component tested in a real
arrangement fails in the ways it will fail in an app, and one tested on its own does
not.

Paste it whole. It is the app the rest of this page describes.

````markdown
---
appId: directive-sweep
title: Directive sweep
description: Shared expenses, and every directive in the registry
icon: shopping-cart
lang: en
version: "1.0"
date: 2026-08-10
---

::page{title="Expenses" icon="data"}
# Shared expenses

::form{path="spesa"}
::input{field="what" legend="What" required placeholder="Bread" help="What you bought."}
::input{field="who" legend="Who paid" required}
::input{field="price" legend="Price" type="number" step="0.01" min="0"}
::input{field="due" legend="When" type="date"}
::input{field="shop" legend="Postcode" pattern="[0-9]{5}" message="Five digits, no spaces" help="Where, if it matters."}
::input{field="settled" legend="Settled" type="checkbox"}
::save{label="Add"}
::/form

::if-empty{path="spesa"}
::illustrated-message{heading="Nothing spent yet" description="Add the first expense above."}
::/illustrated-message
::/if-empty

::if-any{path="spesa"}
## The last five

::list{path="spesa" sort="createdAt" dir="desc" limit="5" deletable editform}
**{what}** — {who} · {price} · {createdAt}
::/list

## All of them

::table{path="spesa" search filters="who,settled" page-size="10" sort="price" dir="desc" deletable editform}
::column{field="what" label="What"}
::column{field="who" label="Who"}
::column{field="price" label="Price" align="end"}
::column{field="due" label="When"}
::column{field="updatedAt" label="Changed"}
::/table

## As cards

::cards{path="spesa" min="15rem" sort="price" dir="desc" deletable editform}
**{what}**

{who} · {price}
::/cards

## Settled, by who paid

::list{path="spesa" filter="settled=true" group-by="who"}
{what} · {price}
::/list

| | |
| --- | --- |
| Expenses | :count{path="spesa"} |
| Total | :sum{path="spesa" field="price" decimals="2"} |
| Average | :avg{path="spesa" field="price" decimals="2"} |
| Cheapest | :min{path="spesa" field="price" decimals="2"} |
| Dearest | :max{path="spesa" field="price" decimals="2"} |
| Typical | :median{path="spesa" field="price" decimals="2"} |
| Spread | :stddev{path="spesa" field="price" decimals="2"} |
| Pays most often | :mode{path="spesa" field="who"} |
::/if-any
::/page

::page{title="Split" icon="calculator"}
# Split the bill

::field-label[Bill]{for="bill" required}
::number-field[bill]{min="0" step="0.5" value="60"}

::slider[people]{label="People" min="1" max="12" value="4" step="1" label-visibility="text" tick-labels editable}

::field-group{label="Add to the bill" horizontal}
::checkbox[service]{emphasized}
Service
::/checkbox
::checkbox[tip]{}
Tip
::/checkbox
::/field-group

::radio-group{name="rounding" selected="up"}
::radio{value="up" emphasized}
Round up
::/radio
::radio{value="exact"}
To the cent
::/radio
::/radio-group

::switch{emphasized}
Show the working
::/switch

Each pays :calc{expr="#bill / #people" decimals="2"} — :value[b]{ref="#bill"} between
:value[p]{ref="#people"}.

::help-text[The switch carries no value, so nothing above reads it.]{icon variant="negative"}

::divider{size="m"}

::textfield[note]{label="Note" placeholder="What was it for" maxlength="80"}

::picker[currency]{label="Currency" quiet}
::menu-item{value="eur"}
Euro
::/menu-item
::menu-item{value="gbp"}
Pound
::/menu-item
::/picker

::combobox{autocomplete="list" pending-label="Loading"}
::menu-item{value="pizza"}
Pizza
::/menu-item
::/combobox

::search{label="Find a person" placeholder="Name"}

::swatch-group{density="compact" shape="rectangle"}
::swatch{color="teal" label="Teal" rounding="full"}
::swatch{color="tomato" label="Tomato"}
::/swatch-group

::tags{}
::tag[Dinner]{deletable}
::tag[Shared]{}
::/tags

::dropzone{dropEffect="copy"}
Drop a receipt here.
::/dropzone

::button-group{}
::button[Save]{variant="accent" treatment="fill" type="button"}
::button[Cancel]{variant="secondary"}
::/button-group

::action-button{quiet toggles}
Undo
::/action-button

::clear-button{label="Clear the note" quiet}
::/page

::page{title="Plan" icon="calendar"}
# What is on

::board{path="tasks" group-by="status" columns="todo,doing,done" min="13rem" editform deletable}
**{what}**
{who}
::/board

::form{path="tasks"}
::input{field="what" legend="Task" required help="What has to happen."}
::input{field="who" legend="Who" type="ref" path="spesa" label="who" help="Anyone who has paid for something."}
::input{field="status" legend="Status" value="todo"}
::input{field="start" legend="From" type="date"}
::input{field="end" legend="To" type="date"}
::save{label="Add task"}
::/form

::calendar{path="tasks" from="start" to="end" sort="start"}
{what} · {who>spesa.who}
::/calendar
::/page

::page{title="Dashboard" icon="gauge3"}
# This month

::card{heading="August" subheading="Shared expenses" variant="quiet"}
:sum{path="spesa" field="price" decimals="2"} across :count{path="spesa"} expenses.
::/card

::slider[used]{label="Budget used" min="0" max="100" value="35" label-visibility="value"}

::progress-bar{label="Budget used" progress="#used" side-label}

::meter{label="Storage" progress="72" variant="negative" side-label}

::progress-circle{label="Working" size="m"}
::/progress-circle

::columns{min="14rem" gap="m"}
::badge[Draft]{variant="neutral" size="m"}
::badge[Settled]{variant="positive"}

::status-light[Everything saved]{variant="positive" size="m"}
::/columns

::alert-banner{open variant="info" dismissible}
Rows live in this browser only. Save the app to a file to take it elsewhere.
::/alert-banner

::toast{open variant="positive" timeout="6000"}
Expense added.
::/toast

::coach-indicator{quiet}

::asset{variant="file" label="receipt.pdf"}
::/asset

::truncated[A note far too long to sit in one column of a table]{success-message="Copied"}

## Worked out in Python

::python{data="spesa" writes="totals"}
```python
prices = [float(r["price"]) for r in data["spesa"] if r["price"]]
if prices:
    print(f"{len(prices)} expenses, {sum(prices):.2f} in total")
    result = [{"what": "average", "value": f"{sum(prices) / len(prices):.2f}"}]
else:
    print("Nothing to add up yet")
    result = []
```
::/python

::list{path="totals"}
{what}: {value}
::/list
::/page

::page{title="Sections" icon="compass"}
# If this app had sections

An app with more than a handful of pages grows chrome: a trail of where you are, a
rail of sections, tabs over one of them, a menu of what can be done to a selection.
None of it routes — an app's pages are `::page`, and the menu you are using now is
the one that does.

::breadcrumbs{label="You are here" max-visible-items="4" compact}
::breadcrumb-item{value="home"}
Home
::/breadcrumb-item
::breadcrumb-item{value="august"}
August
::/breadcrumb-item
::/breadcrumbs

::top-nav{label="Sections" selected="expenses" quiet}
::top-nav-item[Expenses]{selected}
::/top-nav-item
::top-nav-item[People]{}
::/top-nav-item
::/top-nav

::sidenav{label="Sections" value="today" variant="multilevel"}
::sidenav-heading{label="This week"}
::sidenav-item{value="today" selected}
Today
::/sidenav-item
::sidenav-item{value="archive" expanded}
Archive
::/sidenav-item
::/sidenav-heading
::/sidenav

::tabs{label="Views" selected="list" direction="horizontal" quiet}
::tab{value="list" selected}
List
::/tab
::tab{value="chart"}
Chart
::/tab
::tab-panel{value="list"}
:count{path="spesa"} expenses so far.
::/tab-panel
::tab-panel{value="chart"}
Nothing to draw yet.
::/tab-panel
::/tabs

::tabs-overflow{label-previous="Previous" label-next="Next" compact}

::action-group{selects="single" compact}
::action-button{quiet}
Day
::/action-button
::action-button{quiet}
Week
::/action-button
::/action-group

::action-menu{label="More" quiet}
::menu-item{value="rename"}
Rename
::/menu-item
::menu-divider{}
::menu-item{value="delete"}
Delete
::/menu-item
::/action-menu

::menu{label="Actions" selects="single"}
::menu-group{label="Recent" selects="single"}
::menu-item{value="open"}
Open
::/menu-item
::/menu-group
::/menu

::action-bar{emphasized flexible}
Two selected.
::/action-bar

::link[The guide]{quiet variant="secondary"} — and a link that works:
[the documentation](https://example.org).
::/page

::page{title="Help" icon="help"}
# Questions people ask

The page an app needs once someone else uses it: answers that fold away, and the
receipt they will ask about.

::accordion{allow-multiple density="compact" level="3"}
::accordion-item{label="Where is my data?" open}
In this browser, under this app's id. Deleting the app deletes it.
::/accordion-item
::accordion-item{label="Can I share an app?"}
Copy its link, or save it to a file. The rows stay here.
::/accordion-item
::/accordion

::card{heading="Receipt" subheading="12 August" variant="standard" asset="file"}
::thumbnail{size="500" background="black" cover}
![Logo](/logo.svg)
::/thumbnail
::/card

::avatar{src="/logo.svg" size="500"}
::icon{label="Search" size="m"}

::split-view{resizable collapsible primary-size="50%" label="Panes"}
Left.

Right.
::/split-view

::grid{gap="8px" padding="8px"}

::theme{color="dark" scale="large"}
A theme inside the app's own theme, which is what makes this a bad idea.
::/theme
::/page

::page{title="Category" icon="color-palette"}
# The colour of a category

Giving a category its colour, which is the one thing every list of categories ends up
needing.

A hex value cannot be written here: `#` marks a reactive key, so `color="#65c3c8"`
binds to a key named `65c3c8`. Name the colour instead.

::color-wheel{label="Hue" color="teal"}
::color-area{hue="200" label-x="Saturation" label-y="Brightness"}
::color-slider{label="Hue" color="teal"}
::color-field{view-color}
::color-handle{color="teal"}
::color-loupe{open color="teal"}
::/page

::page{title="Confirming" icon="panel"}
# What a confirmation is made of

Deleting a row asks first. These are the pieces that question would be built from —
written closed, on purpose.

An overlay with `open` puts itself in the top layer and leaves the document behind it
inert — nothing else can be clicked, and no directive closes it again. They are here
so the set is complete, not because a document should open one.

::dialog{size="s" dismissable no-divider}
A dialog needs an overlay to show it.
::/dialog

::dialog-base{underlay dismissable}
And a base to sit in.
::/dialog-base

::dialog-wrapper{headline="Delete this row?" confirm-label="Delete" cancel-label="Keep"}
The app's own delete confirmation is React's, not this.
::/dialog-wrapper

::alert-dialog{variant="warning"}
Something needs an answer.
::/alert-dialog

::popover{placement="bottom" tip}
A popover.
::/popover

::tray{has-keyboard-dismiss}
A tray.
::/tray

::underlay{}

::overlay{placement="bottom" type="modal"}
An overlay.
::/overlay

::overlay-trigger{placement="bottom" type="modal"}
Its trigger goes in a named slot, which a document cannot fill.
::/overlay-trigger

::tooltip{placement="top"}
A tooltip needs a focusable parent.
::/tooltip

::tooltip-openable{placement="top"}

::contextual-help{variant="help" label="What is a collection?" placement="bottom"}
A named list of rows belonging to this app.
::/contextual-help

::coachmark{current-step="1" total-steps="3" primary-cta="Next"}
One step of a tour.
::/coachmark
::/page

::page{title="Price list" icon="table"}
# A table nobody edits

Not every table is a collection. A fixed price list is written out cell by cell with
Spectrum's own table, and `::table{path}` is for the rows people actually add.

::table-head{}
::table-head-cell{sortable sort-direction="asc" sort-key="what"}
What
::/table-head-cell
::table-head-cell{sort-key="price"}
Price
::/table-head-cell
::/table-head

::table-body{}
::table-row{value="1" selectable}
::table-checkbox-cell{label="Select the row" emphasized}
::table-cell{}
Bread
::/table-cell
::table-cell{}
2.50
::/table-cell
::/table-row
::/table-body

## The rest of the pieces

::slider-handle{name="min" value="20" label="Minimum"}
::infield-button{inline="end" quiet}
::picker-button{position="right"}
::close-button{static-color="black"}
::/page
````

**Expected**, page by page.

| Page | What it should do |
| --- | --- |
| **Expenses** | *Add* saves a row and clears the form; pressing it with nothing filled in saves nothing at all. A blank *What*, a *Price* that is not a number, a date before its minimum or a postcode that is not five digits are each refused under the field they belong to, with the focus on the first — nothing is written until they are all gone. The guidance under a field is `aria-describedby`, not part of the field's name. The empty state gives way to the list, the table and the numbers. Dates read in your own format. A row's × asks in a modal that names it; its ✎ fills the form and turns *Add* into an update. The table searches, sorts both ways and pages; the editor does not reset either. |
| **Split** | Every control with a store key writes to it: the bill and the slider drive the division live, the tick boxes store `true`/`false`. The switch stores nothing — it has no `checked` — which is what the help text says. |
| **Plan** | *Who* is a `type="ref"` field: it lists the rows of another collection and stores the row's **id**, so renaming that row changes every view of it — the calendar's `{who>spesa.who}` reads it back. The board's columns are the values of `status`, plus any that turn up; dragging a card into another column rewrites that field and stamps `updatedAt`. The calendar places each task from `start` to `end` — a task with both is one bar across the days between, named on the day it starts. |
| **Dashboard** | The Python block runs real CPython on the rows of *Expenses* — the first run fetches the interpreter and takes a few seconds, the rest are quick — prints its two lines, and writes what it worked out into a `totals` collection the list below reads. Press *Show code* to see what ran. The badges and the status light sit in `::columns`, which reflows from several columns to one as the pane narrows — with the editor open it is already narrower. The card reads the same collection as the first page. The progress bar follows the slider, because `progress="#used"` is a binding rather than a number. The banner stays; the toast closes itself after its `timeout`, so refresh the page to see it again. |
| **Sections** | Every composite nests without counting anything: each close names what it ends. Tabs switch, the accordion on the next page opens, and none of it changes the page — that is the menu's job. |
| **Help** | The accordion holds its items, the card holds a thumbnail, the split view holds exactly two children. `::grid` renders nothing at all: `sp-grid` is described by the manifests and not shipped by the bundle. |
| **Category** | Six controls appear. They are driven by JavaScript properties, so a document can start them and not much more. |
| **Confirming** | Nothing is visible, which is the point: the app's own confirmation is a React dialog, and a document cannot open one. |
| **Price list** | A hand-composed table head and body, and the four controls that only make sense inside something else. |

---

## 2. ReactiveNET's directives, one at a time

### `::page`

```markdown
::page{title="Today" icon="calendar"}
Only page one is visible at a time.
::/page

::page{title="Archive" icon="folder"}
Page two.
::/page
```

**Expected** a menu with two entries; the chosen page survives typing in the editor.
Delete the second page and the menu goes away — one entry is not a choice.

### `::form`, `::input`, `::save`

```markdown
::form{path="people"}
::input{field="name" legend="Name" required placeholder="Ada"}
::input{field="age" legend="Age" type="number" min="0" max="120"}
::input{field="email" legend="Email" type="email"}
::input{field="site" legend="Site" type="url"}
::input{field="colour" legend="Colour" type="color" value="#65c3c8"}
::input{field="at" legend="Time" type="time"}
::input{field="ok" legend="Confirmed" type="checkbox"}
::save{label="Save"}
::/form
```

**Expected** one field per `::input`, labelled by `legend`; nothing repeats the form
or its path, because containment already says both. Saving writes one row to
`people` with those field names.

A field written *outside* its form names it instead:

```markdown
::form{id="person" path="people"}
::input{field="name" legend="Name"}
::/form

::input{form="person" field="note" legend="Note"}
::save{form="person" label="Save"}
```

### `::choose`

```markdown
::od-query{into="comuni" sql="SELECT DISTINCT codice_istat, comune FROM istat_sezioni WHERE regione = 'Molise' ORDER BY comune" limit="200"}
::choose[comune]{path="comuni" field="codice_istat" label="comune" legend="Comune" placeholder="Scegli un comune"}

Scelto: :value{ref="#comune"}

::od-query{into="sezioni" sql="SELECT sez_id, tipo_localita, popolazione FROM istat_sezioni WHERE codice_istat = '{#comune}' ORDER BY popolazione DESC" limit="500"}
Sezioni: :count{path="sezioni"} — abitanti: :sum{path="sezioni" field="popolazione"}
```

**Expected** a dropdown of 136 comuni **in alphabetical order** with a blank first
option carrying the author's placeholder, showing the name and storing the ISTAT
code. Choosing Termoli sets `:value` to `070078`, and the second query re-runs on its
own: 226 sections, 32.391 abitanti.

Three things to look at deliberately, because each is a failure that only appears in
the running app:

- **Type in the editor beside it.** The preview replaces every node it owns on each
  keystroke, so the select is rebuilt from nothing — and the choice must still be
  there afterwards, with the query still showing the same rows. It survives because
  the chosen option is restored from the *store*, never from the node: at seed time
  the fresh select has no options at all.
- **Watch the second query while the first is still loading.** It must not flap
  between filtered and unfiltered. A collection still being read is an empty
  collection, and rebuilding an empty dropdown would clear the key once per render.
- **Write it without brackets** (`::choose{path="comuni"}`) and it is an error on the
  page, not a control that quietly writes nowhere — the brackets are the key, and a
  selector that stores nothing is the one mistake nothing downstream can report.

And the same key steering a **local** view, which is the case with no query in it at
all — this is the one to check at `/a/<id>`, as a reader, never beside the editor,
because every keystroke there re-renders the document and would hide a view that does
not follow the key on its own:

```markdown
::choose[chi]{path="persone" field="who" label="who" legend="Chi"}
::list{path="persone" filter="who=#chi"}
{title} — {who}
::/list
```

**Expected** the list narrows within a fraction of a second of each choice, and
unchoosing empties it — an unset key filters for the blank value, which is what makes
a master–detail page show nothing before anyone has picked.

### `::list`

```markdown
::list{path="people" sort="name" dir="asc" filter="ok=true" limit="20" deletable editform}
**{name}** — {email} · {createdAt}
::/list
```

**Expected** one block per row, `{field}` replaced by that row's value. A row whose
name is `<script>alert(1)</script>` displays those characters: values arrive as text,
never as markup.

### `::table` and `::column`

```markdown
::table{path="people" search page-size="5" sort="age" dir="desc" filter="ok=true" deletable editform}
::column{field="name" label="Name"}
::column{field="age" label="Age" align="end"}
::column{field="updatedAt" label="Changed"}
::/table
```

**Expected** a search box, headers that sort (and turn around when clicked twice,
announcing `aria-sort`), and a pager. Typing in the editor does not reset the page or
the search — the table's state is kept per node, not rebuilt with the preview.

### `::if-any` and `::if-empty`

```markdown
::if-empty{path="people"}
Nobody yet.
::/if-empty

::if-any{path="people"}
:count{path="people"} people.
::/if-any
```

**Expected** exactly one of the two, and neither flashes the wrong answer first: both
start hidden and appear once the collection has been read.

### `:value` and `:calc`

```markdown
::slider[volume]{min="0" max="100" value="50" label-visibility="text"}

Volume is :value[v]{ref="#volume"}, doubled :calc{expr="#volume * 2"}.

::progress-bar{label="Volume" progress="#volume"}
```

**Expected** all three follow the slider as it is dragged. Write `ref="volume"`
without the `#` and `:value` renders an error rather than a span that quietly never
updates.

`:calc` with a missing key counts it as zero; a division by zero or a malformed
expression renders `—`, never `NaN`.

### The aggregations

```markdown
:count{path="people"} rows,
:sum{path="people" field="age"} years in total,
:avg{path="people" field="age" decimals="1"} on average,
between :min{path="people" field="age"} and :max{path="people" field="age"},
median :median{path="people" field="age"},
spread :stddev{path="people" field="age" decimals="2"},
most often :mode{path="people" field="name"}.
```

**Expected** a value that does not read as a number is not counted rather than
counted as zero — an average over four rows with one blank is an average of three.
`:mode` works on text too.

---
## 3. Appendix — every directive

### ReactiveNET

| Directive | Written as | |
| --- | --- | --- |
| `page` | `::page{title="Today" icon="calendar"} … ::/page` | container |
| `columns` | `::columns{min="16rem" gap="m"} … ::/columns` | container |
| `form` | `::form{path="items" id="item"} … ::/form` | container |
| `input` | `::input{field="what" legend="Item" type="text" required pattern="[A-Za-z ]+" message="Letters only" help="What you bought."}` | leaf |
| `input` (reference) | `::input{field="who" legend="Paid by" type="ref" path="people" label="name"}` | leaf, stores the row's id |
| `save` | `::save{label="Add"}` | leaf |
| `list` | `::list{path="items" sort="createdAt" dir="desc" filter="ok=true" limit="20" group-by="who" deletable editform} … ::/list` | container |
| `cards` | `::cards{path="items" min="16rem" sort="createdAt" dir="desc" deletable editform} … ::/cards` | container |
| `board` | `::board{path="tasks" group-by="status" columns="todo,doing,done" min="14rem" editform} … ::/board` | container, drag writes the field |
| `calendar` | `::calendar{path="tasks" from="start" to="end" sunday} … ::/calendar` | container |
| `table` | `::table{path="items" search filters="who,ok" page-size="10" sort="price" dir="asc" filter="ok=true" deletable editform} … ::/table` | container |
| `column` | `::column{field="price" label="Price" align="end"}` | leaf, inside `::table` |
| `if-any` | `::if-any{path="items"} … ::/if-any` | container |
| `if-empty` | `::if-empty{path="items"} … ::/if-empty` | container |
| `value` | `:value[v]{ref="#volume"}` | inline |
| `calc` | `:calc{expr="#price * #qty * 1.22" decimals="2"}` | inline |
| `python` | ` ::python{data="spesa" packages="numpy" writes="totals"} … ::/python ` | container; the body is a fenced code block |
| `workflow` | `::workflow[Evening]{at="18:00" catchup on="save:spese" every="15m" label="Update" show quiet} … ::/workflow` | container; the body is the engines that produce data |
| `count` | `:count{path="items"}` | inline |
| `sum` | `:sum{path="items" field="price" decimals="2"}` | inline |
| `avg` | `:avg{path="items" field="price" decimals="2"}` | inline |
| `min` | `:min{path="items" field="price"}` | inline |
| `max` | `:max{path="items" field="price"}` | inline |
| `median` | `:median{path="items" field="price"}` | inline |
| `stddev` | `:stddev{path="items" field="price" decimals="2"}` | inline |
| `mode` | `:mode{path="items" field="who"}` | inline |

`id` is available on every directive, ReactiveNET's and Spectrum's alike: it is an
HTML global and the handle one directive uses to point at another.

### Spectrum
*source* means the brackets name a store key and the visible text goes in the body.
*piece* means the component is part of a composition — it renders, but on its own it
does little.

#### Status and feedback

The components that say what is going on, and the ones that separate it.

| Directive | Written as | |
| --- | --- | --- |
| `badge` | `::badge[Draft]{variant="neutral" size="m"}` | |
| `status-light` | `::status-light[Saved]{variant="positive" size="m"}` | |
| `progress-bar` | `::progress-bar{label="Volume" progress="#volume" side-label}` | binds a `#key` |
| `progress-circle` | `::progress-circle{label="Loading" size="m"} … ::/progress-circle` | no `progress` means indeterminate |
| `meter` | `::meter{label="Storage" progress="72" variant="negative" side-label}` | |
| `toast` | `::toast{open variant="positive" timeout="6000"} … ::/toast` | |
| `alert-banner` | `::alert-banner{open variant="info" dismissible} … ::/alert-banner` | |
| `help-text` | `::help-text[Between 1 and 10]{icon variant="negative"}` | |
| `coach-indicator` | `::coach-indicator{quiet}` | piece |
| `illustrated-message` | `::illustrated-message{heading="Nothing here" description="Add a row."} … ::/illustrated-message` | |
| `asset` | `::asset{variant="file" label="Report.pdf"} … ::/asset` | |
| `divider` | `::divider{size="m"}` | `vertical` needs a sized parent |
| `truncated` | `::truncated[A value too long for its column]{success-message="Copied"}` | |

#### Controls

Everything a reader operates. The ones carrying a value are sources: their brackets name the store key.

| Directive | Written as | |
| --- | --- | --- |
| `button` | `::button[Save]{variant="accent" treatment="fill" type="button"}` | |
| `action-button` | `::action-button{quiet toggles} … ::/action-button` | source |
| `clear-button` | `::clear-button{label="Clear" quiet}` | piece |
| `close-button` | `::close-button{static-color="white"}` | piece |
| `infield-button` | `::infield-button{inline="end" quiet}` | piece |
| `picker-button` | `::picker-button{position="right"}` | piece |
| `checkbox` | `::checkbox[done]{emphasized} … ::/checkbox` | source — stores `true`/`false` |
| `radio` | `::radio{value="s" emphasized} … ::/radio` | source |
| `radio-group` | `::radio-group{name="size" selected="s"} … ::/radio-group` | holds `radio` |
| `switch` | `::switch{emphasized} … ::/switch` | stores nothing — no `checked` |
| `slider` | `::slider[volume]{label="Volume" min="0" max="100" value="50" step="1" label-visibility="text" editable tick-labels}` | source |
| `slider-handle` | `::slider-handle{name="min" value="20" label="Minimum"}` | source, piece of `slider` |
| `number-field` | `::number-field[qty]{min="1" max="10" step="1" value="1" hide-stepper}` | source |
| `textfield` | `::textfield[note]{label="Note" placeholder="Anything" maxlength="80" multiline}` | source, stores nothing — use `::input` |
| `search` | `::search{label="Search" placeholder="Filter"}` | a field, not `::table{search}` |
| `combobox` | `::combobox{autocomplete="list" pending-label="Loading"} … ::/combobox` | holds `menu-item` |
| `picker` | `::picker[country]{label="Country" quiet} … ::/picker` | source, holds `menu-item` |
| `swatch` | `::swatch{color="teal" label="Teal" rounding="full"}` | source |
| `swatch-group` | `::swatch-group{density="compact" shape="rectangle"} … ::/swatch-group` | holds `swatch` |
| `field-label` | `::field-label[Note]{for="note" required side-aligned="start"}` | |
| `field-group` | `::field-group{label="Notify me by" horizontal} … ::/field-group` | holds `checkbox` |
| `tag` | `::tag[Urgent]{deletable}` | |
| `tags` | `::tags{} … ::/tags` | holds `tag` |
| `dropzone` | `::dropzone{dropEffect="copy"} … ::/dropzone` | piece |

#### Navigation

Menus, tabs and rails. None of them route: an app's own pages are `::page`.

| Directive | Written as | |
| --- | --- | --- |
| `tabs` | `::tabs{label="Views" selected="form" direction="horizontal" quiet} … ::/tabs` | holds `tab`, `tab-panel` |
| `tab` | `::tab{value="form" selected} … ::/tab` | source |
| `tab-panel` | `::tab-panel{value="form"} … ::/tab-panel` | source, piece — hidden until its `tabs` selects it |
| `tabs-overflow` | `::tabs-overflow{label-previous="Previous" label-next="Next" compact}` | piece |
| `sidenav` | `::sidenav{label="Sections" value="today" variant="multilevel"} … ::/sidenav` | source |
| `sidenav-heading` | `::sidenav-heading{label="This week"} … ::/sidenav-heading` | |
| `sidenav-item` | `::sidenav-item{value="today" selected} … ::/sidenav-item` | source |
| `breadcrumbs` | `::breadcrumbs{label="You are here" max-visible-items="4" compact} … ::/breadcrumbs` | holds `breadcrumb-item` |
| `breadcrumb-item` | `::breadcrumb-item{value="today"} … ::/breadcrumb-item` | source |
| `top-nav` | `::top-nav{label="Sections" selected="today" quiet} … ::/top-nav` | |
| `top-nav-item` | `::top-nav-item[Today]{selected} … ::/top-nav-item` | no href — see `::page` |
| `menu` | `::menu{label="Actions" selects="single"} … ::/menu` | source, holds `menu-item` |
| `menu-item` | `::menu-item{value="open" selected} … ::/menu-item` | source |
| `menu-divider` | `::menu-divider{}` | |
| `menu-group` | `::menu-group{label="Recent" selects="single"} … ::/menu-group` | source |
| `action-menu` | `::action-menu{label="More" quiet} … ::/action-menu` | source, holds `menu-item` |
| `action-group` | `::action-group{selects="single" compact vertical} … ::/action-group` | holds `action-button` |
| `action-bar` | `::action-bar{emphasized flexible} … ::/action-bar` | piece — `open` makes it modal |
| `button-group` | `::button-group{} … ::/button-group` | holds `button` |
| `link` | `::link[Read the guide]{quiet variant="secondary"}` | no href — use a markdown link |

#### Layout and containers

What holds other things.

| Directive | Written as | |
| --- | --- | --- |
| `accordion` | `::accordion{allow-multiple density="compact" level="3"} … ::/accordion` | holds `accordion-item` |
| `accordion-item` | `::accordion-item{label="First" open} … ::/accordion-item` | |
| `card` | `::card{heading="August" subheading="Totals" variant="quiet" asset="file"} … ::/card` | source |
| `split-view` | `::split-view{resizable collapsible primary-size="50%" label="Panes"} … ::/split-view` | exactly two children |
| `grid` | `::grid{gap="8px" padding="8px"}` | **not in the loaded bundle** — never upgrades |
| `theme` | `::theme{color="dark" scale="large"} … ::/theme` | nests a second theme inside the app's |
| `thumbnail` | `::thumbnail{size="500" background="black" cover} … ::/thumbnail` | |
| `avatar` | `::avatar{src="/logo.svg" size="500"}` | |
| `icon` | `::icon{label="Search" size="m"}` | see `::page{icon}` |

#### Overlays

Written closed on purpose — see §5. Most are pieces of a composition the document cannot finish.

| Directive | Written as | |
| --- | --- | --- |
| `dialog` | `::dialog{size="s" dismissable no-divider} … ::/dialog` | piece |
| `dialog-base` | `::dialog-base{underlay dismissable} … ::/dialog-base` | piece — `open` makes it modal |
| `dialog-wrapper` | `::dialog-wrapper{headline="Delete this row?" confirm-label="Delete" cancel-label="Keep"} … ::/dialog-wrapper` | piece — `open` makes it modal |
| `alert-dialog` | `::alert-dialog{variant="warning"} … ::/alert-dialog` | piece |
| `popover` | `::popover{placement="bottom" tip} … ::/popover` | piece |
| `tray` | `::tray{has-keyboard-dismiss} … ::/tray` | piece — `open` makes it modal |
| `underlay` | `::underlay{}` | piece |
| `overlay` | `::overlay{placement="bottom" type="modal"} … ::/overlay` | piece — `open` freezes the page |
| `overlay-trigger` | `::overlay-trigger{placement="bottom" type="modal"} … ::/overlay-trigger` | piece, needs named slots |
| `tooltip` | `::tooltip{placement="top"} … ::/tooltip` | piece — needs a focusable parent |
| `tooltip-openable` | `::tooltip-openable{placement="top"}` | piece |
| `contextual-help` | `::contextual-help{variant="help" label="What is this?" placement="bottom"} … ::/contextual-help` | |
| `coachmark` | `::coachmark{current-step="1" total-steps="3" primary-cta="Next"} … ::/coachmark` | piece |

#### Colour

Driven by JavaScript properties, so a document can start them but not steer them.

| Directive | Written as | |
| --- | --- | --- |
| `color-area` | `::color-area{hue="200" label-x="Saturation" label-y="Brightness"}` | source |
| `color-field` | `::color-field{view-color}` | |
| `color-handle` | `::color-handle{color="teal"}` | piece — `#` is taken |
| `color-loupe` | `::color-loupe{open color="teal"}` | piece |
| `color-slider` | `::color-slider{label="Hue" color="teal"}` | source |
| `color-wheel` | `::color-wheel{label="Hue" color="teal"}` | source |

#### Spectrum's table

`sp-table` is a layout composed one cell at a time — not a collection. `::table` is ours.

| Directive | Written as | |
| --- | --- | --- |
| `table-body` | `::table-body{} … ::/table-body` | piece of Spectrum's table |
| `table-head` | `::table-head{} … ::/table-head` | piece |
| `table-head-cell` | `::table-head-cell{sortable sort-direction="asc" sort-key="what"} … ::/table-head-cell` | piece |
| `table-row` | `::table-row{value="1" selectable} … ::/table-row` | source, piece |
| `table-cell` | `::table-cell{} … ::/table-cell` | piece |
| `table-checkbox-cell` | `::table-checkbox-cell{label="Select" emphasized}` | piece |

Attributes are documented by the component, not here: the registry carries 482 of
them and the editor is where to read them. Type `{` inside a directive for the list,
`="` for the values a closed one allows.
## 4. What this page does not hide

- **Named slots are not expressible.** A directive's body goes to the default slot,
  so a dialog's `heading` and `footer`, or an `overlay-trigger`'s `trigger`, cannot
  be filled from a document. Those components are marked *piece*.
- **An overlay written `open` freezes the rest of the app.** It puts itself in the
  top layer, and the document behind it goes inert: nothing else can be clicked, and
  no directive can close it, because the thing that would is a trigger the document
  cannot express. That is why `overlay`, `dialog-base`, `dialog-wrapper`, `tray` and
  `popover` are written *closed* above — the one modal this app has is the delete
  confirmation, and it is React's, not a directive.
- **`sp-link` has no `href` in its manifest**, so `::link` cannot navigate. An
  ordinary markdown link does, and is checked against `SafeUrl` on the way in.
- **`::switch` and `::search` store nothing.** Their manifests carry no `value` or
  `checked`, so neither is a source — `::checkbox` and `::radio` are, and store
  `true`/`false`. `::input{type="checkbox"}` and `::table{search}` are what write to
  a collection and what filters one.
- **`#` belongs to the reactive keys**, so a hex colour cannot be written as an
  attribute value: `color="#65c3c8"` binds to a key named `65c3c8` and the colour
  never arrives. Name the colour, or write it as `rgb(101 195 200)`.
- **`sp-grid` is described by the manifests but not shipped by the bundle**, so
  `::grid` never upgrades: the element stays in the DOM and draws nothing. It is the
  one component of the 91 that cannot work at all.
- **A component that needs JavaScript properties** — the `color-*` family,
  `coachmark` — renders but stays inert: a document sets attributes, and only
  attributes.
- **`required` marks a field and refuses nothing.** Nothing here submits, so there is
  no submit to validate: the only thing the save button turns down is a draft with
  every field empty. A half-filled row is saved as written.
- **Python is real and therefore slow to start.** The first `::python` block on a page
  fetches a 13 MB interpreter from this origin; a `packages` attribute fetches several
  megabytes more from Pyodide's own CDN, which is the only third party this app ever
  talks to. A block re-runs when its code, its data or its packages change — not on
  every keystroke — and it cannot write to a collection it also reads.
- **A `::workflow` runs while the app is open, and cannot do otherwise.** There is no
  server here and the service worker precaches rather than executes, so `at="18:00"`
  means the first time the app is open at or after 18:00 on a day it has not already
  run — `catchup` chooses between the whole evening and the hour after. `every=` is
  raised to 60 s, because a background tab is throttled to about one timer a minute.
  The strip says all of this to the reader rather than leaving it to be discovered.
- **`::table` is ours, `sp-table` is Spectrum's.** The `table-*` rows above are the
  pieces of Spectrum's layout table, composed one cell at a time. A collection is
  `::table{path}`, and a test asserts `table` is the only name where the two
  vocabularies collide.

## Una mappa e un pivot in una pagina che non è la prima

Da provare a mano, perché è il caso che è già stato rotto due volte e nessun
test lo vede: mettere `::map` e `::explore` in una `::page` che **non** è quella
mostrata all'apertura, poi aprire quella pagina.

Cosa deve succedere: la mappa inquadra i suoi dati — l'area colorata riempie il
riquadro, non è un francobollo in mezzo al mondo — e il pivot ha un'altezza
vera con le sue righe dentro. Entrambi vanno provati anche **come foglia**,
senza corpo (`::map{path=…}` su una riga sola): scritti così finivano nel
registro Spectrum e uscivano come un elemento vuoto, senza che niente dicesse
perché.

## Un workflow, provato a mano

Sono tre comportamenti che nessun test automatico vede, perché sono quello che
appare sulla pagina.

**L'ordine.** Scrivere due `::python` dentro un `::workflow` **al contrario** — il
consumatore (`data="passo1" writes="passo2"`) sopra, il produttore
(`writes="passo1"`) sotto — e una `::table{path="passo2"}` fuori. La striscia deve
elencarli nell'ordine in cui *girano*, cioè `passo1` prima di `passo2`, e la tabella
deve riempirsi: se l'ordine fosse quello scritto, il primo passo leggerebbe una
collezione ancora vuota e la tabella resterebbe così.

**Il passo saltato.** Cambiare il produttore in `raise ValueError("prova")`. Il primo
passo deve mostrare `✗` con il messaggio di Python — le sue parole, nella lingua del
lettore — e il secondo `saltato — il passo prima non è riuscito`, senza essere
eseguito. Le righe che la tabella già mostrava **restano**: un risultato vecchio e
dichiarato tale è meglio di uno calcolato su un dato che non è arrivato.

**Il giro chiuso.** Due passi che si scrivono a vicenda (`data="b" writes="a"` e
`data="a" writes="b"`) più un terzo indipendente. Il terzo deve girare, i due devono
comparire come `⟲ in cerchio`, e sopra la lista deve esserci la frase che lo dice.
Senza questo controllo un workflow circolare girerebbe a vuoto per sempre e la pagina
non direbbe niente.

Da guardare anche: che i **controlli** di un passo restino visibili mentre il suo
stato e il suo codice spariscono — un `::sql` alla prima esecuzione, o un
`::python{manual}`, devono mostrare il loro pulsante dentro il workflow, altrimenti
sono un passo che non parte e nessuno sa perché.
