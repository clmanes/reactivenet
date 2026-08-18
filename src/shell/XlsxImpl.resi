/** SheetJS, statically imported here and nowhere else: reach this module only
    through a dynamic `import()`. */

let toBytes: array<array<string>> => Js.TypedArray2.Uint8Array.t

let parse: Js.TypedArray2.ArrayBuffer.t => array<array<string>>
