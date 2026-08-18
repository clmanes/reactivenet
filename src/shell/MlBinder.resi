/** Binds the ml-* directives: scikit-learn (and statsmodels for the seasonal
    forecasts) over the shared Python runtime, fixed code templates, data and
    parameters through the data channel, results into a derived device-local
    collection. Numeric parameters accept reactive #keys. */

type labels = {
  run: string,
  loading: string,
  rows: string,
  refused: string,
  engine: string,
}

let bind: (Dom.element, ~app: string, ~labels: labels) => unit
