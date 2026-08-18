---
title: "La scuola in cifre: cinque nuove fonti e una dashboard per dirigenti e docenti"
description: "Il warehouse open data di Reactive sale a 237 dataset con una sezione scuola completa: iscrizioni con dieci anni di storia, dispersione scolastica estratta dai PDF ministeriali, edilizia e rischio sismico, personale di ruolo, risultati INVALSI regionali. E una nuova app-dashboard con previsione delle iscrizioni, filtro incrociato e mappe coropletiche."
date: 2026-07-21
author: "Cosimo Luigi Manes"
translationKey: "five-school-datasets"
cover: "/img/blog/five-school-datasets.jpg"
coverAlt: "High school classroom blocks under construction, Bamaga, April 1972"
coverAuthor: "Queensland State Archives"
coverAuthorUrl: "https://www.flickr.com/photos/60455048@N02"
coverSource: "https://www.flickr.com/photos/60455048@N02/37077784015"
coverLicense: "Public Domain Mark"
coverLicenseUrl: "https://creativecommons.org/publicdomain/mark/1.0/"
---

Dopo i fondi di coesione, il parco veicolare e la giustizia civile, il
warehouse open data di Reactive completa il quadro dell’**istruzione**:
cinque fonti ufficiali che insieme raccontano chi studia, dove, con quali
risultati, in che edifici e con che organico. Tutte senza chiave d’accesso:

- gli **alunni iscritti** per comune, grado e anno scolastico (MIUR), dieci
  anni di serie storica dal 2015/16 — il quadro attuale e il trend;
- la **dispersione scolastica** (MIM — Ufficio di Statistica): la serie
  nazionale dal 2013/14 e il dettaglio regionale, ricostruiti dai rapporti
  ufficiali del Ministero;
- l’**edilizia scolastica**: 60.054 edifici con epoca di costruzione,
  classificazione sismica e vincoli — il più vecchio è datato all’anno
  1000, e non è un refuso;
- il **personale di ruolo** (docenti e ATA) per provincia, dieci anni: la
  base per il rapporto alunni/docente e per leggere l’onda dei
  pensionamenti;
- i **risultati INVALSI campionari** per regione e area geografica,
  2012/13-2022/23: la serie storica che al dato comunale già in catalogo
  mancava.

Il warehouse sale così a **237 dataset**, con **33 relazioni** verificate
nel layer semantico.

## Una nuova app: dashboard per chi la scuola la dirige o ci insegna

Non una vetrina di grafici: **La scuola in cifre** è pensata per le domande
operative di un dirigente scolastico o di un docente, e usa quasi tutto il
vocabolario BI di Reactive in un documento solo.

### 🏫 Quanti alunni avrai (non solo quanti ne hai)

Cerchi il comune **per nome** (un campo di ricerca che filtra l’anagrafe
ISTAT, niente codici da ricordare) e la scheda si aggiorna da sola. Poi il
dato che serve per programmare organico e classi: il trend delle iscrizioni
**prolungato in avanti** con una previsione a 1-5 anni — slider per
l’orizzonte, **menu dell’algoritmo** (trend lineare, ARIMA/SARIMA o
Holt-Winters) e R² dichiarato. Lo stesso strumento, nella scheda Organico,
proietta i docenti titolari della provincia.

### 📉 Il filtro incrociato sulla dispersione

Clicchi la barra di una regione e il dettaglio storico si restringe a
quella regione — il pattern dei veri strumenti BI, in un file Markdown.
Stessa cosa per i punteggi INVALSI, con le mappe coropletiche a fianco: la
geografia dell’abbandono e quella dei punteggi, colorate dai dati.

### 🔍 Il pivot e le domande a parole

L’ultima scheda carica le iscrizioni per regione/grado/anno in una vista
**pivot esplorabile** (trascini le colonne, cambi grafico, filtri — anche in
modalità Uso) e, con un motore AI configurato, risponde a domande in
linguaggio naturale sugli stessi dati.

Vuoi vedere tutto quello che c’è, con le relazioni misurate tra le tabelle?
[Esplora il catalogo dei dataset](/dati/) — o apri
[La scuola in cifre](/app/opendata/scuola-in-cifre) e parti dal tuo comune.
