// Pure. The completion list behind the editor's autocomplete: CodeMirror calls
// `matching` with the word under the cursor and renders whatever comes back, so the
// behaviour is decided here and tested without an editor.

type t = {
  label: string,
  detail: string,
  insert: string,
  // Where to leave the caret inside `insert`, counted in characters from its start.
  // Snippets are only useful if the caret lands where you would type next.
  caret: int,
}

let all = [
  {label: "h1", detail: "Heading 1", insert: "# ", caret: 2},
  {label: "h2", detail: "Heading 2", insert: "## ", caret: 3},
  {label: "h3", detail: "Heading 3", insert: "### ", caret: 4},
  {label: "bold", detail: "Bold text", insert: "****", caret: 2},
  {label: "italic", detail: "Italic text", insert: "**", caret: 1},
  {label: "strike", detail: "Strikethrough (GFM)", insert: "~~~~", caret: 2},
  {label: "link", detail: "Link", insert: "[](https://)", caret: 1},
  {label: "image", detail: "Image", insert: "![](https://)", caret: 2},
  {label: "code", detail: "Fenced code block", insert: "```\n\n```", caret: 3},
  {label: "mermaid", detail: "Mermaid diagram", insert: "```mermaid\nflowchart LR\n  A --> B\n```", caret: 11},
  {label: "math", detail: "Inline math (KaTeX)", insert: "$$", caret: 1},
  {label: "mathblock", detail: "Display math (KaTeX)", insert: "$$\n\n$$", caret: 3},
  {label: "table", detail: "Table (GFM)", insert: "| A | B |\n| --- | --- |\n|  |  |", caret: 0},
  {label: "todo", detail: "Task list (GFM)", insert: "- [ ] ", caret: 6},
  {label: "quote", detail: "Blockquote", insert: "> ", caret: 2},
  {label: "hr", detail: "Horizontal rule", insert: "---\n", caret: 4},
]

// Case-insensitive prefix match. An empty prefix offers everything, which is what
// makes an explicit Ctrl-Space useful.
let matching = prefix => {
  let needle = prefix->String.trim->String.toLowerCase

  if needle == "" {
    all
  } else {
    all->Array.filter(snippet => snippet.label->String.toLowerCase->String.startsWith(needle))
  }
}
