---
title: "App componibili, spazi dati condivisi e sync senza segreti nel file"
seotitle: "App componibili e spazi dati condivisi"
description: "Le soluzioni del catalogo diventano suite di micro app, gli spazi dati condivisi chiedono il consenso e la chiave di sync esce dal documento."
date: 2026-07-14
author: "Cosimo Luigi Manes"
translationKey: "app-componibili-spazi-condivisi"
cover: "/img/blog/app-componibili-spazi-condivisi.jpg"
coverAlt: "Planning Your Online Course v2"
coverAuthor: "giulia.forsythe"
coverAuthorUrl: "https://www.flickr.com/photos/59217476@N00"
coverSource: "https://www.flickr.com/photos/59217476@N00/8186356402"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

Luglio è stato un mese denso per Reactive. Tre novità collegate tra loro
cambiano il modo in cui le app si costruiscono, si combinano e si condividono —
sempre con la stessa bussola: **i tuoi dati restano tuoi, sul tuo dispositivo**.

## Costruisci cose grandi con app piccole

Ogni soluzione del catalogo è ora una **suite di micro app componibili**:
l’inserimento rapido da telefono, il cruscotto da scrivania, l’anagrafica che
alimenta tutto — ogni pezzo fa una cosa sola e la fa bene. Apri la suite con un
clic dalla scheda del catalogo, tieni solo i pezzi che ti servono.

Le macro app possono anche **integrarsi tra loro**: Compass (CRM) e Tally
(preventivi e fatture) condividono la stessa anagrafica clienti; inserisci un
cliente una volta sola e lo ritrovi in entrambe. E l’assistente AI sa creare
sistemi di micro app su richiesta: descrivi il flusso, lui genera le app che
lavorano in squadra.

## Spazi dati condivisi, con il tuo consenso

Il meccanismo sotto il cofano è lo **spazio dati condiviso**: app che dichiarano
lo stesso spazio leggono e scrivono le stesse collezioni, sul dispositivo.
Nessun automatismo silenzioso: alla prima apertura ogni app chiede il tuo
consenso, revocabile in ogni momento; senza consenso l’app funziona
normalmente sui suoi dati privati. In galleria, un’etichetta colorata raggruppa
a colpo d’occhio le app che condividono uno spazio.

## Il file non contiene più segreti

La terza novità è la più profonda. La sincronizzazione multi-utente — cifrata
da un capo all’altro, senza account — non scrive più la chiave d’accesso nel
documento: la chiave vive in un **registro locale del browser** e viaggia solo
nel link d’invito, in un **QR code** da inquadrare o nel **backup locale** che
puoi copiare o salvare su file.

Cosa cambia in pratica:

- **condividere il file non regala più l’accesso ai dati** — un’app si può
  pubblicare, esportare, passare di mano senza pensieri;
- il link di condivisione porta app e accesso insieme, e chi lo apre decide
  esplicitamente se **partecipare** prima che un solo byte lasci il dispositivo;
- anche gli spazi condivisi diventano multi-utente con lo stesso gesto: un
  invito, e tutta la suite si sincronizza con il tuo gruppo;
- i documenti condivisi in passato continuano a funzionare: la chiave viene
  migrata automaticamente (e rimossa dal file) alla prima apertura.

## Da dove iniziare

Sfoglia il [catalogo delle soluzioni](/app/), leggi la
[guida passo passo](/guida/sintassi/) o apri direttamente
[l’app](https://app.reactivenet.ai) e descrivi all’assistente quello che ti
serve — in una frase.
