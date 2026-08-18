/** The asymmetric leg of a space's cryptography: sealing the symmetric space key
    to a member's public key (ECIES over P-256, WebCrypto), so the server carries
    what it cannot open. The symmetric leg is ShareCrypto's. */

/** Seals a secret to a member's public key (JWK JSON string). */
let wrapForMember: (~pub: string, ~secret: string) => promise<string>

/** Opens a wrapped secret with the member's private key; None when the blob was
    not sealed to exactly this key. */
let unwrapAsMember: (~priv: string, ~payload: string) => promise<option<string>>
