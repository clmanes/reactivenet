---
appId: clip-spesa
title: Spese di casa
description: "Un modulo, una lista, un totale."
icon: money
lang: it
---

# Spese di casa

::form{path="voci"}
::input{field="cosa" legend="Voce" required}
::input{field="prezzo" type="number" legend="Prezzo" step="0.01" required}
::save{label="Aggiungi"}
::/form

::if-empty{path="voci"}
Non c'è ancora niente in lista.
::/if-empty

::list{path="voci" deletable}
{cosa} — {prezzo} euro
::/list
