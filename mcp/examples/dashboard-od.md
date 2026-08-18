---
appId: ricetta-dashboard-od
title: Farmacie in Sicilia
description: "Una dashboard sui dati aperti: grafico e tabella che si filtrano a vicenda, e una mappa."
lang: it
---

# Farmacie in Sicilia

::od-query{into="per_provincia" sql="SELECT provincia, count(*) AS n FROM farmacie WHERE regione = 'SICILIA' GROUP BY provincia ORDER BY n DESC"}

::od-query{into="farmacie_ct" sql="SELECT nome, comune, indirizzo, lat, lon FROM farmacie WHERE sigla = 'CT' LIMIT 200"}

::dashboard{path="per_provincia"}

## Per provincia — :count{path="per_provincia"} province

Un clic su una barra filtra la tabella; un secondo clic toglie il filtro.

::chart-bar{data="per_provincia" x="provincia" y="n"}

::table{path="per_provincia" sort="n" dir="desc"}
::column{field="provincia" label="Provincia"}
::column{field="n" label="Farmacie" align="end"}
::/table

::/dashboard

## Le farmacie della provincia di Catania

::map{path="farmacie_ct" height="22rem"}
**{nome}** — {indirizzo}, {comune}
::/map

I dati vengono dal servizio open data (Ministero della Salute, licenza IODL 2.0) e
restano leggibili anche senza rete: l'ultima copia scaricata è la collection stessa.
