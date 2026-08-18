---
title: "Come si vive qui"
translationKey: "app-come-si-vive"
seotitle: "Il ritratto del tuo comune con dati ufficiali"
appid: "come-si-vive"
weight: 5
description: "Il ritratto del tuo comune su undici fonti ufficiali: popolazione, redditi, incidenti, sanità, suolo e rifiuti, sempre accanto a provincia e Italia."
lead: "Una cifra da sola non dice niente. Questa app mette il tuo comune accanto ai suoi vicini su sette indicatori, tira avanti le serie storiche e cerca chi è fuori dal coro — e fa tutti i conti dentro il tuo browser."
shots:
  - src: come-si-vive-ritratto.jpg
    alt: "La pagina «Il ritratto»: il menu dei comuni e sei numeri in fila — abitanti, reddito, incidenti, farmacie, suolo costruito, zona sismica."
    caption: "Sei numeri da sei fonti diverse: Napoli, 905.050 abitanti, 25.360 € di reddito medio, 28,1 incidenti ogni diecimila, 63,7% di suolo già costruito, zona sismica 2."
  - src: come-si-vive-previsione.jpg
    alt: "La pagina «La strada»: ventiquattro anni di incidenti con la retta di tendenza proiettata in avanti."
    caption: "La serie 2001-2024 e la proiezione, con l'orizzonte scelto da uno slider. Il grafico dimostra da sé l'avvertenza che gli sta sotto: la retta ignora il crollo del 2020 e la risalita recente."
  - src: come-si-vive-salute.jpg
    alt: "La pagina «La salute»: la tabella degli ospedali del bacino con casi, valore grezzo e valore aggiustato per il rischio."
    caption: "Gli esiti delle cure, struttura per struttura. Le due colonne di destra dicono cose diverse: il Fatebenefratelli fa 19,3% grezzo e 6,08% aggiustato sulla frattura del femore."
  - src: come-si-vive-confronti.jpg
    alt: "La pagina «I confronti»: la tabella delle correlazioni fra gli indicatori dei comuni della provincia."
    caption: "Novantadue comuni, sette indicatori, e la correlazione fra ogni coppia — calcolata in Python nel browser, senza che un dato esca."
tags: ["Cittadini", "Comuni", "Giornalisti", "Open data", "ISTAT", "Sanità", "Ambiente", "Machine learning"]
---

## Cosa fa

Si sceglie un comune in cima — sono tutti e 7.896 — e sette pagine si riempiono.

**Il ritratto** mette in fila sei numeri da sei fonti diverse: quanti siamo,
quanto si guadagna, quanto è pericolosa la strada, quanta salute c'è a portata di
mano, quanto del territorio è stato costruito, e in che zona sismica si sta.
Sotto, lo stesso numero accanto a quello della provincia, della regione e
dell'Italia, perché è l'unico modo di sapere se una cifra è alta.

**La strada** è la serie degli incidenti dal 2001 con la proiezione in avanti, e
il parco veicolare per classe Euro. **Chi si muove** dice quante persone escono
ogni giorno e quante arrivano, e con quale mezzo.

**La salute** parte dalla domanda che nessun portale sanitario risolve — qual è
la mia azienda sanitaria — e poi mostra gli ospedali del bacino, quanti medici e
infermieri ci lavorano, **come vanno a finire le cure** struttura per struttura,
i consultori del comune e le macchine che fanno diagnosi su una mappa.

**L'ambiente** è il suolo costruito periodo per periodo e la raccolta
differenziata anno per anno, con i chili per abitante accanto alla percentuale:
differenziare bene una montagna di rifiuti resta peggio che produrne meno.

**I confronti** è la pagina che smette di guardare un comune solo.

## Il machine learning, e perché è onesto

Tre analisi girano **nel browser**, sui dati che ha già scaricato:

- una **proiezione** della serie degli incidenti, con l'orizzonte scelto da chi
  guarda. È una retta tirata avanti e la pagina lo dice: il modello non sa niente
  di rotatorie costruite o limiti abbassati, e su una serie con una svolta la
  ignora per costruzione;
- le **correlazioni** fra i sette indicatori dei comuni della provincia — quali
  cose si muovono insieme. Accanto c'è la frase che rende la pagina utile invece
  che pericolosa: due cose che si muovono insieme non sono una la causa
  dell'altra;
- il **rilevamento delle anomalie**, che segnala i comuni che non somigliano ai
  vicini. Un comune insolito non è un comune messo male: può essere il capoluogo,
  può essere il paese con l'autostrada accanto, può essere un dato sbagliato alla
  fonte. Il modello dice dove guardare, chi guarda decide che cosa ha trovato.

Non c'è nessun modello addestrato altrove, nessuna classifica precalcolata, e
nessun dato che parte: sono conti fatti davanti a chi legge, e per questo se ne
possono cambiare i parametri.

## Da dove vengono i dati

Undici fonti ufficiali: ISTAT (popolazione, incidenti stradali, pendolarismo),
MEF (redditi), ACI (parco veicolare), Ministero della Salute (aziende sanitarie,
ospedali, personale, apparecchiature, consultori, farmacie — tutte con licenza
IODL 2.0), AGENAS (esiti delle cure), ISPRA (suolo consumato e rifiuti),
Dipartimento della Protezione Civile (zone sismiche).

L'ultima pagina dell'app le elenca tutte e spiega le quattro cose che vanno
sapute per non leggerle male — a partire dalla più insidiosa, che i **posti letto
per abitante** non sono calcolati apposta: un ospedale non serve il paese in cui
sta, serve il bacino dell'azienda.
