/** The dialog that hands over a link carrying the app. `shortLink` is the stored,
    encrypted form ("" when the server did not answer); `link` is the full serverless
    one ("" when past the fragment ceiling). `tooBig` means neither exists. */
@react.component
let make: (
  ~open_: bool,
  ~locale: Locale.t,
  ~title: string,
  ~link: string,
  ~shortLink: string,
  ~tooBig: bool,
  ~onClose: unit => unit,
) => Jsx.element
