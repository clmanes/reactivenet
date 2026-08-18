---
title: "Direttive dei dati"
description: "Form, liste, tabelle, board, calendari, condizionali, aggregazioni e Python: le direttive che danno a un'app i suoi dati."
weight: 20
translationKey: "direttive"
---

Una **collezione** è una lista di righe che appartiene a un'app. `path` la
nomina. Le righe stanno in questo browser soltanto, sotto lo spazio dei nomi di
questa app, e se ne vanno quando l'app se ne va.

Queste direttive sono di ReactiveNET e non saranno mai componenti Spectrum: non
esiste un elemento HTML che significhi «le righe di questa collezione».

## Pagine e colonne

### `::page` … `::/page`

Divide un'app in pagine con un menu fisso. Un documento con **una** pagina non
riceve nessun menu: un controllo con una sola voce non fa niente.

| Attributo | |
| --- | --- |
| `title` | Il nome mostrato nel menu |
| `icon` | Un'icona Spectrum per nome; un nome fuori dall'insieme viene rifiutato invece che disegnato come niente |

```markdown
::page{title="Oggi" icon="calendar"}
## Oggi
::/page

::page{title="Archivio" icon="folder"}
## Archivio
::/page
```

### `::columns` … `::/columns`

Dispone il contenuto in colonne che si riadattano da sole.

| Attributo | |
| --- | --- |
| `min` | Quanto stretta può diventare una colonna — `18rem` di default |
| `gap` | `s`, `m` o `l` |

Non c'è nessun breakpoint, e la domanda che pone riguarda il **riquadro**, non
la finestra: a `/a/<id>` l'anteprima è tutta la finestra, accanto a un editor ne
è la metà, e una media query metterebbe tre colonne dove ce ne sta una.

## Il form

### `::form` … `::/form`

Raggruppa i campi. Disegna un `<div>`, mai un elemento `<form>`: qui non si
invia niente da nessuna parte.

| Attributo | |
| --- | --- |
| `path` | La collezione su cui scrive il suo pulsante di salvataggio |
| `id` | Serve solo quando due form condividono un path, o quando un campo vive fuori dal form |

Il contenimento porta quello che prima ripeteva un attributo: un campo dentro un
form non nomina il form, e un pulsante di salvataggio non nomina né il form né
il suo path.

### `::input`

Un campo del form.

| Attributo | |
| --- | --- |
| `field` | Il nome sotto cui il valore è memorizzato — **obbligatorio** |
| `legend` | L'etichetta visibile; in mancanza, il nome del campo |
| `type` | `text` `number` `date` `time` `email` `tel` `url` `color` `checkbox` `ref` |
| `placeholder`, `value`, `min`, `max`, `step`, `required` | come su un input HTML |
| `pattern` | Un'espressione regolare che **tutto** il valore deve soddisfare |
| `message` | Cosa dire quando `pattern` rifiuta — senza, il lettore viene contraddetto da un'espressione che non vede |
| `help` | Una riga di guida sotto il campo, prima che qualcuno sbagli |
| `form` | Solo quando il campo *non* sta dentro il suo form |

`type="ref"` rende il campo una scelta fra le righe di un'altra collezione:
`path` dice quale, `label` quale suo campo mostrare. Quello che viene
memorizzato è l'**id della riga**, così il riferimento sopravvive a un
rinominamento.

```markdown
::input{field="chi" legend="Pagato da" type="ref" path="persone" label="nome"}
```

**Il salvataggio controlla la bozza.** `required` rifiuta un vuoto, `type`
rifiuta un valore che non è quella cosa, `min`/`max` rifiutano un valore fuori
intervallo e `pattern` uno fuori forma. Ogni obiezione compare sotto il suo
campo, il campo porta `aria-invalid`, e il fuoco va sulla prima. Un form che
nessuno ha compilato affatto non salva niente e non dice niente: quello è un
clic sbagliato, non un errore.

La guida è `aria-describedby`, non parte dell'etichetta: il testo di
un'etichetta *è* il nome accessibile del controllo, e una guida al suo interno
verrebbe annunciata come parte del nome.

### `::save`

Salva il form in cui si trova come riga nuova — o aggiorna la riga in
modifica, se una lista ne ha messa una lì.

| Attributo | |
| --- | --- |
| `label` | Il testo del pulsante |
| `form`, `path` | Solo quando il pulsante non è dentro il form che salva |

`::add-form` è il nome che aveva prima che un form diventasse la cosa dentro cui
lo si scrive. Funziona ancora.

## Le viste sulle righe

`::list`, `::cards`, `::table`, `::board` e `::calendar` disegnano le stesse
righe e fanno le stesse domande — ricerca, filtro, ordinamento, limite, pagina,
gruppo — e differiscono solo nella forma che disegnano.

### `::list` … `::/list`

Il corpo è un **modello di riga**: `{campo}` è sostituito col valore di quella
riga.

| Attributo | |
| --- | --- |
| `path` | La collezione |
| `sort` / `dir` | Il campo su cui ordinare, e da che parte (`asc`, `desc`) |
| `filter` | Solo le righe che soddisfano `campo=valore` |
| `limit` | Quante righe al massimo |
| `group-by` | Raggruppa per campo |
| `deletable` | Un pulsante di eliminazione per riga, confermato in un dialogo |
| `editform` | Un pulsante di modifica; nudo riempie il form su questo stesso path, con un valore ne nomina un altro per id |

```markdown
::list{path="voci" sort="createdAt" dir="desc" deletable editform}
**{cosa}** — {chi} · {createdAt}
::/list
```

Un token può raggiungere un'altra collezione: `{chi>persone.nome}` legge `chi`
come id di una riga di `persone` e ne mostra il `nome`. Il token nomina la
collezione perché una lista sta quasi sempre lontana dal form che ha creato il
riferimento.

Un valore raggiunge la pagina come **testo, mai come marcatura**: una riga che
contiene `<script>` è una riga che mostra quei caratteri.

### `::cards` … `::/cards`

Le stesse righe disegnate come schede in una griglia che si riadatta da sola.
Prende `min` oltre a tutto quello che prende `::list`.

### `::table` … `::/table`

Una colonna per ogni `::column` nel corpo. L'intestazione ordina; un secondo
clic inverte.

| Attributo | |
| --- | --- |
| `path` | La collezione |
| `search` | Una casella di ricerca sopra la tabella |
| `page-size` | Righe per pagina; senza, nessuna paginazione |
| `sort` / `dir` | Come si apre |
| `filter` | Solo le righe che soddisfano `campo=valore` |
| `filters="a,b"` | Un controllo per colonna, coi valori davvero presenti |
| `deletable`, `editform` | come su `::list` |

`::column` prende `field`, un `label` facoltativo e un `align` — `start`,
`center` o `end`.

```markdown
::table{path="spese" search page-size="10" sort="prezzo" dir="desc" deletable editform}
::column{field="cosa" label="Voce"}
::column{field="prezzo" label="Prezzo" align="end"}
::/table
```

I numeri si ordinano come numeri e tutto il resto come testo: «10» prima di «9»
non è giusto da nessuna parte, e in una colonna di prezzi è sbagliato due volte.
L'ordinamento è stabile, quindi le righe a pari merito restano nell'ordine in
cui sono state create.

`filters` è la versione del lettore di `filter`: nomina le colonne su cui può
restringere, e vengono offerti i valori che quelle colonne davvero contengono,
già ristretti da qualunque altra scelta — così una scelta che non mostrerebbe
niente non viene offerta.

> `::table` prende il nome da `sp-table` di Spectrum, che è un componente di
> impaginazione composto una riga e una cella per volta. Dove i due vocabolari
> si scontrano vince il nostro, e un test verifica che `table` sia l'unico nome
> in cui succede.

### `::board` … `::/board`

Le righe in colonne, una per valore di un campo. **Trascinare una scheda in
un'altra colonna scrive quel valore su quella riga**: è tutta la ragione per cui
una board vale più di una lista raggruppata.

| Attributo | |
| --- | --- |
| `group-by` | Il campo i cui valori sono le colonne |
| `columns` | Le colonne da mostrare, in ordine — tiene sullo schermo anche una vuota |
| `min`, `sort`, `dir`, `filter`, `deletable`, `editform` | come altrove |

Un valore che compare senza essere stato nominato riceve comunque la sua
colonna: una scheda non è mai nascosta perché nessuno l'aveva prevista. Il
trascinamento è quello del browser, quindi funziona col mouse e non al tatto —
per questo la scheda conserva il pulsante di modifica.

### `::timetable` … `::/timetable`

Le righe su una griglia di **due campi insieme**, uno lungo il fianco e uno in
cima, dove trascinare una scheda li scrive tutti e due. `::board` trascina, ma
su una dimensione sola; `::calendar view="matrix"` disegna due dimensioni, ma le
legge soltanto. Un orario ha bisogno delle due cose insieme, ed è l'unica
ragione per cui questa direttiva esiste.

| Attributo | |
| --- | --- |
| `rows` / `cols` | I campi che dicono in quale riga e in quale colonna sta una lezione |
| `row-values` / `col-values` | I valori dei due assi, in ordine, separati da virgola |
| `row-labels` / `col-labels` | Intestazioni da mostrare al posto di quei valori, nello stesso ordine |
| `pin` | Un campo a spunta che marca una riga da non trascinare |
| `colour` | Colora le schede per valore di questo campo |
| `blocked` | La collezione che dice quali celle sono vietate |
| `path`, `filter`, `deletable`, `editform` | come altrove |

```markdown
::timetable{path="lezioni" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" col-values="lun,mar,mer,gio,ven" colour="disciplina" pin="fisso" blocked="violazioni" deletable editform="modLezione"}
**{disciplina}**
{docente} · {aula}
::/timetable
```

Il corpo è il **modello della cella**, sostituito nei nodi di testo come fa
`::list`. Un asse senza i suoi valori dichiarati è quello che i dati contengono,
ordinato, e un valore che i dati contengono senza essere stato nominato riceve
comunque la sua riga. Il rilascio scrive `rows` e `cols` sulla riga trascinata,
sposta `updatedAt` e lascia stare `createdAt`: la stessa aritmetica di
`::board`. Una riga il cui campo `pin` è spuntato porta un vessillo e non si
trascina affatto — è la lezione che qualcuno ha fissato a mano.

Le celle vietate arrivano da una collezione, non da una funzione. `blocked` ne
nomina una qualunque, le cui righe portano `row` e `col` e, se serve, `for`
— l'id dell'unica lezione a cui il divieto si applica — e `why`, la frase da
mostrare; senza `for` la cella è chiusa per chiunque. Chi decide cosa è lecito è
dunque qualcosa che *scrive righe*: un blocco `::python`, una query `::sql`, un
form compilato a mano. La griglia fa rispettare e non calcola mai, ed è questo
che tiene la regola visibile, perché le ragioni sono righe che si possono
elencare e contare come le altre. Durante il trascinamento le celle dicono
quello che sono — consentita, con avviso, vietata — il rilascio su una vietata è
rifiutato con la frase di quella riga, e il colore non è mai l'unico segnale: la
cella chiusa porta anche il suo simbolo.

### `::calendar` … `::/calendar`

Le righe su una griglia mensile, collocate dalle loro date.

| Attributo | |
| --- | --- |
| `from` | Il campo data in cui una riga comincia |
| `to` | Il campo data in cui finisce; senza, la riga è un giorno solo |
| `sunday` | Comincia la settimana di domenica invece che di lunedì |

Una riga con `to` è un **intervallo**: compare su ogni giorno fra i due,
disegnata come una barra sola. Il mese ha sempre sei settimane, così la griglia
non cambia altezza mentre si scorre l'anno, e l'aritmetica è fatta sul
`YYYY-MM-DD` scritto — mai su un istante interpretato, che è mezzanotte UTC e
cade il giorno prima a ovest di Greenwich.

### `::if-any` / `::if-empty`

Mostrano il corpo secondo che la collezione abbia righe o no. Partono entrambe
nascoste e compaiono quando la collezione è stata davvero letta, così nessuna
delle due lampeggia la risposta sbagliata.

```markdown
::if-empty{path="voci"}
Ancora niente qui.
::/if-empty
```

### Ogni riga porta due timbri

`createdAt` e `updatedAt` sono campi ordinari con nomi riservati, quindi
`{createdAt}` funziona in un modello e `field="updatedAt"` in un'aggregazione
senza niente in più. Una modifica sposta `updatedAt` e lascia stare `createdAt`.

Sono **memorizzati** ISO 8601 e **mostrati** nel formato del lettore. Un campo
tuo con uno di quei nomi viene scartato invece che lasciato a litigare col
timbro.

## Valori e aritmetica

### `:value` e `:calc`

```markdown
Il volume è :value[v]{ref="#volume"}.

Totale: :calc{expr="#prezzo * #quantità * 1.22" decimals="2"}
```

`:calc` fa aritmetica dal vivo su `+ - * /`, parentesi, numeri e `#chiavi`. Una
chiave mancante o non numerica conta zero, così un form mezzo compilato mostra
un totale che cresce; un'espressione malformata o una divisione per zero non ha
risposta affatto e si disegna `—` invece di stampare `NaN`.

Legge le chiavi che legge `:value` — quelle su cui scrivono i controlli. È una
vista legata, non una query sulle righe memorizzate.

### Le aggregazioni

Sulle righe memorizzate. Tutte prendono `path`, tutte tranne `count` prendono
`field`, tutte accettano `decimals`.

| | |
| --- | --- |
| `:count{path}` | quante righe |
| `:sum{path field}` | il totale |
| `:avg{path field}` | la media |
| `:min` / `:max` | gli estremi |
| `:median` | il valore tipico |
| `:stddev` | lo scarto quadratico medio campionario |
| `:mode` | il valore più frequente — funziona anche sul testo |

Lavorano sulle *stringhe memorizzate*, e un valore che non si legge come numero
**non viene contato** invece che contato zero: una media su quattro righe di cui
una lasciata in bianco è una media di tre.

Una collezione vuota ha un conteggio e una somma (entrambi 0) ma nessuna media,
nessun minimo e nessuna mediana. Quelle si disegnano `—`, non uno zero che
affermerebbe il falso.

## `::python` … `::/python`

CPython vero, nel browser: l'interprete gira su WebAssembly in un worker, così
un ciclo scritto per sbaglio non si porta via l'editor. Il codice va in un
**blocco recintato dentro la direttiva** — una recinzione è l'unico posto dove
Markdown conserva l'indentazione esattamente come è scritta, e l'indentazione è
la sintassi di Python.

| Attributo | |
| --- | --- |
| `data` | Collezioni da passare, separate da virgola. In Python sono `data["nome"]`, liste di dizionari di **stringhe** |
| `packages` | Pacchetti da caricare: `numpy`, `pandas`, `scipy`, `matplotlib`, `scikit-learn`, `sympy`… |
| `writes` | Una collezione in cui memorizzare le righe di `result` |
| `params` | Chiavi reattive da passare, separate da virgola. In Python sono `params["nome"]`, stringhe come tutto il resto |
| `manual` | Non parte mai da solo: aspetta il suo pulsante |
| `show` | Mostra il codice fin dall'inizio invece che dietro il suo pulsante |

````markdown
::python{data="voti"}
```python
voti = [int(v["voto"]) for v in data["voti"] if v["voto"]]
if voti:
    print(f"Media: {sum(voti) / len(voti):.1f}")
```
::/python
````

Viene mostrato quello che il codice ha **stampato**, poi il valore della sua
ultima espressione, poi le figure matplotlib — e il traceback al posto di tutti
e tre quando fallisce.

> I valori di una collezione sono **stringhe**. Passali per `int(...)` o
> `float(...)` prima di farci aritmetica, esattamente come sopra.

**Un blocco viene rieseguito quando cambia ciò da cui dipende** — il codice, i
dati, i pacchetti, i parametri — e non altrimenti: l'anteprima si ridisegna a
ogni battuta, e una esecuzione per battuta renderebbe impossibile scrivere.

**`params` fa entrare i controlli.** I pesi di un modello stanno su degli
slider, e `data=` porta dentro soltanto collezioni: `params="pesoBuche"` passa
al blocco il valore corrente di quelle chiavi reattive — quelle su cui scrivono
`::slider` e compagni, quelle che `:value` legge — come `params["pesoBuche"]`.
Sono parte di ciò per cui il blocco viene rieseguito, con lo stesso ritardo
delle altre direttive reattive, quindi muovere uno slider lo riesegue e
rimetterlo dov'era non lo esegue due volte.

**`manual` significa che il blocco aspetta il suo pulsante.** Un simulated
annealing non deve ripartire perché qualcuno ha corretto un cognome: un blocco
`manual` non parte mai da solo, i suoi dati e i suoi parametri si muovono
liberamente, e l'esecuzione comincia col pulsante *Esegui* e con nient'altro —
offerto prima della prima volta e di nuovo dopo ognuna. È anche quello che gli
compra tempo: un'esecuzione che nessuno ha chiesto viene fermata dopo due
minuti, una che qualcuno ha chiesto dopo dieci.

**Un'esecuzione lunga può riferire, e si può fermare.** Dentro il codice
esistono due funzioni: `progress(fatto, totale, messaggio)` disegna la barra e
dice cosa sta facendo — una chiamata senza totale lascia la barra indeterminata,
che è la forma onesta di «non so quanto ci vuole» — e `partial(righe)` pubblica
la migliore soluzione trovata finora, nella stessa forma di `result`. Mentre un
blocco gira c'è un pulsante **Ferma**, che termina l'interprete e memorizza
l'ultima `partial` ricevuta: è quello che rende «fermalo e tieni il risultato
migliore» una promessa invece che una frase. Un blocco che non chiama mai
`partial` non dà a Ferma niente da tenere: l'esecuzione finisce e non scrive
nulla. Conviene pubblicarne una ogni volta che la soluzione migliora — la regola
degli id è la stessa, quindi una `partial` aggiorna le sue righe invece di
raddoppiarle.

````markdown
::slider[pesoBuche]{label="Peso delle ore buche" min="0" max="100" value="60"}

::python{data="lezioni" params="pesoBuche" writes="violazioni" manual}
```python
peso = float(params["pesoBuche"] or 0)
lezioni = data["lezioni"]
migliore = []
for i, lezione in enumerate(lezioni):
    progress(i + 1, len(lezioni), "controllo i vincoli")
    if lezione.get("aula") == "":
        migliore.append({"row": lezione["ora"], "col": lezione["giorno"], "why": "manca l'aula"})
    partial(migliore)
result = migliore
```
::/python
````

**`writes` rimanda indietro le righe.** Assegna una lista di dizionari a
`result` e diventano una collezione di questa app. Una riga che porta un `id`
aggiorna quella riga, una che non ce l'ha ne riceve uno nuovo, così eseguire due
volte non raddoppia le righe. Un blocco non può scrivere in una collezione che
legge anche: si rieseguirebbe per sempre, ed è rifiutato invece che lasciato
girare.

**La prima esecuzione è lenta.** Scarica l'interprete (13 MB, da questa origine,
poi in cache); un pacchetto è qualche megabyte in più e viene dal CDN di Pyodide
— l'unico terzo con cui quest'app parli mai, e solo per i documenti che ne
chiedono uno.

## `::print` — la stampa

`::print{target="fattura" label="Stampa la fattura"}` stampa soltanto il
contenitore che porta quell'id — un `id` si dà a un `::card` come a qualunque
altro contenitore — e la finestra di stampa salva anche in PDF.

**`repeat` stampa una pagina per riga.** «Una pagina per classe» e «una pagina
per docente» sono la stessa richiesta ripetuta, e venti classi non sono una cosa
che qualcuno scriva a mano.

| Attributo | |
| --- | --- |
| `target` | L'id del contenitore da stampare |
| `label` | Cosa dice il pulsante |
| `repeat` | Una collezione: stampa il bersaglio una volta per ogni sua riga |
| `key` | La chiave reattiva impostata a ogni riga a turno |
| `field` | Quale campo della riga assume quella chiave; l'id se manca |

```markdown
::list{path="lezioni" filter="classe=#classe" id="orarioClasse"}
{giorno} · {ora} — {disciplina}
::/list

::print{target="orarioClasse" repeat="classi" key="classe" field="nome" label="Stampa l'orario di ogni classe"}
```

Per ogni riga la chiave viene impostata, alle viste è dato un momento per
rimettersi in pari, e il bersaglio viene *fotografato* in un contenitore di
stampa: un foglio per riga, con l'interruzione di pagina fra l'uno e l'altro. Le
copie sono HTML morto e nessuna deve restare viva; i grafici vengono congelati
nell'immagine che stavano mostrando, perché una tela copiata senza i suoi pixel
stamperebbe bianca. Alla fine la chiave torna al valore che aveva, così quello
che si vede a schermo prima e dopo è lo stesso.

Il bersaglio deve dipendere dalla chiave, e non c'è niente che lo imponga: una
sezione che non legge `#classe` — nessun `filter="classe=#classe"`, nessun
`:value{ref="#classe"}` — viene fotografata identica venti volte, e dalla
stampante escono venti pagine uguali. Il pulsante non segnala niente, perché da
dove sta lui non c'è niente che non vada.
