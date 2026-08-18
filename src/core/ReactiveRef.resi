/***
A reference written in a directive attribute.

`#volume` is a reactive reference — a view subscribes to it. `volume` is a store key
— a source control writes to it. Keeping them apart in the type system matters
because confusing them fails silently: a view bound to a store key simply never
updates.
*/

type t =
  | Reactive(string)
  | StoreKey(string)

let parse: string => option<t>

let key: t => string
let isReactive: t => bool
let toString: t => string

/** The key to subscribe to, or None if this is not a reactive reference. */
let reactiveKey: string => option<string>
