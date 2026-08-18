type t =
  | Light
  | Dark

let toggle: t => t

/** The `color` attribute of `sp-theme`. */
let toSpectrumColor: t => string

let isDark: t => bool

let toTag: t => string
let parse: string => option<t>

let fromPrefersDark: bool => t
