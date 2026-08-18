# Authoring an app

In order, from an empty gallery to something that stores data.

## 1. Make one

The first tile of the gallery makes a new app. It does not start empty: a new app is
already a form that saves a row, a list that reads it back, and the empty state in
between. The fastest way to learn the language is to change that.

The app opens in the editor at `/a/<id>/edit`, with the source on the left and the
running app on the right. It saves itself as you stop typing.

## 2. Name it

The `⌄` panel at the top of the block editor — or the frontmatter block at the top of
the Markdown source — is where the app's identity lives:

```markdown
---
appId: shopping
title: Shopping list
description: What to buy this week
icon: shopping-cart
lang: en
version: "1.0"
date: 2026-08-10
---
```

`icon` is a Spectrum workflow icon by name — the same set `::page{icon}` draws from —
and it marks the app on its card in the gallery and in the toolbar above it. A name
outside the set is refused rather than drawn as a gap, and an app with no icon gets
the default one.

`chat: true` adds a chat panel to the app — see [Chat](#chat) below.

Changing `appId` **moves** the app: its stored data comes with it and the URL
follows. That is the one field to think about before sharing a link.

## 3. Make something reactive

The smallest interesting thing: a control that writes, and something that reads.

```markdown
::slider[volume]{min="0" max="100" value="50" label-visibility="text"}

Volume is :value[v]{ref="#volume"}.
```

`volume` is where the slider writes. `#volume` reads it. That `#` is the whole rule —
see [`#ref` versus a bare id](language.md#ref-versus-a-bare-id).

## 4. Store something

A form, a save button and a list. Nothing repeats itself: a field inside a form does
not name the form, and the button does not name the path.

```markdown
::form{path="items"}
::input{field="what" legend="Item"}
::input{field="who" legend="For"}
::save{label="Add"}
::/form

::if-empty{path="items"}
Nothing on the list yet.
::/if-empty

::if-any{path="items"}
:count{path="items"} items:

::list{path="items" deletable editform}
**{what}** — {who} · {createdAt}
::/list
::/if-any
```

`deletable` gives every row a delete button, confirmed in a dialog. `editform` gives
it an edit button that fills the form above and turns *Add* into an update.

`{createdAt}` and `{updatedAt}` are there without being asked for, and are shown in
your own date format.

## 5. Or show it as a table

Once there are more rows than a list reads well, the same collection as a table —
with a search box, sortable headers and pages:

```markdown
::table{path="items" search page-size="10" deletable editform}
::column{field="what" label="Item"}
::column{field="who" label="For"}
::column{field="createdAt" label="Added"}
::/table
```

## 5b. Or as cards, a board, a calendar

The same rows, drawn differently — and the same attributes decide which rows:

```markdown
::cards{path="items" min="16rem" deletable editform}
**{what}** — {who}
::/cards

::board{path="items" group-by="status" columns="todo,doing,done" editform}
**{what}**
::/board

::calendar{path="items" from="due" to="until"}
{what}
::/calendar
```

Dragging a card between the board's columns **writes** that field on that row. A row
with both dates is one bar across the days between them.

## 6. Summarise it

```markdown
Spent so far: :sum{path="items" field="price" decimals="2"}
Typical:      :median{path="items" field="price" decimals="2"}
```

And, for something that follows the form as it is typed rather than what is stored:

```markdown
With VAT: :calc{expr="#price * #qty * 1.22" decimals="2"}
```

## 6b. Read open data

Three directives fetch from the open-data service into an ordinary collection —
which is the whole trick: everything above draws fetched rows exactly as it
draws saved ones.

```markdown
::textfield[comune]{value="TAORMINA"}

::od-query{into="farmacie" sql="SELECT nome, indirizzo FROM farmacie WHERE comune = '{#comune}' LIMIT 8"}

::list{path="farmacie"}
**{nome}** — {indirizzo}
::/list
```

`{#comune}` binds the reactive key as a **prepared parameter** — never text
pasted into the SQL — and the query re-runs by itself when the key changes.
`::od-datasets{into="catalogo"}` lists the catalogue, and
`::od-search{into="risultati" placeholder="…"}` is a search box whose results
land in a collection too. A status line under each says how many rows arrived;
when the service is unreachable it shows the last rows received, and says so.

## 7. Split it into pages

Once the document is longer than a screen:

```markdown
::page{title="Add" icon="add"}
…the form…
::/page

::page{title="List" icon="view-list"}
…the list…
::/page
```

A menu appears from the second page onwards.

## Two editors

The toolbar above the left pane switches between them, and only one is ever mounted.

**Markdown** is the source, with completion: type `::` for directives, `{` for that
component's attributes, `="` for the values an attribute allows.

**Blocks** is a Notion-style editor where each directive is a block with its
attributes as fields, created from the slash menu and nested by indentation.

Its markdown conversion is **lossy in both directions** — that is inherent to the
block editor, not a bug. Anything without a block equivalent, `$$` display maths in
particular, comes back as a plain paragraph. Do the maths-heavy editing in Markdown.

## Chat

An app whose frontmatter says `chat: true` gets a speech-bubble button in the
toolbar above it, opening a panel where the people using the app talk to each
other. Messages are signed with the sender's account username — or shown as a
guest's without one — and stamped with when they were said, in the reader's own
date format.

A message can also carry a **file**, attached with the paperclip: an image shows
itself in the thread, anything else becomes a download link named after the file.
The whole file travels inside the message's row as a `data:` URL, so it syncs
end-to-end encrypted like the words around it — which is also why an attachment
is capped at 700 kB: a bigger one would not fit inside a single sync change.

There is deliberately no chat server. The messages are rows of an ordinary
collection named `chat`, and everything follows from that:

- They store, back up and export like any other collection, and the data panel
  shows them under `chat`.
- When the app is **synced** (see below), the conversation syncs with it —
  end-to-end encrypted, live, between the members of the space, exactly as every
  other collection does. That is what makes it a chat between users rather than a
  notepad: link the app to a space and every member's panel shows the same thread.
- A read-only member's messages stay on their own device — the server refuses
  their writes, which is what read-only means — so a reader can take notes in the
  panel but cannot be heard.
- A document can render the same conversation itself: `::list{path="chat"}` shows
  the rows any way it likes, because the collection is not special.

The `chat` collection name is reserved by convention only: an app that already
stores something else under `chat` will find those rows in the panel.

## Sharing, saving, and getting it back

| | |
| --- | --- |
| **Copy link** | The app's URL. Sending it is sending the app — to anyone who can reach the same page. |
| **Save to a file** | The document as a `.md` file: frontmatter and all, readable and editable anywhere, and storable in a repository. |
| **Share** | A short link when the server answers — the document travels **encrypted**, the key stays in the link's fragment, and the server can read none of it; it expires 120 days after its last opening. Otherwise the full link, with the whole app compressed into the fragment: longer, but it needs no server at all. Either way, whoever opens it gets a copy. |
| **Open from a file** | Brings one back. An import never overwrites: a file whose `appId` is already here lands as a copy. |
| **Sync** | The circular arrows in the navbar. Everything above hands over a *copy*; this keeps everyone's copy the same — the app's data (and its document) sync, end-to-end encrypted, with the people you invite by link, each as editor or read-only. It needs an account (a username and a password, nothing else) and is the one feature that does. See [rbac.md](rbac.md). |
| **Duplicate** | On the card in the gallery: a copy under a free id, opened in the editor. The document only — the rows belong to the app that collected them. |

A shared link carries the document and **not the rows** — the same line a file draws,
and the dialog says so before you send it. The fragment is never sent to a server, so
nobody's app ends up in an access log; a link past what a URL can carry is refused
with a sentence rather than truncated.

The file is the *document*, not the data. Rows are backed up separately, from the
data panel in the preview toolbar — and one collection at a time as CSV, which is how
they leave for a spreadsheet and come back from one. See [Storage](storage.md).

## On a phone

A handset cannot edit. Below the two-pane breakpoint the editing control disappears
*and* `/a/<id>/edit` is rewritten to `/a/<id>`: the editors are desktop surfaces,
and offering them on half a phone screen is worse than not offering them. Reading and
using an app work everywhere.
