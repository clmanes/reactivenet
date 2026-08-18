@react.component
let make: (
  ~source: string,
  ~theme: Theme.t,
  ~locale: Locale.t,
  /** The app whose collections the data directives read and write. */
  ~app: option<string>,
) => Jsx.element
