---
title: "Italian public data, inside your apps"
description: "Reactive apps now query Italian open data — municipalities, ATECO codes, professions, all state legislation since 1861 — with one line of text."
date: 2026-07-15
author: "Cosimo Luigi Manes"
translationKey: "dati-open-nelle-app"
cover: "/img/blog/dati-open-nelle-app.jpg"
coverAlt: "Breviary, Initial 'B' with David playing the harp, and heraldic shield, Walters Manuscript W.83, fol. 7v"
coverAuthor: "Walters Art Museum Illuminated Manuscripts"
coverAuthorUrl: "https://www.flickr.com/photos/39699193@N03"
coverSource: "https://www.flickr.com/photos/39699193@N03/13923505863"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

Starting today, Reactive apps can draw on **Italian open data**: nearly two hundred official datasets — municipalities with their full history, provinces and regions, ATECO codes, the classification of professions, education levels — plus the entire **state legislation from 1861 to today**, queryable straight from any document, with one line of text.

## One line of text, one living table

The principle is the same as everything in Reactive: you write what you want, the browser compiles it into an app. It now applies to public data too:

```
::od-query{into="cities" sql="SELECT LABEL_COMUNE_IT AS name, SIGLA_AUTOMOBILISTICA AS plate
  FROM voc_istat_cities
  WHERE CODICE_PROVINCIA = '015' AND DATA_FINE_VALIDITA = '31-12-9999'"}

::table{path="cities"}
| {name} | {plate} |
::/table
```

Results land in an ordinary collection: tables with search and sorting, aggregations, charts and even Python work on them like on any other data. The query can also hold **reactive parameters**: an input field wired in with `{#province}` re-runs the search on every change — a live lookup app in a handful of lines.

## Find the dataset by describing it

You don’t need to know table names. The `::od-search` directive runs a **semantic search** over the catalog: type “list of municipalities with their codes” or “classification of economic activities” and you get the relevant datasets, with their columns and a ready-to-copy sample query.

And since Reactive’s AI assistant knows the new directives, you can skip even that step: ask it for _“an app with the municipalities of the Milan province”_ and it writes the query for you.

## Every law, since 1861

The datasets also include the **legislation**: the reference data of every state legislative act published in the Official Journal since Italy’s unification — laws, decree-laws, legislative decrees, presidential decrees, royal decrees — each with a link to the **consolidated text on Normattiva** and to the Official Journal publication. And the search understands meaning, not just words:

```
::od-search{table="lex_atti" placeholder="Find a law…"}
```

Type “parental leave” or “first-home tax relief” and you find the right laws even without knowing their references. Results are a collection like any other: hand them to the **AI directives** — `::ai-summary` sums them up in plain words, `::ai-chat` reasons about them — or show them in a view with the links ready. The professional firm that pins legal references to its case files, the municipal desk that cites sources with the right link: four lines of text.

## The same model as always: your data doesn’t move

The open data integration doesn’t change Reactive’s promise — it extends it:

- queries are **read-only** and travel alone — none of the user’s data leaves the device;
- collections filled by the service are **excluded from multi-user sync**: nothing coming from the datasets ever crosses the relay;
- the last good response stays in a **local cache**, so the app remains usable offline (with a notice that data may be out of date).

The datasets come from official public administration sources, with bilingual Italian/English labels right in the data.

## Where to start

Browse the [dataset catalog](/en/data/) — each dataset comes with columns and a sample query — or open [the app](https://app.reactivenet.ai) and ask the assistant for an app that uses public data. The [syntax guide](/en/guida/sintassi/) documents the three new directives: `::od-query`, `::od-search` and `::od-datasets`.
