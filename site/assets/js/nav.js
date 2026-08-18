/* Menu burger mobile: il bottone esiste solo quando questo script gira,
   così senza JS la navigazione resta un elenco visibile. */
(function () {
  "use strict";
  var btn = document.querySelector(".nav-toggle");
  var header = document.querySelector(".site-header");
  if (!btn || !header) return;

  btn.hidden = false;

  function setOpen(open) {
    header.classList.toggle("is-open", open);
    btn.setAttribute("aria-expanded", String(open));
  }

  btn.addEventListener("click", function () {
    setOpen(!header.classList.contains("is-open"));
  });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && header.classList.contains("is-open")) {
      setOpen(false);
      btn.focus();
    }
  });

  // Un tap su una voce chiude il menu: la navigazione è avvenuta.
  header.addEventListener("click", function (e) {
    if (e.target.closest(".site-nav a")) setOpen(false);
  });
})();

/* Navbar hero (home): parte invisibile sopra l'hero a schermo pieno e si
   materializza gradualmente con lo scroll — opacità e discesa proporzionali
   alla posizione, nessuno scatto on/off. Stesse soglie del FAB, così i due
   elementi appaiono insieme. */
(function () {
  "use strict";
  var hdr = document.querySelector(".site-header.hero-nav");
  if (!hdr) return;
  var raf = 0;
  function apply() {
    raf = 0;
    var p = Math.min(Math.max((window.scrollY - 30) / 170, 0), 1);
    // A reveal completo la classe `on` riporta la barra allo stato normale
    // via CSS e gli inline style si tolgono TUTTI: un transform:'' inline
    // ricadrebbe sul translateY(-40%) di base. visibility esplicita quando
    // parzialmente visibile: '' ricadrebbe sull'hidden dello stato iniziale.
    hdr.classList.toggle("on", p >= 1);
    if (p >= 1) {
      hdr.style.opacity = "";
      hdr.style.transform = "";
      hdr.style.pointerEvents = "";
      hdr.style.visibility = "";
    } else {
      hdr.style.opacity = String(p);
      hdr.style.transform = "translateY(" + (p - 1) * 40 + "%)";
      hdr.style.pointerEvents = p > 0.35 ? "auto" : "none";
      hdr.style.visibility = p > 0 ? "visible" : "";
    }
  }
  window.addEventListener(
    "scroll",
    function () {
      if (!raf) raf = requestAnimationFrame(apply);
    },
    { passive: true }
  );
  apply(); // stato iniziale corretto anche ricaricando a metà pagina
})();

/* FAB LinkedIn: non copre mai il footer (quando il footer entra nel viewport
   il bottone si ferma sopra il suo bordo, via --li-lift) e in home si
   materializza con lo scroll, come sul vecchio sito. */
(function () {
  "use strict";
  var btn = document.querySelector(".linkedin-float");
  if (!btn) return;
  var hero = btn.classList.contains("hero-reveal");
  var footer = document.querySelector(".site-footer");
  var raf = 0;
  function apply() {
    raf = 0;
    if (footer) {
      var overlap = window.innerHeight - footer.getBoundingClientRect().top;
      btn.style.setProperty("--li-lift", Math.max(overlap, 0) + "px");
    }
    if (hero) {
      var p = Math.min(Math.max((window.scrollY - 30) / 170, 0), 1);
      // A reveal completo si passa alla classe `on` e si tolgono TUTTI gli
      // inline style: lo stato nascosto del CSS vale solo per :not(.on).
      // Un inline transform:'' ricadrebbe sul translateY(40%) di base —
      // bottone più in basso per sempre. pointer-events 'auto' esplicito:
      // '' ricadrebbe sul none dello stato iniziale.
      btn.classList.toggle("on", p >= 1);
      btn.style.opacity = p >= 1 ? "" : String(p);
      btn.style.transform = p >= 1 ? "" : "translateY(" + (1 - p) * 40 + "%)";
      btn.style.pointerEvents = p >= 1 ? "" : p > 0.35 ? "auto" : "none";
    }
  }
  function schedule() {
    if (!raf) raf = requestAnimationFrame(apply);
  }
  window.addEventListener("scroll", schedule, { passive: true });
  window.addEventListener("resize", schedule, { passive: true });
  // La posizione del footer cambia anche senza scroll (immagini/font/canvas
  // che arrivano dopo): un ResizeObserver sul body ricalcola il lift.
  new ResizeObserver(schedule).observe(document.body);
  apply();
})();

/* §2.2.2: chi chiede meno movimento non riceve video che partono da soli.
   I controls restano, quindi il video si può comunque avviare a mano. */
(function () {
  "use strict";
  if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  document.querySelectorAll("video[autoplay]").forEach(function (v) {
    v.removeAttribute("autoplay");
    v.pause();
  });
})();

/* Le clip della home: non scaricano niente finché non entrano in campo e non
   girano quando non si vedono — un video fermo fuori schermo è banda e
   batteria buttate. Un solo bottone le ferma tutte (§2.2.2), e chi chiede
   meno movimento le trova già ferme sul poster. */
(function () {
  "use strict";
  var clips = Array.prototype.slice.call(document.querySelectorAll("video.clip"));
  if (!clips.length || !("IntersectionObserver" in window)) return;
  var btn = document.querySelector(".clip-toggle");
  var visible = new Set();
  // prefers-reduced-motion decide lo stato iniziale, non la disponibilità:
  // il bottone resta e permette di avviarle comunque.
  var paused = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function label() {
    if (!btn) return;
    var text = paused ? btn.dataset.labelPlay : btn.dataset.labelPause;
    btn.textContent = text;
  }

  function sync() {
    clips.forEach(function (v) {
      if (!paused && visible.has(v)) {
        // play() rifiuta se il browser nega l'autoplay: è un caso normale,
        // non un errore da propagare.
        var p = v.play();
        if (p && p.catch) p.catch(function () {});
      } else {
        v.pause();
      }
    });
  }

  var io = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) visible.add(e.target);
        else visible.delete(e.target);
      });
      sync();
    },
    { threshold: 0.35 }
  );
  clips.forEach(function (v) {
    io.observe(v);
  });

  if (btn) {
    btn.hidden = false;
    label();
    btn.addEventListener("click", function () {
      paused = !paused;
      label();
      sync();
    });
  }
})();
