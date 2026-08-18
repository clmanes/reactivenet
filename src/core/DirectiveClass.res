// Pure. Which kind of thing a directive is.
//
// The registry knows every directive and every attribute, and nothing about what any
// of them is *for*. That is fine for the renderer, which only has to build elements,
// and useless for anything that presents the set to a person: a slash menu of 114
// entries in one list is a list nobody reads to the end.
//
// So the classes are written down here, once, and everything that shows directives to
// somebody — the block editor's menu today, the completions and the documentation
// tomorrow — reads the same answer. A directive with no class is a directive somebody
// added and did not file; the test says so rather than letting it fall quietly into
// "other".

type t =
  | Structure
  | Data
  | Ai
  | Views
  | Values
  | Status
  | Controls
  | Navigation
  | Layout
  | Overlays
  | Colour
  | TableParts

let members = [
  // `workflow` is filed here and not under Data because it stores nothing: it is the
  // arrangement of the blocks that do, the way a page is the arrangement of what it
  // holds.
  (Structure, ["page", "columns", "dashboard", "workflow"]),
  (Data, ["form", "input", "choose", "save", "add-form", "geo", "od-query", "od-search", "od-datasets", "api-query", "geocode", "file", "sql",
      "ml-cluster", "ml-anomaly", "ml-predict", "ml-correlate", "ml-forecast",
    ]),
  // The ai-* family gets a heading of its own: they are not a way of storing data
  // and not a way of drawing it, they are the assistant put to work inside the app,
  // and a reader scanning a menu of a hundred and thirty entries is scanning for
  // exactly that distinction.
  (
    Ai,
    [
      "ai-summary", "ai-chat", "ai-agent", "ai-pipeline", "ai-query", "ai-rule",
      "ai-classify", "ai-extract", "ai-field", "ai-suggest", "ai-assist",
      "ai-translate", "ai-rewrite", "ai-vision", "ai-search",
    ],
  ),
  (
    Views,
    [
      "list", "cards", "table", "column", "board", "timetable", "calendar", "if-any", "if-empty",
      "chart-bar", "chart-line", "chart-pie", "chart-scatter", "chart-area",
      "chart-doughnut", "chart-radar", "map", "explore",
    ],
  ),
  // `python` is filed here rather than under its own heading because that is what it
  // is for: a number worked out from the rows and shown. `:sum` is the short way and
  // this is the long one.
  (Values, ["value", "calc", "count", "sum", "avg", "min", "max", "median", "stddev", "mode", "python"]),
  (
    Status,
    [
      "badge", "status-light", "progress-bar", "progress-circle", "meter", "toast",
      "alert-banner", "help-text", "coach-indicator", "illustrated-message", "asset",
      "divider", "truncated",
    ],
  ),
  (
    Controls,
    [
      "print",
      "button", "action-button", "clear-button", "close-button", "infield-button",
      "picker-button", "checkbox", "radio", "radio-group", "switch", "slider",
      "slider-handle", "number-field", "textfield", "search", "combobox", "picker",
      "swatch", "swatch-group", "field-label", "field-group", "tag", "tags", "dropzone",
    ],
  ),
  (
    Navigation,
    [
      "tabs", "tab", "tab-panel", "tabs-overflow", "sidenav", "sidenav-heading",
      "sidenav-item", "breadcrumbs", "breadcrumb-item", "top-nav", "top-nav-item",
      "menu", "menu-item", "menu-divider", "menu-group", "action-menu", "action-group",
      "action-bar", "button-group", "link",
    ],
  ),
  (
    Layout,
    ["accordion", "accordion-item", "card", "split-view", "grid", "theme", "thumbnail", "avatar", "icon"],
  ),
  (
    Overlays,
    [
      "dialog", "dialog-base", "dialog-wrapper", "alert-dialog", "popover", "tray",
      "underlay", "overlay", "overlay-trigger", "tooltip", "tooltip-openable",
      "contextual-help", "coachmark",
    ],
  ),
  (Colour, ["color-area", "color-field", "color-handle", "color-loupe", "color-slider", "color-wheel"]),
  (
    TableParts,
    ["table-body", "table-head", "table-head-cell", "table-row", "table-cell", "table-checkbox-cell"],
  ),
]

/** The order a menu should list them in: ours first, because they are what makes a
    document an app, and Spectrum's after, roughly from the ones people reach for most
    to the pieces of a composition. */
let all = members->Array.map(((class, _)) => class)

/** Where the class sits in the order above. A menu draws a heading each time the
    group changes, so items have to arrive sorted by it or the same heading appears
    a dozen times with a directive or two under each. */
let order = directive =>
  members->Array.findIndex(((_, names)) => names->Array.includes(directive))

let of_ = directive =>
  members
  ->Array.find(((_, names)) => names->Array.includes(directive))
  ->Option.map(((class, _)) => class)

let label = class =>
  switch class {
  | Structure => Translations.ClassStructure
  | Data => Translations.ClassData
  | Ai => Translations.ClassAi
  | Views => Translations.ClassViews
  | Values => Translations.ClassValues
  | Status => Translations.ClassStatus
  | Controls => Translations.ClassControls
  | Navigation => Translations.ClassNavigation
  | Layout => Translations.ClassLayout
  | Overlays => Translations.ClassOverlays
  | Colour => Translations.ClassColour
  | TableParts => Translations.ClassTableParts
  }

/** How a directive is written, which is the only name it should ever be shown under:
    a menu that says "Accordion item" and a document that says `::accordion-item`
    leave the reader to work out that they are the same thing. Inline directives carry
    one colon because that is how they are typed. */
let inlineNames = ["value", "calc", "count", "sum", "avg", "min", "max", "median", "stddev", "mode"]

let written = directive =>
  inlineNames->Array.includes(directive) ? ":" ++ directive : "::" ++ directive

/** A glyph for the class, as the `d` of one SVG path on a 24×24 grid. Drawn rather
    than fetched: the menu shows eleven of these and they are strokes, not artwork —
    a request and a cache entry each would be a poor trade. One per *class* rather
    than one per directive, because what the reader is scanning for in a list of 114
    entries is which family they are in. */
let glyph = class =>
  switch class {
  // A page with a fold.
  | Structure => "M6 3h8l4 4v14H6z M14 3v4h4"
  // A stack: rows going in.
  | Data => "M4 7c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3z M4 7v10c0 1.7 3.6 3 8 3s8-1.3 8-3V7"
  // A spark: the mark the assistant already wears in the navbar.
  | Ai => "M12 3l1.9 4.6L18.5 9.5 13.9 11.4 12 16l-1.9-4.6L5.5 9.5l4.6-1.9z M18 15l.9 2.1L21 18l-2.1.9L18 21l-.9-2.1L15 18l2.1-.9z"
  // A grid of rows and columns.
  | Views => "M3 5h18v14H3z M3 10h18 M9 10v9"
  // A sum.
  | Values => "M17 5H7l6 7-6 7h10"
  // A dot in a ring: something is the case.
  | Status => "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 8v5 M12 16h.01"
  // A slider.
  | Controls => "M4 8h16 M4 16h16 M9 5v6 M15 13v6"
  // A signpost.
  | Navigation => "M12 3v18 M5 6h11l3 3-3 3H5z"
  // Panes.
  | Layout => "M3 5h18v14H3z M10 5v14"
  // One card over another.
  | Overlays => "M8 4h12v12H8z M4 8v12h12"
  // A drop.
  | Colour => "M12 3s6 6.5 6 10a6 6 0 0 1-12 0c0-3.5 6-10 6-10z"
  // A table with its header.
  | TableParts => "M3 5h18v14H3z M3 9h18 M9 9v10 M15 9v10"
  }
