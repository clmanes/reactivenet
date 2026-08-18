---
title: "Micro app componibili: costruire cose grandi con pezzi piccoli"
seotitle: "Micro app componibili: costruire cose grandi"
description: "App minuscole con un compito solo che condividono uno spazio dati e si compongono in soluzioni complete, con consenso esplicito e multi-utente su invito."
date: 2026-07-14
author: "Cosimo Luigi Manes"
translationKey: "micro-app-componibili"
cover: "/img/blog/micro-app-componibili.jpg"
coverAlt: "building blocks: social experience"
coverAuthor: "David Armano"
coverAuthorUrl: "https://www.flickr.com/photos/7855449@N02"
coverSource: "https://www.flickr.com/photos/7855449@N02/4058959195"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Le soluzioni del catalogo di Reactive non sono monoliti: sono **composizioni
di micro app**. È il concetto più importante del sistema, e merita una
spiegazione per bene.

## Cos’è una micro app

Una micro app è un’app Reactive con **un compito solo**: registrare una
spesa, tenere l’anagrafica clienti, mostrare un cruscotto. È un semplice
documento Markdown — poche decine di righe — che il browser compila in
un’app reattiva: un form, una vista, un totale. Interfaccia minima, zero
curva di apprendimento, niente menu labirintici.

Il limite apparente — “fa una cosa sola” — è la sua forza: un’app piccola si
capisce al volo, si modifica senza paura e si sostituisce senza toccare il
resto.

## Il collante: lo spazio dati condiviso

Da sole, le micro app sarebbero isole. A tenerle insieme è lo **spazio dati
condiviso**: le app che dichiarano lo stesso spazio (`dataId` nel
frontmatter) leggono e scrivono le stesse collezioni, sul tuo dispositivo.

L’esempio più concreto è lo spazio «casa»: la micro **Spese veloci** — tre
tocchi dal telefono — scrive nella stessa collezione che **Piggybank** usa
per il bilancio e **Hearth** per le spese domestiche. Una spesa inserita una
volta, tre app aggiornate. Nello spazio «studio» vale lo stesso per i
clienti: l’anagrafica alimenta le trattative di **Compass** e le fatture di
**Tally**.

Due regole non negoziabili governano il meccanismo:

1. **Consenso esplicito.** Ogni app chiede il permesso prima di entrare in
   uno spazio condiviso, alla prima apertura. Senza consenso funziona
   comunque, sui suoi dati privati. E puoi revocare quando vuoi.
2. **Il documento non contiene mai segreti.** La chiave che rende uno spazio
   multi-utente vive nel registro locale del browser, mai nel file: puoi
   condividere o pubblicare una micro app senza regalare l’accesso ai dati.

## Comporre, non configurare

Una suite del catalogo si apre con un clic e arriva già composta: cruscotto,
inserimento, viste, anagrafiche. Ma la composizione è tua:

- **togli** i pezzi che non usi (ogni micro app si elimina senza rompere le
  altre);
- **aggiungi** micro app dal catalogo — o fattele **generare dall’assistente
  AI**, che sa creare interi sistemi di micro app coordinate su richiesta;
- **modifica** un pezzo alla volta: ogni micro app resta un semplice file di
  testo, con la sua versione e il suo ciclo di vita.

È la differenza tra un gestionale da configurare e una scatola di mattoncini:
non adatti te stesso all’app, componi l’app attorno a come lavori.

## Multi-utente con un invito

Quando serve collaborare, l’intero spazio diventa condiviso **con un solo
gesto**: dal menu sync generi un invito — un link o un QR da inquadrare — e
chi lo accetta lavora sugli stessi dati, in tempo reale, cifrati da un capo
all’altro. Non serve invitare app per app: lo spazio è uno, l’invito è uno.
La spesa registrata dal telefono di un familiare compare nel bilancio sul
tuo computer, e nessun server in mezzo può leggere nulla.

## Perché è meglio di un’app grande

- **Semplicità dove serve**: chi inserisce le spese vede solo il form delle
  spese, non un gestionale intero.
- **Coerenza dei dati**: un inserimento, zero doppioni, tutte le viste
  aggiornate.
- **Evolvibilità**: si cambia un mattoncino, non si rifà il muro.
- **Portabilità**: ogni pezzo è un file — si esporta, si condivide, si mette
  sotto versione.

Prova una composizione dal [catalogo](/app/) — ogni scheda mostra da quali
micro app è fatta — o parti dalla [guida](/guida/sintassi/) per scriverne
una tua. Bastano poche righe di testo.
