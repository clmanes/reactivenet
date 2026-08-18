/** The account calls against PocketBase: register, sign in, refresh. Plain fetch on
    /pb, every failure None — except registration, which says whether the username
    was the problem. */

type registration = {ok: bool, taken: bool}

type session = {
  token: string,
  userId: string,
  username: string,
  keyBundle: string,
}

let register: (
  ~username: string,
  ~password: string,
  ~keyBundle: string,
) => promise<registration>

let signIn: (~username: string, ~password: string) => promise<option<session>>

type refreshed = {denied: bool, fresh: option<session>}

/** A stored token traded for a fresh one. `denied` signs the user out; an
    unreachable server is neither denied nor fresh, and the session stays. */
let refresh: (~token: string) => promise<refreshed>
