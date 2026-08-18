---
appId: ricetta-workflow
title: Listino e scostamenti
description: "Un ::workflow che ogni sera scarica un listino dagli open data, lo confronta con quello che è stato speso e proietta l'andamento: come si mettono in fila i motori, e cosa può e non può fare un orario in un browser."
lang: it
version: "1.0"
---

# Listino e scostamenti

::page{title="Spese" icon="money"}

::form{path="spese"}
::input{field="voce" legend="Voce" required}
::input{field="codice" legend="Codice ISTAT del prodotto" required help="Lo stesso codice del listino, es. 1103"}
::input{field="importo" type="number" legend="Importo speso" required}
::input{field="mese" type="date" legend="Mese" required}
::save{label="Registra la spesa"}
::/form

::table{path="spese" search deletable editform="true" page-size="10"}
::column{field="voce"}
::column{field="codice"}
::column{field="importo" align="end"}
::column{field="mese"}
::/table

Totale registrato: **:sum{path="spese" field="importo" decimals="2"}**

::/page

::page{title="Aggiornamento" icon="refresh"}

## La catena

I tre passi qui sotto stanno dentro un `::workflow`, e questo cambia quattro
cose: girano **nell'ordine giusto** (il listino prima del confronto, il confronto
prima della proiezione — l'ordine lo decidono i nomi delle collezioni, non
l'ordine in cui sono scritti), riportano su **una riga sola** invece che tre,
**niente a valle di un passo fallito viene eseguito**, e partono da soli alle
18:00 e a ogni spesa registrata.

`at="18:00"` qui significa *la prima volta che l'app è aperta alle 18:00 o dopo,
in un giorno in cui non è già stato eseguito*: non c'è un server e non c'è
esecuzione in secondo piano, e `catchup` dice di recuperare in qualunque momento
della giornata invece che solo nell'ora dopo. La striscia lo dice al lettore.

::workflow[Aggiornamento serale]{at="18:00" catchup on="save:spese" label="Aggiorna ora"}

::od-query{into="listino" sql="SELECT codice, descrizione, prezzo FROM prezzi_medi LIMIT 500"}

::sql{data="spese,listino" into="scostamenti"}
```sql
SELECT
  s.voce            AS voce,
  s.mese            AS mese,
  l.descrizione     AS prodotto,
  CAST(s.importo AS DOUBLE) - CAST(l.prezzo AS DOUBLE) AS delta
FROM spese s
JOIN listino l ON l.codice = s.codice
ORDER BY 4 DESC
```
::/sql

::ml-forecast{data="scostamenti" x="mese" y="delta" into="previsione" horizon="6" model="linear"}

::/workflow

Il `::ml-forecast` è scritto `model="linear"` di proposito: la retta non scarica
niente, mentre `arima` e `holt` fanno scaricare statsmodels e aspettano un
pulsante. Un workflow che parte da solo non deve far scaricare decine di
megabyte a chi apre l'app senza averlo chiesto.

::/page

::page{title="Risultato" icon="graph-bar-vertical"}

::if-empty{path="scostamenti"}
Ancora niente da confrontare: registri una spesa nella prima pagina, oppure prema
*Aggiorna ora* nella seconda.
::/if-empty

::if-any{path="scostamenti"}

Voci confrontate: **:count{path="scostamenti"}** — scostamento medio
**:avg{path="scostamenti" field="delta" decimals="2"}**, massimo
**:max{path="scostamenti" field="delta" decimals="2"}**.

::table{path="scostamenti" search sort="delta" dir="desc" page-size="15"}
::column{field="voce"}
::column{field="prodotto"}
::column{field="mese"}
::column{field="delta" align="end"}
::/table

::chart-line{data="previsione" x="mese" y="delta"}

::/if-any

::/page
