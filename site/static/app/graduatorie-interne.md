---
appId: graduatorie-interne
title: Graduatorie Interne
description: "Graduatorie interne d'istituto per l'individuazione dei soprannumerari: tabella di valutazione modificabile, dichiarazioni del personale, istruttoria, punteggi spiegati riga per riga, graduatoria in ordine crescente, reclami e stampe."
icon: list-numbered
lang: it
version: "1.0"
author: ReactiveNET
date: "2026-08-13"
---

::page{title="Avvio" icon="list-numbered"}

# Graduatorie Interne d'Istituto

Raccoglie le dichiarazioni del personale, calcola i punteggi secondo una **tabella
di valutazione che sta nei dati e non nel codice**, e produce le graduatorie interne
per l'individuazione dei soprannumerari. Tutto in questo browser: nessun dato esce.

## La regola che decide tutto il resto

La tabella di valutazione **cambia**. La riscrive ogni rinnovo del CCNI sulla
mobilità, l'ordinanza annuale ne cambia termini e dettagli, e quella dei docenti non
è quella degli ATA. Un software che si portasse i punteggi dentro sarebbe da buttare
al primo rinnovo.

Quindi qui **non c'è un solo punteggio scritto nel programma**. Voci, sezioni, punti,
massimali, tipi e riferimenti normativi sono righe di una collezione, si modificano
dalla pagina *Tabella*, e ogni graduatoria porta scritta la versione con cui è stata
calcolata.

> La tabella seminata qui dentro è un **esempio realistico ma non ufficiale**, utile
> per provare l'app al primo avvio. Prima di usarla per davvero va confrontata voce
> per voce con il CCNI vigente e con l'ordinanza dell'anno: è esattamente il lavoro
> che questa app rende possibile fare una volta invece che ogni anno da capo.

## Che cosa fa, e che cosa non fa

| Fa | Non fa |
| --- | --- |
| Tabella di valutazione modificabile dall'interfaccia, versionata | Non conosce il CCNI: quello che sa è quello che c'è scritto in tabella |
| Anagrafica del personale con titolarità e modalità di arrivo | Non parla col SIDI e non importa nulla da lì |
| Dichiarazioni voce per voce, con quantità e dettagli | Non manda link personali a nessuno: la scheda si compila qui |
| **Servizio calcolato**: la continuità nella scuola si ricava dalla data di titolarità | Non ricostruisce carriere: il pre-ruolo e le altre scuole si dichiarano |
| Istruttoria con conferme, rettifiche motivate e anomalie | Non decide se una dichiarazione è vera |
| **Prospetto individuale**: ogni punto giustificato, con riferimento normativo | Non risponde al reclamo al posto tuo — ma stampa quello che serve per farlo |
| Graduatoria in ordine **crescente**, per raggruppamento, con esclusi in coda | Non individua il soprannumerario: lo individua il dirigente, leggendo |
| Riporto dall'anno precedente con anzianità aggiornata | Non conserva a norma nulla: l'archivio è un backup, non una conservazione |
| Documento **pubblicabile** senza dati eccedenti | Non firma digitalmente niente |

## Dati sanitari: non ce ne sono

Non esiste in tutta l'app un campo in cui scrivere una patologia, una diagnosi o la
condizione di un familiare. L'esclusione dalla graduatoria si registra con la sola
**categoria normativa** che vi dà titolo, e il documento pubblicabile non riporta
neppure quella.

## Chi possiede che cosa

Un blocco Python **riscrive per intero** la collezione che gli è affidata, quindi
ogni collezione qui ha un padrone solo.

| Padrone | Collezioni |
| --- | --- |
| Tu, con un modulo | `voci-aggiunte`, `personale-aggiunto`, `dichiarazioni-aggiunte`, `servizi-aggiunti`, `verifiche`, `esclusioni`, `reclami` |
| Un blocco | `tabella`, `personale`, `dichiarazioni`, `servizi`, `prospetto`, `graduatoria`, `anomalie`, `archivio` |

Le anagrafiche *in uso* sono costruite: l'esempio scritto nel blocco più le righe che
hai aggiunto tu. Aggiungi, poi premi **Esegui**.

## Semina l'istituto di esempio

Premi i due pulsanti in ordine — il personale e la tabella — e poi, nella pagina
*Calcolo*, i blocchi del calcolo. La prima esecuzione scarica l'interprete Python
(13 MB, poi resta in cache).

::python{data="personale-aggiunto" writes="personale" manual}
```python
# Quattordici unità di personale, inventate. L'id è scritto a mano perché le
# dichiarazioni, i servizi e le esclusioni lo citano.
result = [
    {"id": "p-01", "cognome": "Baroni", "nome": "Chiara", "profilo": "docente",
     "raggruppamento": "A012 - Lettere", "tipoPosto": "comune",
     "dataTitolarita": "2016-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-02", "cognome": "Costa", "nome": "Marco", "profilo": "docente",
     "raggruppamento": "A012 - Lettere", "tipoPosto": "comune",
     "dataTitolarita": "2022-09-01", "arrivo": "trasferimento d'ufficio"},
    {"id": "p-03", "cognome": "De Santis", "nome": "Elena", "profilo": "docente",
     "raggruppamento": "A012 - Lettere", "tipoPosto": "comune",
     "dataTitolarita": "2024-09-01", "arrivo": "immissione in ruolo"},
    {"id": "p-04", "cognome": "Ferrero", "nome": "Luca", "profilo": "docente",
     "raggruppamento": "A026 - Matematica", "tipoPosto": "comune",
     "dataTitolarita": "2011-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-05", "cognome": "Greco", "nome": "Sara", "profilo": "docente",
     "raggruppamento": "A026 - Matematica", "tipoPosto": "comune",
     "dataTitolarita": "2019-09-01", "arrivo": "passaggio di ruolo"},
    {"id": "p-06", "cognome": "Iervolino", "nome": "Paolo", "profilo": "docente",
     "raggruppamento": "A026 - Matematica", "tipoPosto": "comune",
     "dataTitolarita": "2023-09-01", "arrivo": "trasferimento d'ufficio"},
    {"id": "p-07", "cognome": "Lanza", "nome": "Marta", "profilo": "docente",
     "raggruppamento": "A046 - Diritto", "tipoPosto": "comune",
     "dataTitolarita": "2014-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-08", "cognome": "Marino", "nome": "Davide", "profilo": "docente",
     "raggruppamento": "ADSS - Sostegno", "tipoPosto": "sostegno",
     "dataTitolarita": "2018-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-09", "cognome": "Neri", "nome": "Giulia", "profilo": "docente",
     "raggruppamento": "ADSS - Sostegno", "tipoPosto": "sostegno",
     "dataTitolarita": "2021-09-01", "arrivo": "immissione in ruolo"},
    {"id": "p-10", "cognome": "Orlando", "nome": "Franco", "profilo": "docente",
     "raggruppamento": "A046 - Diritto", "tipoPosto": "comune",
     "dataTitolarita": "2009-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-11", "cognome": "Pastore", "nome": "Rita", "profilo": "ata",
     "raggruppamento": "AA - Assistente amministrativo", "tipoPosto": "",
     "dataTitolarita": "2013-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-12", "cognome": "Quaranta", "nome": "Nicola", "profilo": "ata",
     "raggruppamento": "AA - Assistente amministrativo", "tipoPosto": "",
     "dataTitolarita": "2020-09-01", "arrivo": "trasferimento d'ufficio"},
    {"id": "p-13", "cognome": "Riva", "nome": "Anna", "profilo": "ata",
     "raggruppamento": "CS - Collaboratore scolastico", "tipoPosto": "",
     "dataTitolarita": "2010-09-01", "arrivo": "trasferimento a domanda"},
    {"id": "p-14", "cognome": "Santoro", "nome": "Gino", "profilo": "ata",
     "raggruppamento": "CS - Collaboratore scolastico", "tipoPosto": "",
     "dataTitolarita": "2025-09-01", "arrivo": "immissione in ruolo"},
]

campi = ["cognome", "nome", "profilo", "raggruppamento", "tipoPosto",
         "dataTitolarita", "arrivo"]
for riga in data["personale-aggiunto"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d unità in anagrafica, di cui %d aggiunte da te."
      % (len(result), len(data["personale-aggiunto"])))
```
::/python

::python{data="voci-aggiunte" writes="tabella" manual}
```python
# La tabella di valutazione. NON è normativa: è un esempio da confrontare con il
# CCNI vigente. Ogni riga è una voce; il codice è la sua chiave.
#
#   tipo:  fisso                 punti una volta sola
#          moltiplicabile        punti * quantità dichiarata
#          per-anno-continuita   punti per ogni anno nella scuola di titolarità
#          per-anno-ruolo        punti per ogni anno di ruolo altrove
#          per-anno-preruolo     punti per ogni anno pre-ruolo
#          per-anno-disagiata    punti per ogni anno in sede disagiata
#          massimale-sezione     non è una voce: è il tetto di quella sezione
#
#   permanente: "true" se il titolo vale anche l'anno prossimo senza ridichiararlo.
docenti = [
    ("D-I-1", "docenti", "I", "Anzianità di servizio", "Per ogni anno di ruolo prestato nella scuola di attuale titolarità", 6, "per-anno-continuita", "", "true", "CCNI mobilità, tab. valutazione, sez. I"),
    ("D-I-2", "docenti", "I", "Anzianità di servizio", "Per ogni anno di ruolo prestato in altra istituzione scolastica", 6, "per-anno-ruolo", "", "true", "CCNI mobilità, tab. valutazione, sez. I"),
    ("D-I-3", "docenti", "I", "Anzianità di servizio", "Per ogni anno di servizio pre-ruolo riconosciuto", 3, "per-anno-preruolo", "", "true", "CCNI mobilità, tab. valutazione, sez. I"),
    ("D-I-4", "docenti", "I", "Anzianità di servizio", "Per ogni anno prestato in sede disagiata", 2, "per-anno-disagiata", "20", "true", "CCNI mobilità, tab. valutazione, sez. I"),
    ("D-II-1", "docenti", "II", "Esigenze di famiglia", "Ricongiungimento al coniuge o alla parte dell'unione civile", 6, "fisso", "", "", "CCNI mobilità, tab. valutazione, sez. II"),
    ("D-II-2", "docenti", "II", "Esigenze di famiglia", "Per ogni figlio di età inferiore a sei anni", 4, "moltiplicabile", "", "", "CCNI mobilità, tab. valutazione, sez. II"),
    ("D-II-3", "docenti", "II", "Esigenze di famiglia", "Per ogni figlio di età fra sei e diciotto anni", 3, "moltiplicabile", "", "", "CCNI mobilità, tab. valutazione, sez. II"),
    ("D-II-4", "docenti", "II", "Esigenze di famiglia", "Assistenza al familiare rientrante nelle categorie previste dal CCNI", 6, "fisso", "", "", "CCNI mobilità, tab. valutazione, sez. II"),
    ("D-III-1", "docenti", "III", "Titoli generali", "Superamento di concorso ordinario per esami e titoli", 12, "fisso", "12", "true", "CCNI mobilità, tab. valutazione, sez. III"),
    ("D-III-2", "docenti", "III", "Titoli generali", "Inclusione nella graduatoria di merito del medesimo concorso", 3, "fisso", "3", "true", "CCNI mobilità, tab. valutazione, sez. III"),
    ("D-III-3", "docenti", "III", "Titoli generali", "Per ogni dottorato o diploma di specializzazione post-laurea", 5, "moltiplicabile", "10", "true", "CCNI mobilità, tab. valutazione, sez. III"),
    ("D-III-4", "docenti", "III", "Titoli generali", "Per ogni master o corso di perfezionamento annuale", 1, "moltiplicabile", "5", "true", "CCNI mobilità, tab. valutazione, sez. III"),
    ("D-III-5", "docenti", "III", "Titoli generali", "Titolo di specializzazione per il sostegno", 6, "fisso", "", "true", "CCNI mobilità, tab. valutazione, sez. III"),
    ("D-MAX-III", "docenti", "III", "Titoli generali", "Massimale della sezione III", 20, "massimale-sezione", "", "", "CCNI mobilità, tab. valutazione, sez. III"),
]
ata = [
    ("A-I-1", "ata", "I", "Anzianità di servizio", "Per ogni anno di ruolo prestato nella scuola di attuale titolarità", 6, "per-anno-continuita", "", "true", "CCNI mobilità, tab. valutazione ATA, sez. I"),
    ("A-I-2", "ata", "I", "Anzianità di servizio", "Per ogni anno di ruolo prestato in altra istituzione scolastica", 6, "per-anno-ruolo", "", "true", "CCNI mobilità, tab. valutazione ATA, sez. I"),
    ("A-I-3", "ata", "I", "Anzianità di servizio", "Per ogni anno di servizio pre-ruolo riconosciuto", 3, "per-anno-preruolo", "", "true", "CCNI mobilità, tab. valutazione ATA, sez. I"),
    ("A-II-1", "ata", "II", "Esigenze di famiglia", "Ricongiungimento al coniuge o alla parte dell'unione civile", 6, "fisso", "", "", "CCNI mobilità, tab. valutazione ATA, sez. II"),
    ("A-II-2", "ata", "II", "Esigenze di famiglia", "Per ogni figlio di età inferiore a sei anni", 4, "moltiplicabile", "", "", "CCNI mobilità, tab. valutazione ATA, sez. II"),
    ("A-II-3", "ata", "II", "Esigenze di famiglia", "Per ogni figlio di età fra sei e diciotto anni", 3, "moltiplicabile", "", "", "CCNI mobilità, tab. valutazione ATA, sez. II"),
    ("A-III-1", "ata", "III", "Titoli generali", "Titolo di studio superiore a quello richiesto per l'accesso al profilo", 5, "fisso", "5", "true", "CCNI mobilità, tab. valutazione ATA, sez. III"),
    ("A-III-2", "ata", "III", "Titoli generali", "Per ogni corso o certificazione attinente al profilo", 1, "moltiplicabile", "4", "true", "CCNI mobilità, tab. valutazione ATA, sez. III"),
    ("A-MAX-III", "ata", "III", "Titoli generali", "Massimale della sezione III", 10, "massimale-sezione", "", "", "CCNI mobilità, tab. valutazione ATA, sez. III"),
]

def voce(riga):
    return {
        "id": "v-" + riga[0].lower(), "codice": riga[0], "profilo": riga[1],
        "sezione": riga[2], "sezioneNome": riga[3], "descrizione": riga[4],
        "punti": str(riga[5]), "tipo": riga[6], "massimale": riga[7],
        "permanente": riga[8], "riferimento": riga[9],
    }

result = [voce(r) for r in docenti + ata]

# Una voce aggiunta CON LO STESSO CODICE sostituisce quella di serie: è così che
# si corregge un punteggio senza toccare il programma. Con punti vuoti, la
# disattiva — sparisce dalla tabella e da ogni calcolo.
per_codice = {v["codice"]: i for i, v in enumerate(result)}
campi = ["codice", "profilo", "sezione", "sezioneNome", "descrizione", "punti",
         "tipo", "massimale", "permanente", "riferimento"]
sostituite, disattivate, aggiunte = 0, 0, 0
for riga in data["voci-aggiunte"]:
    codice = (riga.get("codice") or "").strip()
    if not codice:
        continue
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    if codice in per_codice:
        if (nuova.get("punti") or "").strip() == "":
            result[per_codice[codice]] = None
            disattivate += 1
        else:
            base = result[per_codice[codice]]
            for campo in campi:
                if (nuova.get(campo) or "").strip() != "":
                    base[campo] = nuova[campo]
            sostituite += 1
    else:
        result.append(nuova)
        aggiunte += 1
result = [v for v in result if v is not None]

print("Tabella: %d voci (%d sostituite, %d disattivate, %d aggiunte da te)."
      % (len(result), sostituite, disattivate, aggiunte))
print("Versione della tabella: %s" % ("v" + str(len(result)) + "-" + str(sostituite + aggiunte)))
```
::/python

::/page

::page{title="Tabella" icon="data-edit"}

# Tabella di valutazione

Questa è la tabella con cui si calcola. Per correggerla non si tocca il programma:
si aggiunge una riga qui sotto e si ripremi *Esegui* nella pagina Avvio.

**Una riga con un codice già esistente sostituisce quella di serie.** Con i punti
lasciati vuoti, la disattiva.

::form{path="voci-aggiunte" id="modVoce"}
::input{field="codice" legend="Codice" required help="D-II-2 corregge quella voce; un codice nuovo aggiunge una voce."}
::input{field="profilo" legend="Profilo" required pattern="docenti|ata" message="Scrivi docenti oppure ata"}
::input{field="sezione" legend="Sezione" required pattern="I|II|III" message="I, II oppure III"}
::input{field="sezioneNome" legend="Nome della sezione" placeholder="Titoli generali"}
::input{field="descrizione" legend="Descrizione della voce"}
::input{field="punti" type="number" legend="Punti" step="0.01" help="Vuoto = disattiva la voce di serie con questo codice."}
::input{field="tipo" legend="Tipo" pattern="fisso|moltiplicabile|per-anno-continuita|per-anno-ruolo|per-anno-preruolo|per-anno-disagiata|massimale-sezione|" message="fisso, moltiplicabile, per-anno-continuita, per-anno-ruolo, per-anno-preruolo, per-anno-disagiata, massimale-sezione"}
::input{field="massimale" type="number" legend="Massimale della voce" step="0.01"}
::input{field="permanente" type="checkbox" legend="Vale anche l'anno prossimo"}
::input{field="riferimento" legend="Riferimento normativo"}
::save{label="Salva la voce"}
::/form

::if-any{path="voci-aggiunte"}
### Le tue modifiche alla tabella

::table{path="voci-aggiunte" deletable editform="modVoce" sort="codice"}
::column{field="codice" label="Codice"}
::column{field="descrizione" label="Descrizione"}
::column{field="punti" label="Punti" align="end"}
::column{field="tipo" label="Tipo"}
::/table
::/if-any

## La tabella in uso

::table{path="tabella" search filters="profilo,sezione" sort="codice" page-size="20"}
::column{field="codice" label="Codice"}
::column{field="profilo" label="Profilo"}
::column{field="sezione" label="Sez."}
::column{field="descrizione" label="Descrizione"}
::column{field="punti" label="Punti" align="end"}
::column{field="tipo" label="Tipo"}
::column{field="massimale" label="Max" align="end"}
::/table

::/page

::page{title="Personale" icon="user-group"}

# Personale titolare

::form{path="personale-aggiunto" id="modPersona"}
::input{field="cognome" legend="Cognome" required}
::input{field="nome" legend="Nome" required}
::input{field="profilo" legend="Profilo" required pattern="docente|ata" message="docente oppure ata"}
::input{field="raggruppamento" legend="Classe di concorso o profilo" required help="È il raggruppamento in cui si formerà la graduatoria."}
::input{field="tipoPosto" legend="Tipologia di posto" help="comune, sostegno — vuoto per gli ATA"}
::input{field="dataTitolarita" type="date" legend="Titolarità nella scuola dal" required help="Da qui si ricava la continuità: non va dichiarata."}
::input{field="arrivo" legend="Modalità di arrivo" help="trasferimento a domanda, d'ufficio, passaggio di ruolo, immissione in ruolo"}
::save{label="Salva"}
::/form

::if-any{path="personale-aggiunto"}
::table{path="personale-aggiunto" deletable editform="modPersona" sort="cognome"}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="raggruppamento" label="Raggruppamento"}
::/table
::/if-any

## In anagrafica: :count{path="personale"} unità

::table{path="personale" search filters="profilo,raggruppamento" sort="cognome" page-size="20"}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="profilo" label="Profilo"}
::column{field="raggruppamento" label="Raggruppamento"}
::column{field="dataTitolarita" label="Titolare dal"}
::column{field="arrivo" label="Arrivo"}
::/table

## Esclusioni dalla graduatoria

Si registra **soltanto la categoria normativa** che dà titolo all'esclusione o alla
precedenza. Non c'è, e non ci sarà, un campo per la patologia o per la condizione
della persona o del familiare.

::form{path="esclusioni" id="modEsclusione"}
::input{field="interessato" type="ref" path="personale" label="cognome" legend="Interessato" required}
::input{field="categoria" legend="Categoria normativa" required help="Es.: beneficiario delle precedenze previste dal CCNI, punto III"}
::input{field="riferimento" legend="Riferimento" placeholder="CCNI mobilità, art. 13"}
::input{field="decorrenza" type="date" legend="Decorrenza"}
::input{field="verificataDa" legend="Verificata da"}
::save{label="Registra l'esclusione"}
::/form

::if-any{path="esclusioni"}
::list{path="esclusioni" deletable editform="modEsclusione"}
**{interessato>personale.cognome}** — {categoria} ({riferimento})
::/list
::/if-any

::/page

::page{title="Servizio" icon="clock"}

# Servizio

La **continuità nella scuola di attuale titolarità** non si dichiara: si ricava dalla
data di titolarità, un anno per ogni anno scolastico fino a quello di riferimento. È
la funzione che fa risparmiare più tempo di ogni altra, ed è anche quella che toglie
l'errore più frequente — l'anzianità che nessuno ha aggiornato.

Si dichiara soltanto il resto: il pre-ruolo, il servizio in altre scuole, quello in
altro ruolo, la sede disagiata.

Anno scolastico di riferimento — l'anno in cui inizia:

::number-field[annoRiferimento]{value="2026" min="1980" max="2100"}
Giorni che valgono un anno intero:

::number-field[giorniPerAnno]{value="180" min="1" max="366"}

Un periodo dichiarato vale **un anno intero** se raggiunge
:value[giorniPerAnno]{ref="#giorniPerAnno"} giorni, altrimenti zero. È la regola
predefinita, ed è dichiarata qui perché è una scelta: la pagina *Decisioni* dice
perché.

::form{path="servizi-aggiunti" id="modServizio"}
::input{field="interessato" type="ref" path="personale" label="cognome" legend="Interessato" required}
::input{field="tipo" legend="Tipo di servizio" required pattern="preruolo|altra-scuola|altro-ruolo|disagiata" message="preruolo, altra-scuola, altro-ruolo, disagiata"}
::input{field="anno" type="number" legend="Anno scolastico (l'anno in cui inizia)" required min="1960" max="2100"}
::input{field="scuola" legend="Scuola o amministrazione"}
::input{field="giorni" type="number" legend="Giorni di servizio" min="0" max="366" required}
::input{field="note" legend="Note"}
::save{label="Registra il periodo"}
::/form

::if-any{path="servizi-aggiunti"}
::table{path="servizi-aggiunti" search deletable editform="modServizio" sort="anno" dir="desc" filters="tipo"}
::column{field="interessato" label="Interessato"}
::column{field="tipo" label="Tipo"}
::column{field="anno" label="Anno" align="end"}
::column{field="scuola" label="Scuola"}
::column{field="giorni" label="Giorni" align="end"}
::/table
::/if-any

## Ricostruisci il servizio

::python{data="servizi-aggiunti,personale" params="annoRiferimento,giorniPerAnno" writes="servizi" manual}
```python
def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

ANNO = intero(params.get("annoRiferimento"), 2026)
SOGLIA = max(1, intero(params.get("giorniPerAnno"), 180))

result = []

# La continuità, derivata. Un anno per ogni anno scolastico dalla titolarità
# all'anno di riferimento escluso: chi è titolare dal 2016 e siamo al 2026 ha
# dieci anni, e nessuno ha dovuto ricordarsene.
for persona in data["personale"]:
    inizio = (persona.get("dataTitolarita") or "")[:4]
    if not inizio.isdigit():
        continue
    for anno in range(int(inizio), ANNO):
        result.append({
            "id": "s-cont-%s-%d" % (persona["id"], anno),
            "interessato": persona["id"], "tipo": "continuita", "anno": str(anno),
            "scuola": "questa scuola", "giorni": str(SOGLIA), "anni": "1",
            "origine": "derivato", "note": "",
        })

# Il dichiarato. Un periodo che non raggiunge la soglia non vale un anno: vale
# zero, e resta in elenco perché è stato dichiarato.
scartati = 0
for riga in data["servizi-aggiunti"]:
    giorni = intero(riga.get("giorni"), 0)
    vale = 1 if giorni >= SOGLIA else 0
    if vale == 0:
        scartati += 1
    result.append({
        "id": riga.get("id", ""),
        "interessato": riga.get("interessato", ""),
        "tipo": riga.get("tipo", ""),
        "anno": str(intero(riga.get("anno"), 0)),
        "scuola": riga.get("scuola", ""),
        "giorni": str(giorni),
        "anni": str(vale),
        "origine": "dichiarato",
        "note": riga.get("note", ""),
    })

derivati = sum(1 for r in result if r["origine"] == "derivato")
print("%d periodi: %d derivati dalla titolarità, %d dichiarati." % (len(result), derivati, len(result) - derivati))
if scartati:
    print("%d periodi dichiarati sotto i %d giorni: valgono zero anni." % (scartati, SOGLIA))
```
::/python

::if-any{path="servizi"}
::table{path="servizi" search filters="tipo,origine" sort="anno" dir="desc" page-size="15"}
::column{field="interessato" label="Interessato"}
::column{field="tipo" label="Tipo"}
::column{field="anno" label="Anno" align="end"}
::column{field="anni" label="Vale" align="end"}
::column{field="origine" label="Origine"}
::/table
::/if-any

::/page

::page{title="Dichiarazioni" icon="file-add"}

# Dichiarazioni

Ogni riga è **una voce dichiarata da una persona**: quale voce, in che quantità, con
quali dati. La dichiarazione sostitutiva ai sensi del DPR 445/2000 è la spunta in
fondo: senza, la riga resta ma l'istruttoria la vede come incompleta.

::form{path="dichiarazioni-aggiunte" id="modDichiarazione"}
::input{field="interessato" type="ref" path="personale" label="cognome" legend="Interessato" required}
::input{field="voce" type="ref" path="tabella" label="descrizione" legend="Voce della tabella" required}
::input{field="quantita" type="number" legend="Quantità" value="1" min="0" max="99" required help="Quanti figli, quanti master. Per una voce fissa, 1."}
::input{field="dettaglio" legend="Dati specifici" help="Date, denominazioni, sedi: quello che serve a chi verifica."}
::input{field="documentazione" legend="Documentazione allegata" help="Estremi del documento, non il documento."}
::input{field="autodichiarazione" type="checkbox" legend="Dichiarazione sostitutiva resa"}
::save{label="Registra la dichiarazione"}
::/form

::if-any{path="dichiarazioni-aggiunte"}
::table{path="dichiarazioni-aggiunte" search deletable editform="modDichiarazione" page-size="15"}
::column{field="interessato" label="Interessato"}
::column{field="voce" label="Voce"}
::column{field="quantita" label="Qtà" align="end"}
::column{field="dettaglio" label="Dettaglio"}
::/table
::/if-any

## Riporto dall'anno precedente

Il riporto prende dall'archivio le voci **permanenti** — un dottorato non si
ridichiara ogni anno — e lascia cadere tutte le altre, che vanno riconfermate. Le
esigenze di famiglia scadono per definizione: un figlio di cinque anni l'anno scorso
può averne sei adesso, e nessun programma può saperlo al posto della persona.

::python{data="dichiarazioni-aggiunte,archivio,tabella" writes="dichiarazioni" manual}
```python
tabella = {v["id"]: v for v in data["tabella"]}
result = []
viste = set()

campi = ["interessato", "voce", "quantita", "dettaglio", "documentazione",
         "autodichiarazione"]

for riga in data["dichiarazioni-aggiunte"]:
    nuova = {"id": riga.get("id", ""), "origine": "quest'anno"}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)
    viste.add((nuova["interessato"], nuova["voce"]))

riportate, scadute = 0, 0
for riga in data["archivio"]:
    chiave = (riga.get("interessato", ""), riga.get("voce", ""))
    if chiave in viste:
        continue
    voce = tabella.get(riga.get("voce", ""))
    if voce is None:
        continue
    if (voce.get("permanente") or "").strip().lower() not in ("true", "1", "yes", "si", "sì"):
        scadute += 1
        continue
    nuova = {"id": "d-rip-%s-%s" % chiave, "origine": "riportata"}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)
    viste.add(chiave)
    riportate += 1

print("%d dichiarazioni: %d di quest'anno, %d riportate dall'archivio."
      % (len(result), len(result) - riportate, riportate))
if scadute:
    print("%d voci dell'anno scorso NON sono permanenti: vanno riconfermate." % scadute)
```
::/python

::if-any{path="dichiarazioni"}
:count{path="dichiarazioni"} dichiarazioni in istruttoria.

::table{path="dichiarazioni" search filters="origine" page-size="15"}
::column{field="interessato" label="Interessato"}
::column{field="voce" label="Voce"}
::column{field="quantita" label="Qtà" align="end"}
::column{field="origine" label="Origine"}
::/table
::/if-any

## Archivia il procedimento

Da premere **a procedimento chiuso**: fotografa le dichiarazioni di quest'anno
nell'archivio, che è quello da cui il riporto pescherà l'anno prossimo.

::python{data="dichiarazioni" writes="archivio" manual}
```python
result = []
for riga in data["dichiarazioni"]:
    result.append({
        "id": "a-" + riga.get("id", ""),
        "interessato": riga.get("interessato", ""),
        "voce": riga.get("voce", ""),
        "quantita": riga.get("quantita", ""),
        "dettaglio": riga.get("dettaglio", ""),
        "documentazione": riga.get("documentazione", ""),
        "autodichiarazione": riga.get("autodichiarazione", ""),
    })
print("Archiviate %d dichiarazioni." % len(result))
```
::/python

::/page

::page{title="Istruttoria" icon="check-box"}

# Istruttoria

La verifica non modifica la dichiarazione: la **annota**. Così resta scritto che cosa
aveva dichiarato la persona e che cosa ha riconosciuto la scuola, che è esattamente
ciò che serve quando arriva un reclamo.

::form{path="verifiche" id="modVerifica"}
::input{field="dichiarazione" type="ref" path="dichiarazioni" label="voce" legend="Dichiarazione" required}
::input{field="esito" legend="Esito" required pattern="confermata|rettificata|respinta" message="confermata, rettificata oppure respinta"}
::input{field="quantitaRettificata" type="number" legend="Quantità riconosciuta" min="0" max="99" help="Solo se rettificata."}
::input{field="motivazione" legend="Motivazione" help="Obbligatoria di fatto: senza, il prospetto non regge un reclamo."}
::input{field="verificataDa" legend="Verificata da"}
::save{label="Registra la verifica"}
::/form

::if-any{path="verifiche"}
::table{path="verifiche" search deletable editform="modVerifica" filters="esito" page-size="15"}
::column{field="dichiarazione" label="Dichiarazione"}
::column{field="esito" label="Esito"}
::column{field="quantitaRettificata" label="Riconosciuta" align="end"}
::column{field="motivazione" label="Motivazione"}
::/table
::/if-any

## Anomalie

Il controllo non giudica: segnala le cose che, se restano così, diventano un reclamo.

::python{data="dichiarazioni,servizi,tabella,personale" writes="anomalie" manual}
```python
def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

tabella = {v["id"]: v for v in data["tabella"]}
persone = {p["id"]: p for p in data["personale"]}
result = []

def segnala(interessato, tipo, dettaglio):
    result.append({
        "id": "an-%d" % (len(result) + 1),
        "interessato": persone.get(interessato, {}).get("cognome", interessato),
        "tipo": tipo, "dettaglio": dettaglio,
    })

# 1. Periodi di servizio sovrapposti: lo stesso anno dichiarato due volte.
per_persona = {}
for s in data["servizi"]:
    if s.get("origine") != "dichiarato":
        continue
    per_persona.setdefault(s.get("interessato", ""), []).append(s)
for chi, righe in per_persona.items():
    visti = {}
    for s in righe:
        anno = s.get("anno", "")
        if anno in visti:
            segnala(chi, "servizio sovrapposto",
                    "l'anno %s è dichiarato due volte (%s e %s)"
                    % (anno, visti[anno], s.get("scuola", "")))
        visti[anno] = s.get("scuola", "")

# 2. La dichiarazione di una voce di un profilo che non è il suo.
# 3. Quantità fuori scala per una voce fissa.
# 4. Dichiarazione sostitutiva mancante.
for d in data["dichiarazioni"]:
    voce = tabella.get(d.get("voce", ""))
    persona = persone.get(d.get("interessato", ""))
    if voce is None:
        segnala(d.get("interessato", ""), "voce inesistente",
                "la voce dichiarata non è più in tabella")
        continue
    if persona is not None:
        atteso = "ata" if persona.get("profilo") == "ata" else "docenti"
        if voce.get("profilo") not in ("", atteso):
            segnala(d.get("interessato", ""), "profilo sbagliato",
                    "%s è una voce del profilo %s" % (voce.get("codice"), voce.get("profilo")))
    if voce.get("tipo") == "fisso" and intero(d.get("quantita"), 1) > 1:
        segnala(d.get("interessato", ""), "quantità fuori scala",
                "%s è una voce fissa, dichiarata %s volte" % (voce.get("codice"), d.get("quantita")))
    if not vero(d.get("autodichiarazione")):
        segnala(d.get("interessato", ""), "dichiarazione sostitutiva mancante",
                voce.get("codice", ""))

# 5. La stessa voce dichiarata due volte dalla stessa persona.
visto = set()
for d in data["dichiarazioni"]:
    chiave = (d.get("interessato", ""), d.get("voce", ""))
    if chiave in visto:
        segnala(chiave[0], "voce ripetuta",
                tabella.get(chiave[1], {}).get("codice", chiave[1]))
    visto.add(chiave)

print("%d anomalie." % len(result))
for tipo in sorted(set(r["tipo"] for r in result)):
    print("  %s: %d" % (tipo, sum(1 for r in result if r["tipo"] == tipo)))
```
::/python

::if-any{path="anomalie"}
::table{path="anomalie" search filters="tipo" page-size="20"}
::column{field="interessato" label="Interessato"}
::column{field="tipo" label="Anomalia"}
::column{field="dettaglio" label="Dettaglio"}
::/table
::/if-any

::if-empty{path="anomalie"}
Nessuna anomalia — o il controllo non è ancora stato eseguito.
::/if-empty

::/page

::page{title="Calcolo" icon="data-check"}

# Calcolo e graduatoria

Due blocchi, in quest'ordine. Il primo produce il **prospetto**: una riga per ogni
punto attribuito, con la voce, la quantità, il punteggio unitario, il massimale
applicato e il riferimento normativo. Il secondo somma il prospetto e ordina.

## 1. Il prospetto

::python{data="tabella,personale,dichiarazioni,servizi,verifiche" params="giorniPerAnno" writes="prospetto" manual}
```python
def numero(v, d=0.0):
    try:
        return float(str(v).strip().replace(",", "."))
    except (TypeError, ValueError):
        return d

def intero(v, d=0):
    return int(numero(v, d))

tabella = [v for v in data["tabella"] if v.get("tipo") != "massimale-sezione"]
per_id = {v["id"]: v for v in tabella}
persone = {p["id"]: p for p in data["personale"]}

# L'ultima verifica per dichiarazione vince: l'istruttoria può tornare su una riga.
verifica = {}
for v in data["verifiche"]:
    verifica[v.get("dichiarazione", "")] = v

# Anni di servizio per persona e per tipo, dai periodi ricostruiti.
anni = {}
for s in data["servizi"]:
    chi = s.get("interessato", "")
    anni.setdefault(chi, {}).setdefault(s.get("tipo", ""), 0)
    anni[chi][s.get("tipo", "")] += intero(s.get("anni"), 0)

TIPO_SERVIZIO = {
    "per-anno-continuita": "continuita",
    "per-anno-ruolo": "altra-scuola",
    "per-anno-preruolo": "preruolo",
    "per-anno-disagiata": "disagiata",
}

result = []
def riga(persona, voce, quantita, motivo):
    unitario = numero(voce.get("punti"), 0.0)
    lordo = unitario * quantita
    tetto = voce.get("massimale", "")
    applicato = ""
    if str(tetto).strip() != "":
        limite = numero(tetto, 0.0)
        if lordo > limite:
            lordo = limite
            applicato = str(limite)
    result.append({
        "id": "pr-%d" % (len(result) + 1),
        "interessato": persona["id"],
        "cognome": persona.get("cognome", ""),
        "nome": persona.get("nome", ""),
        "raggruppamento": persona.get("raggruppamento", ""),
        "codice": voce.get("codice", ""),
        "sezione": voce.get("sezione", ""),
        "sezioneNome": voce.get("sezioneNome", ""),
        "descrizione": voce.get("descrizione", ""),
        "quantita": ("%g" % quantita),
        "unitario": ("%g" % unitario),
        "punti": ("%.2f" % lordo),
        "massimale": applicato,
        "riferimento": voce.get("riferimento", ""),
        "motivo": motivo,
    })

# Le voci di servizio: la quantità non la dichiara nessuno, la contano i periodi.
for persona in data["personale"]:
    atteso = "ata" if persona.get("profilo") == "ata" else "docenti"
    for voce in tabella:
        if voce.get("profilo") not in ("", atteso):
            continue
        tipo = TIPO_SERVIZIO.get(voce.get("tipo"))
        if tipo is None:
            continue
        quantita = anni.get(persona["id"], {}).get(tipo, 0)
        if quantita <= 0:
            continue
        riga(persona, voce, quantita, "servizio ricostruito: %d anni" % quantita)

# Le voci dichiarate, con la quantità che l'istruttoria ha riconosciuto.
respinte = 0
for d in data["dichiarazioni"]:
    voce = per_id.get(d.get("voce", ""))
    persona = persone.get(d.get("interessato", ""))
    if voce is None or persona is None:
        continue
    if voce.get("tipo") in TIPO_SERVIZIO:
        continue  # il servizio non si dichiara: si conta
    quantita = numero(d.get("quantita"), 1.0)
    motivo = "dichiarata"
    v = verifica.get(d.get("id", ""))
    if v is not None:
        if v.get("esito") == "respinta":
            respinte += 1
            continue
        if v.get("esito") == "rettificata":
            quantita = numero(v.get("quantitaRettificata"), quantita)
            motivo = "rettificata: " + (v.get("motivazione") or "")
        else:
            motivo = "confermata"
    if voce.get("tipo") == "fisso":
        quantita = 1.0 if quantita > 0 else 0.0
    if quantita <= 0:
        continue
    riga(persona, voce, quantita, motivo)

# I massimali di sezione, applicati per persona: la riga eccedente resta scritta e
# il taglio è una riga sua, perché un punto tolto senza dirlo è un reclamo.
tetti = {}
for v in data["tabella"]:
    if v.get("tipo") == "massimale-sezione":
        tetti[(v.get("profilo"), v.get("sezione"))] = numero(v.get("punti"), 0.0)

tagli = []
for persona in data["personale"]:
    atteso = "ata" if persona.get("profilo") == "ata" else "docenti"
    for (profilo, sezione), tetto in tetti.items():
        if profilo not in ("", atteso):
            continue
        righe = [r for r in result
                 if r["interessato"] == persona["id"] and r["sezione"] == sezione]
        somma = sum(numero(r["punti"]) for r in righe)
        if somma > tetto:
            tagli.append({
                "id": "pr-max-%s-%s" % (persona["id"], sezione),
                "interessato": persona["id"],
                "cognome": persona.get("cognome", ""),
                "nome": persona.get("nome", ""),
                "raggruppamento": persona.get("raggruppamento", ""),
                "codice": "MAX-" + sezione,
                "sezione": sezione,
                "sezioneNome": righe[0]["sezioneNome"] if righe else "",
                "descrizione": "Massimale della sezione %s" % sezione,
                "quantita": "1", "unitario": ("%g" % tetto),
                "punti": ("%.2f" % (tetto - somma)),
                "massimale": ("%g" % tetto),
                "riferimento": "tabella di valutazione, massimale di sezione",
                "motivo": "eccedenza di %.2f punti riportata al massimale" % (somma - tetto),
            })
result.extend(tagli)

print("%d righe di prospetto per %d persone." % (len(result), len(data["personale"])))
if respinte:
    print("%d dichiarazioni respinte in istruttoria: non entrano nel calcolo." % respinte)
if tagli:
    print("%d massimali di sezione applicati." % len(tagli))
```
::/python

## 2. La graduatoria

**Si legge dal basso.** L'ordine è **crescente**: chi ha il punteggio più basso è il
primo individuabile come soprannumerario. È controintuitivo, è la fonte di errore più
comune in questa materia, e per questo la colonna della posizione si chiama
*posizione*, non *classifica*.

::python{data="prospetto,personale,esclusioni" writes="graduatoria" manual}
```python
def numero(v, d=0.0):
    try:
        return float(str(v).strip().replace(",", "."))
    except (TypeError, ValueError):
        return d

esclusi = {}
for e in data["esclusioni"]:
    esclusi[e.get("interessato", "")] = e.get("categoria", "")

punti = {}
for r in data["prospetto"]:
    chi = r.get("interessato", "")
    punti.setdefault(chi, {"I": 0.0, "II": 0.0, "III": 0.0})
    sezione = r.get("sezione", "")
    if sezione in punti[chi]:
        punti[chi][sezione] += numero(r.get("punti"))

righe = []
for persona in data["personale"]:
    chi = persona["id"]
    sezioni = punti.get(chi, {"I": 0.0, "II": 0.0, "III": 0.0})
    totale = sezioni["I"] + sezioni["II"] + sezioni["III"]
    righe.append({
        "interessato": chi,
        "cognome": persona.get("cognome", ""),
        "nome": persona.get("nome", ""),
        "profilo": persona.get("profilo", ""),
        "raggruppamento": persona.get("raggruppamento", ""),
        "dataTitolarita": persona.get("dataTitolarita", ""),
        "sezioneI": "%.2f" % sezioni["I"],
        "sezioneII": "%.2f" % sezioni["II"],
        "sezioneIII": "%.2f" % sezioni["III"],
        "totale": "%.2f" % totale,
        "_totale": totale,
        "escluso": esclusi.get(chi, ""),
    })

result = []
for gruppo in sorted(set(r["raggruppamento"] for r in righe)):
    dentro = [r for r in righe if r["raggruppamento"] == gruppo and not r["escluso"]]
    fuori = [r for r in righe if r["raggruppamento"] == gruppo and r["escluso"]]
    # Crescente. A parità, chi è titolare da meno tempo viene prima: è arrivato per
    # ultimo. Due ordinamenti, non uno con una chiave astuta: il secondo è stabile,
    # quindi il primo sopravvive dove i totali sono uguali, e si legge.
    dentro.sort(key=lambda r: r["dataTitolarita"], reverse=True)
    dentro.sort(key=lambda r: r["_totale"])
    for i, r in enumerate(dentro, start=1):
        riga = dict(r)
        riga["id"] = "g-%s-%03d" % (gruppo[:4].lower().replace(" ", ""), i)
        riga["posizione"] = str(i)
        del riga["_totale"]
        result.append(riga)
    for j, r in enumerate(fuori, start=1):
        riga = dict(r)
        riga["id"] = "g-%s-esc%02d" % (gruppo[:4].lower().replace(" ", ""), j)
        riga["posizione"] = "—"
        del riga["_totale"]
        result.append(riga)

print("%d raggruppamenti, %d in graduatoria, %d esclusi."
      % (len(set(r["raggruppamento"] for r in righe)),
         sum(1 for r in result if r["posizione"] != "—"),
         sum(1 for r in result if r["posizione"] == "—")))
for gruppo in sorted(set(r["raggruppamento"] for r in result)):
    primi = [r for r in result if r["raggruppamento"] == gruppo and r["posizione"] == "1"]
    if primi:
        print("  %s: primo individuabile %s (%s punti)"
              % (gruppo, primi[0]["cognome"], primi[0]["totale"]))
```
::/python

::/page

::page{title="Graduatoria" icon="list-numbered"}

# La graduatoria

**Ordine crescente**: la posizione 1 è il primo individuabile come soprannumerario.
Gli esclusi sono in coda, senza posizione.

::if-empty{path="graduatoria"}
Non è ancora stata calcolata: i due blocchi sono nella pagina *Calcolo*.
::/if-empty

::if-any{path="graduatoria"}
::table{path="graduatoria" search filters="raggruppamento,profilo" sort="raggruppamento" page-size="30"}
::column{field="posizione" label="Pos." align="end"}
::column{field="raggruppamento" label="Raggruppamento"}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="sezioneI" label="Sez. I" align="end"}
::column{field="sezioneII" label="Sez. II" align="end"}
::column{field="sezioneIII" label="Sez. III" align="end"}
::column{field="totale" label="Totale" align="end"}
::column{field="escluso" label="Esclusione"}
::/table

## Come sono distribuiti i punteggi

::chart-bar{data="graduatoria" x="cognome" y="totale" height="20rem"}

## Chiedi alla graduatoria

Una domanda a parole sui dati che hai davanti. Il modello non vede le righe: produce
un piano di interrogazione — filtri, raggruppamento, una aggregazione — e il piano
gira qui. Sotto la risposta c'è scritto il piano, perché una risposta di cui non si
vede la domanda non si può controllare.

::ai-query{data="graduatoria" into="risposta-graduatoria" placeholder="Qual è il punteggio medio per raggruppamento?"}

::if-any{path="risposta-graduatoria"}
::table{path="risposta-graduatoria"}
::column{field="raggruppamento" label="Gruppo"}
::column{field="valore" label="Valore" align="end"}
::/table
::/if-any
::/if-any

::/page

::page{title="Prospetti" icon="print"}

# Prospetti individuali e stampe

## Il prospetto di una persona

Riga per riga, ogni punto con la sua giustificazione. **È il documento che risponde a
un reclamo**: si stampa e si allega.

::textfield[interessatoSel]{label="Id dell'interessato" placeholder="p-01"}

Oppure usa il pulsante in fondo alla pagina, che li stampa tutti.

::columns{min="20rem" gap="m" id="prospettoStampa"}
### Prospetto individuale

::list{path="prospetto" filter="interessato=#interessatoSel" limit="1"}
**{cognome} {nome}** — {raggruppamento}
::/list

::table{path="prospetto" filter="interessato=#interessatoSel" sort="codice"}
::column{field="codice" label="Voce"}
::column{field="descrizione" label="Descrizione"}
::column{field="quantita" label="Qtà" align="end"}
::column{field="unitario" label="Unit." align="end"}
::column{field="punti" label="Punti" align="end"}
::column{field="massimale" label="Max" align="end"}
::column{field="motivo" label="Motivo"}
::column{field="riferimento" label="Riferimento"}
::/table

**Totale: :sum{path="prospetto" field="punti" decimals="2"}** — calcolato sulle righe
mostrate qui sopra.
::/columns

::print{target="prospettoStampa" repeat="personale" landscape label="Stampa il prospetto di ogni interessato"}

## Il documento pubblicabile

Cognome, nome, punteggi e posizione. **Niente altro**: né le voci dichiarate, né le
esigenze di famiglia, né la categoria di esclusione.

::columns{min="24rem" id="graduatoriaPubblica"}
### Graduatoria interna d'istituto — versione pubblicabile

::table{path="graduatoria" sort="raggruppamento"}
::column{field="posizione" label="Pos." align="end"}
::column{field="raggruppamento" label="Raggruppamento"}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="totale" label="Punteggio" align="end"}
::/table

Graduatoria formata in ordine crescente di punteggio ai fini dell'individuazione del
personale soprannumerario. Avverso la presente graduatoria è ammesso reclamo nei
termini stabiliti dall'ordinanza ministeriale sulla mobilità.
::/columns

::print{target="graduatoriaPubblica" landscape label="Stampa la graduatoria pubblicabile"}

::/page

::page{title="Reclami" icon="comment"}

# Reclami

::form{path="reclami" id="modReclamo"}
::input{field="interessato" type="ref" path="personale" label="cognome" legend="Interessato" required}
::input{field="data" type="date" legend="Data del reclamo" required}
::input{field="vociContestate" legend="Voci contestate" help="I codici, separati da virgola: D-II-2, D-III-3"}
::input{field="motivazione" legend="Motivazione" required}
::input{field="esito" legend="Esito" pattern="accolto|accolto in parte|respinto|" message="accolto, accolto in parte, respinto"}
::input{field="dataEsito" type="date" legend="Data dell'esito"}
::input{field="variazione" type="number" legend="Variazione di punteggio" step="0.01"}
::save{label="Registra il reclamo"}
::/form

::if-any{path="reclami"}
::table{path="reclami" search deletable editform="modReclamo" filters="esito" sort="data" dir="desc"}
::column{field="interessato" label="Interessato"}
::column{field="data" label="Data"}
::column{field="vociContestate" label="Voci"}
::column{field="esito" label="Esito"}
::column{field="variazione" label="Δ punti" align="end"}
::/table

Reclami: **:count{path="reclami"}**, variazione complessiva
**:sum{path="reclami" field="variazione" decimals="2"}** punti.
::/if-any

::if-empty{path="reclami"}
Nessun reclamo registrato.
::/if-empty

## Come si lavora un reclamo

1. Si stampa il **prospetto individuale** della persona: c'è dentro ogni punto con il
   suo perché.
2. Se il reclamo è fondato, si registra una **verifica** sulla dichiarazione
   contestata — rettificata, con la motivazione.
3. Si rieseguono i due blocchi del **Calcolo**. Il prospetto e la graduatoria si
   rifanno da soli.
4. Si registra qui l'esito e la variazione.

La versione precedente non si perde se, prima di ricalcolare, si archivia: è quello
che fa il pulsante *Archivia* nella pagina Dichiarazioni.

::/page

::page{title="Decisioni" icon="info"}

# Decisioni prese, e perché

Le regole di questa materia hanno punti ambigui. Dove ce n'è uno, qui non si
indovina: si sceglie un comportamento predefinito, lo si scrive, e lo si rende
modificabile.

**La tabella non è normativa.** Quella seminata è un esempio realistico. Va
confrontata voce per voce con il CCNI vigente prima di formare una graduatoria vera.
Si corregge dalla pagina *Tabella*, senza toccare il programma.

**Un periodo dichiarato vale un anno intero o zero.** La soglia è
:value[giorniPerAnno]{ref="#giorniPerAnno"} giorni ed è modificabile nella pagina
*Servizio*. La proporzionalità non è implementata: dove serve, si dichiarano periodi
separati.

**La continuità si deriva dalla titolarità.** Chi è titolare dal 2016 e siamo al 2026
ha dieci anni di continuità. Le interruzioni — aspettative, comandi — non sono
modellate: vanno gestite dichiarando il periodo come *altra-scuola* o *altro-ruolo* e
correggendo in istruttoria.

**A parità di punteggio viene prima chi è titolare da meno tempo.** È la scelta
predefinita: a parità, il soprannumerario individuato per primo è chi è arrivato per
ultimo. I criteri di preferenza del CCNI sono più articolati; questa è una scelta
dichiarata, non una lettura della norma.

**Il massimale di sezione produce una riga di taglio.** Il punto tolto resta scritto,
con l'eccedenza. Un punteggio ridotto senza dirlo è la prima cosa che diventa un
reclamo.

**Le esigenze di famiglia non si riportano.** Nessuna voce della sezione II è
permanente: l'età dei figli cambia, e nessun programma può saperlo al posto della
persona. Vanno riconfermate ogni anno.

**Nessun dato sanitario, in nessun campo.** L'esclusione porta la categoria normativa
e nulla di più, e il documento pubblicabile non riporta neppure quella.

**Non c'è controllo d'accesso dentro il documento.** Chi apre questa app la vede
tutta. La separazione dei ruoli, dove serve, è quella degli **spazi condivisi** della
piattaforma — lettore o redattore — non una regola scritta qui dentro.

::/page
