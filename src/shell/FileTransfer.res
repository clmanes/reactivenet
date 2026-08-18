// Writing a file to disk and reading one back — a data backup, or a whole app.
//
// Both go through the plain, universally available paths — an `<a download>` and an
// `<input type="file">` — rather than the File System Access API. That API is
// Chromium-only, needs a permission prompt, and buys nothing here: there is no
// long-lived handle to keep, because an app's home is IndexedDB and the file is a
// copy leaving or arriving.
//
// Nothing here parses. What a document means is decided in `core/AppFile` and what a
// backup means in `core/Backup`; this module only moves bytes.

// From the extension, because the caller already had to choose one and two ways of
// saying the same thing is one too many. A type the browser does not know is not an
// error — it downloads all the same.
let mimeFor = filename => {
  let lower = filename->String.toLowerCase
  if lower->String.endsWith(".json") {
    "application/json;charset=utf-8"
  } else if lower->String.endsWith(".md") || lower->String.endsWith(".markdown") {
    "text/markdown;charset=utf-8"
  } else {
    "text/plain;charset=utf-8"
  }
}

let write: (string, string, string) => unit = %raw(`
function (filename, text, mime) {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  // Appended before the click: Firefox ignores a click on an anchor that is not in
  // the document, and the failure is silent.
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Deferred, because revoking it in the same task can cancel the download that the
  // click has only just started.
  setTimeout(function () { URL.revokeObjectURL(url); }, 0);
}
`)

let download = (filename, text) => write(filename, text, mimeFor(filename))

// Resolves to nothing when the picker is dismissed. There is no cancel event on a
// file input that every browser fires, so a dismissed picker simply never resolves
// with a file — which is why the result is an option rather than a rejection the
// caller would have to catch on the ordinary path.
let open_: string => promise<option<(string, string)>> = %raw(`
function (accept) {
  return new Promise(function (resolve) {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = accept;
    input.style.display = "none";
    document.body.appendChild(input);
    const done = function (value) {
      input.remove();
      resolve(value);
    };
    input.addEventListener("change", function () {
      const file = input.files && input.files[0];
      if (!file) return done(undefined);
      file.text()
        .then(function (text) { done([file.name, text]); })
        // An unreadable file is "no file", the same as a dismissed picker: there is
        // nothing the caller could do differently, and nothing to report but that
        // no document arrived.
        .catch(function () { done(undefined); });
    });
    input.addEventListener("cancel", function () { done(undefined); });
    input.click();
  });
}
`)

/** Reads a file and hands its text to the callback. Nothing happens if the picker
    was dismissed, which is the whole of "the user changed their mind". */
let readTextFile = (~accept=".json,application/json", receive) =>
  open_(accept)
  ->Promise.thenResolve(chosen =>
    switch chosen {
    | Some((_, text)) => receive(text)
    | None => ()
    }
  )
  ->ignore

/** Asks for an app document and resolves to its name and contents. */
let readDocument = () => open_(AppFile.accept)

// Binary twins of the text pair above, for the spreadsheet formats: same
// anchor, same input, bytes instead of text.
let writeBinary: (string, Js.TypedArray2.Uint8Array.t, string) => unit = %raw(`
function (filename, bytes, mime) {
  const blob = new Blob([bytes], { type: mime });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(function () { URL.revokeObjectURL(url); }, 0);
}
`)

let downloadBinary = (filename, bytes) =>
  writeBinary(filename, bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

let openBinary: string => promise<option<Js.TypedArray2.ArrayBuffer.t>> = %raw(`
function (accept) {
  return new Promise(function (resolve) {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = accept;
    input.style.display = "none";
    document.body.appendChild(input);
    const done = function (value) {
      input.remove();
      resolve(value);
    };
    input.addEventListener("change", function () {
      const file = input.files && input.files[0];
      if (!file) return done(undefined);
      file.arrayBuffer()
        .then(function (buffer) { done(buffer); })
        .catch(function () { done(undefined); });
    });
    input.addEventListener("cancel", function () { done(undefined); });
    input.click();
  });
}
`)

/** Asks for a binary file and hands its bytes to the callback. Nothing happens
    if the picker was dismissed. */
let readBinaryFile = (~accept, receive) =>
  openBinary(accept)
  ->Promise.thenResolve(chosen =>
    switch chosen {
    | Some(buffer) => receive(buffer)
    | None => ()
    }
  )
  ->ignore

// A chat attachment: any file, read as a data: URL so the whole of it — bytes and
// type — fits in one stored string. The size is checked *before* reading: the
// ceiling exists because an attachment travels inside a sync change, and a change
// past the server's own limit would be refused after the fact with no way to say
// why. `tooBig` comes back instead of the data so the caller can say it in words.
type picked = {name: string, dataUrl: string, tooBig: bool}

let readAttachment: (~maxBytes: int) => promise<option<picked>> = %raw(`
function (maxBytes) {
  return new Promise(function (resolve) {
    const input = document.createElement("input");
    input.type = "file";
    input.style.display = "none";
    document.body.appendChild(input);
    const done = function (value) {
      input.remove();
      resolve(value);
    };
    input.addEventListener("change", function () {
      const file = input.files && input.files[0];
      if (!file) return done(undefined);
      if (file.size > maxBytes)
        return done({ name: file.name, dataUrl: "", tooBig: true });
      const reader = new FileReader();
      reader.onload = function () {
        done({ name: file.name, dataUrl: String(reader.result), tooBig: false });
      };
      reader.onerror = function () { done(undefined); };
      reader.readAsDataURL(file);
    });
    input.addEventListener("cancel", function () { done(undefined); });
    input.click();
  });
}
`)
