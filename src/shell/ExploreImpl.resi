/** Perspective, statically imported here and nowhere else: reach this module
    only through a dynamic `import()`. */

type table

let makeTable: array<JSON.t> => promise<table>

let replaceRows: (table, array<JSON.t>) => promise<unit>

let makeViewer: (Dom.element, table, JSON.t) => promise<Dom.element>

/** Takes a viewer out of service and removes it. Perspective leaks WASM memory
    for a `<perspective-viewer>` that leaves the document without this. The
    table it was loaded with is not deleted. */
let deleteViewer: Dom.element => promise<unit>

let saveConfig: Dom.element => promise<JSON.t>
