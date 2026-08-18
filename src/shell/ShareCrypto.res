// The lock on a stored share.
//
// A short link means the document sits on a server, and the whole privacy story of
// sharing — nobody's app in anybody's log — would end there. So it is encrypted
// *before* it leaves the browser, with a key minted per share, and the key travels
// in the link's fragment: the one part of a URL that is never sent. The server
// stores a blob it cannot read; whoever has the link has the key; there is no
// account, no passphrase, nothing to manage.
//
// AES-GCM 256 via WebCrypto — native, constant-time, authenticated: a tampered or
// truncated blob fails to decrypt rather than decoding to garbage that the importer
// would then have to distrust. The IV is 12 random bytes, prefixed to the
// ciphertext; both ride base64url, the same alphabet the rest of a link uses.
//
// This encrypts the *encoded* payload (SharePayload's gzip+base64 string) rather
// than raw bytes. That costs a second base64 layer (~1.33×), and buys one seam: the
// decrypted value is exactly what `SharePayload.decode` already accepts, so the long
// and short forms share every step but this one.

let generateKey: unit => promise<string> = %raw(`
async function () {
  const key = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, [
    "encrypt",
  ]);
  const raw = new Uint8Array(await crypto.subtle.exportKey("raw", key));
  let binary = "";
  for (const byte of raw) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
`)

let encrypt: (~key: string, ~text: string) => promise<string> = %raw(`
async function (key, text) {
  const bytesOf = (encoded) => {
    const binary = atob(encoded.replaceAll("-", "+").replaceAll("_", "/"));
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return bytes;
  };
  const cryptoKey = await crypto.subtle.importKey(
    "raw", bytesOf(key), { name: "AES-GCM" }, false, ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, cryptoKey, new TextEncoder().encode(text))
  );
  const joined = new Uint8Array(iv.length + sealed.length);
  joined.set(iv);
  joined.set(sealed, iv.length);
  let binary = "";
  for (const byte of joined) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
`)

/** Nothing rather than garbage: GCM authenticates, so a truncated or tampered blob —
    or the wrong key — fails here instead of producing a plausible-looking document
    the importer would have to distrust. */
let decrypt: (~key: string, ~payload: string) => promise<option<string>> = %raw(`
async function (key, payload) {
  try {
    const bytesOf = (encoded) => {
      const binary = atob(encoded.replaceAll("-", "+").replaceAll("_", "/"));
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      return bytes;
    };
    const joined = bytesOf(payload);
    const cryptoKey = await crypto.subtle.importKey(
      "raw", bytesOf(key), { name: "AES-GCM" }, false, ["decrypt"]
    );
    const opened = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: joined.slice(0, 12) }, cryptoKey, joined.slice(12)
    );
    return new TextDecoder().decode(opened);
  } catch (error) {
    return undefined;
  }
}
`)
