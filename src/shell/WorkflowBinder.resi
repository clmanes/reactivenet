/** `::workflow` — the orchestrator, bound after every render and after every engine,
    because the steps are those engines and it needs the runs they registered.

    It computes nothing itself. It supplies the order (from the collection names the
    steps already carry), the trigger, one status line for the lot, and the rule that
    nothing downstream of a failed step runs. */

type labels = {
  run: string,
  stop: string,
  steps: string,
  waiting: string,
  running: string,
  skipped: string,
  failed: string,
  last: string,
  next: string,
  never: string,
  cycle: string,
  looped: string,
  empty: string,
  whileOpen: string,
}

let bind: (Dom.element, ~app: string, ~labels: labels, ~locale: string) => unit
