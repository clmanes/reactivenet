// Crosswalk condiviso REF_AREA (SDMX ISTAT, codelist CL_ITTER107) → nome
// provincia in italiano. Diversi dataflow SDMX ISTAT (delitti, turismo, …)
// geolocalizzano a livello PROVINCIA con codici NUTS-simili (es. "ITC11" =
// Torino) invece del codice ISTAT numerico usato altrove nel warehouse: qui
// si estrae la mappa codice→nome dalla struttura del dataflow (via
// `references=all`) e si lascia poi il join per NOME alla query di ogni ETL
// (contro istat_confini_province.provincia, univoco).
//
// Cache su file (../raw/istat-geo/itter107.tsv): la struttura è ~200.000
// righe XML, costosa da riscaricare — un solo fetch condiviso da tutti gli
// ETL che ne hanno bisogno.

const DSD_URL = "https://esploradati.istat.it/SDMXWS/rest/dataflow/IT1/{FLOW}/1.0?references=all";

// estrae {codice: nomeIT} dal blocco <structure:Codelist id="CL_ITTER107">…
function parseItter107(xml) {
  const m = xml.match(/<structure:Codelist id="CL_ITTER107"[\s\S]*?<\/structure:Codelist>/);
  if (!m) throw new Error("CL_ITTER107 non trovato nella struttura del dataflow");
  const out = new Map();
  const codeRe = /<structure:Code id="([^"]+)">([\s\S]*?)<\/structure:Code>/g;
  let cm;
  while ((cm = codeRe.exec(m[0]))) {
    const nameM = cm[2].match(/<common:Name xml:lang="it">([^<]+)<\/common:Name>/);
    if (nameM) out.set(cm[1], nameM[1]);
  }
  return out;
}

// carica il crosswalk (dalla cache se presente), filtrato ai soli codici
// provincia (5 caratteri "ITxxx"): il codelist copre anche regioni, aree
// macro, comuni e SLL nello stesso spazio di codici.
export async function loadItter107Province(rawGeoDir, { refresh = false, dataflow = "73_67_DF_DCCV_DELITTIPS_9" } = {}) {
  const cachePath = `${rawGeoDir}itter107.tsv`;
  let text;
  if (!refresh && (await Bun.file(cachePath).exists())) {
    text = await Bun.file(cachePath).text();
  } else {
    const res = await fetch(DSD_URL.replace("{FLOW}", dataflow), {
      headers: { accept: "application/xml" },
      signal: AbortSignal.timeout(120_000),
    });
    if (!res.ok) throw new Error(`dataflow structure: HTTP ${res.status}`);
    const map = parseItter107(await res.text());
    text = [...map.entries()].map(([c, n]) => `${c}\t${n}`).join("\n");
    await Bun.write(cachePath, text);
  }
  const map = new Map();
  for (const line of text.split("\n")) {
    const [code, name] = line.split("\t");
    if (code && name && /^IT[A-Z0-9]{3}$/.test(code)) map.set(code, name);
  }
  return map;
}
