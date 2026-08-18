type token =
  /** `{field}` — the row's own value. */
  | Own(string)
  /** `{field>path.label}` — the `label` of the row of `path` this field points at. */
  | Ref({field: string, path: string, label: string})
  /** `{qta*prezzo}` — arithmetic over the row's own fields, two decimals,
      missing fields as zero. `a-b` stays a field name; subtraction needs
      spaces. */
  | Calc(string)

/** Every token a template refers to, in first-appearance order. */
let tokens: string => array<token>

/** The names read off the row itself, which is what a search looks in. */
let fields: string => array<string>

/** The collections a template reaches into through a reference. */
let referenced: string => array<string>

/** Substitutes each token. Unrecognised tokens are left as written; a field the row
    does not have becomes `fallback`, and so does a reference whose row has gone. */
let fill: (
  string,
  Collection.record,
  ~fallback: string=?,
  ~resolve: (~path: string, ~id: string, ~label: string) => option<string>=?,
) => string
