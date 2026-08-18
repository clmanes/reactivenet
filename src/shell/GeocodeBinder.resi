/** Wires `::geocode`: on a click, the rows with an address and no coordinates
    yet get them from Nominatim — one request a second, at most 50 per click,
    saved row by row so an interrupted run keeps its answers. The scalar form
    resolves one address into a reactive key. */

let bind: (Dom.element, ~app: string, ~labels: OpenDataBinder.labels) => unit
