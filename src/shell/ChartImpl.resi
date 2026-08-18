/** Chart.js, statically imported here and nowhere else: reach this module only
    through a dynamic `import()`, or the engine lands in the initial bundle. */

type chart

let render: (Dom.element, {..}) => chart

let destroy: chart => unit
