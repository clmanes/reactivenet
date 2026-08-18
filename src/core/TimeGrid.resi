type block = {
  row: string,
  col: string,
  /** The id of the one row this forbids; empty forbids the cell to everyone. */
  forId: string,
  why: string,
}

type t = {
  rows: array<string>,
  cols: array<string>,
  rowLabels: array<string>,
  colLabels: array<string>,
  /** The records of each cell, addressed `cells[row][col]`. */
  cells: array<array<array<Collection.record>>>,
  /** Records naming no row or no column: in no cell at all. */
  unplaced: array<Collection.record>,
}

/** A comma-separated attribute as the values it lists, trimmed, blanks dropped. */
let list: string => array<string>

/** The values of one axis: those the author declared, in their order, then any the
    data holds that they did not — a row is never hidden because nobody predicted its
    value. Sorted by `RowView.compare`, so hours sort as numbers. */
let axis: (array<Collection.record>, ~field: string, ~declared: string) => array<string>

/** The nth label names the nth value; a value the list does not reach keeps its own
    text. */
let labelled: (array<string>, ~labels: string) => array<string>

let build: (
  array<Collection.record>,
  ~rowField: string,
  ~colField: string,
  ~rowValues: string,
  ~colValues: string,
  ~rowLabels: string,
  ~colLabels: string,
) => t

/** The forbidden cells, read out of an ordinary collection: row, col, for, why. */
let blocks: array<Collection.record> => array<block>

/** Why this row may not go in this cell, or None when it may. `Some("")` is a refusal
    with no words: the caller has the language, this module does not. */
let refusal: (array<block>, ~row: string, ~col: string, ~id: string) => option<string>

/** Whether the cell is forbidden to some *other* row — a warning during a drag, not a
    refusal of it. */
let warned: (array<block>, ~row: string, ~col: string, ~id: string) => bool

/** Whether a record is pinned by the field named, which holds a tick. */
let pinned: (Collection.record, ~field: string) => bool
