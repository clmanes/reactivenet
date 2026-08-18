---
title: "Sei nuovi dataset: dal voto ai rifiuti, dal turismo alla scuola"
description: "Il warehouse open data di Reactive sale a 223 dataset: raccolta differenziata comunale, risultati delle elezioni politiche, imprese e addetti, punteggi INVALSI, criminalità e turismo provinciali. Tre app nuove o arricchite per esplorarli, tutte incrociate da sole col codice ISTAT."
date: 2026-07-19
author: "Cosimo Luigi Manes"
translationKey: "six-new-datasets"
cover: "/img/blog/six-new-datasets.jpg"
coverAlt: "Opening the Data Vaults"
coverAuthor: "giulia.forsythe"
coverAuthorUrl: "https://www.flickr.com/photos/59217476@N00"
coverSource: "https://www.flickr.com/photos/59217476@N00/8126486040"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

Il servizio dati open di Reactive continua a crescere. Ai fatti già disponibili
— redditi IRPEF, infortuni sul lavoro, farmacie, scuole, indicatori
demografici, appalti pubblici — si aggiungono **sei nuovi dataset ufficiali**,
tutti scaricabili senza chiave d’accesso e agganciati da soli al resto del
warehouse tramite il codice ISTAT del comune o la sigla della provincia:

- la **raccolta differenziata** per comune (ISPRA — Catasto Nazionale
  Rifiuti): rifiuti totali, differenziata e la sua percentuale, quattro anni
  di serie storica;
- i **risultati delle elezioni politiche 2022** per comune (Ministero
  dell’Interno): affluenza e lista più votata;
- **imprese e addetti** per comune (ISTAT ASIA): unità locali attive e
  addetti medi annui, cinque anni di serie storica;
- i **punteggi delle prove INVALSI** per comune (INVALSI): copertura
  volutamente parziale — solo i comuni sopra la soglia minima di studenti
  testati, per il segreto statistico;
- i **delitti denunciati** per provincia (ISTAT): tasso ogni 100.000
  abitanti, già normalizzato, per tipo di reato;
- il **movimento turistico** per provincia (ISTAT): arrivi, presenze e quota
  di turismo straniero.

Il layer semantico che descrive il warehouse cresce con loro: **22 relazioni**
tra tabelle (erano 16), ciascuna verificata a ogni aggiornamento con una
misura reale della percentuale di aggancio — non dichiarazioni, numeri.

## Tre app per vederli all’opera

### 🚨 Sicurezza pubblica

Il quadro della criminalità provincia per provincia: l’andamento dei delitti
negli anni, il confronto tra furti, rapine, omicidi e reati da stupefacenti,
e la mappa d’Italia col tasso di delittuosità. Il tasso è già ogni 100.000
abitanti — confrontabile tra Milano e un piccolo capoluogo senza bisogno di
altri incroci.

### 🏖️ Turismo

Arrivi e presenze della tua provincia, l’andamento dal 2019 a oggi (il crollo
e la ripresa post-pandemia si vedono a colpo d’occhio), la quota di turismo
straniero e la mappa delle presenze per abitante — dove le città d’arte e le
mete balneari svettano di un ordine di grandezza sul resto del Paese.

### 🏘️ Il tuo comune in cifre, ora più ricco

L’app che fa il ritratto di un comune dal solo codice ISTAT si arricchisce di
quattro nuove informazioni: raccolta differenziata, imprese attive, esito
elettorale e punteggio INVALSI. Le nuove carte compaiono solo se il comune ha
il dato — INVALSI ed elezioni non coprono tutti i 7.900 comuni italiani, e
l’app lo gestisce da sola:

```md
::od-query{into="ambiente" sql="SELECT percentuale_rd, anno FROM rifiuti
  WHERE codice_istat = '{#comune}' ORDER BY anno DESC LIMIT 1"}

::cards{path="ambiente" search="false"}
♻️ Raccolta differenziata **{percentuale_rd}%** (anno {anno})
::/cards
```

Se la query non trova righe, la carta semplicemente non appare. Nessuna
condizione da scrivere a mano.

Vuoi vedere tutto quello che c’è, con le relazioni misurate tra le tabelle?
[Esplora il catalogo dei dataset](/dati/) — o chiedi all’assistente AI
un’app che incroci uno di questi dataset con quelli che già conosci.
