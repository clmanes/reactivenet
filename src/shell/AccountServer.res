// The account calls against PocketBase, plain fetch like ShareServer.
//
// Three endpoints: register, sign in, refresh. The server never sees a key or a
// password it could use — the password reaches it only as PocketBase's own auth
// hash, and the keyBundle it stores is sealed before it leaves the browser.
//
// Failures collapse to nothing with one exception: registration distinguishes "that
// username is taken" from "it did not work", because the first has an obvious next
// move and the second does not — and a form that answers both with the same
// sentence sends the user guessing.

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
) => promise<registration> = %raw(`
async function (username, password, keyBundle) {
  try {
    const response = await fetch("/pb/api/collections/users/records", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username,
        password,
        passwordConfirm: password,
        keyBundle: JSON.parse(keyBundle),
      }),
    });
    if (response.ok) return { ok: true, taken: false };
    const failure = await response.json().catch(() => null);
    const code =
      failure && failure.data && failure.data.username && failure.data.username.code;
    return { ok: false, taken: code === "validation_not_unique" };
  } catch (error) {
    return { ok: false, taken: false };
  }
}
`)

let signIn: (~username: string, ~password: string) => promise<option<session>> = %raw(`
async function (username, password) {
  try {
    const response = await fetch("/pb/api/collections/users/auth-with-password", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identity: username, password }),
    });
    if (!response.ok) return undefined;
    const answer = await response.json();
    if (!answer || typeof answer.token !== "string" || !answer.record) return undefined;
    return {
      token: answer.token,
      userId: String(answer.record.id || ""),
      username: String(answer.record.username || ""),
      keyBundle: JSON.stringify(answer.record.keyBundle || null),
    };
  } catch (error) {
    return undefined;
  }
}
`)

type refreshed = {denied: bool, fresh: option<session>}

/** A stored token traded for a fresh one — how a returning visit stays signed in
    without ever storing the password. The two failures mean opposite things and
    are kept apart: `denied` is the server saying the token is no longer good, and
    signs the user out; an unreachable server is neither denied nor fresh, and the
    session stays — offline must not log anybody out of their own device. */
let refresh: (~token: string) => promise<refreshed> = %raw(`
async function (token) {
  try {
    const response = await fetch("/pb/api/collections/users/auth-refresh", {
      method: "POST",
      headers: { Authorization: token },
    });
    if (response.status === 401 || response.status === 403 || response.status === 404) {
      return { denied: true, fresh: undefined };
    }
    if (!response.ok) return { denied: false, fresh: undefined };
    const answer = await response.json();
    if (!answer || typeof answer.token !== "string" || !answer.record) {
      return { denied: false, fresh: undefined };
    }
    return {
      denied: false,
      fresh: {
        token: answer.token,
        userId: String(answer.record.id || ""),
        username: String(answer.record.username || ""),
        keyBundle: JSON.stringify(answer.record.keyBundle || null),
      },
    };
  } catch (error) {
    return { denied: false, fresh: undefined };
  }
}
`)
