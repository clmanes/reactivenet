---
title: "Sintassi delle direttive"
description: "Le tre forme di una direttiva, il blocco che si chiude per nome, gli attributi e la differenza fra #ref e id."
weight: 10
translationKey: "sintassi"
---

Una direttiva si scrive in tre forme, e sono le tre forme standard delle
direttive Markdown.

| Forma | Come si scrive | Cos'è |
| --- | --- | --- |
| Inline | `:nome[testo]{attributi}` | Dentro un paragrafo |
| Blocco | `::nome[testo]{attributi}` | Su una riga propria |
| Contenitore | `::nome{…}` … `::/nome` | Un blocco con un corpo |

## C'è una sola forma di blocco, e la chiusura dice cosa chiude

`::nome{…}` su una riga apre un blocco. Se sotto compare `::/nome`, quel blocco
diventa un **contenitore** e tutto ciò che sta in mezzo è il suo corpo. Un blocco
che nessuno chiude è una **foglia**.

Le due si scrivono identiche di proposito: non si conta niente, e due
contenitori scritti allo stesso modo si annidano lo stesso, perché ogni
chiusura dice quale apertura sta terminando.

```markdown
::accordion{density="compact"}
::accordion-item{label="Primo" open}
Il contenuto della prima voce.
::/accordion-item
::accordion-item{label="Secondo"}
Il contenuto della seconda.
::/accordion-item
::/accordion
```

La profondità si conta per nome, quindi un form dentro un form finisce al
proprio `::/form`.

> **La vecchia regola dei due punti non si legge più.** Prima un contenitore si
> apriva con tre o più `:` e si chiudeva con una riga della stessa identica
> lunghezza, il che obbligava il contenitore esterno a portare *più* due punti di
> quelli che conteneva. Funzionava, ma rendeva l'annidamento — la cosa che tutti
> fanno — l'unica cosa che bisognava contare. Tre due punti su una riga oggi sono
> testo.

## Gli attributi

Fra graffe, separati da spazi. Un attributo senza valore è una bandiera.

```markdown
::input{field="prezzo" type="number" min="0" required}
```

Le virgolette contano più di quanto sembri: lo scanner le legge come una unità,
quindi un'espressione regolare che contiene le proprie graffe sopravvive.

```markdown
::input{field="cap" pattern="^[0-9]{5}$" message="Cinque cifre"}
```

Senza questa regola il `{5}` chiuderebbe la lista degli attributi e la riga
smetterebbe di essere una direttiva: il campo semplicemente non comparirebbe.

> **Un colore esadecimale non può stare in un attributo.** `#` appartiene ai
> riferimenti reattivi, quindi `color="#65c3c8"` viene letto come un legame alla
> chiave `65c3c8`. Scrivi il nome del colore, oppure `rgb(101 195 200)`.

## `#ref` contro un id nudo

È la regola centrale, e confonderla non produce nessun errore visibile.

- Un **id nudo** è la chiave su cui un controllo *scrive*: `::slider[volume]`
  memorizza il proprio valore sotto `volume`.
- Un **`#ref`** è una vista che *legge* quella chiave e la segue:
  `:value[v]{ref="#volume"}`.

Una vista legata a una chiave-magazzino invece che a un riferimento reattivo
semplicemente non si aggiorna mai, e nessuno segnala niente — per questo le due
cose sono tenute separate fin dalla grammatica, e `:value` con un `ref` non
reattivo si disegna come errore invece che come uno spazio inerte.

## Quando le parentesi quadre sono una chiave

Per la maggior parte delle direttive `[testo]` è un'etichetta. Per un
**controllo sorgente** — un componente che porta `value` o `checked` — le quadre
sono la *chiave di memorizzazione*, e il testo visibile va nel corpo:

```markdown
::checkbox[fatto]{}
Fatto
::/checkbox
```

Due conseguenze da sapere prima di chiedersi perché non succede niente:
`::switch` e `::search` non dichiarano né `value` né `checked`, quindi
memorizzano nulla (`::input{type="checkbox"}` e `::table{search}` fanno quei due
lavori); e una casella va letta da `checked`, non da `value`, perché il suo
valore è quello che invierebbe un form — la stringa vuota.

## Una direttiva che non esiste resta scritta

Il registro non conosce ogni nome possibile, e un nome che non conosce viene
reso **come è stato scritto**. Una direttiva non implementata non deve mai far
perdere testo a un documento.

## Il frontmatter

Un documento può aprirsi con un blocco delimitato da `---`:

```markdown
---
appId: spese
title: Spese condivise
description: Chi ha pagato cosa
icon: receipt
lang: it
version: "1.0"
author: Nome Cognome
date: 2026-08-11
---
```

`appId` è tre cose insieme: la chiave di memorizzazione, lo spazio dei nomi
delle collezioni e la parte indirizzabile dell'URL. Cambiarlo *sposta* l'app.

Il parser è un sottoinsieme YAML deliberatamente piccolo: righe `chiave: valore`
in ordine, virgolette accoppiate rimosse, e tutto ciò che segue i **primi** due
punti conservato, così URL e orari sopravvivono. Una chiave che questa app non
ha mai sentito nominare viene comunque mostrata nel pannello informazioni, esattamente
come è stata scritta. Un blocco che non è ben formato — o che nessuno chiude —
resta corpo del documento: inghiottire il resto di un file perché qualcuno ha
digitato `---` sarebbe molto peggio che ignorarlo.
