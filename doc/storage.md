# Storage

Everything an app knows lives in **one IndexedDB store in the reader's own browser**.
Nothing is sent anywhere: there is no account, no server and no request.

`localStorage` and `sessionStorage` are **not used anywhere in this project, by
rule** — including for single small values like the theme preference. `shell/Idb.res`
is the only storage API.

## The keys

| Key | |
| --- | --- |
| `doc/<appId>` | the app's document, as Markdown |
| `app/<appId>/<path>` | one collection of that app |
| `theme`, `palette`, `locale` | interface preferences |

An app's `appId` is therefore three things at once: the document key, the namespace
of its collections, and the addressable part of its URL. Because the last of those
means it arrives from outside, every id goes through `AppId.isValid` — a hash that is
not a valid id is not a route, so no other module has to wonder where the one it
holds came from.

## Failures resolve to "nothing"

Both `Idb` operations swallow failures and resolve to "no value" rather than
rejecting. A blocked database — private browsing, a full disk, a corrupt store —
shows an empty gallery, not an error page.

The consequence is that a persisted value cannot be read during synchronous React
state initialisation. The pattern everywhere is: seed state from a pure default, then
hydrate in an effect. The app starts on the OS colour-scheme preference and overrides
it once IndexedDB answers.

## The database is opened without a version

The obvious implementation — `open(name, 1)` with `onupgradeneeded` — is wrong. A
database can already sit at that version with the store *missing*, left by an upgrade
that never completed or by an older schema. `open()` then succeeds and every
transaction fails with `NotFoundError`, which — because failures resolve to null here
— is indistinguishable from "nothing was ever saved". `Idb` detects the missing store
and reopens one version higher to create it, repairing such a database in place.

## Deleting an app deletes its data

Leaving the collections behind would orphan them under a namespace nothing can reach
any more, and hand them to the next app that happens to take that id. That is why it
is confirmed in a **modal** rather than by a second click: a two-step button can only
repeat its own label, and this one needs a sentence saying the data goes too and that
it cannot be undone.

The same applies at the row level: deleting a row from a list is confirmed in a
dialog that names the row.

## Renaming moves everything

Changing `appId` in the editor calls `DocumentStore.rename`, which carries the
collections across to the new namespace and then removes the old keys. The URL
follows in the same step.

## Getting things out, and back

Two different things, deliberately separate.

**An app** — the navbar's *Save to a file* writes the document as `<appId>.md`:
frontmatter and all, plain Markdown, readable and editable in any editor and storable
in a repository. *Open from a file* brings one back. An import **never overwrites**:
a file whose `appId` is already here lands as a copy under a free id, because a
replaced app cannot be recovered and a duplicate can simply be deleted. The document
is rewritten with the id it was actually stored under, so the frontmatter, the
storage key and the URL cannot disagree.

**Its data** — the data panel in the preview toolbar backs up and restores an app's
collections as JSON. Restoring a backup that belongs to a different app is refused
outright rather than merged: mixing two apps' rows corrupts both.

The two are separate because they are different things with different lifetimes. A
document is what the author wrote; the rows are what its readers produced, they can
be far larger, and an app you share should not quietly replace the recipient's data
with yours.

## Time

What is **stored** is always ISO 8601 — `2026-08-10T13:10:34.324Z`. It sorts as text,
and it means the same moment in every time zone, so a backup taken in one and
restored in another still says what it said.

What is **shown** is whatever the reader's locale writes. `core/DateValue` decides,
strictly, which stored strings are dates at all; `shell/Clock` formats one. A value
that is not a date is left exactly as it was typed.

## A note on localhost

`localhost` origins are shared between projects: other apps served on the same port
have their own entries visible in devtools, and their service workers can hijack the
page. Those are not ours — this app writes no `localStorage` at all. If `preview`
shows something that is not this app, use a different port rather than debugging the
build.

## One collection at a time

The data panel writes a whole backup — every collection, in the app's own shape — and
also each collection on its own as **CSV**, which is what a spreadsheet reads. The two
are for different things: a backup is for putting an app back the way it was, a CSV is
for taking the rows somewhere else and bringing rows in from somewhere else.

Ids travel in their own column. A file that carries them updates the rows it names;
a file without them — the usual spreadsheet — is added as new rows, with ids minted
against the ones already stored. So exporting and importing the same file twice
changes nothing, and importing a colleague's list adds it.

## The welcome app, and when it comes back

It is written back when it is missing, and also when it is **stale and untouched**:
the seeding records a fingerprint of what it wrote and replaces only a copy that still
matches. Change one line of it and it is yours — it will never be overwritten again.
A browser seeded before the fingerprint existed has none recorded, which counts as
"leave it alone".
