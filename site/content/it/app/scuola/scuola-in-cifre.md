---
title: "La scuola in cifre"
translationKey: "app-scuola-in-cifre"
seotitle: "La scuola in cifre: dati MIUR e INVALSI"
appid: "scuola-in-cifre"
weight: 10
description: "Sei cruscotti su dati MIUR, INVALSI e ISTAT: iscrizioni con previsione, dispersione, prove, edilizia scolastica, organico, mappe e una vista pivot."
lead: "Quanti alunni avrai, non solo quanti ne hai. Sei cruscotti su cinque fonti ufficiali, che si incrociano da soli per comune, provincia e regione — e girano interamente nel tuo browser."
tags: ["Dirigenti scolastici", "Docenti", "Open data", "MIUR", "INVALSI", "Previsioni"]
shots:
  - src: scuola-in-cifre-comune.jpg
    alt: "La pagina «Il mio comune»: tre schede con alunni, scuole ed edifici, il grafico delle iscrizioni con la previsione e la tabella delle scuole."
    caption: "Si digita il nome di un comune e la pagina si riempie: alunni di oggi, variazione in dieci anni, edifici censiti e la loro epoca di costruzione."
  - src: scuola-in-cifre-dispersione.jpg
    alt: "La pagina «Dispersione»: serie storica nazionale e classifica regionale dell'abbandono, con la tabella di dettaglio sotto."
    caption: "Il filtro incrociato: si clicca una barra della classifica regionale e la tabella sotto si restringe a quella regione. Un secondo clic la libera."
  - src: scuola-in-cifre-invalsi.jpg
    alt: "La pagina «INVALSI»: grafici dei punteggi per anno e per grado, con i menu di grado e materia."
    caption: "Grado e materia non sono cablati nel documento: due menu li scelgono e le tre interrogazioni li ricevono come parametri preparati."
  - src: scuola-in-cifre-mappa.jpg
    alt: "La pagina «La mappa»: l'Italia divisa per regioni e colorata secondo il punteggio INVALSI di matematica."
    caption: "Le stesse righe, disegnate: la coropletica dei confini ISTAT colorata per quantili, con il valore nel fumetto."
  - src: scuola-in-cifre-esplora.jpg
    alt: "La pagina «Esplora»: la vista pivot con le iscrizioni per regione, grado e anno."
    caption: "L'ultima pagina non decide niente per il lettore: 540 combinazioni in una tabella pivot che si raggruppa e si grafica trascinando."
---

## Cosa fa

Cinque fonti ufficiali, sei pagine, e una domanda diversa per ciascuna.

**Il mio comune** parte da una ricerca per nome e mette in fila quello che
serve per programmare: gli alunni di oggi e la loro variazione in dieci anni,
le scuole statali e gli edifici censiti, l'anno medio di costruzione e quanti
edifici stanno in zona sismica 1 o 2. Sotto, il dato che conta davvero per
l'organico: la serie delle iscrizioni **prolungata in avanti**, con
l'orizzonte scelto da uno slider e il modello scelto da un menu — trend
lineare, ARIMA/SARIMA oppure Holt-Winters.

**Dispersione** mostra la serie storica nazionale dall'anno 2013/2014 per
medie, passaggio tra i cicli e superiori, poi la classifica regionale
dell'abbandono alle superiori. La classifica è cliccabile: è un vero filtro
incrociato, quello degli strumenti di business intelligence — si sceglie una
regione sul grafico e la tabella di dettaglio si restringe, un secondo clic e
il filtro se ne va.

**INVALSI** confronta italiano e matematica lungo il percorso, dalla quinta
primaria alla quinta superiore, con grado e materia scelti dal lettore e non
decisi dall'autore. **Organico** fa per i docenti quello che la prima pagina
fa per gli alunni: titolari per provincia, rapporto alunni-docente, quota di
posti di sostegno, personale ATA, la distribuzione per fascia d'età — dove si
vede l'onda dei pensionamenti — e la stessa proiezione applicata ai titolari.

**La mappa** colora l'Italia due volte, per punteggio e per abbandono, sui
confini ISTAT. **Esplora** non decide niente: mette 540 combinazioni di
regione, grado e anno in una tabella pivot che si raggruppa, si filtra e si
grafica trascinando le colonne, anche da chi l'app la usa e non la scrive.

## Da dove vengono i dati

Sono aperti e ufficiali, e l'app li interroga dal vivo:

| Fonte | Cosa fornisce | Licenza |
| --- | --- | --- |
| MIUR — Portale Unico dei Dati della Scuola | iscrizioni, edilizia scolastica, personale, anagrafe delle scuole | Open Data IODL 2.0 |
| MIM — Ufficio di Statistica | dispersione scolastica per regione e grado | riuso libero con citazione |
| INVALSI — Servizio Statistico | risultati regionali delle prove | CC BY 4.0 IT |
| ISTAT | confini di comuni e regioni | CC BY 4.0 |

Si agganciano da soli attraverso il comune, la provincia e la regione: è
quello che rende possibile dividere i docenti di una provincia per gli alunni
della stessa provincia senza incollare due tabelle a mano.

## Quello che l'app non dice, e perché

Ogni pagina si chiude con le sue avvertenze, che fanno parte del documento
tanto quanto i grafici. Le iscrizioni riguardano la sola scuola statale e
l'infanzia è esclusa dalla fonte. La previsione è un trend, non un oracolo:
l'R² nello stato dice quanto quel trend spieghi davvero la serie. Il dato
INVALSI è campionario, in scala WLE con media nazionale intorno a 200 — utile
per confrontare territori e anni, non per giudicare un singolo istituto, e
l'anno 2019/2020 non esiste perché le prove non si sono svolte. Valle d'Aosta
e Trentino-Alto Adige mancano dalla dispersione per tutta la serie; il
Trentino compare fra i dati INVALSI come due province autonome e non come
regione, e per questo resta bianco sulla mappa. Il rapporto alunni-docente
incrocia due fonti costruite diversamente ed è un indicatore di tendenza, non
un dato di organico.

## Come si cambia

È un documento Markdown: si apre nell'editor e si legge tutto, interrogazioni
comprese. Cambiare la soglia di un grafico, aggiungere una colonna a una
tabella o sostituire una `SELECT` sono modifiche di una riga. L'assistente
può farle al posto tuo, se preferisci descriverle a parole.

I dati che l'app scarica restano nel tuo browser e valgono anche da offline:
quando il servizio non risponde, le pagine mostrano l'ultima copia ricevuta
dicendo che è vecchia, invece di un errore sopra numeri che sembrano freschi.
