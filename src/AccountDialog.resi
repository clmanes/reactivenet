@react.component
let make: (
  ~open_: bool,
  ~locale: Locale.t,
  ~session: option<Session.t>,
  ~onClose: unit => unit,
  ~onSignedIn: Session.t => unit,
  ~onSignOut: unit => unit,
) => React.element
