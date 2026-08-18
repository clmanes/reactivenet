// The ml-* directives: scikit-learn in the browser, on the Python runtime the
// ::python blocks already share. Five directives, one discipline:
//
//   - The executed code is a FIXED template. Nothing an author or reader
//     writes is ever pasted into it: the rows and every parameter travel in
//     the runner's data channel and Python reads them from `data` — the same
//     reason od-query binds parameters instead of concatenating SQL.
//   - `features` are numeric fields; a row that does not parse (decimal comma
//     accepted) is left out, and the status says used/total.
//   - Numeric parameters accept a reactive #key: move a slider and the model
//     recomputes, debounced, exactly like a query.
//   - Results land in the DERIVED collection `into=` — this device's own,
//     out of the sync — ready for tables, charts and maps.
//   - The very first run that needs a package downloads scikit-learn (tens of
//     MB, cached after): that waits behind a Run button, remembered once.

type labels = {
  run: string,
  loading: string,
  rows: string,
  refused: string,
  // Said when a run wants a package the reader has not accepted yet. It has to be
  // words: the Run button beside it says what to press and nothing says why.
  engine: string,
}

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  (~app: string, ~path: string, Collection.t) => promise<unit>,
  (~app: string, ~path: string) => promise<unit>,
  string => Nullable.t<string>,
  (string => unit) => unit,
  (~code: string, ~data: string, ~packages: array<string>, ~writes: string) => promise<PythonRunner.outcome>,
  unit => promise<bool>,
  unit => promise<unit>,
) => (Dom.element, string, labels) => unit = %raw(`
function (read, write, markDerived, storeGet, storeSubscribe, runPython, isEnabled, enable) {
  // Inside a ::workflow this block does not start itself: the order, and whether it
  // runs at all after the step before it failed, is the workflow's answer. Asked
  // defensively, the way the dashboard's cross-filter is, so a document with no
  // workflow in it pays nothing.
  const wfDefers = (node) =>
    globalThis.__rnWorkflow ? globalThis.__rnWorkflow.defers(node) : false;
  const wfRegister = (node, run) => {
    if (globalThis.__rnWorkflow) globalThis.__rnWorkflow.register(node, run);
  };

  const NL = "\n";

  // The shared prelude: rows in, features parsed, the usable subset kept.
  const PRELUDE = [
    "def _num(v):",
    "    try:",
    "        return float(str(v).replace(',', '.'))",
    "    except Exception:",
    "        return None",
    "rows = data['rows']",
    "p = data['params'][0]",
    "feats = [f.strip() for f in p.get('features', '').split(',') if f.strip()]",
    "X = []",
    "keep = []",
    "for r in rows:",
    "    vals = [_num(r.get(f)) for f in feats]",
    "    if vals and all(v is not None for v in vals):",
    "        X.append(vals)",
    "        keep.append(r)",
  ].join(NL);

  const TEMPLATES = {
    cluster: PRELUDE + NL + [
      "k = max(2, min(20, int(float(str(p.get('k') or 4).replace(',', '.')))))",
      "out = []",
      "if len(X) >= k:",
      "    from sklearn.preprocessing import StandardScaler",
      "    from sklearn.cluster import KMeans",
      "    Xs = StandardScaler().fit_transform(X)",
      "    labels = KMeans(n_clusters=k, n_init=10, random_state=0).fit_predict(Xs)",
      "    for r, lab in zip(keep, labels):",
      "        q = dict(r)",
      "        q['cluster'] = int(lab)",
      "        out.append(q)",
      "result = out",
      "print(str(len(keep)) + '/' + str(len(rows)))",
    ].join(NL),

    anomaly: PRELUDE + NL + [
      "c = max(0.001, min(0.5, float(str(p.get('contamination') or 0.05).replace(',', '.'))))",
      "out = []",
      "if len(X) >= 5:",
      "    from sklearn.ensemble import IsolationForest",
      "    forest = IsolationForest(contamination=c, random_state=0).fit(X)",
      "    flags = forest.predict(X)",
      "    scores = forest.score_samples(X)",
      "    lo = min(scores)",
      "    hi = max(scores)",
      "    span = (hi - lo) or 1.0",
      "    for r, s, fl in zip(keep, scores, flags):",
      "        q = dict(r)",
      "        q['anomalia'] = round((hi - s) / span, 3)",
      "        q['flag'] = 1 if fl < 0 else 0",
      "        out.append(q)",
      "result = out",
      "print(str(len(keep)) + '/' + str(len(rows)))",
    ].join(NL),

    predict: PRELUDE + NL + [
      "t = p.get('target') or ''",
      "Xt = []",
      "yt = []",
      "for r, v in zip(keep, X):",
      "    tv = _num(r.get(t))",
      "    if tv is not None:",
      "        Xt.append(v)",
      "        yt.append(tv)",
      "out = []",
      "note = str(len(keep)) + '/' + str(len(rows))",
      "if len(Xt) >= 3:",
      "    if (p.get('model') or 'linear') == 'forest':",
      "        from sklearn.ensemble import RandomForestRegressor",
      "        m = RandomForestRegressor(n_estimators=50, random_state=0).fit(Xt, yt)",
      "    else:",
      "        from sklearn.linear_model import LinearRegression",
      "        m = LinearRegression().fit(Xt, yt)",
      "    preds = m.predict(X)",
      "    for r, pv in zip(keep, preds):",
      "        q = dict(r)",
      "        q['previsione'] = round(float(pv), 4)",
      "        out.append(q)",
      "    note = note + ' R2=' + str(round(m.score(Xt, yt), 3))",
      "result = out",
      "print(note)",
    ].join(NL),

    correlate: PRELUDE + NL + [
      "import math",
      "out = []",
      "n = len(X)",
      "if n >= 3:",
      "    for i in range(len(feats)):",
      "        for j in range(i + 1, len(feats)):",
      "            xs = [v[i] for v in X]",
      "            ys = [v[j] for v in X]",
      "            mx = sum(xs) / n",
      "            my = sum(ys) / n",
      "            cov = sum((a - mx) * (b - my) for a, b in zip(xs, ys))",
      "            vx = math.sqrt(sum((a - mx) ** 2 for a in xs))",
      "            vy = math.sqrt(sum((b - my) ** 2 for b in ys))",
      "            out.append({'a': feats[i], 'b': feats[j], 'r': round(cov / (vx * vy), 3) if vx and vy else 0.0})",
      "result = out",
      "print(str(n) + '/' + str(len(rows)))",
    ].join(NL),

    forecast: [
      "def _num(v):",
      "    try:",
      "        return float(str(v).replace(',', '.'))",
      "    except Exception:",
      "        return None",
      "import datetime, math",
      "def _x(v):",
      "    s = str(v).strip()",
      "    n = _num(s)",
      "    if n is not None:",
      "        return n",
      "    try:",
      "        return float(datetime.date.fromisoformat(s[:10]).toordinal())",
      "    except Exception:",
      "        return None",
      "rows = data['rows']",
      "p = data['params'][0]",
      "xf = p.get('x') or ''",
      "yf = p.get('y') or ''",
      "pts = []",
      "for r in rows:",
      "    xv = _x(r.get(xf))",
      "    yv = _num(r.get(yf))",
      "    if xv is not None and yv is not None:",
      "        pts.append((xv, yv, r))",
      "pts.sort(key=lambda t: t[0])",
      "out = []",
      "model_used = 'linear'",
      "failed = ''",
      "h = max(1, min(60, int(float(str(p.get('horizon') or 6).replace(',', '.')))))",
      "season = int(float(str(p.get('season') or 0).replace(',', '.')))",
      "if len(pts) >= 3:",
      "    xs = [t[0] for t in pts]",
      "    ys = [t[1] for t in pts]",
      "    steps = sorted(xs[i + 1] - xs[i] for i in range(len(xs) - 1))",
      "    step = steps[len(steps) // 2] if steps else 1.0",
      "    if step <= 0:",
      "        step = 1.0",
      "    fit = None",
      "    future = None",
      "    m = p.get('model') or 'linear'",
      "    if m in ('arima', 'sarima', 'holt', 'holt-winters', 'ets'):",
      "        try:",
      "            if m in ('arima', 'sarima'):",
      "                from statsmodels.tsa.statespace.sarimax import SARIMAX",
      "                seasonal = (1, 1, 1, season) if (m == 'sarima' and season > 1) else (0, 0, 0, 0)",
      "                sm = SARIMAX(ys, order=(1, 1, 1), seasonal_order=seasonal).fit(disp=False)",
      "            else:",
      "                from statsmodels.tsa.holtwinters import ExponentialSmoothing",
      "                kw = {'seasonal': 'add', 'seasonal_periods': season} if season > 1 else {}",
      "                sm = ExponentialSmoothing(ys, trend='add', **kw).fit()",
      "            fit = list(sm.fittedvalues)",
      // The first fitted values of a DIFFERENCED model are not predictions: they
      // are the state before the model has any history, and statsmodels reports
      // them as zero. Left in, an ARIMA over ten years of enrolments drew its
      // projection line from 0 up to 36 000 in one step — the whole chart
      // flattened under a spike at the left edge — and the R² computed against
      // that zero came out at -63, telling the reader the model was catastrophic
      // when it was fine. "loglikelihood_burn" is how many the model itself
      // excludes: 1 for order=(1,1,1), 5 once a seasonal difference is added.
      // They are dropped rather than zeroed, so those rows carry no "previsione"
      // at all and the line simply starts where the model does.
      "            for i in range(min(int(getattr(sm, 'loglikelihood_burn', 0) or 0), len(fit))):",
      "                fit[i] = None",
      "            fit = [v if (v is not None and math.isfinite(float(v))) else None for v in fit]",
      "            future = list(sm.forecast(h))",
      // A non-finite forecast is refused rather than carried: "json.dumps" writes it
      // as the bare word NaN, which is not JSON, so the whole run would come back as
      // a parse error naming nothing. Raised here it becomes the ordinary fallback,
      // with a reason.
      "            if any(not math.isfinite(float(v)) for v in future):",
      "                raise ValueError('forecast not finite')",
      "            model_used = m",
      // A swallowed exception is why this was hard to see: the block fell back to
      // the straight line and said 'linear', which is true and says nothing about
      // the model that was asked for. The reason travels with the status now.
      "        except Exception as errore:",
      "            fit = None",
      "            failed = ' [' + m + ': ' + str(errore)[:120] + ']'",
      "    if fit is None:",
      "        n = len(xs)",
      "        mx = sum(xs) / n",
      "        my = sum(ys) / n",
      "        den = sum((a - mx) ** 2 for a in xs) or 1.0",
      "        b = sum((a - mx) * (c - my) for a, c in zip(xs, ys)) / den",
      "        a0 = my - b * mx",
      "        fit = [a0 + b * v for v in xs]",
      "        future = [a0 + b * (xs[-1] + step * (i + 1)) for i in range(h)]",
      "        model_used = 'linear'",
      // R² over the points the model actually fitted, which after the burn-in is not
      // all of them: measuring it against a prediction the model never made is how
      // -63 got printed beside a perfectly good ARIMA.
      "    coppie = [(f, v) for f, v in zip(fit, ys) if f is not None]",
      "    if coppie:",
      "        my2 = sum(v for _, v in coppie) / len(coppie)",
      "        sst = sum((v - my2) ** 2 for _, v in coppie) or 1.0",
      "        r2 = 1 - sum((f - v) ** 2 for f, v in coppie) / sst",
      "    else:",
      "        r2 = 0.0",
      "    for (xv, yv, r), f in zip(pts, fit):",
      "        q = dict(r)",
      "        if f is not None:",
      "            q['previsione'] = round(float(f), 4)",
      "        out.append(q)",
      "    isdate = _num(str(pts[-1][2].get(xf)).strip()) is None",
      "    last = xs[-1]",
      "    for i, f in enumerate(future):",
      "        nx = last + step * (i + 1)",
      "        if isdate:",
      "            lbl = str(datetime.date.fromordinal(int(round(nx))))",
      "        elif float(nx).is_integer():",
      "            lbl = str(int(nx))",
      "        else:",
      "            lbl = str(round(nx, 3))",
      "        out.append({xf: lbl, 'previsione': round(float(f), 4)})",
      "    print(str(len(pts)) + '/' + str(len(rows)) + ' R2=' + str(round(r2, 3)) + ' ' + model_used + failed)",
      "else:",
      "    print(str(len(pts)) + '/' + str(len(rows)))",
      "result = out",
    ].join(NL),
  };

  const PACKAGES = (kind, params) => {
    if (kind === "cluster" || kind === "anomaly" || kind === "predict") return ["scikit-learn"];
    if (kind === "forecast" && ["arima", "sarima", "holt", "holt-winters", "ets"].includes(params.model || ""))
      return ["statsmodels"];
    return [];
  };

  const mlState = new WeakMap();
  const stateFor = (container, index) => {
    let states = mlState.get(container);
    if (states === undefined) {
      states = new Map();
      mlState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = { signature: null, status: null, gen: 0 };
      states.set(index, state);
    }
    return state;
  };

  // A parameter is its attribute, or — written "#key" — whatever that reactive
  // key holds right now. The keys are also what a re-run subscribes to.
  const paramOf = (node, name, keys) => {
    const given = node.getAttribute("data-rn-ml-" + name);
    if (given === null) return "";
    if (given.startsWith("#")) {
      if (keys && !keys.includes(given.slice(1))) keys.push(given.slice(1));
      const held = storeGet(given.slice(1));
      return held === null || held === undefined ? "" : held;
    }
    return given;
  };

  let live = [];
  let subscribed = false;
  const ensureSubscribed = () => {
    if (subscribed) return;
    subscribed = true;
    storeSubscribe((key) => {
      live = live.filter((entry) => entry.node.isConnected);
      for (const entry of live) {
        if (!entry.keys.includes(key)) continue;
        clearTimeout(entry.timer);
        entry.timer = setTimeout(entry.rerun, 400);
      }
    });
    // The collections these read are written by forms, od-query and the other
    // engines: every announced change is a chance the inputs moved, and the
    // signature makes an unchanged re-run a no-op.
    window.addEventListener("rn:data", () => {
      live = live.filter((entry) => entry.node.isConnected);
      for (const entry of live) {
        clearTimeout(entry.timer);
        entry.timer = setTimeout(entry.rerun, 200);
      }
    });
  };

  const paintStatus = (node, status) => {
    const element = node.querySelector(":scope > .rn-od-status");
    if (!element || !status) return;
    element.textContent = status.text;
    element.className = "rn-od-status " + (status.kind === "error" ? "rn-error" : "rn-muted");
  };

  return function (container, app, labels) {
    const nodes = [...container.querySelectorAll("[data-rn-ml]")];
    if (nodes.length === 0) return;
    ensureSubscribed();

    nodes.forEach((node, index) => {
      const kind = node.getAttribute("data-rn-ml");
      const into = node.getAttribute("data-rn-ml-into");
      const path = node.getAttribute("data-rn-ml-data");
      const code = TEMPLATES[kind];
      if (!into || !path || !code) return;
      const state = stateFor(container, index);
      const keys = [];

      const run = async (force) => {
        const target = [...container.querySelectorAll("[data-rn-ml]")][index];
        if (!target || !target.isConnected) return;
        const params = {
          features: node.getAttribute("data-rn-ml-features") || "",
          target: node.getAttribute("data-rn-ml-target") || "",
          x: node.getAttribute("data-rn-ml-x") || "",
          y: node.getAttribute("data-rn-ml-y") || "",
          k: paramOf(node, "k", keys),
          contamination: paramOf(node, "contamination", keys),
          model: paramOf(node, "model", keys),
          horizon: paramOf(node, "horizon", keys),
          season: paramOf(node, "season", keys),
        };
        if (path === into) {
          state.status = { text: labels.refused + " into=data", kind: "error" };
          paintStatus(target, state.status);
          return;
        }
        // The consent gate holds on every road into a run: packages are never
        // downloaded because a collection happened to change. It is decided HERE,
        // from the parameters this run actually has, and no longer once when the
        // block was bound — because for ::ml-forecast whether a package is needed
        // at all is a READER's choice: the linear trend needs nothing, ARIMA and
        // Holt-Winters need statsmodels. Deciding it at bind time meant a document
        // whose picker opens on "linear" was bound with no Run button, and then the
        // moment somebody chose ARIMA the run fell into a bare "return": no
        // download, no button, no message, no error — and the chart went on showing
        // the straight line they had just asked to replace. So the button is offered
        // from inside the run that wants it.
        const controls = target.querySelector(":scope > .rn-od-controls");
        if (PACKAGES(kind, params).length > 0 && !(await isEnabled())) {
          state.status = { text: labels.engine, kind: "muted" };
          paintStatus(target, state.status);
          if (controls && controls.firstChild === null) {
            const start = document.createElement("button");
            start.type = "button";
            start.className = "rn-od-go";
            start.textContent = labels.run;
            start.addEventListener("click", async () => {
              await enable();
              run(true);
            });
            controls.appendChild(start);
          }
          // A workflow must hear that this did not run: the package is not here and a
          // person has to say so. Its own status already says which.
          return "waiting";
        }
        if (controls) controls.textContent = "";
        const collection = await read(app, path);
        const rows = collection.records.map((record) => {
          const row = { id: record.id };
          for (const field of record.fields) row[field.name] = field.value;
          return row;
        });
        const payload = JSON.stringify({ rows, params: [params] });
        const signature = kind + " " + app + " " + into + " " + payload;
        if (!force && state.signature === signature) {
          paintStatus(target, state.status);
          return;
        }
        state.signature = signature;
        const gen = ++state.gen;
        state.status = { text: labels.loading, kind: "muted" };
        paintStatus(target, state.status);
        try {
          const outcome = await runPython(code, payload, PACKAGES(kind, params), into);
          if (state.gen !== gen) return;
          if (outcome.error !== "") throw new Error(outcome.error.split(NL).pop());
          const offered = outcome.rows === "" ? [] : JSON.parse(outcome.rows);
          const used = [];
          const records = offered.map((row, i) => {
            const fields = [];
            let id = "";
            for (const [name, value] of Object.entries(row)) {
              if (name === "id") { id = String(value); continue; }
              fields.push({ name, value: value === null || value === undefined ? "" : String(value) });
            }
            if (id === "" || used.includes(id)) id = "ml-" + i;
            used.push(id);
            return { id, fields };
          });
          await markDerived(app, into);
          await write(app, into, { records });
          if (state.gen !== gen) return;
          window.dispatchEvent(new Event("rn:data"));
          state.status = { text: (outcome.output.trim() || records.length + " " + labels.rows), kind: "muted" };
          paintStatus(target, state.status);
        } catch (error) {
          if (state.gen !== gen) return;
          state.status = {
            text: labels.refused + " " + String(error && error.message ? error.message : error).slice(0, 300),
            kind: "error",
          };
          paintStatus(target, state.status);
        }
      };

      // The package gate lives inside run() and is offered from there, so handing the
      // run over hands the gate with it — the workflow's strip reports a step waiting
      // behind a button rather than pretending it finished.
      if (wfDefers(node)) {
        wfRegister(node, (asked) => run(asked));
        return;
      }
      live = live.filter((entry) => entry.node.isConnected && entry.node !== node);
      live.push({ node, keys, rerun: () => run(false), timer: null });

      // One road in. The gate guards the package download and not Python itself —
      // correlate and a linear forecast need nothing and start straight away, like
      // ::python — and "run" is where that is asked, so there is nothing left to
      // decide here.
      run(false);
    });
  };
}
`)

// Whether the reader has ever accepted the model-package download.
let enabledKey = "ml-enabled"

let isEnabled = async () =>
  switch await Idb.get(enabledKey) {
  | Value("yes") => true
  | _ => false
  }

let enable = () => Idb.set(enabledKey, "yes")

let binder = install(
  CollectionStore.read,
  CollectionStore.write,
  DerivedPaths.mark,
  ReactiveStore.get,
  ReactiveStore.subscribe,
  PythonRunner.run,
  isEnabled,
  enable,
)

let bind = (container, ~app, ~labels) => binder(container, app, labels)
