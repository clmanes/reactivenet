/** A fresh AES-GCM key, base64url, ready for a link fragment. */
let generateKey: unit => promise<string>

/** The text sealed under the key: base64url(iv ++ ciphertext). */
let encrypt: (~key: string, ~text: string) => promise<string>

/** The text back, or nothing — a wrong key, a truncated blob and a tampered one all
    fail the same way, which is the point of an authenticated cipher. */
let decrypt: (~key: string, ~payload: string) => promise<option<string>>
