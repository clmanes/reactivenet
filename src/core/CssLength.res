// Una lunghezza CSS scritta da un autore in un attributo di direttiva.
//
// Esiste per un guasto che non dice niente. `height="520"` è quello che chiunque
// scrive, e non è una lunghezza CSS: `style.setProperty("height", "520")` viene
// RIFIUTATO dal parser e la proprietà resta com'era, senza eccezione, senza
// avviso, senza niente in console. La mappa continua a disegnarsi all'altezza di
// default e l'autore vede un attributo che non fa nulla — la stessa forma di
// fallimento del ritorno silenzioso di cui questo progetto si guarda altrove.
//
// La regola è quella che l'autore intendeva: un numero nudo sono pixel. Tutto il
// resto passa com'è scritto, perché `18rem`, `50vh` e `calc(100% - 2rem)` sono
// già lunghezze e non tocca a noi giudicarle — il parser CSS lo fa meglio, e
// quello che rifiuta lo rifiuta comunque.
//
// Non è una validazione di sicurezza e non deve sembrarlo: il valore arriva da un
// documento e finisce in `setProperty`, che lo consegna INTERO al parser CSS —
// `18rem` entra, `18rem; background: url(…)` viene rifiutato come un tutt'uno.
// È la stessa ragione per cui `shell/Columns` passa da `setProperty` invece che
// costruire uno stile per concatenazione.

let normalise = value => {
  let trimmed = String.trim(value)
  if trimmed == "" {
    None
  } else if RegExp.test(%re("/^\d+(\.\d+)?$/"), trimmed) {
    Some(trimmed ++ "px")
  } else {
    Some(trimmed)
  }
}
