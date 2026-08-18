---
title: "Licences and attributions"
translationKey: "legal-licences"
description: "Who owns what: the ReactiveNET software, the third-party components it is built from, and the open-data sources whose licences require them to be credited."
version: "1.2"
updated: "2026-08-18"
---

# Licences and attributions

## 1. The ReactiveNET software

ReactiveNET is the work of **Cosimo Luigi Manes**, a natural person, who is its
author and the owner of the copyright in it: **© Cosimo Luigi Manes**. That
holds for the source code, the documentation and the project's editorial
content, save for the third-party components listed in § 3.

The ReactiveNET source code is **free software**, released under the **Apache
License 2.0**: anyone may use, copy, modify and redistribute it, including
commercially, on the licence's conditions — keeping the copyright notices and
the NOTICE file, and stating the changes made. The licence includes an express
patent grant and grants no rights over the trade marks (§ 2). The full text is
in the `LICENSE` file of the public repository.

The documentation, guides, examples, articles and other editorial content
published on `reactivenet.ai` are, by contrast, released under the **Creative
Commons Attribution 4.0 International licence (CC BY 4.0)**: they may be
reproduced, adapted and reused, including commercially, with attribution to the
author.

## 2. Trade marks

The names **«ReactiveNET»** and **«Reactive»**, the logo and the identifying
graphic elements belong to Cosimo Luigi Manes. A licence over the software,
where granted, **is not a licence over the trade mark**: it does not permit
presenting a derived product as if it were ReactiveNET, nor using its name or
logo to promote something else. Descriptive use is permitted — saying that a
service is built with ReactiveNET — provided it does not cause confusion as to
origin.

## 3. Third-party components

The application incorporates third-party free software, each with its own
licence and copyright notices, which remain with their respective owners. The
main ones:

| Component | Licence | Role |
| --- | --- | --- |
| React, React DOM | MIT | user interface |
| ReScript | LGPL-3.0-or-later AND MIT | compiler and standard library |
| Adobe Spectrum Web Components | Apache-2.0 | interface components and icons |
| CodeMirror | MIT | Markdown editor |
| BlockNote | MPL-2.0 | block editor |
| Automerge | MIT | shared-space synchronisation |
| DOMPurify | MPL-2.0 OR Apache-2.0 | sanitisation of generated HTML |
| marked | MIT | Markdown parsing |
| KaTeX | MIT | mathematics |
| Mermaid | MIT | diagrams |
| Leaflet | BSD-2-Clause | maps |
| Chart.js | MIT | charts |
| Pyodide (CPython on WebAssembly) | MPL-2.0 | running Python in the browser |
| scikit-learn, statsmodels (via Pyodide) | BSD-3-Clause | the machine-learning directives |
| Perspective (FINOS) | Apache-2.0 | the `::explore` exploratory view |
| DuckDB WASM and DuckDB | MIT | open-data service |
| SheetJS (xlsx) | Apache-2.0 | reading and writing spreadsheets |
| Tailwind CSS, Vite | MIT | styling and build |
| PocketBase | MIT | sharing and synchronisation service |
| Space Grotesk | SIL Open Font License 1.1 | website typeface |

The complete list, with exact versions, is in the repository's `package.json`
and in the packages themselves; the full licence texts accompany each package in
`node_modules`. The MPL-2.0 and LGPL licences apply to the files of those
projects and remain in force: nothing stated here modifies them.

## 4. Maps

Maps use the map tiles and geocoding service of the **OpenStreetMap
Foundation**. OpenStreetMap data is licensed under the **Open Data Commons Open
Database License (ODbL) 1.0**, the cartography under CC BY-SA 2.0.

Attribution is **mandatory** and is rendered by every map in the application:

> © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors

An author replacing the tile service with another must state the attribution
that provider requires, through the `attribution` attribute of the `::map`
directive. Use of OpenStreetMap's public services is subject to their Tile Usage
Policy: they are meant for modest traffic, and heavy use calls for one's own
tile provider.

## 5. Open data: sources and licences

The open-data service exposes **third parties' public data**, reloaded
periodically and sometimes transformed (joins, aggregations, normalisation of
ISTAT codes). The bodies publishing the data remain its owners; each licence
carries an attribution requirement that also binds **anyone republishing that
data through an app built with ReactiveNET**.

| Source | Licence |
| --- | --- |
| ISTAT — population, territorial indicators, administrative boundaries and census geography, census variables, reported crimes, businesses, tourism, waste, road accidents, commuting, cause-of-death mortality, life expectancy, infant mortality | CC BY 4.0 |
| schema.gov.it — National Data Semantics Catalogue (controlled vocabularies) | NDC catalogue licence, free reuse with citation |
| Normattiva / dati.normattiva.it — national legislation | free reuse with citation of the source |
| ANAC — public contracts (CIG, awardees) | **CC BY-SA 4.0** |
| MIMIT — fuel price observatory (stations and prices) | IODL 2.0 |
| Ministry of Education and Merit — school registry, enrolments, staff, school buildings, early leaving | IODL 2.0 |
| INVALSI — assessment results | CC BY 4.0 IT |
| Ministry of Health — pharmacies and para-pharmacies, health authorities and the municipalities they cover, hospitals and beds, staff and medical equipment, family clinics, mental-health and addiction services, hospital discharge records (SDO), ward activity | IODL 2.0 |
| AGENAS — National Outcomes Programme (PNE) | CC BY 4.0 |
| Treasury (MEF) — SIOPE, public bodies' receipts and payments | CC BY 4.0 |
| Treasury (MEF) — Public Administration property register | CC BY 4.0 |
| ISPRA — land take | CC BY 4.0 |
| Civil Protection Department — seismic classification of municipalities | CC BY 4.0 |
| Revenue Agency — ANNCSU, national register of street numbers and urban roads | CC BY 4.0 |
| Ministry of Culture — ArCo, cultural heritage knowledge graph | CC BY 4.0 |
| Shared-mobility operators — GBFS feeds published by each service | under the terms published by each operator |
| MEF — income tax returns | CC BY 3.0 IT |
| ACI — vehicle fleet (Autoritratto) | CC BY 4.0 |
| INAIL — reported workplace injuries | CC BY 4.0 |
| IndicePA (AgID) — registry of public administrations | CC BY 4.0 |
| OpenCoesione, OpenCUP (DIPE) — public projects and investments | CC BY 4.0 |
| Ministry of Justice — DGSTAT, length of proceedings | CC BY 4.0 |
| Chamber of Deputies, Senate, Constitutional Court, Administrative Justice — institutional open data | free reuse under the conditions published by the respective portals |
| Ministry of the Interior — electoral data | free reuse under the published conditions |

The precise provenance of each table — source URL, licence, date last loaded —
is given in the data service's catalogue and in the header of the corresponding
loading script in the repository.

No source here contains named health records: those about people are already
aggregated at origin, and the cells the publishing body suppressed so that nobody
can be identified stay empty — they are not estimated, and never read as zeros.

**Two obligations that are easy to breach without noticing.**

1. **CC BY-SA (ANAC data)**: anyone redistributing that data, including in
   reworked form, must do so under the *same licence*. A table of public tenders
   republished inside an app remains CC BY-SA 4.0.
2. **No endorsement**: attribution does not permit implying that the owning body
   approves, endorses or has checked the app or the processing. The data is
   reworked by the provider and any reworking errors are the provider's, not the
   body's.

The provider does not warrant the accuracy, completeness or currency of the
data: for official use, verify at source.

## 6. User-created content

Apps written by users, their data and the content they enter remain **the
users'**. The provider acquires no rights over them, does not dispose of them
and holds no copy, save the encrypted blob it is unable to read in the cases
described in the privacy policy.

## 7. Reports

Anyone who believes content published by the provider infringes their rights may
write to info@reactivenet.ai stating the work, the right claimed and
the address of the content: the report receives a reply within 30 days and, if
well founded, the content is removed or corrected.

---

Version 1.2 — 18 August 2026. In the event of any discrepancy between the
Italian and English versions, the Italian version prevails.
