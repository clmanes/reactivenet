/** Le parti di un indirizzo italiano, come le indicizza l'ANNCSU. */
type t = {
  odonimo: string,
  civico: string,
  esponente: string,
  comune: string,
}

/** Spezza un indirizzo scritto a mano. Nothing quando manca la strada o il comune:
    un indirizzo a metà cercato lo stesso trova qualcosa, ed è il modo peggiore di
    sbagliare. Il civico può essere vuoto — una via senza numero è comunque una
    ricerca sensata. */
let parse: string => option<t>
