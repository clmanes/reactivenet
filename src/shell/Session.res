// Who is signed in on this device, persisted like every other preference: in
// IndexedDB, through Idb, and nowhere else.
//
// What is stored is the token and the *opened* private key. Storing the key rather
// than re-deriving it each visit is the same trust every end-to-end client extends
// to the device it runs on: the password unseals the vault once, at sign-in, and
// from then on this device is one of the user's devices. Signing out deletes the
// key with the token — after that the vault on the server is all that exists, and
// only the password or the recovery code opens it.
//
// The password itself is never stored, anywhere, in any form.

type t = {
  token: string,
  userId: string,
  username: string,
  pub: string,
  priv: string,
}

let storageKey = "account"

let encode: t => string = %raw(`
function (session) {
  return JSON.stringify({
    v: 1,
    token: session.token,
    userId: session.userId,
    username: session.username,
    pub: session.pub,
    priv: session.priv,
  });
}
`)

let decode: string => option<t> = %raw(`
function (text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return undefined;
  }
  if (!parsed || typeof parsed !== "object" || parsed.v !== 1) return undefined;
  for (const field of ["token", "userId", "username", "pub", "priv"]) {
    if (typeof parsed[field] !== "string" || parsed[field] === "") return undefined;
  }
  return {
    token: parsed.token,
    userId: parsed.userId,
    username: parsed.username,
    pub: parsed.pub,
    priv: parsed.priv,
  };
}
`)

let save = session => Idb.set(storageKey, encode(session))

let load = async () =>
  switch await Idb.get(storageKey) {
  | Value(stored) => decode(stored)
  | Null | Undefined => None
  }

let clear = () => Idb.remove(storageKey)
