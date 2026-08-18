@react.component
let make: (
  ~open_: bool,
  ~locale: Locale.t,
  ~app: option<string>,
  ~session: option<Session.t>,
  ~onClose: unit => unit,
  ~onOpenAccount: unit => unit,
  ~onChanged: unit => unit,
) => React.element
