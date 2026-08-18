/** A collection as a rectangular grid of cells — the shape a spreadsheet is —
    and back. Ids travel in their own first column, so a re-import updates the
    rows it came from; a file without one gets fresh ids from `makeId`. */

let encode: Collection.t => array<array<string>>

let decode: (array<array<string>>, ~makeId: array<string> => string) => array<Collection.record>
