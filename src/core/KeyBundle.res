// Pure. The envelope an account's keys travel in.
//
// What the server stores about a user's cryptography is this one JSON value: the
// public key in the clear — it is public — and the private key sealed twice, once
// under a key derived from the password and once under the recovery code. The
// sealing itself is the shell's (WebCrypto); the shape is decided and tested here,
// because a bundle the login flow cannot read back is an account nobody can enter.
//
// A version field from day one: the bundle outlives any one build of this app, and
// a future format has to be recognisable before it can be migrated.

type t = {
  pub: string,
  salt: string,
  iterations: int,
  vault: string,
  recoveryVault: string,
}

let currentVersion = 1

let encode: t => string = %raw(`
function (bundle) {
  return JSON.stringify({
    v: 1,
    pub: bundle.pub,
    salt: bundle.salt,
    iterations: bundle.iterations,
    vault: bundle.vault,
    recoveryVault: bundle.recoveryVault,
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
  const fields = ["pub", "salt", "vault", "recoveryVault"];
  for (const field of fields) {
    if (typeof parsed[field] !== "string" || parsed[field] === "") return undefined;
  }
  if (typeof parsed.iterations !== "number" || parsed.iterations < 1) return undefined;
  return {
    pub: parsed.pub,
    salt: parsed.salt,
    iterations: parsed.iterations,
    vault: parsed.vault,
    recoveryVault: parsed.recoveryVault,
  };
}
`)
