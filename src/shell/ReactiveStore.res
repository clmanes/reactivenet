// The store that makes `:value` reactive: views subscribe to a key, sources write to
// it. Source directives (::slider and friends) do not exist yet, so for now the only
// writer is the global exposed at the bottom.

let set: (string, string) => unit = %raw(`
function (key, value) {
  globalThis.__rnReactive.set(key, value);
}
`)

let get: string => Nullable.t<string> = %raw(`
function (key) {
  const value = globalThis.__rnReactive.values.get(key);
  return value === undefined ? null : value;
}
`)

// Called after every preview render. The preview replaces its innerHTML wholesale,
// so the previous nodes for that container are gone and must be forgotten — keeping
// them would leak a growing list of detached elements on every keystroke.
let bind: Dom.element => unit = %raw(`
function (container) {
  globalThis.__rnReactive.bind(container);
}
`)

// Called when a different app is opened. The store is global — that is what lets a
// slider and a view find each other with nothing but a key — so without this, the
// volume dragged in one app arrived as the starting volume of the next: keys leak
// wherever two documents happen to choose the same name.
let reset: unit => unit = %raw(`
function () {
  const store = globalThis.__rnReactive;
  store.values.clear();
  store.authored.clear();
  store.bound = [];
}
`)

// Module-level subscribers survive reset() on purpose: what resets is the
// *values* when another app opens, not who is listening — the open-data binder
// subscribes once at load, exactly like the sync engine's collection-write
// listener, and filters by the elements actually on the page.
let subscribe: (string => unit) => unit = %raw(`
function (listener) {
  globalThis.__rnReactive.listeners.add(listener);
}
`)

// :calc lives here rather than with the collections because what it reads are the
// same reactive keys :value reads — a total that follows a form as it is typed is a
// bound view, not a query. The evaluator is pure and in core/; this only supplies the
// lookup and the formatting.
let installCalc: (
  (string, string => option<string>) => option<float>,
  string => array<string>,
  (float, ~decimals: int=?) => string,
) => unit = %raw(`
function (evaluate, references, format) {
  globalThis.__rnCalc = { evaluate, references, format };
}
`)

installCalc(Expr.evaluate, Expr.references, (value, ~decimals=?) =>
  Aggregate.format(value, ~decimals?)
)

// The seeding rule, and how a tick is spelled. Pure, tested, and installed the same
// way `:calc` is — the store below is DOM and events, nothing else.
let installSeed: (
  (Nullable.t<string>, string, Nullable.t<string>) => {"adopt": bool, "value": string},
  string => bool,
  bool => string,
) => unit = %raw(`
function (decide, ticked, ofTick) {
  globalThis.__rnSeed = { decide, ticked, ofTick };
}
`)

installSeed(
  (known, authored, seen) =>
    switch SourceSeed.decide(
      ~known=known->Nullable.toOption,
      ~authored,
      ~seen=seen->Nullable.toOption,
    ) {
    | Adopt(value) => {"adopt": true, "value": value}
    | Keep(value) => {"adopt": false, "value": value}
    },
  SourceSeed.ticked,
  SourceSeed.ofTick,
)

%%raw(`
const store = {
  values: new Map(),
  // The last value each control *declared in the document*, as opposed to the live
  // value a user produced by interacting with it. Keeping both is what lets the two
  // be told apart on the next bind.
  authored: new Map(),
  bound: [],
  // Whole-store listeners, told which key moved: what an od-query subscribes to,
  // since its SQL may mention keys bound to nodes it knows nothing about.
  listeners: new Set(),

  bind(container) {
    store.bound = store.bound.filter(
      (entry) => entry.element.isConnected && !container.contains(entry.element)
    );

    // Sources first: a control carrying an initial value seeds the store, so a view
    // shows something before anyone touches the control.
    container.querySelectorAll("[data-reactive-source]").forEach((element) => {
      const key = element.getAttribute("data-reactive-source");
      const known = store.values.get(key);
      // A tick box answers with checked, not with value: its value is the form value
      // it would submit, which for a control written ::checkbox[done] is the empty
      // string. Reading that left the key permanently empty, so a view bound to a
      // tick box never said anything. "true"/"false" is what the same tick is stored
      // as in a collection, so the two agree.
      const ticks = "checked" in element || element.getAttribute("type") === "checkbox";
      const reading = () =>
        ticks ? globalThis.__rnSeed.ofTick(!!element.checked) : element.value;
      // The attribute, not the property: a custom element that has not upgraded yet
      // has no value property, and reading the property alone left the view showing
      // "undefined" until the component bundle finished loading.
      const authored = ticks
        ? globalThis.__rnSeed.ofTick(element.hasAttribute("checked"))
        : String(element.getAttribute("value") ?? element.value ?? "");
      const previouslyAuthored = store.authored.get(key);
      store.authored.set(key, authored);

      // Which of the two values wins is decided in core/SourceSeed, where the three
      // cases are written down together and tested — the rule is only readable that
      // way, and getting it wrong breaks either the block editor or a dragged slider.
      const apply = (value) => {
        if (ticks) element.checked = globalThis.__rnSeed.ticked(value);
        else element.value = value;
      };
      const decision = globalThis.__rnSeed.decide(known, authored, previouslyAuthored);
      if (decision.adopt) store.values.set(key, decision.value);
      apply(decision.value);
      // Spectrum controls emit change on release and input while dragging; a plain
      // input element emits only input. Listening for both covers either.
      const emit = () => store.set(key, reading());
      element.addEventListener("input", emit);
      element.addEventListener("change", emit);
    });

    // Attributes bound to a key: written now from whatever the store holds, and
    // rewritten by set() whenever it changes.
    container.querySelectorAll("[data-reactive-bind]").forEach((element) => {
      for (const pair of element.getAttribute("data-reactive-bind").split(";")) {
        const separator = pair.indexOf(":");
        if (separator < 0) continue;
        const attribute = pair.slice(0, separator);
        const key = pair.slice(separator + 1);
        const value = store.values.get(key);
        if (value !== undefined) element.setAttribute(attribute, value);
        store.bound.push({ key, element, attribute });
      }
    });

    container.querySelectorAll("[data-rn-calc]").forEach((element) => {
      const expression = element.getAttribute("data-rn-calc");
      // Subscribed to every key the expression mentions, so any of them changing
      // recomputes the whole thing — the alternative, recomputing every calc on every
      // write, is the same answer at more cost.
      for (const key of globalThis.__rnCalc.references(expression)) {
        store.bound.push({ key, element, calc: expression });
      }
      store.paintCalc(element, expression);
    });

    container.querySelectorAll("[data-reactive-key]").forEach((element) => {
      const key = element.getAttribute("data-reactive-key");
      const value = store.values.get(key);
      // The placeholder distinguishes "no source has written this yet" from a value
      // that happens to be empty.
      element.textContent = value === undefined ? element.dataset.placeholder || "" : value;
      store.bound.push({ key, element });
    });
  },

  paintCalc(element, expression) {
    const decimals = element.getAttribute("data-rn-decimals");
    const value = globalThis.__rnCalc.evaluate(expression, (key) => {
      const found = store.values.get(key);
      return found === undefined ? undefined : found;
    });
    // An expression that does not parse, or divides by zero, has no answer — the
    // placeholder says so rather than printing NaN or Infinity.
    element.textContent = value === undefined
      ? element.dataset.placeholder || "—"
      : globalThis.__rnCalc.format(value, decimals === null ? undefined : Number(decimals));
  },

  set(key, value) {
    store.values.set(key, String(value));
    for (const listener of store.listeners) listener(key);
    store.bound = store.bound.filter((entry) => entry.element.isConnected);
    for (const entry of store.bound) {
      if (entry.key !== key) continue;
      // A bound attribute is set on the element; a calc recomputes; a bound view
      // replaces its text.
      if (entry.calc) store.paintCalc(entry.element, entry.calc);
      else if (entry.attribute) entry.element.setAttribute(entry.attribute, String(value));
      else entry.element.textContent = String(value);
    }
  },
};

globalThis.__rnReactive = store;

// Temporary source-side API. Until the source directives land, this is how a value
// gets written — including from the console, which is how :value can be exercised.
globalThis.reactiveNet = {
  set: (key, value) => store.set(key, value),
  get: (key) => store.values.get(key),
};
`)
