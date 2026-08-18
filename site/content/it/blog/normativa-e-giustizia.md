---
title: "Il Parlamento e la giustizia, in dati aperti: quattro nuove fonti"
seotitle: "Parlamento e giustizia in dati aperti"
description: "Atti e votazioni della Camera, ddl del Senato, pronunce della Consulta dal 1956, sentenze di TAR e Consiglio di Stato: il warehouse sale a 228 dataset."
date: 2026-07-20
author: "Cosimo Luigi Manes"
translationKey: "parliament-and-justice"
cover: "/img/blog/parliament-and-justice.jpg"
coverAlt: "Ovid - New York - Seneca County Courthouse Complex - 'Three Bears,' is a historic courthouse complex"
coverAuthor: "Onasill - Bill Badzo - 149 Million Views - Thank Y"
coverAuthorUrl: "https://www.flickr.com/photos/7156765@N05"
coverSource: "https://www.flickr.com/photos/7156765@N05/51513431053"
coverLicense: "Public Domain Mark"
coverLicenseUrl: "https://creativecommons.org/publicdomain/mark/1.0/"
---

Dopo i dati su comuni e territorio, il warehouse open data di Reactive si
apre alla sfera **normativa e giudiziaria**: come si fa una legge, chi la
vota, e cosa dicono i giudici quando quella legge viene contestata.
**Quattro nuove fonti ufficiali**, tutte senza chiave d’accesso:

- gli **atti e le votazioni nominali elettroniche della Camera dei
  Deputati** (dati.camera.it), ogni legislatura della Repubblica dal 1948;
- i **disegni di legge del Senato**, con lo stato più recente dell’iter e —
  quando approvati — numero e data della legge risultante
  (SenatoDellaRepubblica/OpenData);
- le **pronunce della Corte Costituzionale** dal 1956 a oggi, sentenze e
  ordinanze, testo integrale compreso (dati.cortecostituzionale.it);
- le **sentenze di tutti i Tribunali Amministrativi Regionali, del
  Consiglio di Stato e del CGA Sicilia** (portale OpenGA della Giustizia
  Amministrativa, attivato nel 2024 con fondi PNRR).

Il warehouse sale così a **228 dataset**, e il layer semantico che li
descrive cresce a **24 relazioni** verificate: le votazioni della Camera si
agganciano ai rispettivi atti, le sentenze di TAR e Consiglio di Stato alla
loro regione.

## Due app per vederli all’opera

### 🏛️ Parlamento in numeri

L’attività di Camera e Senato in una sola app. Scegli la legislatura e vedi
l’esito delle votazioni in Aula (quante approvate, quante respinte), sfoglia
le ultime votazioni con il conteggio di favorevoli e contrari, cerca un
progetto di legge per titolo. Lato Senato, i disegni di legge con lo stato
più recente dell’iter — e quelli che sono diventati legge, con link diretto
alla legge risultante.

### ⚖️ Giustizia costituzionale e amministrativa

Le pronunce della Consulta si possono cercare **in linguaggio naturale**:
descrivi la questione — «legittimo impedimento», «autonomia regionale» — e
la ricerca semantica trova le pronunce pertinenti, senza bisogno di
conoscerne gli estremi. La stessa app mostra anche le sentenze di TAR e
Consiglio di Stato, filtrabili per regione e cercabili per oggetto: il
contenzioso pubblico sugli appalti, i concorsi, l’urbanistica.

```md
::od-search{into="ricerca" table="corte_costituzionale" placeholder="Descrivi la questione che cerchi…"}

::cards{path="ricerca" search="false"}
**{tipo} n. {numero}/{anno}** — {presidente}
{epigrafe}
[Scheda ufficiale]({url})
::/cards
```

Vuoi vedere tutto quello che c’è, con le relazioni misurate tra le tabelle?
[Esplora il catalogo dei dataset](/dati/) — o chiedi all’assistente AI
un’app che incroci uno di questi dataset con quelli che già conosci.
