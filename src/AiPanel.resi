/** The assistant: a chat that writes apps, opened from the navbar in the gallery and
    beside an open app alike.

    Not [ChatPanel] — that one is the people using an app talking to each other, and
    its messages are rows of that app's own collection. This one belongs to the
    browser: it answers the four tools about this gallery itself (the MCP server
    answers everything grammatical and custodies nothing), and it keeps the
    difference between creating and editing — a new app is written and offered, a
    rewrite of the open app is proposed and applied only when the author says so. */

@react.component
let make: (
  ~locale: Locale.t,
  /** The app currently open, which is what the edit tools act on. */
  ~app: option<string>,
  /** A question asked elsewhere — the gallery's opening box — to be sent as soon as
      the assistant has something to send it to. */
  ~question: option<string>,
  ~onQuestionTaken: unit => unit,
  /** An app was written: the gallery has changed under whoever is looking at it. */
  ~onCreated: string => unit,
  ~onOpen: string => unit,
  /** The author accepted a proposed rewrite of the open app. */
  ~onApply: (~id: string, ~source: string) => unit,
  ~onClose: unit => unit,
) => Jsx.element
