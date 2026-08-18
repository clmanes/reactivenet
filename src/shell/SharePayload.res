// A document, small enough to put in a link.
//
// Two platform things do the work and neither can live in `core`: `CompressionStream`
// for gzip, and base64 for turning bytes into characters a URL survives. What is left
// pure — the marker, the ceiling, the shape of the link — is in `core/ShareLink`.
//
// base64**url**: the ordinary alphabet contains `+` and `/`, which a URL either
// escapes or, worse, does not, and `=` padding that some chat clients eat. The three
// substitutions are undone on the way back in.
//
// Compression is not decoration here: a welcome-sized document is 2.3 kB, which
// base64 alone turns into 3.1 kB of link. Gzipped it is closer to 1 kB, and the
// difference is between a link that pastes anywhere and one that gets truncated.
// Where `CompressionStream` is missing the document is encoded uncompressed and says
// so in one character, so a link made by a browser that has it still opens in one
// that does not.

let encode: string => promise<string> = %raw(`
async function (source) {
  const bytes = new TextEncoder().encode(source);
  const characters = (data) => {
    let binary = "";
    for (const byte of data) binary += String.fromCharCode(byte);
    return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  };
  if (typeof CompressionStream !== "function") return "u" + characters(bytes);
  try {
    const stream = new Blob([bytes]).stream().pipeThrough(new CompressionStream("gzip"));
    const packed = new Uint8Array(await new Response(stream).arrayBuffer());
    return "z" + characters(packed);
  } catch (error) {
    return "u" + characters(bytes);
  }
}
`)

/** The document a payload carries, or nothing when it is not readable — a link
    someone truncated, or one written by a version whose format this is not. A
    corrupted link has to be *said*, not guessed at: half a document restored as an
    app would be worse than none. */
let decode: string => promise<option<string>> = %raw(`
async function (payload) {
  try {
    const how = payload.slice(0, 1);
    const body = payload.slice(1).replaceAll("-", "+").replaceAll("_", "/");
    const binary = atob(body);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    if (how === "u") return new TextDecoder().decode(bytes);
    if (how !== "z") return undefined;
    if (typeof DecompressionStream !== "function") return undefined;
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
    return await new Response(stream).text();
  } catch (error) {
    return undefined;
  }
}
`)
