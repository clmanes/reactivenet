// SheetJS, statically imported here and nowhere else — reach this module only
// through the dynamic import() in DataPanel, or a megabyte of spreadsheet
// codec lands in the initial bundle for every browser that never touches one.

%%raw(`import * as XLSX from "xlsx";`)

/** A grid of cells into the bytes of an .xlsx file. */
let toBytes: array<array<string>> => Js.TypedArray2.Uint8Array.t = %raw(`
function (grid) {
  const sheet = XLSX.utils.aoa_to_sheet(grid);
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, sheet, "rows");
  return new Uint8Array(XLSX.write(book, { type: "array", bookType: "xlsx" }));
}
`)

/** The first sheet of an .xlsx file as a grid of cell strings — formatted the
    way the spreadsheet showed them, dates included, which is what a value a
    person typed should stay. Nothing readable answers an empty grid. */
let parse: Js.TypedArray2.ArrayBuffer.t => array<array<string>> = %raw(`
function (buffer) {
  try {
    const book = XLSX.read(buffer, { type: "array" });
    const first = book.SheetNames[0];
    if (!first) return [];
    return XLSX.utils
      .sheet_to_json(book.Sheets[first], { header: 1, raw: false, defval: "" })
      .map((row) => row.map((cell) => String(cell ?? "")));
  } catch {
    return [];
  }
}
`)
