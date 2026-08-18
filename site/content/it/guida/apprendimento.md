---
title: "Apprendimento automatico"
description: "Le cinque direttive ml-*: gruppi, anomalie, regressione, correlazioni e previsioni, con scikit-learn dentro il browser."
weight: 25
translationKey: "apprendimento"
---

Cinque direttive fanno girare **scikit-learn nel browser** — sullo stesso
interprete Python di `::python`, quindi in un worker, quindi senza che una
elaborazione lunga blocchi la pagina. I dati non escono da qui.

Tutte hanno la stessa forma: leggono una collezione, imparano da alcuni campi
numerici, e **riscrivono le righe** in una collezione derivata con una colonna
in più.

```markdown
::range[k]{min="2" max="10" value="4" legend="Numero di gruppi"}

::ml-cluster{data="comuni" features="reddito,eta" k="#k" into="gruppi"}

::chart-scatter{data="gruppi" x="reddito" y="eta"}
```

## La regola comune

**Il codice eseguito è un modello fisso.** Quello che il documento scrive —
nomi di campi, parametri — non finisce mai dentro il codice: le righe e i
parametri viaggiano nel canale dati del runner e il Python li legge da lì. È lo
stesso argomento dell'SQL injection, applicato al posto in cui di solito nessuno
lo applica.

**Le feature sono campi numerici**, e conta tutta la stringa, non il suo inizio.
La **virgola decimale è accettata**. Le righe inutilizzabili vengono **scartate
e contate** nella riga di stato — che dice `usate/totali`, così si vede subito
se il modello ha imparato da trenta righe su duemila.

**I risultati sono collezioni derivate** e locali a questo dispositivo: non
vengono spinte in uno spazio condiviso, e un aggiornamento remoto non può
cancellarle. Un raggruppamento è il calcolo di questo browser, non un fatto
condiviso.

**I parametri numerici accettano le `#chiavi`**, quindi uno slider sopra la
direttiva la fa rieseguire: è il modo di guardare come cambia il risultato al
variare di k senza toccare il documento.

**La prima esecuzione che ha bisogno di un pacchetto aspetta dietro un pulsante
*Esegui*.** scikit-learn sono decine di megabyte, poi restano in cache. Nessun
documento li fa scaricare a chi lo apre senza averlo chiesto — con un'eccezione:
`::ml-correlate` è Python puro e non scarica niente.

Per `::ml-forecast` **se un pacchetto serva lo decide chi legge**: la tendenza
lineare non scarica nulla, `arima` e `holt` hanno bisogno di statsmodels. Quindi
scrivere `model="#chiave"` e metterci sopra un `::picker` è previsto, e il
pulsante *Esegui* compare quando viene scelto il modello che lo richiede — non
quando il blocco viene disegnato.

## `::ml-cluster` — i gruppi

K-means su feature standardizzate. Riscrive le righe con una colonna `cluster`.

| Attributo | |
| --- | --- |
| `data` | La collezione da cui imparare |
| `features` | I campi **numerici**, separati da virgola |
| `k` | Quanti gruppi, da 2 a 20 — un numero o una `#chiave` |
| `into` | La collezione derivata dove finiscono le righe |

La standardizzazione non è un dettaglio: senza, un campo in euro e uno in anni
non sono confrontabili e il raggruppamento lo decide da solo quello con i numeri
più grandi.

## `::ml-anomaly` — quello che non torna

Isolation Forest. Riscrive le righe con `anomalia` (da 0 a 1, più alto più
strano) e `flag` (1 = fuori riga).

| Attributo | |
| --- | --- |
| `data` | La collezione |
| `features` | I campi numerici |
| `contamination` | La quota attesa di anomalie, da 0 a 0.5; senza, 0.05 — un numero o una `#chiave` |
| `into` | La collezione derivata |

`contamination` è una **dichiarazione**, non una misura: si sta dicendo al
metodo quante anomalie aspettarsi, e lui ne troverà all'incirca quelle. Alzarla
non trova più problemi, segna più righe.

## `::ml-predict` — la regressione

Impara dalle righe in cui `target` è numerico e scrive `previsione` su **ogni**
riga che ha feature valide — comprese quelle in cui il target manca, che è
tutto il punto.

| Attributo | |
| --- | --- |
| `data` | La collezione |
| `features` | I campi numerici da cui imparare |
| `target` | Il campo numerico da imparare |
| `model` | `linear` oppure `forest` |
| `into` | La collezione derivata |

L'**R²** compare nella riga di stato. Vale la pena leggerlo prima di guardare le
previsioni: un R² basso non rende le previsioni sbagliate, le rende **prive di
informazione**, e una colonna di numeri plausibili è la cosa più facile da
credere che ci sia.

```markdown
::ml-predict{data="immobili" features="mq,piano,anno" target="prezzo" model="forest" into="stime"}

::chart-scatter{data="stime" x="prezzo" y="previsione"}
```

Quel grafico a dispersione — il vero contro il previsto — è il modo di guardare
un modello che non si riassume in un numero solo.

## `::ml-correlate` — che cosa va con che cosa

Matrice di correlazione di Pearson sulle feature: scrive coppie `{a, b, r}`.

| Attributo | |
| --- | --- |
| `data` | La collezione |
| `features` | I campi numerici |
| `into` | La collezione derivata dove finiscono le coppie |

È l'unica delle cinque che **non scarica niente**: è Python puro, quindi gira
subito. È anche quella da cui conviene partire, prima di scegliere le feature
delle altre.

## `::ml-forecast` — la previsione nel tempo

| Attributo | |
| --- | --- |
| `data` | La collezione con la serie |
| `x` | Il campo del tempo: un numero (un anno) o una data ISO |
| `y` | Il campo numerico del valore |
| `horizon` | Quante righe future scrivere, da 1 a 60; senza, 6 |
| `model` | `linear` (il difetto), `arima`/`sarima`, `holt`/`holt-winters`/`ets` |
| `season` | Il periodo stagionale: 12 per dati mensili |
| `into` | La collezione derivata |

Scrive la storia con una colonna `previsione`, più `horizon` righe future al
passo mediano della serie.

```markdown
::ml-forecast{data="iscritti" x="anno" y="alunni" model="holt" horizon="5" into="proiezione"}

::chart-line{data="proiezione" x="anno" y="alunni,previsione"}
```

Il **ripiego lineare è dichiarato**: se SARIMAX o Holt-Winters non convergono
sulla serie che hanno, il risultato è una tendenza lineare, la riga di stato lo
dice e riporta il motivo. Un modello stagionale che restituisse silenziosamente
una retta sarebbe peggio di uno che fallisce, perché il grafico verrebbe comunque
bene.

Un modello **differenziato** — ARIMA, SARIMA — non ha una stima per le sue prime
osservazioni: quelle righe restano **senza `previsione`**, e la linea della
proiezione comincia dove comincia il modello. Non valgono zero perché uno zero
all'inizio di un grafico di iscritti schiaccia tutto il resto sotto un picco, e
un R² calcolato contro quello zero racconta un modello disastroso che invece va
benissimo. L'R² è misurato solo su quello che il modello ha davvero stimato.

Se la serie ha **meno di tre punti** non c'è previsione: la riga di stato dice
`usate/totali` e la collezione resta vuota. Capita più spesso di quanto sembri
quando la serie viene da un dato aperto che copre pochi anni.
