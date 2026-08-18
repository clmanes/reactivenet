/** Binds the chart-* directives after each render: reads the collection, draws
    with Chart.js (a lazy chunk, loaded only when a document has a chart), and
    follows the store through `rn:data`. Inside a ::dashboard a click selects
    the bar's x value for the sibling views. */

let bind: (Dom.element, ~app: string) => unit
