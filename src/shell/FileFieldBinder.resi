/** Wires `::file` fields: reads the chosen file, caps it at maxkb, stores
    small files inside the row's value and large ones in FileStore, and shows
    the preview beside the input. */

type labels = {tooBig: string}

let bind: (Dom.element, ~app: string, ~labels: labels) => unit
