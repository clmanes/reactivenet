/** Binds `::sql`: the collections in data= become tables, the fenced body is a
    SELECT, the answer lands in the derived collection into= (≤1000 rows,
    device-local). `{#key}` placeholders are reactive prepared parameters. The
    first run anywhere waits behind a Run button — it downloads the engine. */

type labels = {
  run: string,
  loading: string,
  rows: string,
  refused: string,
}

let bind: (Dom.element, ~app: string, ~labels: labels) => unit
