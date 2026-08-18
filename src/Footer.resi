@react.component
let make: (
  ~theme: Theme.t,
  ~palette: Palette.t,
  ~locale: Locale.t,
  ~accountName: option<string>,
  ~onAccount: unit => unit,
  ~onToggleTheme: unit => unit,
  ~onSelectPalette: Palette.t => unit,
  ~onSelectLocale: Locale.t => unit,
) => Jsx.element
