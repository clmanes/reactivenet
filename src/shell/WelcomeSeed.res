// What the welcome app looked like when this browser was given it.
//
// One value, in the same IndexedDB store as the theme and the language — a preference
// about the app rather than data belonging to one. It is a fingerprint, not a copy:
// the question it answers is only "is the stored welcome app still the one we wrote?",
// and keeping the whole document to compare against would be a second copy to keep in
// step with the first.

let key = "welcome-seed"

let read = () => Idb.get(key)->Promise.thenResolve(value => value->Nullable.toOption->Option.getOr(""))

let record = digest => Idb.set(key, digest)
