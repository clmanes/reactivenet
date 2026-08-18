---
title: "Data directives"
description: "Forms, lists, tables, boards, calendars, conditionals, aggregations and Python: the directives that give an app its data."
weight: 20
translationKey: "direttive"
---

A **collection** is a list of rows belonging to an app. `path` names it. The
rows live in this browser only, under this app's namespace, and they leave when
the app leaves.

These directives are ReactiveNET's own and will never be Spectrum components:
there is no HTML element that means "the rows of this collection".

## Pages and columns

### `::page` … `::/page`

Splits an app into pages with a sticky menu. A document with **one** page gets
no menu at all: a control with a single entry does nothing.

| Attribute | |
| --- | --- |
| `title` | The name shown in the menu |
| `icon` | A Spectrum icon by name; a name outside the set is refused rather than drawn as nothing |

```markdown
::page{title="Today" icon="calendar"}
## Today
::/page

::page{title="Archive" icon="folder"}
## Archive
::/page
```

### `::columns` … `::/columns`

Lays the content out in columns that reflow by themselves.

| Attribute | |
| --- | --- |
| `min` | How narrow a column may get — `18rem` by default |
| `gap` | `s`, `m` or `l` |

There is no breakpoint, and the question it asks is about the **pane**, not the
window: at `/a/<id>` the preview is the whole window, beside an editor it is
half of it, and a media query would put three columns where there is room for
one.

## The form

### `::form` … `::/form`

Groups the fields. It draws a `<div>`, never a `<form>` element: nothing here
submits anywhere.

| Attribute | |
| --- | --- |
| `path` | The collection its save button writes to |
| `id` | Needed only when two forms share a path, or when a field lives outside the form |

Containment carries what an attribute used to repeat: a field inside a form does
not name the form, and a save button names neither the form nor its path.

### `::input`

A field of the form.

| Attribute | |
| --- | --- |
| `field` | The name the value is stored under — **required** |
| `legend` | The visible label; failing that, the field name |
| `type` | `text` `number` `date` `time` `email` `tel` `url` `color` `checkbox` `ref` |
| `placeholder`, `value`, `min`, `max`, `step`, `required` | as on an HTML input |
| `pattern` | A regular expression that **all** of the value must satisfy |
| `message` | What to say when `pattern` refuses — without it, the reader is contradicted by an expression they cannot see |
| `help` | A line of guidance under the field, before anyone gets it wrong |
| `form` | Only when the field is *not* inside its form |

`type="ref"` makes the field a choice among the rows of another collection:
`path` says which, `label` says which of its fields to show. What is stored is
the **row's id**, so the reference survives a rename.

```markdown
::input{field="who" legend="Paid by" type="ref" path="people" label="name"}
```

**Saving checks the draft.** `required` refuses an empty value, `type` refuses a
value that is not that thing, `min`/`max` refuse a value out of range and
`pattern` one out of shape. Every objection appears under its own field, the
field carries `aria-invalid`, and focus goes to the first. A form nobody filled
in at all saves nothing and says nothing: that is a mis-click, not an error.

Guidance is `aria-describedby`, not part of the label: a label's text *is* the
control's accessible name, and guidance inside it would be announced as part of
that name.

### `::save`

Saves the form it sits in as a new row — or updates the row being edited, if a
list put one there.

| Attribute | |
| --- | --- |
| `label` | The button's text |
| `form`, `path` | Only when the button is not inside the form it saves |

`::add-form` is the name it had before a form became the thing you write it
inside. It still works.

## The views over the rows

`::list`, `::cards`, `::table`, `::board` and `::calendar` draw the same rows
and ask the same questions — search, filter, sort, limit, page, group — and
differ only in the shape they draw.

### `::list` … `::/list`

The body is a **row template**: `{field}` is replaced with that row's value.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `sort` / `dir` | The field to sort on, and which way (`asc`, `desc`) |
| `filter` | Only the rows satisfying `field=value` |
| `limit` | How many rows at most |
| `group-by` | Group by field |
| `deletable` | A delete button per row, confirmed in a dialog |
| `editform` | An edit button; bare it fills the form on this same path, with a value it names another one by id |

```markdown
::list{path="items" sort="createdAt" dir="desc" deletable editform}
**{what}** — {who} · {createdAt}
::/list
```

A token can reach into another collection: `{who>people.name}` reads `who` as
the id of a row of `people` and shows its `name`. The token names the collection
because a list is almost always nowhere near the form that created the
reference.

A value reaches the page as **text, never as markup**: a row containing
`<script>` is a row that shows those characters.

### `::cards` … `::/cards`

The same rows drawn as cards in a grid that reflows by itself. It takes `min` on
top of everything `::list` takes.

### `::table` … `::/table`

One column for every `::column` in the body. The header sorts; a second click
reverses it.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `search` | A search box above the table |
| `page-size` | Rows per page; without it, no paging |
| `sort` / `dir` | How it opens |
| `filter` | Only the rows satisfying `field=value` |
| `filters="a,b"` | One control per column, with the values actually present |
| `deletable`, `editform` | as on `::list` |

`::column` takes `field`, an optional `label` and an `align` — `start`,
`center` or `end`.

```markdown
::table{path="expenses" search page-size="10" sort="price" dir="desc" deletable editform}
::column{field="what" label="Item"}
::column{field="price" label="Price" align="end"}
::/table
```

Numbers sort as numbers and everything else as text: "10" before "9" is right
nowhere, and in a column of prices it is wrong twice over. The sort is stable,
so rows that tie keep the order they were created in.

`filters` is the reader's version of `filter`: it names the columns they can
narrow on, and the values offered are the ones those columns really contain,
already narrowed by whatever else was chosen — so a choice that would show
nothing is not offered.

> `::table` takes its name from Spectrum's `sp-table`, which is a layout
> component composed one row and one cell at a time. Where the two vocabularies
> collide ours wins, and a test verifies that `table` is the only name where
> that happens.

### `::board` … `::/board`

The rows in columns, one per value of a field. **Dragging a card into another
column writes that value onto that row**: it is the whole reason a board is
worth more than a grouped list.

| Attribute | |
| --- | --- |
| `group-by` | The field whose values are the columns |
| `columns` | The columns to show, in order — it keeps an empty one on screen too |
| `min`, `sort`, `dir`, `filter`, `deletable`, `editform` | as elsewhere |

A value that turns up without having been named still gets its column: a card is
never hidden because nobody foresaw it. The drag is the browser's, so it works
with a mouse and not by touch — which is why the card keeps its edit button.

### `::timetable` … `::/timetable`

The rows on a grid of **two fields at once**, one down the side and one across
the top, where dragging a card writes both of them. `::board` drags, but on one
dimension only; `::calendar view="matrix"` draws two dimensions, but only reads
them. A timetable needs the two together, and that is the only reason this
directive exists.

| Attribute | |
| --- | --- |
| `rows` / `cols` | The fields that say which row and which column a lesson is in |
| `row-values` / `col-values` | The values of each axis, in order, comma separated |
| `row-labels` / `col-labels` | Headings shown instead of those values, in the same order |
| `pin` | A tick field marking a row that may not be dragged |
| `colour` | Colour the cards by this field's values |
| `blocked` | The collection that says which cells are forbidden |
| `path`, `filter`, `deletable`, `editform` | as elsewhere |

```markdown
::timetable{path="lessons" rows="hour" cols="day" row-values="1,2,3,4,5,6" col-values="mon,tue,wed,thu,fri" colour="subject" pin="fixed" blocked="clashes" deletable editform="editLesson"}
**{subject}**
{teacher} · {room}
::/timetable
```

The body is the **cell template**, substituted into text nodes as `::list` does.
An axis without its declared values is whatever the data holds, sorted, and a
value the data holds without having been named still gets its line. A drop
writes `rows` and `cols` onto the dragged row, moves `updatedAt` and leaves
`createdAt` alone: the same arithmetic as `::board`. A row whose `pin` field is
ticked carries a flag and cannot be dragged at all — it is the lesson somebody
fixed by hand.

The forbidden cells come from a collection, not from a function. `blocked` names
an ordinary one whose rows carry `row` and `col` and, where it matters, `for` —
the id of the single lesson the ban applies to — and `why`, the sentence to
show; without `for` the cell is closed to everyone. Whatever decides what is
legal is therefore something that *writes rows*: a `::python` block, a `::sql`
query, a form somebody fills in. The grid enforces and never computes, which is
what keeps the rule visible, because the reasons are rows you can list and count
like any others. During a drag the cells say what they are — allowed, warned,
forbidden — a drop on a forbidden one is refused with that row's sentence, and
the colour is never the only signal: a closed cell carries its mark as well.

### `::calendar` … `::/calendar`

The rows on a monthly grid, placed by their dates.

| Attribute | |
| --- | --- |
| `from` | The date field a row starts on |
| `to` | The date field it ends on; without it, the row is a single day |
| `sunday` | Start the week on Sunday rather than Monday |

A row with `to` is a **span**: it appears on every day between the two, drawn as
a single bar. The month always has six weeks, so the grid does not change height
as the reader moves through the year, and the arithmetic is done on the written
`YYYY-MM-DD` — never on a parsed instant, which is midnight UTC and falls the
day before west of Greenwich.

### `::if-any` / `::if-empty`

They show the body according to whether the collection has rows or not. Both
start hidden and appear once the collection has actually been read, so neither
flashes the wrong answer.

```markdown
::if-empty{path="items"}
Nothing here yet.
::/if-empty
```

### Every row carries two stamps

`createdAt` and `updatedAt` are ordinary fields with reserved names, so
`{createdAt}` works in a template and `field="updatedAt"` in an aggregation with
nothing extra. An edit moves `updatedAt` and leaves `createdAt` alone.

They are **stored** ISO 8601 and **shown** in the reader's format. A field of
your own with one of those names is dropped rather than left to fight the stamp.

## Values and arithmetic

### `:value` and `:calc`

```markdown
The volume is :value[v]{ref="#volume"}.

Total: :calc{expr="#price * #quantity * 1.22" decimals="2"}
```

`:calc` does live arithmetic over `+ - * /`, parentheses, numbers and `#keys`. A
missing or non-numeric key counts as zero, so a half-filled form shows a total
that grows; a malformed expression or a division by zero has no answer at all
and draws `—` instead of printing `NaN`.

It reads the keys `:value` reads — the ones controls write to. It is a bound
view, not a query over the stored rows.

### The aggregations

Over the stored rows. All take `path`, all but `count` take `field`, all accept
`decimals`.

| | |
| --- | --- |
| `:count{path}` | how many rows |
| `:sum{path field}` | the total |
| `:avg{path field}` | the mean |
| `:min` / `:max` | the extremes |
| `:median` | the typical value |
| `:stddev` | the sample standard deviation |
| `:mode` | the most frequent value — works on text too |

They work on the *stored strings*, and a value that does not read as a number is
**not counted** rather than counted as zero: an average over four rows one of
which was left blank is an average of three.

An empty collection has a count and a sum (both 0) but no average, no minimum
and no median. Those draw `—`, not a zero that would state something false.

## `::python` … `::/python`

Real CPython, in the browser: the interpreter runs on WebAssembly in a worker,
so a loop written by accident does not take the editor with it. The code goes in
a **fenced block inside the directive** — a fence is the one place Markdown
keeps indentation exactly as written, and indentation is Python's syntax.

| Attribute | |
| --- | --- |
| `data` | Collections to pass in, comma-separated. In Python they are `data["name"]`, lists of dictionaries of **strings** |
| `packages` | Packages to load: `numpy`, `pandas`, `scipy`, `matplotlib`, `scikit-learn`, `sympy`… |
| `writes` | A collection to store the rows of `result` in |
| `params` | Reactive keys to pass in, comma-separated. In Python they are `params["name"]`, strings like everything else |
| `manual` | Never runs by itself: it waits for its button |
| `show` | Show the code from the start rather than behind its button |

````markdown
::python{data="grades"}
```python
grades = [int(g["grade"]) for g in data["grades"] if g["grade"]]
if grades:
    print(f"Average: {sum(grades) / len(grades):.1f}")
```
::/python
````

What the code **printed** is shown, then the value of its last expression, then
the matplotlib figures — and the traceback in place of all three when it fails.

> A collection's values are **strings**. Put them through `int(...)` or
> `float(...)` before doing arithmetic with them, exactly as above.

**A block re-runs when what it depends on changes** — the code, the data, the
packages, the parameters — and not otherwise: the preview redraws on every
keystroke, and one run per keystroke would make writing impossible.

**`params` is how the controls get in.** A model's weights live on sliders, and
`data=` carries collections and nothing else: `params="gapWeight"` passes the
block the current value of those reactive keys — the ones `::slider` and its
kind write to, the ones `:value` reads — as `params["gapWeight"]`. They are part
of what the block re-runs for, with the same delay as every other reactive
directive, so moving a slider re-runs it and putting it back where it was does
not run it twice.

**`manual` means the block waits for its button.** A simulated annealing must
not restart because somebody corrected a surname: a `manual` block never starts
by itself, its data and its parameters move freely, and the run begins with the
*Run* button and with nothing else — offered before the first time and again
after each one. It is also what buys it time: a run nobody asked for is stopped
after two minutes, one somebody asked for after ten.

**A long run can report, and it can be stopped.** Two functions exist inside the
code: `progress(done, total, message)` draws the bar and says what is happening
— a call without a total leaves the bar indeterminate, which is the honest shape
of "I do not know how long this takes" — and `partial(rows)` publishes the best
solution found so far, in the same shape as `result`. While a block runs there
is a **Stop** button, which ends the interpreter and stores the last `partial`
received: that is what makes "stop it and keep the best result" a promise rather
than a sentence. A block that never calls `partial` gives Stop nothing to keep:
the run ends and writes nothing. Publish one whenever the solution improves —
the id rule is the same, so a `partial` updates its rows instead of doubling
them.

````markdown
::slider[gapWeight]{label="Weight of the gaps" min="0" max="100" value="60"}

::python{data="lessons" params="gapWeight" writes="clashes" manual}
```python
weight = float(params["gapWeight"] or 0)
lessons = data["lessons"]
best = []
for i, lesson in enumerate(lessons):
    progress(i + 1, len(lessons), "checking the constraints")
    if lesson.get("room") == "":
        best.append({"row": lesson["hour"], "col": lesson["day"], "why": "no room"})
    partial(best)
result = best
```
::/python
````

**`writes` sends the rows back.** Assign a list of dictionaries to `result` and
they become a collection of this app. A row carrying an `id` updates that row,
one without gets a new one, so running twice does not double the rows. A block
cannot write to a collection it also reads: it would re-run itself for ever, and
it is refused rather than left to spin.

**The first run is slow.** It downloads the interpreter (13 MB, from this
origin, then cached); a package is a few megabytes more and comes from Pyodide's
CDN — the only third party this app ever talks to, and only for the documents
that ask for one.

## `::print` — printing

`::print{target="invoice" label="Print the invoice"}` prints only the container
carrying that id — an `id` is given to a `::card` as to any other container —
and the print dialog saves to PDF too.

**`repeat` prints one page per row.** "One page per class" and "one page per
teacher" are the same request repeated, and twenty classes are not something
anybody writes out by hand.

| Attribute | |
| --- | --- |
| `target` | The id of the container to print |
| `label` | What the button says |
| `repeat` | A collection: print the target once per row of it |
| `key` | The reactive key set to each row in turn |
| `field` | Which field of the row that key takes; the id if omitted |

```markdown
::list{path="lessons" filter="class=#class" id="classTimetable"}
{day} · {hour} — {subject}
::/list

::print{target="classTimetable" repeat="classes" key="class" field="name" label="Print every class's timetable"}
```

For each row the key is set, the views are given a moment to catch up, and the
target is *photographed* into a printing container: one sheet per row, with a
page break between them. The copies are dead HTML and none of them has to stay
alive; charts are frozen at the image they were showing, because a canvas copied
without its pixels would print blank. At the end the key returns to the value it
had, so what is on screen before and after is the same.

The target has to depend on the key, and nothing enforces it: a section that
does not read `#class` — no `filter="class=#class"`, no `:value{ref="#class"}` —
is photographed identically twenty times, and twenty identical pages come out of
the printer. The button reports nothing, because from where it stands there is
nothing wrong.
