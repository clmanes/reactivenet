---
title: "Componenti Spectrum"
description: "I 92 componenti Adobe Spectrum disponibili come direttive, con i loro attributi tipizzati e le icone."
weight: 30
translationKey: "componenti"
---

Ogni componente Adobe Spectrum è disponibile come direttiva sotto il proprio tag
senza `sp-`: lo slider è `::slider`, il badge è `::badge`, l'accordion è
`::accordion`.

```markdown
::badge[Bozza]{variant="neutral"}
::progress-bar{label="Volume" progress="#volume"}
::divider{size="m"}
```

E, dove hanno un contenuto, come blocco con un corpo:

```markdown
::accordion{density="compact"}
::accordion-item{label="Come funziona l'annidamento?" open}
Ogni chiusura dice cosa termina.
::/accordion-item
::/accordion
```

La composizione segue quella di Spectrum: un accordion contiene voci di
accordion, un gruppo di tab contiene tab, un menu contiene voci di menu. Non ci
sono casi speciali per componente.

## Un registro, quattro consumatori

Uno script legge i Custom Elements Manifest che accompagnano la libreria e ne
ricava **92 componenti e 482 attributi**, ognuno tipizzato: bandiera, numero,
scelta o testo. Un'unione di stringhe letterali nel manifest (`'text' | 'value'
| 'none'`) diventa una *scelta* con i suoi valori ammessi — ed è questo che
permette di segnalare un valore sbagliato invece di lasciarlo ignorare in
silenzio dall'elemento.

Da quella lista sola vengono: la costruzione dell'elemento e la validazione
degli attributi, la lista di ciò che il sanitizzatore lascia passare, i blocchi
dell'editor a blocchi e i completamenti. Aggiungere un componente è un
aggiornamento di libreria, non una modifica al codice.

Le direttive di ReactiveNET stanno **nello stesso registro**, descritte nella
stessa forma, e vengono prima: un nome che si scontrasse con un componente
Spectrum si risolve nella direttiva che il renderer gestisce davvero.

## Gli attributi li documenta il componente

Il registro ne porta 482 su 92 componenti, generati dai manifest, e l'editor è
il posto dove leggerli: digitando `::` vengono offerte tutte le direttive,
digitando `{` gli attributi di quel componente coi loro tipi e default,
digitando `="` i valori che un attributo a scelta ammette. Quello che viene
offerto è quello che funziona, perché la lista è la stessa contro cui il
renderer valida.

Una pagina che li elencasse sarebbe vecchia il giorno dell'aggiornamento della
libreria.

## Le icone

`icon: calendar` nel frontmatter e `::page{icon}` attingono allo stesso
insieme di icone Spectrum. Come vengono spedite è la parte interessante: gli
elementi non sono un'opzione — 1096 custom element sono 4,3 MB. Vengono estratti
i *disegni* in un unico blocco caricato pigramente e i *nomi* in un elenco che
il registro offre come scelta, così un nome fuori dall'insieme viene rifiutato
invece che disegnare niente.
