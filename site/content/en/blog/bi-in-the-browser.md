---
title: "Your app becomes a BI tool: dashboards, SQL in the browser and natural-language questions"
description: "Eight new features turn every Reactive app into a small business-intelligence tool: cross-filtering between charts and tables, a full SQL engine (DuckDB) running in the browser, AI that translates questions into queries, connectors for worldwide public APIs, address geocoding, time-series forecasts and benchmarking with rank and percentile. All client-side, all in Markdown."
date: 2026-07-21
author: "Cosimo Luigi Manes"
translationKey: "bi-in-the-browser"
cover: "/img/blog/bi-in-the-browser.jpg"
coverAlt: "Google Analytics"
coverAuthor: "Negative Space"
coverAuthorUrl: "https://stocksnap.io/author/4440"
coverSource: "https://stocksnap.io/photo/google-analytics-89AZTB8E5H"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

A Reactive app could already collect data, show it in views and charts, map it, run machine learning on it and let an AI reason over it. What was missing was the signature gesture of real business-intelligence tools: **click a chart and watch everything else filter itself**. And, for those who want to go further, a real query engine. Both arrive today — plus six more features that complete the picture. As always: no server, no account, the data never leaves the device.

## Cross-filtering: `::dashboard`

Wrap charts and views on the same collection in one container:

```markdown
::dashboard{path="sales"}
::chart-bar{data="sales" x="region" y="amount"}

::table{path="sales" headers="Region,Channel,Amount"}
{region} | {channel} | {amount}
::/table
::/dashboard
```

Click a bar: the table narrows to that region, a chip at the top shows the active filter, and the chart **highlights** the selection by dimming the rest — without filtering itself, because the context must stay visible (the same choice Tableau and Power BI make). Click again: filter cleared. It works with tables, lists, cards, derived views and maps, and every chart in the dashboard is a different filter: one by region, one by channel.

## Real SQL, in the browser: `::sql`

For the analyses Markdown cannot express there is now a **full** SQL engine — DuckDB compiled to WebAssembly — running entirely in the browser. The app’s collections become tables, and you write SQL:

````markdown
::sql{data="clients,orders" into="revenue"}
```sql
SELECT c.name, sum(o.amount) AS total
FROM orders o JOIN clients c ON c.name = o.client
GROUP BY 1 ORDER BY 2 DESC
```
::/sql

::chart-bar{data="revenue" x="name" y="total"}
````

**JOINs across collections**, GROUP BY, window functions: the result is a collection like any other, so it goes straight into a table, a chart, a map. `{#key}` placeholders are reactive parameters — a slider that re-runs the query — and `read_parquet('https://…')` reads remote files in place: worldwide open data published as Parquet or CSV enters the app with no middleman service. Even attachments uploaded with `::file` can be queried with `read_csv('sales.csv')`. The engine (~10 MB) downloads once, on the first click of Run.

## Ask your data: `::ai-query`

The most requested feature of modern BI, in one line:

```markdown
::ai-query{data="expenses" into="answer"}
```

“How much did I spend on transport in June?”, “top 5 clients by revenue”: the model — in the browser, on Ollama or via API — neither sees the whole collection nor writes free-form code. It produces a **constrained query plan** (the allowed fields are a closed list: it cannot invent columns) executed locally. And if the app also uses `::sql`, it upgrades itself: the question becomes a real DuckDB SELECT — joins, dates, expressions — shown in the widget for transparency, falling back to the plan automatically if anything goes wrong.

## Open data beyond Italy: `::api-query`

Reactive’s data service covers Italy; the new REST connector covers the rest of the world. Exchange rates, weather, stocks, Eurostat — any public JSON API lands in a collection:

```markdown
::input[base]{value="EUR"}
::api-query{url="https://api.frankfurter.dev/v1/latest?base={#base}" into="rates" pick="rates" as="pairs"}

::chart-bar{data="rates" x="key" y="value"}
```

Change the base currency and the call re-runs by itself. `pick` descends into the JSON, and the common shapes become rows with no glue: even Open-Meteo’s columnar format zips itself into a time series ready for a chart.

## From addresses to the map: `::geocode`

Business data — clients, branches, points of sale — has addresses, not GPS. Now it takes one button:

```markdown
::geocode{path="clients" from="address" to="coords"}

::map{path="clients" coords="coords"}
**{name}** — {address}
::/map
```

It only geocodes the rows that don’t have coordinates yet (a second click picks up where it left off), respects the Nominatim policy — one request per second, never automatic — and `url=` points to a self-hosted instance, consistent with the privacy-first stance.

## Forecasts, rankings and percentiles

Three bricks that complete the analytical side:

- **`::ml-forecast`** — the time-series forecast that was missing next to `ml-predict`: a trend over income by year, population, accumulated prices. It writes the history with its fit plus the future rows, so `::chart-line{y="value,previsione"}` shows the series and its extension together.
- **`:rank`** and **`:percentile`** — benchmarking in one line: “this town is at the 12th percentile for income”, “3rd of 42”. Reactive twice: on the group’s data and on the compared value.

## Everything composes

The strength is not in the eight features taken one by one, but in the fact that they all speak the same language: a collection. `api-query` fetches the exchange rates, `::sql` joins them with your orders, the result lands in a `::dashboard` where one click filters the table, and `::ai-query` answers your questions — while `:rank` tells you where you stand. Each piece is one line of Markdown, and the whole app remains a text file you share with a link.

Try it now: [open the app](https://app.reactivenet.ai) or browse the [catalog](/en/app/) — the open data apps are already being updated with dashboards, benchmarks and forecasts.
