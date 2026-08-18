// Pure. What the assistant's delivery *means*, decided before anything is written.
//
// The model hands over a document; this module says which app it becomes. Every
// rule here is a rule this app already had, reused rather than restated — an
// assistant that could overwrite an app, or land one under an id the URL would
// refuse, would be a second way into storage with weaker rules than the first.
//
//   - the id is `AppFile.idFor`, the same decision an imported .md file goes
//     through: the declared id when it is free, a fresh one when it is taken. An
//     assistant never overwrites, for the reason an import never does — a replaced
//     app cannot be recovered and a duplicate can simply be deleted.
//   - the id is written back into the frontmatter, so the document, the storage key
//     and the URL cannot disagree about what the app is called.
//
// Editing the open app is the other direction and has the opposite rule: the id is
// forced back to the one already open. A model that changed `appId` in a proposed
// rewrite would *move* the app — collections, URL and all — as a side effect of
// being asked to add a button. Moving an app stays something the author does in the
// editor, deliberately.

type delivery =
  | Deliver({
      id: string,
      /** The document as it will be stored: the id written into its frontmatter. */
      source: string,
      title: string,
      /** True when the id the document asked for was taken and it landed elsewhere. */
      renamed: bool,
    })
  | Refused(string)

/** Models fence what they are asked for. A document that arrives wrapped in
    ```markdown … ``` is the document, not a code block inside one — and stored as
    written it would render as a page of grey text with the directives inert. Only a
    fence that wraps the *whole* answer is taken off: one in the middle is somebody's
    ::python block. */
let unfence = markdown => {
  let text = markdown->String.trim
  if !(text->String.startsWith("```")) {
    text
  } else {
    switch text->String.indexOf("\n") {
    | -1 => text
    | first =>
      let opening = text->String.slice(~start=0, ~end=first)->String.trim
      // ```markdown, ```md, ``` — an opening line that is only a fence and a word.
      let isLanguageOnly = opening->String.length <= 12 && !(opening->String.includes(" "))
      let body = text->String.slice(~start=first + 1, ~end=text->String.length)
      if isLanguageOnly && body->String.trimEnd->String.endsWith("```") {
        let trimmed = body->String.trimEnd
        trimmed->String.slice(~start=0, ~end=trimmed->String.length - 3)->String.trimEnd
      } else {
        text
      }
    }
  }
}

// A document with nothing in it is not an app, and writing one would put an empty
// card in the gallery that says nothing about what went wrong.
let refuseEmpty = "The document is empty. Write the whole app, frontmatter included, and call this tool again."

/** Whether the validator's report says the document is good.

    The report is the MCP server's `report()`, which begins with `ok — …` when the
    document validates and with `N problem(s):` when it does not. Reading the first
    word is a seam between two programs, so it is written down once, here, tested on
    both sides — `scripts/test-mcp.mjs` asserts the server still says `ok`.

    It matters because a model asked to validate first will not always do it. The
    small ones write the app, create it, and validate afterwards, which is how a
    document with a broken `::list` reached a gallery: the instruction was there and
    nothing enforced it. Delivery checks for itself. */
let validates = report => report->String.trim->String.toLowerCase->String.startsWith("ok")

// The analyzer's own marker. A second seam of the same kind as the one above, and it
// needs one for the same reason: validation reads a document a directive at a time and
// cannot see whether the pieces MEET, so an app can be perfect grammar and still be a
// page where nothing happens — a list over a collection no form writes, a total bound
// to a key no control feeds. That is not a lesser problem than a misspelled attribute;
// it is the worse one, because it *renders*.
//
// Read as a marker rather than by counting findings, because the report is prose and
// the count is in it: "3 finding(s)" would have to be parsed, "No orphans" is stated.
// Anything else is a no — an unreachable analyzer must not wave a document through, and
// silence is not a clean bill.
let orphansMarker = "No orphans"

let connects = report => report->String.includes(orphansMarker)

// --- The third gate: the queries, actually run --------------------------------
//
// Grammar says the directive is written correctly. Data flow says the collection has
// a writer. Neither can say the SELECT that writes it returns anything, and that is
// the failure that survives both and reaches a person: a dashboard whose every figure
// is blank because `regione='PUGLIA'` finds nothing in a column holding 'Puglia'.
// DuckDB compares case-sensitively; the query parses, runs, matches nothing, and the
// app renders empty cards with no error anywhere.
//
// Only the SELECTs that can be run *here* are collected. A query carrying `{#key}`
// depends on what a reader will type, so there is no honest value to put in its place
// and it is left alone rather than tried with a guess — a false verdict about a query
// that is fine is worse than no verdict, because it sends somebody to change the one
// thing that was right.
let odQueries = document =>
  DirectiveScan.scan(document)
  ->Array.filterMap(occurrence =>
    occurrence.DirectiveScan.name == "od-query"
      ? DirectiveAttributes.parse(occurrence.DirectiveScan.attributes)
        ->DirectiveAttributes.find("sql")
        ->Option.flatMap(sql => OdQuery.references(sql)->Array.length == 0 ? Some(sql) : None)
      : None
  )

/** The two things the runner says when a query is not usable. Written down here
    because delivery reads them, exactly as it reads the validator's `ok` and the
    analyzer's `No orphans`. */
let brokenQueryMarker = "THIS IS A BROKEN QUERY"
let refusedQueryMarker = "The query was refused"

// Only an EXPLICIT failure blocks — the opposite of the rule the other two gates
// follow, and deliberately so. Those two ask a pure function about a string that is
// already in hand; this one asks a service over a network, and a warehouse being
// briefly away must not make delivery impossible. It is the same decision as opening
// the gate when there is no documentation server at all.
let queryFails = answer =>
  answer->String.includes(brokenQueryMarker) || answer->String.includes(refusedQueryMarker)

let titleOf = (~source, ~id) =>
  switch Frontmatter.parse(source).meta->Option.flatMap(meta => Frontmatter.get(meta, "title")) {
  | Some(title) if title->String.trim != "" => title->String.trim
  | _ => id
  }

let create = (~markdown, ~taken, ~fallback) => {
  let source = unfence(markdown)
  if source->String.trim == "" {
    Refused(refuseEmpty)
  } else {
    let id = AppFile.idFor(~source, ~taken, ~fallback)
    let stored = AppDocument.withId(source, id)
    Deliver({
      id,
      source: stored,
      title: titleOf(~source=stored, ~id),
      renamed: AppFile.isCopy(~source, ~id),
    })
  }
}

let replace = (~markdown, ~id) => {
  let source = unfence(markdown)
  if source->String.trim == "" {
    Refused(refuseEmpty)
  } else if !AppId.isValid(id) {
    Refused("No app is open, so there is nothing to edit. Ask the user to open one, or create a new app instead.")
  } else {
    // Forced back to the open app's id: a rewrite must not move the app.
    let stored = AppDocument.withId(source, id)
    Deliver({id, source: stored, title: titleOf(~source=stored, ~id), renamed: false})
  }
}
