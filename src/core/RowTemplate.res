// Pure. `{field}` tokens, as a list view's body writes them.
//
// Substitution is defined here, over strings, and applied by the binder to *text
// nodes only* — never by building HTML. That is deliberate: a row's values come from
// whatever someone typed into a form, and a template that produced markup would make
// every stored value a scripting vector. Working on text nodes means a value
// containing `<script>` is a row that displays those characters.
//
// There are two tokens. `{who}` is the row's own field. `{who>people.name}` says that
// `who` holds the id of a row of `people`, and asks for that row's `name` — a
// relation, written where it is read. It names the collection rather than relying on
// something declared elsewhere, because a list is often nowhere near the form whose
// input made the reference, and a token that could not be read on its own would be a
// token nobody could check.

let openToken = "{"
let closeToken = "}"

// A token is a bare field name: letters, digits, underscore and hyphen. Anything
// else — a brace in prose, `${}`, a CSS rule that slipped into a paragraph — is left
// exactly as written rather than guessed at.
let namePattern = "^[A-Za-z][A-Za-z0-9_-]*$"

let isName = candidate => RegExp.test(RegExp.fromString(namePattern), candidate)

type token =
  /** `{field}` — the row's own value. */
  | Own(string)
  /** `{field>path.label}` — the `label` of the row of `path` whose id this field
      holds. */
  | Ref({field: string, path: string, label: string})
  /** `{qta*prezzo}` — arithmetic over the row's own fields, computed per row.
      Missing fields count as zero; the result carries two decimals. */
  | Calc(string)

let referencePattern = "^([A-Za-z][A-Za-z0-9_-]*)>([A-Za-z][A-Za-z0-9_-]*)\\.([A-Za-z][A-Za-z0-9_-]*)$"

let parseToken = candidate =>
  if isName(candidate) {
    Some(Own(candidate))
  } else {
    switch RegExp.exec(RegExp.fromString(referencePattern), candidate) {
    | None =>
      // Arithmetic comes LAST, and only when it truly parses: `{a-b}` is a
      // field name (hyphens are legal in one), a CSS rule in prose is neither
      // a name nor a sum, and both must stay exactly as written.
      RowExpr.looksLike(candidate) && RowExpr.parses(candidate) ? Some(Calc(candidate)) : None
    | Some(result) =>
      let part = index =>
        result->RegExp.Result.matches->Array.at(index)->Option.flatMap(v => v)->Option.getOr("")
      Some(Ref({field: part(0), path: part(1), label: part(2)}))
    }
  }

// One walk over the template, used by everything below: a second implementation of
// "where do the braces sit" would be a second set of edge cases.
let walk = (template, onToken, onText) => {
  let rec step = from =>
    switch template->String.indexOfFrom(openToken, from) {
    | -1 => onText(template->String.sliceToEnd(~start=from))
    | start =>
      switch template->String.indexOfFrom(closeToken, start + 1) {
      | -1 => onText(template->String.sliceToEnd(~start=from))
      | stop =>
        onText(template->String.slice(~start=from, ~end=start))
        let inside = template->String.slice(~start=start + 1, ~end=stop)
        switch parseToken(inside) {
        | Some(token) => onToken(token)
        // Not a token: left exactly as written, braces and all.
        | None => onText(template->String.slice(~start=start, ~end=stop + 1))
        }
        step(stop + 1)
      }
    }
  step(0)
}

// Written out rather than compared structurally: `Array.includes` on a variant is
// reference equality once it is JavaScript, so two `Own("name")` from different
// places in the template would never look alike.
let key = token =>
  switch token {
  | Own(field) => field
  | Ref({field, path, label}) => field ++ ">" ++ path ++ "." ++ label
  | Calc(expression) => expression
  }

/** Every token a template refers to, in the order it first appears. */
let tokens = template => {
  let found = []
  let seen = []
  walk(
    template,
    token =>
      if !(seen->Array.includes(key(token))) {
        seen->Array.push(key(token))
        found->Array.push(token)
      },
    _ => (),
  )
  found
}

/** The field names a template reads off the row itself, which is what a search has to
    look in. */
let fields = template =>
  tokens(template)->Array.flatMap(token =>
    switch token {
    | Own(field) => [field]
    | Ref({field}) => [field]
    | Calc(expression) => RowExpr.references(expression)
    }
  )

/** The collections a template reaches into, so the binder knows what else to read. */
let referenced = template =>
  tokens(template)->Array.filterMap(token =>
    switch token {
    | Own(_) | Calc(_) => None
    | Ref({path}) => Some(path)
    }
  )

/** Replaces each token with the record's value. `resolve` is asked for the relations:
    given a collection and the id a field holds, it answers with that row's value, or
    nothing when the row has gone — a reference to a deleted row shows the fallback
    rather than an id nobody can read. */
let fill = (template, record, ~fallback="", ~resolve=(~path as _, ~id as _, ~label as _) => None) => {
  let built = ref("")
  let add = text => built := built.contents ++ text
  walk(
    template,
    token =>
      switch token {
      | Own(field) => add(Collection.field(record, field)->Option.getOr(fallback))
      | Ref({field, path, label}) =>
        switch Collection.field(record, field) {
        | None | Some("") => add(fallback)
        | Some(id) => add(resolve(~path, ~id, ~label)->Option.getOr(fallback))
        }
      // Per row, two decimals — an amount, which is what row arithmetic is
      // for. No answer (a division by an empty field) shows the fallback.
      | Calc(expression) =>
        add(
          RowExpr.evaluate(expression, field => Collection.field(record, field))
          ->Option.map(value => Aggregate.format(value, ~decimals=2))
          ->Option.getOr(fallback),
        )
      },
    add,
  )
  built.contents
}
