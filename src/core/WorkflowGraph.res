// Pure. The shape of a workflow: which step feeds which, in what order they may run,
// and what stops when one of them fails.
//
// **Nobody writes the edges.** A step that writes the collection another step reads
// *is* the edge — `into="listino"` above and `data="spese,listino"` below say it
// already. That is the whole reason a workflow needs no node language of its own: the
// names are in the document, they are the same names every view and aggregation
// reads, and inventing a second way to say them would give the analyzer two graphs to
// disagree about.
//
// The order is Kahn's algorithm with the lowest-numbered step picked first, so two
// steps that do not feed each other keep the order the author wrote. That stability
// is the same promise `RowView.sort` makes and for the same reason: a list that
// reshuffles between runs is one nobody can read twice.
//
// A cycle is reported rather than run. The signature guard in every engine breaks
// most loops by accident — an unchanged input is a no-op — but not one whose output
// carries a timestamp, and that one spins for ever with nothing on screen saying why.

type step = {
  /** The directive's own name, for the message. Not used to decide anything. */
  name: string,
  /** The collections this step reads. */
  reads: array<string>,
  /** The collections this step writes. */
  writes: array<string>,
}

type plan = {
  /** Positions into the steps given, in the order they may run. */
  order: array<int>,
  /** The positions no order could place: they feed each other in a circle. Empty when
      the graph is a DAG. A plan can carry both — what can run is still worth running,
      and what cannot is worth naming. */
  cycle: array<int>,
}

// One collection written above and read below. Blank names are not edges: a step with
// no `into=` produces nothing, and treating "" as a shared collection would make every
// such step feed every other.
let feeds = (from: step, to_: step) =>
  from.writes->Array.some(written =>
    written != "" && to_.reads->Array.some(readen => readen == written)
  )

let plan = (steps: array<step>): plan => {
  let count = steps->Array.length
  let waiting = Array.make(~length=count, 0)
  for from in 0 to count - 1 {
    for to_ in 0 to count - 1 {
      if (
        from != to_ && feeds(steps->Array.getUnsafe(from), steps->Array.getUnsafe(to_))
      ) {
        waiting->Array.set(to_, waiting->Array.getUnsafe(to_) + 1)
      }
    }
  }

  let placed = Array.make(~length=count, false)
  let order = []
  let more = ref(true)
  while more.contents {
    // The lowest-numbered step with nothing left feeding it. Scanning from zero every
    // time is what makes the order stable; a queue would hand back whatever finished
    // draining last.
    let next = ref(-1)
    for index in 0 to count - 1 {
      if (
        next.contents == -1 &&
        !(placed->Array.getUnsafe(index)) &&
        waiting->Array.getUnsafe(index) == 0
      ) {
        next := index
      }
    }
    switch next.contents {
    | -1 => more := false
    | from =>
      placed->Array.set(from, true)
      order->Array.push(from)
      for to_ in 0 to count - 1 {
        if (
          from != to_ && feeds(steps->Array.getUnsafe(from), steps->Array.getUnsafe(to_))
        ) {
          waiting->Array.set(to_, waiting->Array.getUnsafe(to_) - 1)
        }
      }
    }
  }

  let cycle = []
  for index in 0 to count - 1 {
    if !(placed->Array.getUnsafe(index)) {
      cycle->Array.push(index)
    }
  }
  {order, cycle}
}

// Everything a failed step was feeding, however far down. A result computed from an
// input that never arrived is worse than no result, because nothing on the page can
// tell the two apart — the same reason an unreachable open-data service leaves the
// last rows in place and says "stale" instead of writing an empty collection over
// them.
let downstream = (steps: array<step>, from: int): array<int> => {
  let count = steps->Array.length
  let hit = Array.make(~length=count, false)
  let queue = [from]
  let head = ref(0)
  while head.contents < queue->Array.length {
    let current = queue->Array.getUnsafe(head.contents)
    head := head.contents + 1
    for to_ in 0 to count - 1 {
      if (
        current != to_ &&
        !(hit->Array.getUnsafe(to_)) &&
        feeds(steps->Array.getUnsafe(current), steps->Array.getUnsafe(to_))
      ) {
        hit->Array.set(to_, true)
        queue->Array.push(to_)
      }
    }
  }
  let out = []
  for index in 0 to count - 1 {
    if hit->Array.getUnsafe(index) {
      out->Array.push(index)
    }
  }
  out
}

// The collections a workflow produces, once each and in the order they are first
// written. What the strip names, and what a reader looking for the rows should go and
// find a view over.
let outputs = (steps: array<step>): array<string> => {
  let seen = []
  steps->Array.forEach(step =>
    step.writes->Array.forEach(written =>
      if written != "" && !(seen->Array.includes(written)) {
        seen->Array.push(written)
      }
    )
  )
  seen
}
