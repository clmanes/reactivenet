// Pure. Finds directives in a document and splices edits back in.
//
// The shared vocabulary: the same scanner and renderer serve the marked pipeline and
// the block editor, so directive syntax has one definition. BlockNoteImpl builds its
// custom blocks from what `scan` finds and writes them back through `render` —
// necessary because BlockNote's markdown converter escapes anything it does not
// recognise, so `::range[volume]` typed into it would come back mangled.
//
// Offsets are absolute into the original string so an edit can be spliced without
// re-rendering the parts of the document nobody touched.

type form =
  | Inline
  | Leaf
  | Container

type occurrence = {
  form: form,
  name: string,
  label: string,
  attributes: string,
  start: int,
  stop: int,
}

// A value in quotes may contain a closing brace — `pattern="[0-9]{5}"` is the case
// that matters — so the attribute list is scanned quote-aware rather than up to the
// first `}`. Outside quotes a brace still ends it, which is what keeps a directive
// one line long.
let attributesPart = "(?:\\{((?:\\\"[^\\\"]*\\\"|'[^']*'|[^}])*)\\})?"

let inlinePattern = "(?<!:):(?!:)([A-Za-z][A-Za-z0-9_-]*)(?:\\[([^\\]]*)\\])?" ++ attributesPart
// One block form, not two. `::name{…}` opens a leaf or a container and the *close*
// decides which: a `::/name` below it makes the block a container and everything
// between them its body. Naming the close is what removes the counting — two
// containers written the same way are still unambiguous, because each says what it
// ends. A leaf is simply a block nobody closed.
let blockPattern =
  "^::(?!:)([A-Za-z][A-Za-z0-9_-]*)(?:\\[([^\\]]*)\\])?" ++ attributesPart ++ "[ \\t]*$"
let blockClosePattern = "^::/([A-Za-z][A-Za-z0-9_-]*)[ \\t]*$"

let captured = (result, index) =>
  result->RegExp.Result.matches->Array.at(index)->Option.flatMap(value => value)->Option.getOr("")

// A fenced code block is code, and code is not scanned.
//
// This is not a nicety: marked tokenises a fence before any inline tokenizer sees
// inside it, and our own block extension declines every line that does not open with
// `::`, so the fence tokenizer takes the whole block. Which means the renderer has
// ALWAYS ignored directives written inside a fence — and the scanner, which is
// supposed to match it line for line, did not. The two disagreed everywhere a
// document carries code, which here means every `::python`, `::sql` and `::explore`.
//
// What it cost: a slice written `disponibili[:tetto]` inside a Python block reads as
// the inline directive `:tetto`, so the validator reported an unknown directive in
// code that renders perfectly, and the block editor's splitter — which splits the
// source on what `scan` finds — would cut a line of Python in half. A false report
// about correct code is the worst kind: it sends somebody to change the one thing
// that was right.
//
// The rule is CommonMark's, cut to what marked accepts: three or more backticks or
// tildes, indented at most three spaces, closed by at least as many of the SAME
// character on a line of its own. A fence nobody closes runs to the end of the
// document, which is again what marked does — the two must agree even when the
// document is wrong, or they disagree about where the damage stops.
let fenceOpen = RegExp.fromString("^ {0,3}(`{3,}|~{3,})(.*)$")
let fenceClose = RegExp.fromString("^ {0,3}(`{3,}|~{3,})[ \\t]*$")

let fencedLines = lines => {
  let inside = lines->Array.map(_ => false)
  let marker = ref("")
  lines->Array.forEachWithIndex((line, index) => {
    if marker.contents == "" {
      switch fenceOpen->RegExp.exec(line) {
      // An info string may not contain a backtick when the fence is made of them:
      // otherwise `` `a` and `b` `` in a paragraph would open one.
      | Some(result) if !(captured(result, 0)->String.startsWith("`")) ||
        !(captured(result, 1)->String.includes("`")) =>
        marker := captured(result, 0)
        inside->Array.set(index, true)
      | _ => ()
      }
    } else {
      inside->Array.set(index, true)
      switch fenceClose->RegExp.exec(line) {
      | Some(result) =>
        let found = captured(result, 0)
        // Same character, at least as long. A shorter run, or the other character,
        // is content — which is how a fenced block can show a fence.
        if (
          String.get(found, 0) == String.get(marker.contents, 0) &&
            String.length(found) >= String.length(marker.contents)
        ) {
          marker := ""
        }
      | None => ()
      }
    }
  })
  inside
}

// Inline directives are searched per line rather than across the whole document, so
// a `{` left open on one line cannot swallow the next.
let scanInline = (line, offset) => {
  let regex = RegExp.fromString(inlinePattern, ~flags="g")

  let rec collect = accumulated =>
    switch regex->RegExp.exec(line) {
    | None => accumulated
    | Some(result) =>
      let matched = result->RegExp.Result.fullMatch
      let start = result->RegExp.Result.index
      collect(
        accumulated->Array.concat([
          {
            form: Inline,
            name: captured(result, 0),
            label: captured(result, 1),
            attributes: captured(result, 2),
            start: offset + start,
            stop: offset + start + String.length(matched),
          },
        ]),
      )
    }

  collect([])
}

let scan = source => {
  let lines = source->String.split("\n")
  let block = RegExp.fromString(blockPattern)
  let blockClose = RegExp.fromString(blockClosePattern)
  // Computed once and consulted by both walks below. The close of a container has to
  // obey the same rule as its opening: a `::/form` inside a fence is code, and
  // letting it close the container would end the block in the middle of somebody's
  // program.
  let fenced = fencedLines(lines)
  let inFence = index => fenced->Array.at(index)->Option.getOr(false)

  // The close that belongs to *this* block: the first `::/name` not claimed by a
  // block of the same name opened in between. Depth is counted per name, which is
  // why the name on the close is not decoration — without it two containers of
  // different kinds would still have to be told apart by length.
  let rec findNamedClose = (name, cursor, cursorOffset, depth) =>
    switch lines->Array.at(cursor) {
    | None => None
    | Some(candidate) =>
      let candidateNext = cursorOffset + String.length(candidate) + 1
      if inFence(cursor) {
        findNamedClose(name, cursor + 1, candidateNext, depth)
      } else {
        switch blockClose->RegExp.exec(candidate) {
        | Some(closing) if captured(closing, 0) == name =>
          depth == 0
            ? Some((cursor, cursorOffset + String.length(candidate)))
            : findNamedClose(name, cursor + 1, candidateNext, depth - 1)
        | _ =>
          switch block->RegExp.exec(candidate) {
          | Some(opening) if captured(opening, 0) == name =>
            findNamedClose(name, cursor + 1, candidateNext, depth + 1)
          | _ => findNamedClose(name, cursor + 1, candidateNext, depth)
          }
        }
      }
    }

  // `skipUntil` carries the line index a container has already consumed up to, so its
  // body is not scanned again as if it were top level.
  let rec walk = (index, offset, skipUntil, found) =>
    switch lines->Array.at(index) {
    | None => found
    | Some(line) =>
      let lineLength = String.length(line)
      let next = offset + lineLength + 1

      if index < skipUntil || inFence(index) {
        walk(index + 1, next, skipUntil, found)
      } else {
        switch block->RegExp.exec(line) {
        | Some(result) =>
          let name = captured(result, 0)
          let shared = {
            form: Leaf,
            name,
            label: captured(result, 1),
            attributes: captured(result, 2),
            start: offset,
            stop: offset + lineLength,
          }
          switch findNamedClose(name, index + 1, next, 0) {
          | Some((closeLine, stop)) =>
            walk(
              index + 1,
              next,
              closeLine + 1,
              found->Array.concat([{...shared, form: Container, stop}]),
            )
          // Nobody closed it, so it is a leaf — which is the whole grammar: a block
          // with a body and a block without one are written the same way.
          | None => walk(index + 1, next, skipUntil, found->Array.concat([shared]))
          }
        | None => walk(index + 1, next, skipUntil, found->Array.concat(scanInline(line, offset)))
        }
      }
    }

  walk(0, 0, 0, [])
}

// Rendered back in the same shape it was read, so an untouched directive round-trips
// to exactly its own text.
let render = (~form, ~name, ~label, ~attributes) => {
  let labelPart = label == "" ? "" : "[" ++ label ++ "]"
  let attributePart = attributes->String.trim == "" ? "" : "{" ++ attributes->String.trim ++ "}"

  switch form {
  | Inline => ":" ++ name ++ labelPart ++ attributePart
  // A container opens exactly like a leaf. That the two arms are the same line is
  // the grammar, not a duplication to fold away: only `closing` tells them apart.
  | Leaf | Container => "::" ++ name ++ labelPart ++ attributePart
  }
}

/** The line that ends a container opened by `render`. */
let closing = (~name) => "::/" ++ name

let replace = (source, occurrence, replacement) =>
  source->String.slice(~start=0, ~end=occurrence.start) ++
  replacement ++
  source->String.slice(~start=occurrence.stop, ~end=String.length(source))

// A container carries its body, so removing one removes the content it wrapped; the
// caller is expected to have asked first.
let remove = (source, occurrence) => {
  let before = source->String.slice(~start=0, ~end=occurrence.start)
  let after = source->String.slice(~start=occurrence.stop, ~end=String.length(source))
  // Leaf and container directives own their whole line: leaving the newline behind
  // would accumulate blank lines with every deletion.
  switch occurrence.form {
  | Inline => before ++ after
  | Leaf | Container => before ++ after->String.replaceRegExp(RegExp.fromString("^\\n"), "")
  }
}
