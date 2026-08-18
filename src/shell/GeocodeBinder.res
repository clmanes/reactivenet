// `::geocode` — addresses into "lat, lon", ALWAYS on the reader's click and
// never by itself.
//
// TWO RESOLVERS, AND THE ORDER IS THE POINT. First the open-data service on this
// app's own origin, where the warehouse holds ANNCSU — the national archive of street
// numbers, twenty million of them with coordinates. That answer is same-origin,
// instant, unmetered, and it never tells anybody what was searched. Only when it has
// nothing does the request go out to Nominatim.
//
// The order matters for three separate reasons, and each would justify it alone: it
// is faster (a local join against a rate-limited public service), it is more private
// (a reader's address does not leave this machine), and it is kinder — the public
// Nominatim instance is a shared, donated service, and the requests we do not send
// are the ones it does not have to serve.
//
// The local resolver misses in two honest ways, and both fall through rather than
// fail: ANNCSU has no coordinates at all in 2402 of 7890 comuni, and it is Italy
// only. An address abroad, or in a comune whose Comune never uploaded the
// georeferencing, still resolves — through Nominatim, exactly as before.
//
// The address is split by `core/AddressParse`, which is pure and tested: deciding
// WHAT to look up is the part that fails by returning a wrong point rather than an
// error, so it does not live in here.
//
// Nothing a reader types is ever concatenated into SQL. The query carries `?`
// placeholders and the values travel as prepared parameters, the same rule
// `::od-query` follows for its `{#key}`.
//
// Nominatim's policy — one request a second, an identified purpose — still shapes the
// fallback path, and is not a nuisance bolted on.
//
//   - Idempotent: only rows that HAVE the address and DON'T have coordinates
//     yet are asked about, so a second click resumes the leftovers.
//   - At most 50 rows per click, one per second, written back one by one — the
//     map fills in live, and an interrupted run has lost nothing.
//   - `url=` points a self-hosted /search instead; https only, either way.
//   - The scalar form resolves one address — literal or `#key` — into a
//     reactive key.

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  (~app: string, ~path: string, Collection.t) => promise<unit>,
  string => Nullable.t<string>,
  (string, string) => unit,
  string => option<AddressParse.t>,
) => (Dom.element, string, OpenDataBinder.labels) => unit = %raw(`
function (read, write, storeGet, storeSet, parseAddress) {
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  const fieldOf = (record, name) => {
    for (const field of record.fields) {
      if (field.name.toLowerCase() === name.toLowerCase()) return field.value;
    }
    return undefined;
  };

  const searchBase = (node) => {
    const asked = node.getAttribute("data-rn-geocode-url") || "";
    return asked.startsWith("https://") ? asked : "https://nominatim.openstreetmap.org/search";
  };

  // Il resolver locale: ANNCSU attraverso /od, sulla nostra stessa origine.
  // Ritorna null — non solleva — quando non trova o quando il servizio non c'è: è un
  // ripiego che deve cadere in piedi, non un errore da propagare.
  const SQL =
    "SELECT round(c.lat, 5) AS lat, round(c.lon, 5) AS lon FROM anncsu_civici c " +
    "JOIN anncsu_strade s USING (codice_istat, strada) " +
    "JOIN istat_confini_comuni g ON g.codice_istat = c.codice_istat " +
    "WHERE lower(strip_accents(g.comune)) = ? AND s.odonimo ILIKE ? AND c.lat IS NOT NULL " +
    // Il civico esatto se è stato scritto; altrimenti una qualunque della via, che è
    // la risposta giusta a "dov'è via Lucana".
    "AND (? = '' OR c.civico = ?) " +
    // metodo 1 e 3 sono accurati sotto i cinque metri: a parità di indirizzo si
    // preferisce il rilievo alla derivazione.
    "ORDER BY CASE c.metodo WHEN 1 THEN 0 WHEN 3 THEN 1 WHEN 2 THEN 2 WHEN 4 THEN 3 ELSE 4 END " +
    "LIMIT 1";

  let localeAssente = false;
  const resolveLocal = async (address) => {
    if (localeAssente) return null;
    const parti = parseAddress(address);
    if (parti === undefined) return null;
    try {
      const res = await fetch("/od/query", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          sql: SQL,
          params: [
            parti.comune.toLowerCase(),
            "%" + parti.odonimo.toUpperCase() + "%",
            parti.civico,
            parti.civico,
          ],
        }),
        signal: AbortSignal.timeout(8000),
      });
      if (!res.ok) {
        // Nessun servizio open-data su questa origine: si smette di chiederglielo per
        // il resto della sessione invece di pagare un fetch fallito per ogni riga.
        if (res.status === 404 || res.status >= 500) localeAssente = true;
        return null;
      }
      const body = await res.json().catch(() => null);
      const riga = body?.rows?.[0];
      if (!riga || riga.lat === undefined || riga.lon === undefined) return null;
      return Number(riga.lat).toFixed(5) + ", " + Number(riga.lon).toFixed(5);
    } catch {
      localeAssente = true;
      return null;
    }
  };

  const resolveOne = async (base, address) => {
    const res = await fetch(base + "?format=json&limit=1&q=" + encodeURIComponent(address), {
      headers: { accept: "application/json" },
    });
    const body = await res.json().catch(() => null);
    if (!res.ok || !Array.isArray(body)) throw new Error("unreachable");
    const hit = body[0];
    if (!hit || hit.lat === undefined || hit.lon === undefined) return null;
    return Number(hit.lat).toFixed(5) + ", " + Number(hit.lon).toFixed(5);
  };

  return function (container, app, labels) {
    container.querySelectorAll("[data-rn-geocode]").forEach((node) => {
      const button = node.querySelector(".rn-geocode-run");
      const status = node.querySelector(".rn-od-status");
      if (!button) return;
      const say = (text, error) => {
        if (!status) return;
        status.textContent = text;
        status.className = "rn-od-status " + (error ? "rn-error" : "rn-muted");
      };

      button.addEventListener("click", async () => {
        button.disabled = true;
        try {
          const base = searchBase(node);
          const key = node.getAttribute("data-rn-geocode-key");

          // The scalar form: one address, one reactive key.
          if (key) {
            const asked = node.getAttribute("data-rn-geocode-value") || "";
            const address = asked.startsWith("#")
              ? (storeGet(asked.slice(1)) ?? "")
              : asked;
            if (String(address).trim() === "") return;
            const testo = String(address).trim();
            const coords = (await resolveLocal(testo)) ?? (await resolveOne(base, testo));
            if (coords) {
              storeSet(key, coords);
              say(coords, false);
            } else say("—", false);
            return;
          }

          const path = node.getAttribute("data-rn-geocode-path");
          const from = node.getAttribute("data-rn-geocode-from");
          const to = node.getAttribute("data-rn-geocode-to") || "coords";
          if (!path || !from) return;

          const collection = await read(app, path);
          const waiting = collection.records.filter((record) => {
            const address = fieldOf(record, from);
            const done = fieldOf(record, to);
            return address && String(address).trim() !== "" && (!done || String(done).trim() === "");
          }).slice(0, 50);

          let solved = 0;
          let daNominatim = false;
          for (let i = 0; i < waiting.length; i++) {
            say((i + 1) + "/" + waiting.length + "…", false);
            const address = String(fieldOf(waiting[i], from)).trim();
            // Locale prima: se risponde, la pausa di un secondo qui sotto non serve —
            // è la cortesia dovuta a Nominatim, non a noi stessi.
            const daCasa = await resolveLocal(address);
            const coords = daCasa ?? (await resolveOne(base, address));
            if (daCasa) daNominatim = false; else daNominatim = true;
            if (coords) {
              // Read-modify-write per row: the run can be interrupted anywhere
              // and every answer already received is already saved.
              const current = await read(app, path);
              const records = current.records.map((record) =>
                record.id === waiting[i].id
                  ? { id: record.id, fields: [...record.fields.filter((f) => f.name.toLowerCase() !== to.toLowerCase()), { name: to, value: coords }] }
                  : record,
              );
              await write(app, path, { records });
              window.dispatchEvent(new Event("rn:data"));
              solved++;
            }
            // La regola del servizio pubblico: una richiesta al secondo. Vale solo
            // per le righe che ci sono davvero andate.
            if (daNominatim && i < waiting.length - 1) await sleep(1000);
          }
          say(solved + "/" + waiting.length, false);
        } catch {
          say(labels.unreachable, true);
        } finally {
          button.disabled = false;
        }
      });
    });
  };
}
`)

let binder = install(
  CollectionStore.read,
  CollectionStore.write,
  ReactiveStore.get,
  ReactiveStore.set,
  AddressParse.parse,
)

let bind = (container, ~app, ~labels) => binder(container, app, labels)
