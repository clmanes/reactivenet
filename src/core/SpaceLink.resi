/** The shape of an invitation link: `/j/<inviteId>#k<key>`. The id names the
    invite; the key rides in the fragment, which is never sent. The whole link is
    the capability to join, once, with the role the invite names. */

let segment: string

let path: string

let keyMarker: string

let isInviteId: string => bool

let of_: (~origin: string, ~id: string, ~key: string) => string

/** The key an invitation's fragment carries, or nothing when it is not one. */
let keyOf: string => option<string>
