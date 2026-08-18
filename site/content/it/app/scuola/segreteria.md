---
title: "Segreteria"
translationKey: "app-segreteria"
seotitle: "Segreteria scolastica: pratiche e scadenze"
appid: "segreteria"
weight: 50
description: "Il cruscotto operativo della segreteria scolastica: pratiche con vista kanban, scadenzario degli adempimenti, contatori contrattuali, acquisti e stampe."
lead: "Non sostituisce il SIDI né il protocollo: copre quello che oggi vive in fogli condivisi, cartelle di rete e post-it — dove sta una pratica, chi la lavora, che cosa scade quando, quali contatori sono a saldo."
shots:
  - src: segreteria-scadenzario.jpg
    alt: "La pagina Scadenzario: la tabella degli adempimenti ordinati per scadenza, con area, responsabile e stato."
    caption: "Gli adempimenti ricorrenti in ordine di scadenza, con l'area e chi ne risponde. Nessun programma conosce il calendario del tuo istituto: le date si scrivono una volta e restano di anno in anno."
  - src: segreteria-personale.jpg
    alt: "La pagina Personale: la tabella del personale con matricola, cognome, nome, profilo, tipo di contratto, percentuale e data di fine."
    caption: "Il personale con il contratto e la percentuale di part-time: è quello che i contatori leggono, ed è anche l'elenco di chi ha una scadenza addosso."
  - src: segreteria-contatori.jpg
    alt: "La pagina Personale: la tabella dei contatori per unità e voce, con valore, limite e unità di misura."
    caption: "I contatori contrattuali, unità per unità: ferie spettanti, godute e residue, festività soppresse, permessi. Ogni voce ha il suo limite accanto — è la domanda «sono a saldo?» con la risposta a fianco."
tags: ["DSGA", "Assistenti amministrativi", "Dirigenti scolastici", "Back office"]
---

## Il posizionamento, prima di tutto

Questa app **non sostituisce e non replica** il SIDI, il protocollo informatico a
norma, la conservazione digitale, il registro elettronico o la contabilità di bilancio.
Dove servirebbe uno di questi tiene un **riferimento** e un export, non una finta
implementazione: il numero di protocollo è quello vero, assegnato altrove, perché un
numero generato qui sarebbe un numero che non esiste in nessun registro.

Copre il livello di coordinamento che manca fra il gestionale ministeriale e la memoria
dell'assistente amministrativo.

## Che cosa fa

**I tipi di pratica sono dati.** Nome, area, termine in giorni, checklist e firma del
dirigente: un tipo nuovo si crea da un modulo, in meno di cinque minuti, senza toccare
il programma. Ne arrivano dodici già pronti — certificato di servizio, nulla osta,
infortunio, istanza di ferie, decreto di supplenza, ordine di acquisto.

**Le pratiche si trascinano.** Una vista kanban per stato, dove spostare una scheda
scrive lo stato su quella pratica, e una tabella ad alta densità con filtri
combinabili accanto.

**Lo scadenzario** arriva con quindici adempimenti tipici di un anno — organico,
iscrizioni, graduatorie interne, adozioni, PTOF, programma annuale, conto consuntivo,
inventario, prove di evacuazione, accessibilità AgID — come dati modificabili, non come
codice, perché le date cambiano ogni settembre.

**I contatori si calcolano.** Ferie spettanti, godute e residue, festività soppresse,
permessi retribuiti, permessi brevi da recuperare, giorni di malattia e di permesso
legge 104. Le spettanze sono riproporzionate sul part-time, e i parametri contrattuali
stanno in una tabella in cima al blocco: cambiano a ogni rinnovo, e quella è la riga da
correggere.

**Un blocco dice che cosa non va**: pratiche fuori termine, contratti in scadenza nei
trenta giorni, DURC scaduti, adempimenti oltre il preavviso, contatori oltre il limite.
Una schermata, in ordine di gravità.

**Tre direttive AI, nessuna irreversibile.** Una riempie la bozza di una pratica da una
frase, che una persona rivede e salva; una assegna l'area scegliendo fra quattro e
scartando ogni risposta fuori elenco; una regola scritta a parole viene compilata una
volta sola e poi gira senza modello, deterministica e idempotente.

## Dati sanitari: non ce ne sono

Delle assenze si registrano il **tipo secondo la codifica contrattuale** e i giorni.
Del certificato medico si registra l'estremo, non il certificato. Il comporto si conta
in giorni e i permessi della legge 104 sono un numero: quello che vi sta dietro non
entra in questa app.

## Quello che non fa, ed è scritto dentro

Non protocolla, non manda mail, non liquida, non trasmette e non firma digitalmente. Il
termine di una pratica è una data che si scrive, non un calcolo: i termini si
sospendono, i giorni si contano in modi diversi e le festività cambiano per regione — un
calcolo automatico sbagliato è peggio di un campo da compilare. Non ha controllo
d'accesso per ruolo: dove l'area didattica non deve vedere i dati del personale, la
risposta sono due app, o gli spazi condivisi della piattaforma.
