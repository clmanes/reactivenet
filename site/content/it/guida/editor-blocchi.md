---
title: "Editor a blocchi"
description: "Le stesse direttive modificate come blocchi, con il menu slash, il trascinamento e il frontmatter come modulo."
weight: 40
translationKey: "editor-blocchi"
---

Lo stesso documento si scrive in due modi: come sorgente Markdown, o a blocchi
in stile Notion. **I due editor non sono mai montati insieme** — è un invariante
imposto dal codice e verificato da un test.

Nell'editor a blocchi le direttive e il frontmatter sono **blocchi veri**:
si creano, si modificano e si eliminano come qualunque altro, dal menu slash,
dalla maniglia del blocco, o trascinandoli. Ogni componente del registro ha il
suo blocco, `:value` è contenuto in linea, e il frontmatter è un blocco a sé.

## L'annidamento è l'indentazione

Tutto ciò che è indentato sotto un blocco componente ne diventa il contenuto, e
quel blocco viene riscritto come contenitore. Non c'è niente da dichiarare in
anticipo: un blocco inserito dal menu slash nasce foglia, e diventa contenitore
nel momento in cui qualcosa gli finisce sotto.

## Il frontmatter diventa un modulo

In modalità blocchi il frontmatter si modifica come un modulo, dal pulsante ⓘ
della barra, e all'editor arriva il corpo da solo.

Non è una comodità: l'editor a blocchi non ha modo di rappresentare un blocco di
frontmatter, e farlo passare per il suo convertitore Markdown lo trasformerebbe
in un paragrafo o in una riga orizzontale. Il modulo appartiene alla modalità
blocchi soltanto — in modalità Markdown il blocco è lì nel testo, e un secondo
modo di modificarlo sarebbe due verità sullo stesso dato.

L'ordine delle chiavi e le virgolette vengono conservati: `version: "1.0"` resta
una stringa e non diventa il numero uno.

## Il prezzo: la conversione è a mano

Il convertitore Markdown dell'editor a blocchi non conosce questi tipi e sfugge
quello che non riconosce, quindi **entrambe le direzioni sono scritte a mano**,
blocco per blocco, delegando all'editor solo i blocchi ordinari. Markdown →
blocchi divide il sorgente sulle direttive trovate; blocchi → Markdown ridisegna
le nostre e chiama il convertitore per il resto. Il corpo di un contenitore
viene analizzato ricorrendo nel nostro stesso divisore, non consegnandolo
all'editor, che ne farebbe testo letterale.

## Cosa si perde, e perché non è un difetto da correggere

La conversione a blocchi è **lossy in entrambe le direzioni** — l'API della
libreria si chiama letteralmente `blocksToMarkdownLossy`. Far girare un
documento attraverso i blocchi trasforma la matematica `$$` e qualunque altra
cosa senza un blocco equivalente in paragrafi normali, e la cosa si vede subito
nell'anteprima.

È inerente alla libreria, non un bug di ReactiveNET. Chi lavora su un documento
pieno di matematica o di direttive esotiche lo tratta come sorgente Markdown, ed
è per questo che i due editor esistono entrambi.

Un paragrafo che contiene una direttiva in linea viene ricostruito a mano,
perché l'editor scarterebbe il nodo: dentro *quel* paragrafo la formattazione
dei caratteri si perde. È il posto più stretto in cui pagare il prezzo.
