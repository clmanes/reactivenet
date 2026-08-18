// Pure. What changed between two documents, line by line.
//
// This exists for one reader: the person deciding whether to apply the assistant's
// proposed rewrite. Until now that decision was made on the model's own word — a
// note saying what it changed — which is exactly the witness that cannot be
// trusted. The diff is computed from the two documents themselves.
//
// It is a plain LCS diff over whole lines, dynamic programming, O(n·m). Documents
// here are apps — hundreds of lines, not thousands — so the table costs nothing
// worth engineering away; a Myers implementation would earn its complexity only on
// inputs this feature never sees. Ties in the table prefer keeping the *earlier*
// line, which groups deletions before insertions the way readers expect a diff to
// read.

type change = {
  /** "+" for a line only in the new document, "-" for one only in the old,
      " " for a line in both. */
  sign: string,
  text: string,
}

let diff: (string, string) => array<change> = %raw(`
function (before, after) {
  const a = before.split("\n");
  const b = after.split("\n");
  const n = a.length, m = b.length;
  // lcs[i][j] = length of the longest common subsequence of a[i..] and b[j..]
  const lcs = Array.from({ length: n + 1 }, () => new Int32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] === b[j] ? lcs[i + 1][j + 1] + 1 : Math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  const out = [];
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) {
      out.push({ sign: " ", text: a[i] });
      i++; j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.push({ sign: "-", text: a[i] });
      i++;
    } else {
      out.push({ sign: "+", text: b[j] });
      j++;
    }
  }
  while (i < n) out.push({ sign: "-", text: a[i++] });
  while (j < m) out.push({ sign: "+", text: b[j++] });
  return out;
}
`)

/** Only what changed, which is what the proposal shows: context lines say nothing
    the person deciding does not already have on screen. */
let changesOnly = (before, after) => diff(before, after)->Array.filter(line => line.sign != " ")

type counts = {added: int, removed: int}

let count = changes =>
  changes->Array.reduce({added: 0, removed: 0}, (tally, line) =>
    switch line.sign {
    | "+" => {...tally, added: tally.added + 1}
    | "-" => {...tally, removed: tally.removed + 1}
    | _ => tally
    }
  )
