---
title: "What it is like to live here"
translationKey: "app-come-si-vive"
seotitle: "What it is like to live here: your municipality in official data"
appid: "come-si-vive"
weight: 5
description: "Your municipality's portrait in one place: how many of us there are and what people earn, how safe the roads are and who commutes, what health care is around — hospitals, care outcomes, clinics, doctors and scanners — how much soil has been built on and how much is recycled. Eleven official sources, always next to the province and national figure."
lead: "A figure on its own says nothing. This app puts your municipality next to its neighbours across seven indicators, projects the time series forward and looks for the ones out of line — computing all of it inside your browser."
shots:
  - src: come-si-vive-ritratto.jpg
    alt: "The “Portrait” page: the municipality menu and six figures in a row — residents, income, accidents, pharmacies, built-on soil, seismic zone."
    caption: "Six figures from six different sources: Naples, 905,050 residents, €25,360 average income, 28.1 accidents per ten thousand, 63.7% of soil already built on, seismic zone 2."
  - src: come-si-vive-previsione.jpg
    alt: "The “Roads” page: twenty-four years of accidents with the trend line projected forward."
    caption: "The 2001-2024 series and its projection, with the horizon set by a slider. The chart demonstrates the caveat printed under it: the line ignores the 2020 collapse and the recent rise."
  - src: come-si-vive-salute.jpg
    alt: "The “Health” page: the catchment's hospitals with cases, crude value and risk-adjusted value."
    caption: "Care outcomes, facility by facility. The two right-hand columns say different things: one hospital is 19.3% crude and 6.08% adjusted on hip fracture mortality."
  - src: come-si-vive-confronti.jpg
    alt: "The “Comparisons” page: the correlation table across the indicators of the province's municipalities."
    caption: "Ninety-two municipalities, seven indicators, and the correlation between each pair — computed in Python in the browser, with no data leaving."
tags: ["Citizens", "Municipalities", "Journalists", "Open data", "ISTAT", "Health", "Environment", "Machine learning"]
---

## What it does

You pick a municipality at the top — all 7,896 of them — and seven pages fill up.

**The portrait** lines up six figures from six different sources: how many of us
there are, what people earn, how dangerous the road is, how much health care is
within reach, how much of the territory has been built on, and which seismic zone
it sits in. Below, the same figure next to the province, the region and Italy,
because that is the only way to know whether a number is high.

**The road** is the accident series since 2001 with its projection, and the
vehicle fleet by Euro class. **Who moves** says how many people leave each day and
how many arrive, and by what means.

**Health** starts from the question no health portal answers — which health
authority is mine — and then shows the catchment's hospitals, how many doctors and
nurses work there, **how care actually ends** facility by facility, the
municipality's family clinics and the diagnostic machines on a map.

**Environment** is built-on soil period by period and recycling year by year, with
kilos per resident next to the percentage: sorting a mountain of waste well is
still worse than producing less of it.

**Comparisons** is the page that stops looking at one municipality alone.

## The machine learning, and why it is honest

Three analyses run **in the browser**, over data it has already downloaded:

- a **projection** of the accident series, with the horizon chosen by the reader.
  It is a straight line pushed forward and the page says so: the model knows
  nothing about roundabouts built or limits lowered, and on a series with a turn
  it ignores it by construction;
- the **correlations** across the seven indicators of the province's
  municipalities — which things move together. Next to it sits the sentence that
  makes the page useful rather than dangerous: two things that move together are
  not one the cause of the other;
- **anomaly detection**, flagging municipalities that do not resemble their
  neighbours. An unusual municipality is not one in trouble: it may be the
  provincial capital, the town with the motorway beside it, or an error at source.
  The model says where to look; whoever looks decides what they found.

There is no model trained elsewhere, no precomputed ranking, and no data leaving:
these are sums done in front of the reader, which is why their parameters can be
changed.

## Where the data comes from

Eleven official sources: ISTAT (population, road accidents, commuting), the
Treasury (incomes), ACI (vehicle fleet), the Ministry of Health (health
authorities, hospitals, staff, equipment, family clinics, pharmacies — all under
the IODL 2.0 licence), AGENAS (care outcomes), ISPRA (land consumption and waste),
and the Civil Protection Department (seismic zones).

The app's last page lists them all and explains the four things you need to know
in order not to misread them — starting with the most treacherous, that **beds per
resident** are deliberately not computed: a hospital does not serve the town it
stands in, it serves the authority's catchment.
