// Pure. The `{...}` part of a directive: `{ref="#volume" min="0" legend="Volume"}`.
//
// Deliberately not a general YAML/JSON parser. Directive attributes are a flat list
// of `name="value"` pairs, and accepting more than that would let a document look
// like it means something the renderer will not honour.

type t = {
  name: string,
  value: string,
}

// Values may be double-quoted, single-quoted, or bare when they contain no
// whitespace. A bare `name` on its own is a boolean flag and reads as "true", which
// is how `{quiet}` and `{quiet="true"}` end up meaning the same thing.
let pattern = "([A-Za-z_][A-Za-z0-9_-]*)(?:\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s}]+)))?"

let parse = source => {
  // Built per call: a /g regex carries `lastIndex`, so a shared instance would make
  // the second parse of the same string return nothing.
  let regex = RegExp.fromString(pattern, ~flags="g")

  let rec collect = accumulated =>
    switch regex->RegExp.exec(source) {
    | None => accumulated
    | Some(result) =>
      // `matches` already models an unmatched group as None, which is exactly what
      // distinguishes `legend=""` from an attribute written without a value.
      let captured = index =>
        result->RegExp.Result.matches->Array.at(index)->Option.flatMap(value => value)

      switch captured(0) {
      | None => accumulated
      | Some(name) =>
        // The three alternatives are mutually exclusive; whichever matched carries
        // the value, and none matching means the attribute was written as a flag.
        let value =
          captured(1)->Option.orElse(captured(2))->Option.orElse(captured(3))->Option.getOr("true")
        collect(accumulated->Array.concat([{name, value}]))
      }
    }

  collect([])
}

// Attribute names are matched case-insensitively, the way HTML attributes are.
let find = (attributes, name) => {
  let needle = name->String.toLowerCase
  attributes
  ->Array.find(attribute => attribute.name->String.toLowerCase == needle)
  ->Option.map(attribute => attribute.value)
}

// The boundary the renderer calls: parse and look up in one step, since it never
// needs the whole list.
let attribute = (source, name) => find(parse(source), name)

// Always double-quoted on the way out, even when the value would survive bare: one
// shape means a rewritten directive never changes shape just because a value did.
let serialize = attributes =>
  attributes
  ->Array.map(attribute =>
    attribute.name ++ "=\"" ++ attribute.value->String.replaceAll("\"", "'") ++ "\""
  )
  ->Array.join(" ")

// Updates in place or appends, keeping the order the author wrote.
let set = (attributes, ~name, ~value) =>
  attributes->Array.some(a => a.name->String.toLowerCase == name->String.toLowerCase)
    ? attributes->Array.map(a =>
        a.name->String.toLowerCase == name->String.toLowerCase ? {name: a.name, value} : a
      )
    : attributes->Array.concat([{name, value}])
