---
title: "Mobilità del comune"
translationKey: "app-mobilita-comune"
seotitle: "Mobilità del comune: incidenti stradali, parco veicolare e pendolari"
appid: "mobilita-comune"
weight: 20
description: "Come ci si muove in ogni comune italiano e come va a finire: incidenti stradali dal 2001, parco veicolare per classe Euro, chi entra e chi esce per lavoro e con quale mezzo, e — dove esiste — i mezzi in condivisione in tempo reale. Cinque pagine su dati ufficiali ISTAT, ACI e GBFS."
lead: "Quante auto ci sono e dove passano le strade dicono com'è fatto un territorio. Gli incidenti dicono come va a finire — e questa è l'unica misura che esiste per tutti i 7.896 comuni, ventiquattro anni di fila."
shots:
  - src: mobilita-comune-sicurezza.jpg
    alt: "La pagina «Sicurezza stradale»: il menu dei comuni, le cifre dell'ultimo anno e il grafico di ventiquattro anni di incidenti e feriti."
    caption: "Si sceglie il comune una volta e tutte le pagine seguono: Napoli, 2.544 incidenti con feriti nel 2024, 35 morti, e la serie che risale al 2001."
  - src: mobilita-comune-pendolari.jpg
    alt: "La pagina «Chi si muove»: i due totali di chi esce e chi entra, e il grafico dei dieci comuni verso cui si esce di più."
    caption: "Da Napoli escono 40.446 persone al giorno e ne arrivano 196.335: quale dei due numeri è più grande dice se è un posto dove si viene a lavorare o da cui si parte."
  - src: mobilita-comune-diretta.jpg
    alt: "La pagina «In tempo reale»: la mappa di Padova con oltre duemilaseicento mezzi in condivisione disegnati come punti."
    caption: "Non è una serie storica: sono i 2.601 mezzi fermi a Padova nell'istante dello scatto, chiesti al servizio dal browser e aggiornati ogni minuto."
tags: ["Comuni", "Amministratori", "Giornalisti", "Open data", "ISTAT", "Sicurezza stradale", "Tempo reale"]
---

## Cosa fa

Si sceglie un comune in cima e le cinque pagine si riempiono. Sono tutti e 7.896,
non i capoluoghi.

**Sicurezza stradale** è la pagina che giustifica l'app. Di tutto quello che si
può misurare sugli spostamenti — quante auto ci sono, dove passano le strade, chi
va a lavorare dove — questa è l'unica cosa che è un **esito**: quanti incidenti
con lesioni alle persone, quanti morti, quanti feriti, ogni anno dal 2001. Sotto
la serie c'è il confronto che serve per leggerla, perché il numero da solo non
dice niente: il tasso ogni diecimila abitanti del comune accanto a quello della
provincia, della regione e dell'Italia.

**Che cosa circola** conta il parco veicolare per classe Euro e mette in evidenza
la quota immatricolata prima del 2006 — quella che decide chi resta fuori il
giorno che una città chiude il centro alle auto più inquinanti.

**Chi si muove** apre con i due numeri che dicono quasi tutto: quante persone
escono ogni giorno e quante ne arrivano. Sotto, i dieci comuni verso cui si esce
di più e i dieci da cui si arriva, e la ripartizione per mezzo — a piedi, auto,
autobus, treno.

**In tempo reale** è l'unica pagina che non è una serie storica: chiede a un
servizio pubblico dove sono i suoi mezzi in condivisione nel momento in cui la
stai guardando, e si aggiorna da sola ogni minuto.

## Il limite, che è meglio dire prima

Il tempo reale in Italia esiste dove c'è lo sharing, e finisce lì: su 7.896
comuni, ventitré hanno un sistema che risponde. Non è una scelta dell'app — è che
il **Punto di Accesso Nazionale**, l'aggregatore che una norma europea impone per
gli orari del trasporto pubblico, al momento non risponde alle richieste. Il
giorno che tornerà su, gli autobus di mezza Italia potranno stare in quella
pagina senza cambiare niente d'altro.

Per lo stesso motivo l'app non mostra il traffico: nessuno lo pubblica in modo
aperto e uniforme per comune.

## Da dove vengono i dati

| Cosa | Fonte | Annata |
| --- | --- | --- |
| Incidenti, morti, feriti | ISTAT — incidenti stradali per comune | 2001-2024 |
| Parco veicolare per classe Euro | ACI — Autoritratto | l'ultima disponibile |
| Chi entra, chi esce, e con che mezzo | ISTAT — matrice del pendolarismo | 2011 |
| Popolazione residente | ISTAT — bilancio demografico | l'ultima disponibile |
| Mezzi in condivisione | GBFS, pubblicato dai gestori | adesso |

Due avvertenze che l'app ripete dove servono, perché sono il genere di cosa che
fa leggere male un numero giusto.

Il **parco veicolare** è il Pubblico Registro Automobilistico, cioè dove il
veicolo è *registrato*: i grandi noleggiatori iscrivono flotte intere su pochi
indirizzi, e il comune di Trento risulta con più autovetture di Napoli a fronte
di centodiciottomila abitanti. È così nella fonte.

Il **pendolarismo è del 2011**, e non è una scelta: la matrice del Censimento
2021 è stata pubblicata ma il canale con cui si scaricano i dati non la serve.
Quindici anni comprendono la diffusione del lavoro da remoto, quindi quei numeri
vanno letti per la *struttura* dei legami — chi gravita su chi — molto più che
per le quantità.

## Come è fatta

Le posizioni dei mezzi non sono salvate da nessuna parte: arrivano dal servizio
al browser e restano lì. È una scelta e non una mancanza — un mezzo si sposta
ogni minuto mentre un magazzino dati si aggiorna ogni pochi giorni, quindi una
fotografia conservata sarebbe un dato vecchio *che sembra vivo*, e un dato che
sembra vivo inganna peggio di un dato assente perché nessuno lo va a controllare.

Tutto il resto è una interrogazione al magazzino dei dati aperti, con il codice
del comune passato come parametro: cambiare comune non ricarica la pagina, fa
ripartire le interrogazioni.
