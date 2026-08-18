---
appId: ricetta-sondaggio
title: Sondaggio
description: "Raccogliere valutazioni da 1 a 5 con un commento, e leggere i risultati."
lang: it
---

# Come è andata?

::form{path="risposte"}
::input{field="voto" type="number" legend="Voto da 1 a 5" min="1" max="5" required}
::input{field="commento" legend="Commento" placeholder="Facoltativo"}
::save{label="Invia"}
::/form

::if-any{path="risposte"}
## Risultati

Risposte: **:count{path="risposte"}** — voto medio **:avg{path="risposte" field="voto" decimals="1"}**, mediana **:median{path="risposte" field="voto"}**.

::list{path="risposte" sort="createdAt" dir="desc" limit="20"}
**{voto}/5** — {commento}
::/list
::/if-any

::if-empty{path="risposte"}
Nessuna risposta ancora: la prima arriva dal modulo qui sopra.
::/if-empty
