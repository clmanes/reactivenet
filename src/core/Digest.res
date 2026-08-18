// Pure. A short fingerprint of a document, for one question: has anybody touched it?
//
// The welcome app is written back whenever it is missing, which keeps the gallery
// from ever being empty — but an app that already exists is never touched again, so
// a browser that opened this once keeps the welcome app of that day forever, missing
// every directive added since. Rewriting it unconditionally is the other extreme and
// worse: it would silently discard whatever the reader had changed in it.
//
// So the seeding records what it wrote, and only replaces a copy that still matches.
// A hash is what makes that comparison cheap to store — the alternative is keeping a
// second copy of the document to compare against, which is a second thing to keep in
// step.
//
// It is not a security primitive and is not used as one: nothing here depends on
// nobody being able to produce a collision, only on an *edit* not landing on the same
// value, which any decent mixer gives.

// A polynomial hash, modulo a prime — and the prime is small on purpose. ReScript's
// `int` is JavaScript's 32-bit integer: `*` compiles to `Math.imul`, which *wraps*.
// With a modulus near a billion the multiplication overflowed on any document longer
// than a few characters and the fingerprint came out negative, which is a fingerprint
// that changes when nothing did. Everything here stays under 2^31: 16777213 × 101
// plus the largest code point is about 1.7 billion.
let modulus = 16777213
let factor = 101

let of_ = text => {
  let hash = ref(0)
  for index in 0 to text->String.length - 1 {
    let code = text->String.codePointAt(index)->Option.getOr(0)
    hash := mod(hash.contents * factor + code, modulus)
  }
  hash.contents->Int.toString(~radix=16)
}

/** Whether this text is the one that was recorded. An empty record means nothing was
    ever recorded, which is not a match: a document nobody vouched for is a document
    to leave alone. */
let matches = (text, ~recorded) => recorded != "" && of_(text) == recorded
