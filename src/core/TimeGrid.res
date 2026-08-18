// Pure. Which cells a two-dimensional grid has, and which row of a collection falls
// in each of them.
//
// `::board` asks one question of a row — what does its `group-by` field hold — and
// draws a column per answer. A timetable asks two at once, and the pair is what makes
// a cell: the lesson at hour 3 on Wednesday is the row whose `rows` field says 3 and
// whose `cols` field says mer. Everything below is that sentence, plus the ordering
// and the two lists an author may declare instead of letting the data decide.
//
// The ordering is `RowView.compare`, not a second one: hours are numbers and days are
// words, and a grid that put "10" before "9" would be wrong in exactly the way a
// column of prices is.

type block = {
  row: string,
  col: string,
  /** The id of the one row this forbids; empty means it forbids the cell to everyone. */
  forId: string,
  why: string,
}

type t = {
  rows: array<string>,
  cols: array<string>,
  /** One per row value, in the same order — the author's heading or the value itself. */
  rowLabels: array<string>,
  colLabels: array<string>,
  /** The records of each cell, addressed `cells[row][col]`. */
  cells: array<array<array<Collection.record>>>,
  /** Records that named no row or no column: they belong to no cell, and are handed
      back rather than dropped, because a lesson nobody has placed yet is the normal
      state of a half-built timetable. */
  unplaced: array<Collection.record>,
}

let list = value =>
  value->String.split(",")->Array.map(String.trim)->Array.filter(entry => entry != "")

// Declared first and in the author's order — that is what `row-values` is for, and it
// is also what keeps an empty hour on screen once its last lesson has moved away.
// Anything the data holds and the author did not predict is appended rather than
// hidden: a lesson that vanished because somebody typed a seventh hour would be the
// worst failure this view could have. Same rule as the board's columns.
let axis = (records, ~field, ~declared) => {
  let named = list(declared)
  let present = field == "" ? [] : RowView.values(records, ~field)
  named->Array.concat(present->Array.filter(value => !(named->Array.includes(value))))
}

// Headings are positional: the nth label names the nth value. A list of the wrong
// length is not an error — the values it does reach are renamed and the rest keep
// their own text, which is more useful than refusing to draw the grid.
let labelled = (values, ~labels) => {
  let given = list(labels)
  values->Array.mapWithIndex((value, index) =>
    switch given[index] {
    | Some(label) => label
    | None => value
    }
  )
}

let build = (records, ~rowField, ~colField, ~rowValues, ~colValues, ~rowLabels, ~colLabels) => {
  let rows = axis(records, ~field=rowField, ~declared=rowValues)
  let cols = axis(records, ~field=colField, ~declared=colValues)
  let cells =
    rows->Array.map(row =>
      cols->Array.map(col =>
        records->Array.filter(record =>
          RowView.valueOf(record, rowField) == row && RowView.valueOf(record, colField) == col
        )
      )
    )
  {
    rows,
    cols,
    rowLabels: rows->labelled(~labels=rowLabels),
    colLabels: cols->labelled(~labels=colLabels),
    cells,
    // A record is unplaced when either of its two values is not one of the grid's —
    // which, since the axes adopt every value present, means the field is empty.
    unplaced: records->Array.filter(record =>
      !(rows->Array.includes(RowView.valueOf(record, rowField))) ||
        !(cols->Array.includes(RowView.valueOf(record, colField)))
    ),
  }
}

/** The forbidden cells, read out of an ordinary collection: `row`, `col`, and
    optionally `for` (the one lesson the prohibition is about) and `why` (the sentence
    to show). A validator writes them and the grid reads them — the constraint is data,
    not code, which is what lets an author change the rules without changing the app. */
let blocks = (records: array<Collection.record>) =>
  records->Array.map(record => {
    row: RowView.valueOf(record, "row"),
    col: RowView.valueOf(record, "col"),
    forId: RowView.valueOf(record, "for"),
    why: RowView.valueOf(record, "why"),
  })

/** Why this row may not go in this cell, or `None` when it may. `Some("")` is a
    refusal the author gave no words for; the caller supplies those, because they are
    words and this module has no language. */
let refusal = (blocks, ~row, ~col, ~id) =>
  blocks
  ->Array.find(block =>
    block.row == row && block.col == col && (block.forId == "" || block.forId == id)
  )
  ->Option.map(block => block.why)

/** Whether a cell is forbidden to *someone else* — the standing prohibition that does
    not apply to the row being dragged. It is worth showing during a drag, because a
    cell that is free for this lesson and spoken for by another is not the same thing
    as an empty one. */
let warned = (blocks, ~row, ~col, ~id) =>
  blocks->Array.some(block =>
    block.row == row && block.col == col && block.forId != "" && block.forId != id
  )

/** Whether a row is pinned: the lesson somebody fixed by hand, which no drag and no
    solver may move. Written the way a tick box is stored, so `::input{type="checkbox"}`
    is the control that sets it. */
let pinned = (record, ~field) =>
  field != "" && SourceSeed.ticked(RowView.valueOf(record, field))
