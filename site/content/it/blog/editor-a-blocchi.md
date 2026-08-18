---
title: "Scrivi la tua app come un documento: arriva l'editor a blocchi"
seotitle: "L'editor a blocchi: l'app come un documento"
description: "Il documento si costruisce come su Notion: ogni widget è una scheda da compilare, il menu / suggerisce tutto nella tua lingua, un blocco AI genera il resto."
date: 2026-08-04
author: "Cosimo Luigi Manes"
translationKey: "editor-a-blocchi"
cover: "/img/blog/editor-a-blocchi.jpg"
coverAlt: "From Harpel's Typograph"
coverAuthor: "Double--M"
coverAuthorUrl: "https://www.flickr.com/photos/49879584@N00"
coverSource: "https://www.flickr.com/photos/49879584@N00/4619880040"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Finora per costruire un’app con Reactive si scriveva il documento: testo
normale per il testo, e qualche riga speciale — le direttive — per i pezzi
interattivi. Funziona, ed è il cuore del sistema. Ma la prima volta che ti
trovi davanti a `::form{path="spese" id="f1"}` una domanda è legittima:
_devo davvero impararlo?_

Da oggi no. Aprendo un’app in modifica trovi la nuova vista **Blocchi**: il
documento si costruisce come su un editor moderno di appunti, blocco dopo
blocco. I titoli sono titoli, i paragrafi si scrivono e basta. E i pezzi
interattivi — un modulo, una tabella, un grafico, una mappa — sono **schede**
con un’etichetta chiara: _Elemento_, _Sezione_, _Codice_, _Impostazioni_.

## Compilare, non sintassi

Ogni scheda mostra i suoi campi come un piccolo modulo: la collezione dove
salvare i dati, l’etichetta del pulsante, il numero di colonne. Le opzioni
sì/no sono interruttori, le scelte chiuse sono menu a tendina. Cambi un
valore e l’anteprima accanto si aggiorna da sola: l’app è viva mentre la
costruisci.

Le sezioni contengono davvero i loro pezzi: un modulo mostra dentro di sé i
suoi campi, uno dentro l’altro, e puoi trascinarli per riordinare. Le
impostazioni dell’app — nome, titolo, lingua — sono un modulo anche loro,
in cima al documento.

## Il menu che sa tutto

Digitando **/** compare l’elenco completo di quello che puoi inserire: i
blocchi classici (titoli, elenchi, immagini) e tutti i widget di Reactive,
ognuno con una descrizione breve **nella tua lingua** — italiano, inglese,
spagnolo, francese, tedesco, portoghese o cinese. Scrivi `/tabella`, scegli,
compili i campi. Fine.

## E se non sai da dove iniziare, chiedilo

Il pulsante **✦ AI** (o `/ai`) apre un blocco speciale: descrivi a parole
cosa vuoi — _«un contatore di caffè con bottone +1 e totale di oggi»_ — e
l’assistente genera i blocchi giusti proprio in quel punto del documento,
già compilati e funzionanti nell’anteprima. Usa lo stesso motore AI della
chat: quello sul tuo computer, se preferisci che nulla esca dal dispositivo.
E se il modello scrive i widget in modo impreciso — succede — Reactive li
ripara da solo prima di inserirli.

## Il codice non se n’è andato

La vista **Codice** è sempre lì, a un click: stesso documento, stessa unica
fonte. Quello che tocchi nei blocchi lo ritrovi nel Markdown, byte per
byte dove non hai messo mano — perché l’app _è_ ancora quel file di testo
che puoi salvare, condividere con un link, versionare. È la promessa di
Reactive, e l’editor a blocchi non la cambia: la rende solo più facile da
mantenere.

Aprite [app.reactivenet.ai](https://app.reactivenet.ai), scegliete
un’app e premete ✎ Modifica: la vista Blocchi vi aspetta.
