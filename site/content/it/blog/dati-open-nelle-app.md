---
title: "I dati pubblici italiani, dentro le tue app"
description: "Arriva l'integrazione open data: le app Reactive interrogano i dataset ufficiali — comuni, ATECO, professioni, e tutta la legislazione statale dal 1861 — con una riga di testo o descrivendo a parole quello che cercano. E la query la scrive l'AI."
date: 2026-07-15
author: "Cosimo Luigi Manes"
translationKey: "dati-open-nelle-app"
cover: "/img/blog/dati-open-nelle-app.jpg"
coverAlt: "Breviary, Initial 'B' with David playing the harp, and heraldic shield, Walters Manuscript W.83, fol. 7v"
coverAuthor: "Walters Art Museum Illuminated Manuscripts"
coverAuthorUrl: "https://www.flickr.com/photos/39699193@N03"
coverSource: "https://www.flickr.com/photos/39699193@N03/13923505863"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

Da oggi le app Reactive possono attingere ai **dati aperti italiani**: quasi
duecento dataset ufficiali — i comuni con il loro storico, province e regioni,
i codici ATECO, la classificazione delle professioni, i titoli di studio —
più l’intera **legislazione statale dal 1861 a oggi**, interrogabili
direttamente da qualsiasi documento, con una riga di testo.

## Una riga di testo, una tabella viva

Il principio è lo stesso di tutto Reactive: scrivi cosa vuoi, il browser lo
compila in un’app. Ora vale anche per i dati pubblici:

```
::od-query{into="comuni" sql="SELECT LABEL_COMUNE_IT AS nome, SIGLA_AUTOMOBILISTICA AS sigla
  FROM voc_istat_cities
  WHERE CODICE_PROVINCIA = '015' AND DATA_FINE_VALIDITA = '31-12-9999'"}

::table{path="comuni"}
| {nome} | {sigla} |
::/table
```

I risultati arrivano in una normale collezione: le tabelle con ricerca e
ordinamento, le aggregazioni, i grafici e perfino Python ci lavorano come su
qualsiasi altro dato. E la query può contenere **parametri reattivi**: un
campo di input collegato con `{#provincia}` riesegue la ricerca a ogni
modifica, in una manciata di righe hai un’app di consultazione live.

## Trova il dataset descrivendolo a parole

Non serve conoscere i nomi delle tabelle. La direttiva `::od-search` fa una
**ricerca semantica** sul catalogo: scrivi «elenco dei comuni con i codici» o
«classificazione delle attività economiche» e ottieni i dataset pertinenti,
con le colonne e una query d’esempio pronta da copiare.

E siccome l’assistente AI di Reactive conosce le nuove direttive, puoi
saltare anche quel passaggio: chiedigli _«un’app con i comuni della provincia
di Milano»_ e la query la scrive lui.

## Tutte le leggi, dal 1861

Tra i dataset c’è anche la **legislazione**: gli estremi di ogni atto
normativo statale pubblicato in Gazzetta Ufficiale dall’unità d’Italia —
leggi, decreti-legge, decreti legislativi, DPR, regi decreti — ciascuno con
il link al **testo vigente su Normattiva** e alla pubblicazione in Gazzetta.
E la ricerca capisce il significato, non solo le parole:

```
::od-search{table="lex_atti" placeholder="Cerca una norma…"}
```

Scrivi «congedo parentale» o «agevolazioni prima casa» e trovi le norme
giuste anche senza conoscerne gli estremi. I risultati sono una collezione
come le altre: puoi passarli alle **direttive AI** — `::ai-summary` li
riassume in parole semplici, `::ai-chat` ci ragiona sopra — o mostrarli in
una vista con i link pronti. Lo studio professionale che aggancia i
riferimenti normativi alle pratiche, lo sportello comunale che cita le fonti
con il link giusto: quattro righe di testo.

## Il modello di sempre: i tuoi dati non si muovono

L’integrazione open data non cambia la promessa di Reactive, la estende:

- le query sono in **sola lettura** e viaggiano da sole — nessun dato
  dell’utente lascia il dispositivo;
- le collezioni riempite dal servizio sono **escluse dalla sincronizzazione**
  multi-utente: sul relay non passa nulla che venga dai dataset;
- l’ultima risposta buona resta in **cache locale**, quindi l’app è
  consultabile anche offline (con l’avviso che i dati potrebbero non essere
  aggiornati).

I dataset vengono dalle fonti ufficiali della pubblica amministrazione, con
etichette bilingui italiano/inglese già nei dati.

## Da dove cominciare

Sfoglia il [catalogo dei dataset](/dati/) — per ogni dataset trovi colonne e
query d’esempio — oppure apri [l’app](https://app.reactivenet.ai) e chiedi
all’assistente un’app che usi i dati pubblici. La
[guida alla sintassi](/guida/sintassi/) documenta le tre nuove direttive:
`::od-query`, `::od-search` e `::od-datasets`.
