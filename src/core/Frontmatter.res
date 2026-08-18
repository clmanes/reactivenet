// Pure. A deliberately small YAML subset: the `---` delimited block at the very top
// of a document, read as ordered `key: value` lines.
//
// Fields are kept as an ordered list rather than a fixed record so that a document
// carrying keys this app has never heard of still shows them in the info panel,
// exactly as authored. Typed access to the ones that drive behaviour goes through
// `get`.

type field = {
  key: string,
  value: string,
}

type t = {fields: array<field>}

type document = {
  meta: option<t>,
  body: string,
}

let delimiter = "---"

// Trailing \r survives when a CRLF document is split on \n, and would otherwise end
// up inside every value and stop the closing delimiter from matching.
let stripCarriageReturn = line =>
  line->String.endsWith("\r") ? line->String.slice(~start=0, ~end=String.length(line) - 1) : line

// The escapes `quote` below writes, undone one by one. A double replaceAll cannot do
// this — unescaping `\\n` before `\\\\` or after it both misread one of the two — so
// the value is walked once, left to right.
let unescape = value => {
  let out = ref("")
  let rec walk = index =>
    switch value->String.charAt(index) {
    | "" => ()
    | "\\" =>
      switch value->String.charAt(index + 1) {
      | "n" =>
        out := out.contents ++ "\n"
        walk(index + 2)
      | "r" =>
        out := out.contents ++ "\r"
        walk(index + 2)
      | "\"" =>
        out := out.contents ++ "\""
        walk(index + 2)
      | "\\" =>
        out := out.contents ++ "\\"
        walk(index + 2)
      // A backslash before anything else is content, exactly as written.
      | _ =>
        out := out.contents ++ "\\"
        walk(index + 1)
      }
    | character =>
      out := out.contents ++ character
      walk(index + 1)
    }
  walk(0)
  out.contents
}

// Only matched pairs are removed: a value like "it's" keeps its apostrophe. A
// double-quoted value is also unescaped, because that is the form `quote` writes —
// without this, every edit-save cycle grew the value a layer of backslashes.
let unquote = value => {
  let length = String.length(value)
  if length >= 2 {
    let first = value->String.charAt(0)
    let last = value->String.charAt(length - 1)
    if first == "\"" && first == last {
      value->String.slice(~start=1, ~end=length - 1)->unescape
    } else if first == "'" && first == last {
      value->String.slice(~start=1, ~end=length - 1)
    } else {
      value
    }
  } else {
    value
  }
}

let parseField = line =>
  switch line->String.indexOf(":") {
  // No colon at all, or a line starting with one: not a field.
  | -1 | 0 => None
  | index =>
    let key = line->String.slice(~start=0, ~end=index)->String.trim
    // Everything after the *first* colon, so ISO timestamps and URLs survive intact.
    let value = line->String.slice(~start=index + 1, ~end=String.length(line))->String.trim->unquote
    key == "" ? None : Some({key, value})
  }

let rec findClosing = (lines, index) =>
  switch lines->Array.at(index) {
  | None => None
  | Some(line) => line->stripCarriageReturn->String.trim == delimiter ? Some(index) : findClosing(lines, index + 1)
  }

let parse = source => {
  let lines = source->String.split("\n")

  switch lines->Array.at(0) {
  | Some(first) if first->stripCarriageReturn->String.trim == delimiter =>
    switch findClosing(lines, 1) {
    // An unterminated block is not frontmatter: treating it as one would swallow the
    // whole document, so the text is left exactly as written.
    | None => {meta: None, body: source}
    | Some(closing) =>
      let fields =
        lines
        ->Array.slice(~start=1, ~end=closing)
        ->Array.map(stripCarriageReturn)
        ->Array.filterMap(line => {
          let trimmed = line->String.trim
          // Blank lines and comments carry no field.
          trimmed == "" || trimmed->String.startsWith("#") ? None : parseField(line)
        })

      let body =
        lines
        ->Array.slice(~start=closing + 1, ~end=Array.length(lines))
        ->Array.join("\n")
        // The blank line that conventionally follows the block would otherwise become
        // leading whitespace in the rendered document.
        ->String.replaceRegExp(RegExp.fromString("^\\s*\\n"), "")

      {meta: Some({fields: fields}), body}
    }
  | _ => {meta: None, body: source}
  }
}

// Case-insensitive: YAML keys are conventionally lowercase but authors are not.
let get = (meta, name) => {
  let needle = name->String.toLowerCase
  meta.fields
  ->Array.find(field => field.key->String.toLowerCase == needle)
  ->Option.map(field => field.value)
}

let empty = {fields: []}

// Values that YAML would otherwise read as something other than a string get quoted:
// a bare 1.0 is a float and 2026-06-27 is a date, but `version` and `date` are meant
// to survive as text. Also quoted: anything empty, carrying edge whitespace, opening
// with a comment marker, or containing a `: ` that would look like a second key.
let needsQuoting = value =>
  value == "" ||
  value != value->String.trim ||
  value->String.startsWith("#") ||
  // A value that merely *looks* quoted would be stripped on the way back in.
  value->String.startsWith("\"") ||
  value->String.startsWith("'") ||
  // A raw newline would end the field mid-value — or, carrying `---`, end the block.
  value->String.includes("\n") ||
  value->String.includes("\r") ||
  value->String.includes(": ") ||
  RegExp.test(RegExp.fromString("^-?[0-9]+(\\.[0-9]+)?$"), value) ||
  RegExp.test(RegExp.fromString("^[0-9]{4}-[0-9]{2}-[0-9]{2}"), value) ||
  RegExp.test(RegExp.fromString("^(true|false|null|yes|no|on|off)$", ~flags="i"), value)

// The backslash first, or escaping the quotes would double what it just wrote.
let quote = value =>
  "\"" ++
  value
  ->String.replaceAll("\\", "\\\\")
  ->String.replaceAll("\"", "\\\"")
  ->String.replaceAll("\n", "\\n")
  ->String.replaceAll("\r", "\\r") ++ "\""

let renderValue = value => needsQuoting(value) ? quote(value) : value

// Existing keys keep their position; new ones are appended. Rewriting the block must
// not reorder what the author wrote.
let setField = (meta, ~key, ~value) =>
  meta.fields->Array.some(field => field.key->String.toLowerCase == key->String.toLowerCase)
    ? {
        fields: meta.fields->Array.map(field =>
          field.key->String.toLowerCase == key->String.toLowerCase ? {key: field.key, value} : field
        ),
      }
    : {fields: meta.fields->Array.concat([{key, value}])}

let removeField = (meta, ~key) => {
  fields: meta.fields->Array.filter(field =>
    field.key->String.toLowerCase != key->String.toLowerCase
  ),
}

// A block with no fields is omitted entirely rather than written as an empty pair of
// delimiters, which the parser would accept but no author would have typed.
let serialize = (meta, body) =>
  meta.fields->Array.length == 0
    ? body
    : delimiter ++
      "\n" ++
      meta.fields
      ->Array.map(field => field.key ++ ": " ++ renderValue(field.value))
      ->Array.join("\n") ++
      "\n" ++
      delimiter ++
      "\n\n" ++
      body
