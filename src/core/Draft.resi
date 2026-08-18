type control = {
  field: string,
  /** The visible label, so a complaint names the field the way the reader sees it. */
  label: string,
  value: string,
  /** The `type` attribute, which decides how the value is read. */
  kind: string,
  ticked: bool,
  required: bool,
  min: string,
  max: string,
  /** A regular expression the whole value must match. Empty means no rule. */
  pattern: string,
  /** What to say when `pattern` refuses. */
  patternMessage: string,
}

type problem =
  | Missing
  | NotANumber
  | NotADate
  | NotATime
  | NotAnEmail
  | NotAUrl
  | Below(string)
  | Above(string)
  | NotMatching(string)

type complaint = {
  field: string,
  label: string,
  problem: problem,
}

/** What the control stores: `"true"`/`"false"` for a tick, the value otherwise. */
let reading: control => string

/** Whether this control holds nothing. An unticked box holds nothing, even though it
    reads as `"false"`. */
let isBlank: control => bool

/** Whether the whole draft holds nothing, which is a mis-click rather than a row. */
let blank: array<control> => bool

/** Every complaint the draft deserves, in the order the fields were written. Empty
    means it can be saved. */
let check: array<control> => array<complaint>
