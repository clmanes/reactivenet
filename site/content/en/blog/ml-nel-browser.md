---
title: "Machine learning lands in your apps: four directives, zero servers"
seotitle: "Machine learning in your apps, zero servers"
description: "Clustering, anomalies, regressions and correlations with scikit-learn in the browser — reactive: move a slider and the model recomputes. No servers."
date: 2026-07-18
author: "Cosimo Luigi Manes"
translationKey: "ml-nel-browser"
cover: "/img/blog/ml-nel-browser.jpg"
coverAlt: "Neural Network"
coverAuthor: "Kevin Rheese"
coverAuthorUrl: "https://www.flickr.com/photos/129440207@N08"
coverSource: "https://www.flickr.com/photos/129440207@N08/27929852485"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

A Reactive app already knew how to collect data, show it in tables, charts and maps, and let an AI answer questions about it. As of today it can also **do machine learning on it** — without writing code, without servers, without a single byte of data leaving the device.

## Four directives, one principle

The new `ml-*` family brings **scikit-learn into the browser** (via Pyodide, the same engine as the Python blocks). Like everything in Reactive, it’s a line of Markdown:

```markdown
::range[k]{min="2" max="8" value="4" legend="Numero di gruppi"}

::ml-cluster{data="comuni" features="reddito,eta,stranieri" k="#k" into="gruppi"}

::map{path="gruppi" geojson="geojson" fill="cluster"}
**{comune}** — gruppo {cluster}
::/map
```

Move the slider: the clustering **recomputes** and the map **recolors**. The results land in a normal collection (`into=`), so they work with any view — tables, charts, aggregations, even an AI summary.

- **`::ml-cluster`** — K-means grouping: municipalities, customers, sensor readings… similar rows end up in the same group, with a `cluster` column ready for a map or a filter.
- **`::ml-anomaly`** — anomaly detection (Isolation Forest): a 0-1 score per row, high = out of the ordinary. For finding the outlier among a thousand.
- **`::ml-predict`** — regression (linear or random forest): it learns from the rows that already have the value and **predicts** it for the others, with the R² in plain sight.
- **`::ml-correlate`** — correlation matrix: which fields move together.

The principle that governs them: **the executed code is a fixed template** — data and parameters never enter the code, the AI generates nothing at runtime, the same input always gives the same result. The very first run downloads scikit-learn (~60 MB, then cached) behind a click; from then on everything is automatic and reactive. And the computations stay **on your device**.

To try them out there’s a ready-made app in the catalog: **Municipalities lab** — pick a region, group its municipalities by income, age and foreign residents, find the ones that stand out, discover which indicators run together.

## A warehouse that grows to 15 fact tables

The open data service has grown quite a bit. Alongside fuel prices, ANAC tenders, population and the PA registry it has gained:

- **IRPEF incomes per municipality** (MEF) — average income, taxable income, brackets;
- **workplace injuries** (INAIL) — by province, including fatal cases;
- **pharmacies** (Ministry of Health) — geolocated, ready for the map;
- **state schools** (MIUR) — 50,000 of them, by municipality and level;
- ISTAT **socio-demographic indicators** — average age, ageing index, foreign residents;
- the tenders’ **awardees** (ANAC) — who wins the contracts: the circle administration → tender → winner is now closed;
- ISTAT **administrative boundaries** — the polygon of every municipality, province and region as GeoJSON: any per-municipality number becomes a **choropleth map** (the `::map` directive has learned `geojson=` and `fill=`).

## A warehouse that describes itself

Underneath there’s a less visible but deeper novelty: a **semantic layer**. Three metadata tables — the conceptual keys (with the URIs of the OntoPiA ontologies), the **formal relationships** between the tables, and the annotated columns — queryable like everything else. The distinctive part: every declared relationship is **verified against the real data on every update**, and the join’s coverage percentage lands in the table itself. “How do X and Y join?” is a SELECT.

You can touch all of this on the [Open data](/en/data/) page, rebuilt as a **live explorer**: the choropleth map of Italy (population, density, average income — click a region to drill down to its municipalities), the **navigable graph of relationships** between the tables, the catalog with previews and, for those who want to get their hands dirty, a read-only SQL playground.

As always: apps are Markdown, your data stays yours, and everything you’ve read here also works offline after the first load.
