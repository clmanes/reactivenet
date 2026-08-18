// Pure. One collection as a spreadsheet, and back.
//
// A backup is the whole app in the app's own shape; this is one collection in a shape
// other things read. That is the entire reason it exists: the rows an app collects
// are usually wanted somewhere else eventually, and "somewhere else" reads CSV.
//
// The dialect is RFC 4180 as everyone actually implements it: comma-separated, CRLF
// between rows, a field quoted when it contains a comma, a quote or a line break, and
// a quote inside quotes doubled. Reading is more forgiving than writing — a file that
// arrives with LF endings, or with no trailing newline, is a file someone made in an
// editor rather than a bug to report.

let separator = ","
let newline = "\r\n"

let needsQuotes = value =>
  value->String.includes(separator) ||
  value->String.includes("\"") ||
  value->String.includes("\n") ||
  value->String.includes("\r")

let quote = value => "\"" ++ value->String.replaceAll("\"", "\"\"") ++ "\""

let cell = value => needsQuotes(value) ? quote(value) : value

/** Every field name used by any row, in first-appearance order: a collection has no
    schema, so the header is the union of what is actually there. */
let columns = (records: array<Collection.record>) =>
  records->Array.reduce([], (found, record) =>
    record.fields->Array.reduce(found, (found, field) =>
      found->Array.includes(field.Collection.name) ? found : found->Array.concat([field.name])
    )
  )

/** The collection as CSV, header first. The id travels in its own column: without it
    an export cannot be read back as an *update* of the same rows, only as new ones. */
let encode = (collection: Collection.t) => {
  let fields = columns(collection.records)
  let header = ["id"]->Array.concat(fields)->Array.map(cell)->Array.join(separator)
  let rows = collection.records->Array.map(record =>
    ["id"]
    ->Array.concat(fields)
    ->Array.map(name =>
      name == "id" ? cell(record.id) : cell(Collection.field(record, name)->Option.getOr(""))
    )
    ->Array.join(separator)
  )
  [header]->Array.concat(rows)->Array.join(newline) ++ newline
}

// A hand-written scanner rather than a split: a comma inside quotes is a comma, and
// splitting on the separator is the bug every CSV parser is written to avoid.
let parse = text => {
  let rows = []
  let row = []
  let field = ref("")
  let quoted = ref(false)
  let started = ref(false)
  // Whether anything in the current row was quoted. `""` on a line of its own is a
  // row with one deliberately empty cell, and only this flag tells it apart from the
  // blank line a file ends with.
  let rowQuoted = ref(false)
  let characters = text->String.split("")
  let closeField = () => {
    row->Array.push(field.contents)
    field := ""
    started := true
  }
  let closeRow = () => {
    closeField()
    // A line with nothing on it is not a row: files end with a newline, and reading
    // that as an empty record would add one on every round trip.
    if !(row->Array.length == 1 && (row->Array.getUnsafe(0))->String.trim == "" && !rowQuoted.contents) {
      rows->Array.push(row->Array.copy)
    }
    rowQuoted := false
    row->Array.length->(length => row->Array.splice(~start=0, ~remove=length, ~insert=[]))
    started := false
  }
  let rec walk = index =>
    switch characters->Array.at(index) {
    | None =>
      if field.contents != "" || started.contents || row->Array.length > 0 {
        closeRow()
      }
    | Some(character) =>
      if quoted.contents {
        if character == "\"" {
          // Two quotes inside a quoted field are one quote.
          switch characters->Array.at(index + 1) {
          | Some("\"") =>
            field := field.contents ++ "\""
            walk(index + 2)
          | _ =>
            quoted := false
            walk(index + 1)
          }
        } else {
          field := field.contents ++ character
          walk(index + 1)
        }
      } else if character == "\"" && field.contents == "" {
        quoted := true
        started := true
        rowQuoted := true
        walk(index + 1)
      } else if character == separator {
        closeField()
        walk(index + 1)
      } else if character == "\r" {
        walk(index + 1)
      } else if character == "\n" {
        closeRow()
        walk(index + 1)
      } else {
        field := field.contents ++ character
        started := true
        walk(index + 1)
      }
    }
  walk(0)
  rows
}

/** The rows a CSV describes, given the ids already taken and a way to mint new ones.
    A file that carries an `id` column keeps those ids, so re-importing an export
    updates the rows it came from instead of doubling them; a file without one — the
    usual spreadsheet — gets fresh ids. */
let decode = (text, ~makeId) => {
  switch parse(text) {
  | [] => []
  | rows =>
    let header = rows->Array.getUnsafe(0)
    let idColumn = header->Array.indexOf("id")
    let taken = []
    rows
    ->Array.sliceToEnd(~start=1)
    ->Array.map(row => {
      let value = index => row->Array.at(index)->Option.getOr("")
      let id = idColumn == -1 ? "" : value(idColumn)->String.trim
      let id = id == "" || taken->Array.includes(id) ? makeId(taken) : id
      taken->Array.push(id)
      {
        Collection.id,
        fields: header
        ->Array.mapWithIndex((name, index) => (name, value(index)))
        ->Array.filter(((name, _)) => name != "id" && name->String.trim != "")
        ->Array.map((((name, value))): Collection.field => {name, value}),
      }
    })
  }
}
