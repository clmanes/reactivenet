/** The envelope an account's keys travel in: the public key in the clear, the
    private key sealed under the password and again under the recovery code. The
    sealing is the shell's; the shape is decided here. */

type t = {
  pub: string,
  salt: string,
  iterations: int,
  vault: string,
  recoveryVault: string,
}

let currentVersion: int

let encode: t => string

/** The bundle a stored value names, or nothing when it is not one — a missing
    field, a foreign version, or text that is not JSON at all. */
let decode: string => option<t>
