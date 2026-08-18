/** Binds `::api-query`: any public https JSON API into a derived, device-local
    collection — or a scalar into a reactive key. `{#key}` URL placeholders are
    reactive; `every=` polls, floored at 60 s; a refresh button always exists. */

type labels = {
  loading: string,
  rows: string,
  stale: string,
  unreachable: string,
  refused: string,
  refresh: string,
}

let bind: (Dom.element, ~app: string, ~labels: labels) => unit
