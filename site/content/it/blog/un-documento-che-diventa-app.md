---
title: "Un documento che diventa un'app: vibecoding con un vincolo"
seotitle: "Un documento che diventa un'app: vibecoding"
description: "ReactiveNET esegue un documento Markdown come un'applicazione: come funziona, cosa un'app può fare e perché un formato leggibile rende controllabile l'AI."
date: 2026-08-13
author: "Cosimo Luigi Manes"
translationKey: "un-documento-che-diventa-app"
cover: "/img/blog/documento-che-diventa-app-editor.png"
coverAlt: "L'editor di ReactiveNET: il sorgente Markdown a sinistra, l'app che ne risulta a destra"
---

Se un modello sa scrivere software, la domanda interessante non è quanto in fretta lo
scrive. È: **come faccio a controllare quello che ha scritto?**

ReactiveNET risponde scegliendo il formato di consegna: un documento Markdown che il
browser esegue così com'è. Non un repository da compilare, non un servizio da
installare. Un file di testo che si legge in cinque minuti.

## Come funziona

Questa è un'applicazione completa:

```markdown
---
appId: spesa
title: Lista della spesa
---

::form{path="voci"}
::input{field="cosa" legend="Voce"}
::save{label="Aggiungi"}
::/form

::if-empty{path="voci"}
Non c'è ancora niente in lista.
::/if-empty

::list{path="voci" deletable}
{cosa}
::/list
```

![L'editor di ReactiveNET: a sinistra il sorgente Markdown del documento, a destra l'applicazione che ne risulta, con uno slider e i valori che lo seguono](/img/blog/documento-che-diventa-app-editor.png "A sinistra il documento, a destra l'app: la stessa cosa vista da due lati. L'anteprima si aggiorna mentre si scrive.")

È Markdown normale — titoli, tabelle, formule, diagrammi — più le **direttive**: le
righe che descrivono le parti interattive. Ce ne sono di due forme, in riga
(`:nome[…]{…}`) e a blocco (`::nome{…}`), e la chiusura dice che cosa chiude
(`::/form`). Non c'è niente da contare, e annidare non richiede aritmetica.

Il documento diventa app passando per una catena breve:

```
documento
  → si separano i metadati dal corpo
  → Markdown e direttive diventano HTML
  → il sanitizzatore approva l'HTML
  → l'HTML entra nella pagina (unico punto di scrittura)
  → si legano controlli, viste, moduli e liste
```

Tutto quello che viene dopo il sanitizzatore lavora su nodi già approvati. Tutto
quello che viene prima non tocca l'archivio.

I componenti non sono scritti a mano. Uno script legge i manifest di Adobe Spectrum e
genera un registro di **92 componenti e 482 attributi**. Da quella lista sola
discendono la costruzione degli elementi, la validazione degli attributi, l'allowlist
del sanitizzatore, i blocchi dell'editor visuale e i completamenti. Aggiungere un
componente è un aggiornamento di libreria, non una riga di codice.

## Perché così si riesce a controllare

L'obiezione al *vibecoding* non è che il codice generato sia sbagliato: quasi sempre è
plausibile. È che nessuno lo legge. Codice lungo, sparso su venti file e mai riletto
sposta il costo più avanti, dove si paga di più.

Qui lo spazio in cui si può sbagliare è ristretto per costruzione. Un'app non esegue
codice arbitrario, non va in rete di sua iniziativa, non tocca dati che non siano i
suoi. La logica sta in una schermata e si legge come prosa.

Su questo si appoggiano due strumenti, disponibili anche agli assistenti esterni
tramite MCP:

- un **validatore**, che legge il documento con lo stesso scanner del motore di
  rendering — mai una seconda copia, che prima o poi divergerebbe — e segnala anche
  le cose che sono valide ma sbagliate: un campo fuori da un modulo, un colore
  esadecimale letto come riferimento, un overlay che bloccherebbe la pagina;
- un **analizzatore del flusso dei dati**, che costruisce il grafo di chi scrive ogni
  collezione e chi la legge, e trova quello che la sintassi non vede: una vista su
  dati che nessuno produce, un riferimento senza sorgente, un modulo senza salvataggio.

L'assistente integrato passa da lì, e **senza validazione non consegna**: se il
rapporto non è pulito non scrive niente e rimanda gli errori al modello. Non è
prudenza teorica — i modelli piccoli dichiaravano di aver validato senza averlo fatto.

![La galleria delle app del browser, con il campo per descrivere una nuova app e il catalogo delle app pubblicate](/img/blog/documento-che-diventa-app-galleria.png "La galleria: le app di questo browser, il campo da cui l'assistente ne genera una nuova e il catalogo di quelle pubblicate.")

## Dove finiscono i dati

Tutto quello che un'app sa vive in **IndexedDB, nel browser di chi la usa**.
`localStorage` non è usato da nessuna parte, per regola. E l'archivio non fallisce
rumorosamente: un database bloccato — navigazione privata, disco pieno — risponde
«nessun valore» e produce una galleria vuota, non una pagina di errore.

Il rischio da cui difendersi è il **DOM XSS**, perché la funzione è letteralmente
trasformare in HTML del testo scritto da qualcuno. Le difese sono a strati, così che
nessuna sia l'unica a reggere:

- gli URL non sicuri **non sono esprimibili**: il tipo è astratto, il parser è l'unico
  modo di costruirne uno, e ripulisce i caratteri di controllo *prima* di leggere lo
  schema — `java\tscript:` naviga esattamente come `javascript:`;
- anche l'HTML sanitizzato è un tipo astratto, e la funzione che scrive nella pagina
  non accetta altro: scrivere senza passare dal sanitizzatore non si può proprio dire;
- un valore salvato entra come **testo, mai come markup**: una riga che contiene
  `<script>` è una riga che mostra quei caratteri, e c'è un test che lo verifica;
- le espressioni di calcolo le valuta un parser scritto a mano su quattro operatori.
  `eval` non c'è da nessuna parte;
- CSP con Trusted Types, `script-src` senza `unsafe-inline` e senza `unsafe-eval`, con
  la stessa politica emessa in tre posti e un test che impedisce che divergano.

Il Python di un blocco `::python` gira in un worker con un tetto di tempo: un ciclo
infinito scritto per sbaglio finisce, senza portarsi via l'editor.

## La privacy non è una promessa, è la forma del sistema

Non c'è un backend applicativo a cui mandare qualcosa. Documenti, righe e preferenze
restano sul dispositivo, non serve un account, e un'app non può esfiltrare dati perché
non può raggiungere niente di sua iniziativa.

La condivisione segue la stessa logica. Il **link lungo** porta il documento nel
frammento dell'indirizzo — la parte dopo `#`, che per specifica non arriva mai a
nessun server. Il **link breve**, quando il documento è troppo grande per un
indirizzo, deposita un blob cifrato in AES-GCM: la cifratura avviene nel browser prima
dell'invio, la chiave viaggia nel frammento e al server non arriva mai. Quello che
resta è illeggibile, e viene cancellato 120 giorni dopo l'ultima apertura.

La sincronizzazione fra più persone è cifrata end-to-end: una chiave per spazio e per
epoca, consegnata a ogni membro cifrata verso la sua chiave pubblica. Il server è un
relay di blob opachi; la fusione avviene solo nei client. E i limiti sono dichiarati:
**la revoca non annulla il passato**, ruota la chiave e sigilla il futuro; il server
vede comunque che uno pseudonimo appartiene a uno spazio, quando arriva una modifica e
quanto è grande. È il pavimento di metadati di questo disegno — minimizzato, e poi
detto invece che negato.

## E l'assistente?

È disattivato finché non lo si configura, e come lo si configura decide tutto.

Con un **modello locale** — Ollama in ascolto su `localhost` — niente lascia la
macchina, e non c'è nessuna chiave da proteggere. Con un **fornitore remoto** il
browser parla direttamente con lui, e a lui arrivano la domanda, la conversazione e il
testo del documento aperto.

Da poco un'app può contenere anche direttive `ai-*`: riassumere una collezione,
rispondere a domande sui propri dati, riempire un modulo da una frase, cercare per
significato. Usano lo stesso modello, e vale la stessa regola: con un fornitore remoto
**vanno a quel fornitore anche un campione delle righe** — non l'intera collezione, ma
righe vere. Un'app senza direttive `ai-*` non ne manda nessuna.

È scritto nell'informativa con questo livello di dettaglio perché è una scelta che
spetta a chi usa la piattaforma, e va potuta fare sapendo che cosa si sceglie. Per
un'app che tratta dati personali, la risposta consigliata è una sola: il modello
locale.

![L'app aperta senza editor: menu delle pagine a sinistra, contenuto e controlli interattivi al centro](/img/blog/documento-che-diventa-app-uso.png "La stessa app vista da chi la usa. Lettura e modifica sono due URL distinti: inviare il primo significa inviare l'app.")

## Che cosa cambia davvero con l'AI

Non la velocità di scrittura. Cambia che **il costo di un'app fatta apposta scende
sotto la soglia oltre la quale conviene adattarsi a uno strumento generico**. Il
registro di uno studio, la turnazione di un reparto, l'inventario di
un'associazione: casi che non hanno mai giustificato un progetto software, e che oggi
si descrivono in una frase.

Quando produrre costa poco, il collo di bottiglia si sposta: non è più scrivere, è
**controllare**. E la controllabilità non è una proprietà del modello, è una proprietà
del formato e del perimetro. Un documento che si legge tutto, gira in locale, non
raggiunge la rete e tiene i dati sul dispositivo soddisfa entrambe le condizioni. Un
artefatto opaco che gira sull'infrastruttura di qualcun altro non ne soddisfa nessuna.

Una conseguenza va detta per intero, perché è il rovescio esatto della promessa: chi
crea un'app e la usa per raccogliere dati di altre persone è **titolare autonomo** di
quel trattamento. La piattaforma non ha accesso a quei dati e non può intervenirci —
ed è precisamente ciò che rende credibile la garanzia di riservatezza a rendere quella
responsabilità non delegabile.

## In arrivo: la nuova release

Le schermate di questo articolo non sono della versione oggi in linea: sono la
**release 1.1**, in uscita a breve. Cambia parecchia superficie — il routing per
percorso, con un indirizzo distinto per leggere e per modificare ogni app; il catalogo
delle app pubblicate dentro la galleria; la grammatica dei blocchi con la chiusura che
nomina; le direttive per dati aperti, grafici, mappe, SQL, calcolo e AI; l'assistente
con la validazione obbligatoria prima della consegna.

Il dettaglio sarà nel post di rilascio, ma un'avvertenza va data adesso: la vecchia
forma dei contenitori — tre o più due punti, chiusi da una riga della stessa lunghezza
— **non viene più letta**. Un documento scritto così mostrerà le direttive come testo,
e va convertito riscrivendo ogni apertura in `::nome` e ogni chiusura in `::/nome`.

È una rottura voluta. Una grammatica con due modi di scrivere la stessa cosa va tenuta
in piedi in quattro punti del sistema, e il secondo modo era quello che obbligava chi
scrive a contare.

## Provare

Il percorso più corto è [aprire l'applicazione](https://app.reactivenet.ai) e
descrivere in una frase l'app che serve. Per la sintassi si parte dalla
[guida](/guida/sintassi/). In ogni caso, quello che resta in mano è un file di testo:
si legge, si versiona, si porta via.
