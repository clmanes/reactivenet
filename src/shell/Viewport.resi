/** The width at or above which the two panes are shown side by side, and editing is
    offered. */
let editingBreakpoint: string

/** Whether this viewport is wide enough to edit in. */
let canEdit: unit => bool

/** Calls back when that answer changes; returns the unsubscribe. */
let subscribe: (bool => unit) => unit => unit
