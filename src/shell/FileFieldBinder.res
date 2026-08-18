// The working half of `::file`: reads the chosen file, caps it, decides where
// its bytes live, and writes the VALUE — a small JSON of {name, data} or
// {name, local} — into the hidden field the form's draft already reads.
//
// The 300 kB line is the sync ceiling's, not taste: a value inside a row
// travels inside a sync change, and past that the change would grow beyond
// what the server accepts (the same arithmetic as a chat attachment). Bigger
// files — up to maxkb, default 10 MB — go to FileStore on THIS device, and the
// row carries the name plus a local id: elsewhere the name shows, the content
// honestly does not exist.

type labels = {tooBig: string}

let install: (
  (~app: string, ~id: string, string) => promise<unit>,
) => (Dom.element, string, labels) => unit = %raw(`
function (saveLocal) {
  const INLINE_CEILING = 300000;

  return function (container, app, labels) {
    container.querySelectorAll("[data-rn-file]").forEach((input) => {
      const holder = input.closest(".rn-file-field");
      const hidden = holder && holder.querySelector('input[type="hidden"].rn-field-input');
      const preview = holder && holder.querySelector(".rn-file-preview");
      const status = holder && holder.querySelector(".rn-od-status");
      if (!hidden) return;

      const accept = input.getAttribute("data-rn-file-accept");
      if (accept) input.accept = accept;
      const maxGiven = parseInt(input.getAttribute("data-rn-file-maxkb") || "", 10);
      const maxBytes = (Number.isNaN(maxGiven) ? 10240 : maxGiven) * 1024;

      const say = (text, error) => {
        if (!status) return;
        status.textContent = text;
        status.className = "rn-od-status " + (error ? "rn-error" : "rn-muted");
      };

      const paintPreview = (name, dataUrl) => {
        if (!preview) return;
        preview.textContent = "";
        if (dataUrl && dataUrl.startsWith("data:image/")) {
          const img = document.createElement("img");
          img.src = dataUrl;
          img.alt = name;
          img.className = "rn-file-image";
          preview.appendChild(img);
        } else if (name) {
          preview.textContent = name;
        }
      };

      input.addEventListener("change", () => {
        const file = input.files && input.files[0];
        if (!file) return;
        say("", false);
        if (file.size > maxBytes) {
          input.value = "";
          say(labels.tooBig.replace("{n}", String(Math.floor(maxBytes / 1024))), true);
          return;
        }
        const reader = new FileReader();
        reader.onload = async () => {
          const dataUrl = String(reader.result);
          let value;
          if (file.size <= INLINE_CEILING) {
            value = JSON.stringify({ name: file.name, data: dataUrl });
          } else {
            const id = crypto.randomUUID();
            await saveLocal(app, id, dataUrl);
            value = JSON.stringify({ name: file.name, local: id });
          }
          hidden.value = value;
          hidden.dispatchEvent(new Event("input", { bubbles: true }));
          paintPreview(file.name, dataUrl);
        };
        reader.onerror = () => say(labels.tooBig, true);
        reader.readAsDataURL(file);
      });
    });
  };
}
`)

let binder = install(FileStore.save)

let bind = (container, ~app, ~labels) => binder(container, app, labels)
