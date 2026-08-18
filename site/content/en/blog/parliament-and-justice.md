---
title: "Parliament and the courts, in open data: four new sources"
description: "Reactive's open data warehouse grows to 228 datasets: Chamber of Deputies bills and votes, Senate bills, Constitutional Court rulings since 1956, and rulings from Italy's Regional Administrative Courts and Council of State. Two new apps to explore them — Parliament by the numbers and Constitutional and administrative justice."
date: 2026-07-20
author: "Cosimo Luigi Manes"
translationKey: "parliament-and-justice"
cover: "/img/blog/parliament-and-justice.jpg"
coverAlt: "Ovid - New York - Seneca County Courthouse Complex - 'Three Bears,' is a historic courthouse complex"
coverAuthor: "Onasill - Bill Badzo - 149 Million Views - Thank Y"
coverAuthorUrl: "https://www.flickr.com/photos/7156765@N05"
coverSource: "https://www.flickr.com/photos/7156765@N05/51513431053"
coverLicense: "Public Domain Mark"
coverLicenseUrl: "https://creativecommons.org/publicdomain/mark/1.0/"
---

After municipal and territorial data, Reactive’s open data warehouse now opens up to the **legislative and judicial sphere**: how a law is made, who votes for it, and what judges say when that law is challenged. **Four new official sources**, all without an access key:

- the **Chamber of Deputies’ bills and electronic roll-call votes** (dati.camera.it), every Republic legislature since 1948;
- the **Senate’s bills**, with the latest known stage of their process and — once passed — the number and date of the resulting law (SenatoDellaRepubblica/OpenData);
- **Constitutional Court rulings** from 1956 to today, judgments and orders, full text included (dati.cortecostituzionale.it);
- **rulings from every Regional Administrative Court, the Council of State, and the CGA Sicilia** (OpenGA portal of Italian administrative justice, launched in 2024 with PNRR funding).

The warehouse now stands at **228 datasets**, and the semantic layer that describes them grows to **24 verified relationships**: Chamber votes join their bills, and Regional Court and Council of State rulings join their region.

## Two apps to see them at work

### 🏛️ Parliament by the numbers

Both chambers’ activity in one app. Pick a legislature and see the outcome of floor votes (how many passed, how many failed), browse the latest votes with the tally of votes for and against, search a bill by title. On the Senate side, bills with the latest known stage of their process — and the ones that became law, with a direct link to the resulting law.

### ⚖️ Constitutional and administrative justice

Constitutional Court rulings can be searched **in plain language**: describe the issue — «legitimate impediment», «regional autonomy» — and semantic search finds the relevant rulings without knowing their reference numbers. The same app also shows rulings from Regional Administrative Courts and the Council of State, filterable by region and searchable by subject: public litigation over tenders, competitions, urban planning.

```md
::od-search{into="ricerca" table="corte_costituzionale" placeholder="Describe the issue you're looking for…"}

::cards{path="ricerca" search="false"}
**{tipo} no. {numero}/{anno}** — {presidente}
{epigrafe}
[Official record]({url})
::/cards
```

Want to see everything on offer, with the measured relationships between tables? [Browse the dataset catalog](/en/data/) — or ask the AI assistant for an app that cross-references one of these datasets with the ones you already know.
