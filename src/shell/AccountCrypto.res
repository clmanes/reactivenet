// The account's cryptography, all of it WebCrypto.
//
// One keypair per user, P-256 ECDH — the curve every engine ships. The private key
// never travels in the clear: it is sealed under a key derived from the password
// (PBKDF2-SHA256; Argon2 would need wasm and the iteration count is set to
// compensate) and again under the recovery code, and the server stores only the
// sealed forms. What decrypts a space is wrapped *to* the public key; what unwraps
// it is the private key held here.
//
// The same conventions as ShareCrypto throughout: AES-GCM, the IV prefixed to the
// ciphertext, base64url for anything that travels or is stored, and failure as
// nothing rather than garbage — a wrong password is an unwrap that answers None,
// which is all the login flow needs to know.

type identity = {pub: string, priv: string}

/** PBKDF2 rounds for the password seal. High because the password is the weak
    secret; the recovery code has 160 random bits and reuses the same number only
    for uniformity. */
let iterations = 600000

/** The fixed salt under the recovery seal — base64url of "rn-recovery". A fixed
    salt is safe exactly because the code is full-entropy: there is nothing a
    rainbow table could precompute against 160 random bits. */
let recoverySalt = "cm4tcmVjb3Zlcnk"

let randomBytes: int => array<int> = %raw(`
function (length) {
  return Array.from(crypto.getRandomValues(new Uint8Array(length)));
}
`)

/** A fresh 16-byte salt, base64url. */
let newSalt: unit => string = %raw(`
function () {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
`)

/** A fresh P-256 ECDH keypair, both halves as JWK JSON strings. */
let generateIdentity: unit => promise<identity> = %raw(`
async function () {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" }, true, ["deriveKey", "deriveBits"]
  );
  const pub = await crypto.subtle.exportKey("jwk", pair.publicKey);
  const priv = await crypto.subtle.exportKey("jwk", pair.privateKey);
  return { pub: JSON.stringify(pub), priv: JSON.stringify(priv) };
}
`)

let wrapWithSecret: (
  ~secret: string,
  ~salt: string,
  ~iterations: int,
  ~text: string,
) => promise<string> = %raw(`
async function (secret, salt, iterations, text) {
  const bytesOf = (encoded) => {
    const binary = atob(encoded.replaceAll("-", "+").replaceAll("_", "/"));
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return bytes;
  };
  const material = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret), "PBKDF2", false, ["deriveKey"]
  );
  const key = await crypto.subtle.deriveKey(
    { name: "PBKDF2", salt: bytesOf(salt), iterations, hash: "SHA-256" },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(text))
  );
  const joined = new Uint8Array(iv.length + sealed.length);
  joined.set(iv);
  joined.set(sealed, iv.length);
  let binary = "";
  for (const byte of joined) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
`)

/** None on a wrong secret or a tampered vault — GCM authenticates, so there is no
    "decrypted to garbage" case to distrust. */
let unwrapWithSecret: (
  ~secret: string,
  ~salt: string,
  ~iterations: int,
  ~payload: string,
) => promise<option<string>> = %raw(`
async function (secret, salt, iterations, payload) {
  try {
    const bytesOf = (encoded) => {
      const binary = atob(encoded.replaceAll("-", "+").replaceAll("_", "/"));
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      return bytes;
    };
    const material = await crypto.subtle.importKey(
      "raw", new TextEncoder().encode(secret), "PBKDF2", false, ["deriveKey"]
    );
    const key = await crypto.subtle.deriveKey(
      { name: "PBKDF2", salt: bytesOf(salt), iterations, hash: "SHA-256" },
      material,
      { name: "AES-GCM", length: 256 },
      false,
      ["decrypt"]
    );
    const joined = bytesOf(payload);
    const opened = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: joined.slice(0, 12) }, key, joined.slice(12)
    );
    return new TextDecoder().decode(opened);
  } catch (error) {
    return undefined;
  }
}
`)
