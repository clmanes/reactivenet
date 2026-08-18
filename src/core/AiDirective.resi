/** Pure. What the ai-* directives ask, and what an answer is allowed to mean.

    The model never produces anything that is executed: it produces a word from a
    closed list, or an object whose keys the document declared, or a query plan
    whose every field name is checked against that collection's own fields. Each of
    those is refused here rather than downstream — a value that never becomes a row
    is a value nothing has to defend against later. */

type field = {name: string, kind: string}

type filter = {field: string, op: string, value: string}

type plan = {
  filters: array<filter>,
  groupBy: string,
  metric: string,
  metricField: string,
  sort: string,
  limit: int,
}

type line = {label: string, value: string}

type answer = {scalar: string, rows: array<line>}

type rule = {
  field: string,
  op: string,
  value: string,
  setField: string,
  setValue: string,
}

let metrics: array<string>

let operators: array<string>

/** The first JSON value in a model's answer — fenced, bare, or buried in prose. */
let json: string => option<JSON.t>

/** `"voce,importo:number"` as the fields it declares. */
let fields: string => array<field>

/** A comma-separated attribute as the list it is. */
let list: string => array<string>

/** The model's word onto the document's closed list, or nothing. */
let clamp: (string, array<string>) => option<string>

/** An answered object as the declared fields only, in the declared types. */
let record: (JSON.t, array<field>) => array<Collection.field>

/** The query plan, with every field name checked against the closed list. */
let plan: (JSON.t, array<string>) => result<plan, string>

/** Whether one row passes one test. */
let passes: (filter, Dict.t<string>) => bool

/** The plan, run over rows this device already holds. */
let run: (plan, array<Dict.t<string>>) => answer

/** A rule compiled once, checked against the same closed list. */
let rule: (JSON.t, array<string>) => result<rule, string>

/** The rows the rule would actually change — which is what makes it idempotent. */
let applies: (rule, array<Dict.t<string>>) => array<Dict.t<string>>

/** A sample of rows as JSON: what a prompt may carry, which is never the whole
    collection. */
let sample: (array<Dict.t<string>>, int) => string

let planPrompt: (~question: string, ~fields: array<string>, ~rows: string) => string

let rulePrompt: (~when_: string, ~do_: string, ~fields: array<string>, ~rows: string) => string

let recordPrompt: (~instruction: string, ~fields: array<field>, ~text: string) => string

let classifyPrompt: (~instruction: string, ~values: array<string>, ~text: string) => string

let summaryPrompt: (~instruction: string, ~rows: string, ~many: int) => string

let chatSystem: (~persona: string, ~rows: string) => string
