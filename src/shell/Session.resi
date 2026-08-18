/** Who is signed in on this device: the token and the opened private key, in
    IndexedDB. The password is never stored, in any form; signing out deletes the
    key with the token. */

type t = {
  token: string,
  userId: string,
  username: string,
  pub: string,
  priv: string,
}

let save: t => promise<unit>

let load: unit => promise<option<t>>

let clear: unit => promise<unit>
