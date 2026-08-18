/** Pure. A line diff between two documents — computed from the documents
    themselves, so the person deciding whether to apply a proposed rewrite is not
    deciding on the proposer's own account of it. Plain LCS over whole lines. */

type change = {
  /** "+" only in the new document, "-" only in the old, " " in both. */
  sign: string,
  text: string,
}

let diff: (string, string) => array<change>

/** The changed lines alone, in document order. */
let changesOnly: (string, string) => array<change>

type counts = {added: int, removed: int}

let count: array<change> => counts
