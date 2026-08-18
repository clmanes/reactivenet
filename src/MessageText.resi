/** One message rendered as markdown: sanitised, with its links held to the app's own
    allowlist. No directives — a message is text somebody sent, not a document that
    runs. `className` is added beside `rn-md`, which carries the styling. */
@react.component
let make: (~text: string, ~locale: Locale.t, ~className: string=?) => Jsx.element
