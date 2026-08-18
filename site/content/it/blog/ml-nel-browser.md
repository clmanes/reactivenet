---
title: "Il machine learning entra nelle app: quattro direttive, zero server"
description: "Nuova famiglia di direttive ml-*: clustering, anomalie, regressioni e correlazioni con scikit-learn direttamente nel browser, reattive come tutto il resto — muovi uno slider e il modello si ricalcola. Insieme: il warehouse open data sale a 15 tabelle di fatti, si descrive da solo con un layer semantico e si esplora dal vivo con mappa e grafo delle relazioni."
date: 2026-07-18
author: "Cosimo Luigi Manes"
translationKey: "ml-nel-browser"
cover: "/img/blog/ml-nel-browser.jpg"
coverAlt: "Neural Network"
coverAuthor: "Kevin Rheese"
coverAuthorUrl: "https://www.flickr.com/photos/129440207@N08"
coverSource: "https://www.flickr.com/photos/129440207@N08/27929852485"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Un’app Reactive sapeva già raccogliere dati, mostrarli in tabelle, grafici e
mappe, interrogarci sopra un’AI. Da oggi sa anche **farci machine learning** —
senza scrivere codice, senza server, senza che un solo dato lasci il
dispositivo.

## Quattro direttive, un principio

La nuova famiglia `ml-*` porta **scikit-learn nel browser** (via Pyodide, lo
stesso motore dei blocchi Python). Come tutto in Reactive, è una riga di
Markdown:

```markdown
::range[k]{min="2" max="8" value="4" legend="Numero di gruppi"}

::ml-cluster{data="comuni" features="reddito,eta,stranieri" k="#k" into="gruppi"}

::map{path="gruppi" geojson="geojson" fill="cluster"}
**{comune}** — gruppo {cluster}
::/map
```

Muovi lo slider: il clustering si **ricalcola** e la mappa si **ricolora**. I
risultati finiscono in una collezione normale (`into=`), quindi funzionano con
qualunque vista — tabelle, grafici, aggregazioni, perfino un riassunto AI.

- **`::ml-cluster`** — raggruppamento K-means: comuni, clienti, letture di
  sensori… righe simili nello stesso gruppo, con la colonna `cluster` pronta
  per una mappa o un filtro.
- **`::ml-anomaly`** — rilevamento anomalie (Isolation Forest): un punteggio
  0-1 per riga, alto = fuori norma. Per trovare l’outlier in mezzo a mille.
- **`::ml-predict`** — regressione (lineare o random forest): impara dalle
  righe che hanno già il valore e lo **prevede** per le altre, con l’R² in
  vista.
- **`::ml-correlate`** — matrice di correlazione: quali campi si muovono
  insieme.

Il principio che le governa: **il codice eseguito è un template fisso** — i
dati e i parametri non entrano mai nel codice, l’AI non genera nulla a runtime,
lo stesso input dà sempre lo stesso risultato. La prima esecuzione in assoluto
scarica scikit-learn (~60 MB, poi in cache) dietro un click; da lì in poi è
tutto automatico e reattivo. E i calcoli restano **sul tuo dispositivo**.

Per provarle c’è un’app pronta nel catalogo: **Laboratorio comuni** — scegli
una regione, raggruppa i suoi comuni per reddito, età e presenza straniera,
trova quelli fuori norma, scopri quali indicatori corrono insieme.

## Un warehouse che sale a 15 tabelle di fatti

Il servizio dati open è cresciuto parecchio. Ai carburanti, alle gare ANAC,
alla popolazione e all’anagrafe delle PA si sono aggiunti:

- i **redditi IRPEF per comune** (MEF) — reddito medio, imponibile, fasce;
- gli **infortuni sul lavoro** (INAIL) — per provincia, con i casi mortali;
- le **farmacie** (Ministero della Salute) — geolocalizzate, pronte per la
  mappa;
- le **scuole statali** (MIUR) — 50.000, per comune e grado;
- gli **indicatori socio-demografici** ISTAT — età media, indice di
  vecchiaia, presenza straniera;
- gli **aggiudicatari** delle gare (ANAC) — chi vince gli appalti: si chiude
  il cerchio amministrazione → gara → vincitore;
- i **confini amministrativi** ISTAT — il poligono di ogni comune, provincia
  e regione come GeoJSON: qualunque numero per comune diventa una **mappa
  coropletica** (la direttiva `::map` ha imparato `geojson=` e `fill=`).

## Un warehouse che si descrive da solo

Sotto c’è una novità meno visibile ma più profonda: un **layer semantico**.
Tre tabelle di metadati — le chiavi concettuali (con gli URI delle ontologie
OntoPiA), le **relazioni formali** tra le tabelle e le colonne annotate —
interrogabili come tutto il resto. La particolarità: ogni relazione dichiarata
viene **verificata sul dato reale a ogni aggiornamento**, e la percentuale di
copertura del join finisce nella tabella stessa. «Come si uniscono X e Y?» è
una SELECT.

Tutto questo si tocca con mano nella pagina [Dati open](/dati/), rifatta come
**esploratore dal vivo**: la mappa coropletica dell’Italia (popolazione,
densità, reddito medio — clicca una regione per scendere ai comuni), il
**grafo navigabile delle relazioni** tra le tabelle, il catalogo con anteprima
e, per chi vuole sporcarsi le mani, un playground SQL in sola lettura.

Come sempre: le app sono Markdown, i dati restano tuoi, e tutto quello che hai
letto qui funziona anche offline dopo il primo caricamento.
