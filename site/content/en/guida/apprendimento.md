---
title: "Machine learning"
description: "The five ml-* directives: groups, anomalies, regression, correlations and forecasts, with scikit-learn inside the browser."
weight: 25
translationKey: "apprendimento"
---

Five directives run **scikit-learn in the browser** — on the same Python
interpreter as `::python`, so in a worker, so a long computation never blocks
the page. The data does not leave here.

They all have the same shape: they read a collection, learn from some numeric
fields, and **write the rows back** into a derived collection with one more
column.

```markdown
::range[k]{min="2" max="10" value="4" legend="Number of groups"}

::ml-cluster{data="towns" features="income,age" k="#k" into="groups"}

::chart-scatter{data="groups" x="income" y="age"}
```

## The common rules

**The executed code is a fixed template.** What the document writes — field
names, parameters — never ends up inside the code: the rows and the parameters
travel in the runner's data channel and the Python reads them from there. It is
the SQL-injection argument, applied where nobody usually applies it.

**Features are numeric fields**, and the whole string counts, not its beginning.
The **decimal comma is accepted**. Unusable rows are **dropped and counted** in
the status line — which reads `used/total`, so you see at once whether the model
learned from thirty rows out of two thousand.

**Results are derived collections**, local to this device: they are not pushed
into a shared space, and a remote update cannot delete them. A clustering is
this browser's computation, not a shared fact.

**Numeric parameters accept `#keys`**, so a slider above the directive re-runs
it: that is how you watch the result change as k varies without touching the
document.

**The first run that needs a package waits behind a *Run* button.**
scikit-learn is tens of megabytes, then cached. No document makes somebody
download that for opening it — with one exception: `::ml-correlate` is pure
Python and downloads nothing.

For `::ml-forecast` **whether a package is needed at all is the reader's
choice**: the linear trend downloads nothing, `arima` and `holt` need
statsmodels. So writing `model="#key"` with a `::picker` above it is supported,
and the *Run* button appears when the model that needs it is chosen — not when
the block is drawn.

## `::ml-cluster` — the groups

K-means over standardised features. Writes the rows back with a `cluster`
column.

| Attribute | |
| --- | --- |
| `data` | The collection to learn from |
| `features` | The **numeric** fields, comma-separated |
| `k` | How many groups, 2 to 20 — a number or a `#key` |
| `into` | The derived collection the rows land in |

The standardising is not a detail: without it, a field in euro and one in years
are not comparable and the grouping is decided on its own by whichever has the
bigger numbers.

## `::ml-anomaly` — what does not fit

Isolation Forest. Writes the rows back with `anomalia` (0 to 1, higher is
stranger) and `flag` (1 = out of line).

| Attribute | |
| --- | --- |
| `data` | The collection |
| `features` | The numeric fields |
| `contamination` | The expected share of anomalies, 0 to 0.5; without it, 0.05 — a number or a `#key` |
| `into` | The derived collection |

`contamination` is a **declaration**, not a measurement: you are telling the
method how many anomalies to expect, and it will find about that many. Raising
it does not find more problems, it marks more rows.

## `::ml-predict` — regression

Learns from the rows where `target` is numeric and writes `previsione` on
**every** row with valid features — including the ones where the target is
missing, which is the entire point.

| Attribute | |
| --- | --- |
| `data` | The collection |
| `features` | The numeric fields to learn from |
| `target` | The numeric field to learn |
| `model` | `linear` or `forest` |
| `into` | The derived collection |

The **R²** appears in the status line. It is worth reading before looking at the
predictions: a low R² does not make the predictions wrong, it makes them
**uninformative** — and a column of plausible numbers is the easiest thing in
the world to believe.

```markdown
::ml-predict{data="properties" features="sqm,floor,year" target="price" model="forest" into="estimates"}

::chart-scatter{data="estimates" x="price" y="previsione"}
```

That scatter plot — the truth against the prediction — is how you look at a
model that does not summarise into a single number.

## `::ml-correlate` — what goes with what

A Pearson correlation matrix over the features: writes `{a, b, r}` pairs.

| Attribute | |
| --- | --- |
| `data` | The collection |
| `features` | The numeric fields |
| `into` | The derived collection the pairs land in |

It is the only one of the five that **downloads nothing**: it is pure Python, so
it runs straight away. It is also the one to start from, before choosing the
features for the others.

## `::ml-forecast` — forecasting over time

| Attribute | |
| --- | --- |
| `data` | The collection holding the series |
| `x` | The time field: a number (a year) or an ISO date |
| `y` | The numeric value field |
| `horizon` | How many future rows to write, 1 to 60; without it, 6 |
| `model` | `linear` (the default), `arima`/`sarima`, `holt`/`holt-winters`/`ets` |
| `season` | The seasonal period: 12 for monthly data |
| `into` | The derived collection |

It writes the history with a `previsione` column, plus `horizon` future rows at
the series' median step.

```markdown
::ml-forecast{data="enrolments" x="year" y="pupils" model="holt" horizon="5" into="projection"}

::chart-line{data="projection" x="year" y="pupils,previsione"}
```

The **linear fallback is declared**: if SARIMAX or Holt-Winters do not converge
on the series they were given, the result is a linear trend, and the status line
says so and carries the reason. A seasonal model that silently returned a straight
line would be worse than one that fails, because the chart would come out looking
fine anyway.

A **differenced** model — ARIMA, SARIMA — has no estimate for its first
observations: those rows carry **no `previsione`**, and the projection line starts
where the model does. They are not zero, because a zero at the left edge of an
enrolment chart flattens everything else under a spike, and an R² measured against
that zero reports a catastrophic model that is in fact perfectly good. The R² is
measured only over what the model actually fitted.

With **fewer than three points** there is no forecast: the status line says
`used/total` and the collection stays empty. That happens more often than it
sounds when the series comes from an open dataset covering few years.
