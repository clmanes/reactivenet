---
title: "La salute dove vivi"
translationKey: "app-salute-cittadino"
seotitle: "La salute dove vivi: ospedali, esiti delle cure e servizi del tuo territorio"
appid: "salute-cittadino"
weight: 7
description: "Scegli il tuo comune e nove pagine si riempiono: qual è la tua azienda sanitaria e cosa c'è dentro, chi finisce ricoverato, come vanno a finire le cure, i servizi per la salute mentale e le dipendenze, medici e macchine, la spesa, e le cento province una accanto all'altra. Ventiquattro tabelle dal Ministero della Salute, ISTAT, AGENAS e MEF."
lead: "Chi cerca «i dati sanitari del mio paese» trova numeri appesi a un'entità di cui non conosce nemmeno il nome: il Servizio Sanitario pubblica per azienda, e le aziende sono centodieci contro settemilaottocento comuni. Questa app comincia da lì e arriva fino all'unica domanda che conta davvero — se le persone guariscono."
shots:
  - src: salute-cittadino-territorio.jpg
    alt: "La pagina «La mia sanità»: il nome dell'azienda sanitaria, il bacino che serve, e quattro numeri su farmacie, consultori, ospedali e apparecchiature."
    caption: "Si parte dalla domanda che nessun portale sanitario risolve: qual è la mia azienda. I primi due numeri sono del comune, gli altri due del bacino — perché in farmacia ci si va a piedi e in ospedale no."
  - src: salute-cittadino-ricoveri.jpg
    alt: "La pagina «Chi va in ospedale»: i ricoveri per classe d'età, con una gobba sotto i sei anni e una montagna dopo i cinquantacinque."
    caption: "Chi finisce ricoverato, per età. Le due gobbe hanno cause opposte: la prima è la nascita, la seconda la vecchiaia — e quello che cambia da un territorio all'altro è il rapporto fra le due."
  - src: salute-cittadino-esiti.jpg
    alt: "La pagina «Come vanno le cure»: la tabella degli ospedali con casi, valore grezzo e valore aggiustato per il rischio."
    caption: "L'unica misura di esito che esista. Le due colonne di destra dicono cose diverse, e capita spesso che l'aggiustato sia più alto del grezzo: vuol dire il contrario di quello che sembra."
  - src: salute-cittadino-confronti.jpg
    alt: "La pagina «I confronti»: la tabella delle correlazioni fra gli indicatori delle centocinque aziende sanitarie."
    caption: "Centocinque aziende, sei indicatori, e la correlazione fra ogni coppia — calcolata in Python nel browser."
  - src: salute-cittadino-italia.jpg
    alt: "La pagina «L'Italia a confronto»: due mappe coropletiche affiancate delle cento province, la mortalità standardizzata a sinistra e la speranza di vita a destra."
    caption: "Le due misure che riassumono la salute di una popolazione, una accanto all'altra. Sono quasi l'una il negativo dell'altra — e fra Treviso e Caserta ci sono tre anni e mezzo di vita."
tags: ["Sanità", "Cittadini", "Giornalisti", "Open data", "Ministero della Salute", "AGENAS", "Machine learning"]
---

## Cosa fa

Si sceglie un comune in cima — sono tutti e 7.896 — e nove pagine si riempiono.

**La mia sanità** risolve la domanda da cui tutto dipende: qual è l'azienda
sanitaria che serve questo comune, quanti comuni condivide, e che cosa c'è
vicino — farmacie e consultori nel comune, ospedali e apparecchiature nel bacino.

**Chi va in ospedale** è la domanda che i posti letto non toccano: la capienza
dice quanto si può accogliere, non chi arriva. I ricoveri per età, come si esce
(a casa, verso un'altra struttura, o no), e i traumi.

**Come vanno le cure** è il Programma Nazionale Esiti: mortalità a trenta giorni,
femori operati in tempo, struttura per struttura e aggiustato per quanto erano
gravi i pazienti arrivati.

**Mente e dipendenze** copre i due servizi di cui si parla di più e su cui si
trovano meno numeri. **Con che cosa** conta medici e infermieri e disegna le TAC
e le risonanze su una mappa. **Quanto costa** apre il bilancio di cassa
dell'azienda, voce per voce.

**L'Italia a confronto** è l'unica pagina che non guarda un territorio ma tutti:
le cento province su due mappe, la mortalità standardizzata e la speranza di
vita, con i dati ISTAT. Standardizzata è la parola che conta — una provincia con
molti anziani ha più morti di una giovane senza che nessuno stia peggio, e il
tasso grezzo direbbe esattamente quello.

## Le tre analisi, e perché sono oneste

**I confronti** mette le centocinque aziende sanitarie confrontabili una accanto
all'altra e fa girare tre modelli **nel browser**: le correlazioni fra gli
indicatori, il rilevamento delle anomalie, e un raggruppamento.

La pagina delle anomalie è anche una lezione su come si legge un modello, perché
i due casi che trova sono **tutti e due falsi allarmi, di tipo diverso**. In cima
escono le ASL romane con duecento letti ogni diecimila abitanti: Roma è divisa
fra più aziende ma i suoi grandi ospedali servono la città intera, e al
denominatore c'è solo una fetta di popolazione. Poco sotto arrivano le ATS
lombarde con meno di un medico ogni diecimila: là l'ATS compra le prestazioni e
il personale sta nelle ASST, che sono aziende separate.

In tutti e due i casi il modello ha trovato il **denominatore**, non la sanità. È
per questo che una classifica automatica delle aziende non è in questa app e non
ci sarà.

## Le cinque cose da sapere

L'ultima pagina le elenca, e sono quelle che fanno leggere male un numero giusto:
i **posti letto per abitante** vanno calcolati sul bacino e mai sul comune; il
rapporto fra **decessi e dimissioni non è la mortalità** di un ospedale; le
**celle vuote non sono zeri** ma dati oscurati per non identificare le persone;
il rapporto fra **medici e abitanti non è confrontabile fra regioni** che
organizzano il servizio in modo diverso; e un **servizio molto usato non è un
servizio che va male** — per la salute mentale vale il contrario di quello che
l'istinto suggerisce.

## Da dove vengono i dati

Ministero della Salute (aziende, ospedali, posti letto, personale, apparecchiature,
consultori, salute mentale, dipendenze, dimissioni ospedaliere, farmacie — tutto
con licenza IODL 2.0), AGENAS (esiti delle cure), MEF (spesa delle aziende dai
flussi SIOPE), ISTAT (popolazione, confini, mortalità per causa, speranza di vita
e mortalità infantile per provincia).
