/** Binds `::map` after each render: markers or GeoJSON areas from a collection,
    popups from the body template, Leaflet as a lazy chunk. The reader's view
    survives edits and refreshes; rows without valid coordinates simply have no
    marker. */

let bind: (Dom.element, ~app: string) => unit
