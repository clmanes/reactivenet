/** Evaluates `+ - * /` with parentheses over numbers and `#key` references, resolved
    through the lookup. A key holding nothing, or something that is not a number,
    counts as zero. `None` when the expression does not parse, or divides by zero. */
let evaluate: (string, string => option<string>) => option<float>

/** Every `#key` the expression mentions. */
let references: string => array<string>
