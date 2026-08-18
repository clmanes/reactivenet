/** Pure. The shape of a workflow: which step feeds which, in what order they may
    run, and what stops when one of them fails.

    Nobody writes the edges — a step that writes the collection another step reads is
    the edge. The order is stable: two steps that do not feed each other keep the
    order the author wrote. */

type step = {
  name: string,
  reads: array<string>,
  writes: array<string>,
}

type plan = {
  /** Positions into the steps given, in the order they may run. */
  order: array<int>,
  /** The positions no order could place: they feed each other in a circle. */
  cycle: array<int>,
}

/** Whether the first step writes something the second reads. */
let feeds: (step, step) => bool

let plan: array<step> => plan

/** Everything that step was feeding, however far down — what must not run when it
    failed. Excludes the step itself. */
let downstream: (array<step>, int) => array<int>

/** The collections the workflow produces, once each, in first-written order. */
let outputs: array<step> => array<string>
