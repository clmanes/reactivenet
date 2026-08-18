// The two calls the short links need, against PocketBase on this origin.
//
// Plain fetch, no SDK: a client library earns its place when there are queries,
// auth, realtime — here there is a deposit and a withdrawal, and two fetches keep
// the bundle exactly as heavy as it was. The server is reached as /pb/* so
// connect-src 'self' keeps holding: the Vite proxy answers in dev, a host rewrite in
// production, and where neither exists every call resolves to nothing — which the
// dialog reads as "offer the long link only".
//
// Every failure is `None`, never an exception: an unreachable server, a 404 from an
// expired share and a malformed answer all mean the same thing to the caller —
// nothing arrived — and each already has its own sentence in the dialog or the
// import path.

/** Deposits an encrypted payload; answers with the id the link will carry. */
let create: string => promise<option<string>> = %raw(`
async function (payload) {
  try {
    const response = await fetch("/pb/api/collections/shares/records", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ payload }),
    });
    if (!response.ok) return undefined;
    const record = await response.json();
    return typeof record.id === "string" && record.id !== "" ? record.id : undefined;
  } catch (error) {
    return undefined;
  }
}
`)

/** The payload under an id, or nothing — expired, purged, or no server here. The
    read is also the touch: the server renews the 120 days on every view. */
let fetchPayload: string => promise<option<string>> = %raw(`
async function (id) {
  try {
    const response = await fetch(
      "/pb/api/collections/shares/records/" + encodeURIComponent(id)
    );
    if (!response.ok) return undefined;
    const record = await response.json();
    return typeof record.payload === "string" && record.payload !== ""
      ? record.payload
      : undefined;
  } catch (error) {
    return undefined;
  }
}
`)
