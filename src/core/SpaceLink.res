// Pure. The shape of an invitation link.
//
// Joining a shared space follows the same grammar as opening a shared app, because
// it is the same privacy argument: `/j/<inviteId>#k<key>`. The id names an invite
// record the server holds; the key that opens what the invite carries rides in the
// fragment, which is never sent. The server can hand out the sealed space key to
// whoever presents the id — it still cannot read it, and neither can anyone who
// saw the link go past without the fragment.
//
// The link is the capability: whoever has the whole of it can join, with the role
// the invite names, exactly once. That is what an invitation *is*, and it is why
// no directory of users has to exist anywhere.

let segment = "j"

let path = "/" ++ segment

/** The marker for the key fragment — the same letter the short share links use,
    because it means the same thing: a key that never left the sender's hands. */
let keyMarker = "k"

// PocketBase ids, accepted as loosely as the share ids are: enough to survive a
// future id scheme, tight enough that a path segment cannot smuggle anything.
let inviteIdPattern = RegExp.fromString("^[A-Za-z0-9_-]{8,40}$")

let isInviteId = candidate => RegExp.test(inviteIdPattern, candidate)

let of_ = (~origin, ~id, ~key) => origin ++ path ++ "/" ++ id ++ "#" ++ keyMarker ++ key

/** The key an invitation's fragment carries, or nothing when the fragment is not
    one — including the empty fragment of a link something truncated. */
let keyOf = fragment => {
  let value = fragment->String.startsWith("#")
    ? fragment->String.sliceToEnd(~start=1)
    : fragment
  value->String.startsWith(keyMarker) && value->String.length > keyMarker->String.length
    ? Some(value->String.sliceToEnd(~start=keyMarker->String.length))
    : None
}
