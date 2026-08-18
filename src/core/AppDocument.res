// Pure. A stored document seen as an app: what the gallery shows, and what a new
// app starts as.
//
// Both directions go through `Frontmatter`, so the gallery card and the info panel
// read the same fields from the same parser — a document whose title changes in the
// editor changes on the card because there is only one place it is written down.

type summary = {
  id: string,
  title: string,
  description: string,
  author: string,
  date: string,
  version: string,
  /** A Spectrum workflow icon name, or the empty string. Validated here rather than
      where it is drawn: a name from a document arrives from outside, and one that is
      not an icon would draw nothing and leave a gap nobody can explain. */
  icon: string,
  /** Whether the document asks for the chat panel (`chat: true`). */
  chat: bool,
}

// What counts as "yes" in the frontmatter's YAML subset. Anything else — including
// an absent field — is "no": a value from a document arrives from outside, and an
// unrecognised one must not quietly enable a panel.
let truthy = value =>
  switch value->String.trim->String.toLowerCase {
  | "true" | "yes" | "on" | "1" => true
  | _ => false
  }

/** What an app with no icon of its own is drawn with. A card missing the thing every
    other card has reads as broken; a default reads as plain. */
let defaultIcon = "app"

let field = (meta, key) =>
  meta->Option.flatMap(fields => Frontmatter.get(fields, key))->Option.getOr("")

// The title falls back to the id rather than to a placeholder: an untitled app is
// still addressable, and its id is the one thing it certainly has.
let summary = (~id, ~source) => {
  let meta = Frontmatter.parse(source).meta
  let title = field(meta, "title")
  {
    id,
    title: title == "" ? id : title,
    description: field(meta, "description"),
    author: field(meta, "author"),
    date: field(meta, "date"),
    version: field(meta, "version"),
    icon: {
      let named = field(meta, "icon")
      SpectrumIcons.all->Array.includes(named) ? named : ""
    },
    chat: truthy(field(meta, "chat")),
  }
}

/** The id the document declares, which may differ from the key it was stored under
    once someone edits the frontmatter. */
let declaredId = source =>
  switch Frontmatter.parse(source).meta {
  | None => None
  | Some(meta) =>
    switch Frontmatter.get(meta, "appId") {
    | Some(declared) if AppId.isValid(declared) => Some(declared)
    | _ => None
    }
  }

/** Writes an id into the document, so a renamed app carries its own identity. */
let withId = (source, id) => {
  let parsed = Frontmatter.parse(source)
  let meta = parsed.meta->Option.getOr(Frontmatter.empty)
  Frontmatter.serialize(Frontmatter.setField(meta, ~key="appId", ~value=id), parsed.body)
}

// A working app, not an empty page. A blank document gives no clue what a directive
// looks like, and the first thing someone does with a new app is copy the shape of
// something that already runs — so the starter *is* that something: a form that
// writes a row, a list that reads it back, and the empty state in between. Nothing
// in here repeats itself: a field is inside its form, so it does not name it.
let blank = (~id, ~title, ~date, ~locale: Locale.t) => {
  let text = Starter.of_(locale)
  Frontmatter.serialize(
    Frontmatter.empty
    ->Frontmatter.setField(~key="appId", ~value=id)
    ->Frontmatter.setField(~key="title", ~value=title)
    ->Frontmatter.setField(~key="description", ~value="")
    ->Frontmatter.setField(~key="icon", ~value=defaultIcon)
    ->Frontmatter.setField(~key="lang", ~value=Locale.toTag(locale))
    ->Frontmatter.setField(~key="version", ~value="1.0")
    ->Frontmatter.setField(~key="date", ~value=date),
    "# " ++
    title ++
    "\n\n" ++
    text.starterIntro ++
    "\n\n## " ++
    text.addHeading ++
    `

::form{path="items"}
::input{field="name" legend="` ++
    text.nameField ++
    `"}
::input{field="note" legend="` ++
    text.noteField ++
    `"}
::save{label="` ++
    text.addButton ++
    `"}
::/form

::if-empty{path="items"}
` ++
    text.emptyItems ++
    `
::/if-empty

::if-any{path="items"}
:count{path="items"} ` ++
    text.savedItems ++
    `

::list{path="items" deletable editform}
**{name}** — {note}
::/list
::/if-any
`,
  )
}

// The app that is always there. It is a real stored app like any other — it has a
// URL, it can be read, edited and backed up — but `welcomeId` is re-seeded whenever
// it is missing, so the gallery is never empty and there is always a working example
// of every kind of directive to read.
let welcomeId = "welcome"

let welcome = (~locale: Locale.t, ~date) => {
  let text = Starter.of_(locale)
  Frontmatter.serialize(
    Frontmatter.empty
    ->Frontmatter.setField(~key="appId", ~value=welcomeId)
    ->Frontmatter.setField(~key="title", ~value=text.welcomeTitle)
    ->Frontmatter.setField(~key="description", ~value=text.welcomeDescription)
    ->Frontmatter.setField(~key="icon", ~value="hand")
    ->Frontmatter.setField(~key="lang", ~value=Locale.toTag(locale))
    ->Frontmatter.setField(~key="version", ~value="1.0")
    ->Frontmatter.setField(~key="date", ~value=date),
    // Two pages, so the welcome app also demonstrates the menu it describes. A page
    // holds an accordion which holds its items, and all three are written the same
    // way — each close says what it ends.
    `::page{title="` ++
    text.reactiveHeading ++
    `" icon="gauge3"}
# ` ++
    text.welcomeTitle ++
    `

` ++
    text.intro ++
    `

` ++
    text.openHint ++
    `

## ` ++
    text.reactiveHeading ++
    `

` ++
    text.reactiveIntro ++
    `

::slider[volume]{min="0" max="100" value="50" label-visibility="text"}

` ++
    text.volumeNow ++
    ` :value[v]{ref="#volume"}

::progress-bar{label="Volume" progress="#volume"}

` ++
    text.refRule ++
    `

## ` ++
    text.componentsHeading ++
    `

` ++
    text.componentsIntro ++
    `

::badge[Spectrum]{variant="accent"}

::accordion{density="compact"}
::accordion-item{label="` ++
    text.nestingQuestion ++
    `" open}
` ++
    text.nestingAnswer ++
    `
::/accordion-item
::/accordion
::/page

::page{title="` ++
    text.dataHeading ++
    `" icon="data"}
## ` ++
    text.dataHeading ++
    `

` ++
    text.dataIntro ++
    `

::form{path="notes"}
::input{field="title" legend="` ++
    text.noteField ++
    `" required}
::input{field="who" legend="` ++
    text.whoField ++
    `" help="` ++
    text.whoHelp ++
    `"}
::save{label="` ++
    text.saveButton ++
    `"}
::/form

::if-empty{path="notes"}
` ++
    text.emptyNotes ++
    `
::/if-empty

::if-any{path="notes"}
:count{path="notes"} ` ++
    text.savedNotes ++
    `

::list{path="notes" deletable editform}
**{title}** — {who} · {createdAt}
::/list

### ` ++
    text.viewsHeading ++
    `

` ++
    text.boardIntro ++
    `

::board{path="notes" group-by="who" min="11rem" editform}
**{title}**
::/board

### ` ++
    text.chooseHeading ++
    `

` ++
    text.chooseIntro ++
    `

::choose[chi]{path="notes" field="who" label="who" legend="` ++
    text.chooseLegend ++
    `"}

` ++
    text.chooseAnswer ++
    ` :value[chosen]{ref="#chi"}

::list{path="notes" filter="who=#chi"}
**{title}** · {createdAt}
::/list
::/if-any

## ` ++
    text.markdownHeading ++
    `

` ++
    text.markdownIntro ++
    `

| Feature | Status |
| --- | --- |
| KaTeX | yes |
| Mermaid | yes |

$$
\\int_{0}^{\\infty} e^{-x^2}\\,dx = \\frac{\\sqrt{\\pi}}{2}
$$
::/page
`,
  )
}

/** Newest first, then by title, so the list is stable when dates are missing. */
let order = summaries =>
  summaries->Array.toSorted((a, b) =>
    a.date == b.date
      ? String.compare(a.title->String.toLowerCase, b.title->String.toLowerCase)
      : String.compare(b.date, a.date)
  )
