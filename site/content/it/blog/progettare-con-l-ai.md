---
title: "Descrivi il pezzo, l'AI lo disegna: il CAD di Reactive diventa un configuratore"
seotitle: "Il CAD di Reactive diventa un configuratore"
description: "La direttiva ::cad guadagna slider automatici dal customizer, misure e peso di stampa, export SVG/DXF per il laser e l'AI che riscrive il codice OpenSCAD."
date: 2026-07-20
author: "Cosimo Luigi Manes"
translationKey: "design-with-ai"
cover: "/img/blog/design-with-ai.jpg"
coverAlt: "painter's house, isfahan, iran october 2007"
coverAuthor: "seier+seier"
coverAuthorUrl: "https://www.flickr.com/photos/94852245@N00"
coverSource: "https://www.flickr.com/photos/94852245@N00/2087845614"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Cinque giorni fa la direttiva `::cad` ha portato [i pezzi 3D parametrici nel browser](/blog/pezzi-3d-nel-browser). Oggi fa il salto di categoria: da
generatore a **configuratore interattivo**, con una novità che cambia il modo
stesso di progettare — **descrivi il pezzo in linguaggio naturale, e l’AI
scrive il codice OpenSCAD per te**.

## Gli slider arrivano da soli

OpenSCAD ha da sempre una sintassi standard per dichiarare i parametri
regolabili, le annotazioni del _customizer_. Ora Reactive le legge e
costruisce i controlli da solo:

```md
::cad{data="scatole"}
```
w = 30;         // [10:100]
spessore = 2.4; // [0.8:0.4:5]
tipo = "esa";   // [esa, tondo, quadro]
coperchio = true;
cube([w, w, 20]);
```
::/cad
```

`w` diventa uno **slider** da 10 a 100, `spessore` uno slider con passo 0.4,
`tipo` un **menu**, `coperchio` un **toggle**. Trascini, e il pezzo si
rigenera — senza perdere l’inquadratura: la camera resta dov’era, il pezzo
cambia sotto i tuoi occhi. Il form collegato alla collezione resta il posto
delle configurazioni salvate: aggiungi una riga e gli slider saltano ai suoi
valori.

## Misure, volume e grammi di filamento

Sotto l’anteprima ora c’è una chip con l’**ingombro** del pezzo, il **volume**
e il **peso stimato in PLA** — utile per capire al volo quanto filamento
costerà la stampa. E il download è più onesto: l’anteprima gira in modalità
veloce (`$preview`, come l’F5 di OpenSCAD), mentre “Scarica STL” fa sempre un
**render finale a qualità piena**.

## Dal 3D al taglio laser: `mode="2d"`

Non tutto si stampa: molto si taglia. Con `mode="2d"` la direttiva accetta
geometrie piane (`square`, `circle`, `polygon`, `projection()`…) e al posto
dell’STL esporta **SVG e DXF**, i formati che le lasercutter e le fresa CNC
si aspettano:

```md
::cad{mode="2d"}
```
lato = 40; // [20:120]
difference() {
  square([lato, lato/2], center=true);
  circle(d=lato/4);
}
```
::/cad
```

Stessa reattività, stessi slider, anteprima SVG con le misure in millimetri.

## Descrivi il pezzo, l’AI lo disegna

La novità più grande è la barra di **progettazione assistita**: con
`ai="true"` sotto il blocco compare un campo di testo. Scrivi _“aggiungi 4
fori passanti da 3mm vicino agli angoli”_ e il motore AI dell’assistente —
quello che già conosci dalla chat: modello nel browser, Ollama in locale o
un’API compatibile — **riscrive il codice OpenSCAD** in streaming, davanti a
te.

Il bello è quello che viaggia insieme alla richiesta, senza che tu debba
pensarci: il codice corrente, i valori attuali dei parametri e — se il render
è fallito — **l’ultimo errore di OpenSCAD**. “Non compila” diventa “chiedi
all’AI di sistemarlo”. E il modello è istruito a esporre le misure come
annotazioni customizer: il codice generato arriva **già con gli slider**.

Il codice dell’AI non tocca il documento: vive accanto ai dati dell’app, e il
pulsante “Codice originale” ripristina quello dell’autore in un click. Nei
nostri test, da _“aggiungi 4 fori agli angoli”_ sono arrivati i quattro fori
— e tre slider nuovi (`hole_r`, `inset`, `extra_len`) per regolarli.

## C’è anche l’import di file

Un campo caricato con `::file` in una collezione dichiarata in `data` finisce
nel filesystem del motore, e la variabile ne porta il nome: nel codice basta
`import(disegno);` per personalizzare un modello caricato dall’utente —
un’incisione su una base STL, una sagoma SVG da estrudere.

Tutto, come sempre, in un documento Markdown: nessun server, nessuna
installazione, e il motore OpenSCAD (~10MB) si scarica dal CDN solo al primo
uso e resta in cache per l’offline. Apri l’[app](https://app.reactivenet.ai),
crea un blocco `::cad` e prova a chiedere un pezzo.
