/** The account's cryptography: a P-256 ECDH keypair per user, the private half
    sealed under the password and under the recovery code. All WebCrypto; every
    failure is None, never garbage. */

type identity = {pub: string, priv: string}

/** PBKDF2 rounds for the password seal. */
let iterations: int

/** The fixed salt under the recovery seal — safe because the code is full-entropy. */
let recoverySalt: string

let randomBytes: int => array<int>

/** A fresh 16-byte salt, base64url. */
let newSalt: unit => string

/** A fresh keypair, both halves as JWK JSON strings. */
let generateIdentity: unit => promise<identity>

let wrapWithSecret: (
  ~secret: string,
  ~salt: string,
  ~iterations: int,
  ~text: string,
) => promise<string>

/** None on a wrong secret or a tampered vault. */
let unwrapWithSecret: (
  ~secret: string,
  ~salt: string,
  ~iterations: int,
  ~payload: string,
) => promise<option<string>>
