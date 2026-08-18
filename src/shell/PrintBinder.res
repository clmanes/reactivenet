// `::print` — a button that prints ONE section of the app, found by the id it
// names. A target that does not exist makes the click do nothing rather than print
// the whole app pretending it was a section.
//
// **One mechanism, both forms.** The section is *photographed* into a sheet — a
// clone, dead HTML, appended to a container that is a child of <body> — and while
// printing every other child of <body> is hidden with `display`. That is available
// precisely because the copies are nobody's descendant: the rule about not hiding an
// ancestor with `display` is about the original, and the original is not what goes on
// the paper.
//
// It used to be two mechanisms, and the simple one was wrong: it left the section
// where it was, hid everything else with `visibility` and pinned the target with
// `position: fixed`. A fixed box is exactly one viewport tall, so anything longer
// than the screen printed its first page and then stopped — silently, because a
// truncated print looks like a short document. The copy has no such ceiling: it is
// in the flow, and the flow is what pagination is made of.
//
// With `repeat=` it is the same act once per row of a collection. "A page per class"
// and "a page per teacher" are the same request repeated, and twenty classes is not
// something anybody writes by hand. The loop sets the reactive key to the row, waits
// for the views to catch up, and photographs. The key goes back to what it held when
// it is over, so the screen before and after says the same thing.

type labels = {
  print: string,
  printEach: string,
}

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  (string, string) => unit,
  string => Nullable.t<string>,
  (Collection.record, string) => string,
) => (Dom.element, string, labels) => unit = %raw(`
function (read, storeSet, storeGet, valueOf) {
  // The binders answer from IndexedDB, which reports to nobody: there is no event
  // meaning "every view has caught up with that key". So the wait is a wait — the
  // change is announced first, so the views that listen for it do go and read again,
  // and a frame is given to the ones that repaint synchronously.
  const settle = () => new Promise((resolve) => {
    window.dispatchEvent(new Event("rn:data"));
    setTimeout(() => requestAnimationFrame(() => resolve()), 160);
  });

  // A canvas is pixels, and cloneNode copies the element without them: a chart
  // photographed this way would print as a blank rectangle, which looks like the
  // chart is broken rather than like the copy is. So each one is replaced by the
  // picture it is currently showing.
  const freezeCanvases = (original, copy) => {
    const sources = original.querySelectorAll("canvas");
    const copies = copy.querySelectorAll("canvas");
    for (let i = 0; i < copies.length && i < sources.length; i++) {
      try {
        const picture = document.createElement("img");
        picture.src = sources[i].toDataURL("image/png");
        picture.className = "rn-print-canvas";
        picture.alt = "";
        copies[i].replaceWith(picture);
      } catch {
        // A tainted canvas refuses toDataURL. Nothing to photograph, and nothing
        // worth throwing away the whole print for.
      }
    }
  };

  const printing = (done) => {
    const off = () => {
      done();
      window.removeEventListener("afterprint", off);
    };
    window.addEventListener("afterprint", off);
    window.print();
  };

  return function (container, app, labels) {
    container.querySelectorAll("[data-rn-print]").forEach((button) => {
      // The default is words, so it is written here and not by the renderer, which is
      // installed once with no language. An author's own label is already in place.
      if (button.textContent.trim() === "") {
        button.textContent = button.hasAttribute("data-rn-print-repeat")
          ? labels.printEach
          : labels.print;
      }
      button.addEventListener("click", () => {
        const id = button.getAttribute("data-rn-print");
        const target = container.querySelector('[id="' + CSS.escape(id) + '"]');
        if (!target) return;

        const sheets = document.createElement("div");
        sheets.className = "rn-print-sheets";
        if (button.hasAttribute("data-rn-print-landscape")) {
          sheets.classList.add("rn-print-landscape");
        }
        const photograph = () => {
          const sheet = document.createElement("div");
          sheet.className = "rn-print-sheet";
          const copy = target.cloneNode(true);
          // Two ids for one section would be one too many, and the copy is the one
          // nothing may find: every binder addresses its work by id.
          copy.removeAttribute("id");
          copy.querySelectorAll("[id]").forEach((node) => node.removeAttribute("id"));
          freezeCanvases(target, copy);
          sheet.appendChild(copy);
          sheets.appendChild(sheet);
        };
        const paper = () => {
          document.body.appendChild(sheets);
          document.body.classList.add("rn-print-mode");
          printing(() => {
            document.body.classList.remove("rn-print-mode");
            sheets.remove();
            button.disabled = false;
          });
        };

        const path = button.getAttribute("data-rn-print-repeat");
        const key = button.getAttribute("data-rn-print-key") || "";
        if (!path || key === "" || !app) {
          photograph();
          paper();
          return;
        }

        // The id is what a reference stores, so it is what the key holds unless the
        // author names another field — and a form that filters by #key is reading the
        // same thing a ::input{type="ref"} would have written.
        const field = button.getAttribute("data-rn-print-field") || "";
        const held = storeGet(key);
        const before = held === null || held === undefined ? "" : String(held);
        button.disabled = true;

        read(app, path)
          .then(async (collection) => {
            for (const record of collection.records) {
              storeSet(key, field === "" ? record.id : valueOf(record, field));
              await settle();
              photograph();
            }
            // Back to where it was before anybody pressed anything: what is on screen
            // when the dialog closes has to be what was on screen when it opened.
            storeSet(key, before);
            await settle();
            paper();
          })
          .catch(() => {
            sheets.remove();
            button.disabled = false;
          });
      });
    });
  };
}
`)

let binder = install(CollectionStore.read, ReactiveStore.set, ReactiveStore.get, RowView.valueOf)

let bind = (container, ~app, ~labels) => binder(container, app, labels)
