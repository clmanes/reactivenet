// The static Chart.js imports, reached ONLY through the dynamic import() in
// ChartBinder — that is what keeps the charting engine out of the initial
// bundle: a document with no chart never loads a byte of it. Same policy as
// BlockNoteImpl and SpectrumElements.

%%raw(`
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);
`)

type chart

let render: (Dom.element, {..}) => chart = %raw(`
function (canvas, config) {
  return new Chart(canvas, config);
}
`)

let destroy: chart => unit = %raw(`
function (chart) {
  try { chart.destroy(); } catch {}
}
`)
