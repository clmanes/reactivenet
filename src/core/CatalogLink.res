// Pure. Where an app of the published catalogue is fetched from, and how it is
// addressed inside this app.
//
// A share link carries the whole document in the fragment, which works right up to
// the point where the document is bigger than an address — `soldi-territorio` is
// 12943 characters of payload against a ceiling of 8000, legitimately, because it is
// a large app. So the catalogue offers the other way round: the address names the
// app, `/c/<id>`, and the app goes and fetches the document itself. It is shorter,
// it is readable, and it costs the same whatever the document weighs.
//
// The site already publishes the documents at `/app/<id>.md` — `site/scripts/
// app-links.mjs` writes them — and an index of what is there beside them. The id in
// the URL is the document's own `appId`, so the three names an app has (the file,
// the catalogue entry, the address) are one name.
//
// The *origin* is deliberately not here: it is a constant of the build, chosen by
// `shell/CatalogServer` between the dev site and the published one, and nothing —
// no document, no setting — may move it. Same discipline as the MCP server: a
// configurable catalogue would be an app pointing at a host of somebody's choosing.

let segment = "c"

let path = "/" ++ segment

/** Where the document of an app lives, relative to the catalogue's origin. The id is
    the `appId`, which is also the filename the site publishes it under. */
let documentPath = id => "/app/" ++ id ++ ".md"

/** The list of what the catalogue holds: id, title, description and icon per app,
    written by the same script that publishes the documents. */
let indexPath = "/app/index.json"

/** The address that opens a catalogue app in this application. What the site's own
    «open in the platform» button points at. */
let of_ = (~origin, ~id) => origin ++ path ++ "/" ++ id
