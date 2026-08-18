---
title: "Tre app che mettono al lavoro i dati pubblici"
description: "Ai vocabolari si aggiungono i fatti vivi: prezzi dei carburanti, 2,6 milioni di gare ANAC, popolazione e IndicePA. Tre app pronte li mettono al lavoro."
date: 2026-07-18
author: "Cosimo Luigi Manes"
translationKey: "tre-app-open-data"
cover: "/img/blog/tre-app-open-data.jpg"
coverAlt: "Public Domain: Dead American Soldiers, WWII (NARA)"
coverAuthor: "pingnews.com"
coverAuthorUrl: "https://www.flickr.com/photos/39735679@N00"
coverSource: "https://www.flickr.com/photos/39735679@N00/441531286"
coverLicense: "Public Domain Mark"
coverLicenseUrl: "https://creativecommons.org/publicdomain/mark/1.0/"
---

Qualche settimana fa le app Reactive hanno imparato a leggere i **dati aperti
italiani**: i vocabolari ufficiali — comuni, province, ATECO, professioni — e
tutta la legislazione statale dal 1861. Erano soprattutto _dimensioni_: tabelle
di riferimento, stabili, con cui dare un nome ai codici.

Da oggi arrivano i **fatti vivi**, quelli che cambiano:

- i **prezzi dei carburanti** di tutti gli impianti italiani, che il MIMIT
  ripubblica **ogni mattina** — con marca, comune e coordinate;
- oltre **2,6 milioni di gare pubbliche** (i CIG di ANAC), con oggetto,
  importo, amministrazione appaltante e comune di esecuzione;
- la **popolazione residente** per comune (bilancio demografico ISTAT), il
  denominatore che rende sensati i confronti pro capite;
- l’**anagrafe delle Pubbliche Amministrazioni** (IndicePA): tipo di ente,
  comune, PEC, sito e codice fiscale di ogni PA.

E la cosa più bella è che queste tabelle **si parlano tra loro**: una gara
conosce il codice fiscale dell’ente, l’ente conosce il suo comune, il comune
conosce la sua popolazione. Tre fonti diverse — ANAC, IndicePA, ISTAT — che si
agganciano da sole.

## Tre app per vederle all’opera

Le abbiamo messe in evidenza in home, pronte da aprire e usare — non da
costruire.

### ⛽ Carburante

Scegli il tipo di carburante e la tua provincia: vedi i dieci distributori dove
costa meno, in tabella **e su una mappa**. I prezzi sono quelli ufficiali,
aggiornati stamattina. La query che alimenta tutto è una riga:

```md
::od-query{into="distributori" sql="SELECT i.bandiera AS marca, i.comune AS comune, p.prezzo AS prezzo, i.latitudine AS latitudine, i.longitudine AS longitudine
  FROM carb_prezzi p JOIN carb_impianti i USING (id_impianto)
  WHERE p.carburante = '{#carburante}' AND i.provincia = upper(trim('{#prov}')) AND p.self
  ORDER BY p.prezzo LIMIT 10"}

::map{path="distributori" lat="latitudine" lon="longitudine"}
**{marca}** · {prezzo} €/litro — {comune}
::/map
```

I `{#carburante}` e `{#prov}` sono valori reattivi: cambi il tipo o la provincia
e la lista si riscrive da sola, senza ricaricare nulla.

### 🏛️ Appalti trasparenti

Cerca tra le gare pubbliche **in linguaggio naturale** — «manutenzione delle
scuole», «fornitura di vaccini» — e trovi i lotti pertinenti anche senza
conoscerne i codici. Poi guarda le gare del tuo comune, o chi appalta di più per
tipo di ente. È qui che le tre fonti lavorano insieme: la ricerca semantica
sull’oggetto della gara, il codice fiscale che porta all’anagrafe, il comune che
porta alla popolazione.

### ⚖️ Cerca la norma

«Congedo parentale», «bonus ristrutturazioni»: descrivi l’argomento e trovi la
norma giusta, con il link al **testo vigente su Normattiva**. La ricerca capisce
il senso, non solo le parole — copre la legislazione della Repubblica dal 1946.

## Come sono fatte, davvero

Nessun trucco: sono **documenti Markdown**, come qualsiasi app Reactive. Le
trovi nel catalogo, nella nuova sezione **Dati pubblici**, e puoi aprirle,
leggerne il sorgente, duplicarle e modificarle. Le query in sola lettura
viaggiano da sole verso il servizio dati; l’ultima risposta resta in cache, così
l’app funziona anche offline. E come sempre: nessun dato tuo lascia il
dispositivo.

Vuoi vedere tutto quello che c’è? [Sfoglia il catalogo dei dataset](/dati/) — o
chiedi all’assistente AI «un’app coi distributori più economici della mia
provincia», e la query la scrive lui.
