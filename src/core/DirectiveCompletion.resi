type context =
  /** `colons` is how many the author typed: one inline, two for a block — whether
      that block is completed with a `::/name` close is the component's business, not
      theirs — three or more for the legacy fence. */
  | Directive({prefix: string, colons: int})
  | Attribute({directive: string, prefix: string})
  | Value({directive: string, attribute: string, prefix: string})
  | Prose(string)

type completion = {
  label: string,
  detail: string,
  insert: string,
  caret: int,
  /** Characters before the word being typed that `insert` already contains, and
      which the editor must replace along with it. */
  back: int,
}

/** Reads the text before the cursor and decides what is being typed. */
let analyse: string => context

let completions: (context, array<SpectrumRegistry.component>) => array<completion>
