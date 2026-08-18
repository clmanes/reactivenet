---
title: "Guida per sviluppatori"
description: "Il riferimento completo del linguaggio: la sintassi, le direttive dei dati, i grafici, le mappe, gli open data, l'assistente, l'apprendimento automatico, i 92 componenti Spectrum, l'editor a blocchi e il server MCP."
translationKey: "guida-index"
---

Un'app ReactiveNET è un documento Markdown. Non un progetto, non un bundle: un
file di testo che qualunque editor legge, in cui alcune righe — le **direttive**
— diventano campi, liste, tabelle, grafici e calcoli.

Questa guida è il riferimento di chi le scrive a mano. Chi preferisce descrivere
l'app a parole può lasciarla scrivere all'assistente e tornare qui solo per
capire cosa ha prodotto.

## Da dove cominciare

1. **[Sintassi](sintassi/)** — le tre forme di una direttiva, come si annidano,
   e la regola centrale: `#ref` contro un id nudo.
2. **[Direttive dei dati](direttive/)** — form, liste, tabelle, board,
   calendari, aggregazioni e Python: quello che dà a un'app i suoi dati.
3. **[Grafici e viste esplorative](grafici/)** — i sette grafici, il cruscotto
   con filtro incrociato e il pivot che il lettore si costruisce da sé.
4. **[Mappe e coordinate](mappe/)** — la collezione disegnata su una mappa, il
   punto raccolto da chi compila, gli indirizzi risolti in coordinate.
5. **[Dati da fuori](dati-esterni/)** — gli open data, una qualunque API
   pubblica, un motore SQL nel browser, e il `::workflow` che li mette in fila
   con un orario e una riga di stato sola.
6. **[L'assistente dentro l'app](assistente/)** — le quindici direttive `ai-*`,
   e la regola che le rende sicure in un documento scritto da altri.
7. **[Apprendimento automatico](apprendimento/)** — gruppi, anomalie,
   regressione, correlazioni e previsioni, con scikit-learn nel browser.
8. **[Componenti](componenti/)** — i 92 componenti Adobe Spectrum, disponibili
   senza scrivere una riga di codice.
9. **[Editor a blocchi](editor-blocchi/)** — le stesse direttive modificate come
   blocchi, con il menu slash e il trascinamento.
10. **[Il server MCP](mcp/)** — collegare un modello: sette strumenti per
    scrivere un'app, verificarla e consegnarla.

Le direttive di ReactiveNET documentate qui sono **58**, e sono tutte: una prova
confronta questa guida col registro che l'app stessa legge, in entrambe le
lingue, così una direttiva nuova non può restare senza la sua pagina.

## Un'app completa

```markdown
---
appId: spese
title: Spese condivise
icon: receipt
---

::form{path="spese"}
::input{field="cosa" legend="Voce" required}
::input{field="prezzo" legend="Prezzo" type="number" min="0"}
::save{label="Aggiungi"}
::/form

::if-empty{path="spese"}
Ancora niente. Aggiungi la prima voce qui sopra.
::/if-empty

::table{path="spese" search page-size="10" deletable editform}
::column{field="cosa" label="Voce"}
::column{field="prezzo" label="Prezzo" align="end"}
::column{field="createdAt" label="Aggiunta"}
::/table

Totale: :sum{path="spese" field="prezzo" decimals="2"}
```

Il form scrive righe nella collezione `spese`, la tabella le rilegge con
ricerca, ordinamento e paginazione, l'aggregazione somma la colonna. Non c'è
altro da configurare: il documento *è* l'app.
