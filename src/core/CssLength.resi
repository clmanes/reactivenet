/** Normalizza una lunghezza CSS scritta in un attributo di direttiva.

Un numero nudo sono pixel — `"520"` diventa `"520px"` — perché è quello che
l'autore intendeva e perché `setProperty` rifiuta un numero senza unità in
silenzio. Qualunque altro valore passa com'è scritto: giudicarlo tocca al parser
CSS, che lo fa meglio. Una stringa vuota o di soli spazi non è una lunghezza e
risponde `None`. */
let normalise: string => option<string>
