---
title: "Orario Scolastico"
translationKey: "app-orario-scolastico"
seotitle: "Orario scolastico: software per costruire l'orario delle lezioni"
appid: "orario-scolastico"
weight: 20
description: "Costruire e gestire l'orario delle lezioni di un istituto di II grado: anagrafiche, cattedre, scelta automatica dell'aula, blocchi di ore consecutive, compresenze, regole fra materie, griglia trascinabile giorno per ora, controllo dei vincoli in chiaro, monitor che dice se l'orario può esistere prima di generarlo e generazione assistita che gira nel browser. Le anagrafiche e le cattedre si importano da un CSV o da un foglio Excel, e ogni tabella si riesporta nello stesso modo. E le sostituzioni giornaliere: le ore scoperte, i candidati in ordine e il conto di chi ne ha fatte quante. Con un istituto di esempio già dentro."
lead: "Il solver propone, la scuola decide. Sceglie anche l'aula, tiene interi i blocchi di laboratorio, rispetta le compresenze, non lascia ore buche alle classi e non fa cambiare plesso a nessuno da un'ora alla successiva — e si può fermare tenendo il risultato migliore trovato finora."
tags: ["Dirigenti scolastici", "Collaboratori del dirigente", "Segreterie", "Timetabling", "Laboratori"]
shots:
  - src: orario-scolastico-griglia.jpg
    alt: "La pagina Orario: la griglia settimanale della classe 1A con le lezioni colorate per disciplina, la legenda sotto e l'inizio della stessa griglia filtrata su un docente."
    caption: "La stessa direttiva vista in tre modi — per classe, per docente, per aula. Una lezione si sposta trascinandola, e il rilascio scrive insieme il giorno e l'ora."
  - src: orario-scolastico-monitor.jpg
    alt: "La pagina Monitor: l'esito del calcolo di fattibilità — 22 misure, nessuna impossibile o al limite — e la tabella di quanto ogni classe, docente e tipo di aula deve reggere contro quello che ha."
    caption: "La domanda che si fa prima di generare: questo orario può esistere? Sono ventidue misure sulle sole anagrafiche — aspettare la generazione per scoprire che le palestre non bastano vuol dire aver aspettato per niente."
  - src: orario-scolastico-saturazione.jpg
    alt: "La saturazione delle aule: un grafico a barre con la percentuale di occupazione di ogni aula e la tabella con posti, ore occupate e ore libere."
    caption: "Quanto sono piene le aule. Nessuna sopra l'80%: c'è margine per una variazione, ed è la domanda che si fa a settembre quando arriva una classe in più."
  - src: orario-scolastico-qualita.jpg
    alt: "La qualità per docente: un grafico delle ore buche per cognome e la tabella con ore in orario, ore di cattedra, giorni, ore buche, massimo giornaliero, giorno libero e cambi di plesso."
    caption: "La misura che conta davvero per chi insegna: ore buche, giorni impegnati, giorno libero ottenuto o no. E i cambi di plesso, che sulla carta non si vedono."
  - src: orario-scolastico-pesi.jpg
    alt: "La pagina Controlli e generazione: i quattro cursori della configurazione dell'istituto — ore minime e massime al giorno per una classe e per un docente — e sotto l'inizio della sezione dei pesi."
    caption: "Quanto dura una giornata, per una classe e per un docente: qui è un vincolo duro, e l'eccezione di una singola classe sta in anagrafica. Sotto ci sono i cinque pesi e il numero di mosse, che non cambiano niente finché non si rigenera: il blocco è manuale apposta, perché una euristica non deve ripartire perché qualcuno ha corretto un cognome."
---

## Cosa fa

Dieci pagine che seguono il lavoro come lo si fa davvero a settembre — e una,
l'ultima, che si apre tutte le mattine dell'anno.

**Avvio** semina un istituto finto ma coerente — l'IIS «Ada Lovelace»: due indirizzi su
due plessi, 6 classi, 13 docenti, 11 aule fra cui **tre laboratori e due palestre**, 13
discipline, 66 cattedre per 180 ore settimanali — così si può premere Genera al primo
avvio e vedere che cosa produce, invece di dover prima inserire un'anagrafica intera.

**Anagrafiche** e **Cattedre** sono le tabelle che tutti conoscono, con qualcosa in
più: le classi portano il numero di alunni, il plesso e quante ore possono fare in una
giornata; le aule il tipo, la capienza in alunni e **quante classi ci stanno insieme**,
perché una palestra divisa a metà ne tiene due; i docenti i giorni di non disponibilità,
il tetto e il pavimento giornalieri, quanti giorni possono salire in tutto e se fanno o
no la prima ora; le discipline il **peso didattico da 0 a 10**, come spezzare le ore
fra le giornate, il massimo giornaliero e quali materie non stanno nello stesso giorno.
Le cattedre puntano alle righe vere di quelle anagrafiche, quindi rinominare una classe
non rompe niente.

**Dati** è la pagina da cui si comincia quando la scuola è già scritta da qualche
parte, e lo è quasi sempre. Le quattro anagrafiche e le cattedre si importano da un
CSV o da un foglio Excel: la pagina elenca le colonne che ogni foglio deve avere e
dice in quale collezione va versato, perché importare nella collezione sbagliata è
l'unico modo di perdere il lavoro fatto. Le cattedre si scrivono **per nome** — `3B`,
`Matematica`, `Rinaldi` — e la ricostruzione li traduce negli identificativi interni,
dato che gli id li conosce l'app e non il foglio della segreteria. Una riga che non si
risolve resta fuori e viene elencata col motivo, invece di entrare e sparire poi
dall'orario senza spiegazioni. Nell'altro verso, ogni collezione si scarica in CSV o
in Excel, e un blocco costruisce il foglio che di solito serve mandare a qualcuno:
l'orario intero ordinato per classe, giorno e ora, col giorno per esteso e il nome
completo del docente.

**Orario** è la stessa griglia vista in tre modi — per classe, per docente, per aula —
perché sono la stessa direttiva con un filtro diverso. Una lezione si sposta
trascinandola, e il rilascio scrive insieme il giorno e l'ora. Le lezioni **fissate**
non si trascinano: sono quelle che qualcuno ha deciso e che il generatore non deve
toccare. Le caselle chiuse — l'indisponibilità dell'istituto, quella della classe, i
giorni in cui un docente non è in servizio, la prima ora che non fa — si vedono
**prima** di provare a metterci qualcosa, e ognuna dice il perché.

**Controlli e generazione** è il cuore. Il controllo trova i conflitti duri — un
docente in due posti alla stessa ora, una classe con due lezioni, un'aula occupata due
volte, una casella vietata, un giorno libero violato, un monte ore che non torna — e li
scrive in una collezione che la griglia legge: le celle in conflitto si vedono nella
griglia stessa, non in un rapporto a parte.

**Monitor** risponde a due domande, e la prima si fa **prima** di generare. *Questo
orario può esistere?* è una domanda sulle anagrafiche, non sull'orario: si risponde
contando le ore che ogni classe, ogni docente e ogni tipo di aula devono reggere contro
le caselle che hanno. Aspettare la generazione per scoprire che le palestre non bastano
vuol dire aver aspettato per niente. Accanto c'è il conto meno ovvio e che salva più
tempo di tutti: **quanti docenti hanno chiesto lo stesso giorno libero** — è una
preferenza personale, ma la loro somma è un vincolo collettivo, e se nove su tredici
chiedono il sabato non è la preferenza che si perde, è l'orario che non si chiude. La
seconda domanda — *si pubblica?* — conta per tipo le segnalazioni del controllo.

**Laboratori e qualità** misura quello che un orario vale davvero: quanto sono sature
le aule speciali, quante ore buche ha ciascun docente, chi ha ottenuto il giorno libero
che aveva chiesto e chi cambia plesso in giornata.

**Stampe** produce una pagina per classe e una per docente in un colpo solo, più la
singola per aula — **in orizzontale**, perché una griglia di sei giorni per sei ore in
verticale non ci sta. E due stampe che guardano tutto insieme: il **tabellone**, tutte
le classi su un foglio solo con la materia e la sigla del docente in ogni casella, e
l'elenco delle **ore a disposizione**, che è quello che serve il primo giorno di
supplenza.

**Sostituzioni** è l'unica pagina che si apre a orario finito, ed è quella che si
usa di più: le altre servono tre o quattro volte l'anno, questa tutte le mattine.
Si registra chi manca — il giorno, e le ore se non è l'intera giornata — e le ore
rimaste scoperte compaiono da sé, ognuna con i candidati **in ordine**: prima chi
è già in quella classe in compresenza, poi chi è a disposizione e si trova in
istituto fra due sue lezioni, poi chi ci arriverebbe prima o si fermerebbe dopo,
infine le ore eccedenti — e a parità di titolo chiama chi ne ha fatte meno finora.
Quel conto è il punto: è il numero che rende una chiamata difendibile in collegio,
ed è precisamente quello che nessuno tiene, perché tenerlo a mano è noioso. Chi
viene impegnato sparisce dai candidati delle altre classi scoperte in quella stessa
ora, chi è assente non viene proposto come sostituto di nessuno, e alla fine si
stampa il foglio del giorno.

L'app **propone e non decide**: la prima riga della lista è una proposta, e resta
tale finché una persona non registra la sostituzione. Chi sta al telefono sa cose
che nell'orario non sono scritte da nessuna parte.

## Le ore buche delle classi, che sono la cosa nuova più importante

In una scuola italiana un'ora buca a una classe non è un difetto di qualità: sono
trenta ragazzi in corridoio, e un orario che ne contiene non si pubblica. Prima
succedeva e nessuno lo contava. Adesso la generazione finisce con una **compattazione**
che fa scivolare le ore di ogni giornata fino a toccarsi, un blocco per volta, e se uno
non ci sta quella giornata resta com'era — una compattazione che rompe un vincolo duro
per chiudere un buco ha peggiorato l'orario, non lo ha migliorato. Miglioramento e
compattazione si alternano in tre giri, perché sono due mosse che si sbloccano a
vicenda. Quello che resta lo dice il monitor, e sull'istituto di esempio non resta
niente.

## Le regole fra materie

**Regole fra materie.** Il peso didattico da 0 a 10 decide quanto presto una materia sta
nella giornata — una bandierina sa dire soltanto «presto», e fra un'ora di religione e
quattro di matematica serve un ordine. La distribuzione dice come spezzare le ore fra le
giornate (`2+1+1` sono quattro ore in tre giorni, uno doppio) e si **adatta** dove il
monte ore è diverso, invece di essere scartata. E tre vincoli duri sulla giornata della
classe: massimo ore al giorno di una materia, materie che non stanno nello stesso
giorno, materie da tenere in giorni non consecutivi.

## Aule, blocchi e compresenze

**Sceglie l'aula.** La disciplina chiede un *tipo* — aula, laboratorio, palestra — e il
generatore trova quale è libera in quella casella, abbastanza capiente per quella
classe e nel plesso giusto. Aggiungere un secondo laboratorio è, in questa app, il modo
di far respirare un orario che non si chiude.

**Tiene interi i blocchi.** Il laboratorio si fa in due ore consecutive, e un blocco o
ci sta intero o non ci sta: non viene spezzato per salvare una preferenza.

**Mette due docenti nella stessa casella.** Il sostegno segue la classe, l'ITP affianca
il titolare: sono compresenze, e i vincoli del docente affiancante — giorni di non
disponibilità, plesso, tetto giornaliero — valgono durante la collocazione, non dopo.

E un vincolo che sulla carta non si vede: **nessun docente cambia plesso da un'ora alla
successiva.** È il primo a saltare nella realtà, ed è il primo che questa versione fa
rispettare.

## Quanto funziona

Il generatore è stato eseguito sull'istituto di esempio: **180 ore su 180 collocate**
in 150 blocchi, **zero conflitti**, **zero ore buche alle classi**, monte ore che torna
per tutte e 65 le cattedre, 202 lezioni di cui 22 in compresenza, tutte le ore di
laboratorio e di palestra come blocchi di due ore interi, 33 ore buche in tutta la
settimana per 13 docenti. Provato anche spegnendo un vincolo alla volta, per sapere
quale costa che cosa: con quattro «massimo al giorno» invece di due restavano cinque
ore senza casella, e nessuna di quelle quattro regole era stata chiesta da qualcuno —
il che è la ragione per cui l'esempio ne dichiara due. Provato con divieti e
pre-assegnazioni, e simulando trascinamenti sbagliati per verificare che il controllo li
veda tutti. Il risultato del browser è identico a quello di CPython sulla stessa
macchina.

## Quello che l'app non fa, ed è scritto dentro

Non è un applicativo commerciale e non finge di esserlo. Non parla col SIDI, non
nomina i supplenti e non conosce i contratti — quante ore eccedenti si possano
chiedere a qualcuno lo sa la scuola, non l'app — non garantisce l'ottimo e può
lasciare ore non collocate. Le lezioni non si modificano da un modulo: si spostano trascinandole, si
cancellano, e si fissano dalle pre-assegnazioni — che sono anche il modo di lavorare da
telefono, dove il trascinamento non esiste.

C'è poi un vincolo del linguaggio che questa app spiega invece di nascondere: un blocco
di calcolo **riscrive per intero** la collezione su cui scrive, quindi ogni collezione
ha un padrone solo. Le anagrafiche compilate a mano — o importate da un foglio —
stanno in una collezione a parte, e il blocco le unisce a quelle di esempio
conservandone gli identificativi, così le cattedre che vi puntano restano valide. La
pagina Avvio lo dice con una tabella: chi scrive che cosa. È anche la ragione per cui
un'importazione va fatta nella collezione giusta, e la pagina Dati non ne parla per
scrupolo.

## Come si cambia

Sei ore al giorno invece di sei e mezza, il sabato che non esiste, un vincolo che a
una scuola serve e a un'altra no: sono tutte modifiche di una riga, e il codice del
generatore è lì da leggere, in Python, dentro il documento.
