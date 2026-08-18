---
title: "Six new datasets: from elections to waste, from tourism to schools"
description: "Reactive's open data warehouse grows to 223 datasets: municipal recycling rates, general election results, businesses and employees, INVALSI test scores, and province-level crime and tourism. Three new or enriched apps to explore them, all joined on their own via the ISTAT code."
date: 2026-07-19
author: "Cosimo Luigi Manes"
translationKey: "six-new-datasets"
cover: "/img/blog/six-new-datasets.jpg"
coverAlt: "Opening the Data Vaults"
coverAuthor: "giulia.forsythe"
coverAuthorUrl: "https://www.flickr.com/photos/59217476@N00"
coverSource: "https://www.flickr.com/photos/59217476@N00/8126486040"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

Reactive’s open-data service keeps growing. Alongside the facts already available — IRPEF income, workplace injuries, pharmacies, schools, demographic indicators, public tenders — come **six new official datasets**, all downloadable without an access key and joined on their own to the rest of the warehouse via the municipality’s ISTAT code or the province code:

- **separate waste collection** by municipality (ISPRA — National Waste Register): total waste, separate collection and its rate, four years of history;
- **2022 general election results** by municipality (Ministry of the Interior): turnout and the top list;
- **businesses and employees** by municipality (ISTAT ASIA): active local units and average annual employees, five years of history;
- **INVALSI standardized test scores** by municipality (INVALSI): deliberately partial coverage — only municipalities above the minimum tested-student threshold, due to statistical secrecy;
- **crimes reported** by province (ISTAT): rate per 100,000 inhabitants, already normalized, by crime type;
- **tourist flows** by province (ISTAT): arrivals, overnight stays and the share of foreign tourism.

The semantic layer describing the warehouse grows with them: **22 relationships** between tables (up from 16), each verified on every update with a real measurement of the join coverage — not claims, numbers.

## Three apps to see them at work

### 🚨 Public safety

The crime picture, province by province: trends over the years, a comparison between theft, robbery, homicide and drug offences, and a map of Italy with the crime rate. The rate is already per 100,000 inhabitants — comparable between Milan and a small provincial capital without any further cross-referencing.

### 🏖️ Tourism

Arrivals and overnight stays in your province, the trend since 2019 (the pandemic crash and the recovery are obvious at a glance), the share of foreign tourism, and a map of overnight stays per inhabitant — where art cities and seaside destinations top the rest of the country by an order of magnitude.

### 🏘️ Your municipality in numbers, now richer

The app that builds a municipality’s portrait from just its ISTAT code gains four new pieces of information: separate waste collection, active businesses, election results and INVALSI score. The new cards only appear if the municipality has the data — INVALSI and election data don’t cover all 7,900 Italian municipalities, and the app handles that on its own:

```md
::od-query{into="waste" sql="SELECT percentuale_rd, anno FROM rifiuti
  WHERE codice_istat = '{#comune}' ORDER BY anno DESC LIMIT 1"}

::cards{path="waste" search="false"}
♻️ Separate waste collection **{percentuale_rd}%** (year {anno})
::/cards
```

If the query returns no rows, the card simply doesn’t appear. No condition to write by hand.

Want to see everything on offer, with the measured relationships between tables? [Browse the dataset catalog](/en/data/) — or ask the AI assistant for an app that cross-references one of these datasets with the ones you already know.
