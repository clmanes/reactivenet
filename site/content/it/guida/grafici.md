---
title: "Grafici e viste esplorative"
description: "I sette grafici che disegnano una collezione, il cruscotto con filtro incrociato e il pivot che il lettore costruisce da sé."
weight: 21
translationKey: "grafici"
---

Un grafico disegna **una collezione**, direttamente. Non c'è un passaggio di
preparazione, non c'è Python, non c'è un formato intermedio: si nomina la
collezione e i campi, e il grafico si ridisegna da sé ogni volta che quelle
righe cambiano — che sia qualcuno che salva un modulo, un `::od-query` che
risponde o un sensore che scrive.

Il motore è un pezzo caricato **solo se il documento ha un grafico**. Un
documento senza grafici non lo scarica mai.

## I sette

```markdown
::chart-bar{data="spese" x="voce" y="importo"}
::chart-line{data="letture" x="ts" y="temperatura,umidita"}
::chart-area{data="vendite" x="mese" y="online,negozio" stacked}
::chart-pie{data="spese" label="categoria" value="importo"}
::chart-doughnut{data="spese" label="categoria" value="importo"}
::chart-radar{data="profili" x="voce" y="a,b"}
::chart-scatter{data="comuni" x="reddito" y="eta"}
```

Si dividono in due famiglie secondo come nominano i dati, ed è l'unica cosa da
ricordare.

**Barre, linee, aree, radar e dispersione** prendono `x` e `y`:

| Attributo | |
| --- | --- |
| `data` | La collezione da disegnare |
| `x` | Il campo delle etichette |
| `y` | Uno o **più** campi numerici separati da virgola: una serie ciascuno |
| `height` | Un'altezza CSS; senza, `18rem` |

`::chart-bar` prende in più `horizontal` — le barre da sinistra a destra, che è
quello che serve quando le etichette sono nomi di persone o di comuni — e
`stacked`, che impila le serie invece di affiancarle. `::chart-area` prende
`stacked`: impilata, le serie salgono fino al loro totale, ed è la forma giusta
quando la somma significa qualcosa.

**Torta e ciambella** prendono invece `label` e `value`, perché una fetta è una
categoria e una quantità e non ha un asse:

| Attributo | |
| --- | --- |
| `data` | La collezione |
| `label` | Il campo della categoria |
| `value` | Il campo numerico |
| `height` | Un'altezza CSS |

```markdown
::chart-bar{data="comuni" x="comune" y="spesa" horizontal height="30rem"}
```

## Che cosa conta come numero

I valori memorizzati sono **stringhe** — è così che una riga viene salvata — e
un grafico deve decidere quali di quelle stringhe sono numeri. La regola è che
lo è **tutta** la stringa, non il suo inizio: `2026-08-10` non è l'anno 2026 e
`10 pezzi` non è dieci. La **virgola decimale è accettata**, perché i dati di un
grafico arrivano spesso da un CSV o da un dataset pubblico e lì `1.234,50` è
come si scrive.

Una riga che non si legge come numero **viene lasciata fuori**, non disegnata
come zero. È una differenza che si vede: una media su quattro righe di cui una
vuota è una media di tre, e una barra a zero direbbe che quel comune ha speso
zero invece che «non lo sappiamo».

## I colori

La tavolozza è fissa ed è quella di **Okabe-Ito**, nell'ordine: otto colori
scelti perché restino distinguibili anche a chi non distingue il rosso dal
verde. Non è configurabile per scelta — un grafico con colori scelti a mano è un
grafico che qualcuno dovrà ricontrollare, e la prima serie di ogni grafico
dell'app è dello stesso colore, il che è metà della leggibilità di un cruscotto.

## `::dashboard` … `::/dashboard` — il filtro incrociato

Un cruscotto lega insieme le viste che contiene. Cliccando una barra o una fetta
di un grafico annidato, **tutte le altre viste** — tabelle, liste, schede,
calendari, mappe — si restringono alle righe che hanno quel valore. Un secondo
clic sulla stessa barra toglie il filtro, e un chip in alto lo mostra con la sua
✕.

```markdown
::dashboard{path="spese"}
::chart-bar{data="spese" x="categoria" y="importo"}

::table{path="spese" search}
::column{field="voce" label="Voce"}
::column{field="importo" label="Importo" align="end"}
::/table
::/dashboard
```

Tre regole, prese dagli strumenti che fanno questo di mestiere:

- **Il grafico cliccato non filtra sé stesso.** Sbiadisce le altre barre e
  tiene la sua. Un grafico che si riducesse a una barra sola toglierebbe proprio
  il contesto per cui lo si stava guardando.
- **Una vista su un'altra collezione filtra solo le righe che quel campo ce
  l'hanno.** Chi non lo ha resta.
- **La selezione è di questo dispositivo**, non viene mai sincronizzata, e
  sopravvive alle modifiche dei dati. Quello che sto guardando io non è un fatto
  dell'app, è un fatto di questa sessione.

## `::explore` … `::/explore` — il pivot del lettore

```markdown
::explore{path="spese" view="bar" group-by="categoria"}
::/explore
```

Una tabella pivot interattiva: il lettore trascina le colonne, raggruppa,
cambia grafico, filtra — **anche in sola lettura**, senza toccare il documento.
È la direttiva da usare quando non si sa in anticipo che domanda verrà fatta ai
dati.

| Attributo | |
| --- | --- |
| `path` | La collezione |
| `view` | Il grafico iniziale: `datagrid`, `bar`, `line`, `area`, `scatter`, `heatmap`, `treemap`, `sunburst` |
| `group-by` | I campi che diventano le righe del pivot, separati da virgola |
| `split-by` | I campi che diventano le colonne |
| `columns` | I campi mostrati come valori |
| `height` | Un'altezza CSS; senza, `24rem` |

I tipi delle colonne sono **dedotti dai dati** — una stringa che è tutta un
numero entra come numero — così le aggregazioni sommano davvero invece di
concatenare. La configurazione che il lettore si costruisce **sopravvive alle
modifiche del documento**: si sta scrivendo accanto, l'anteprima si ridisegna a
ogni tasto, e il pivot resta com'era.

Il corpo fenced facoltativo è la configurazione JSON nativa del visualizzatore e
**vince sugli attributi**, per chi ha già una configurazione salvata e vuole
incollarla.

> Un nome di colonna che le righe non hanno viene tolto prima di applicare la
> configurazione, e non è pignoleria: quel visualizzatore ripristina tutto o
> niente, quindi un nome sbagliato costerebbe la configurazione intera —
> compreso il grafico — e il lettore si troverebbe una griglia dove il documento
> chiedeva un grafico, senza niente che dica perché.

## Su una pagina che non si vede

Un grafico e un pivot **si misurano**: hanno bisogno di sapere quanto sono
larghi per disegnarsi. Una `::page` che non è quella mostrata non ha dimensioni
affatto, quindi una vista costruita lì disegnerebbe dentro una scatola di zero
pixel. Non è un problema da gestire: l'app aspetta che la pagina compaia e
costruisce allora. Vale la pena saperlo solo per non stupirsi che un grafico su
una pagina mai aperta non abbia ancora fatto niente.
