@react.component
let make: (
  ~locale: Locale.t,
  ~route: Route.t,
  ~canEdit: bool,
  /** Whether this app's link was just copied, so the control can say so. */
  ~copied: bool,
  ~onToggleEditing: unit => unit,
  ~onHome: unit => unit,
  ~onCopyLink: unit => unit,
  ~onShare: unit => unit,
  ~onSync: unit => unit,
  ~onExport: unit => unit,
  ~onImport: unit => unit,
  /** The assistant is on both the gallery and an open app: it is about making one. */
  ~assistantOpen: bool,
  ~onAssistant: unit => unit,
) => Jsx.element
