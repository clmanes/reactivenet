// Pure. Decides what the editor should offer, given the text before the cursor.
//
// The decision is here rather than in the CodeMirror extension because it is the
// part with all the edge cases — a colon inside prose is not a directive, a `{` that
// is already closed is not an attribute list — and none of them need an editor to
// test.

type context =
  /** `colons` is how many the author actually typed: one is inline, two is a block.
      Whether that block is completed with a close depends on the component, not on
      the author. */
  | Directive({prefix: string, colons: int})
  | Attribute({directive: string, prefix: string})
  | Value({directive: string, attribute: string, prefix: string})
  | Prose(string)

type completion = {
  label: string,
  detail: string,
  insert: string,
  /** Caret position inside `insert`, in characters from its start. */
  caret: int,
  /** Characters *before* the word being typed that `insert` already contains, and
      which the editor must therefore replace too. A directive snippet carries its
      own colons, so accepting `::acc` has to consume the two that are there rather
      than writing two more in front of them. */
  back: int,
}

// Whether a block is completed with a close, which the author no longer says: they
// type `::` for everything. A component with a slot can hold content — but one that
// carries a value is a *control*, written `::slider[key]`, where the brackets name
// the store key and there is nothing to put inside. Offering the closed form for
// those would be offering the shape nobody writes.
let holdsContent = (component: SpectrumRegistry.component) =>
  component.slots->Array.length > 0 &&
    !(component.attributes->Array.some(a => a.name == "value" || a.name == "checked"))

// The last `{` with no `}` after it: anything before that is not the attribute list
// the cursor sits in.
let openBrace = line =>
  switch line->String.lastIndexOf("{") {
  | -1 => None
  | index => line->String.lastIndexOf("}") > index ? None : Some(index)
  }

let directiveNameBefore = (line, index) =>
  switch RegExp.exec(
    RegExp.fromString(":+([A-Za-z][A-Za-z0-9_-]*)(?:\\[[^\\]]*\\])?\\s*$"),
    line->String.slice(~start=0, ~end=index),
  ) {
  | Some(result) =>
    result->RegExp.Result.matches->Array.at(0)->Option.flatMap(value => value)
  | None => None
  }

// Inside an attribute list, the fragment after the last space is what is being
// typed; an `=` in it means the cursor has moved on to the value.
let analyseAttributes = (directive, fragment) => {
  let current = switch fragment->String.lastIndexOf(" ") {
  | -1 => fragment
  | index => fragment->String.slice(~start=index + 1, ~end=String.length(fragment))
  }

  switch current->String.indexOf("=") {
  | -1 => Attribute({directive, prefix: current})
  | index =>
    let attribute = current->String.slice(~start=0, ~end=index)
    let raw = current->String.slice(~start=index + 1, ~end=String.length(current))
    // The opening quote is syntax, not part of what the author has typed.
    let prefix = raw->String.startsWith("\"") || raw->String.startsWith("'")
      ? raw->String.slice(~start=1, ~end=String.length(raw))
      : raw
    Value({directive, attribute, prefix})
  }
}

let analyse = line =>
  switch openBrace(line) {
  | Some(index) =>
    switch directiveNameBefore(line, index) {
    | Some(directive) =>
      analyseAttributes(
        directive,
        line->String.slice(~start=index + 1, ~end=String.length(line)),
      )
    // A `{` that follows no directive is ordinary text.
    | None => Prose("")
    }
  | None =>
    // The name must start with a letter, the same rule the scanner applies: without
    // it "Meeting at 10:30" reads as an inline directive named "30".
    switch RegExp.exec(RegExp.fromString("(?<!:)(:{1,2})([A-Za-z][A-Za-z0-9_-]*)?$"), line) {
    | Some(result) =>
      let captured = index =>
        result->RegExp.Result.matches->Array.at(index)->Option.flatMap(v => v)->Option.getOr("")
      Directive({prefix: captured(1), colons: String.length(captured(0))})
    | None =>
      switch RegExp.exec(RegExp.fromString("([A-Za-z0-9]*)$"), line) {
      | Some(result) =>
        Prose(
          result->RegExp.Result.matches->Array.at(0)->Option.flatMap(v => v)->Option.getOr(""),
        )
      | None => Prose("")
      }
    }
  }

let matchesPrefix = (candidate, prefix) =>
  prefix == "" || candidate->String.toLowerCase->String.startsWith(prefix->String.toLowerCase)

// The skeleton a directive is inserted as. The caret lands where the author has to
// type next: the label for a leaf, the attribute list for a container.
let directiveInsert = (component: SpectrumRegistry.component, ~colons=2) => {
  let name = component.directive
  if colons <= 1 {
    (":" ++ name ++ "[]{}", String.length(name) + 2)
  } else if holdsContent(component) {
    ("::" ++ name ++ "{}\n\n::/" ++ name, String.length(name) + 3)
  } else {
    ("::" ++ name ++ "[]{}", String.length(name) + 3)
  }
}

let completions = (context, registry: array<SpectrumRegistry.component>) =>
  switch context {
  | Directive({prefix, colons}) =>
    registry
    ->Array.filter(component => matchesPrefix(component.directive, prefix))
    ->Array.map(component => {
      let (insert, caret) = directiveInsert(component, ~colons)
      // The snippet carries its own colons, so accepting it has to consume the ones
      // already typed rather than writing them twice.
      let back = colons
      {
        label: component.directive,
        detail: component.description == ""
          ? component.tag ++ " — " ++ component.attributes->Array.length->Int.toString ++ " attributes"
          : component.description,
        insert,
        caret,
        back,
      }
    })
  | Attribute({directive, prefix}) =>
    switch registry->Array.find(component => component.directive == directive) {
    | None => []
    | Some(component) =>
      component.attributes
      ->Array.filter(attribute => matchesPrefix(attribute.name, prefix))
      ->Array.map(attribute => {
        // A flag carries no value, so inserting `="")` for it would be wrong.
        let insert = switch attribute.kind {
        | Flag => attribute.name
        | _ => attribute.name ++ "=\"\""
        }
        {
          label: attribute.name,
          // The manifest documents fewer than half the attributes, so the type
          // stands in where it does not.
          detail: attribute.description != ""
            ? attribute.description
            : switch attribute.kind {
              | Flag => "flag"
              | Number => "number"
              | Choice => attribute.choices->Array.join(" | ")
              | Text => "text"
              },
          insert,
          caret: switch attribute.kind {
          | Flag => String.length(insert)
          | _ => String.length(attribute.name) + 2
          },
          back: 0,
        }
      })
    }
  | Value({directive, attribute, prefix}) =>
    switch registry->Array.find(component => component.directive == directive) {
    | None => []
    | Some(component) =>
      switch component.attributes->Array.find(candidate => candidate.name == attribute) {
      | None => []
      | Some(found) =>
        let values = switch found.kind {
        | Flag => ["true", "false"]
        | _ => found.choices
        }
        values
        ->Array.filter(value => matchesPrefix(value, prefix))
        ->Array.map(value => {
          label: value,
          detail: attribute,
          insert: value,
          caret: String.length(value),
          back: 0,
        })
      }
    }
  | Prose(prefix) =>
    MarkdownSnippets.matching(prefix)->Array.map(snippet => {
      label: snippet.label,
      detail: snippet.detail,
      insert: snippet.insert,
      caret: snippet.caret,
      back: 0,
    })
  }
