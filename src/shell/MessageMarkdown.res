// Markdown for a *message* — the assistant's answers, and what people say to each
// other in an app's chat. Deliberately its own `marked` instance rather than
// `MarkdownRenderer`'s, and the two differences are the whole design:
//
//   - **No directives.** `MarkdownRenderer` turns `::form` into a form and `::python`
//     into a running interpreter, which is right for a document its author wrote and
//     wrong for a line somebody else sent. Here a directive is the characters it is
//     made of. Nothing binds this output either — no ReactiveStore, no
//     CollectionBinder — so even a directive that survived would be inert markup.
//   - **`breaks: true`.** In CommonMark a single newline is a space, which is right
//     for a document and wrong for a chat: people press Enter to break a line and
//     expect the line to break. It is the one setting every chat turns on.
//
// And one thing left out on purpose: **no KaTeX**. `$5 for lunch, $10 for dinner` is
// what people actually type in a chat, and the extension reads the span between the
// dollars as an equation. Math belongs to the document, where the author asked for it.
// Fenced `mermaid` is likewise just a code block here — a diagram needs the lazy
// Mermaid chunk and a pass over real DOM, and a message showing its own source is a
// better answer than a message that quietly renders nothing.
//
// The result is NOT safe to insert. It goes through `Sanitizer`, exactly like the
// preview's — the type system says so, and `MessageText` is where both happen.

%%raw(`
import { Marked } from "marked";

const messages = new Marked({
  gfm: true,
  breaks: true,
});
`)

let toHtml: string => string = %raw(`
function (source) {
  try {
    return messages.parse(source, { async: false });
  } catch (error) {
    // A message is not a document being typed: there is no author here to fix it, so
    // the fallback is the text as written rather than a rendering error nobody can
    // act on. Escaped, because it is about to be sanitised as HTML.
    return "<p>" + String(source)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;") + "</p>";
  }
}
`)
