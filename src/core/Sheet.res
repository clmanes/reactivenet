// Pure. A collection as a GRID — the shape a spreadsheet is — and back.
//
// The same two decisions core/Csv made, because they are about spreadsheets,
// not about commas:
//
//   - Ids travel in their own first column, so re-importing an export UPDATES
//     the rows it came from instead of doubling them; a file without that
//     column — the usual spreadsheet — gets fresh ids.
//   - The header is the union of every field name, in order of first
//     appearance: rows are ragged in a collection and rectangular on a sheet,
//     and a field a row does not have is simply an empty cell.

let idColumn = "id"

/** The collection as rows of cells, header first. */
let encode = (collection: Collection.t) => {
  let header = [idColumn]
  collection.records->Array.forEach(record =>
    record.fields->Array.forEach(field =>
      if !(header->Array.includes(field.name)) {
        header->Array.push(field.name)
      }
    )
  )
  let rows =
    collection.records->Array.map(record =>
      header->Array.map(name =>
        name == idColumn
          ? record.id
          : record.fields
            ->Array.find(field => field.name == name)
            ->Option.map(field => field.value)
            ->Option.getOr("")
      )
    )
  [header]->Array.concat(rows)
}

/** Rows of cells back into records. The first row is the header; an `id`
    column claims ids, its absence mints them via `makeId` (given the ids
    already used, so a whole import cannot collide with itself). Blank rows
    are skipped, blank cells are absent fields. */
let decode = (grid: array<array<string>>, ~makeId) => {
  switch grid->Array.at(0) {
  | None => []
  | Some(header) => {
      let used = []
      grid
      ->Array.sliceToEnd(~start=1)
      ->Array.filterMap(cells => {
        let fields = []
        let id = ref("")
        header->Array.forEachWithIndex((name, index) => {
          let cell = cells->Array.at(index)->Option.getOr("")->String.trim
          if name == idColumn {
            id := cell
          } else if name->String.trim != "" && cell != "" {
            fields->Array.push({Collection.name: name->String.trim, value: cell})
          }
        })
        if fields->Array.length == 0 && id.contents == "" {
          None
        } else {
          let final = id.contents == "" || used->Array.includes(id.contents)
            ? makeId(used)
            : id.contents
          used->Array.push(final)
          Some({Collection.id: final, fields})
        }
      })
    }
  }
}
