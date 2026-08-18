// Pure. The shape of a recovery code.
//
// Zero-knowledge has a price and this is where it is paid: the server cannot reset
// what it cannot read, so losing the password would mean losing every shared space —
// unless the user holds a second secret. The recovery code is that secret: 160
// random bits, shown once at registration, wrapping the same private key the
// password wraps.
//
// The bytes come from the shell (crypto.getRandomValues); what is decided here is
// the human form, which is the part worth testing. Crockford base32: no I, L, O or
// U, so nothing in a printed code is ambiguous, and reading O as 0 or l as 1 when
// typing it back is corrected rather than punished. Eight groups of four — a shape
// the eye can check line by line against a paper copy.

let byteLength = 20

let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

let format = bytes => {
  if Array.length(bytes) != byteLength || bytes->Array.some(b => b < 0 || b > 255) {
    None
  } else {
    let chars = []
    let buffer = ref(0)
    let bits = ref(0)
    bytes->Array.forEach(byte => {
      buffer := buffer.contents->lsl(8)->lor(byte)
      bits := bits.contents + 8
      while bits.contents >= 5 {
        bits := bits.contents - 5
        let index = buffer.contents->asr(bits.contents)->land(31)
        chars->Array.push(alphabet->String.charAt(index))
      }
    })
    let joined = chars->Array.join("")
    let groups = []
    for group in 0 to 7 {
      groups->Array.push(joined->String.slice(~start=group * 4, ~end=group * 4 + 4))
    }
    Some(groups->Array.join("-"))
  }
}

/** The bytes a typed code names, or nothing when it is not a code. Case, separators
    and the lookalike characters are forgiven — O is 0, I and L are 1 — because a
    code read from paper deserves the same tolerance the alphabet was chosen for. */
let parse = text => {
  let cleaned =
    text
    ->String.toUpperCase
    ->String.replaceAll("O", "0")
    ->String.replaceAll("I", "1")
    ->String.replaceAll("L", "1")
    ->String.split("")
    ->Array.filter(char => alphabet->String.includes(char))
    ->Array.join("")
  if String.length(cleaned) != 32 {
    None
  } else {
    let bytes = []
    let buffer = ref(0)
    let bits = ref(0)
    cleaned
    ->String.split("")
    ->Array.forEach(char => {
      buffer := buffer.contents->lsl(5)->lor(alphabet->String.indexOf(char))
      bits := bits.contents + 5
      if bits.contents >= 8 {
        bits := bits.contents - 8
        bytes->Array.push(buffer.contents->asr(bits.contents)->land(255))
      }
    })
    Some(bytes)
  }
}
