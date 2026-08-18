---
title: "Three apps that put public data to work"
description: "Reactive's open data grows up: alongside the official vocabularies come the living facts — fuel prices refreshed every morning, over 2.6 million public tenders, population and the registry of public bodies. And three ready-to-use apps prove it: the cheapest fuel station near you, your town's tenders, the right law described in your own words."
date: 2026-07-18
author: "Cosimo Luigi Manes"
translationKey: "tre-app-open-data"
cover: "/img/blog/tre-app-open-data.jpg"
coverAlt: "Public Domain: Dead American Soldiers, WWII (NARA)"
coverAuthor: "pingnews.com"
coverAuthorUrl: "https://www.flickr.com/photos/39735679@N00"
coverSource: "https://www.flickr.com/photos/39735679@N00/441531286"
coverLicense: "Public Domain Mark"
coverLicenseUrl: "https://creativecommons.org/publicdomain/mark/1.0/"
---

A few weeks ago Reactive apps learned to read **Italian open data**: the official vocabularies — municipalities, provinces, ATECO codes, professions — and all state legislation since 1861. Those were mostly _dimensions_: stable reference tables that give names to codes.

Now come the **living facts**, the ones that change:

- the **fuel prices** of every Italian station, which the Ministry of Enterprise republishes **every morning** — with brand, town and coordinates;
- over **2.6 million public tenders** (ANAC’s CIG lots), with subject, amount, contracting authority and place of performance;
- **resident population** by municipality (ISTAT’s demographic balance), the denominator that makes per-capita comparisons meaningful;
- the **registry of public administrations** (IndicePA): each body’s kind, town, certified email, website and tax code.

And the best part is that these tables **talk to each other**: a tender knows the body’s tax code, the body knows its town, the town knows its population. Three different sources — ANAC, IndicePA, ISTAT — that join on their own.

## Three apps to see them at work

We’ve featured them on the home page, ready to open and use — not to build.

### ⛽ Fuel

Pick the fuel type and your province: see the ten stations where it costs least, in a table **and on a map**. The prices are official, refreshed this morning. The query behind it all is a single line:

```md
::od-query{into="stations" sql="SELECT i.bandiera AS brand, i.comune AS town, p.prezzo AS price, i.latitudine AS latitudine, i.longitudine AS longitudine
  FROM carb_prezzi p JOIN carb_impianti i USING (id_impianto)
  WHERE p.carburante = '{#fuel}' AND i.provincia = upper(trim('{#prov}')) AND p.self
  ORDER BY p.prezzo LIMIT 10"}

::map{path="stations" lat="latitudine" lon="longitudine"}
**{brand}** · {price} €/litre — {town}
::/map
```

`{#fuel}` and `{#prov}` are reactive values: change the type or the province and the list rewrites itself, with no reload.

### 🏛️ Public tenders in the open

Search public tenders **in plain language** — “school maintenance”, “vaccine supply” — and find the relevant lots even without knowing their codes. Then look at your town’s tenders, or who tenders the most by kind of body. This is where the three sources work together: semantic search on the tender’s subject, the tax code that leads to the registry, the town that leads to population.

### ⚖️ Find a law

“Parental leave”, “renovation tax break”: describe the topic and find the right law, with a link to the **consolidated text on Normattiva**. The search understands meaning, not just words — it covers the legislation of the Republic since 1946.

## How they’re really made

No trick: they are **Markdown documents**, like any Reactive app. You’ll find them in the catalog, in the new **Public data** section, and you can open them, read their source, duplicate and edit them. The read-only queries travel on their own to the data service; the last response stays cached, so the app works offline too. And as always: none of your data leaves the device.

Want to see everything on offer? [Browse the dataset catalog](/en/data/) — or ask the AI assistant for “an app with the cheapest fuel stations in my province”, and it writes the query for you.
