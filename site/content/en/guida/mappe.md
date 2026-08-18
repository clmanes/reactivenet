---
title: "Maps and coordinates"
description: "A collection drawn on a map, positions collected by whoever fills the form, and addresses resolved into coordinates."
weight: 22
translationKey: "mappe"
---

A map is **a view over a collection**, like a list or a table: a row is a
marker, and the directive's body is the popup template. What changes from the
other views is how a row says where it is.

The map engine is a chunk loaded only if the document has one.

## `::map` … `::/map`

```markdown
::map{path="reports" coords="position" height="26rem"}
**{kind}** — {street}
{notes}
::/map
```

| Attribute | |
| --- | --- |
| `path` | The collection |
| `coords` | The field holding **both coordinates in one string**, `"45.46, 9.18"` — the format `::geo` writes |
| `lat` / `lon` | The two fields, when the coordinates are two columns (`lat` and `lon` by default) |
| `geojson` | The field holding a GeoJSON geometry: each row becomes an **area** instead of a marker |
| `fill` | With `geojson`, the numeric field that colours the areas as blue quantiles |
| `center` | The initial centre, `"lat, lon"` |
| `zoom` | The initial zoom, 0 (the world) to 19 (the street) |
| `height` | A CSS height; without it, `24rem` |
| `tiles` | A different basemap: an https URL with the `{z}/{x}/{y}` placeholders |
| `attribution` | The credit line that tile provider requires |

The popup is a **row template** like `::list`'s: `{field}` is replaced by the
value, and the value arrives as **text, never as markup** — a row containing
`<script>` shows those characters.

A row without valid coordinates simply has no marker. It is not an error and
stops nothing: in a freshly imported collection half the addresses have not been
resolved yet, and that is normal.

### The view follows the markers, until you move it

Without `center`, the map frames itself on the markers it has. It keeps doing so
as the rows change — a report is added and the map widens — **until the reader's
first gesture**. From then on the view is theirs and is never moved out from
under them, which is the thing that makes self-repositioning maps unbearable.

### Areas, and the choropleth

```markdown
::od-query{into="districts" sql="SELECT * FROM istat_sezioni WHERE codice_istat = '{#town}'"}

::map{path="districts" geojson="geojson" fill="population"}
**{district}** — {population} residents
::/map
```

With `geojson` each row is a polygon instead of a marker, and `fill` colours it
by a numeric field: the scale is by **quantile**, not linear, so a
long-tailed distribution — which is how nearly all territorial data is shaped —
does not produce a map of one colour with three exceptions.

### The tiles

By default they are OpenStreetMap's, with the credit its licence requires. They
are the one reason the app's security policy grants `img-src https:`. A
different `tiles=` is accepted **only** if it is https and contains
`{z}/{x}/{y}`; otherwise it falls back to OpenStreetMap. Under a dark theme the
tiles are re-toned in CSS, because a blazing-white map inside a dark interface
is the only thing anyone can see in the room.

## `::geo` — the position of whoever is filling the form

```markdown
::form{path="reports"}
::input{field="kind" legend="Kind of report"}
::geo{field="position" legend="Where"}
::save{label="Report it"}
::/form
```

It is **a form field** with a button beside it: pressed, it asks the device for
its position and writes it into the field as `"lat, lon"` — exactly the format
`::map{coords}` reads. It takes `field`, `legend` and `form` (when the field
sits outside the form that owns it), like any other field.

The position is asked for **on a gesture**, never on its own when the page
opens.

## `::geocode` — from addresses to coordinates

```markdown
::geocode{path="suppliers" from="address" to="coords" label="Put them on the map"}
```

A button that resolves into coordinates the addresses already written in the
rows.

| Attribute | |
| --- | --- |
| `path` | The collection |
| `from` | The field holding the address |
| `to` | The field the coordinates land in; without it, `coords` |
| `value` | Single-address form: the address, or a `#key` holding one |
| `url` | Your own Nominatim `/search` endpoint instead of the public one |
| `label` | What the button says |

Three things make it usable on a real collection:

- It looks **only** at rows that have the address and do not have coordinates
  yet. Pressing it twice does not redo the work: it picks up where it left off.
- It does at most **50 per click**, one request a second, and writes row by row
  — so a run interrupted halfway keeps the answers it already got.
- It starts **on a gesture**, always.

The single-address form writes a reactive key instead of a row:

```markdown
::textfield[address]{label="Address"}
::geocode[point]{value="#address" label="Find it"}
::map{path="poi" center="#point" zoom="16"}
::/map
```

### Two resolvers, the local one first

An Italian address is looked up in **ANNCSU**, the national archive of street
numbers — twenty million of them, with coordinates — held by the open-data
service on the app's own origin. That answer is instant, unmetered, and **never
tells anybody what was searched for**. Only when nothing is found there does the
request go out to Nominatim, at its one-request-a-second policy.

It falls through for two honest reasons, and both are worth knowing: ANNCSU is
**Italy only**, and **2,402 of 7,890 comuni** have no coordinates in it at all.
An address abroad, or in one of those comuni, still resolves — just not from
here. Where there is no open-data service on the origin, every address goes to
Nominatim exactly as before.

Which of the two answered is visible in the network panel and nowhere else,
deliberately: a reader asking "where is this address" should get the same answer
either way.
