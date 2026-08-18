# Tre direttive per la pianificazione oraria

Specifica di ciò che manca al linguaggio perché un orario scolastico sia
scrivibile come documento. Sono tre aggiunte, non una famiglia nuova: una
vista, due estensioni. Il resto dell'applicativo — anagrafiche, cattedre,
vincoli, statistiche, export, ruoli — è già esprimibile con ciò che c'è.

## 1. `::timetable` — la griglia bidimensionale

`::board` trascina, ma su una dimensione sola: il rilascio scrive il campo
`group-by`. `::calendar view="matrix"` disegna righe per colonne, ma in sola
lettura. Un orario ha bisogno di entrambe le cose insieme, e questa è
l'unica ragione per cui la direttiva esiste.

```
::timetable{path="lezioni" rows="ora" cols="giorno"
            row-values="1,2,3,4,5,6" col-values="lun,mar,mer,gio,ven"
            filter="classe=3A" pin="fisso" blocked="violazioni"
            colour="disciplina" deletable editform="modLezione"}
{disciplina}
{docente} · {aula}
::/timetable
```

Contenitore: il corpo è il modello della **cella**, con i token `{campo}`
sostituiti nei nodi di testo esattamente come fa `::list` — le celle
mostrano quello che qualcuno ha digitato, quindi la regola del `textContent`
vale qui come altrove.

| Attributo | Significato |
| --- | --- |
| `path` | la collezione delle lezioni (obbligatorio) |
| `rows` | il campo che dice in quale riga sta la lezione |
| `cols` | il campo che dice in quale colonna |
| `row-values` | i valori di riga, nell'ordine; se manca, quelli presenti ordinati |
| `col-values` | i valori di colonna, nell'ordine; se manca, quelli presenti ordinati |
| `row-labels` | intestazioni di riga alternative ai valori, stessa cardinalità |
| `col-labels` | idem per le colonne |
| `filter` | `campo=valore`, come nelle altre viste |
| `pin` | il campo booleano che marca una lezione bloccata: non si trascina |
| `blocked` | la collezione che dice quali celle sono vietate (sotto) |
| `colour` | il campo i cui valori scelgono il colore della cella |
| `deletable` | ogni cella ha il suo bottone di eliminazione |
| `editform` | come in `::list`: apre la riga in un form |

**Il rilascio scrive due campi**, `rows` e `cols`, sulla riga trascinata, e
muove `updatedAt` lasciando `createdAt` — la stessa aritmetica di `::board`.
Una riga il cui campo `pin` vale `true` non è trascinabile: è la lezione che
l'utente ha fissato e che il solver non deve toccare.

**Le celle vietate arrivano da una collezione**, non da una funzione: il
validatore — un blocco `::python` — scrive le violazioni e la griglia le
legge. Ogni riga di `blocked` porta `row`, `col` e, facoltativo, `for` (l'id
della lezione a cui la proibizione si applica) e `why` (la frase da mostrare).
Senza `for` la cella è vietata per chiunque. Durante il trascinamento le celle
si colorano: consentita, con avviso, vietata — e il rilascio su una cella
vietata è **rifiutato**, con la frase di `why` se c'è. Il colore non è mai
l'unico veicolo: la cella vietata porta anche il suo simbolo.

Il resto del modulo M6 del prompt non chiede codice nuovo: le viste per
docente, per aula, per disciplina sono la stessa direttiva con `filter`,
`rows` e `cols` diversi.

## 2. `::python`: parametri, esecuzione governata, avanzamento

Tre aggiunte a una direttiva che per il resto va già bene — gira in un Web
Worker, riceve le collezioni, riscrive righe.

- **`params="pesoBuche,pesoGiornoLibero"`** — le chiavi reattive entrano nel
  codice come `params["pesoBuche"]`. Oggi entra solo `data=`, e i pesi dei
  vincoli sono slider: senza questo, il pannello dei pesi non arriva al
  solver. Un cambio di parametro rientra nella firma, quindi ri-esegue,
  con lo stesso ritardo delle altre direttive reattive.
- **`manual`** — il blocco non parte mai da solo: aspetta il suo bottone.
  Un simulated annealing non deve ripartire perché qualcuno ha corretto un
  cognome. È il `Run` che già esiste per i pacchetti, reso una scelta
  dell'autore.
- **avanzamento e Stop** — nel codice sono disponibili due funzioni:
  `progress(fatto, totale, messaggio)` disegna la barra, e `partial(righe)`
  pubblica la migliore soluzione trovata finora. Il bottone **Stop** termina
  il worker e scrive l'ultima `partial` ricevuta: è quello che rende onesta
  la promessa «interrompi e tieni il risultato migliore». Senza `partial` lo
  Stop non scrive nulla, perché non c'è nulla da scrivere.

Il tetto dei due minuti resta il tetto di una esecuzione **automatica**. Un
blocco `manual` lo alza a dieci: l'ha chiesto una persona, che sta guardando
la barra e può fermarla.

## 3. `::print{repeat}` — una pagina per riga

`::print` stampa una sezione. «Una pagina per classe» e «una pagina per
docente» sono la stessa richiesta ripetuta, e la ripetizione non si scrive a
mano quando le classi sono venti.

```
::print{target="orarioClasse" repeat="classi" key="classeSel" field="id"
        label="Stampa l'orario di ogni classe"}
```

Per ogni riga di `repeat`: imposta la chiave reattiva `key` al valore del
campo `field` (l'id se `field` manca), attende che i binder si siano
riaggiornati, e **fotografa** il contenuto di `target` in un contenitore di
stampa, con l'interruzione di pagina fra una copia e l'altra. Alla fine
stampa quel contenitore. Funziona perché ciò che serve alla stampa è HTML
fermo: nessuna copia deve restare viva, e infatti nessuna lo resta.

La chiave torna al valore di partenza quando la stampa è finita — quello che
si vede a schermo prima e dopo è lo stesso.
