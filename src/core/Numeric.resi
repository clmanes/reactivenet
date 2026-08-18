/** The number a stored value holds, when the whole of it is one. A numeric *prefix*
    is not a number: "2026-08-10" is a date and "10 items" is text, and reading either
    as a number is how a sort or an average goes quietly wrong. */
let parse: string => option<float>

let isNumber: string => bool
