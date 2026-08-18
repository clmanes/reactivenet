// Pure. The registry the app actually uses: Spectrum's generated components, plus
// the attributes every element has regardless of what the manifest lists.
//
// The manifest describes each component's *own* API and stops there, so `id` — an
// HTML global, and the handle a document uses to point at an element — appears on
// none of them. Adding it here rather than special-casing the renderer keeps one
// code path: the renderer, the block specs and the editor completions all read this
// list, so all three gain it at once.
//
// There are deliberately no per-component overrides. The accordion used to have one,
// rendering to native `<details>`; it is now `sp-accordion` holding `sp-accordion-item`
// as Spectrum composes it, which the nesting rule makes expressible in the source.

let global: array<SpectrumRegistry.attribute> = [
  {
    name: "id",
    description: "Element id — how other directives refer to this element",
    kind: Text,
    choices: [],
    fallback: "",
  },
]

let withGlobals = (component: SpectrumRegistry.component): SpectrumRegistry.component => {
  ...component,
  attributes: component.attributes->Array.concat(
    global->Array.filter(extra =>
      !(component.attributes->Array.some(own => own.SpectrumRegistry.name == extra.name))
    ),
  ),
}

// ReactiveNET's own directives, described in the same shape as a Spectrum component
// so that every consumer keeps working without knowing the difference: the editor
// completions, the block specs and the attribute validation all read this one list.
// The `tag` is what the renderer emits for them, which is why it is a plain element
// here rather than an `sp-` one — these describe an app's relationship with its
// stored data, and no custom element means "the rows of this collection".

let attribute = (name, description, kind, choices): SpectrumRegistry.attribute => {
  name,
  description,
  kind,
  choices,
  fallback: "",
}

let text = (name, description) => attribute(name, description, Text, [])
let flag = (name, description) => attribute(name, description, Flag, [])
let number = (name, description) => attribute(name, description, Number, [])

let path = text("path", "The collection this reads or writes")
let field = text("field", "The field of the collection to summarise")
let decimals = number("decimals", "Decimal places; omit to trim trailing zeros")

let summary = (directive, description): SpectrumRegistry.component => {
  directive,
  description,
  tag: "span",
  package: "reactivenet",
  slots: [],
  attributes: [path, field, decimals],
}

let reactive: array<SpectrumRegistry.component> = [
  {
    directive: "page",
    description: "One page of the app; two or more produce a navigation menu.",
    tag: "section",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("title", "The name shown in the page menu"),
      // Offered as a closed list because it is one: an icon outside Spectrum's set
      // would upgrade to nothing and leave a silent gap in the menu.
      attribute("icon", "A Spectrum workflow icon", Choice, SpectrumIcons.all),
    ],
  },
  {
    // Columns that reflow with the room they have, and no breakpoint anywhere: the
    // grid is told the narrowest a column may be and works the rest out. A media
    // query would be the wrong question — beside the editor the preview is half a
    // window, and asking about the *window* gives three columns where there is room
    // for one.
    directive: "columns",
    description: "Lays its content out in columns that reflow to the room they have.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("min", "The narrowest a column may get, e.g. 18rem"),
      attribute("gap", "The space between columns", Choice, ["s", "m", "l"]),
    ],
  },
  {
    directive: "form",
    description: "Groups the fields of a form; the save button writes them as a row.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [path],
  },
  {
    directive: "input",
    description: "One field of a form.",
    tag: "input",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("field", "The name this is stored under"),
      // Containment says which form a field belongs to; this is only for a field
      // written outside the form it writes to.
      text("form", "The form's id, when the field is not inside it"),
      text("legend", "The visible label"),
      text("placeholder", "Hint shown while empty"),
      attribute(
        "type",
        "The kind of value",
        Choice,
        ["text", "number", "date", "time", "email", "tel", "url", "color", "checkbox", "ref"],
      ),
      // type="ref" turns the field into a choice of rows from another collection. It
      // stores that row's id, which is what makes the reference survive a rename;
      // what a reader sees is `label`, and a list shows it with {field>path.label}.
      path,
      text("label", "Which field of the referenced row to show"),
      text("value", "Initial value"),
      flag("required", "Must be filled before saving"),
      text("min", "Lowest accepted value"),
      text("max", "Highest accepted value"),
      text("step", "Increment"),
      // The author's own rule, and what to say when it refuses. Without the message
      // the reader is told no by an expression they cannot see.
      text("pattern", "A regular expression the whole value must match"),
      text("message", "What to say when the pattern refuses"),
      // Said once, under the field, before anyone gets it wrong — which is cheaper
      // than a complaint after.
      text("help", "A line of guidance shown under the field"),
    ],
  },
  {
    // The one piece missing between the data directives and the query directives.
    // `::od-query` already re-runs when a `{#key}` its SQL mentions changes, and
    // `ReactiveStore` already treats anything carrying `data-reactive-source` as a
    // source — but nothing could WRITE such a key *from a collection*. A picker's
    // options have to be written into the document by hand, and a row of a `::list` is
    // not a control. So a document over the 7896 comuni either fixed one in the SQL or
    // asked the reader to type `058091` from memory.
    //
    // It is deliberately NOT `::input{type="ref"}` with an extra attribute: that one
    // fills a form's draft, this one writes a reactive key, and those are the two sides
    // of the `#ref`-versus-bare-id rule. A directive that wrote to whichever of the two
    // an attribute named would make the distinction invisible exactly where it matters.
    directive: "choose",
    description: "A dropdown of a collection's rows; choosing one writes a reactive key.",
    tag: "select",
    package: "reactivenet",
    slots: [],
    attributes: [
      path,
      // Stored and shown are rarely the same field: a comune is chosen by its name and
      // queried by its ISTAT code.
      text("field", "The field whose value is stored; omit to store the row id"),
      text("label", "The field the reader sees; defaults to field, then the row id"),
      text("legend", "The visible label"),
      text("placeholder", "The text of the blank first option"),
      // A dropdown is for FINDING, which is why the binder orders it by what is shown
      // rather than keeping insertion order the way ::list does. This names another
      // field to order by, for the cases where the alphabet is the wrong answer.
      text("sort", "Order the options by this field instead of by what is shown"),
      attribute("dir", "Which way that order runs", Choice, ["asc", "desc"]),
      text("value", "The value chosen at the start"),
      text("help", "A line of guidance shown under the control"),
    ],
  },
  {
    directive: "save",
    description: "Saves the form it is in as a new row, or updates the row being edited.",
    tag: "button",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("label", "The button's text"),
      // Both only for a button written outside the form it saves; inside one, the
      // form and its path are already known.
      text("form", "The form's id, when the button is not inside it"),
      path,
    ],
  },
  {
    directive: "table",
    description: "The rows of a collection as a table; the body is one ::column each.",
    tag: "table",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      flag("search", "Show a search box above the table"),
      attribute("page-size", "Rows per page; omit for no paging", Number, []),
      text("sort", "The field the table opens sorted by"),
      attribute("dir", "Which way that sort runs", Choice, ["asc", "desc"]),
      text("filter", "Show only rows matching field=value"),
      // The author's `filter` is fixed; this is the reader's. Naming the columns
      // rather than offering every one of them is what keeps the row of controls
      // shorter than the table it sits above.
      text("filters", "Columns the reader may narrow by, comma separated"),
      flag("deletable", "Give every row a delete button"),
      text("editform", "Edit a row in a form; bare means the form on this path"),
    ],
  },
  {
    directive: "column",
    description: "One column of a table. Its header sorts.",
    tag: "th",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("field", "The field this column shows"),
      text("label", "The header text; defaults to the field name"),
      attribute("align", "Which edge the values sit against", Choice, ["start", "center", "end"]),
    ],
  },
  {
    directive: "list",
    description: "The rows of a collection; the body is the row template with {field} tokens.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      flag("deletable", "Give every row a delete button"),
      // Bare, it means the form on this same path — the usual case. A value names
      // another form, for a list edited somewhere other than where it is shown.
      text("editform", "Edit a row in a form; bare means the form on this path"),
      text("sort", "The field to order by"),
      attribute("dir", "Which way that order runs", Choice, ["asc", "desc"]),
      text("filter", "Show only rows matching field=value"),
      attribute("limit", "Show at most this many rows", Number, []),
      text("group-by", "Gather the rows under the value of this field"),
    ],
  },
  {
    // The same rows as ::list, drawn as cards in a grid that reflows by itself — the
    // ::columns mechanism, so there is one definition of "columns that fit".
    directive: "cards",
    description: "The rows of a collection as cards, in a grid that reflows.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      text("min", "The narrowest a card may get, e.g. 16rem"),
      flag("deletable", "Give every card a delete button"),
      text("editform", "Edit a row in a form; bare means the form on this path"),
      text("sort", "The field to order by"),
      attribute("dir", "Which way that order runs", Choice, ["asc", "desc"]),
      text("filter", "Show only rows matching field=value"),
      attribute("limit", "Show at most this many cards", Number, []),
      text("group-by", "Gather the cards under the value of this field"),
    ],
  },
  {
    // A board is the rows in columns, one per value of a field, and moving a card
    // between columns is what writes that field. Kanban is a verb here, not a layout.
    directive: "board",
    description: "The rows of a collection in columns, one per value; dragging a card rewrites it.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      text("group-by", "The field whose values are the columns"),
      // Named columns fix the order and keep an empty one on screen; without them the
      // board shows the values that happen to be there, which loses a column the
      // moment its last card leaves.
      text("columns", "The columns to show, in order, comma separated"),
      text("min", "The narrowest a column may get, e.g. 14rem"),
      flag("deletable", "Give every card a delete button"),
      text("editform", "Edit a row in a form; bare means the form on this path"),
      text("sort", "The field to order the cards by"),
      attribute("dir", "Which way that order runs", Choice, ["asc", "desc"]),
      text("filter", "Show only rows matching field=value"),
    ],
  },
  {
    // The one view that asks two questions of a row at once. A board writes one field
    // when a card moves; this writes both, which is the whole reason it exists — an
    // hour and a day are a cell, and a timetable is what you get when the pair can be
    // dragged. ::calendar view="matrix" draws rows against columns and reads only.
    directive: "timetable",
    description: "A two-dimensional grid of a collection — rows against columns — where dragging a card writes BOTH fields. Made for timetables: hours against days, rooms against shifts.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      text("rows", "The field that says which row a record is in"),
      text("cols", "The field that says which column"),
      // Declared values fix the order and keep an empty slot on screen; without them
      // the grid shows the values that happen to be there, which loses an hour the
      // moment its last lesson moves away.
      text("row-values", "The row values, in order, comma separated"),
      text("col-values", "The column values, in order, comma separated"),
      text("row-labels", "Headings for the rows, in the same order"),
      text("col-labels", "Headings for the columns, in the same order"),
      text("filter", "Show only rows matching field=value"),
      // The lesson somebody fixed by hand. It is data, not a mode: a tick in a field.
      text("pin", "A tick field marking a record that may not be dragged"),
      // The constraints are rows of a collection a validator writes, not a function
      // here: an author changes the rules by changing data.
      text("blocked", "A collection of forbidden cells: row, col, and optionally for and why"),
      text("colour", "Colour the cards by this field's values"),
      flag("deletable", "Give every card a delete button"),
      text("editform", "Edit a record in a form; bare means the form on this path"),
    ],
  },
  {
    // The rows on a month grid, placed by one of their date fields. The arithmetic is
    // core/MonthGrid, on the written year-month-day rather than on a parsed instant:
    // an instant is midnight UTC and lands on the day before west of Greenwich.
    directive: "calendar",
    description: "The rows of a collection on a month grid, placed by a date field.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      text("field", "The date field a row starts on"),
      text("from", "Older name for field; both are read"),
      // With an "end" a row is a span rather than a point: it appears on every day
      // from one to the other, which is what an event lasting a week actually is.
      text("end", "The date field a row runs to; without it a row is one day"),
      text("to", "Older name for end; both are read"),
      attribute("view", "How the days are laid out", Choice, ["month", "week", "agenda", "matrix"]),
      // One colour per value, with a legend — and in the matrix view these same
      // values are the columns.
      text("by", "Colour the events by this field's values"),
      text("time", "A HH:MM field that orders the events within a day"),
      text("form", "A form's id: clicking a day fills that form's date field"),
      text("tooltip", "\"false\" for none, or a template with {field} tokens; default is the whole row"),
      text("filter", "Show only rows matching field=value"),
      text("sort", "The field to order the rows within a day by"),
      attribute("dir", "Which way that order runs", Choice, ["asc", "desc"]),
      flag("sunday", "Start the week on Sunday rather than Monday"),
    ],
  },
  {
    // The orchestrator. Its body is the engines that already exist — od-query, sql,
    // python, ml-*, api-query, the ai-* that write — and it adds the four things none
    // of them can have on its own: an order, a trigger, one status, and the rule that
    // nothing downstream of a failed step runs.
    //
    // It deliberately introduces NO node language. The edges are the collection names
    // the steps already carry: `into=` above, `data=` below. Anything else would be a
    // second way to say what the document says once, and the analyzer would have two
    // graphs to disagree about.
    directive: "workflow",
    description: "Runs the engines inside it in dependency order — the collection one writes and another reads IS the edge — with one status line, a Run button, and nothing downstream of a failed step. every=/at= schedule it while the app is open; on= starts it from a saved row or a changed key. Put the directives that PRODUCE data inside it and leave the views that show it outside.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      // Elapsed time, floored at a minute: a background tab is throttled to about one
      // timer a minute, so anything faster is a promise the browser will not keep.
      text("every", "Run this often while the app is open: 15m, 2h, 1d — at least 60s"),
      // Wall clock, local. It can only mean "the first time the app is open at or
      // after this", which is what the strip says out loud.
      text("at", "Run once a day at this local time, e.g. 18:00 — when the app is open"),
      flag("catchup", "With at=, run any time later that day rather than only within the hour"),
      text("on", "What else starts it: save:collection, change:#key, open — comma separated"),
      text("label", "What the Run button says"),
      // A workflow's steps are usually noise to a reader: they produce collections
      // that the views elsewhere draw. Same default and same escape as ::python.
      flag("show", "Show each step's own code and controls rather than only the strip"),
      flag("quiet", "Hide the strip entirely: the workflow runs with nothing on screen"),
    ],
  },
  {
    // Real CPython, in a worker, over the app's own collections. The code goes in a
    // fenced block inside the directive, because indentation is Python's syntax and a
    // fence is the one place markdown keeps it exactly as written.
    directive: "python",
    description: "Runs Python on this app's data and shows what it prints.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("data", "Collections to pass in, comma separated; read as data[\"name\"]"),
      // Names only: numpy,matplotlib — no versions, no imports, no spaces. The import
      // statements belong in the Python, which is where they read as Python.
      text("packages", "Packages to load, comma separated: numpy, pandas, matplotlib…"),
      // The other direction: rows the code produced, stored as a collection of this
      // app, so a ::list or a ::table can read what Python worked out.
      text("writes", "Collection to store the rows in `result` as"),
      // The reactive keys the code reads as params["name"]. Sliders are how an author
      // exposes the weights of a model, and without this they never reach it.
      text("params", "Reactive keys passed in, comma separated; read as params[\"name\"]"),
      // A long computation must not restart because somebody corrected a surname.
      flag("manual", "Never run by itself: wait for the Run button"),
      flag("show", "Show the code from the start rather than behind its button"),
    ],
  },
  {
    directive: "if-any",
    description: "Shows the body only when the collection has rows.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [path],
  },
  {
    directive: "if-empty",
    description: "Shows the body only when the collection is empty.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [path],
  },
  {
    directive: "value",
    description: "A reactive value, shown inline and updated live.",
    tag: "span",
    package: "reactivenet",
    slots: [],
    attributes: [text("ref", "The key to read, written as #key")],
  },
  {
    directive: "calc",
    description: "Live arithmetic over reactive keys, e.g. expr=\"#price * #qty\".",
    tag: "span",
    package: "reactivenet",
    slots: [],
    attributes: [text("expr", "The expression, with + - * / and #keys"), decimals],
  },
  // The open-data directives: rows fetched from the same-origin /od service into
  // an ordinary collection, which every view then reads exactly as it reads rows
  // a form saved. The service is reached like PocketBase is — a proxy in dev, a
  // rewrite in production — so `connect-src 'self'` keeps holding.
  {
    directive: "od-query",
    description: "Runs one SELECT on the open-data service into a collection; {#key} placeholders become prepared parameters and re-run the query when the key changes.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("into", "The collection the rows land in"),
      text("sql", "The SELECT to run; {#key} binds a reactive key as a parameter"),
      number("limit", "At most this many rows"),
    ],
  },
  {
    directive: "od-search",
    description: "A search box over the open-data catalog — or, with table, over the rows of a searchable table. Results land in a collection, ready for a ::list to draw.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("into", "The collection the results land in"),
      text("placeholder", "What the empty search box says"),
      text("table", "Search this table's rows instead of the catalog"),
    ],
  },
  {
    directive: "od-datasets",
    description: "Lists the open-data catalog — every dataset, with its table name and row count — into a collection.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [text("into", "The collection the catalog lands in")],
  },
  // The generic REST connector: any public https JSON API into a derived,
  // device-local collection — or, with a store key in the brackets and a
  // scalar pick, into a reactive key.
  {
    directive: "api-query",
    description: "Reads a public https JSON API into a collection (local to this device, out of the sync). {#key} URL placeholders are reactive; pick walks the JSON by dots and indices; as=\"pairs\" turns an object of scalars into {key, value} rows. With [storekey] and a scalar pick it writes a reactive key instead. every= polls, minimum 60 seconds; a refresh button always exists.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("url", "The https address; {#key} placeholders are percent-encoded reactive parameters"),
      text("into", "The collection the rows land in"),
      text("pick", "Dot path into the JSON, e.g. results.0.series"),
      attribute("as", "How an object of scalars becomes rows", Choice, ["pairs"]),
      number("every", "Poll every this many seconds (minimum 60)"),
    ],
  },
  // The exploratory view: Perspective, the reader's own pivot table — drag,
  // group, chart, filter, without touching the document.
  {
    directive: "explore",
    description: "An interactive analysis view over a collection (Perspective, loaded only when used): the reader drags columns, groups, switches chart and filters — even in reading mode. Column types are inferred, so aggregations really sum. The optional fenced body is the viewer's native JSON configuration, which wins over the attributes.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      attribute("view", "The initial chart", Choice, ["datagrid", "bar", "line", "area", "scatter", "heatmap", "treemap", "sunburst"]),
      text("group-by", "Fields for the pivot's rows, comma-separated"),
      text("split-by", "Fields for the pivot's columns, comma-separated"),
      text("columns", "Fields shown as values, comma-separated"),
      text("height", "CSS height (default 24rem)"),
    ],
  },
  // The ml-* directives: scikit-learn on the shared in-browser Python. Fixed
  // code templates — the data never enters the code — results into a derived,
  // device-local collection, numeric parameters reactive as #keys.
  {
    directive: "ml-cluster",
    description: "K-means clustering (standardised features): writes the rows back with a cluster column. k from 2 to 20, also a #key.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to learn from"),
      text("features", "NUMERIC fields, comma-separated (decimal comma accepted)"),
      text("k", "How many groups, 2–20 — a number or a #key"),
      text("into", "The derived collection the rows land in"),
    ],
  },
  {
    directive: "ml-anomaly",
    description: "Anomaly detection (Isolation Forest): writes the rows back with anomalia (0–1, higher is stranger) and flag (1 = out of line). contamination is the expected share of anomalies (default 0.05), also a #key.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to learn from"),
      text("features", "NUMERIC fields, comma-separated"),
      text("contamination", "Expected share of anomalies, 0–0.5 — a number or a #key"),
      text("into", "The derived collection the rows land in"),
    ],
  },
  {
    directive: "ml-predict",
    description: "Regression: learns from the rows where target is numeric and writes previsione for every row with valid features (R² in the status).",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to learn from"),
      text("features", "NUMERIC fields, comma-separated"),
      text("target", "The numeric field to learn"),
      attribute("model", "The regressor", Choice, ["linear", "forest"]),
      text("into", "The derived collection the rows land in"),
    ],
  },
  {
    directive: "ml-correlate",
    description: "Pearson correlation matrix over the features: writes {a, b, r} pairs. Needs no package download.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to read"),
      text("features", "NUMERIC fields, comma-separated"),
      text("into", "The derived collection the pairs land in"),
    ],
  },
  {
    directive: "ml-forecast",
    description: "Time-series forecast: x is time (a number like a year, or an ISO date), y the value. model = linear (default), arima/sarima (SARIMAX) or holt/holt-winters/ets, with a declared linear fallback; season is the seasonal period (12 for monthly data). Writes the history with a previsione column plus horizon future rows at the series' median step (default 6). model, horizon and season also take #keys.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection holding the series"),
      text("x", "The time field: numeric, or an ISO date"),
      text("y", "The numeric value field"),
      text("horizon", "Future rows to write, 1–60 — a number or a #key"),
      text("model", "linear | arima | sarima | holt | holt-winters | ets — or a #key"),
      text("season", "The seasonal period, e.g. 12 for monthly — a number or a #key"),
      text("into", "The derived collection the rows land in"),
    ],
  },
  // Local SQL: DuckDB in the browser, over the app's own collections. The
  // body is a fenced SELECT; the answer is a derived, device-local collection.
  {
    directive: "sql",
    description: "A full SQL engine (DuckDB) in the browser: the collections in data= become tables of the same name (types inferred), the fenced body is one SELECT — JOINs, GROUP BY, window functions — and the result lands in the derived collection into= (max 1000 rows, local to this device). {#key} placeholders are reactive prepared parameters; remote https Parquet/CSV read directly. The very first run downloads the engine (~10 MB) behind a Run button.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("data", "Collections that become tables, comma-separated"),
      text("into", "The collection the result lands in"),
      number("limit", "At most this many rows (ceiling 1000)"),
    ],
  },
  // The ai-* directives: the assistant's own model, put to work inside the app
  // rather than beside it. They share one setting, one wire and one rule — the
  // model's answer is DATA, checked in core/AiDirective against the closed list
  // the document declared, and never anything that is executed.
  {
    directive: "ai-summary",
    description: "A short written summary of a collection, rewritten whenever the rows change. The body (or prompt=) says what to look at; only a sample of the rows travels, never the whole collection.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("data", "The collection to describe"),
      text("prompt", "What to say about it, when the body does not"),
      text("rag", "Fields to search first and cite, as collection.field, comma-separated"),
    ],
  },
  {
    directive: "ai-chat",
    description: "A chat over the collections in data=: the reader asks in their own words and the model answers from those rows only. The body is the persona. The conversation stays on this device.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("data", "The collections it may read, comma-separated"),
      text("persona", "Who the assistant is, when the body does not say"),
      text("rag", "Fields to search first and cite, as collection.field, comma-separated"),
      text("placeholder", "What the empty question box says"),
    ],
  },
  {
    directive: "ai-agent",
    description: "A chat WITH TOOLS over the collections in data=: query reads them, insert PROPOSES a row that is written only when the reader presses confirm. The body is the persona; every step leaves a line in the log.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("data", "The collections the tools may reach, comma-separated"),
      attribute("tools", "What it may do: query, insert — comma-separated", Text, []),
      text("placeholder", "What the empty question box says"),
    ],
  },
  {
    directive: "ai-pipeline",
    description: "Fills the fields of rows that do not have them yet — the new ones, recognised by the first declared field being empty — writing ONLY the fields in fields=. The body is the instruction; the first batch waits for its button.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      text("data", "The collection to work through"),
      text("fields", "The fields it may write, comma-separated, name:type"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-query",
    description: "A question about a collection in plain words. The model produces a QUERY PLAN — filters, a group-by, one aggregation, every field name from a closed list — which is then run on this device. A single answer shows in the widget; a breakdown lands in into=.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to question"),
      text("into", "The collection the breakdown lands in"),
      text("placeholder", "What the empty question box says"),
    ],
  },
  {
    directive: "ai-rule",
    description: "An automation written in words and compiled ONCE into a checked plan: from then on it runs with no model at all — reactive, deterministic, and idempotent because it only touches rows it would actually change.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection the rule watches"),
      text("when", "The condition, in plain words"),
      text("do", "What to write, in plain words: one field, one value"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-classify",
    description: "Sorts the rows of a collection into the values you list, writing the chosen one into field=. An answer outside the list is dropped rather than stored. By default only rows where the field is still empty.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      path,
      text("field", "The field the chosen value is written to"),
      text("values", "The closed list of values, comma-separated"),
      flag("overwrite", "Also reconsider rows that already have a value"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-extract",
    description: "Reads free text and fills the draft of a form with what it finds. Only the fields declared in fields= are written, in the type declared — a :number that is not a number is left alone.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("form", "The form whose draft is filled"),
      text("fields", "The fields it may fill, comma-separated, name:type"),
      text("source", "Where the text comes from: a #key, or omitted for a box of its own"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-field",
    description: "Suggests ONE field of a form from the others already filled, choosing from the closed list in values=.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("form", "The form the field belongs to"),
      text("field", "The field to suggest"),
      text("values", "The closed list of values, comma-separated"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-suggest",
    description: "Proposes the next plausible row from what the collection already holds, into the form's draft. The person reviews it and presses save — nothing is written by the model.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("form", "The form whose draft is filled"),
      path,
      text("fields", "The fields it may fill, comma-separated, name:type"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-assist",
    description: "Fills a form from one sentence — «Mario, giovedì alle 15» — by reading the fields the form actually has. The draft is filled; the person reviews it and presses the form's own save button.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("form", "The form whose draft is filled"),
      text("label", "What the button says"),
      text("placeholder", "What the empty box says"),
    ],
  },
  {
    directive: "ai-translate",
    description: "Translates the text of a reactive key or a form field into to=, in place.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("to", "The language to translate into"),
      text("form", "The form, when it is a field rather than a key"),
      text("field", "The field, when it is a field rather than a key"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-rewrite",
    description: "Rewrites the text of a reactive key or a form field in the style asked for, in place.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("style", "How to rewrite it, e.g. più formale"),
      text("form", "The form, when it is a field rather than a key"),
      text("field", "The field, when it is a field rather than a key"),
      text("label", "What the button says"),
    ],
  },
  {
    directive: "ai-search",
    description: "Semantic search over the fields in rag= (collection.field, comma-separated), including the text of ::file attachments: the index is built on this device with a small embedding model and never leaves it. Finds by meaning, not by the word you typed.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("rag", "The fields to index, as collection.field, comma-separated"),
      text("placeholder", "What the empty search box says"),
      text("into", "A collection the results land in, for a view to draw"),
    ],
  },
  {
    directive: "ai-vision",
    description: "Describes the image attached to a ::file field into another field of the same form. Needs a model that reads images.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("form", "The form both fields belong to"),
      text("field", "The ::file field holding the image"),
      text("target", "The field the description is written to"),
      text("prompt", "What to look for in the image"),
      text("label", "What the button says"),
    ],
  },
  // A file in a form field. Small files live inside the row and sync with it;
  // big ones stay on the device that chose them, name visible everywhere.
  {
    directive: "file",
    description: "A form field holding a file. In views the value shows as an image preview or a named download. Files up to 300 kB live inside the row and sync; larger ones (up to maxkb, default 10240) stay on this device — elsewhere the name shows without the content.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("field", "The field of the row the file is written to"),
      text("form", "The form this field belongs to, when written outside it"),
      text("legend", "The visible name of the field"),
      text("accept", "What the picker offers, e.g. image/*"),
      number("maxkb", "The size ceiling in kB (default 10240)"),
    ],
  },
  // Address to coordinates, on a click and never by itself: business data has
  // addresses, maps want GPS, and Nominatim's public instance allows one
  // request a second.
  {
    directive: "geocode",
    description: "A button that geocodes the rows that have an address (from=) and no coordinates yet (to=, default coords, written as ::geo writes them). Idempotent — a second click resumes what is left, at most 50 rows per click, one request a second. With [storekey] and value= it resolves a single address into a reactive key.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      path,
      text("from", "The field holding the address"),
      text("to", "The field the coordinates land in (default coords)"),
      text("value", "Single-address form: the address, or a #key holding one"),
      text("url", "A self-hosted Nominatim /search endpoint instead of the public one"),
      text("label", "What the button says"),
    ],
  },
  // Print: a button that prints ONE section of the app — the print dialog is
  // also where a PDF comes from.
  {
    directive: "print",
    description: "A button that prints only the container whose id it names (give a ::card an id); the print dialog also saves to PDF. With repeat= it prints one page per row of that collection: the reactive key is set to each row in turn and the target is photographed after the views have caught up.",
    tag: "button",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("target", "The id of the container to print"),
      text("label", "What the button says"),
      // One page per class and one page per teacher are the same request repeated,
      // and twenty classes is not something anybody writes by hand.
      text("repeat", "A collection: print the target once per row of it"),
      text("key", "The reactive key set to each row's value in turn"),
      text("field", "Which field of the row that key takes; the id if omitted"),
      // A weekly grid is six days wide and does not fit a portrait page. The flag
      // names a page box rather than setting a size directly: @page cannot be
      // switched by a class, but a named page can be given to the sheets.
      flag("landscape", "Print on landscape paper — for a wide grid or table"),
    ],
  },
  // The dashboard container: nested views over the same collection, cross-
  // filtered by clicking a nested chart's bar or slice. The selection is per
  // device and never synced.
  {
    directive: "dashboard",
    description: "Ties nested views together with the cross-filter of BI tools: clicking a bar or slice of a nested chart narrows the sibling views to matching rows; a second click clears it.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [path],
  },
  // The map view: Leaflet with OpenStreetMap tiles, a lazy chunk. A row is a
  // marker — or an area, with geojson — and the body is the popup template.
  {
    directive: "map",
    description: "A map of a geolocated collection: a row is a marker (or a GeoJSON area), the body is the popup template. Follows the store live.",
    tag: "div",
    package: "reactivenet",
    slots: [""],
    attributes: [
      path,
      text("coords", "The field holding both coordinates in one string (\"45.46, 9.18\") — the format ::geo writes"),
      text("lat", "The latitude field, when the coordinates are two columns (default lat)"),
      text("lon", "The longitude field (default lon)"),
      text("geojson", "The field holding a GeoJSON geometry: each row becomes an area instead of a marker"),
      text("fill", "With geojson, the numeric field that colours areas as a choropleth (blue quantiles)"),
      text("center", "Initial centre as \"lat, lon\"; omitted, the map frames the markers until the reader moves it"),
      number("zoom", "Initial zoom, 0 (world) to 19 (street)"),
      text("height", "CSS height (default 24rem)"),
      text("tiles", "A different basemap: https URL with {z}/{x}/{y} placeholders"),
      text("attribution", "The credit line the tile provider requires"),
    ],
  },
  {
    directive: "geo",
    description: "A form field filled with the device's position at a click, as \"lat, lon\" — exactly what ::map{coords} reads.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("field", "The field of the row the position is written to"),
      text("form", "The form this field belongs to, when written outside it"),
      text("legend", "The visible name of the field"),
    ],
  },
  // The chart directives: drawn straight from a collection by Chart.js, a lazy
  // chunk loaded only when a document has one. Reactive — the collection
  // changes, the chart redraws.
  {
    directive: "chart-bar",
    description: "A bar chart of a collection: x is the label field, y one or MORE numeric fields separated by commas — one series per field.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("x", "The label field"),
      text("y", "Numeric field(s), comma-separated: one series each"),
      flag("horizontal", "Bars left to right — for long labels"),
      flag("stacked", "Stack the series instead of grouping them"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  {
    directive: "chart-area",
    description: "A filled line chart — lines with the area under them coloured; stacked, the series pile up to their total.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("x", "The label field"),
      text("y", "Numeric field(s), comma-separated: one series each"),
      flag("stacked", "Stack the series to show a total and its parts"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  {
    directive: "chart-doughnut",
    description: "A doughnut chart: a pie with a hole — label is the category field, value the numeric one.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("label", "The category field"),
      text("value", "The numeric field"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  {
    directive: "chart-radar",
    description: "A radar chart: each x value is a spoke, each y field a shape — profiles compared at a glance.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("x", "The label field, one spoke per value"),
      text("y", "Numeric field(s), comma-separated: one shape each"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  {
    directive: "chart-line",
    description: "A line chart: x is the label field, y one or more numeric fields. Made for the time series IoT collections produce.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("x", "The label field"),
      text("y", "Numeric field(s), comma-separated: one series each"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  {
    directive: "chart-pie",
    description: "A pie chart: label is the category field, value the numeric one.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("label", "The category field"),
      text("value", "The numeric field"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  {
    directive: "chart-scatter",
    description: "A scatter plot: x and y are numeric fields — e.g. prediction against truth after ::ml-predict.",
    tag: "div",
    package: "reactivenet",
    slots: [],
    attributes: [
      text("data", "The collection to draw"),
      text("x", "The numeric x field"),
      text("y", "The numeric y field"),
      text("height", "CSS height (default 18rem)"),
    ],
  },
  summary("count", "How many rows the collection has."),
  summary("sum", "The total of a numeric field."),
  summary("avg", "The average of a numeric field."),
  summary("min", "The lowest value of a numeric field."),
  summary("max", "The highest value of a numeric field."),
  summary("median", "The median of a numeric field — the typical value."),
  summary("stddev", "The sample standard deviation of a numeric field."),
  summary("mode", "The most frequent value of a field; works on text too."),
]

// Ours first: if a name ever collided with a Spectrum component, the directive the
// renderer actually handles is the one that must be described.
let all = {
  let ours = reactive->Array.map(component => component.SpectrumRegistry.directive)
  reactive
  ->Array.concat(SpectrumRegistry.all->Array.filter(component => !(ours->Array.includes(component.directive))))
  ->Array.map(withGlobals)
}

let find = directive => all->Array.find(component => component.directive == directive)
