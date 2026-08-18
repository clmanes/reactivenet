/* Bottone pausa dell'animazione three.js (§2.2.2) + copia indirizzo MCP.
   L'animazione è quella del sito originale (vendor/hero-three.js), patchata
   per leggere window.__heroPaused nel proprio loop: qui c'è solo il controllo. */
(function () {
  "use strict";

  /* ---- Copia indirizzo MCP ---- */
  var copyBtn = document.querySelector(".hero-mcp-copy");
  if (copyBtn && navigator.clipboard) {
    var code = copyBtn.querySelector("code");
    var status = copyBtn.querySelector("[role=status]");
    var original = code.textContent;
    var timer = null;
    copyBtn.addEventListener("click", function () {
      navigator.clipboard.writeText(copyBtn.dataset.url).then(function () {
        code.textContent = copyBtn.dataset.copied;
        if (status) status.textContent = copyBtn.dataset.copied;
        clearTimeout(timer);
        timer = setTimeout(function () {
          code.textContent = original;
          if (status) status.textContent = "";
        }, 1600);
      });
    });
  }

  /* ---- Pausa/riavvio dell'animazione ---- */
  var toggle = document.querySelector(".anim-toggle");
  if (!toggle) return;

  // Con prefers-reduced-motion l'animazione non parte affatto (lo decide
  // hero-three.js): niente movimento automatico, niente bottone.
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  window.__heroPaused = false;
  toggle.hidden = false;
  toggle.addEventListener("click", function () {
    window.__heroPaused = !window.__heroPaused;
    toggle.setAttribute("aria-pressed", String(window.__heroPaused));
    toggle.setAttribute(
      "aria-label",
      window.__heroPaused ? toggle.dataset.labelPlay : toggle.dataset.labelPause
    );
    if (!window.__heroPaused) {
      // Il loop patchato riparte dal gestore di visibilitychange.
      document.dispatchEvent(new Event("visibilitychange"));
    }
  });
})();
