/** Pure. What the assistant's delivery means: which app a document it hands over
    becomes, decided by the rules an imported file already goes through. It never
    overwrites — a taken id makes the delivery a copy — and a rewrite of the open app
    keeps that app's id, so being asked for a button cannot move an app. */

type delivery =
  | Deliver({
      id: string,
      /** The document as it will be stored: the id written into its frontmatter. */
      source: string,
      title: string,
      /** True when the id the document asked for was taken and it landed elsewhere. */
      renamed: bool,
    })
  | Refused(string)

/** Takes off a fence wrapping the *whole* answer — ```markdown … ``` — and nothing
    else: a fence in the middle is somebody's code block. */
let unfence: string => string

/** Whether the validator's report says the document is good — its first word. The
    seam between this app and the MCP server's `report()`, written down once and
    asserted on both sides, because a model told to validate first will not always
    do it and delivery has to check for itself. */
let validates: string => bool

/** Whether the analyzer's report says the document's pieces meet — no view over a
    collection nothing writes, no `#ref` no source feeds, no id pointing nowhere. The
    second half of the delivery gate: grammar is what `validates` answers, and an app
    can pass that and still be a page where nothing happens. The seam is a marker the
    server writes and this reads, asserted on both sides. */
let connects: string => bool

/** The SQL of every `::od-query` that can be run as written — those carrying a
    `{#key}` are left out, because what they select depends on what a reader types and
    there is no honest value to try in its place. */
let odQueries: string => array<string>

/** Whether the runner's answer says the query is not usable: refused by the service,
    or returning nothing at all. Unlike the other two gates, only an explicit failure
    counts — this one reaches a network service, and a warehouse being away must not
    stop delivery. */
let queryFails: string => bool

/** A new app: the declared id when it is free, a fresh one when it is taken. */
let create: (~markdown: string, ~taken: array<string>, ~fallback: string) => delivery

/** A rewrite of the app already open, under that app's own id. */
let replace: (~markdown: string, ~id: string) => delivery
