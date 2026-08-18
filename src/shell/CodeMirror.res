// CodeMirror 6 setup. Imperative and DOM-bound by nature, so it lives in the shell;
// what it *offers* as completions comes from the pure MarkdownSnippets module, which
// is passed in as a callback rather than duplicated here.

%%raw(`
import { EditorView, keymap, lineNumbers, highlightActiveLine } from "@codemirror/view";
import { EditorState } from "@codemirror/state";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { languages } from "@codemirror/language-data";
import { autocompletion, completionKeymap } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { syntaxHighlighting, HighlightStyle, indentOnInput } from "@codemirror/language";
import { tags } from "@lezer/highlight";

// CodeMirror's defaultHighlightStyle is built for light backgrounds only: on the
// dark theme its link colour (#221199) sits at 1.32:1 against the editor background,
// which is not a readability problem so much as an invisibility one. The colours here
// are Spectrum tokens instead, so they invert with the theme rather than needing a
// second style and a Compartment to swap between them.
const markdownHighlight = HighlightStyle.define([
  { tag: tags.heading, color: "var(--spectrum-gray-900)", fontWeight: "600" },
  { tag: tags.strong, fontWeight: "700" },
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: tags.strikethrough, textDecoration: "line-through" },
  { tag: [tags.link, tags.url], color: "var(--spectrum-blue-1000)", textDecoration: "underline" },
  { tag: [tags.monospace, tags.literal], color: "var(--spectrum-magenta-1000)" },
  { tag: tags.quote, color: "var(--spectrum-gray-700)", fontStyle: "italic" },
  { tag: tags.keyword, color: "var(--spectrum-purple-1000)" },
  { tag: tags.string, color: "var(--spectrum-green-1000)" },
  { tag: tags.number, color: "var(--spectrum-orange-1000)" },
  { tag: tags.comment, color: "var(--spectrum-gray-600)", fontStyle: "italic" },
  { tag: [tags.name, tags.labelName], color: "var(--spectrum-gray-900)" },
  {
    tag: [tags.processingInstruction, tags.punctuation, tags.meta, tags.contentSeparator],
    color: "var(--spectrum-gray-600)",
  },
]);
`)

type view

let create: (
  ~parent: Dom.element,
  ~doc: string,
  ~onChange: string => unit,
  ~complete: string => array<DirectiveCompletion.completion>,
) => view = %raw(`
function (parent, doc, onChange, complete) {
  const completionSource = (context) => {
    // The whole line up to the cursor, because a directive's attribute list needs
    // more context than the word under the cursor: what is being completed depends
    // on an unclosed brace and the directive name before it.
    const line = context.state.doc.lineAt(context.pos);
    const before = line.text.slice(0, context.pos - line.from);

    // What the completion replaces: the run of characters that belongs to the token
    // being typed, so accepting one does not duplicate what is already there.
    const token = /[A-Za-z0-9_-]*$/.exec(before);
    const from = context.pos - (token ? token[0].length : 0);

    if (from === context.pos && !context.explicit && !/[:{="\s]$/.test(before)) return null;

    const snippets = complete(before);
    if (snippets.length === 0) return null;

    return {
      from,
      options: snippets.map((snippet) => ({
        label: snippet.label,
        detail: snippet.detail,
        type: "keyword",
        apply: (view, completion, from, to) => {
          // A directive snippet carries its own colons, so the ones already typed
          // are part of what it replaces — otherwise accepting ":::acc" writes the
          // fence twice and produces "::::::accordion".
          const start = Math.max(line.from, from - (snippet.back || 0));
          view.dispatch({
            changes: { from: start, to, insert: snippet.insert },
            selection: { anchor: start + snippet.caret },
          });
        },
      })),
      // The pure function already decided what matches; re-filtering here would
      // apply CodeMirror's fuzzy matching on top and drop entries it disagrees with.
      filter: false,
    };
  };

  return new EditorView({
    parent,
    // Explicit, and load-bearing. CodeMirror otherwise resolves its root by walking
    // up through the slot into <sp-theme>'s shadow root, and mounts its stylesheet
    // there via adoptedStyleSheets — where it styles nothing, because the editor
    // itself sits in the light DOM. The symptom is an editor with no layout at all.
    root: document,
    state: EditorState.create({
      doc,
      extensions: [
        lineNumbers(),
        history(),
        indentOnInput(),
        highlightActiveLine(),
        syntaxHighlighting(markdownHighlight, { fallback: true }),
        markdown({ base: markdownLanguage, codeLanguages: languages }),
        autocompletion({ override: [completionSource], activateOnTyping: true }),
        keymap.of([...completionKeymap, ...defaultKeymap, ...historyKeymap, indentWithTab]),
        EditorView.lineWrapping,
        EditorView.updateListener.of((update) => {
          if (update.docChanged) onChange(update.state.doc.toString());
        }),
      ],
    }),
  });
}
`)

let destroy: view => unit = %raw(`function (view) { view.destroy(); }`)
