type kind =
  | Count
  | Sum
  | Average
  | Minimum
  | Maximum
  | Median
  | Deviation
  | Mode

/** The directive name, or nothing when it is not an aggregation. */
let parse: string => option<kind>

/** Formats a number the way it was meant: integers without a point, everything else
    trimmed of the zeros division leaves behind. */
let format: (float, ~decimals: int=?) => string

/** The value to display, already formatted. `None` when there is nothing to say: an
    empty collection has no average, and a dash is more honest than a zero. */
let compute: (
  kind,
  Collection.t,
  ~field: string=?,
  ~decimals: int=?,
) => option<string>
