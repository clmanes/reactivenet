/** Binds the od-* directives after each render: fetches from the same-origin
    `/od` service into ordinary collections, re-runs a query when a `{#key}` it
    mentions changes, and keeps the last received rows as the offline copy. */

type labels = {
  loading: string,
  rows: string,
  stale: string,
  unreachable: string,
  refused: string,
  search: string,
}

let bind: (Dom.element, ~app: string, ~labels: labels) => unit
