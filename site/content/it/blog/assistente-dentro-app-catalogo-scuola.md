---
title: "L'assistente entra nelle app, e il catalogo scuola arriva a cinque"
description: "Quindici direttive ai-*: riassunti reattivi, chat sui propri dati, ricerca semantica sugli allegati, regole scritte a parole e compilate una volta sola, un agente con due strumenti e un bottone di conferma. E tre nuove app per la scuola — graduatorie interne, PEI e PDP, segreteria — che le usano dove servono e le lasciano stare dove non servono."
date: 2026-08-13
author: "Cosimo Luigi Manes"
translationKey: "assistente-dentro-app-catalogo-scuola"
---

Fino a ieri l'assistente di ReactiveNET stava **accanto** all'app: gli chiedevi
un'app, lui la scriveva, tu la usavi. Da oggi sta anche **dentro**. Quindici nuove
direttive `ai-*` mettono lo stesso modello — quello configurato una volta nelle
impostazioni della chat — al servizio di chi l'app la usa, non solo di chi la scrive.

E insieme arrivano tre app nuove nel catalogo scuola, che sono il modo migliore che
conosco per spiegare a che cosa servono davvero.

## La regola che le tiene tutte insieme

C'è una sola frase da ricordare, ed è quella che rende queste direttive mettibili in
un documento scritto da qualcun altro:

> **Il modello non produce mai niente che venga eseguito.**

Produce una parola presa da un elenco che il documento ha scritto. Oppure un oggetto le
cui chiavi il documento ha dichiarato. Oppure un *piano di interrogazione*, i cui nomi
di campo vengono controllati uno per uno contro quelli che la collezione ha davvero — e
il piano poi gira qui, sulle righe che questo dispositivo già possiede.

Tutto il resto viene rifiutato prima di diventare una riga. Non c'è nessun punto in cui
il testo di un modello diventi codice, SQL o markup: è la stessa scelta per cui i
blocchi `::python` ricevono i dati in un canale a parte invece di vederseli incollare
dentro, e per cui `::sql` usa parametri preparati.

## Che cosa si può fare

**Chiedere.** `::ai-query` prende una domanda in italiano — «quanto ho speso in
trasporti a giugno?» — e la trasforma in filtri, un raggruppamento e una aggregazione.
Il widget mostra la risposta **e il piano**, perché una risposta di cui non si vede la
domanda non si può controllare. Il risultato scomposto finisce in una collezione, e da
lì lo disegna una tabella o un grafico come qualunque altra.

**Riassumere.** `::ai-summary` riscrive il suo riassunto ogni volta che le righe
cambiano. Viaggia un campione, mai la collezione intera.

**Parlare con i propri dati.** `::ai-chat` risponde a partire dalle collezioni
dichiarate e dice quando non ci sono dentro. `::ai-agent` è la stessa cosa con due
strumenti: `query`, che legge, e `insert`, che **propone** una riga — la scrive solo
quando la persona preme conferma, e ogni passo lascia una riga nel registro.

**Riempire un modulo.** `::ai-assist` legge «Mario, giovedì alle 15» e riempie la
bozza; `::ai-field` sceglie una categoria fra quelle che hai elencato; `::ai-suggest`
propone la riga successiva guardando quelle che ci sono già. Nessuna di queste scrive
una riga: riempiono la bozza, e il pulsante di salvataggio resta quello di sempre,
premuto da una persona.

**Lavorare una collezione.** `::ai-classify` mette in ordine le righe che una categoria
non ce l'hanno ancora. `::ai-pipeline` elabora le righe nuove — quelle in cui il primo
campo dichiarato è vuoto — venticinque alla volta.

**Scrivere una regola una volta sola.** `::ai-rule` è la mia preferita. Scrivi la
condizione e l'azione a parole; il modello le compila **una volta** in un piano
controllato che resta in IndexedDB; da lì in avanti la regola gira senza modello, a
ogni cambiamento dei dati, deterministica — e idempotente, perché tocca solo le righe
il cui valore cambierebbe davvero. Il modello ti è servito per un secondo, non per
sempre.

**Cercare per significato.** `::ai-search` indicizza i campi che gli dici, compreso il
**contenuto testuale degli allegati** di `::file`, e cerca per senso: «non riesce a
stare attento a lungo» trova l'obiettivo sull'attenzione anche senza condividerci una
parola. L'indice si costruisce su questo dispositivo, si ricostruisce solo quando il
testo cambia davvero, e non lo lascia. Il modello di embedding predefinito è
**Qwen3-Embedding-0.6B** — seicento megabyte, `ollama pull qwen3-embedding:0.6b` — e
non è un'impostazione: la scelta ha due risposte oneste e a decidere è l'endpoint.

I PDF e le scansioni **non** vengono indicizzati. Servirebbero un parser e un OCR, e
una ricerca che indicizzasse zitta zitta il *nome* di un file fingendo di averlo letto
sarebbe peggio che non offrirla.

## Dove finiscono i dati

Dove finiscono dipende dall'endpoint, non dalla direttiva. Con un modello che gira
sulla tua macchina — Ollama — non esce niente: né le righe di campione, né il testo che
stai riformulando, né le domande. Con un fornitore remoto, quello che la direttiva ha
messo nel prompt arriva a quel fornitore, esattamente come per la chat.

È lo stesso `AiSettings.isLocal` che lo decide, ed è la stessa funzione che leggono il
pannello e l'informativa privacy. Se non c'è nessun modello configurato, ogni direttiva
scrive una frase e **l'app continua a funzionare**: un documento scritto per un modello
non deve diventare una pagina di rotelline su un browser che non ne ha.

## Tre app nuove, e perché proprio queste

Il catalogo scuola passa da due a cinque. Le tre nuove sono lavori che in una scuola si
fanno ogni anno, sempre allo stesso modo, sempre con gli stessi errori.

**[Graduatorie Interne](/it/app/scuola/graduatorie-interne/)** forma le graduatorie per
l'individuazione dei soprannumerari. La decisione che regge tutto è che **la tabella di
valutazione sta nei dati**: la riscrive ogni rinnovo del CCNI, e un software che se la
portasse dentro sarebbe da buttare al primo. Il servizio di continuità non si dichiara,
si ricava dalla data di titolarità — è l'errore più frequente, tolto di mezzo per
costruzione. E ogni punto attribuito ha un prospetto che lo giustifica, con il
riferimento normativo: è quello che si stampa quando arriva un reclamo.

**[Inclusione](/it/app/scuola/inclusione/)** è PEI e PDP. Tratta dati sulla salute di
minori, e questo ha deciso tutto il resto: niente esce dal dispositivo, **non c'è
nessun campo in cui scrivere una diagnosi**, i riepiloghi d'istituto contano invece di
elencare, e l'estratto per il consiglio di classe porta misure e criteri di valutazione
e nient'altro. Le sole due direttive AI presenti sono `::ai-rewrite`, che riformula un
testo che un docente ha già scritto, e `::ai-search` sulla banca delle formulazioni.
Nessuna classifica, prevede o valuta un alunno — e non è una dimenticanza.

**[Segreteria](/it/app/scuola/segreteria/)** è il cruscotto del back office: pratiche
con tipi e termini configurabili, kanban per stato, scadenzario, contatori
contrattuali, contratti a termine, acquisti e inventario. Comincia dicendo che cosa
**non** è — non sostituisce SIDI, protocollo, conservazione, contabilità — perché è la
prima cosa da chiarire prima di dare un software a una segreteria. Dove servirebbe uno
di quelli tiene un riferimento e un export, non una finta implementazione.

Tutte e tre finiscono con una pagina **Decisioni**: le scelte prese dove la norma è
ambigua, scritte come scelte e non come letture della norma, e la riga da cambiare per
cambiarle.

## Quello che nessuna delle tre fa

Nessuna ha controllo d'accesso per ruolo dentro il documento. Chi apre l'app la vede
tutta. Dove i ruoli devono essere separati davvero, la risposta sono gli **spazi
condivisi** della piattaforma — lettore o redattore, con la lettura tenuta dalla
crittografia e la scrittura dal server — oppure, più semplicemente, due app.

È il tipo di cosa che preferisco scrivere nella pagina iniziale dell'app piuttosto che
lasciar scoprire a chi ci mette dentro i dati veri.

## Provarle

Ognuna delle tre si apre dal catalogo e arriva nella tua galleria con l'istituto di
esempio già dentro: si preme *Esegui* sui blocchi di semina e c'è qualcosa da guardare
subito, invece di un guscio vuoto da riempire prima di capire se serve.

Le app sono documenti Markdown: si leggono, si cambiano, si portano via.
