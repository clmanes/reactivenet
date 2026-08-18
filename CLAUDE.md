# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Package manager is **bun** (`bun.lock`), though the scripts are plain npm scripts.

Development requires **two processes running in parallel**:

```sh
bun run res:dev   # rescript watch — compiles .res -> .res.mjs
bun run dev       # vite dev server (consumes the .res.mjs output)
```

Other commands:

```sh
bun run test        # rescript, then bun test over the compiled test modules
bun run test:watch  # same, without recompiling first
bun run res:build   # one-shot ReScript compile
bun run res:clean   # remove compiler artifacts
bun run build       # vite build — does NOT compile ReScript; run res:build first
bun run preview     # serve the production build, with the real CSP headers
bun run icons       # re-rasterise the PWA icons after editing logo.svg
```

There is no linter or formatter configured. Type errors come from the ReScript compiler.

### Running one test

`bun test` cannot discover these files on its own: it only picks up `.test.`/`.spec.` names with a `.js`/`.ts` extension, and the compiler emits `Foo_test.res.mjs`. Explicit paths bypass discovery entirely, which is why the `test` script shells out to `find`. The paths must start with `./` — bare relative paths are treated as name filters and match nothing.

```sh
bun test ./src/core/SafeUrl_test.res.mjs       # one file
bun run test -t "rejects"                      # by test name, across all files
```

### Testing the directives

Deliberately **by hand**, and `doc/test-directives.md` is the script for it. What a directive does is what it looks like on the page, and a test runner sees none of that — so what is written down instead is one app to paste and a table of what should come back from each of its pages.

The app is one document of **eight pages, one per class of directive and each a real arrangement** — shared expenses, a bill to split, a dashboard, the chrome of a bigger app — because a component fails in an app the way it never fails on its own. Every one of the 110 directives appears in it, and again on its own in the page's appendix. Running it found the `Numeric` prefix bug, the empty-draft guard defeated by a checkbox, `sp-grid` not shipping, and the overlays freezing the page.

ReScript 12 → React 19 → Vite 7. Two things drive most of the structure.

**Vite never sees ReScript source**, only the compiled output:

- `rescript.json` sets `in-source: true` with `suffix: ".res.mjs"`, so the compiler emits `Foo.res.mjs` next to `Foo.res`.
- `vite.config.js` restricts the React plugin to `include: ["**/*.res.mjs"]` and tells the watcher to ignore `lib/bs`, `lib/ocaml`, `lib/rescript.lock`.
- `index.html` loads `/src/Main.res.mjs` directly — nothing works until ReScript has compiled once.

**Pure core, effectful shell.** The split is the point, not decoration:

| Layer | Location | Rule |
| --- | --- | --- |
| Core | `src/core/` | No DOM, no IO, no React. Total, deterministic functions. Every module has a `.resi` and a `_test.res`. |
| Shell | `src/shell/` | All browser contact: storage, media queries, Trusted Types, service worker. |
| UI | `src/` | Components. They hold state but delegate every decision to `core/`. |
| Bindings | `src/spectrum/` | Typed wrappers over the Spectrum custom elements. |

`SafeUrl.parse` deliberately avoids the `URL` global so its result depends only on its input. `Theme` decides what a theme *is*; `ThemeStorage` does the talking to the browser. `EditorMode` owns the workspace state machine, and `MarkdownSnippets` decides what autocomplete offers — CodeMirror calls into it rather than holding its own list. That boundary is why the tests need no DOM, no jsdom and no stubs.

## The editor

Split pane: an editor on the left, a `marked` preview on the right, both driven by one markdown string in `App.res`.

**Two editors, never both mounted.** `EditorMode` enforces it, and the invariant is tested. CodeMirror edits the markdown source; BlockNote is a Notion-style block editor whose markdown conversion is **lossy in both directions** (its own API is named `blocksToMarkdownLossy`). Round-tripping through Blocks turns `$$` math and anything else without a block equivalent into plain paragraphs — visible immediately in the preview. That is inherent to BlockNote, not a bug to fix.

Three non-obvious things about the wiring:

- **CodeMirror is constructed with an explicit `root: document`.** Without it, CodeMirror resolves its root by walking up through the slot into `<sp-theme>`'s shadow root and mounts its stylesheet there via `adoptedStyleSheets`, where it styles nothing — the editor lives in the light DOM. The symptom is an editor with no layout at all, and no error anywhere.
- **CodeMirror ships its own light-only highlight style.** `defaultHighlightStyle` renders markdown links at `#221199`, which against the dark editor background measures 1.32:1 — invisible rather than merely hard to read. `CodeMirror.res` defines its own `HighlightStyle` whose colours are Spectrum tokens, so they invert with the theme instead of needing a second style and a `Compartment` to swap between them.
- **The editor is uncontrolled**; CodeMirror owns the document. `initialValue` is read once, at mount. Feeding React state back on every keystroke would fight its own undo history and move the caret.
- **The preview is debounced by 250 ms**, because Mermaid lays out a whole diagram on each run. The editor never waits on it.
- **Effect dependencies must be flat.** `Preview` uses `useEffect3(..., (source, theme, locale))`. Nesting them as `useEffect2(..., (source, (theme, locale)))` allocates a new tuple every render, so React never sees the dependencies as unchanged and the whole pipeline — marked, DOMPurify, Mermaid layout — reruns on every render until the main thread stops responding.
- **BlockNote's `onChange` fires while the editor is being seeded.** `replaceBlocks` counts as a change, so merely *opening* the block editor used to write a lossy round-trip back over the document — escaping the display-math fences and silently breaking every KaTeX block. `BlockNoteImpl.res` guards with a ref that is cleared a macrotask after seeding, so the document only changes once the user actually edits.
- **`BlockNoteView` forwards `className` to more than one element** — the editor container and a second `.bn-root` used for portals. Layout classes passed there are applied twice, and the portal root ends up claiming half the pane's height. It gets a marker class only; sizing lives in `index.css`, scoped to `.bn-container`.

**React must stay at ≥ 19.2.** `@blocknote/mantine` pulls Mantine 9, which calls `useEffectEvent` — a React 19.2 API. On 19.1 the block editor mounts fine and then crashes the whole app the moment a Mantine `Popover` appears, i.e. as soon as you type and the formatting toolbar opens. The error surfaces as `useEffectEvent is not a function` inside `useClickOutside`.

`BlockNoteImpl.res` holds the static BlockNote imports and is reached only through the dynamic `import()` in `BlockEditor.res`, which is what keeps that megabyte out of the initial load — and the main chunk under Workbox's 2 MB precache ceiling, which is a hard build failure, not a warning. `vite.config.js` also splits vendors by hand; the CodeMirror rule deliberately names only core packages, because naming `@codemirror` wholesale drags every on-demand language grammar into the initial chunk (1.6 MB instead of 550 kB).

## Apps, and the URL

The home page is a gallery of the apps this browser has stored; each one has its own URL and opens either as its readers see it or in the editor.

**Routes live in the path, not the hash.** A hash costs nothing to serve, which is why it was here first, but it is in every link anyone copies and a link is how an app is shared. The price is one rewrite rule wherever this is hosted — every unknown URL answers with `index.html` — and it is paid three times over: `vite dev` and `vite preview` do it out of the box, `public/_redirects` says it for the static hosts that read that file, and the service worker's `navigateFallback` says it again for a reader who is offline. `core/Route` still accepts a leading `#` on the way *in*, so a link saved under the old scheme still opens its app.

**Navigation is `pushState`, which fires nothing.** Assigning a hash used to notify the app by itself; `pushState` does not, so `Router` dispatches its own event and `subscribe` listens for that and for `popstate`, which is what Back and Forward produce. The gallery's cards are real `<a href>` elements — copyable, openable in a new tab — and `Router.follow` intercepts only a plain left click, leaving every modified one to the browser.

**An app's identity is the `appId` in its frontmatter**, and the same string is three things: the storage key (`DocumentKey`), the namespace of its collections (`CollectionKey`), and the addressable part of the URL. Because the last of those means it arrives from outside, `AppId.isValid` is what everything goes through — `Route.parse` refuses a hash that is not a valid id, so no other module has to wonder whether the one it holds came from a link. Editing `appId` in the editor therefore *moves* the app: `DocumentStore.rename` carries the collections across and the URL follows. `App.res` sets `openedId` before navigating, so the hash change that causes is not read back as "open a different document" — otherwise the uncontrolled editor would be reseeded from storage under the author's cursor.

Deleting an app deletes its collections with it. Leaving them would orphan data under a namespace nothing can reach, and hand it to the next app that happens to take that id. That is why it is confirmed in a **modal** rather than by a second click on the same button: a two-step button can only repeat its own label, and this one needs a sentence saying the data goes too and that it cannot be undone.

**A row is deleted through the same modal.** `CollectionBinder` does not build chrome inside the preview — that DOM is sanitiser output — so it *asks*: `bind` takes a `~confirm: string => promise<bool>`, hands it the row's own text, and removes the row only if the promise resolves true. `Render.res` owns the dialog, keeps the resolver in state, and mounts it as a **sibling** of the preview container, never a child: the container's `innerHTML` is replaced on every render and would take an open dialog with it.

`ConfirmDialog` is the native `<dialog>` with `showModal()`, which supplies the focus trap, Esc, the inert background and — the part hand-written modals always miss — returning focus to whatever opened it. Two things it needs that are easy to get wrong:

- **It is always mounted and driven by `open_`.** Mounting the dialog and calling `showModal()` in the same commit races the node's arrival in the document.
- **`margin: auto` has to be restored.** A modal `<dialog>` centres itself through auto margins, which the CSS reset zeroes along with every other margin; without it the dialog lands in the top-left corner.

A wrapper for a Spectrum element does nothing until the element is registered: `sp-button` needed its own side-effect import in `Spectrum.res`, and until it had one the dialog's buttons rendered as unstyled text.

**Seeding has to finish before a route can be resolved.** "This browser does not have that app" is not an answer until the welcome app has been written — a link straight to it on a fresh browser bounced to the gallery a moment before it existed. The route effect waits on a `seeded` flag.

**A new app starts as a working app**, not an empty page: `AppDocument.blank` is a form writing to a collection, the list reading it back, and the empty state in between. The first thing anyone does with a new app is copy the shape of something that already runs, so the starter is that something — and nothing in it repeats itself, because it is the example that will be copied.

**Creating an app is the first tile of the grid**, not a button in the header: it sits in the thing it adds to, it is the size of what it produces, and on a narrow screen it stays a full-width target instead of competing with the search box. A search narrows what exists; it never removes the way to make more, so the tile is not filtered away. Past six cards a floating button appears as well — by then the tile has scrolled off — and `.rn-gallery-floating` reserves room underneath it so no card comes to rest below it, which is the §2.4.11 failure a FAB invites.

**The gallery search is a pure filter.** `AppSearch` matches every space-separated word against the fields the card already shows — title, id, description, author. Matching something the card does not mention reads as a bug, and matching from the middle is what makes `voti` find `registro-voti`.

**A handset cannot edit at all.** Below the same breakpoint the stylesheet stops showing two panes, `Viewport.canEdit` is false: the editing control disappears *and* `#/a/<id>/edit` is rewritten to `#/a/<id>`. Hiding the control while leaving the URL saying `/edit` would defeat the whole point of routing by URL. CodeMirror and BlockNote are desktop editing surfaces; offering them on half a handset screen is worse than not offering them. Phone-width preview goes the same way — it is the author's layout check, so `EditorMode.showEditor` drops it when the editor does.

**The welcome app is always available.** It is a real stored app — its own URL, editable, backed up with the rest — but it is written back whenever it is missing, so the gallery is never empty and there is always a working example of every kind of directive. It is also the regression test nobody has to run: it exercises a slider, a reactive view, an attribute binding, a form with `required` and `help`, a list with row editing, a board whose drag writes the grouped field, `if-empty`/`if-any`, a nested accordion, KaTeX and Mermaid. Deliberately **no `::python`**: the first block on a page fetches a 13 MB runtime, and the one app every browser opens must not cost that.

**Whether an editor is on screen is the route's business, not a component's.** There was briefly both — a local `toggleEditor` and the URL — and two answers to one question disagree the moment someone copies the address bar. `EditorMode.showEditor` is now set *from* the route, and the navbar control navigates. For the same reason the right-hand pane is only called "Preview" while something is being previewed: at `#/a/<id>` it is the running app, and it is named after the app.

## Documents

A document may open with a `---` delimited frontmatter block (`appId`, `title`, `description`, `icon`, `lang`, `version`, `author`, `date`). `Frontmatter.parse` is a deliberately small YAML subset: ordered `key: value` lines, matched surrounding quotes removed, everything after the *first* colon kept so URLs and timestamps survive. Fields are an ordered list rather than a fixed record, so a document carrying keys this app has never heard of still shows them in the info panel, exactly as authored.

Anything that is not a well-formed, *terminated* block is left alone as body — swallowing the rest of a document because someone typed `---` would be far worse than ignoring it.

The parsed body, not the raw source, is what the preview renders. The ⓘ button in the preview toolbar shows the metadata read-only.

**An app's icon is a frontmatter field.** `icon: calendar` names one of Spectrum's workflow icons — the same set `::page{icon}` draws from — and it marks the app on its gallery card and in the toolbar above it. The name is validated in `AppDocument.summary`, where it arrives from outside, so a name that is not an icon becomes the default rather than a gap nobody can explain. The drawings come from `shell/IconDrawings`, one lazily loaded chunk shared with the page menu.

**A message is markdown, and deliberately not a document.** Both places a message is
shown — the assistant's answers and the app's own chat — render through
`shell/MessageMarkdown` and `MessageText.res`, and the two differences from the
preview's renderer are the whole design. **No directives**: `MarkdownRenderer` turns
`::form` into a form and `::python` into a running interpreter, which is right for a
document its author wrote and wrong for a line somebody else sent — so a second
`marked` instance parses none of them, and nothing binds the result either, so even a
directive that survived would be inert markup. And **`breaks: true`**: in CommonMark a
single newline is a space, which is right for a document and wrong for a chat, where
people press Enter expecting the line to break. Left out on purpose: **KaTeX**, because
`$5 a pranzo, $10 a cena` is what people actually type and the extension reads the span
between the dollars as an equation.

The two things that have to happen to any rendered markdown before a person can use it
live in `shell/SafeMarkup` and are shared with `Render.res` rather than copied: every
link re-checked against `SafeUrl` and given `noopener noreferrer` — a link that does not
pass keeps its text and loses its href — and every table wrapped in a scrollable named
region, which in a panel this narrow is what stops a comparison table from pushing the
page sideways. A security routine with two copies is one that will be forgotten; the
same is true of an accessibility one.

`.rn-chat-text` lost its `white-space: pre-wrap` in the move and `.rn-md` sets
`white-space: normal`: the markdown is what makes the paragraphs now, and pre-wrap left
in place doubles every blank line. It is the kind of leftover that looks like a styling
opinion and is actually a bug.

**`chat: true` in the frontmatter gives the app a chat panel** (`ChatPanel.res`, toggled by a toolbar button that only exists when the document asks). There is deliberately no chat machinery: messages are rows of an ordinary collection named `chat` — `author`, `text`, the reserved stamps — written through `CollectionStore` like every other row. That single decision is the feature: they back up with the data, they sync end-to-end encrypted through the existing engine when the app is linked to a space (the panel refreshes on the same `rn:data` event the binder listens for, so remote messages land live), a reader's messages stay local because their pushes are refused, and a document can render the thread itself with `::list{path="chat"}`. Which values of the field count as yes is decided in `AppDocument.summary` (`true`/`yes`/`on`/`1`), where the value arrives from outside. A message can carry a file: the whole content rides in the row as a `data:` URL (`file` + `filename` fields), capped at 700 kB because the sealed sync change it travels in must stay under the server's 2,000,000-character payload limit. Rendering only ever accepts `data:` URLs from the row — a stored `javascript:` never becomes a link — and an `image/*` data URL is shown inline, anything else as a download link.

**In Blocks mode the frontmatter is edited as a form**, toggled by the ⓘ button in the editor toolbar, and BlockNote receives the body alone. This is not a convenience: BlockNote has no way to represent a frontmatter block, so round-tripping one through its markdown converter turns it into a paragraph or a horizontal rule. The toggle lives in `EditorMode` rather than as component state, so `showsFrontmatterForm` can express that the form belongs to Blocks mode alone — in markdown mode the block is right there in the text, and a second way to edit it would be two sources of truth. `FrontmatterFields.res` owns those inputs and writes back through `Frontmatter.setField` / `serialize`, which preserve the order the author wrote and re-quote values YAML would otherwise read as a number, date or boolean — `version: "1.0"` stays a string. The round-trip is covered by a test asserting the sample document serialises back byte-identical.

**A document's `lang` outranks the stored language preference.** It is applied when the document declares one and is deliberately *not* persisted: the language belongs to the document, not the user, so opening an untagged document leaves the last language in place. The ordering matters — the IndexedDB read resolves after the document has been parsed, so `App.res` holds the document's locale in a ref and the storage callback checks it before applying anything.

**A date is stored ISO and shown local.** What is written down never changes — `2026-08-10T13:10:34.324Z` sorts as text and means the same moment in every time zone, which is what makes a backup portable. `core/DateValue` decides, strictly, which stored strings are dates at all, and `shell/Clock.localize` formats one; anything that is not a date is returned untouched, so it is safe to run over every field of a row. The recogniser is strict on purpose: something looser would start reformatting text an author typed deliberately. A whole day is formatted from its written fields rather than from a parsed instant, because `new Date("2026-08-10")` is midnight UTC and would show as the ninth in a western time zone.

## Directives

Reactive Markdown directives, in the three standard forms: inline `:name[label]{attrs}`, leaf `::name[label]{attrs}` on its own line, container `:::name{attrs}` … `:::`. Registered on the shared marked instance in `MarkdownRenderer.res`; the grammar itself lives in `core/` (`DirectiveAttributes`, `ReactiveRef`, `DirectiveScan`) so it is tested without a DOM.

**There is one block form, and the close names what it ends.** `::name{…}` on its own line opens a block; a `::/name` below it makes that block a container and everything between them its body; a block nobody closes is a leaf. The two are written identically on purpose — nothing is counted, and two containers written alike still nest, because each close says which one it is. Depth is counted per name, so a form inside a form still ends at its own `::/form`.

```
::accordion{density="compact"}
::accordion-item{label="First" open}
Content.
::/accordion-item
::/accordion
```

This replaced a colon-fence rule: three or more colons opened a container, the close was the first line of *exactly* that length, and an outer container therefore had to carry MORE colons than the ones it held. It worked, but it made the one thing every author does — nesting — the one thing they had to count, and writing both fences at three was silently wrong. **That form is no longer read.** It was kept for one revision and then removed rather than carried: a grammar with two ways to write a container has to keep both working in the scanner, the marked tokenizer, the completions and the block round-trip, and the second way was the one nobody should learn. Three colons on a line are now text. `DirectiveScan.render` and `closing` are the only writers, and a container and a leaf open with the same text — the two `render` arms being identical *is* the grammar, not a duplication to fold away.

The grammar is implemented once, in `DirectiveScan`, and `MarkdownRenderer` matches it line for line — as **one** block tokenizer, not two: a leaf tokenizer registered separately would consume the opening line before the container one ever saw it, since the two openings are the same text.

**A fenced code block is code, and `DirectiveScan` does not scan inside one.** The renderer never did: marked's fence tokenizer takes the whole block — our block extension declines every line not opening with `::`, and a `code` token's text is never run through inline tokenizers — so a directive written inside a fence has always rendered as the characters it is. The scanner disagreed, and it disagreed precisely where every document carries code: inside `::python`, `::sql` and `::explore`. What it cost was a Python slice written `disponibili[:tetto]`, which reads as the inline directive `:tetto` — so `reactive_validate` reported an unknown directive in code that renders perfectly, and the block editor's splitter, which cuts the source at what `scan` finds, would have cut that line in half. A false report about correct code is the worst kind, because it sends somebody to change the one thing that was right. The rule is CommonMark's cut to what marked accepts — three or more backticks or tildes, at most three spaces of indent, closed by at least as many of the *same* character alone on a line — and an unclosed fence runs to the end of the document, which is again what marked does: the two have to agree even about where the damage stops. The close of a container obeys it too, or a `::/form` inside a program would end the block halfway through it.

**Containment now carries what an attribute used to repeat.** A field inside a form does not name the form, and a save button inside one names neither the form nor its path; `::list{… editform}` written bare edits into the form on its own path. The renderer emits `data-rn-form` on the form's `<div>` only, and `CollectionBinder` resolves a control's form with `closest()`. An explicit `form="id"` still works and rides on `data-rn-in-form`, which is deliberately a *different* attribute: putting it back on the input would make `closest("[data-rn-form]")` return the input itself and break every containment lookup.

**`#ref` versus a bare id is the central rule.** A leading `#` marks a *reactive reference* — a view subscribing to a path. A bare id is the *store key* a source control writes to. `::range[volume]` writes to `volume`; `:value[v]{ref="#volume"}` reads `#volume`. `ReactiveRef` keeps them as separate constructors because confusing them fails silently: a view bound to a store key simply never updates, and nothing reports an error. `:value` with a non-reactive ref renders as an error rather than as an inert span.

`:value` is the app's own inline directive; every other directive is a Spectrum component (see below), usable as a leaf or, where it has content, as a container. A directive the registry does not know is rendered **as written** — an unimplemented directive must never make a document lose text.

`ReactiveStore` keeps two values per key: the one the document *declares* and the one a user produced by interacting with the control. Conflating them breaks one case or the other — overwriting from the store meant editing a `value` attribute in the block editor did nothing, and taking the authored value unconditionally meant a dragged slider snapped back on every unrelated keystroke. The store adopts the authored value only when it has actually changed since the last bind.

`ReactiveStore` binds both sides after each preview render: `[data-reactive-source]` controls seed the store from their authored `value` and write on input; `[data-reactive-key]` views take the current value or their placeholder. Until more source directives exist, `globalThis.reactiveNet.set(key, value)` is the other way in.

**A source is a component whose manifest carries `value` or `checked`**, and for one of those the brackets are the *store key*, not a caption — so its visible text has to go in the body: `::checkbox[done]{}` / `Done` / `::/checkbox`. Two consequences worth knowing before wondering why nothing happens: `sp-switch` and `sp-search` declare neither, so `::switch` and `::search` render a control that stores nothing at all (`::input{type="checkbox"}` and `::table{search}` are what actually do those jobs), and a tick box has to be read through `checked` — its `value` is the form value it would submit, which for `::checkbox[done]` is the empty string, so the store held `""` forever. It now reads `true`/`false`, which is what the same tick is stored as in a collection.

**`#` belongs to the reactive keys, so a hex colour cannot be an attribute value.** `color="#65c3c8"` is read as a binding to a key named `65c3c8` and the colour never reaches the element. Name the colour, or write it `rgb(101 195 200)`. The rule is worth the cost — it is the same `#` everywhere — but it is invisible when it bites.

### ReactiveNET's data directives

The directives that give an app its data: `::form{path}` groups fields, `::input{field}` is one of them, `::save{label}` saves the draft as a row, `::list{path}` renders the rows from a body full of `{field}` tokens, `::if-any` / `::if-empty` show a body according to what is stored, and `:count{path}` is the size inline. `::save` was called `::add-form` when a form was something an input pointed *at* rather than something it sits *inside*; the old name still renders. They are not Spectrum components and never will be: there is no element that means "the rows of this collection".

The split is the same one everything else here follows. `MarkdownRenderer` emits **structure and `data-rn-*` attributes only** — it does not read storage. `shell/CollectionBinder.res` binds after each preview render, exactly as `ReactiveStore` does, and does every read and write. `core/RowTemplate.res` decides what a `{field}` token means; `core/RecordId.res` decides a new row's id given the clock's reading, so only the timestamp is effectful.

Two rules carry the security story, and neither is decoration:

- **A row reaches the document through `textContent`, never `innerHTML`.** The values are whatever someone typed into a form, so a template that built markup would make every stored value a scripting vector. The binder clones the hidden `.rn-list-template` and substitutes into *text nodes*, so a row containing `<script>` is a row that displays those characters. There is a test for exactly that.
- **`::form` renders a `<div>`, not a `<form>`.** Nothing here submits anywhere, and `Sanitizer` forbids form elements on purpose; emitting one would mean relaxing that for no gain.

**Rows can be deleted and edited.** `deletable` gives each row a button; `editform="id"` gives it one that fills that form with the row and switches the save button from inserting to updating. Which row a form is editing lives in a `WeakMap` per container, and the handlers are delegated to the list rather than attached per row — the rows are rebuilt on every refresh, so per-row handlers would have to be reattached each time and the old ones would pile up.

**Saving checks the draft, in `core/Draft`.** `required`, the `type`, `min`/`max`, and the author's own `pattern` with the `message` they wrote for it. The check is pure and the messages are not: a complaint is words, so the binder builds them per render from `Translations`. Two rules that only look obvious afterwards — an unticked box is *empty* for the purpose of "is this a mis-click", because it answers `"false"` and reading that as a value let a form with a checkbox save blank rows forever; and the type is complained about before the pattern, since "this is not a number" beats a message about a shape the value could never have had.

**`pattern` is why the attribute scanner is quote-aware.** A regular expression's own `{5}` is a closing brace, and reading attributes up to the first `}` meant the line stopped being a directive at all — the field simply never appeared. `DirectiveScan` and the marked tokenizer both scan `"…"` as one unit now; outside quotes a brace still ends the list, which is what keeps a directive one line long.

**Guidance is `aria-describedby`, not part of the label.** `help="…"` renders outside the `<label>`, because a label's text *is* the control's accessible name and guidance inside it would be announced as part of it. The ids are minted by the binder, which sees the whole document; the renderer sees one directive at a time and two forms may hold a field of the same name.

**Every row carries `createdAt` and `updatedAt`.** They are ordinary fields with reserved names, so `{createdAt}` works in a template and `field="updatedAt"` works in an aggregation with no extra machinery. The price is that the names are reserved: `Stamps.apply` drops an author's field of the same name rather than letting the two fight. An edit moves `updatedAt` and keeps `createdAt`, which is the whole reason the binder reads the existing row before writing.

**The aggregations are pure and the distinction between them matters.** `core/Aggregate.res` works on the *stored strings*: a value that does not read as a number is not counted, rather than counted as zero — an average over four rows where one was left blank is an average of three. An empty collection has a count and a sum (0) but no average, minimum or median, and those render as a dash rather than as a zero that would claim otherwise.

**What counts as a number is `core/Numeric.res`, not `Float.fromString`.** That function is `parseFloat`, which reads a numeric *prefix* and stops: it turns `2026-08-10T17:50:45.880Z` into 2026 and `10 items` into 10. The damage was silent and in two places at once — `::list{sort="createdAt" dir="desc"}` compared every row as the year they share, found them all equal, and the stable sort left them exactly as stored, which looks precisely like a `dir` nobody read; and a sum over a field of dates totalled the years. A stored value is a number only when the whole of it is one, and `RowView`, `Aggregate` and `Expr` all ask the same module.

`:calc` lives with `ReactiveStore`, not with the collections, because what it reads are the keys `:value` reads — a total that follows a form as it is typed is a bound view, not a query. `core/Expr.res` is a hand-written recursive-descent parser over `+ - * /`, parentheses, numbers and `#keys`, and it must stay that small: an expression in a document is evaluated on every keystroke of every control it mentions, and the point of not reaching for `eval` is that a document cannot execute anything. A missing or non-numeric key counts as zero, so a half-filled form shows a total that grows; a malformed expression or a division by zero has no answer at all rather than printing `NaN`.

`hidden` had to join the sanitiser's attribute list: the list template and both conditionals start hidden, and without it they all render at once for the instant before the collection is read — and the template renders permanently.

**A view and the rows it shows are two different questions.** `core/RowView` answers the second — search, `field=value` filter, sort, limit, paging, grouping — and `::list` and `::table` both ask it, because they differ only in how a row is *drawn*. Numbers sort as numbers and everything else as text: "10" before "9" is right in nothing and wrong in a column of prices. The sort is stable, so rows that tie keep the order they were created in and a table does not shuffle on every refresh.

**A table's search box and pager are built by the binder, not the renderer.** They carry words, and `MarkdownRenderer` is installed once at module load with no locale — the same reason the row buttons are built there. Its state (query, sort column, direction, page, the reader's filters — and a calendar's shown month) lives in a `WeakMap` keyed by the **container**, addressed by the view's position in it. Keyed by the *node* it silently evaporated: `setInnerHtml` recreates every node on each debounced render, so the state looked persistent and reset on every keystroke beside the editor. The container is React's and survives — which is how `PageNav` keeps the chosen page, and the one honest way to keep any per-view state here.

**`::table` shadows `sp-table`.** Ours is the rows of a collection; Spectrum's is a layout composed one row and one cell at a time. `DirectiveRegistry_test` asserts that `table` is the *only* colliding name, so the next collision is a decision someone has to make rather than a component that quietly disappears.

**`.rn-markdown td` outranks `.rn-align-end`.** The generic table styling for authored markdown is one class plus one element, so the table's own rules have to be scoped under `.rn-markdown` too — otherwise a column asked to sit against its right edge quietly does not.

### Open data

`::od-query{into sql limit}`, `::od-search{into placeholder table}` and `::od-datasets{into}` read the open-data service — the DuckDB warehouse under `data/` (`bun run od`, port 8788) — reached as **`/od/*` on this app's own origin**, proxy in dev/preview and a rewrite in production, exactly like `/pb`: `connect-src 'self'` keeps holding and no document can point the app at a host of its choosing (the old `dataServer` frontmatter is deliberately gone). What comes back lands in the **ordinary collection named by `into`**, and that one decision is most of the design: every view, aggregation and Python block reads fetched rows exactly as it reads saved ones, and the collection doubles as the offline copy — on an unreachable service the binder shows the row count with a "stale" status instead of an error over live-looking data. `{#key}` placeholders in the SQL become **prepared parameters** (`core/OdQuery`, quoted form `'{#key}'` consumed with its quotes — the values come from readers, and concatenation would be SQL injection into the service); the query re-runs, debounced 400 ms, when a key it mentions changes, via `ReactiveStore.subscribe` — a module-level listener list that deliberately survives `reset()`. Fetches follow the Python binder's discipline: signature per container position (the app id is part of it), generation counter against superseded responses, and rows with ids stable by position (`od-0`…) so an unchanged re-fetch is a no-op all the way down to the sync engine's diff. The search box is built by the binder — it carries words — and what was typed lives in the per-position state, like a table's search box.

### Charts

Seven `::chart-*` leaves (bar, line, pie, doughnut, area, radar, scatter) draw a collection directly — Chart.js is one lazy chunk (`ChartImpl`, reached only through the dynamic import in `ChartBinder`), so a document with no chart never loads it. The renderer emits an empty `div` (no `<canvas>`: it is not in the sanitiser's vocabulary and does not need to be — binder-built DOM is not sanitiser output). What counts as a number is whole-string with the **decimal comma accepted** — chart data comes from CSVs and open datasets — and a row that does not parse is left out, never drawn as zero. Series colours are the Okabe-Ito palette in fixed order. Charts follow the store through `rn:data`; per-position state keeps the instance so the old one is destroyed when the render replaces its node (a chart on a detached canvas animates for ever). `horizontal` and `stacked` are flags on bars; `chart-area` is a filled line.

### Map, ::geo and ::geocode

`::map{path}` is a container whose body is the popup template; rows become circleMarkers (vectors — Leaflet's default PNG icon is the classic bundler-broken-path bug, and a circle needs no asset), or GeoJSON areas with `geojson=`, choropleth-filled by quantile blues with `fill=`. Leaflet is a lazy chunk (`LeafletImpl`). Coordinates: `coords=` one field holding `"lat, lon"` — the format `::geo` writes — or `lat=`/`lon=` two columns. A row without valid coordinates simply has no marker. The reader's view survives edits and refreshes: it follows the markers (fitBounds) until their first own gesture — and **our own `setView` emits the same `zoomstart` a reader's does**, so the flag is suppressed while any of our fits settles, or the map counts its opening view as the reader's and never follows again. Popups substitute the row into the template's **text nodes**, the list binder's rule. Tiles are `img-src https:` (the one reason that grant exists); a `tiles=` URL is accepted only as https with `{z}/{x}/{y}`, else OSM with credit. Dark themes re-tone tiles by CSS filter. `::geo{field}` is a form field plus a button writing the device position on a click; `::geocode{path from to}` batch-resolves addresses via Nominatim — always on a gesture, one request a second, 50 per click, written row by row so an interrupted run keeps its answers, idempotent by design (only rows with the address and without coordinates are asked about).

### Dashboard

`::dashboard{path}` is the BI cross-filter, one WeakMap deep (`shell/Dashboard`): clicking a bar or slice of a nested chart selects that x value; every row-reading binder narrows through `__rnDashboard.rowsFor` (the single funnel is `arrangeFor` in CollectionBinder, plus the map's read). Three rules from the tools it imitates: the clicked chart never filters itself — it dims the other bars, keeping context; a view over another collection filters only rows that HAVE the selected field; the selection is per device, never synced, and survives edits. A chip shows the filter with its ✕. A second click on the same bar clears.

### ::api-query and derived collections

`::api-query{url into pick as every}` reads any public **https** JSON API into a collection; `{#key}` URL placeholders are percent-encoded reactive parameters (a URL, so encoding *is* the escaping); `pick` walks by dots and indices; the shapes are decided in `core/ApiRows` (array of objects = rows; object of arrays = columnar zip, Open-Meteo's shape; object of scalars = one row, or `{key, value}` pairs with `as="pairs"`; a scalar feeds the `::api-query[storekey]` form, which writes a reactive key instead). `every=` polls, floored at 60 s; a refresh button always exists. This and the map are why the CSP now grants `connect-src https:` and `img-src https:` — the comment in `vite.config.js` says what each grant can and cannot express, and `SecurityPolicy_test` pins both copies.

**Derived collections** (`shell/DerivedPaths`) are the one mechanism under api-query, ::sql and the ml-*: a collection they write is marked derived in IndexedDB, and the sync engine neither pushes it (a fetched rate is not a shared fact) nor lets a remote snapshot delete it (`materializeToLocal` skips derived paths in its removal pass). The marks follow a renamed app.

### ::sql

DuckDB-wasm over the app's own rows: collections named in `data=` are re-registered as tables on every run through `read_json_auto` (types inferred — numbers are numbers), the fenced body is ONE prepared SELECT, `{#key}` placeholders are the same reactive prepared parameters as od-query, and the result lands in the derived collection `into=`, capped at 1000 rows. The engine (~10 MB compressed) comes from jsdelivr — its worker is refetched and rewrapped as a blob URL because `worker-src` allows `'self' blob:` and a cross-origin worker script is neither — and the VERY FIRST run waits behind a Run button, remembered in IndexedDB. Remote https Parquet/CSV read directly (`connect-src https:`).

### The ml-* directives

Five leaves over the shared Pyodide runtime: `ml-cluster` (K-means, standardised), `ml-anomaly` (Isolation Forest), `ml-predict` (linear/forest regression, R² in the status), `ml-correlate` (Pearson pairs — pure Python, no package download), `ml-forecast` (linear trend, SARIMAX or Holt-Winters via statsmodels, with a declared linear fallback). The one rule that matters: **the executed code is a fixed template** — rows and parameters travel in the runner's data channel and Python reads them from `data`, so nothing an author writes is ever pasted into code (the SQL-injection argument, again). Features are numeric fields, decimal comma accepted, unusable rows dropped and counted in the status (`used/total`). Numeric parameters accept `#keys` and re-run debounced. Results land derived; the first run that needs a package (scikit-learn, tens of MB, cached) waits behind Run, once.

**Whether a package is needed is a property of the run, not of the block** — and for `ml-forecast` it is the *reader's* choice, because the linear trend needs nothing and `arima`/`holt` need statsmodels. Deciding it once at bind time is what made a picker over `model=` do nothing at all: a document that opens on `linear` was bound with no Run button, and the moment somebody chose ARIMA the run reached `if (packages && !enabled) return` and fell into that bare `return` — no download, no button, no message, no error, and the chart went on showing the straight line they had just asked to replace. It is the silent-return failure the rest of this file keeps warning about, in the one place where the condition it guards can change after the guard has run. So `run()` asks, and offers the button itself; `bind` has nothing left to decide.

**The first fitted values of a differenced model are not predictions.** SARIMAX reports them as zero — one for `order=(1,1,1)`, five once a seasonal difference is added, and `loglikelihood_burn` is the model's own count — so leaving them in drew the projection line from 0 to 36 000 in one step, flattening a ten-year enrolment chart under a spike at its left edge, and made the R² computed against that zero come out at **-63**, telling the reader the model was catastrophic when it was fine. They are dropped rather than zeroed, so those rows carry no `previsione` at all and the line starts where the model does; the R² is measured only over what was fitted; and a non-finite forecast is raised rather than carried, since `json.dumps` writes it as the bare word `NaN` and the run would come back as a parse error naming nothing. The `except` that swallowed all of this said `linear`, which was true and explained nothing — the reason travels with the status now.

Two things that look like faults and are not: Holt-Winters over a smooth series converges on α=β=0, which *is* the least-squares line, so it legitimately returns exactly what `linear` returns (on a series with a turn — teachers in Milan, 2015-2024 — it differs by three thousand and scores better); and a series of fewer than three points has no forecast at all, which is a data-coverage answer and not a broken directive.

### The ai-* directives

Fifteen leaves and containers putting the assistant's own model to work *inside* an app
(`core/AiDirective`, `core/AiIndex`, `shell/AiRunner`, `shell/AiBinder`). One rule
carries the whole family and is why they are safe in a document somebody else wrote:
**the model never produces anything that is executed** — it produces a word from the
closed list the document wrote, an object whose keys the document declared, or a *query
plan* whose every field name is checked against the collection's own and which is then
run locally, over rows this device already has. Everything else is refused in
`core/AiDirective` before it can become a row, which is the `::python`/`::sql`
data-channel argument again.

`ai-summary` (reactive, re-runs on `rn:data`), `ai-chat`, `ai-agent` (two tools —
`query` reads, `insert` **proposes** a row written only on a confirm button, every step
logged), `ai-pipeline` (the rows whose FIRST declared field is empty, 25 a batch),
`ai-query` (the widget shows the plan as well as the answer, breakdown into `into=`),
`ai-rule` (compiled ONCE into a checked plan kept in IndexedDB, then runs with no model
at all — deterministic, and idempotent because `applies` returns only rows whose value
would change), `ai-classify`, `ai-extract` / `ai-field` / `ai-suggest` / `ai-assist`
(these fill the form's DRAFT — read straight off the inputs at save time, so setting
`input.value` and dispatching `input` is the whole of it — and a person presses save),
`ai-translate` / `ai-rewrite` (a `#key` or a form field, in place), `ai-vision`,
`ai-search`.

**Where the data goes is a property of the endpoint, not of the directive**:
`AiSettings.isLocal` is the only place that is decided, and the panel, the binders and
the privacy policy read the same function. With no model configured every directive
paints one sentence (`AiNotConfigured`) and the app keeps working — a document written
for a model must not become a page of broken widgets on a browser that has none.

`::ai-search` and `rag=` index the named `collection.field` pairs — including the text
content of a `::file` attachment when the browser can decode it — as chunks with
embeddings, kept in IndexedDB and rebuilt only when `Digest.of_` of the source text
changes. **PDFs and scans are deliberately not indexed**: such a file is indexed by its
name, and a search that quietly indexed the name while looking as though it had read
the file would be worse than not offering it. The embedding model is
`AiSettings.defaultEmbedModel` — Qwen3-Embedding-0.6B — and is deliberately NOT a
setting: the choice has two honest answers and the endpoint decides between them
(OpenAI's own host gets `text-embedding-3-small`, since it is the one host that will
not serve Qwen).

Two things that were nearly wrong: a labelled-argument ReScript function called from
`%raw` takes **positional** parameters, not an options object; and `DirectiveClass`
needed a new `Ai` class, or the block editor's slash menu would have filed fourteen new
entries under nothing (its test says so rather than letting them fall quietly into
"other").

### ::workflow

The orchestrator, and it computes nothing: `::od-query`, `::api-query`, `::sql`,
`::python`, the `ml-*` and the four `ai-*` that work through a collection on their own
were already a data-flow graph — `into=` above, `data=` below — settling by cascade.
What no engine can have on its own is what the container adds: **an order** (topological,
`core/WorkflowGraph`, stable so independent steps keep the order they were written in),
**a trigger** (`every=`, `at=`, `on="save:…/change:#…/open"`, `core/WorkflowTrigger`),
**one status line** instead of five, and **the rule that nothing downstream of a failed
step runs** — a number computed from an input that never arrived is worse than no
number, because on the page the two are indistinguishable.

**There is deliberately no node language.** The steps are the ordinary directives and
the edges are the collection names they already carry, which is what keeps this one
graph — the same one `reactive_analyze` builds — rather than two that can disagree. It
is also what makes the whole thing expressible with no new syntax: an author who can
write `::sql` can write a workflow.

**An engine learns exactly one thing to become a step.** `shell/WorkflowHost` installs
`globalThis.__rnWorkflow` — the dashboard's pattern, because a binder cannot import
another binder — and each engine asks `defers(node)` (`closest("[data-rn-workflow]")`,
the containment rule the forms already use) and, when the answer is yes, hands its own
run over instead of calling it. **The report travels back through the engine's own
`.rn-od-status`**: the class is the verdict, structural and language-free, and the text
is already in the reader's language because the engine wrote it. One channel, so there
is nothing to keep in step — an engine that grows a new message tomorrow is understood
by the strip without being touched.

**The strip hides each step's status line and its code, never its controls.** The
first-run gate of `::sql` and of the `ml-*` packages, and a manual `::python` block's
button, stay where they are: a step waiting for somebody to press something is reported
as waiting, and hiding those buttons would produce a step that silently never runs —
the failure `ml-forecast` already taught this codebase once. Stop acts *between* steps;
a request in flight finishes and a Python block keeps its own Stop.

**A schedule can only mean "while the app is open", and the strip says so out loud.**
There is no server and the service worker precaches rather than executes, so `at="18:00"`
is *the first time the app is open at or after 18:00 on a day it has not already run* —
`catchup` chooses between the whole evening and the hour after. `every=` is floored at
60 s because a background tab is throttled to about one timer a minute, which is the
same decision `::api-query{every}` already made. The timer is only the bell: the truth
is the last run in IndexedDB, compared on the tick, on `visibilitychange` and at bind,
so a laptop that slept through six o'clock finds out when it is looked at.

**Without any trigger a workflow is exactly as reactive as the loose directives were** —
it re-runs on `rn:data`, and every engine's own signature makes an unchanged step a
no-op. The echo is what needed guarding: the steps of a finished run announce `rn:data`
themselves, so a quiet period after settling stops the chain walking itself again to
discover nothing moved.

**`rn:collection-write` carries the path now.** `on="save:spese"` has to tell one
collection from another, and announcing the app alone would have made a workflow
watching one form re-run on every write in the document — which is not a trigger, it is
a coincidence. The sync engine reads only the app and is untouched by it.

**The in-place field writers declare what they read and nothing else.** `ai-classify`,
`ai-rule` and `ai-pipeline` write one field back into the rows they read, so declaring
them writers of that collection would make two of them over one collection feed each
other and both would be reported as a circle. Their place in the run is the place the
author wrote them in, which is what the stable order is for — and it is the same
distinction the analyzer draws: they change a collection, they do not own it the way a
`::python{writes}` does.

**A cycle is reported, not run.** The signature guard breaks most loops by accident, but
not one whose output carries a timestamp, and that one spins for ever with nothing on
screen saying why. What can still be placed is still run; the rest is marked and named.

`reactive_validate` refuses an `every=` or an `at=` that does not parse, through the
same compiled parser the binder uses — an unreadable schedule leaves the workflow
manual, which is the silent-return failure this file keeps warning about, arriving
through an attribute that is visibly there.

### ::explore

Perspective (WASM, a lazy chunk) as `::explore{path view group-by split-by columns}`: the reader's own pivot — drag, group, chart, filter — without touching the document. Column types are inferred (whole-string numbers go in as numbers, so aggregations sum). The configuration the reader builds is saved on every `perspective-config-update` into per-position state and restored onto the fresh viewer each render creates; the table itself survives and is `replace`d when rows change, which is what makes an IoT stream draw itself. The optional fenced body is the viewer's native JSON config and wins over the attributes.

**A viewer that leaves the document is `delete()`d.** Perspective is explicit that removing a `<perspective-viewer>` without it leaks WASM memory, and the preview replaces every node it owns on each debounced render — so a document being typed beside would leak one viewer per keystroke, each still holding observers and still measuring an element that is no longer there. The table is deliberately kept: it is ours, it outlives the node, and the next viewer loads it again.

**Not building on a host of no size and withdrawing when the size goes away are the same rule.** A `::page` that stops showing carries `hidden`, and the viewer standing on it keeps drawing against a box of nothing — which is where Perspective reads `undefined` for its own layout and throws from inside `draw`. So the zero-box branch deletes the viewer as well as marking the position deferred, and the `rn:page` listener visits *every* container rather than only the ones with work put down: a page going away has to be heard as clearly as one arriving. Coming back costs a mount, since the reader's configuration is in the per-position state and the table never left.

**`restore()` is all-or-nothing and leaves what it refused pending on the element**, so there is no second chance — restoring the plugin alone afterwards fails with the same complaint. One column name the rows do not have therefore costs the *whole* configuration, the chart included, and the reader gets a datagrid where the document asked for a chart with nothing saying why. The binder drops unknown names from `group-by`/`split-by`/`columns` before restoring; a fenced JSON body is passed through untouched, since an expression invents its own columns.

**That warning was right, and this is what it was.** Perspective's datagrid stands on `regular-table`, which builds its shadow root from a template that OPENS with two `<style>` blocks and then reads the children back BY POSITION — `[, sub_cell_style, virtual_panel, table_clip]`. Under the production CSP that `innerHTML` goes through the default Trusted Types policy, DOMPurify parses the fragment as a document and hands back the **body alone**, and the HTML parser hoists a *leading* `<style>` into `<head>`. Two children short, every field bound to the wrong node, `_table_clip` undefined — and the crash lands far away and much later, inside Perspective's own `draw`, as `Cannot read properties of undefined (reading 'clientWidth')`. The fix is `FORCE_BODY` in `Sanitizer`, described there. Nothing about it is specific to Perspective: **any bundled library that builds a shadow root from a template beginning with `<style>` had the same hole**, and the same one-line remedy closes it.

It only ever happened in production, which is the whole lesson of the CSP being build-only: `bun run dev` installs no policy, so `innerHTML` lands verbatim and the grid is perfect.

### Print, files, row arithmetic, Excel

`::print{target label}` prints ONE section: two classes and a `@media print` rule — everything `visibility: hidden` except the target, lifted out of its scroll containers (`visibility`, not `display`: hiding an ancestor with display would take the target down with it). Classes come off on `afterprint`.

`repeat` prints one page per row: for each row of that collection the reactive key is set, the views are given a moment to catch up, and the target is *photographed* into a printing container — one sheet per row, page break between. The copies are dead HTML, which is why this works at all. Nothing enforces that the target depends on the key: a section that does not read it is photographed identically twenty times, and the button cannot tell, because from where it stands nothing is wrong.

`::file{field maxkb accept}` is a form field holding a file: a visible file input plus a **hidden `.rn-field-input`** carrying the value, so drafts, validation and editing work unchanged. The value is a small JSON — `{name, data}` up to 300 kB (inside the row, synced: the same sync-change arithmetic as a chat attachment) or `{name, local}` above it (bytes in `shell/FileStore`, this device only; elsewhere the name shows and the content honestly does not exist). Views recognise the JSON where values land — `applyTemplate` and the table cell — and render an image preview or a named download; **only `data:` URLs are ever rendered**. The ceiling is `maxkb` (default 10 MB).

`{qta*prezzo}` in a row template computes per row: `core/RowExpr` is `core/Expr` with the `#` implied on every identifier — one arithmetic, the tested one. Missing fields are zero; two decimals; and **`a-b` is a field name** (hyphens are legal in one), so subtraction needs spaces — the `looksLike` test is what keeps `{a-b}` a plain token. Aggregations accept the same expressions in `field=`, so `:sum{path field="qta*prezzo"}` totals an invoice with no Python anywhere.

**The panel lists the collections that EXIST, which is not the same as the ones an app has.** A collection appears once something has written it, so on an app nobody has typed into yet the list holds only what its automatic blocks produced — and none of the collections a spreadsheet would be poured into. That is precisely the moment an import is most wanted: a school starting from the file it already has. So the panel carries an **Importa in** field above the list: the name is typed, and the two import buttons appear beside it. Typed rather than chosen, because what is not there cannot be offered — and the collection joins the list from the first import onward.

The data panel also moves one collection as a real `.xlsx` (SheetJS, lazy chunk, installed from the official tarball — the npm registry copy is stuck on a vulnerable release). `core/Sheet` is the pure grid↔records mapping with the CSV rules, because they are about spreadsheets, not commas: ids travel in their own column so a re-import updates, a file without one gets fresh ids.

### Calendar, in four views

`::calendar` now takes `view=month|week|agenda|matrix` (the matrix — rows are days, columns the values of `by=` — is a real `<table>`, because the day/value relationships are what a screen reader announces). `field`/`end` are the newer spellings of `from`/`to`, both read. `by=` colours events per value with an automatic legend; `time="HH:MM"` orders inside the day; `form="id"` makes days clickable — the click fills that form's date field and scrolls it into view, keyboard-reachable; every event carries its row as a tooltip (`tooltip="false"` off, `tooltip="{a}: {b}"` template). A Today button sits between the arrows, which step weeks in the week view. The week arithmetic is `MonthGrid.weekDays`/`shiftDays` — the civil (Hinnant) algorithm on written days, pure integers, because `new Date("2026-08-10")` is midnight UTC and lands on the ninth west of Greenwich.

### Columns

`::columns{min gap}` lays its content out in columns that reflow by themselves: `grid-template-columns: repeat(auto-fit, minmax(var(--rn-col-min), 1fr))`, and that is the whole mechanism. There is no breakpoint to keep in step with anything — the document says how narrow a column may get and the grid decides how many fit.

The floor below which it is one column is a **container** query, for the same reason the page rail is: what decides how many columns fit is the room the *preview* has, which at `/a/<id>` is the window and beside an editor is half of it. A media query would give the split view three columns it has no space for.

`min` reaches the CSS through `shell/Columns.res` calling `setProperty("--rn-col-min", value)`, never through an inline style built by concatenation. The value comes from a document, and `setProperty` hands it to the CSS parser whole: `18rem` lands, `18rem; background: url(…)` is refused. `gap` is a `Choice` of `s`/`m`/`l` and becomes a class, so no value from a document reaches the stylesheet at all. The same grid is what `::cards` and `::board` use.

### Views over a collection

`::list`, `::cards`, `::table`, `::board` and `::calendar` draw the same rows. They ask `core/RowView` the same questions — search, filter, sort, limit, page, group — and differ only in the shape they draw, which is why `::cards` *is* `::list` with a different wrapper: the renderer emits `data-rn-list` for both and the binder has one code path.

**`::timetable` is the board with two axes.** A board's drop writes one field; an orario needs the day *and* the hour, so the grid asks `core/TimeGrid` which cell a row falls in — rows and columns from the attributes or from the data, ordered numerically-then-textually like `RowView` — and the drop writes BOTH fields plus `updatedAt`. Two things it does that the other views do not: `pin` marks a row that cannot be dragged (the lesson somebody fixed, which the solver must not move), and `blocked` names a *collection* of forbidden cells — `row`, `col`, optional `for` and `why` — so the validator is an ordinary `::python` block writing rows and the grid merely reads them. A refused drop says why; the colour is never the only carrier.

**A board is a verb.** Dragging a card into another column writes that column's value onto that row's `group-by` field, stamps `updatedAt` and leaves `createdAt` alone. Without that it would be a grouped list with borders. The drag is the HTML one, so it does not work on touch — the card keeps its edit button for that, and the same is true of any interaction that only a pointer can express.

**The calendar does its arithmetic on written fields.** `core/MonthGrid` is pure: leap years, the weekday of the first, six weeks always so the grid does not change height as the reader moves through the year. A row with `from` and `to` is a *span*, and whether a day falls inside one is a string comparison — `YYYY-MM-DD` compares as text, so a ten-year span costs what a one-day span costs. Nothing here parses an instant: `new Date("2026-08-10")` is midnight UTC and lands on the ninth west of Greenwich, which is the bug this app already fixed once.

**A relation is written where it is read.** `{who>people.name}` says that `who` holds the id of a row of `people`; the token names the collection because a list is usually nowhere near the form that made the reference. The input that makes one is `::input{type="ref" path label}`, and what it stores is the id — so renaming the referenced row changes every view of it, which is the whole point of not storing the name.

**The reader's filters and the author's are the same kind of thing.** `filters="who,settled"` builds one control per column from the values actually present, narrowed by whatever else is chosen; they are applied by the same `RowView.filter`, one after another, alongside the author's fixed `filter`. Two filters mean both.

### Pages

`::page{title icon}` splits an app into pages with a sticky menu. The renderer emits each page hidden and on its own — it sees one container at a time and cannot know how many there are — and `shell/PageNav.res` decides everything that needs the whole set: the menu, which page is showing, and that a document with **one** page gets no menu at all, because a control with a single entry does nothing.

The menu is laid out as an application's navigation rather than a strip of buttons: a rail down the side where there is room, and a bar where there is not. The switch is a **container** query, not a media query — what matters is how much room the preview has, which at `#/a/<id>` is the window and beside an editor is half of it, and a media query would give the split view a rail it has no space for. `.rn-markdown` carries the `container-type: inline-size` that makes the question answerable.

Below the two-pane breakpoint the *page* scrolls rather than the panes, which two rules have to agree about: `html, body { overflow: hidden }` is undone there, and `.rn-preview` stops being a scroll container. Both matter — the first is what stopped a phone scrolling at all, and the second is why the sticky menu was sticky and never stuck: a sticky element sticks to its nearest scrolling ancestor, and that ancestor was itself scrolling away.

The menu is a `<nav>` of buttons with `aria-current`, deliberately not an ARIA tablist: a tablist is a promise about arrow keys and roving tabindex, and a list of buttons that swaps a region is what this actually is. The chosen page is kept in a `WeakMap` keyed by the container, because the preview replaces its `innerHTML` on every debounce and losing it would snap the reader back to page one as the author typed.

**A component that measures itself cannot be built on a hidden page.** A page that is not showing carries `hidden`, so its canvas has no box, and Leaflet's `fitBounds` against zero pixels is the minimum zoom: the world in a corner, for ever. Chasing it afterwards does not work either — `ResizeObserver` and `IntersectionObserver` are both delivered by the *rendering* lifecycle, so while nothing is being rendered neither fires at all. The moment a page gains a box is known in exactly one place, so `PageNav` dispatches `rn:page`, and `MapBinder` and `ExploreBinder` defer construction until the canvas measures something. Related, and found the same afternoon: `MarkdownRenderer` handled `map` and `explore` only as *containers*, so written as a leaf they fell through to the registry and came out as a bare element with the attributes stripped — rendered, empty, and silent about why.

**The icon is chosen from Spectrum's own set**, and how it is shipped is the interesting part. The elements are not an option: 1096 custom elements are 4.3 MB. A per-icon dynamic import is the obvious answer and is a trap in both directions — left unanalysed (`@vite-ignore`) it resolves in the dev server and fails in the bundle, because a bare specifier cannot be imported at runtime; analysed, it splits the build into a thousand chunks. `scripts/generate-spectrum-icons.mjs` therefore extracts the *drawings* into `src/generated/spectrum-icons.json` (840 kB, one lazily-imported chunk, the same policy as the component bundle) and the *names* into `SpectrumIcons.res`, where the registry offers them as a `Choice` so a name outside the set is refused rather than drawing nothing. The SVG is built with `DOMParser`, not `innerHTML`: it is not a script sink, so no Trusted Types policy is involved.

### The Spectrum component registry

`scripts/generate-spectrum-registry.mjs` reads the Custom Elements Manifests that ship with `@spectrum-web-components` and emits `src/generated/SpectrumRegistry.res`: **92 components, 482 attributes**, each typed as Flag / Number / Choice / Text. A manifest union of string literals (`'text' | 'value' | 'none'`) becomes a `Choice` with its allowed values, which is what lets a wrong value be reported instead of silently ignored by the element.

Regenerate with `bun run spectrum:registry` after upgrading the library. Never edit the generated file.

**One renderer serves all 92.** `MarkdownRenderer` looks the directive up in the registry, validates each attribute against the schema and builds the element; there is no per-component code. The same registry generates the BlockNote block specs and, by design, will drive editor autocomplete. Adding a component is a library upgrade, not a code change.

Three things this arrangement demands:

- **The directive name is the Spectrum tag without `sp-`**, which is what keeps this vocabulary distinct from ReactiveNET's — the slider is `::slider`, not `::range`.
- **The sanitiser has to know the tags.** `Sanitizer.res` carries all 92 tags and 190 attribute names, generated from the same registry; a component silently losing its attributes to DOMPurify looks exactly like a broken component.
- **The component bundle is 2.6 MB**, past Workbox's precache ceiling. It is split out of the shell chunk and loaded on demand by `shell/SpectrumElements.res`, only once a document actually contains an `sp-*` element. Until it resolves the tag is an inert unknown element that upgrades in place.

**ReactiveNET's own directives are in the registry too.** `DirectiveRegistry.reactive` describes pages, forms, lists, conditionals and aggregations in the same shape as a Spectrum component, so the editor completions, the block specs and the attribute validation all read one list and none of them needs to know the difference. Ours come first, so a name that ever collided with a Spectrum component would resolve to the directive the renderer actually handles.

`core/DirectiveRegistry.res` is what every consumer reads — never the generated file directly. It adds the attributes the manifests leave out: a manifest describes a component's *own* API, so `id` — an HTML global, and the handle one directive uses to point at another — appears on none of the 92. Adding it there rather than in the renderer means the block specs and the completions gain it in the same move.

There are deliberately **no per-component overrides**. The accordion used to have one, rendered by hand to native `<details name>`; it is now `sp-accordion` holding `sp-accordion-item`, exactly as Spectrum composes it, which the block grammar makes expressible in the source. Grouping comes from the element, not from `<details>`.

Two things the manifests do not tell you, both found by rendering all 92 at once:

- **`sp-grid` is described by the manifests and not shipped by the bundle.** It is offered, it validates, it renders — and it never upgrades, so it draws nothing. It is the one component of the set that cannot work at all, and only registering it would change that.
- **An overlay written with `open` freezes the whole app.** `sp-overlay`, `sp-dialog-base`, `sp-dialog-wrapper`, `sp-tray` and friends put themselves in the top layer, which leaves the document behind them inert: no click reaches anything, and no directive closes them again, because the trigger lives in a named slot a document cannot fill. Named slots being unreachable is the general rule — a body goes to the default slot, so a dialog's `heading` and `footer` are out of reach too — and this is where it hurts.

**A completion carries the colons it needs replaced.** A directive snippet includes its own colons, and CodeMirror's completion range covers only the word being typed — so accepting `::acc` wrote them twice. `DirectiveCompletion.completion` therefore has a `back` field saying how many characters before the word the snippet already accounts for, and the editor extends the replaced range by it. It is zero for attribute and value completions, where the text before the cursor is not the snippet's to own.

**Whether a completion closes itself is the component's business, not the author's**, since they type `::` either way. `holdsContent` is "has a slot *and* carries no value": a slider has a slot but is written `::slider[key]`, where the brackets name the store key and there is nothing to put inside, so offering it a close would be offering the shape nobody writes.

**Newlines inside `%raw` are emitted verbatim.** Writing `"\\n"` in a ReScript raw block puts a literal backslash-n in the JavaScript, so the serialiser joined blocks with two visible characters instead of a line break and the whole preview came out as one escaped run. It must be `"\n"`.

Each generated block spec is built inside its own `try`: one spec that fails to construct leaves an `undefined` entry in `blockSpecs`, and the resulting schema breaks *every* block with `Cannot read properties of undefined (reading 'isInGroup')` — an error naming neither the component nor the cause.

### Directives as BlockNote blocks

Directives and the frontmatter are **custom BlockNote specs**, so they are created, edited and deleted inside the block editor like any other block — from the slash menu, the block handle, or by dragging. Every registry component gets a block spec, `:value` is an inline content spec, and the frontmatter is a block of its own.

**In the block editor, nesting is indentation.** Anything indented under a component block becomes its content, so the block is written back as a container. Reading the stored `dform` prop alone was the bug: a block inserted from the slash menu starts out a leaf, so indenting anything under it silently dropped the children on the way to markdown. Since the close names the directive, nothing about a container depends on what is inside it any more — the body no longer has to be measured before its own wrapper can be written.

The price is serialisation, and it is paid in `BlockNoteImpl.res`: BlockNote's markdown converter knows nothing about these types and escapes what it does not recognise, so **both directions are done by hand**, per block, delegating to BlockNote only for ordinary blocks. Markdown → blocks splits the source on `DirectiveScan` occurrences; blocks → markdown renders ours through `DirectiveScan.render` and calls `blocksToMarkdownLossy` for the rest. The frontmatter block is hoisted on the way out, so one dragged into the middle of the document is still written where the format requires it.

Two traps:

- **`createReactBlockSpec` returns a factory, not a spec.** Passing the function straight into `BlockNoteSchema.create` fails deep inside ProseMirror schema construction with `Cannot read properties of undefined (reading 'node')`, nowhere near the cause. It must be called: `directiveRange: RangeBlock()`.
- **A paragraph containing an inline directive is rebuilt by hand**, because BlockNote would drop the custom node. Character styling inside *that paragraph* is lost — the narrowest place to pay the cost.
- **A container's body is parsed by recursing into our own splitter**, not by handing it to BlockNote. Its markdown parser knows none of these types and escapes them, so a nested directive would come back as literal text.

`DirectiveScan` remains the shared vocabulary: the same scanner and renderer serve the marked pipeline and the block editor, so directive syntax has one definition and it is the tested one.

### Python

`::python` runs **real CPython** — Pyodide, WebAssembly, in a Web Worker. A worker and not the page for one reason that decides the rest: the code is somebody's, in a document, and a loop written by accident must not take the editor with it.

The code goes in a **fenced block inside the directive**, because a fence is the one place markdown keeps indentation exactly as written and indentation is Python's syntax. The renderer emits structure only, as ever; `shell/PythonBinder` reads the code back with `textContent`, hands it to the worker as a string, and writes what comes back with `textContent` too — a traceback is words, a print is words, and neither is markup.

**`params` carries the reactive keys in, `manual` decides who starts it.** `data=` brings collections and nothing else, so the weights of a solver — which live on sliders — had no way in; `params="w"` passes the current value of those keys as `params["w"]`, and they join the signature, so moving a slider re-runs and putting it back does not run twice. A `manual` block never starts by itself: a simulated annealing must not restart because somebody corrected a surname. That is also what buys it time — two minutes for a run nobody asked for, ten for one somebody did.

**A long run reports and can be stopped, and `partial` is what makes Stop honest.** `progress(done, total, message)` draws the bar; `partial(rows)` publishes the best answer so far. Stop terminates the worker and writes the last `partial` received — a block that never calls it gives Stop nothing to keep, and the run ends having written nothing. That is a property of the contract, not a bug: there is no way to recover a result the code never published.

**A block re-runs when its code, its data or its packages change, and not otherwise.** The preview re-renders on every keystroke; a run per keystroke would make a document with Python in it impossible to type. The signature — and the last outcome, and whether the source is open — lives in per-container state addressed by block position, exactly like a table's page: on a node's dataset it was destroyed with the node each render, so the guard never matched and every keystroke queued a full Pyodide run. On a render whose inputs are unchanged, the cached outcome is repainted into the fresh node — skipping the run must not also skip showing what it produced.

**Clearing the run's controls belongs to every block, not to the manual ones.** `offerRun` used to return early when the block was automatic, and the early return was *before* the line that empties the controls — so a finished automatic block kept its progress bar, the word "running" and a Stop button for ever, with the answer printed right above them. What hid it for so long is where it showed: beside the editor the next keystroke builds a fresh node and takes the stale controls with it, so it only ever appeared on an app running at its own address, which is exactly where nobody is typing. It surfaced from the screenshot script, which asks "is every block idle?" of what the binder itself puts in the DOM — and got told no, for ten minutes, about three blocks that had finished.

**A run has a ceiling and the interpreter forgets `result`.** Two minutes, then the worker is terminated and every pending run answers with an error: an accidental infinite loop never posts back, `onerror` does not fire for a busy loop, and without the ceiling one stray loop wedged every future run of the session. And `result` is popped from the globals before each run — the interpreter is shared, so a block that never assigned it would otherwise hand the *previous* block's rows to its own `writes` target.

**`packages` resolve against the CDN, not `indexURL`.** The wheels are not vendored — numpy alone outweighs the app — so `loadPyodide` gets `packageBaseUrl` pinned to jsdelivr at the vendored version. Without it package requests resolved against `/pyodide/`, where every wheel is a 404 and `packages` could never have worked.

**A collection has exactly one owner.** `writes` does not append: it replaces the whole collection, because a block re-runs and «insert if absent» is not something the grammar can express. So a collection written by a block must not also have a form on it — the next run would wipe what somebody typed. The way through, which `mcp/examples/orario-scolastico.md` demonstrates and explains in its own first page, is a pair: the form writes `classi-aggiunte`, which is the person's and which no block touches, and the block writes `classi` = the seeded rows plus theirs, carrying their ids across so everything pointing at them stays valid. `reactive_analyze` reports the collision, which is how the rule was found rather than discovered later by somebody losing an afternoon of typing.

**`writes` sends rows back.** A list of dicts assigned to `result` becomes a collection of this app — same shape as everything else, ids kept when the code carries them so a second run updates rather than doubles. A block cannot write to a collection it also reads: that re-runs itself for ever, and it is refused rather than left to spin.

Three things this costs, all of them in `vite.config.js`:

- **`script-src 'wasm-unsafe-eval'`.** A WebAssembly module has to be compiled by something the policy allows explicitly, and CPython is one. The token exists precisely so wasm can be permitted *without* opening `eval` and `new Function` — which is what `script-src` is actually for.
- **`connect-src https://cdn.jsdelivr.net`**, the only third party in the whole policy. The interpreter is vendored (`bun run pyodide:assets` copies 13 MB into `public/pyodide`, and `globIgnores` keeps it out of the precache), but numpy and matplotlib are megabytes each and are not. Only a document that names a package ever makes that request.
- **The worker's runtime URL is built, not written.** `import("/pyodide/pyodide.mjs")` as a literal is refused by Vite's import analysis — files in `public/` are copied as they are and are not part of the module graph — so the URL is constructed at runtime and the import is `@vite-ignore`d.

## Internationalisation

Seven languages: English, French, German, Spanish, Portuguese, Chinese, Italian.

**Missing translations are build errors, not runtime fallbacks.** `Translations.key` is a variant and each language is a `switch` over it, so adding a key fails to compile in all seven until every one is written. There is deliberately no `Map<string, string>` and no default-to-English path — a key that silently renders English is exactly the bug this design removes.

`Locale.parse` takes the primary subtag only, so `en-GB`, `pt-BR` and `zh-Hans-CN` all resolve. `LocaleStorage.browserPreference` walks `navigator.languages` in order and takes the first *supported* entry, not the first entry. The choice is persisted in IndexedDB and re-applied one effect after mount, same as the theme.

BlockNote ships dictionaries for all seven, so its slash menu and toolbars follow the app language. It reads the dictionary when the editor is created, which is why `useCreateBlockNote` is keyed on it — a language change rebuilds the instance.

## Theming

Two independent axes, because Spectrum's `sp-theme` `color` attribute selects a shade of the neutral scale, not a hue:

- **Polarity** — `Theme` is light or dark, driven by the navbar switch, seeded from `prefers-color-scheme`, persisted.
- **Palette** — `Palette` offers six hues. Each is an `rn-palette-*` class on `sp-theme` that overrides Spectrum's accent tokens; `core/Palette.res` owns the identity and ordering, `index.css` owns the colour values, and the two must stay in step.

The palette travels as a **class, not a data attribute**: ReScript's `@as("data-palette")` rename does not survive into the props object React hands to a custom element, so the attribute arrives misspelled (`dataPalette`) and no CSS ever matches. That failure is silent — the app renders fine, just never re-coloured.

Two traps worth knowing:

- **`sp-picker` dispatches `change` from its `value` setter.** React writes `value` back on every render, so an unguarded `onChange` handler starts a set-value → change → setState → set-value loop that pegs the main thread. `Navbar.res` compares against the current locale before calling back; that guard is load-bearing.
- Some strings are legitimately identical across languages — "Markdown" is a proper noun, "Editor" is the same loanword in German, Spanish, Portuguese and Italian. `Translations_test.res` lists them explicitly so a genuinely untranslated string cannot hide among them.

## Accessibility

The project targets **WCAG 2.2 level AA**. The scope is the app's own chrome and the rendered document — the *app* a directive document produces. The two editors are explicitly out of scope: CodeMirror and BlockNote are third-party editing surfaces whose conformance is not ours to guarantee.

**Contrast is enforced by tests, not by eye.** `core/Contrast.res` implements the WCAG relative-luminance and ratio formulas, and `Palette_test.res` asserts every palette against its surface, so a colour below 4.5:1 fails the build. The original six palettes were picked by eye and all failed on light backgrounds, between 2.06:1 and 3.11:1.

Two things that only surfaced by measuring:

- **A palette needs two shades, not one.** No single colour clears AA on both polarities: 4.5:1 against white caps relative luminance at 0.178, while 3:1 against the lightest dark grey demands at least 0.182. `Palette.brandColour` therefore takes `~dark`, and the CSS selects with `[color="dark"].rn-palette-*`.
- **The worst-case surface is not white.** Brand text sits on `gray-50`, `gray-100` *and* `gray-200`; contrast is lowest against whichever is nearest the text's own luminance. Calibrating against white overstated every ratio by about a point and left `.rn-value` failing at 3.6:1. The surfaces in `Palette.lightSurface` / `darkSurface` are `gray-200` in each polarity, measured from Spectrum rather than assumed.

**Spectrum's own accent tokens are deliberately not overridden.** Changing a component's background without the label colour Spectrum pairs with it is how contrast regressions get introduced; the palette is applied to the app's own surfaces instead.

**Reflow (§1.4.10)** is verified by constraining the document to 320 px and measuring `document.body.scrollWidth`, because Chrome will not size a window below about 628 px. A table is exempt from reflowing but not from staying inside the page, so `Render.res` wraps each one in a scrollable, keyboard-reachable region — wrapped rather than given `display: block`, which would make it scroll while dropping the row and column relationships a screen reader announces. That region carries an `aria-label`: an unnamed `role="region"` is worse than no role, since it announces a landmark it cannot describe.

**Labels name the control, not the format (§2.4.6).** The editor buttons read "Markdown editor" and "Block editor" rather than "Markdown" and "Blocks", and both panes are named regions. The test that used to assert `MarkdownEditor` was the untranslated string "Markdown" now asserts the opposite — that every language says more than the bare format name while still carrying the proper noun.

The rest is ordinary discipline, all verified in the running app: a visible focus ring at zero specificity so Spectrum's own conformant rings keep priority (§2.4.7), `scroll-margin-block` so a focused control in a scrolling pane does not come to rest under the toolbar (§2.4.11), accessible names on every icon-only control and an `aria-label` fallback on a `::range` written without a `legend` (§4.1.2), and a 24×24 CSS px floor on Spectrum's small controls, which sit exactly on it (§2.5.8).

## Security

The threat model is DOM XSS, and the defences are layered so that no single one is load-bearing.

**Unsafe hrefs are unrepresentable.** `SafeUrl.t` is abstract in `SafeUrl.resi`, so `parse` is the only way to construct one: rendering code takes a `t`, never a string. The parser strips ASCII control characters *before* reading the scheme, because browsers ignore them mid-scheme and `java\tscript:` navigates exactly like `javascript:` — that case is covered in `SafeUrl_test.res` and is the reason the normalisation exists.

**Rendered markdown is sanitised, and the type system says so.** `Sanitizer.trustedHtml` is abstract; the only way to get one is `toTrustedHtml`, which runs DOMPurify with `RETURN_TRUSTED_TYPE`, and `setInnerHtml` accepts nothing else. `Render.res` then re-checks every rendered link against `SafeUrl` and adds `rel="noopener noreferrer"` — DOMPurify already drops `javascript:`, but this holds user markdown to the same allowlist as the rest of the app.

**CSP with Trusted Types**, defined once in `vite.config.js` and emitted three ways: a `<meta>` tag in the built HTML, real headers from `vite preview`, and `public/_headers` for static hosts. `script-src` stays strict — no `unsafe-inline`, no `unsafe-eval`. `style-src` had to accept `unsafe-inline` when the editor landed: KaTeX sizes glyphs with style attributes, Mermaid ships a `<style>` inside its SVG, and CodeMirror injects its theme at runtime. None can be configured out of it. An inline *style* cannot execute script, so the exposure is CSS injection, not XSS.

Four things that will silently break if you change them without knowing why:

- **`sp-theme` assigns the literal `"<slot></slot>"` to `innerHTML`, and Mermaid builds its SVG the same way.** Under `require-trusted-types-for 'script'` these throw. `src/shell/TrustedTypes.res` installs a `default` policy with two tiers: an exact-match allowlist for constant strings, then DOMPurify for everything else. It is deliberately not a pass-through. When it *did* throw instead of sanitising, Mermaid marked its node `data-processed` and rendered nothing — with `suppressErrors: true` swallowing the cause.
- **Mermaid runs with `htmlLabels: false`.** Its default puts node labels in a `<foreignObject>`, whose content the sanitiser strips: the diagram draws correctly and every box comes out empty.
- **DOMPurify returns the `<body>`, and the HTML parser puts a leading `<style>` in the `<head>`.** So `<style>a{}</style>` sanitises to nothing while `<div></div><style>a{}</style>` keeps both — the position decides, which is a parser accident and not a rule anyone chose. `style` is in `ADD_TAGS` deliberately, for the one Mermaid ships inside its SVG, so the sanitiser was dropping exactly what it had been told to keep. `FORCE_BODY: true` is DOMPurify's own remedy: it prepends a throwaway element so the parser stays in body from the first token. Nothing is exempted from sanitising — a `<script>` is still stripped — things are only kept where they were written. What this cost is in the `::explore` section, and it is the failure mode of every library that builds a shadow root out of a template starting with `<style>`.
- **DOMPurify creates its own `dompurify` Trusted Types policy**, which the CSP names. Wrapping it in a second policy of ours was worse than redundant — DOMPurify assigns the *unsanitised* payload to innerHTML while parsing, so a missing policy makes `sanitize()` throw and the preview render nothing at all.
- **The service worker is registered by hand** in `src/shell/ServiceWorker.res`, with `injectRegister: false`. The plugin's injected script is a classic `<script>` that runs during parsing — before the module graph, and therefore before the Trusted Types policy exists.
- **Workbox's runtime is inlined (`inlineWorkboxRuntime: true`), because `importScripts` is a Trusted Types sink.** By default `generateSW` writes `importScripts("workbox-<hash>.js")` into `sw.js`, and a worker served with this CSP inherits `require-trusted-types-for 'script'`, under which that call throws `This document requires 'TrustedScriptURL' assignment`. The page's policy is no help: a worker is a separate global and has none of its own. The worker then never installs, so there is no offline app and no `navigateFallback` — and the page shows nothing wrong, because from its side registration merely never completes.
- **A font is never inlined**, which is why `build.assetsInlineLimit` is a function refusing `woff2/woff/ttf/otf/eot`. Vite inlines assets under 4 kB as `data:` URLs and `font-src 'self'` refuses those — a grant with no other reason to exist, since every font here is served from this origin. It caught exactly one file: KaTeX ships one face just small enough (`KaTeX_Size4`, the large delimiters), so under the real CSP big brackets and radicals fell back to a system font while every other KaTeX face loaded from its own file and looked right.

The CSP is **build-only**. Vite's dev server needs inline scripts and eval for HMR, so `bun run dev` gets the other security headers but no CSP — policy regressions only surface under `bun run preview`, and several of the bugs above appeared *only* there. If Spectrum renders unstyled, suspect the CSP before suspecting Spectrum, and check the console for `[security] default Trusted Types policy not installed`.

`vite preview` reads `vite.config.js` once at startup: after editing the policy, restart it, or the running server keeps serving the old header while the freshly built `<meta>` carries the new one. Both are enforced, and the intersection wins.

`frame-ancestors` is ignored in a `<meta>` CSP, so the meta variant filters it out and relies on `X-Frame-Options` plus the header form.

**The policy has THREE copies, and a test enforces all three.** `vite.config.js` is the source of truth; `public/_headers` is the copy a static host reads; the **`Caddyfile`** is the copy our own server reads, and is therefore the one that actually serves production. Drift is invisible to every local check, because `bun run preview` serves the header from the config and reads neither file — the `::python` tokens were missing from `_headers` for a while and every block would have died on exactly the deploys nobody tests. `SecurityPolicy_test` compares all three and makes drifting a red build.

**A stale copy in the `Caddyfile` cannot widen anything — it narrows.** The `<meta>` from the build and the server's header are both in force and the **intersection wins**, so a token the build has just granted is refused, while the console error quotes the meta tag, which is the copy that is *right*. That is how the Pirsch grant looked deployed and behaved as though it had never been made. The Caddyfile was the last copy kept by hand; a copy kept by hand is a copy that drifts, and the only fix that holds is to stop keeping it by hand.

## Files, and the two bars

**An app can also travel *inside* a link.** "Copy link" copies an address, and an address only opens something the reader already has — every app here lives in one browser. So sharing puts the document in the URL's *fragment*: `core/ShareLink` decides the shape (a version marker, and a ceiling past which a link is refused rather than truncated), `shell/SharePayload` gzips and base64url-encodes it, and `/s` is the route that unpacks one. The fragment rather than the path for three reasons that all hold: it never reaches a server, so a shared document is not in anybody's access log; a static host has nothing extra to route; and a long value belongs there. Opening a shared link goes through the same never-overwrite path as a file import, so a link lands as a copy when its id is taken. The import runs **once per payload** (a ref guards StrictMode's double mount) and leaves `/s` by `history.replaceState`: kept in history, a consumed share link imported another copy on every press of Back. The effect's deps include the fragment, because for `/s` the path alone is constant and two different links in a row would never re-trigger.

**A share can also be a short link**, `/s/<id>#k<key>`: the *encrypted* payload sits in PocketBase under the id, and the AES-GCM key rides in the fragment — never sent, so the server holds a blob it cannot read (verified: the stored payload contains no plaintext). `core/ShareLink` owns both forms and the two fragment markers (`1` payload, `k` key); `shell/ShareCrypto` seals the SharePayload string (one extra base64 layer, one seam — what decrypts is exactly what `decode` accepts); `shell/ShareServer` is two plain fetches, no SDK. Every failure — no server, expired id, wrong key — degrades: the dialog falls back to the long link, an expired id gets its own sentence ("ask for it again"), and a tampered blob fails GCM authentication rather than importing garbage.

**`Router.fragment` must be a function.** As a `@val` external it compiled to `let fragment = location.hash` — evaluated once, at module load — so a page opened at the gallery carried an empty fragment forever and every short link followed *in-app* read as truncated, while the same link opened cold worked. An external re-exported across modules materialises as a binding; anything time-varying has to be a call.

## Server

**Caddy runs the repo's `Caddyfile`, never `/etc/caddy/Caddyfile`.** The default file is not used and not written: the configuration of this system is the one that is versioned, reviewed and deployed, and there must be exactly one live copy of it — a second copy on the default path is one nobody can tell apart from the real one afterwards. Where systemd manages Caddy, `scripts/restart-services.sh` points the unit at the deployed file with a **drop-in** (`caddy.service.d/10-reactive.conf`), which survives a package upgrade of the unit and touches nothing in `/etc/caddy/`. `ExecStart=` has to be emptied before being reassigned: in systemd a second `ExecStart` *adds* to the first.

**A Caddy started by hand is invisible to systemd, and that is the ghost.** `caddy start` puts a process outside the unit; `systemctl restart caddy` then does not touch it, it goes on holding ports 80 and 443, the service "restarts" without being able to bind them, and what answers is still the old process with the old configuration. Nothing looks wrong from outside — and `pgrep -x caddy` finds it and mistakes it for the service that just came up. So the restart stops *every* Caddy — admin API, then systemd, then terminate what is left — before starting one.

**And "running" is not the question; "serving which configuration" is.** The two come apart in exactly the case that matters, which is how a stale CSP survived several deploys that all reported success. The restart therefore asks Caddy for a header over `--resolve … 127.0.0.1` and compares it against the CSP in the deployed `Caddyfile`, and a mismatch is a failed deploy. The CSP is the right probe: long, changed often, and if it is wrong it is not a detail — it is half the app's defences.

Three local services, all reached same-origin so `connect-src 'self'` holds for them: PocketBase as `/pb/*` (below), the open-data warehouse as `/od/*` — DuckDB + ETL under `data/`, started with `bun run od` on 127.0.0.1:8788; its databases and raw downloads are gitignored, the code and ETL are versioned — and the MCP server as `/mcp`, which is what the in-app assistant reads the directive language out of. That one stays on this origin deliberately: the model's endpoint is configurable and the tools' is not, so no setting and no document can point it elsewhere.

PocketBase, for two things: short share links, and shared spaces (multi-user sync, below). Share links are one collection (`shares`: `payload` ≤ 140000 chars, `lastUsed`), rules locked to create-and-view, and hooks in `pb/pb_hooks/` — every view *touches* `lastUsed` server-side (opening a link is what counts as use, and a client can neither skip nor forge it), and a nightly cron purges what nobody opened in **120 days**. Schema and hooks are versioned under `pb/`; the binary and its data are not — `bun run pb` downloads the pinned release into `.pocketbase/` and serves it on 127.0.0.1:8090.

The app reaches it as **`/pb/*` on its own origin**, so `connect-src 'self'` keeps holding: the Vite proxy in dev and preview, a host rewrite in production (`public/_redirects` has the commented line). No server, no `/pb` answer → sharing offers only the long serverless link; nothing else in the app touches the network at all.

## A directive is not finished without its documentation

**Adding or changing a directive is not done until the documentation follows, in the same piece of work.** There are two places and both are read by somebody: `doc/directives.md`, which the MCP server serves to the assistant, and `site/content/{it,en}/guida/`, which is the reference for whoever writes by hand. They drift silently and nothing notices — measured on 2026-08-16, `doc/` documented 57 of the 57 own directives and the site's guide **20**: every `ai-*`, every `ml-*`, every `od-*`, all seven `chart-*`, `map`, `geo`, `geocode`, `api-query`, `choose`, `dashboard`, `explore`. The model could write `::ml-forecast` and a person reading the site could not. It is the same failure as a hand-kept copy of the CSP or a catalogue nobody regenerates.

`scripts/test-guide.mjs` now makes it a red build: it reads the **compiled registry** — never a second list written by hand, which would be one more copy to keep in step — and asserts that every directive is named in `doc/` and in the guide of *both* languages. It runs inside `bun run test`. The search is by bare name rather than by `::name`, because a directive legitimately appears in an attribute table or a sentence; the price is that a passing mention counts as documented, so the test says the hole is not there, not that the page is good.

Attributes are never written from memory: they come out of the registry through the MCP `reactive_directives` tool, which is the same source the app reads. The guide's own pages are `sintassi`, `direttive`, `grafici`, `mappe`, `dati-esterni`, `assistente`, `apprendimento`, `componenti`, `editor-blocchi` — and the 92 Spectrum components are deliberately described as a set rather than listed, since listing them by hand would mean rewriting the page at every upgrade of the library.

## The MCP server

`mcp/server.mjs` (`bun run mcp`, port 8789) lets a model write and verify apps: guide from `doc/` served a section at a time, the directive catalogue, the examples (welcome/starter in seven languages, plus the task-shaped recipes under `mcp/examples/` — one file each, dropping a new `.md` there adds it with no code change, and the smoke test validates and analyzes every one), the open-data catalog (tables, columns and types from the `/od` service, so a model checks that `provincia` is really a column of `farmacie` before writing the SELECT — with an honest degraded answer when the service is away), an open-data *runner* (below), a validator, a data-flow analyzer, and a share-link builder — eight read-only tools over Streamable HTTP, plus the eight guide documents as MCP resources (`reactive://guide/<name>`) and two prompts (`build-app`, `review-app`) packaging the write-validate-analyze-deliver workflow. `reactive_validate` and `reactive_analyze` also return `structuredContent` beside the text. No auth because it custodies nothing; a per-address rate limit (`MCP_RATE`, default 120/min) bounds availability, and setting `MCP_TOKEN` turns on bearer auth for a deployment that leaves localhost. The one rule that matters when editing it: **every grammatical answer comes from importing the compiled core** (`DirectiveScan`, `DirectiveRegistry`, `DirectiveAttributes`, `ShareLink`, `SharePayload`) — never a second implementation that could drift from what the app actually reads. Validation recurses into container bodies the way the renderer does, and also flags the traps that validate but betray at runtime (field outside a form, `:value` with a bare key, hex colour read as a `#reference`, `::grid`, an overlay written `open`). `reactive_analyze` is the layer above grammar: the same recursion builds the document's data-flow graph — who writes each collection and each reactive key, who reads them, which ids are declared and pointed at — and reports the orphans validation cannot see: a view over a collection nothing writes, a `#ref` no source feeds, a form without a save, an engine's `into=` colliding with a form's path, an `editform` naming a form that does not exist. The read/write semantics of each directive live in the server's tables; the scanning, attribute parsing and `{#key}`/expression reference extraction are the compiled core's (`OdQuery.references`, `Expr.references`). A bare `editform` parses as `"true"` and the binder reads `"true"` as bare — the analyzer mirrors exactly that. **`reactive_od_query` runs the SELECT instead of reading its schema, and what it is really for is the emptiness that reads as success.** The catalogue answers "is there a column called `regione`"; only running the thing answers "does `regione` ever hold `'PUGLIA'`" — and it does not, it holds `'Puglia'`, which DuckDB compares case-sensitively. That one is not hypothetical: it shipped a whole regional dashboard whose every figure was blank, because a SELECT that names real columns, parses, runs and matches nothing is indistinguishable from a working one from everywhere except here. No new power is handed out — the service already parses each statement and refuses anything but a single SELECT, caps the rows and interrupts on a timeout, and any document in any browser can already query it; what is new is that the model can look before it writes, which is why step 3 of the workflow now says to run every SELECT, not merely to check its columns.

**Zero rows is the easy empty; the aggregate is the one that bites.** `sum()` over nothing is null and `count(*)` over nothing is 0, so `SELECT sum(popolazione), count(*)` with a WHERE matching nothing answers `{popolazione: null, comuni: 0}` — **one row**, reported as one row, read as a result. That is the exact shape of every dashboard headline, so the check that only looked for an empty result set would have passed the very query that caused the bug; it was written, and it did. Both shapes now get the same verdict and the same diagnosis, because both have the same cause, and the answer says outright that this is a broken query and must not be written into the document — a tool that hands back `null` politely is a tool that helps ship the failure.

`scripts/test-mcp.mjs` starts a real server and talks MCP to it; run it after touching either the server or the grammar it delegates to.

## The assistant

A chat in the app that writes apps: `AiPanel.res`, opened by the spark in the navbar and by the **opening box on the gallery**, which is where the invitation belongs — a button in a bar does not say that describing an app in a sentence is a way to make one. It is not `ChatPanel`: that one is the *people using an app* talking to each other and its messages are rows of that app's own collection; this one belongs to the browser, so its history is one value in IndexedDB and it is available in the gallery and beside an open app alike.

**The tools come from two places and the split is the design.** Everything grammatical — guide, catalogue, examples, validate, analyze, the share link — is the MCP server's, reached over `/mcp` on this app's own origin (proxy in dev and preview, rewrite in production, exactly like `/pb` and `/od`). That server already answers those questions by importing this app's compiled core, so a second implementation here could disagree with the app about what a directive means. What it cannot answer is anything about *this browser*, so four tools — `reactive_list_apps`, `reactive_read_app`, `reactive_create_app`, `reactive_edit_app` — are answered by the panel against `DocumentStore`. `core/AiTools.isLocal` is the only place that split is written down. No MCP server, no grammar: the panel says so in a banner rather than letting the model guess, because a guessed directive renders as its own source text.

**A run waits for the tool list; it does not take whatever the last render held.** The banner covers the case where the server is absent, and there was a second way in that it could not cover: a question typed in the gallery's opening box starts a run in the *same commit* that mounts the panel, so the mount's probe was still in flight and `AiAgent.run` was handed the four local tools and none of the grammar. The model then wrote a document with no directives in it — a plain markdown table — and apologised for a server that was running the whole time, which is exactly the failure the banner exists to prevent, arriving by the one door it does not watch. `ask` therefore starts the run inside `McpClient.tools()`, and the tools also live in a ref beside the state, because the delivery gate runs inside a closure older than the answer and would otherwise see no tools and let an unchecked document through. Probing per question rather than remembering the first answer is deliberate: it costs one small request, and it is what lets a server started after the app was opened be found without a reload. It surfaced from the video script, where the first take recorded the model apologising.

**Delivery checks for itself and refuses, twice over.** The tools' descriptions tell the model to validate first; the small models simply do not — the first app one wrote here was created *then* validated, which put a broken `::list` in the gallery. So `reactive_create_app` and `reactive_edit_app` run `reactive_validate` and write nothing when it complains, handing the report back. `core/AiPlan.validates` reads the report's leading `ok`, which is a seam between two programs and is asserted on both sides (`scripts/test-mcp.mjs` has the other half).

**And grammar is only half of it, so the gate runs `reactive_analyze` too.** The workflow had told the model to analyze since the day the tool existed, and an instruction nothing enforces is a suggestion - the same argument that made validation a gate, left unapplied to the layer above it. What it lets through is the worse failure, because it *renders*: the app opens, the pages are there, the form is there, and the list under it is empty for ever because nothing writes what it reads. Nobody finds that except by using the app; the analyzer finds it in a second. `AiPlan.connects` reads the `No orphans` marker - a marker rather than a count, because the count is in prose and the marker is stated - and anything else is a no, so an analyzer that did not answer cannot wave a document through. Grammar is checked first for the reason `Draft` complains about the type before the pattern: "this is not a directive" beats "this list has no writer", and a document that does not parse has no data flow worth reporting. The bar is known to be reachable - `scripts/test-mcp.mjs` already asserted every recipe is delivered with no orphans.

**And a third gate RUNS the open-data queries.** Grammar says the directive is written correctly; the flow says the collection has a writer; neither can say the SELECT that fills it returns anything — and a SELECT matching nothing renders an app of empty cards with no error anywhere, which is how a regional dashboard shipped blank. It is the one runtime failure checkable *without* running the app, because a SELECT is read-only and costs a request. `AiPlan.odQueries` collects only the queries runnable as written: one carrying `{#key}` selects what a reader will type, so there is no honest value to try in its place and a false verdict about a correct query is the worst kind. And `queryFails` blocks only on an EXPLICIT failure — the opposite of the other two gates, deliberately, because this one reaches a network service and a warehouse being briefly away must not make delivery impossible, the same decision as opening the gate when there is no documentation server at all. A refused delivery is also why `AiAgent.maxSteps` is sized for the long run rather than the ordinary one — at twelve a 35B model ran out of steps mid-recovery and then *said* it had delivered. It is **96**, and the ceiling costs more than it looks: a run's own messages are never compacted (`AiHistory` only touches what a run *inherits*), so every turn re-sends all the turns before it, and a run near the ceiling is what meets a small model's context window first.

**Creating and editing are different acts.** A new app is written and the person is handed a button to open it — nothing of theirs was at risk, and `core/AiPlan.create` goes through `AppFile.idFor`, so a taken id lands as a copy exactly as an imported file does. A rewrite of the **open** app is *proposed*: shown with what the model says it changed, applied only on the person's word, and forced back to that app's own id, because an assistant that changed `appId` while adding a button would move the app — collections, URL and all. Applying one bumps `docEpoch` in `App.res`, which re-keys the editor container: both editors are uncontrolled and read their value once, so without it the change is invisible in the pane it changed and BlockNote writes the old document back on the next keystroke.

**The provider is the user's own, and the endpoint decides everything.** `core/AiSettings` takes three strings; an https URL is a provider somewhere else and needs a key, http on the **loopback host** is a model on this machine and needs none. That second shape is what `connect-src 'self' https: http://localhost:* http://127.0.0.1:*` is for — a real widening of the policy, bounded to the one host a browser will not carry a request off the machine for. Any other http endpoint is refused in the settings form rather than by the policy, which would block it as a console error nobody is looking at; `http://[::1]` is refused too, because CSP's host grammar cannot express an IPv6 literal and the two must agree. With Ollama the settings offer the **installed models** (`shell/AiModels` reads `/api/tags`, marking the ones that cannot call tools) instead of a field where a versioned name is typed from memory.

**The wire is Chat Completions, streamed, by hand** (`shell/OpenAiClient`): the official SDK is written for a server and would add a megabyte. Three things there are load-bearing — no `temperature` and no token ceiling are sent, because the newer OpenAI models refuse the first and renamed the second and sending neither works everywhere; tool-call fragments are accumulated **by index**, because OpenAI streams a call across many deltas and Ollama sends it whole; and `reasoning` is not `content`, because a thinking model is silent in `content` for a minute at a time and showing its reasoning as the answer would be nonsense while dropping it looks broken.

**The loop knows nothing about apps** (`shell/AiAgent`): `dispatch` takes a name and the model's own argument string, which is what makes the MCP tools and the browser's own the same shape from inside it. The system prompt (`core/AiPrompt`) is prepended on every request rather than kept in the history, because it says which app is open and that changes while a conversation is still going.

**Clearing the conversation starts a new session, and a session is the wire.** The
panel's list is the readable half; `wire.current` is what the model is actually
replayed on the next question, so emptying the list alone would produce a panel that
looks new and answers as though nothing had been deleted. The hard case is clearing
*mid-run*: aborting the fetch is not enough, because an aborted run still **resolves**
- `OpenAiClient` turns `AbortError` into an empty failure - and its handler then
writes `outcome.history` back into the wire, commits the streamed text as a turn, and
`remember()`s the lot into IndexedDB. So every run carries the session number it was
started under, and each of its callbacks - `onText`, `onThinking`, `onCall`, the tools
probe and the end-of-run handler - does nothing once that number is stale. It is the
generation guard the Python binder and the open-data fetches already use, applied to a
conversation. `clear` also lowers `busy` and `thinking` itself, since the run that
would have lowered them belongs to the old session and will never report back.

**Stopping is not stalling.** `stalled` is "no error and never finished", which is
exactly what pressing Stop produces - so the panel used to answer a deliberate stop
with "the assistant stopped after too many steps, ask again more simply", blaming the
model for the person's own choice and telling them to rewrite a question that was
fine. A stop is now recorded when it is made and reported as nothing at all: what was
produced is already on screen.

**Storage is written from refs, never from state.** An effect that saved when a run ended also ran on mount, writing an empty conversation over the stored one while the asynchronous load of that same conversation was still in flight — and the run's callbacks outlive the render that made them anyway. A run that ends having said nothing at all says so (`AiNoAnswer`): the small local models call a tool, read a long answer and stop with an empty message, and a panel that stays silent about that looks broken rather than finished.

**How well this works is measured, not guessed.** `scripts/bench-assistant.mjs` runs the real loop — the app's own `AiPrompt`, `AiTools` and `AiPlan`, against the real MCP server — at four difficulties (a shopping list; expenses with a total and a filter; two pages with a chart and a reference; `ultra`, a four-page gym manager with three collections, relations, two charts, three aggregations and a calendar), and scores what comes back: did it deliver, does the app contain what was asked for, how many orphans, refusals, lookups. Every change to the prompt or the server's answers is a column moving. The findings that paid for themselves: a small model given rules but no *procedure* researches for ever, so `AiPrompt` opens with a numbered one ending in the tool call; a reference answer that does not say what to do next is where a 4B stops, so the MCP server's answers end with the next step; **a turn with no tool call and no text is not an answer** (the small thinking models spend the whole turn in the reasoning channel), so `AiAgent` nudges once — for a silent turn and for a document pasted into the chat (`appId:` in a no-tool reply) — retries one 5xx (Ollama's OpenAI-compat layer 500s when its tool-call parser meets a malformed call), and the delivery gate's refusal message escalates, because a refused small model rewrites from scratch and breaks something new each time. Two protocol findings matter more than any prompt edit: **Ollama's native `/api/chat` beats its OpenAI layer** — the parser 500s disappear and 27B/35B go to full scores (`BENCH_NATIVE=1`), which is why `OpenAiClient.complete` speaks native whenever `AiSettings.isLocal` says so (NDJSON stream, `thinking` as its own field, tool calls whole with object arguments re-serialised to keep one contract, tool results by `tool_name` — built by `OpenAiClient.toolMessage`, because the loop must not know there are two wires); and **constrained decoding (`BENCH_SCHEMA=1`) is a wash** — it helps a mid model occasionally, slows the big ones, and collapses reasoning models into answering without working. Nemotron-3-Ultra over plain tools: every level including ultra, 0 orphans.

**The key is in IndexedDB, which is same-origin storage**, so anything else on this origin can read it — a `::python` block in an imported document included, since a worker reaches the same database. No browser mechanism isolates it. That is why the local model is offered as a first-class choice and not as a curiosity: with Ollama there is no key to leak. The privacy policy states the rest — with a remote provider, the question, the whole conversation and the **document of the open app** go to that provider, while the apps' saved rows never do.

## Shared spaces

Multi-user sync of an app's dataset — document and collections — end-to-end encrypted with RBAC. **`doc/rbac.md` is the architecture document**; what follows is what will bite when editing.

**The three enforcement layers are not interchangeable.** Reading is cryptography (no epoch key, no plaintext — holds against the server itself); writing is the server (hooks check the author's role); anything finer is client-side and advisory. Every feature must state which layer carries it before it is promised. Revocation cannot un-read the past; it rotates the epoch key so the future is sealed.

**Accounts are pseudonyms.** `users` has no email requirement, no list rule, and a self-only view rule — there is deliberately no user directory, which is why a member's public key and display name are copied onto the *membership* record at join. Losing the password without the recovery code loses the shared spaces, by design; there is no reset that is not a backdoor.

**The rule pitfall the hooks exist for**: `members_via_space.user ?= @request.auth.id && members_via_space.role != "reader"` passes when *any* row matches each condition — a reader passes while somebody else is an editor. Binding user and role to the same row needs a query, so member-create (invite validity, single-use burn, owner bootstrap) and change-create (author's own role) are hooks in `pb/pb_hooks/spaces.pb.js`. Related trap: `spaces` is visible to members only, so joining must create the membership **before** reading the space — the other order 404s for exactly the person joining.

**The engine is a lazy 4 MB.** `SyncEngine` statically imports `AutomergeImpl` (Automerge slim + 3.9 MB wasm, excluded from precache by the `**/*.wasm` globIgnore); nothing in the main graph may import either statically. `shell/SpaceSync` is the doorway — every reference is a dynamic `import()`, and "is this app linked" is answered from `SpaceStore` (IndexedDB) so the common unlinked case costs one read.

**One order is correct.** Per app, one serial promise chain; each cycle applies remote changes, flushes the queue, *then* diffs local state into the doc. Reversed, a remotely deleted row still in the local store reads as a local addition and resurrects. The engine hears local writes via the `rn:collection-write` event `CollectionStore` dispatches (one hook catches every writer), guards against its own echo with an `applying` flag, and announces remote arrivals as `rn:data` — the event the binder already listens for.

**Ids are translated at the engine's boundary.** The space carries the canonical `appId`; locally the app may live under another id, because every browser already has a `welcome` — the collision is the common case. What syncs carries the canonical id, what lands locally carries the local one, so a local rename stays local and joining lands as a neighbour instead of refusing or overwriting.

**A reader's edits stay local by design**: they merge with what arrives and are never pushed (the server would 403 the append anyway). Remote document edits reach the editor only while it is closed — reseeding the uncontrolled editor mid-edit would be worse than showing the merge one save later.

**The share sheet is the platform's, where there is one.** `navigator.share` lists the apps installed on that device — mail, messages, whatever social apps are there — and tells this app nothing about which. Hard-coding five service buttons would be a guess about the reader plus five third-party URLs baked into a page that otherwise talks to nobody. Where there is no sheet, the dialog offers the link itself and a `mailto:` draft, which is the same act with two more clicks.

**An app leaves as the document it is** — plain Markdown, frontmatter and all, saved as `<appId>.md`. Not a wrapper and not JSON with the source inside a string: the source *is* the app, so a file someone opens in any editor is one they can read, change and bring back, and one a repository can diff. It is read from storage rather than from the editor's `source`, so what lands on disk is what the app is, not the keystroke that has not been saved yet.

**An app can also arrive from the published catalogue.** `/c/<id>` names an app and the app goes and fetches it — which is the only shape that works at any size, because a share link carries the document *inside* the address and stops at 8000 characters of payload (`soldi-territorio` is 12943, legitimately). The catalogue is reached as `/catalog/*` on the app's OWN origin — Vite proxy in dev and preview, Caddy in production — so `connect-src 'self'` keeps holding, no CORS is involved, and no document or setting can point the app at a catalogue of somebody else's choosing. The site publishes the documents and an index with `site/scripts/app-links.mjs`; the gallery reads that index and offers only what this browser does not already have, because offering what you have would be offering a copy. Two failures, two sentences: an id the catalogue does not publish is a wrong link, and nothing arriving at all is the connection — telling somebody to check their network when the link is simply wrong sends them looking in the wrong place.

**An app already here can be brought up to the published version, and it is the one place where a document is overwritten.** Offering only what is absent left the other half of the question unanswered: an app installed months ago stayed as it was for ever, and the only way to take a version released since was to delete it and fetch it again — which is precisely the operation nobody dares perform, because deleting an app deletes its data with it. `core/CatalogUpdate` compares the version in the frontmatter against the one the index now carries (`site/scripts/app-links.mjs` writes it; it already had the document in hand). Two rules keep it from overstating: an update is offered only when **both** versions are written — a document declaring none is claiming nothing, and announcing an update against the empty string would invent a fact — and only when the published one is **strictly newer**, so a catalogue mid-rollback does not invite anyone to install backwards. The comparison goes through `Numeric`, not `Int.fromString`: that one reads a numeric *prefix*, so `1.0-beta` and `1.0-alpha` both come back as zero and two different versions compare equal — the same trap the sorts and the aggregations already went through once.

**Both catalogue reads are made with `cache: "no-cache"`, and without it the whole mechanism above is decorative.** The site serves the index and the documents with an `ETag` and a `Last-Modified` and *no* `Cache-Control`, and a browser given no directive applies its own heuristic freshness — a fraction of the age since the file last changed — and reuses what it holds **without asking**. So an app published minutes ago stays invisible for hours: the gallery offers no update, because the index it read still carries the old version, and `/c/<id>` installs the copy the cache kept. It is measured, not deduced — against a catalogue serving `max-age=3600`, the app made **zero** requests after the first load and never noticed a new version; with the flag it asks every time and the offer appears. `no-cache` is not `no-store`: the copy is kept and the validators travel, so an unchanged 166 kB document costs a 304. The `Caddyfile` says the same thing in a `header Cache-Control "no-cache"` on `/catalog/*`, and both copies are wanted — the client one holds wherever the catalogue is served from, and the catalogue is reached through a proxy to another host whose headers are one deploy further away than that line.

**And the catalogue is a generated copy, so it drifts.** `site/static/app/*.md` and `site/static/app/index.json` are written by `bun site/scripts/app-links.mjs` (which needs `bun run mcp` up, and validates each document on the way through: `reactive_app_link` calls `validated()` *before* the size check, so "too big for a link" is only ever said about a document that passed). Nothing else regenerates them — **`deploy.sh` builds the site but does not run that script** — so a source edited and deployed publishes the *previous* version, silently and on both sides. It had already happened: `scuola-in-cifre` sat in the catalogue at 3.0 while its source was at 4.0, a whole major, in production too.

Everything else that brings a document in files it as a copy; this replaces, because the reader asked exactly that and filing a copy would answer a different question and leave two cards with one name. So it is confirmed in a modal that names both versions and says what happens to the data — **the rows are not in the document and are not touched**, which is true and is the sentence somebody with six months of data needs *before* pressing. Applying one bumps `docEpoch`, for the reason the assistant's rewrite does: both editors are uncontrolled and read their value once. A fetch that fails leaves the app exactly as it was and says so — half an update is the one outcome there is no way back from.

**An import never overwrites.** A file whose `appId` is already here lands as a *copy* under a free id: a replaced app cannot be recovered and a duplicate can simply be deleted. `AppFile.idFor` makes that decision — declared id when free, `AppId.unique` when not, the title's slug when the file declares nothing — and everything goes through `AppId.isValid`, because an `appId` in a file arrives from outside exactly like one in a URL. The document is then written with the id it was actually stored under, so the frontmatter, the storage key and the URL cannot disagree.

The rows are **not** in the file. A document is what the author wrote; the rows are what its readers produced, they can be far larger, and an app you share must not quietly replace the recipient's data with yours. Data is backed up separately, from the data panel.

`FileTransfer` uses an `<a download>` and an `<input type="file">` rather than the File System Access API: that API is Chromium-only, needs a permission prompt, and buys nothing when there is no handle worth keeping. A dismissed picker resolves to *nothing* rather than rejecting — it is the ordinary path, not an error.

**A collection also travels on its own, as CSV.** A backup is the whole app in the app's own shape and is for putting it back; `core/Csv` is one collection in a shape other things read, which is what the rows are usually wanted for eventually. Ids travel in their own column, so re-importing an export *updates* the rows it came from instead of doubling them, and a file without that column — the usual spreadsheet — gets fresh ids. The parser is hand-written because a comma inside quotes is a comma, which is the bug every CSV parser exists to avoid. The panel that writes them announces `rn:data` afterwards, because the preview is bound by `CollectionBinder` and there is no other way to tell it the rows moved under it.

**Duplicating an app copies the document and not the rows**, the same line a file draws: a copy is a new app to change, and duplicating a shopping list to start next week's should not hand you last week's shopping.

**The bars answered three questions and now answer two each.**: where am I (left), what can I do with *this app* (share, save, edit), and how do I want the *interface* (language, palette, polarity). Everything in the two right-hand groups is one icon button of the same kind, separated by a rule. What made it hard to scan before was three kinds of control for one kind of choice: two decorative glyphs floating beside the pickers and a switch carrying a text label. Sharing and saving moved here from the preview toolbar, which is now only about the pane and what it shows.

The navbar is where am I (left) and what can I do with *this app* (right). How the interface looks — language, palette, polarity — is in the **footer**: it is chosen once and then left alone, while everything in the navbar is about the app currently open, and a control you touch twice a year does not belong beside the ones you use every minute. Polarity is a switch there rather than a button, because dark is on or off and that is what a switch means.

Both bars are sticky, and so is the pane's toolbar. Side by side this changes nothing — the panes scroll inside a fixed layout — but below the breakpoint the *page* scrolls, and a bar that scrolls away takes its controls with it. The gallery's floating button reads `--rn-footer-height` to clear the footer; the custom property is declared on `.rn-page` and not on the footer, because a custom property inherits *down* the tree and the button is nowhere near the footer in the markup.

**`overflow: hidden` is a scroll container, and that is what broke every sticky bar on a handset.** A sticky element answers to its nearest scrolling ancestor, and `hidden` makes one — it simply never scrolls. The box holding the two panes is `overflow: hidden` so the fixed desktop layout cannot be pushed out of shape, so below the breakpoint the pane's toolbar, the page menu and the gallery's search box all stuck to *that box*, which rode up out of the window with the page: `position: sticky` in force, doing nothing, and no way to tell from the declaration. The mobile block therefore returns `.rn-panes` and `.rn-panes > main` to `overflow: visible`, alongside `.rn-preview` which was fixed first and alone.

**On a handset the footer drops its own name.** "ReactiveNET" and the version go (`.rn-footer-brand`, hidden in the mobile block); the interface controls and the legal link stay. The name is the navbar's wordmark two lines up, and the version is a diagnostic — something to read out when reporting a problem, not while using the app. What they cost is a second row in a bar that is *sticky*, and every row it takes is a row of the document. The legal link is not dropped with them: it is an obligation, and one nobody can reach is one that is not offered.

**The bars stack, and the offsets cannot be constants.** Below the breakpoint they read down the window — the app's bar, the pane's toolbar, the page menu — and each needs the height of what is above it, which CSS cannot measure. The navbar *wraps* at 320 px, where the controls drop under the wordmark and it goes from 45 px to 81 px, and 320 px is exactly the width §1.4.10 makes us hold: a hardcoded offset there leaves an overlap or a gap with the document sliding through it. `shell/BarMetrics` measures the bar with a `ResizeObserver` and publishes `--rn-navbar-height`; the stylesheet derives `--rn-bar-top` and `--rn-nav-top` from it. They are **custom properties rather than `top` declarations** because the base rules are written later in the file and a media query adds no specificity — an override in the mobile block would lose to source order and silently do nothing.

Two selectors in that block had already gone stale this way: `.rn-page > main` stopped matching the day the panes gained their wrapper, taking the stacked-pane `min-height` with it. A rule that matches nothing looks exactly like a rule that had no effect.

**An icon that changes names the destination, never the state**: the eye means "view this", the moon means "go dark". Naming the state instead makes every toggle in a bar ambiguous, because nothing tells the reader which convention any one of them follows.

## Storage

**The welcome app is reseeded when it is stale *and* untouched.** Seeding only when it was missing meant a browser that opened this once kept that day's welcome app for good, missing every directive added since; rewriting it unconditionally would throw away whatever the reader had changed in it. So the seeding records a fingerprint of what it wrote (`shell/WelcomeSeed`, `core/Digest`) and replaces only a copy that still matches — edit one line and it is yours from then on. A browser seeded before the fingerprint existed has none recorded, which counts as "leave it alone".

`core/Digest` is a polynomial hash with a deliberately small modulus: ReScript's `int` is JavaScript's 32-bit integer and `*` compiles to `Math.imul`, which *wraps*. A modulus near a billion overflowed on any real document and produced a negative fingerprint — one that changes when nothing did.

**IndexedDB only. `localStorage` and `sessionStorage` are not used anywhere in this project, by rule** — including for single small values like the theme preference. `src/shell/Idb.res` is the only storage API; both its operations swallow failures and resolve to "no value" rather than rejecting, so a blocked database never takes the app down.

**`Idb` opens the database without a version and creates the store on demand.** The obvious implementation — `open(name, 1)` with `onupgradeneeded` — is wrong: a database can already sit at that version with the store missing, from an upgrade that never completed or an older schema. `open()` then succeeds and every transaction fails with `NotFoundError`, which, because failures resolve to null here, is indistinguishable from "nothing was ever saved". That is exactly what happened on `localhost:5173`, where the persisted locale silently never came back. The current code detects the missing store and reopens one version higher to create it, repairing such a database in place.

Note that `localhost` origins are shared between projects: other apps on the same port will have their own `localStorage` entries visible in devtools. Those are not ours — this app writes none.

The async API propagates into the UI: a persisted value cannot be read during synchronous React state initialisation. The pattern is to seed state from a pure default and hydrate in an effect — `App.res` starts on the OS colour-scheme preference and overrides it once IndexedDB answers.

## Spectrum Web Components

`src/spectrum/Spectrum.res` wraps the Adobe Spectrum custom elements. **ReScript's JSX cannot express a hyphenated tag** — `<sp-button />` is not parseable, since `sp-button` is not an identifier — so each wrapper calls `React.createElement` with the tag name as a string and declares its own props record. That gives per-component type checking instead of an untyped `domProps` escape hatch. React 19 is what makes this work cleanly: it sets real properties on custom elements when one exists and falls back to attributes otherwise.

Gotchas encountered writing these:

- Do not name the props record `props` — `@react.component` generates a type by that name and they collide. They are called `attrs` here.
- `for` is a ReScript keyword; `FieldLabel` uses `@as("for") for_`.
- Loading a Spectrum module is what registers the element, so the imports are bare `%%raw` side-effect imports with nothing imported by name.

Theme is `system="spectrum-two"`, `scale="medium"`, with `color` driven by the `Theme` module.

## Conventions

**Write a `.resi` interface file for every `.res` file.** Two reasons: React Fast Refresh only works when a module exports components exclusively, and for core modules the interface is what makes types abstract (`SafeUrl.t`). Test modules are the exception — they export nothing anyway.

Component styles in use:

- `@react.component let make = () => ...` with a matching `.resi` (see `App.res`, `Navbar.res`).
- Custom-element wrappers built on `React.createElement` (see `Spectrum.res`).

Assets in `public/` are referenced by absolute URL (`<img src="/logo.svg" />`) — no import, no binding. Only assets that need bundler processing live under `src/` and use `@module` externals.

## Styling and icons

Tailwind v4 with **CSS-first configuration** — no `tailwind.config.js`. The `@theme` block in `src/index.css` holds the design tokens; the `rn-*` classes below it map Spectrum tokens onto elements Spectrum does not own.

`public/` holds three generated things and one written by hand: the icons (`bun run icons`), Pyodide's core (`bun run pyodide:assets`), `_redirects`, and `_headers` — that last one is the source of truth for a static host and is not generated by anything.

The brand mark lives in **`logo.svg` at the repo root**, the single source of truth. `bun run icons` (`scripts/generate-icons.mjs`, uses `sharp`) copies it into `public/` and rasterises `pwa-192.png`, `pwa-512.png`, `apple-touch-icon-180.png`, plus a maskable 512 built by centring the badge at 72% on a flat `#16161d` square — the flat colour matches the badge background so the rounded corners vanish under the launcher's mask. Everything in `public/` except `_headers` is generated; edit the root `logo.svg` and re-run the script. If the badge background colour changes, update `BADGE_BACKGROUND` in the script too.

Palette: ink `#16161d`, teal `#65c3c8`.

## The home page's clips

`bun run clips [nome…] [--publish]` (`scripts/record-clips.mjs`) records them by
driving the REAL app: Chrome headless over CDP — no puppeteer, because the Chrome
already installed does this and a second Chromium is 150 MB — and ffmpeg assembles
the `Page.screencastFrame` jpegs. The clips on the home page are the part of the page
that convinces, and `home.html` says in a comment that they are the product and not a
mockup; that promise is only cheap to keep if re-recording is one command.

Four things it does that are the whole design:

- **An app is seeded by writing its document straight into IndexedDB**, under the key
  `DocumentKey` produces — and the id it is stored under is the one its frontmatter
  declares, because at `/a/<id>` the app looks the document up by that id and a
  mismatch renders an empty editor. The seed then *reads back* what it wrote: a write
  that did not take would otherwise produce a clip of an empty app, which is exactly
  the sort of fake this script exists to avoid.
- **Nothing is published until you look at it.** Output goes to
  `site/static/clip/nuove/` and only `--publish` overwrites what is online. This rule
  was learnt the hard way, by overwriting four good clips with four bad ones on the
  first run.
- **A frame lasts as long as it was on screen, capped at 0.8 s.** The screencast emits
  only when the page changes, so an unbounded duration turns a Pyodide download into
  thirty seconds of still image.
- **The poster is the LAST frame**, not the first or the middle: it is the moment the
  clip existed to show. The first is a loading screen.

The steps of a clip read as a script (`goto`, `page`, `click`, `type`, `until`), and
`until` waits for a condition rather than guessing a duration. The Chrome profile is
deliberately NOT deleted between runs — it is where Pyodide and the wheels stay
cached, and a fresh profile makes the `orario` clip a four-minute wait.

There were four clips. `intro` was the Formazione page's video — the assistant asked
in one sentence, answering on a LOCAL model because the page under it promised the
data stayed on the body's own devices — and it went when that page did, on
2026-08-17, along with the `settleAi` and `emptyGallery` helpers only it used and the
per-clip `size` and `publishTo` options only it set. Every clip is 1280×720 into
`site/static/clip/` again. What is worth keeping from it, should an assistant clip
ever be wanted again: the settings go where the panel writes them (`ai.settings`, an
endpoint on the loopback host, no key), the gallery has to be emptied first because
the profile survives between takes and otherwise the app being asked for is already
on screen, and the last frame — which is the poster — belongs on the app as its
readers see it, not on a pane of markdown.

## The app cards' screenshots

`bun run shots [scheda…] [--publish]` (`scripts/record-shots.mjs`) rebuilds the figures
on the site's app cards the same way and for the same reason: they are the proof of
what the card claims, and they are the first thing to go stale — the app gains a page,
a panel is renamed, and the figure keeps showing last spring while the caption beside
it describes today. The app is driven for real: the document is seeded into IndexedDB,
the `::python` blocks are actually run, the open data actually fetched. The orario card
therefore costs a full generation — five seeding blocks, the solver, the check, the
monitor and the quality measures — because a screenshot of an empty grid would be a
picture of nothing.

The two scripts share `scripts/chrome-driver.mjs`: the CDP client, the steps and the
IndexedDB seeding are one implementation, since two copies drift and the person who
notices is whoever is looking at the site.

Two rules carry it:

- **Nothing is published until you look at it.** Output goes to `shots-nuovi/`, and only
  `--publish` overwrites `site/assets/img/app/` — the clips' rule, learnt by
  overwriting four good recordings with four bad ones.
- **The framing is declared by heading, not by pixels.** `reveal("I pesi")` brings that
  heading to the top; an offset in pixels would be right today and wrong at the first
  paragraph added above it, and nobody would notice without looking. For the same
  reason "is it finished" is asked of what the binders themselves put in the DOM — the
  Stop button of a running block, the ellipsis the open-data status carries only while
  it loads — rather than of a sentence in one language.

Captions are part of the figure. A regenerated screenshot that no longer shows what its
caption says is a broken card, so the two move together: `bun run shots` and then read
the captions in `site/content/{it,en}/app/…`.

## Versioning

`bun run build` advances the version before it builds, and semantic versioning is why only *part* of it is automatic. MAJOR and MINOR are claims about what changed — this breaks something, this adds something — and no script knows that: they stay a deliberate `bun run release minor`. PATCH only says "this is not the build you had before", which is a question a fingerprint of the sources can answer, so `scripts/version.mjs` answers it.

The fingerprint covers what actually ships — `src/`, `index.html`, `vite.config.js`, `public/_headers` — and deliberately **not** the compiled `.res.mjs`, which changes exactly when its `.res` does and would count the same edit twice. `.version-stamp.json` records the last fingerprint and is committed on purpose: without it a fresh clone would bump on its first build of an unchanged tree.

## The legal documents

`legal/it/` is the reference text and `legal/en/` its translation: privacy
policy, cookie policy, terms of service, accessibility statement, licences and
attributions, security policy, and the Article 28 data processing agreement.
Deliberately no training terms: `legal/README.md` records that the documents never
name courses, enrolments or the body that ran them, which is why removing the site's
Formazione section cost nothing here. `legal/README.md` says what has to be filled in — every
`{{PLACEHOLDER}}` — and where they get published on the Hugo site.

**They are not boilerplate: they are claims about this architecture, and a
change to the code can make one of them false.** No telemetry; data lives in
IndexedDB and nowhere else; short links are encrypted client-side and deleted
120 days after they were last opened; shared spaces are end-to-end encrypted, so
the provider holds ciphertext it cannot read; the only third-party hosts the app
ever contacts are OpenStreetMap's tiles, Nominatim, and jsDelivr — and each only
when a document asks for it. A privacy policy that says these things while the
code does otherwise is not a stale document, it is a false statement to users
and to public bodies.

So the documents are updated **in the same piece of work** as the change, in
both languages, bumping `version` and `updated` in the frontmatter. What should
trigger a review: a new host contacted by the client or the site, anything newly
stored or retained server-side, a change to a retention period or to the
encryption, a dependency added or removed (the table in the licences document),
a new open-data source (its licence and required attribution), a change to the
CSP or to the security measures.

Analytics is **Pirsch**, on the Hugo site and in the app: cookieless, no IP
retained, EU-hosted, which is what makes the absence of a consent banner
defensible. Two distinct `data-code`s, one per property. Both load the script
straight from `api.pirsch.io`, which in the app costs a token in the one
directive that had none: `script-src 'self' 'wasm-unsafe-eval'
https://api.pirsch.io`, in `vite.config.js` and `public/_headers`, which
`SecurityPolicy_test` keeps in step. It is the only third-party origin
`script-src` grants, and granting it hands that decision to Pirsch as well —
the trade bought using Pirsch's published snippet unmodified. The way back is
wired and unused: the `/pa/*` same-origin proxy (`vite.config.js`,
`public/_redirects`, `Caddyfile`, the treatment `/pb` and `/od` get), which a
snippet written `src="/pa/pa.js"` plus the three `data-*-endpoint` attributes
turns back on, letting the token come out. **Either way the privacy policy and
cookie policy say which it is**, so the two must move together: the sentence
"the browser contacts no third-party host" is true only under the proxy.

## Notes

Compiled `.res.mjs` files are intended to be **committed to git** — reviewing the emitted JS in diffs is the point. To opt out, delete them and add `src/**/*.res.mjs` to `.gitignore`.

ReScript 12 has the Core standard library built in, so `Int.toString`, `Array`, `Option`, `Result`, `RegExp` are available with no `@rescript/core` dependency (the README's mention of ReScript 11 + Core is stale, as is its ReScript 11 version claim).

**Vite 7 refuses to serve `package.json`.** `shell/BuildInfo` used to import the version straight from it, which worked until that version: the request 404s, the module graph breaks at that one edge, nothing mounts, and the console shows a bare 404 for a file no `<script>` ever asked for — a blank page with no error in it. The version now comes from a virtual module built in `vite.config.js`, which reads the file on every load, so it stays fresh in dev (which `define` would not: it reads once, at config load, and a server started before `scripts/version.mjs` bumped the number keeps showing the old one).

**A new `.res` file needs the dev server restarted.** Vite caches the module graph, and a page that once asked for a module which did not exist yet keeps a record saying so: the import resolves to `undefined`, and React reports it as "Element type is invalid" naming nothing at all. The component is fine; the server is stale.

After changing a dependency's major version, **clear `node_modules/.vite` and restart the dev server**. Vite serves pre-bundled dependencies from that cache and will keep handing out the copy it optimised against the old version — the React 19.2 upgrade above appeared to have no effect until the cache was dropped.

When testing the PWA locally, be aware that **a service worker from another project on the same localhost port will hijack the page** — service worker scope is per-origin, and the port is part of the origin. If `preview` shows an app that is not this one, use a different port rather than debugging the build.
