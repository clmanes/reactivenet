// Pure. What a form's controls hold, and whether that is worth saving.
//
// This is the part of the save button that has nothing to do with the DOM: given the
// fields as they stand, is the draft empty, and is anything in it wrong? Keeping it
// here is what makes both answers testable — the binder reads the controls off the
// page and does what it is told.
//
// `required` used to mark a field and refuse nothing, because nothing here submits
// and there is no submit to validate. A row saved half-written is a row someone has
// to find and fix later, so the check is done before writing rather than not at all.

type control = {
  field: string,
  /** The visible label, so a complaint can name the field the way the reader sees it
      rather than by its storage name. */
  label: string,
  value: string,
  /** The `type` attribute, which is also what decides how the value is read. */
  kind: string,
  ticked: bool,
  required: bool,
  min: string,
  max: string,
  /** A regular expression the whole value must match, as on an HTML input. Empty
      means no rule. */
  pattern: string,
  /** What to say when `pattern` refuses — a rule reads as a bug without one, because
      the reader cannot see the expression. */
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
  /** The author's own rule refused it; the string is what they said about it, empty
      when they said nothing. */
  | NotMatching(string)

type complaint = {
  field: string,
  label: string,
  problem: problem,
}

let isTick = control => control.kind == "checkbox"

/** What the control would store. A tick is `"true"`/`"false"`, which is what the same
    tick reads as everywhere else in the app. */
let reading = control => isTick(control) ? (control.ticked ? "true" : "false") : control.value

// An unticked box is empty for this purpose. It answers "false", which is a value,
// and reading it as one made a form with a checkbox in it impossible to mis-click:
// every press of the button saved a row with nothing in it.
let isBlank = control =>
  isTick(control) ? !control.ticked : control.value->String.trim == ""

let blank = controls => controls->Array.every(isBlank)

let time = RegExp.fromString("^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$")

// Deliberately not the full grammar: an address with no @, no domain or a space in it
// is a typo, and anything stricter starts refusing addresses that work.
let email = RegExp.fromString("^[^@\\s]+@[^@\\s.]+(\\.[^@\\s.]+)+$")

let numeric = (control, value) =>
  switch Numeric.parse(value) {
  | None => Some(NotANumber)
  | Some(number) =>
    switch (Numeric.parse(control.min), Numeric.parse(control.max)) {
    | (Some(low), _) if number < low => Some(Below(control.min))
    | (_, Some(high)) if number > high => Some(Above(control.max))
    | _ => None
    }
  }

// A date and a time both sort as text when written the way their inputs write them,
// which is the whole reason those formats are stored as they are.
let ordered = (control, value, wrong) =>
  switch wrong {
  | Some(_) => wrong
  | None =>
    if control.min != "" && value < control.min {
      Some(Below(control.min))
    } else if control.max != "" && value > control.max {
      Some(Above(control.max))
    } else {
      None
    }
  }

// The author's own rule, anchored at both ends like an HTML `pattern`: a rule that
// matched anywhere in the value would accept "12 rue de la Paix" for a postcode and
// look like it was working. A malformed expression refuses nothing rather than
// refusing everything — an author's typo must not lock the form.
let matches = (expression, value) =>
  switch RegExp.fromStringWithFlags("^(?:" ++ expression ++ ")$", ~flags="u") {
  | exception _ => true
  | rule => RegExp.test(rule, value)
  }

let byPattern = (control, value) =>
  control.pattern != "" && !matches(control.pattern, value)
    ? Some(NotMatching(control.patternMessage))
    : None

let problemOf = control => {
  let value = control.value->String.trim
  if isTick(control) {
    control.required && !control.ticked ? Some(Missing) : None
  } else if value == "" {
    // An empty optional field is not a mistake; it is a field nobody filled in.
    control.required ? Some(Missing) : None
  } else {
    let kind = switch control.kind {
    | "number" => numeric(control, value)
    | "date" =>
      ordered(control, value, DateValue.classify(value) == Some(Day) ? None : Some(NotADate))
    | "time" => ordered(control, value, RegExp.test(time, value) ? None : Some(NotATime))
    | "email" => RegExp.test(email, value) ? None : Some(NotAnEmail)
    | "url" =>
      switch SafeUrl.parse(value) {
      | Ok(_) => None
      | Error(_) => Some(NotAUrl)
      }
    | _ => None
    }
    // The type first: "this is not a number" is a better thing to read than the
    // author's message about a shape the value could never have had.
    switch kind {
    | Some(_) => kind
    | None => byPattern(control, value)
    }
  }
}

/** Every complaint the draft deserves, in the order the fields were written — so the
    first one is the first thing on the page, and focusing it moves nobody backwards. */
let check = controls =>
  controls->Array.filterMap(control =>
    problemOf(control)->Option.map(problem => {
      field: control.field,
      label: control.label == "" ? control.field : control.label,
      problem,
    })
  )
