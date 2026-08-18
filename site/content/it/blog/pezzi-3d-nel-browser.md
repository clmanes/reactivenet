---
title: "Il 3D entra nelle app: modelli, realtà aumentata e pezzi da stampare"
description: "Due nuove direttive portano la terza dimensione in Reactive: ::model visualizza modelli 3D con vista in realtà aumentata, ::cad genera pezzi parametrici con OpenSCAD — un form fa da pannello dei parametri e l'STL è pronto per la stampante."
date: 2026-07-15
author: "Cosimo Luigi Manes"
translationKey: "pezzi-3d-nel-browser"
cover: "/img/blog/pezzi-3d-nel-browser.jpg"
coverAlt: "BEETHEFIRST personal 3D printer"
coverAuthor: "Creative Tools"
coverAuthorUrl: "https://www.flickr.com/photos/33907867@N02"
coverSource: "https://www.flickr.com/photos/33907867@N02/13603739274"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Le app Reactive guadagnano la terza dimensione. Da oggi un documento può
**mostrare modelli 3D interattivi** — con la vista in realtà aumentata sui
dispositivi che la supportano — e, soprattutto, **generare pezzi 3D
parametrici** con OpenSCAD, direttamente nel browser, pronti da scaricare in
STL per la stampante 3D. Come sempre: una riga di testo, nessun server,
nessuna installazione.

## Un modello 3D in una riga: `::model`

La direttiva `::model` mostra un modello glTF/GLB dentro l’app: si ruota col
dito o col mouse, si ingrandisce, e sui telefoni compatibili un pulsante lo
porta in **realtà aumentata**, appoggiato sul tavolo di casa:

```
::model{src="https://esempio.it/statua.glb" alt="Statua romana"}
```

Per l’AR su iPhone e iPad basta aggiungere la variante USDZ
(`ios-src="statua.usdz"`). Il visualizzatore si scarica solo nei documenti
che lo usano, e `src` può essere un riferimento reattivo: un menu a tendina
che cambia modello, un catalogo che mostra il pezzo selezionato.

## Pezzi parametrici con OpenSCAD: `::cad`

La novità più grossa. OpenSCAD è il linguaggio dei maker per descrivere i
solidi con il codice; Reactive lo esegue **nel browser** (WebAssembly) e lo
collega al suo sistema reattivo. Il codice sta in un blocco dentro la
direttiva, come per `::python` — e i campi dell’**ultima riga** delle
collezioni dichiarate in `data` diventano variabili del codice:

```
::form{path="box" id="p"}
::input{form="p" field="w" type="number" placeholder="Larghezza"}
::input{form="p" field="h" type="number" placeholder="Altezza"}
::add-form{form="p" path="box" label="Genera"}
::/form

::cad{data="box"}
```
w = 30; h = 20;
cube([w, h, 10], center=true);
```
::/cad
```

Il form diventa il **pannello dei parametri del pezzo**: inserisci larghezza
e altezza, premi Genera, e il modello si rigenera nell’anteprima 3D
interattiva. Il pulsante accanto scarica l’**STL pronto per la stampa**. Gli
assegnamenti nel codice (`w = 30;`) fanno da default finché la collezione è
vuota.

Non manca nulla del linguaggio: ci sono i **font** per `text()` (incisioni,
targhette) e le librerie **MCAD** e **BOSL2** (ingranaggi, filettature, viti)
già montate. Il motore (~10MB) si scarica al primo uso e resta in cache: da
lì in poi funziona anche offline.

## Cosa ci si costruisce

- **Il configuratore da banco** — un artigiano o una piccola officina
  descrive il pezzo una volta (una staffa, un distanziale, una scatola su
  misura) e il cliente compila tre campi: l’STL arriva senza che nessuno
  apra un CAD. Con la sincronizzazione attiva, le richieste dei clienti
  diventano righe di una collezione condivisa.
- **La classe di tecnologia** — in un’ora di laboratorio ogni studente parte
  dallo stesso documento, cambia i parametri, vede il solido prendere forma
  e porta il suo portachiavi alla stampante della scuola. La geometria si
  tocca.
- **Il catalogo con l’anteprima in casa** — un mobiliere o un ceramista
  mostra i pezzi con `::model`: il cliente li ruota, li ingrandisce e li
  appoggia in realtà aumentata sul proprio tavolo prima di ordinare.
- **Il ricambio impossibile da trovare** — la manopola rotta, il gancio
  fuori produzione: si descrive una volta con quattro parametri e si
  ristampa ogni volta che serve, nella misura che serve.

## E l’editor scrive con te

Insieme al 3D arriva l’**autocompletamento** nell’editor: digitando `:` si
scelgono le direttive da un menu con descrizione e snippet già compilati
(Tab salta tra i campi), tra le graffe vengono proposti gli attributi giusti
per ogni direttiva, nel frontmatter le chiavi dell’app — e dentro un blocco
`::cad` il completamento parla OpenSCAD: `cube`, `cylinder`, `difference`,
le trasformazioni e le variabili speciali, con le firme sotto gli occhi.

Tutto questo è già nell’app: [aprila](https://app.reactivenet.ai) e prova la
sintassi nella [guida](/guida/sintassi/), oppure parti dalla
[guida alle direttive](/guida/direttive/).
