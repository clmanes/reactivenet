// `::map`, bound after each render. The renderer emits structure — the hidden
// popup template and an empty canvas division — and everything else happens
// here: Leaflet (a lazy chunk), the tiles, the markers, the areas.
//
// The decisions worth knowing before editing:
//
//   - A row without valid coordinates is not an error: it simply has no marker,
//     because a collection fills up one piece at a time.
//   - The popup is the row substituted into the TEMPLATE'S TEXT NODES, never
//     markup — the values are whatever someone typed into a form, exactly the
//     rule the list binder follows.
//   - The reader's view survives both document edits and data refreshes: until
//     they move the map it follows the markers (fitBounds), and from the first
//     drag or zoom of their own the view is theirs. The flag and the view live
//     in per-position state; the map instance is rebuilt when the render
//     replaces its node, and reopens exactly where it was.
//   - NOTHING IS BUILT ON A CANVAS OF NO SIZE. On a `::page` that is not the
//     one showing, the panel carries `hidden` — `display: none` — and an
//     element with no box measures 0×0: Leaflet resolves its fit against zero
//     pixels, which is the minimum zoom, which is the whole world drawn in a
//     corner. Repairing that afterwards is what does not work, and it took a
//     ResizeObserver and then an IntersectionObserver to be sure: both are
//     delivered by the rendering lifecycle, so they arrive a frame after the
//     wrong view at best and, while the document is not being rendered at all,
//     never. So the map is simply not made until the canvas has been laid out.
//     The position is marked deferred, and `rn:page` — PageNav saying it just
//     showed a panel — is what picks the work back up.
//   - The observers stay, for the changes that happen to a map already on
//     screen: the editor opening beside the preview, the window resized. What
//     they do is `invalidateSize` and then the SAME fit the drawing does —
//     through `refit`, which is one function precisely so the reader's rule is
//     stated once: their own view outranks our adaptation, so a map they have
//     already moved is only re-measured, never re-centred.
//   - `fill` colours GeoJSON areas by quantiles of a numeric field — five
//     classes of blue, computed over the rows that parse.
//   - A tiles URL is accepted only as https with the {z}/{x}/{y} placeholders;
//     anything else falls back to OpenStreetMap, credited.

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  unit => promise<{..}>,
  string => option<string>,
) => (Dom.element, string) => unit = %raw(`
function (read, loadLeaflet, misuraCss) {
  const mapState = new WeakMap();
  const stateFor = (container, index) => {
    let states = mapState.get(container);
    if (states === undefined) {
      states = new Map();
      mapState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = {
        map: null,
        layer: null,
        canvas: null,
        userMoved: false,
        // Un gesto conta solo quando c'e' gia' qualcosa da guardare. Prima che i
        // dati arrivino la mappa mostra la vista di apertura e nient'altro, e
        // qualunque movimento in quel momento e' nostro, non del lettore.
        hasData: false,
        pinned: false,
        view: null,
        fitting: false,
        observer: null,
        visibility: null,
        size: null,
        deferred: false,
      };
      states.set(index, state);
    }
    return state;
  };

  const numberOf = (value) => {
    const text = String(value ?? "").trim().replace(",", ".");
    if (text === "") return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  };

  // "45.46, 9.18" — the format ::geo writes. The comma is the separator, so
  // decimals are dots here; lat/lon as separate fields go through numberOf and
  // accept the decimal comma CSV columns carry.
  const coordsOf = (text) => {
    const parts = String(text ?? "").split(",");
    if (parts.length !== 2) return null;
    const lat = Number(parts[0].trim());
    const lon = Number(parts[1].trim());
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return [lat, lon];
  };

  const fieldOf = (record, name) => {
    for (const field of record.fields) {
      if (field.name.toLowerCase() === name.toLowerCase()) return field.value;
    }
    return undefined;
  };

  // Row values into the template's text nodes — never markup. Same substitution
  // rule as the list binder: a value containing <script> displays characters.
  const substituted = (template, record) => {
    const clone = template.cloneNode(true);
    clone.hidden = false;
    clone.className = "rn-map-popup";
    const walker = document.createTreeWalker(clone, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      node.textContent = node.textContent.replace(/\{([A-Za-z0-9_>.-]+)\}/g, (whole, name) => {
        const value = fieldOf(record, name);
        return value === undefined ? whole : value;
      });
    }
    return clone;
  };

  // Five blues for the choropleth, light to dark, by quantile.
  const BLUES = ["#eff3ff", "#bdd7e7", "#6baed6", "#3182bd", "#08519c"];
  const quantileScale = (values) => {
    const sorted = [...values].sort((a, b) => a - b);
    if (sorted.length === 0) return () => BLUES[2];
    const cuts = [0.2, 0.4, 0.6, 0.8].map((q) => sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))]);
    return (value) => {
      let i = 0;
      while (i < cuts.length && value > cuts[i]) i++;
      return BLUES[i];
    };
  };

  const tilesOf = (node) => {
    const asked = node.getAttribute("data-rn-map-tiles") || "";
    const ok = asked.startsWith("https://") && asked.includes("{z}") && asked.includes("{x}") && asked.includes("{y}");
    return {
      url: ok ? asked : "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
      attribution: ok
        ? (node.getAttribute("data-rn-map-attribution") || "")
        : '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    };
  };

  // The fit, in one place: the drawing calls it and so does the observer, so
  // "the map follows the data until the reader's first gesture" is written once.
  // Our own fitBounds emits the zoomstart a reader's does, which is what the
  // fitting flag is already there to suppress — raised here, cleared by the
  // map's own moveend.
  const refit = (state) => {
    // Two different reasons not to move the view, and they are not the same
    // thing: pinned is the author writing a center attribute, which outranks
    // the data for ever; userMoved is the reader, and the first real layout
    // may withdraw that one — see the observer.
    if (!state.map || state.userMoved || state.pinned) return;
    const group = state.layer;
    if (!group || group.getLayers().length === 0) return;
    // A fit is only ever as good as the measurement under it, and Leaflet holds
    // the one it took when the map was made. Zero here means the canvas lost
    // its box again — a page hidden while the data was being read — so the view
    // is left exactly as it is and the position asks to be taken up again on
    // the next rn:page announcement. Fitting anyway is what draws the world in
    // a corner.
    const measured = () => {
      const size = state.map.getSize();
      return size.x > 0 && size.y > 0;
    };
    if (!measured()) {
      try {
        state.map.invalidateSize();
      } catch {}
      if (!measured()) {
        state.deferred = true;
        return;
      }
    }
    state.fitting = true;
    try {
      state.map.fitBounds(group.getBounds().pad(0.15), { maxZoom: 15 });
    } catch {}
    // And the fit itself is checked, because the whole bug was a view set
    // against a size nobody had looked at.
    if (!measured()) state.deferred = true;
  };

  // The canvas changed shape under a map that is already on screen — an editor
  // opened beside the preview, a window resized — so everything Leaflet
  // measured before now is wrong. Re-measure, then adapt to the data again.
  //
  // These are an adaptation and never the construction signal, which is the
  // distinction that took an afternoon to learn. Both observers are delivered
  // by the rendering lifecycle: a document nobody is looking at is not being
  // rendered, so nothing is delivered at all, and the map that was made against
  // a hidden canvas stays wrong for as long as that lasts. Deferring the
  // construction is what fixes that; this only keeps a live map honest.
  const observeSize = (state, canvas) => {
    const react = () => {
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;
      // Hidden again: nothing to measure, and the size we were holding has to go
      // with it — a page hidden and shown comes back to the SAME width and
      // height, so keeping it would make the guard below say "nothing changed"
      // and the map would never be re-measured after the one layout it could
      // not use.
      if (width === 0 || height === 0) {
        state.size = null;
        return;
      }
      // invalidateSize relays out the panes and can bring us straight back here.
      // Only a size we have not already applied is worth doing anything about.
      const last = state.size;
      if (last && last.width === width && last.height === height) return;
      state.size = { width, height };
      if (!state.map || !canvas.isConnected) return;
      try {
        state.map.invalidateSize();
      } catch {}
      refit(state);
    };
    if (typeof ResizeObserver !== "undefined") {
      const observer = new ResizeObserver(react);
      observer.observe(canvas);
      state.observer = observer;
    }
    if (typeof IntersectionObserver !== "undefined") {
      const visibility = new IntersectionObserver(react);
      visibility.observe(canvas);
      state.visibility = visibility;
    }
  };

  // The binder rebuilds its nodes on every preview render, so an observer left
  // behind on each one is a leak nobody sees until a document holds ten maps.
  const stopObserving = (state) => {
    for (const observer of [state.observer, state.visibility]) {
      if (observer) {
        try {
          observer.disconnect();
        } catch {}
      }
    }
    state.observer = null;
    state.visibility = null;
    state.size = null;
  };

  // Is any position in this container still waiting for a canvas with a box?
  // Asked of the states rather than kept as a second list, which could only get
  // out of step with them.
  const waiting = (container) => {
    const states = mapState.get(container);
    if (!states) return false;
    for (const state of states.values()) if (state.deferred) return true;
    return false;
  };

  const known = [];
  let listening = false;
  const ensureListening = () => {
    if (listening) return;
    listening = true;
    window.addEventListener("rn:data", () => {
      for (const entry of [...known]) {
        const container = entry.ref.deref();
        if (!container || !container.isConnected) continue;
        rebind(container, entry.app);
      }
    });
    // PageNav has just shown a panel, so something that had no box has one now.
    // Only the containers with work put down are touched: this fires on every
    // render too, since binding a menu ends by showing the current page.
    window.addEventListener("rn:page", () => {
      for (const entry of [...known]) {
        const container = entry.ref.deref();
        if (!container || !container.isConnected || !waiting(container)) continue;
        rebind(container, entry.app);
      }
    });
  };

  async function rebind(container, app) {
    const nodes = [...container.querySelectorAll("[data-rn-map]")];
    if (nodes.length === 0) return;
    const L = await loadLeaflet();

    nodes.forEach((node, index) => {
      const path = node.getAttribute("data-rn-map");
      const canvas = node.querySelector(":scope > .rn-map-canvas");
      const template = node.querySelector(":scope > .rn-map-template");
      if (!path || !canvas) return;
      const state = stateFor(container, index);
      // Un numero nudo non e' una lunghezza CSS e setProperty lo rifiuta in
      // silenzio: height="520" lasciava la mappa all'altezza di default con
      // l'attributo che sembrava non fare niente. core/CssLength decide, una volta
      // sola, che un numero nudo sono pixel.
      const height = node.getAttribute("data-rn-map-height");
      if (height) {
        const misura = misuraCss(height);
        if (misura !== undefined) canvas.style.setProperty("height", misura);
      }

      // The render replaced the node: the old map is attached to a dead
      // element. Its last view carries over, so the reader loses nothing.
      if (state.canvas !== canvas) {
        stopObserving(state);
        if (state.map) {
          try {
            state.view = { center: state.map.getCenter(), zoom: state.map.getZoom() };
            state.map.remove();
          } catch {}
        }
        state.map = null;
        state.layer = null;
        state.canvas = canvas;
      }

      // The canvas has no box — a page that is not showing, most of the time.
      // Everything below this line measures it, so none of it runs: the work is
      // put down here and the rn:page announcement picks it up. A map already
      // built stops being refreshed with it, which is right — its rows are
      // re-read when the page comes back, the moment they are looked at.
      if (canvas.clientWidth === 0 || canvas.clientHeight === 0) {
        state.deferred = true;
        return;
      }
      state.deferred = false;

      if (!state.map) {
        const map = L.map(canvas, { zoomControl: true });
        const tiles = tilesOf(node);
        L.tileLayer(tiles.url, { attribution: tiles.attribution, maxZoom: 19 }).addTo(map);
        // The reader's first own gesture ends the following: dragging always
        // counts, zooming only when we are not mid-fitBounds ourselves.
        // A gesture needs a map the reader can SEE. On a canvas with no size the
        // only thing moving the view is us, and on a 0×0 canvas Leaflet fires
        // moveend (which lowers the fitting flag) before the zoomstart that
        // reads it — so our own opening view was recorded as the reader's first
        // drag, and the map then refused to follow the data for ever after.
        const visible = () => canvas.clientWidth > 0 && canvas.clientHeight > 0;
        // Due condizioni, non una. Che la mappa sia VISIBILE era gia' qui: su una
        // tela senza dimensioni l'unico a muovere la vista siamo noi. Che abbia
        // gia' dei DATI mancava, ed e' la stessa idea applicata al tempo invece
        // che allo spazio: fra la costruzione e l'arrivo delle righe la mappa
        // mostra soltanto la vista di apertura, e un movimento li' non e' una
        // scelta del lettore su niente. Senza questa condizione l'animazione della
        // nostra setView di apertura poteva emettere il moveend che abbassa il
        // flag PRIMA dello zoomstart che lo legge, e la mappa registrava la
        // propria apertura come il primo gesto del lettore: da quel momento non
        // seguiva piu' i dati, restava sull'Italia a zoom 5 con tutti i punti in
        // un pixel, e cambiare comune non la smuoveva.
        const puoContare = () => visible() && state.hasData;
        map.on("dragstart", () => { if (puoContare()) state.userMoved = true; });
        map.on("zoomstart", () => { if (!state.fitting && puoContare()) state.userMoved = true; });
        map.on("moveend", () => {
          state.fitting = false;
          state.view = { center: map.getCenter(), zoom: map.getZoom() };
        });
        const center = coordsOf(node.getAttribute("data-rn-map-center"));
        const zoomGiven = parseInt(node.getAttribute("data-rn-map-zoom") || "", 10);
        const zoom = Number.isNaN(zoomGiven) ? 12 : Math.max(0, Math.min(19, zoomGiven));
        // Our own view changes emit the same zoomstart a reader's do; the flag
        // is up while any of them settles, or the map would count its own
        // opening view as the reader's first gesture and never follow again.
        state.fitting = true;
        if ((state.userMoved || state.pinned) && state.view)
          map.setView(state.view.center, state.view.zoom);
        else if (center) { map.setView(center, zoom); state.pinned = true; }
        else map.setView([42.5, 12.5], 5);
        state.map = map;
        observeSize(state, canvas);
      }

      read(app, path).then((collection) => {
        if (!canvas.isConnected || !state.map) return;
        if (state.layer) { try { state.layer.remove(); } catch {} }
        const group = L.featureGroup();
        // Inside a dashboard the map is one of the filtered views.
        const records = globalThis.__rnDashboard
          ? globalThis.__rnDashboard.rowsFor(node, collection.records)
          : collection.records;
        collection = { records };

        const geojsonField = node.getAttribute("data-rn-map-geojson");
        const fillField = node.getAttribute("data-rn-map-fill");
        const coordsField = node.getAttribute("data-rn-map-coords");
        const latField = node.getAttribute("data-rn-map-lat") || "lat";
        const lonField = node.getAttribute("data-rn-map-lon") || "lon";

        if (geojsonField) {
          // Areas: one GeoJSON geometry per row, optionally choropleth-filled
          // by the quantiles of a numeric field.
          const rows = [];
          for (const record of collection.records) {
            const raw = fieldOf(record, geojsonField);
            if (!raw) continue;
            let geometry;
            try { geometry = JSON.parse(raw); } catch { continue; }
            const fill = fillField ? numberOf(fieldOf(record, fillField)) : null;
            rows.push({ record, geometry, fill });
          }
          const scale = quantileScale(rows.map((r) => r.fill).filter((v) => v !== null));
          for (const row of rows) {
            try {
              const area = L.geoJSON(row.geometry, {
                style: {
                  color: "#3182bd",
                  weight: 1,
                  fillColor: row.fill === null ? "#6baed6" : scale(row.fill),
                  fillOpacity: 0.55,
                },
              });
              if (template) area.bindPopup(substituted(template, row.record));
              area.addTo(group);
            } catch {}
          }
        } else {
          for (const record of collection.records) {
            const position = coordsField
              ? coordsOf(fieldOf(record, coordsField))
              : (() => {
                  const lat = numberOf(fieldOf(record, latField));
                  const lon = numberOf(fieldOf(record, lonField));
                  return lat === null || lon === null ? null : [lat, lon];
                })();
            if (!position) continue;
            const marker = L.circleMarker(position, {
              radius: 7,
              color: "#0072B2",
              weight: 2,
              fillColor: "#56B4E9",
              fillOpacity: 0.7,
            });
            if (template) marker.bindPopup(substituted(template, record));
            marker.addTo(group);
          }
        }

        group.addTo(state.map);
        state.layer = group;
        // Leaflet measures the canvas at construction; a canvas that was still
        // laying out measures 0 and draws one tile. invalidateSize re-measures.
        state.map.invalidateSize();
        refit(state);
        // DOPO l'adattamento, non prima: cosi' nemmeno gli eventi del nostro
        // fitBounds possono essere scambiati per un gesto. Da qui in poi c'e'
        // qualcosa da guardare, e un movimento e' davvero del lettore.
        if (group.getLayers().length > 0) state.hasData = true;
      });
    });
  }

  return function (container, app) {
    if (container.querySelector("[data-rn-map]") === null) return;
    ensureListening();
    if (!known.some((entry) => entry.ref.deref() === container)) {
      known.push({ ref: new WeakRef(container), app });
    } else {
      for (const entry of known) if (entry.ref.deref() === container) entry.app = app;
    }
    rebind(container, app);
  };
}
`)

// The lazy edge, one import for the module's lifetime.
let loaded: ref<option<promise<{..}>>> = ref(None)

let loadLeaflet = () =>
  switch loaded.contents {
  | Some(pending) => pending
  | None => {
      let pending = import(LeafletImpl.leaflet)
      loaded.contents = Some(pending)
      pending
    }
  }

let binder = install(CollectionStore.read, loadLeaflet, CssLength.normalise)

let bind = (container, ~app) => binder(container, app)
