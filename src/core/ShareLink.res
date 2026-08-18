// Pure. The shape of a link that carries an app.
//
// "Copy link" copies an address, and an address only works for somebody who already
// has the app: everything here lives in one browser, so a link to /a/spesa opens
// nothing at all on anybody else's. A shared app therefore has to travel *in* the
// link, which is what this is — the document, compressed and encoded, in the URL's
// fragment.
//
// The fragment, not the path, for three reasons that all matter: it is never sent to
// the server, so nobody's document ends up in an access log; it is not part of what a
// static host has to route; and it is where a long value belongs, since paths have
// limits that fragments in practice do not.
//
// The encoding itself is `shell/SharePayload` — it needs the platform's compression
// and base64. What is decided here is the format around it, which is the part worth
// testing: the marker that says this is one of ours, and the ceiling above which a
// link is not a sensible way to send something.

let segment = "s"

/** The version marker. A link written today has to be readable by a version of this
    app that does not exist yet, and the only way to keep that option is to say which
    format it is in. */
let marker = "1"

/** Past this, a link stops being something anybody can paste. Browsers and address
    bars vary, chat apps truncate, and an app that big is one to send as a file — the
    dialog says so rather than handing over a link that arrives broken. */
let ceiling = 8000

let path = "/" ++ segment

/** The whole link, given where this app is served from and the encoded document. */
let of_ = (~origin, ~payload) => origin ++ path ++ "#" ++ marker ++ payload

/** The payload a link carries, or nothing when the fragment is not one of ours —
    which includes the empty fragment, and a fragment written by some future version
    whose marker this one does not know. */
let payloadOf = fragment => {
  let value = fragment->String.startsWith("#")
    ? fragment->String.sliceToEnd(~start=1)
    : fragment
  value->String.startsWith(marker) && value->String.length > marker->String.length
    ? Some(value->String.sliceToEnd(~start=marker->String.length))
    : None
}

/** Whether a payload is small enough to be worth sending as a link. */
let fits = payload => payload->String.length <= ceiling

/** What to put in a message beside the link: the app's name, and what the link is.
    Built here so the mail, the native share sheet and the dialog all say the same
    thing. */
let message = (~title, ~invitation) => (title == "" ? invitation : title ++ " — " ++ invitation)

// --- The short form ----------------------------------------------------------
//
// `/s/<id>#k<key>`: the *encrypted* document sits on the server under the id, and
// the key rides in the fragment — which is never sent, so the server holds a blob it
// cannot read. The long form above stays: it is the one that needs no server, works
// offline, and is what the dialog falls back to when /pb does not answer.

/** What a server-stored payload may grow to: ~100 KB of encrypted base64. The server
    enforces the same number in its schema; this copy is what lets the dialog say
    "too big" without a round trip. */
let storedCeiling = 140000

let fitsStored = payload => payload->String.length <= storedCeiling

// PocketBase ids are 15 lowercase alphanumerics; accepted loosely enough to survive
// a future id scheme, tightly enough that a path segment cannot smuggle anything.
let shortIdPattern = RegExp.fromString("^[A-Za-z0-9_-]{8,40}$")

let isShortId = candidate => RegExp.test(shortIdPattern, candidate)

/** The marker for a key fragment, distinct from the long form's payload marker. */
let keyMarker = "k"

let shortOf = (~origin, ~id, ~key) => origin ++ path ++ "/" ++ id ++ "#" ++ keyMarker ++ key

/** The decryption key a short link's fragment carries, or nothing when the fragment
    is not one — including the empty fragment of a link something truncated. */
let keyOf = fragment => {
  let value = fragment->String.startsWith("#")
    ? fragment->String.sliceToEnd(~start=1)
    : fragment
  value->String.startsWith(keyMarker) && value->String.length > keyMarker->String.length
    ? Some(value->String.sliceToEnd(~start=keyMarker->String.length))
    : None
}
