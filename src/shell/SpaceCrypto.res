// How a space key reaches a member, and nobody else.
//
// The space key is symmetric — AES-GCM, minted by ShareCrypto.generateKey, sealing
// every change in the log. What this module adds is the asymmetric leg: sealing
// that key *to* a member's public key so the server can carry it without ever
// being able to open it.
//
// The construction is ECIES over P-256, out of WebCrypto primitives: a fresh
// ephemeral keypair per wrap, ECDH against the recipient's public key, and the
// derived AES-GCM key seals the payload. The ephemeral public half travels in the
// blob — it is public by construction — so the recipient alone, holding the
// private half of the pair the blob names, can re-derive the seal and open it.
// One wrap, one ephemeral pair: two wraps of the same key to the same member
// share nothing but the plaintext.

/** Seals a secret to a member's public key (a JWK JSON string). The blob is JSON:
    the ephemeral public JWK and the iv-prefixed ciphertext, base64url. */
let wrapForMember: (~pub: string, ~secret: string) => promise<string> = %raw(`
async function (pub, secret) {
  const recipient = await crypto.subtle.importKey(
    "jwk", JSON.parse(pub), { name: "ECDH", namedCurve: "P-256" }, false, []
  );
  const ephemeral = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" }, false, ["deriveKey"]
  );
  const seal = await crypto.subtle.deriveKey(
    { name: "ECDH", public: recipient },
    ephemeral.privateKey,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, seal, new TextEncoder().encode(secret))
  );
  const joined = new Uint8Array(iv.length + sealed.length);
  joined.set(iv);
  joined.set(sealed, iv.length);
  let binary = "";
  for (const byte of joined) binary += String.fromCharCode(byte);
  const ct = btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  const epk = await crypto.subtle.exportKey("jwk", ephemeral.publicKey);
  return JSON.stringify({ epk, ct });
}
`)

/** Opens a wrapped secret with the member's private key. None on anything that is
    not a blob sealed to exactly this key — GCM authenticates, so there is no
    plausible garbage to distrust. */
let unwrapAsMember: (~priv: string, ~payload: string) => promise<option<string>> = %raw(`
async function (priv, payload) {
  try {
    const parsed = JSON.parse(payload);
    const ephemeral = await crypto.subtle.importKey(
      "jwk", parsed.epk, { name: "ECDH", namedCurve: "P-256" }, false, []
    );
    const own = await crypto.subtle.importKey(
      "jwk", JSON.parse(priv), { name: "ECDH", namedCurve: "P-256" }, false, ["deriveKey"]
    );
    const seal = await crypto.subtle.deriveKey(
      { name: "ECDH", public: ephemeral },
      own,
      { name: "AES-GCM", length: 256 },
      false,
      ["decrypt"]
    );
    const bytesOf = (encoded) => {
      const binary = atob(encoded.replaceAll("-", "+").replaceAll("_", "/"));
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      return bytes;
    };
    const joined = bytesOf(parsed.ct);
    const opened = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: joined.slice(0, 12) }, seal, joined.slice(12)
    );
    return new TextDecoder().decode(opened);
  } catch (error) {
    return undefined;
  }
}
`)
