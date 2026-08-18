/** Writes a file to wherever the browser puts downloads. The content type follows
    the extension. */
let download: (string, string) => unit

/** Asks for a text file and hands its contents to the callback. `accept` is what the
    picker offers — a backup by default, a spreadsheet when one collection is being
    filled from a file. Nothing happens if the picker was dismissed. */
let readTextFile: (~accept: string=?, string => unit) => unit

/** Asks for an app document and resolves to its name and contents, or to nothing if
    the picker was dismissed or the file could not be read. */
let readDocument: unit => promise<option<(string, string)>>

/** Writes an .xlsx download. */
let downloadBinary: (string, Js.TypedArray2.Uint8Array.t) => unit

/** Asks for a binary file and hands its bytes to the callback. Nothing happens
    if the picker was dismissed. */
let readBinaryFile: (~accept: string, Js.TypedArray2.ArrayBuffer.t => unit) => unit

/** What the attachment picker chose: the file's name and its whole content as a
    `data:` URL — or `tooBig` with no data when the file is past `maxBytes`, which
    is the ceiling an attachment must fit under to travel inside a sync change. */
type picked = {name: string, dataUrl: string, tooBig: bool}

/** Asks for any file. Resolves to nothing when the picker is dismissed. */
let readAttachment: (~maxBytes: int) => promise<option<picked>>
