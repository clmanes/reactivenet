---
appId: ricetta-inventario
title: Inventario
description: "Articoli a magazzino: quantità, prezzi, valore totale e scorte in esaurimento."
lang: it
---

# Inventario

::form{path="articoli"}
::input{field="nome" legend="Articolo" required}
::input{field="categoria" legend="Categoria"}
::input{field="qta" type="number" legend="Quantità" min="0" required}
::input{field="prezzo" type="number" legend="Prezzo unitario (€)" min="0" step="0.01" required}
::save{label="Aggiungi"}
::/form

::if-empty{path="articoli"}
Magazzino vuoto: il primo articolo si aggiunge qui sopra.
::/if-empty

::if-any{path="articoli"}
**:count{path="articoli"}** articoli, valore totale **:sum{path="articoli" field="qta*prezzo" decimals="2"} €**.

::table{path="articoli" search sort="nome" deletable editform filters="categoria"}
::column{field="nome" label="Articolo"}
::column{field="categoria" label="Categoria"}
::column{field="qta" label="Quantità" align="end"}
::column{field="prezzo" label="Prezzo €" align="end"}
::/table

## Scorte più basse

::list{path="articoli" sort="qta" limit="5"}
{nome}: {qta} pezzi ({qta*prezzo} € a magazzino)
::/list

## Quantità per articolo

::chart-bar{data="articoli" x="nome" y="qta"}
::/if-any
