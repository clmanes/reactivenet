/** `::dashboard`'s cross-filter: a chart click inside one selects that x value,
    sibling views narrow to matching rows, and a chip shows the filter with its
    ✕. The selection is per device, never synced, and survives edits. */

type labels = {removeFilter: string}

let bind: (Dom.element, ~labels: labels) => unit
