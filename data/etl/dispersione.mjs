// Ingestione della DISPERSIONE SCOLASTICA (abbandono) → tabella
// `dispersione_scolastica` in DuckDB + riga nel `catalog`. Una riga per
// (regione|ITALIA, grado, anno di frequenza): tasso di abbandono complessivo
// (%). Il dato più citato sulla dispersione scolastica italiana, con serie
// storica nazionale e dettaglio regionale.
//
// Fonte (nessuna chiave, riuso libero con citazione): il Ministero
// dell'Istruzione — Ufficio di Statistica NON pubblica un file CSV/XLSX per
// questo fenomeno, solo una serie di PDF "Focus" biennali. Le tabelle e i
// grafici in quei PDF hanno però ETICHETTE NUMERICHE VERE nel layer di
// testo del PDF (non immagini raster) — VERIFICATO scaricando i file e
// ispezionando le coordinate x/y di ogni frammento di testo con pdfjs-dist
// (la stessa libreria già usata dal progetto per il RAG dei PDF, vedi
// RagIndex.js). Si ricostruiscono le coppie (etichetta, valore) per
// prossimità di coordinate — MAI un modello vision che "legge" un grafico:
// qui il numero è testo esatto del ministero, zero rischio di allucinazione.
//
// QUATTRO edizioni, coperture NON sovrapposte (ogni nuova edizione copre i
// bienni successivi all'ultima pubblicata):
//   2015/16-2016/17 (dic.2017) · 2016/17-2017/18 (2019) ·
//   2017/18-2018/19 e 2018/19-2019/20 (giu.2021) ·
//   2019/20-2020/21 e 2020/21-2021/22 (dic.2023, la più recente)
// → 6 bienni contigui, 2015-2020, per il dettaglio REGIONALE.
// La serie STORICA NAZIONALE (Graf.17/18/19 dell'edizione più recente) copre
// da sola 2013/14 a 2020/21 (8 punti): non serve ricostruirla dalle edizioni
// precedenti, la più recente la ripubblica per intero.
//
// TRAPPOLE:
//  - il grafico regionale copre 18 regioni + ITALIA: Valle d'Aosta e
//    Trentino-Alto Adige (Trento/Bolzano) sono ASSENTI dalla fonte per
//    l'intera serie di edizioni — non un buco dell'estrattore, il Focus non
//    le riporta mai (a differenza di INVALSI, che invece include le
//    province autonome);
//  - il grafico "passaggio tra cicli scolastici" NON ha in ogni edizione il
//    dettaglio regionale completo (a volte solo un confronto tra le 6
//    regioni col differenziale di genere più marcato, o è del tutto
//    assente): si prende quello che c'è, non si inventa;
//  - le etichette nei grafici hanno spazi spuri interni per un font TrueType
//    con lo spazio (glifo 32) rotto ("Lomba rdia" invece di "Lombardia"): il
//    match dei nomi regione è per confronto NORMALIZZATO (solo lettere,
//    maiuscolo, accenti rimossi), mai sulla stringa grezza;
//  - le etichette di una stessa riga di un grafico a barre sono sfalsate in
//    verticale di ±20pt (per non sovrapporsi): il clustering per banda-y usa
//    un centroide mobile con tolleranza 25pt, non un'ancora fissa;
//  - copertura regionale PARZIALE per costruzione: qualche barra non ha
//    l'etichetta numerica abbastanza vicina in x per essere accoppiata con
//    sicurezza (tolleranza 20pt) — si scarta la singola cella piuttosto che
//    rischiare un accoppiamento sbagliato;
//  - il valore ITALIA del grafico regionale è ridondante con la serie
//    storica nazionale (la copre per intero): si tiene SOLO la serie
//    nazionale per le righe regione='ITALIA', si scarta il valore ITALIA
//    letto dai grafici regionali.
//
// Uso:  bun etl/dispersione.mjs [--refresh]
//   --refresh  ignora la cache in raw/dispersione/ e riscarica

import { mkdirSync } from "node:fs";
import { DuckDBInstance } from "@duckdb/node-api";

const ROOT = new URL("..", import.meta.url).pathname; // data/
const RAW = ROOT + "raw/dispersione/";
const DB = ROOT + "warehouse.duckdb";

const refresh = process.argv.includes("--refresh");
const esc = s => String(s).replaceAll("'", "''");

const pdfjsLib = await import("pdfjs-dist/legacy/build/pdf.mjs");

// edizioni: URL diretto (documentale, non cambia — verificato manualmente,
// niente pagina-indice da cui risolverlo: il portale pubblicazioni MIM non
// espone un catalogo strutturato per questa serie) + bienni coperti, in
// ordine cronologico (= ordine dei cluster dall'alto in basso nella pagina).
const EDIZIONI = [
  {
    id: "2015-2017",
    url: "https://www.mim.gov.it/documents/20182/0/Focus+La+dispersione+scolastica",
    bienni: [{ anno: 2015, periodo: "2015/2016-2016/2017" }],
  },
  {
    id: "2016-2019",
    url: "https://www.mim.gov.it/documents/20182/2155736/La+dispersione+scolastica+nell'a.s.2016-17+e+nel+passaggio+all'a.s.2017-18.pdf/1e374ddd-29ac-11e2-dede-4710d6613062?version=1.0&t=1563371652741",
    bienni: [{ anno: 2016, periodo: "2016/2017-2017/2018" }],
  },
  {
    id: "2017-2021",
    url: "https://www.mim.gov.it/documents/20182/0/La+dispersione+scolastica+aa.ss.2018-2019+e+aa.ss.2019-2020.pdf/99ea3b7c-5bef-dbd1-c20f-05fed434406f?version=1.0&t=1622822637421",
    bienni: [
      { anno: 2017, periodo: "2017/2018-2018/2019" },
      { anno: 2018, periodo: "2018/2019-2019/2020" },
    ],
  },
  {
    id: "2019-2023",
    url: "https://www.mim.gov.it/documents/20182/7715421/Focus_Dispersione+scolastica+aa.ss.1920_2021+-+2021_2122.pdf/7574e014-b372-d32c-a62c-ddabbd5d7c7c?version=1.0&t=1703760495410",
    bienni: [
      { anno: 2019, periodo: "2019/2020-2020/2021" },
      { anno: 2020, periodo: "2020/2021-2021/2022" },
    ],
    nazionale: true, // l'unica che serve per la serie storica nazionale (la ripubblica per intero)
  },
];

// nomi ESATTI di istat_confini_regioni.regione (con trattino): il match dei
// grafici passa comunque per il confronto normalizzato, ma il valore salvato
// deve combaciare col resto del warehouse per la relazione in semantica.mjs.
const REGIONI = [
  "Piemonte", "Lombardia", "Liguria", "Veneto", "Friuli-Venezia Giulia", "Emilia-Romagna",
  "Toscana", "Umbria", "Marche", "Lazio", "Abruzzo", "Molise", "Campania", "Puglia",
  "Basilicata", "Calabria", "Sicilia", "Sardegna",
];
const norm = s => String(s).normalize("NFD").replace(/\p{Diacritic}/gu, "").replace(/[^A-Za-z]/g, "").toUpperCase();
const REGIONI_N = new Map(REGIONI.map(r => [norm(r), r]));
REGIONI_N.set(norm("Friuli V.G."), "Friuli-Venezia Giulia");
REGIONI_N.set(norm("E.Romagna"), "Emilia-Romagna");
REGIONI_N.set(norm("E.Romag"), "Emilia-Romagna"); // troncato a fine riga in alcune edizioni

function gradoFromCaption(s) {
  if (/passaggio\s+tra\s+cicli/i.test(s)) return "passaggio cicli";
  if (/\bII\s+grado\b/i.test(s)) return "II grado";
  if (/\bI\s+grado\b/i.test(s)) return "I grado";
  return null;
}

mkdirSync(RAW, { recursive: true });
console.log("▸ dispersione scolastica (MIM — Ufficio di Statistica)");

async function loadPdf(ed) {
  const path = `${RAW}${ed.id}.pdf`;
  if (refresh || !(await Bun.file(path).exists())) {
    const res = await fetch(ed.url, { signal: AbortSignal.timeout(120_000) });
    if (!res.ok) throw new Error(`${ed.id}: HTTP ${res.status}`);
    await Bun.write(path, await res.arrayBuffer());
    console.log(`  scaricato ${ed.id}.pdf`);
  } else {
    console.log(`  ${ed.id}.pdf da cache`);
  }
  const data = new Uint8Array(await Bun.file(path).arrayBuffer());
  return pdfjsLib.getDocument({ data, useSystemFonts: true }).promise;
}

async function pageItems(doc, p) {
  const page = await doc.getPage(p);
  const content = await page.getTextContent();
  const items = content.items
    .map(it => ({ str: it.str, x: it.transform[4], y: it.transform[5] }))
    .filter(it => it.str.trim());
  items.sort((a, b) => b.y - a.y || a.x - b.x); // lettura: alto->basso, sx->dx
  return items;
}

// --- 1. dettaglio regionale: tutte e 4 le edizioni ---------------------------------

const regionali = [];
for (const ed of EDIZIONI) {
  const doc = await loadPdf(ed);
  let currentGrado = null;
  const clusters = []; // { grado, page, y, values: [{regione, valore}] }

  for (let p = 1; p <= doc.numPages; p++) {
    const items = await pageItems(doc, p);

    const nameItems = [];
    for (const it of items) {
      if (/^Graf\.?\s*\d/.test(it.str) || /abbandono complessivo/i.test(it.str)) {
        const g = gradoFromCaption(it.str);
        if (g) currentGrado = g;
      }
      const key = norm(it.str);
      if (REGIONI_N.has(key)) nameItems.push({ ...it, regione: REGIONI_N.get(key) });
    }

    // banda-y con centroide mobile: le etichette di una riga sono sfalsate ±20pt
    const bands = [];
    for (const it of nameItems) {
      let band = bands.find(b => Math.abs(b.y - it.y) < 25);
      if (!band) { band = { y: it.y, items: [] }; bands.push(band); }
      band.items.push(it);
      band.y = band.items.reduce((s, x) => s + x.y, 0) / band.items.length;
    }

    for (const band of bands) {
      if (band.items.length < 10) continue; // rumore (menzioni sparse nel testo), non un grafico
      const values = [];
      for (const nameIt of band.items) {
        let best = null, bestDx = Infinity;
        for (const it of items) {
          if (!/^\d,\d{1,2}\s*$/.test(it.str)) continue;
          if (it.y <= band.y || it.y > band.y + 160) continue;
          const dx = Math.abs(it.x - nameIt.x);
          if (dx < bestDx) { bestDx = dx; best = it; }
        }
        if (best && bestDx < 20 && nameIt.regione !== "ITALIA") {
          values.push({ regione: nameIt.regione, valore: parseFloat(best.str.replace(",", ".")) });
        }
      }
      if (values.length) clusters.push({ grado: currentGrado, page: p, y: band.y, values });
    }
  }

  clusters.sort((a, b) => a.page - b.page || b.y - a.y); // ordine di lettura: alto->basso
  const byGrado = new Map();
  for (const c of clusters) {
    if (!c.grado) continue;
    if (!byGrado.has(c.grado)) byGrado.set(c.grado, []);
    byGrado.get(c.grado).push(c);
  }
  for (const [grado, gradoClusters] of byGrado) {
    gradoClusters.forEach((c, i) => {
      const biennio = ed.bienni[i];
      if (!biennio) return; // più cluster del previsto: scarta l'eccedenza piuttosto che disallineare i bienni
      for (const v of c.values) {
        regionali.push({
          regione: v.regione, grado, anno_frequenza: biennio.anno,
          periodo: biennio.periodo, tasso_abbandono_perc: v.valore, edizione: ed.id,
        });
      }
    });
  }
  console.log(`  ${ed.id}: ${[...byGrado.entries()].map(([g, c]) => `${g} x${c.length}`).join(", ") || "nessun grafico regionale trovato"}`);
}
console.log(`  totale righe regionali: ${regionali.length}`);

// --- 2. serie storica nazionale: solo l'edizione più recente (la ripubblica intera) --

const nazionali = [];
{
  const ed = EDIZIONI.find(e => e.nazionale);
  const doc = await loadPdf(ed);
  for (let p = 1; p <= doc.numPages; p++) {
    const items = await pageItems(doc, p);
    // una pagina può contenere PIÙ grafici (es. Graf.18 e Graf.19 sulla stessa
    // pagina): ogni titolo delimita la propria finestra-y fino al titolo
    // successivo (o al fondo pagina), altrimenti i punti dei due grafici si
    // mescolano in un'unica ricerca.
    const titoli = items
      .filter(it => /Graf\.?\s*\d+.*serie storica/i.test(it.str))
      .sort((a, b) => b.y - a.y); // alto->basso
    for (let ti = 0; ti < titoli.length; ti++) {
      const titolo = titoli[ti];
      const grado = gradoFromCaption(titolo.str);
      if (!grado) continue;
      const yMax = titolo.y;
      const yMin = ti + 1 < titoli.length ? titoli[ti + 1].y : -Infinity;
      const chartItems = items.filter(it => it.y < yMax && it.y > yMin);

      // asse x: due righe "a.s.YYYY/YYYY -" (anno iniziale) e "a.s.YYYY/YYYY"
      // (anno finale, senza trattino) su bande y distinte, accoppiate per x
      // più vicina
      const start = chartItems.filter(it => /^a\.s\.\d{4}\/\d{4}\s*-\s*$/.test(it.str));
      const end = chartItems.filter(it => /^a\.s\.\d{4}\/\d{4}\s*$/.test(it.str) && !start.includes(it));
      if (!start.length || !end.length) continue;

      for (const s of start) {
        const e = end.reduce((best, it) => (Math.abs(it.x - s.x) < Math.abs((best?.x ?? Infinity) - s.x) ? it : best), null);
        let best = null, bestDx = Infinity;
        for (const it of chartItems) {
          if (!/^\d,\d{1,2}\s*$/.test(it.str)) continue;
          if (it.y <= s.y) continue; // il valore sta SOPRA l'etichetta dell'asse
          const dx = Math.abs(it.x - s.x);
          if (dx < bestDx) { bestDx = dx; best = it; }
        }
        if (best && bestDx < 30 && e) {
          const annoIniziale = Number(s.str.match(/(\d{4})\/\d{4}/)[1]);
          nazionali.push({
            regione: "ITALIA", grado, anno_frequenza: annoIniziale,
            periodo: `${s.str.match(/\d{4}\/\d{4}/)[0]}-${e.str.match(/\d{4}\/\d{4}/)[0]}`,
            tasso_abbandono_perc: parseFloat(best.str.replace(",", ".")), edizione: ed.id,
          });
        }
      }
    }
  }
  console.log(`  serie storica nazionale: ${nazionali.length} punti (attesi 24 = 3 gradi x 8 anni)`);
}

// --- 3. CSV intermedio + caricamento in DuckDB --------------------------------------

const allRows = [...nazionali, ...regionali];
const csvEsc = v => (v == null ? "" : `"${String(v).replaceAll('"', '""')}"`);
const cols = ["regione", "grado", "anno_frequenza", "periodo", "tasso_abbandono_perc", "edizione"];
const csv = cols.join(",") + "\n" + allRows.map(r => cols.map(c => csvEsc(r[c])).join(",")).join("\n");
await Bun.write(`${RAW}dispersione.csv`, csv);

const instance = await DuckDBInstance.create(DB);
const con = await instance.connect();
// OBBLIGATORIO: le tabelle con indice HNSW (lex_atti, anac_cig, opencoesione)
// non si ricostruiscono dal CHECKPOINT senza l'estensione, e il CHECKPOINT
// tocca tutto il database.
await con.run("INSTALL vss");
await con.run("LOAD vss");

await con.run(`CREATE OR REPLACE TABLE dispersione_scolastica AS
SELECT
  regione, grado, anno_frequenza::INTEGER AS anno_frequenza, periodo,
  tasso_abbandono_perc::DOUBLE AS tasso_abbandono_perc, edizione
FROM read_csv('${RAW}dispersione.csv', header = true, all_varchar = true)`);

const stat = (
  await con.runAndReadAll(`SELECT count(*) AS n, count(DISTINCT regione) AS territori,
    min(anno_frequenza) AS da, max(anno_frequenza) AS a FROM dispersione_scolastica`)
).getRowObjects()[0];
console.log(`  dispersione_scolastica: ${stat.n} righe — ${stat.territori} territori (18 regioni + ITALIA), anni ${stat.da}-${Number(stat.a) + 1}`);

// --- 4. riga di catalogo --------------------------------------------------------------

const colsOut = (
  await con.runAndReadAll(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = 'dispersione_scolastica' ORDER BY ordinal_position`,
  )
).getRowObjects().map(c => ({ name: c.column_name, type: c.data_type }));

const titleIt = "Dispersione scolastica: tasso di abbandono per regione e serie storica (MIM)";
const titleEn = "School drop-out rate by region and historical trend (MIM)";
const descIt = `Tasso di abbandono scolastico complessivo (%), fonte MIM — Ufficio di Statistica, Anagrafe Nazionale degli Studenti (riuso libero con citazione). Serie storica NAZIONALE (regione='ITALIA') dall'a.s.2013/2014 all'a.s.2020/2021, per grado (I grado, passaggio tra cicli, II grado). Dettaglio REGIONALE per 6 bienni consecutivi dal 2015/2016 al 2020/2021 (18 regioni, coperture non sovrapposte tra edizioni successive del Focus ministeriale). Estratto dai PDF ufficiali con parsing a coordinate delle etichette numeriche del layer di testo (non da un modello vision): il ministero non pubblica un export CSV/XLSX per questo fenomeno. Valle d'Aosta e Trentino-Alto Adige assenti dalla fonte per l'intera serie; il grafico "passaggio tra cicli" non ha dettaglio regionale in tutte le edizioni.`;
const descEn = `Overall school drop-out rate (%), source MIM — Statistics Office, National Student Registry (free reuse with attribution). NATIONAL historical series (regione='ITALIA') from school year 2013/2014 to 2020/2021, by grade (lower secondary, cycle transition, upper secondary). REGIONAL detail for 6 consecutive two-year periods from 2015/2016 to 2020/2021 (18 regions, non-overlapping coverage across successive ministry Focus editions). Extracted from the official PDFs via coordinate-based parsing of the text layer's numeric labels (not a vision model): the ministry publishes no CSV/XLSX export for this indicator. Valle d'Aosta and Trentino-Alto Adige are absent from the source for the whole series; the "cycle transition" chart lacks regional detail in every edition.`;
await con.run(`DELETE FROM catalog WHERE table_name = 'dispersione_scolastica'`);
await con.run(`INSERT INTO catalog (table_name, source, dataflow, title_it, title_en, description_it, description_en, url, updated, row_count, columns)
  VALUES ('dispersione_scolastica', 'mim.gov.it', 'scuola/dispersione-scolastica',
    '${esc(titleIt)}', '${esc(titleEn)}', '${esc(descIt)}', '${esc(descEn)}',
    'https://www.mim.gov.it/web/guest/pubblicazioni', now(), ${Number(stat.n)}, '${esc(JSON.stringify(colsOut))}')`);

console.log(`\ndispersione_scolastica: ${stat.n} righe (anni ${stat.da}-${Number(stat.a) + 1})`);
// Consolida il WAL nel file principale: la deploy pubblica SOLO warehouse.duckdb
// (mai il .wal), quindi a fine ETL il file dev'essere autosufficiente.
await con.run("CHECKPOINT")
con.closeSync();
