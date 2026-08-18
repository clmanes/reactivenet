@react.component
let make: (
  ~apps: array<AppDocument.summary>,
  ~locale: Locale.t,
  ~onCreate: unit => unit,
  ~onDelete: string => unit,
  ~onDuplicate: string => unit,
  /** Take the version the catalogue publishes, over the one this browser has. Only
      ever reached through the confirmation, because it replaces a document. */
  ~onUpdate: string => unit,
  ~onCopyLink: string => unit,
  ~copiedId: option<string>,
  ~canEdit: bool,
  /** What an import had to say for itself, if anything. */
  ~notice: option<string>,
  /** The first line of a conversation with the assistant, said on the page where
      apps are made rather than behind the button in the bar. */
  ~onAsk: string => unit,
) => React.element
