---
title: "School in numbers: five new sources and a dashboard for principals and teachers"
description: "Reactive's open data warehouse grows to 237 datasets with a complete school section: enrollment with ten years of history, school drop-out extracted from ministry PDFs, buildings and seismic risk, tenured staff, regional INVALSI results. Plus a new dashboard app with enrollment forecasting, cross-filtering and choropleth maps."
date: 2026-07-21
author: "Cosimo Luigi Manes"
translationKey: "five-school-datasets"
cover: "/img/blog/five-school-datasets.jpg"
coverAlt: "High school classroom blocks under construction, Bamaga, April 1972"
coverAuthor: "Queensland State Archives"
coverAuthorUrl: "https://www.flickr.com/photos/60455048@N02"
coverSource: "https://www.flickr.com/photos/60455048@N02/37077784015"
coverLicense: "Public Domain Mark"
coverLicenseUrl: "https://creativecommons.org/publicdomain/mark/1.0/"
---

After cohesion funds, the vehicle fleet and civil justice, Reactive’s open data warehouse completes the **education** picture: five official sources that together tell who studies, where, with what results, in which buildings and with what staff. All without an access key:

- **enrolled students** by municipality, grade and school year (MIUR), ten years of history from 2015/16 — the current picture and the trend;
- **school drop-out** (MIM — Statistics Office): the national series from 2013/14 and the regional detail, rebuilt from the Ministry’s official reports;
- **school buildings**: 60,054 buildings with construction period, seismic classification and constraints — the oldest is dated year 1000, and it’s not a typo;
- **tenured staff** (teachers and support staff) by province, ten years: the basis for the student-teacher ratio and for reading the retirement wave;
- **INVALSI sample results** by region and geographic area, 2012/13-2022/23: the historical series the municipal-level data already in the catalogue was missing.

The warehouse now stands at **237 datasets**, with **33 verified relationships** in the semantic layer.

## A new app: dashboards for the people who run schools or teach in them

Not a showcase of charts: **School in numbers** is built around the operational questions of a school principal or a teacher, and uses almost the whole Reactive BI vocabulary in a single document.

### 🏫 How many students you WILL have (not just how many you have)

You search the municipality **by name** (a search field filtering the ISTAT registry, no codes to remember) and the tab updates on its own. Then the number you need to plan staff and classes: the enrollment trend **extended forward** with a 1-to-5-year forecast — a slider for the horizon, an **algorithm menu** (linear trend, ARIMA/SARIMA or Holt-Winters) and a declared R². The same tool, in the Staffing tab, projects the province’s tenured teachers.

### 📉 Cross-filtering on drop-out

Click a region’s bar and the historical detail narrows to that region — the pattern of real BI tools, in a Markdown file. Same for INVALSI scores, with choropleth maps alongside: the geography of drop-out and the geography of scores, colored by the data.

### 🔍 The pivot, and questions in plain words

The last tab loads enrollment by region/grade/year into an **explorable pivot view** (drag columns, switch chart type, filter — even in Use mode) and, with an AI engine configured, answers natural-language questions on the same data.

Want to see everything there is, with the measured relationships between tables? [Explore the dataset catalogue](/en/data/) — or open [School in numbers](/app/opendata/school-in-numbers) and start from your municipality.
