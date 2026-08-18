type t =
  | Day
  | Moment

/** What this stored string is, if it is a date at all. Strict: it accepts what this
    app writes and what a date input produces, so text an author typed on purpose is
    never reformatted behind their back. */
let classify: string => option<t>

let isDate: string => bool
