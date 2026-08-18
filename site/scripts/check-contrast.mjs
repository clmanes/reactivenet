// Verifica WCAG 2.2 AA delle coppie colore usate in assets/css/main.css.
// Le coppie sono elencate qui a mano: se cambi un colore nel CSS, cambialo
// anche qui, o il controllo mente. Eseguire con: bun scripts/check-contrast.mjs

const colors = {
  bgLight: "#eceff4",
  bgRaisedLight: "#ffffff",
  fgLight: "#2e3440",
  mutedLight: "#585d68",
  codeBgLight: "#e2e6ed",
  primaryLight: "#5b3df5",

  bgDark: "#2a303c",
  bgRaisedDark: "#333a49",
  fgDark: "#b2ccd6",
  mutedDark: "#94aab4",
  codeBgDark: "#232833",
  primaryDark: "#a78bfa",

  white: "#ffffff",
  gradVioletLight: "#5b3df5",
  gradVioletDark: "#5b3df5",
  gradTeal: "#0f766e",
};

// [descrizione, testo, sfondo, minimo]
const pairs = [
  // tema chiaro
  ["testo su fondo, chiaro", colors.fgLight, colors.bgLight, 4.5],
  ["testo su superficie rialzata, chiaro", colors.fgLight, colors.bgRaisedLight, 4.5],
  ["testo attenuato su fondo, chiaro", colors.mutedLight, colors.bgLight, 4.5],
  ["link/primario su fondo, chiaro", colors.primaryLight, colors.bgLight, 4.5],
  ["testo nel codice, chiaro", colors.fgLight, colors.codeBgLight, 4.5],
  ["bottone: bianco su primario, chiaro", colors.white, colors.primaryLight, 4.5],
  ["badge: bianco su capo violetto, chiaro", colors.white, colors.gradVioletLight, 4.5],
  // tema scuro
  ["testo su fondo, scuro", colors.fgDark, colors.bgDark, 4.5],
  ["testo su superficie rialzata, scuro", colors.fgDark, colors.bgRaisedDark, 4.5],
  ["testo attenuato su fondo, scuro", colors.mutedDark, colors.bgDark, 4.5],
  ["link/primario su fondo, scuro", colors.primaryDark, colors.bgDark, 4.5],
  ["testo nel codice, scuro", colors.fgDark, colors.codeBgDark, 4.5],
  ["bottone: fondo scuro su primario, scuro", colors.bgDark, colors.primaryDark, 4.5],
  ["badge: bianco su capo violetto, scuro", colors.white, colors.gradVioletDark, 4.5],
  // il gradiente dei badge termina su questo teal in entrambi i temi
  ["badge: bianco su capo teal", colors.white, colors.gradTeal, 4.5],
  // messaggi d'errore dell'esploratore dati (--error → --sl-color-red)
  ["errore su fondo, chiaro", "#b3261e", colors.bgLight, 4.5],
  ["errore su fondo, scuro", "#f2857c", colors.bgDark, 4.5],
  // Primario dentro una banda tint: è l'eyebrow della scheda autore in home.
  // Su rialzato non ci va — il primario scuro lì misura 4.19:1 — e questa coppia
  // è ciò che lo tiene vero.
  ["primario su tint, chiaro", colors.primaryLight, colors.codeBgLight, 4.5],
  ["primario su tint, scuro", colors.primaryDark, colors.codeBgDark, 4.5],
  // Attenuato su rialzato: il testo delle why-card e l'etichetta delle schede
  // avanti/indietro.
  ["attenuato su rialzato, chiaro", colors.mutedLight, colors.bgRaisedLight, 4.5],
  ["attenuato su rialzato, scuro", colors.mutedDark, colors.bgRaisedDark, 4.5],
  // FAB LinkedIn: monogramma bianco sul blu del brand, uguale nei due temi
  ["FAB LinkedIn: bianco su blu", colors.white, "#0a66c2", 4.5],
  // scheda autore in home: ruolo e bio sono attenuati dentro la banda tint;
  // l'eyebrow è primario su tint (le due coppie sopra) e l'avatar riusa le
  // coppie dei bottoni (bianco/fondo scuro su primario).
  ["autore: attenuato su tint, chiaro", colors.mutedLight, colors.codeBgLight, 4.5],
  ["autore: attenuato su tint, scuro", colors.mutedDark, colors.codeBgDark, 4.5],
];

const channel = (hex, i) => parseInt(hex.slice(1 + i * 2, 3 + i * 2), 16) / 255;
const linear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const luminance = (hex) =>
  0.2126 * linear(channel(hex, 0)) +
  0.7152 * linear(channel(hex, 1)) +
  0.0722 * linear(channel(hex, 2));
const ratio = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

let failed = false;
for (const [label, fg, bg, min] of pairs) {
  const r = ratio(fg, bg);
  const ok = r >= min;
  if (!ok) failed = true;
  console.log(`${ok ? "✓" : "✗"} ${label}: ${r.toFixed(2)}:1 (minimo ${min}:1)`);
}
process.exit(failed ? 1 : 0);
