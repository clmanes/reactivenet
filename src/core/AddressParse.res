// Spezza un indirizzo italiano scritto a mano nelle parti che l'ANNCSU indicizza:
// l'odonimo, il numero civico col suo esponente, e il comune.
//
// Perché sta in core/ e non dentro il binder: è la parte che decide COSA si cerca, e
// sbagliarla non produce un errore ma un punto sbagliato — cioè il tipo di guasto che
// una mappa mostra senza denunciare. Qui è pura, totale e provata riga per riga.
//
// LE REGOLE, e sono deliberatamente poche. Un parser di indirizzi può crescere senza
// fine, e ogni regola in più è un caso in cui indovina invece di leggere:
//
//   - le virgole separano i pezzi. L'ULTIMO è il comune, il PRIMO è la strada;
//   - dal comune si tolgono il CAP in testa (cinque cifre) e la sigla di provincia in
//     coda, fra parentesi o dopo un trattino: "75100 Matera (MT)" è "Matera";
//   - dalla strada si stacca un numero in CODA, con l'eventuale esponente attaccato o
//     separato da una barra: "Via Roma 12/A" è "Via Roma" + 12 + A;
//   - se la strada non ha numero e i pezzi sono tre o più, il secondo pezzo può essere
//     il numero da solo: "Via Lucana, 53, Matera";
//   - senza strada o senza comune non si restituisce nulla. Un indirizzo a metà
//     cercato lo stesso trova QUALCOSA, ed è il modo peggiore di sbagliare.
//
// Quello che NON fa, per scelta: non normalizza le abbreviazioni (V. → VIA), non
// riconosce le frazioni, non indovina il comune da un CAP. Sono tutte cose che
// richiedono una tabella, e una tabella sbagliata è peggio di una ricerca fallita —
// chi non trova riprova, chi trova il punto sbagliato non lo sa.

type t = {
  odonimo: string,
  civico: string,
  esponente: string,
  comune: string,
}

let trim = s => s->String.trim

// "75100 Matera (MT)" / "Matera - MT" → "Matera"
let pulisciComune = testo => {
  let senzaCap = testo->String.replaceRegExp(%re("/^\s*\d{5}\s+/"), "")
  let senzaSigla =
    senzaCap
    ->String.replaceRegExp(%re("/\s*\([A-Za-z]{2}\)\s*$/"), "")
    ->String.replaceRegExp(%re("/\s+-\s*[A-Za-z]{2}\s*$/"), "")
  senzaSigla->trim
}

// "Via Roma 12/A" → ("Via Roma", "12", "A"); "Via Roma" → ("Via Roma", "", "")
let staccaCivico = testo => {
  let t = testo->trim
  switch %re("/^(.*?)[\s,]+(\d+)\s*(?:\/\s*)?([A-Za-z])?\s*$/")->RegExp.exec(t) {
  | Some(m) =>
    let parte = i => m->RegExp.Result.matches->Array.at(i)->Option.flatMap(v => v)->Option.getOr("")->trim
    let via = parte(0)
    via == "" ? (t, "", "") : (via, parte(1), parte(2)->String.toUpperCase)
  | None => (t, "", "")
  }
}

let soloCifre = s => s != "" && s->String.split("")->Array.every(c => c >= "0" && c <= "9")

let parse = testo => {
  let pezzi =
    testo->String.split(",")->Array.map(trim)->Array.filter(p => p != "")
  switch pezzi->Array.length {
  | 0 | 1 => None
  | n =>
    let comune = pezzi->Array.getUnsafe(n - 1)->pulisciComune
    let (via, civico, esponente) = staccaCivico(pezzi->Array.getUnsafe(0))
    // "Via Lucana, 53, Matera": il numero è il pezzo di mezzo, non in coda alla via
    let (civico, esponente) = if civico == "" && n >= 3 {
      let mezzo = pezzi->Array.getUnsafe(1)
      switch %re("/^(\d+)\s*(?:\/\s*)?([A-Za-z])?$/")->RegExp.exec(mezzo) {
      | Some(m) =>
        let parte = i => m->RegExp.Result.matches->Array.at(i)->Option.flatMap(v => v)->Option.getOr("")->trim
        (parte(0), parte(1)->String.toUpperCase)
      | None => ("", "")
      }
    } else {
      (civico, esponente)
    }
    // Un comune fatto di sole cifre è un CAP rimasto solo: non è un comune.
    via == "" || comune == "" || soloCifre(comune)
      ? None
      : Some({odonimo: via, civico, esponente, comune})
  }
}
