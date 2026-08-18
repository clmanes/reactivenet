// Inline SVG rather than an icon package: a handful of glyphs do not justify pulling in
// @spectrum-web-components/icons-workflow, which ships hundreds. They inherit
// `currentColor`, so they follow whatever the button's Spectrum state paints.

let base = (~children) =>
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.7"
    strokeLinecap="round"
    strokeLinejoin="round"
    className="h-5 w-5"
    ariaHidden={true}>
    children
  </svg>

// Markdown's own mark: rounded frame, an M, and a descending arrow.
let markdown = base(
  ~children=<>
    <rect x="2.5" y="5" width="19" height="14" rx="2.5" />
    <path d="M6 15.5v-7l3 3.5 3-3.5v7" />
    <path d="M16.5 8.5v6m0 0 2-2m-2 2-2-2" />
  </>,
)

// Stacked blocks, the way a block editor shows its outline.
let blocks = base(
  ~children=<>
    <rect x="3" y="4" width="18" height="4.5" rx="1.5" />
    <rect x="3" y="12" width="12" height="3.5" rx="1.5" />
    <rect x="3" y="18" width="16" height="3.5" rx="1.5" />
  </>,
)

// A pane split in two with the left half filled: the editor is showing.
let panelShown = base(
  ~children=<>
    <rect x="3" y="4.5" width="18" height="15" rx="2" />
    <path d="M10 4.5v15" />
    <path d="M4.6 8h3.8M4.6 12h3.8M4.6 16h3.8" />
  </>,
)

// The same pane with the split collapsed: the editor is hidden.
let panelHidden = base(
  ~children=<>
    <rect x="3" y="4.5" width="18" height="15" rx="2" />
    <path d="M7 4.5v15" />
  </>,
)

let phone = base(
  ~children=<>
    <rect x="7" y="2.5" width="10" height="19" rx="2.5" />
    <path d="M10.75 5.4h2.5" />
    <path d="M11 18.6h2" />
  </>,
)

let desktop = base(
  ~children=<>
    <rect x="2.5" y="4" width="19" height="12.5" rx="2" />
    <path d="M9 20.5h6M12 16.5v4" />
  </>,
)

let info = base(
  ~children=<>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 11v5" />
    <path d="M12 7.75h.01" />
  </>,
)

// Two colons and a brace: what a directive looks like.
let directive = base(
  ~children=<>
    <path d="M6.5 9h.01M6.5 15h.01" />
    <path d="M11 5c-1.6 0-2.4.8-2.4 2.4v2.2c0 1.2-.7 1.9-1.9 2.4 1.2.5 1.9 1.2 1.9 2.4v2.2c0 1.6.8 2.4 2.4 2.4" />
    <path d="M17 5c1.6 0 2.4.8 2.4 2.4v2.2c0 1.2.7 1.9 1.9 2.4-1.2.5-1.9 1.2-1.9 2.4v2.2c0 1.6-.8 2.4-2.4 2.4" />
  </>,
)

let language = base(
  ~children=<>
    <circle cx="12" cy="12" r="9" />
    <path d="M3 12h18" />
    <path d="M12 3a15 15 0 0 1 0 18a15 15 0 0 1 0-18" />
  </>,
)

let palette = base(
  ~children=<>
    <path d="M12 3a9 9 0 1 0 0 18c.9 0 1.6-.7 1.6-1.6 0-.4-.2-.8-.5-1.1-.3-.3-.5-.7-.5-1.1 0-.9.7-1.6 1.6-1.6H16a5 5 0 0 0 5-5c0-4.1-4-7.6-9-7.6Z" />
    <circle cx="7.5" cy="11" r="1" />
    <circle cx="10.5" cy="7" r="1" />
    <circle cx="15" cy="7.5" r="1" />
  </>,
)

// A stack of records: the shape a collection has.
let data = base(
  ~children=<>
    <ellipse cx="12" cy="6" rx="7.5" ry="3" />
    <path d="M4.5 6v6c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3V6" />
    <path d="M4.5 12v6c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3v-6" />
  </>,
)

// A chain link, for copying an app's URL.
let link = base(
  ~children=<>
    <path d="M10 13.5a3.5 3.5 0 0 0 5 0l3-3a3.5 3.5 0 0 0-5-5l-1.5 1.5" />
    <path d="M14 10.5a3.5 3.5 0 0 0-5 0l-3 3a3.5 3.5 0 0 0 5 5l1.5-1.5" />
  </>,
)

// Two sheets, one behind the other: the second is what duplicating produces, and the
// offset is the whole idea drawn.
let copy = base(
  ~children=<>
    <rect x="9" y="9" width="11" height="11" rx="2" />
    <path d="M15 6.5A2.5 2.5 0 0 0 12.5 4H6a2 2 0 0 0-2 2v6.5A2.5 2.5 0 0 0 6.5 15" />
  </>,
)

// A node with two others coming off it: the shape everything uses for "send this to
// somebody", and the one that does not look like a link (which is the button next to
// it).
let share = base(
  ~children=<>
    <circle cx="17.5" cy="5.5" r="2.5" />
    <circle cx="6.5" cy="12" r="2.5" />
    <circle cx="17.5" cy="18.5" r="2.5" />
    <path d="m8.8 10.8 6.4-3.7 M8.8 13.2l6.4 3.7" />
  </>,
)

// A waste bin, for deleting an app and its data.
let trash = base(
  ~children=<>
    <path d="M4 6.5h16" />
    <path d="M9 6.5V4.5h6v2" />
    <path d="M6.5 6.5 7.5 20h9l1-13.5" />
    <path d="M10.5 10v6.5M13.5 10v6.5" />
  </>,
)

// A grid of tiles: the destination is a gallery of apps, not a home page, and a
// house would promise a different kind of page than the one it opens.
let gallery = base(
  ~children=<>
    <rect x="3.5" y="3.5" width="7" height="7" rx="1.5" />
    <rect x="13.5" y="3.5" width="7" height="7" rx="1.5" />
    <rect x="3.5" y="13.5" width="7" height="7" rx="1.5" />
    <rect x="13.5" y="13.5" width="7" height="7" rx="1.5" />
  </>,
)

// An eye: the app as its readers see it.
let eye = base(
  ~children=<>
    <path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" />
    <circle cx="12" cy="12" r="3" />
  </>,
)

// A pencil: the same app, open for editing.
let pencil = base(
  ~children=<>
    <path d="M4 20h4l10-10a2.5 2.5 0 0 0-3.5-3.5L4.5 16.5 4 20Z" />
    <path d="M14 7.5 16.5 10" />
  </>,
)

// A plus, for creating an app.
let add = base(
  ~children=<>
    <path d="M12 5v14M5 12h14" />
  </>,
)

// An arrow leaving the tray: the app written out to a file.
let download = base(
  ~children=<>
    <path d="M12 4v11m0 0 4-4m-4 4-4-4" />
    <path d="M4.5 17.5v1A2.5 2.5 0 0 0 7 21h10a2.5 2.5 0 0 0 2.5-2.5v-1" />
  </>,
)

// The same arrow, coming in.
let upload = base(
  ~children=<>
    <path d="M12 15V4m0 0 4 4m-4-4-4 4" />
    <path d="M4.5 17.5v1A2.5 2.5 0 0 0 7 21h10a2.5 2.5 0 0 0 2.5-2.5v-1" />
  </>,
)

// The two polarities. Each names the one it switches *to*, the same way the
// view/edit control does.
let sun = base(
  ~children=<>
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M19.1 4.9l-1.8 1.8M6.7 17.3l-1.8 1.8" />
  </>,
)

let moon = base(
  ~children=<>
    <path d="M20 13.5A8.5 8.5 0 0 1 10.5 4a8.5 8.5 0 1 0 9.5 9.5Z" />
  </>,
)

// A head and shoulders: the account, which is a person and not a gear.
let person = base(
  ~children=<>
    <circle cx="12" cy="8" r="3.5" />
    <path d="M5.5 20a6.5 6.5 0 0 1 13 0" />
  </>,
)

// A speech bubble: the chat between the people using this app.
let chat = base(
  ~children=<>
    <path
      d="M12 4c4.7 0 8.5 2.9 8.5 6.6S16.7 17.2 12 17.2c-.9 0-1.8-.1-2.6-.3L4.8 19.5l1.1-3.3c-1.5-1.2-2.4-2.9-2.4-4.6C3.5 6.9 7.3 4 12 4Z"
    />
    <path d="M8.5 9.5h7M8.5 12.3h4.5" />
  </>,
)

// A paperclip: a file attached to a chat message.
let paperclip = base(
  ~children=<>
    <path
      d="M8.5 12.5 15 6a3.2 3.2 0 0 1 4.5 4.5l-8 8a5.3 5.3 0 0 1-7.5-7.5L11.5 3.5"
    />
  </>,
)

// Two arrows chasing each other: data that goes and comes back.
let sync = base(
  ~children=<>
    <path d="M4.5 9a8 8 0 0 1 13.9-2.2L20 8.5m0 0V4m0 4.5h-4.5" />
    <path d="M19.5 15a8 8 0 0 1-13.9 2.2L4 15.5m0 0V20m0-4.5h4.5" />
  </>,
)

// A spark: the assistant, and the one control here that makes something out of
// nothing. Deliberately not a robot or a speech bubble — the bubble is already the
// chat between the people using an app, and two bubbles in two bars would be two
// names for two different things.
let sparkle = base(
  ~children=<>
    <path d="M12 3.5 13.6 8 18 9.6 13.6 11.2 12 15.6 10.4 11.2 6 9.6 10.4 8 12 3.5Z" />
    <path d="M18 15.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8.8-2.2Z" />
  </>,
)

// A cogwheel, cut to six teeth: any more and they close up at 20 px.
let settings = base(
  ~children=<>
    <circle cx="12" cy="12" r="3.2" />
    <path d="M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3M18.7 5.3l-2.1 2.1M7.4 16.6l-2.1 2.1M18.7 18.7l-2.1-2.1M7.4 7.4 5.3 5.3" />
  </>,
)

// A cross: close the panel.
let close = base(~children=<path d="M6 6l12 12M18 6 6 18" />)
