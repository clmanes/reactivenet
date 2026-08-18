---
appId: inclusione
title: Inclusione
description: "PEI e PDP redatti in collaborazione: modelli modificabili per ordine di scuola, contributo per disciplina, obiettivi e verifiche, incontri del GLO, firme, estratto operativo per il consiglio di classe e riepiloghi d'istituto senza nominativi."
icon: accessibility
lang: it
version: "1.0"
author: ReactiveNET
date: "2026-08-13"
---

::page{title="Avvio" icon="accessibility"}

# Inclusione — PEI e PDP

Redazione, verifica e archiviazione del **Piano Educativo Individualizzato** per gli
alunni con disabilità certificata e del **Piano Didattico Personalizzato** per gli
alunni con DSA e altri bisogni educativi speciali. Con gli incontri del GLO, le
scadenze, le firme e i riepiloghi d'istituto.

## La prima cosa da dire

Questa app tratta **dati relativi alla salute di minori**. È la categoria di rischio
più alta che una scuola gestisca, e qui la protezione non è un contorno: è ciò che ha
deciso la forma del programma.

| Regola | Come è fatta rispettare |
| --- | --- |
| Nessun dato esce dal dispositivo | Tutto vive in IndexedDB, in questo browser. Nessuna chiamata di rete che non sia richiesta esplicitamente da una direttiva |
| **Nessuna diagnosi, in nessun campo** | Della certificazione si registrano ente, data, scadenza e nient'altro. Non esiste un campo referto, non esiste un allegato sanitario |
| L'AI non formula ipotesi sull'alunno | L'unica direttiva AI qui dentro è `::ai-rewrite`, che **riscrive un testo già scritto da un docente**. Non classifica, non prevede, non valuta |
| I riepiloghi d'istituto non hanno nomi | Sono costruiti sul `codice` interno e contano, non elencano |
| L'estratto per il consiglio di classe non porta il quadro funzionale | È una vista sua, con misure, strumenti e criteri di valutazione e nulla di più |

## E la cosa da dire subito dopo

**Il controllo d'accesso per ruolo non è dentro questo documento.** Chi apre l'app la
vede tutta. La separazione — il docente curricolare che compila la sua riga senza
vedere il resto — qui è ottenuta **per costruzione della pagina**: la pagina *Misure*
contiene solo la tabella per disciplina, e la si condivide da sola.

La separazione *forzata* è quella degli **spazi condivisi** della piattaforma
(lettore / redattore), ed è una proprietà del server, non di questo file. La pagina
*Decisioni* lo dice per esteso: prima di usare questa app su dati veri va deciso chi
apre che cosa, e non è una decisione che il documento possa prendere.

## Chi possiede che cosa

| Padrone | Collezioni |
| --- | --- |
| Tu, con un modulo | `alunni-aggiunti`, `modelli-aggiunti`, `banca-aggiunte`, `contenuti`, `misure`, `obiettivi`, `glo`, `firme`, `risorse` |
| Un blocco | `alunni`, `modelli`, `banca`, `stato-documenti`, `somiglianze`, `riepilogo` |

## Semina l'esempio

Dodici alunni **inventati**, quattro classi, i modelli nazionali per ordine di scuola
in forma di sezioni, e una banca di formulazioni ricorrenti. Premi i tre pulsanti.

::python{data="alunni-aggiunti" writes="alunni" manual}
```python
# Dodici alunni inventati. Nessun dato reale, nemmeno parziale: i nomi sono di
# fantasia e le classi non esistono. Della certificazione c'è l'ente, la data e la
# scadenza — e NIENTE di clinico, perché non c'è dove metterlo.
righe = [
    ("AL-001", "Bianchi", "Aurora", "1A", "secondaria I grado", "PEI", "ASL 3", "2024-03-12", "2027-03-12", "true", "assistente all'autonomia", "9", "true"),
    ("AL-002", "Conti", "Elia", "1A", "secondaria I grado", "PDP", "ASL 3", "2025-01-20", "", "false", "", "0", "false"),
    ("AL-003", "Rossi", "Nina", "1A", "secondaria I grado", "PDP", "specialista privato", "2024-11-05", "", "false", "", "0", "false"),
    ("AL-004", "Verdi", "Tommaso", "2A", "secondaria I grado", "PEI", "ASL 3", "2023-05-30", "2026-05-30", "true", "educatore", "12", "true"),
    ("AL-005", "Gallo", "Sofia", "2A", "secondaria I grado", "PDP", "ASL 3", "2025-09-15", "", "false", "", "0", "false"),
    ("AL-006", "Ferri", "Matteo", "2A", "secondaria I grado", "altro BES", "consiglio di classe", "2025-10-02", "2026-06-30", "false", "", "0", "false"),
    ("AL-007", "Sala", "Giada", "3A", "secondaria I grado", "PEI", "ASL 3", "2022-09-01", "2026-09-01", "true", "assistente alla comunicazione", "15", "true"),
    ("AL-008", "Moretti", "Leo", "3A", "secondaria I grado", "PDP", "ASL 3", "2024-02-14", "", "false", "", "0", "false"),
    ("AL-009", "Bruno", "Alice", "4B", "primaria", "PEI", "ASL 3", "2024-06-18", "2027-06-18", "true", "educatore", "11", "false"),
    ("AL-010", "Longo", "Diego", "4B", "primaria", "PDP", "ASL 3", "2025-04-09", "", "false", "", "0", "false"),
    ("AL-011", "Marchetti", "Emma", "4B", "primaria", "PEI", "ASL 3", "2021-10-22", "2025-10-22", "true", "assistente all'autonomia", "8", "true"),
    ("AL-012", "Villa", "Noah", "4B", "primaria", "altro BES", "consiglio di classe", "2025-11-30", "2026-06-30", "false", "", "0", "false"),
]

result = []
for r in righe:
    result.append({
        "id": r[0].lower(), "codice": r[0], "cognome": r[1], "nome": r[2],
        "classe": r[3], "ordine": r[4], "percorso": r[5],
        "enteCertificazione": r[6], "dataCertificazione": r[7],
        "scadenzaCertificazione": r[8], "profiloFunzionamento": r[9],
        "figuraSupporto": r[10], "oreSupporto": r[11], "trasporto": r[12],
    })

campi = ["codice", "cognome", "nome", "classe", "ordine", "percorso",
         "enteCertificazione", "dataCertificazione", "scadenzaCertificazione",
         "profiloFunzionamento", "figuraSupporto", "oreSupporto", "trasporto"]
for riga in data["alunni-aggiunti"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

pei = sum(1 for a in result if a["percorso"] == "PEI")
print("%d alunni: %d con PEI, %d con PDP o altro BES."
      % (len(result), pei, len(result) - pei))
```
::/python

::python{data="modelli-aggiunti" writes="modelli" manual}
```python
# I modelli. NON sono cablati nel programma: sono righe, una per sezione, e si
# modificano dalla pagina Modelli. Un documento già approvato conserva la versione
# con cui è stato redatto, che è il motivo per cui la versione sta nella riga.
#
# Le dimensioni del PEI sono quelle della prospettiva bio-psico-sociale ICF; le
# sezioni del PDP sono quelle che quasi ogni istituto adotta. Vanno confrontate con
# il modello effettivamente deliberato dal collegio.
pei = [
    ("relazione", "Relazione, interazione, socializzazione", "Come l'alunno entra in relazione con adulti e compagni, e in quali contesti."),
    ("comunicazione", "Comunicazione e linguaggio", "Comprensione, produzione, modalità comunicative usate — anche non verbali."),
    ("autonomia", "Autonomia e orientamento", "Autonomia personale, sociale, negli spostamenti e nell'organizzazione del lavoro."),
    ("cognitiva", "Dimensione cognitiva, neuropsicologica e dell'apprendimento", "Attenzione, memoria, funzioni esecutive, strategie di apprendimento osservate."),
    ("contesto", "Osservazioni sul contesto", "Barriere e facilitatori nel contesto scolastico, non nell'alunno."),
    ("interventi", "Interventi sul contesto e strategie", "Che cosa cambia la scuola: spazi, tempi, materiali, organizzazione."),
    ("risorse", "Organizzazione delle risorse", "Ore di sostegno, assistenza, trasporto, sussidi e loro impiego."),
    ("verifica", "Verifica finale e proposte per l'anno successivo", "Che cosa ha funzionato, e le risorse proposte per l'anno prossimo."),
]
pdp = [
    ("funzionamento", "Funzionamento delle abilità strumentali", "Lettura, scrittura, calcolo: come si presentano nel lavoro scolastico."),
    ("apprendimento", "Caratteristiche del processo di apprendimento", "Tempi, modalità, punti di forza su cui si può costruire."),
    ("strategie", "Strategie e metodi didattici", "Che cosa fa il consiglio di classe in aula."),
    ("misure", "Misure dispensative e strumenti compensativi", "Compilata per disciplina nella pagina Misure."),
    ("valutazione", "Criteri e modalità di verifica e valutazione", "Come si verifica e come si valuta, disciplina per disciplina."),
    ("famiglia", "Impegni della famiglia", "Che cosa è concordato con la famiglia, in accordo con lei."),
]

result = []
for ordine in ["infanzia", "primaria", "secondaria I grado", "secondaria II grado"]:
    for i, (chiave, titolo, guida) in enumerate(pei, start=1):
        result.append({
            "id": "m-pei-%s-%s" % (ordine.replace(" ", "-").lower(), chiave),
            "tipo": "PEI", "ordine": ordine, "sezione": chiave, "titolo": titolo,
            "guida": guida, "ordinamento": str(i), "obbligatoria": "true",
            "versione": "2026.1",
        })
for i, (chiave, titolo, guida) in enumerate(pdp, start=1):
    result.append({
        "id": "m-pdp-%s" % chiave,
        "tipo": "PDP", "ordine": "", "sezione": chiave, "titolo": titolo,
        "guida": guida, "ordinamento": str(i), "obbligatoria": "true",
        "versione": "2026.1",
    })

campi = ["tipo", "ordine", "sezione", "titolo", "guida", "ordinamento",
         "obbligatoria", "versione"]
for riga in data["modelli-aggiunti"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d sezioni di modello: %d di PEI (quattro ordini), %d di PDP."
      % (len(result), sum(1 for m in result if m["tipo"] == "PEI"),
         sum(1 for m in result if m["tipo"] == "PDP")))
```
::/python

::python{data="banca-aggiunte" writes="banca" manual}
```python
# La banca serve a ridurre la digitazione, non a produrre documenti uguali. Il
# blocco delle somiglianze, nella pagina Redazione, dice quando ha smesso di
# servire a quello.
righe = [
    ("compensativo", "", "Sintesi vocale per i testi lunghi"),
    ("compensativo", "", "Mappe concettuali e schemi forniti in anticipo"),
    ("compensativo", "matematica", "Formulario e tavola pitagorica sempre disponibili"),
    ("compensativo", "matematica", "Calcolatrice per le operazioni non oggetto di verifica"),
    ("compensativo", "", "Tempi aggiuntivi, fino al 30 per cento"),
    ("compensativo", "", "Riduzione quantitativa, non qualitativa, del compito"),
    ("dispensativo", "", "Dispensa dalla lettura ad alta voce davanti alla classe"),
    ("dispensativo", "", "Dispensa dalla scrittura veloce sotto dettatura"),
    ("dispensativo", "", "Dispensa dallo studio mnemonico di elenchi e definizioni"),
    ("dispensativo", "lingua straniera", "Valutazione della produzione orale in luogo di quella scritta"),
    ("obiettivo", "relazione", "Partecipa a un'attività di piccolo gruppo per l'intera durata proposta"),
    ("obiettivo", "comunicazione", "Formula una richiesta all'adulto usando la modalità comunicativa concordata"),
    ("obiettivo", "autonomia", "Prepara il materiale della lezione successiva senza sollecito"),
    ("obiettivo", "cognitiva", "Porta a termine un compito in tre passaggi seguendo lo schema fornito"),
    ("strategia", "", "Anticipazione dei contenuti prima della lezione"),
    ("strategia", "", "Verifica programmata e concordata con l'alunno"),
    ("strategia", "", "Consegne una alla volta, verificate a voce"),
    ("valutazione", "", "Si valuta il contenuto e non la forma ortografica"),
    ("valutazione", "", "Si valutano i progressi rispetto al livello di partenza"),
]

result = []
for i, (tipo, ambito, testo) in enumerate(righe, start=1):
    result.append({
        "id": "b-%03d" % i, "tipo": tipo, "ambito": ambito, "testo": testo,
        "origine": "di serie",
    })

campi = ["tipo", "ambito", "testo"]
for riga in data["banca-aggiunte"]:
    nuova = {"id": riga.get("id", ""), "origine": "d'istituto"}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d formulazioni in banca." % len(result))
```
::/python

::/page

::page{title="Alunni" icon="user-group"}

# Alunni con bisogni educativi speciali

Della certificazione si registrano **ente, data e scadenza**. Non c'è un campo per la
diagnosi, e non ci sarà: se l'istituto ne ha bisogno, quella resta nel fascicolo
riservato, dove sta oggi.

::form{path="alunni-aggiunti" id="modAlunno"}
::input{field="codice" legend="Codice interno" required help="È il nome con cui l'alunno compare in ogni vista aggregata."}
::input{field="cognome" legend="Cognome" required}
::input{field="nome" legend="Nome" required}
::input{field="classe" legend="Classe" required}
::input{field="ordine" legend="Ordine di scuola" required pattern="infanzia|primaria|secondaria I grado|secondaria II grado" message="infanzia, primaria, secondaria I grado, secondaria II grado"}
::input{field="percorso" legend="Percorso" required pattern="PEI|PDP|altro BES" message="PEI, PDP oppure altro BES"}
::input{field="enteCertificazione" legend="Ente che ha rilasciato la certificazione"}
::input{field="dataCertificazione" type="date" legend="Data della certificazione"}
::input{field="scadenzaCertificazione" type="date" legend="Scadenza"}
::input{field="profiloFunzionamento" type="checkbox" legend="Profilo di funzionamento acquisito"}
::input{field="figuraSupporto" legend="Figura di supporto" help="assistente all'autonomia, assistente alla comunicazione, educatore"}
::input{field="oreSupporto" type="number" legend="Ore settimanali di supporto" min="0" max="40"}
::input{field="trasporto" type="checkbox" legend="Trasporto dedicato"}
::save{label="Salva"}
::/form

::if-any{path="alunni-aggiunti"}
::table{path="alunni-aggiunti" deletable editform="modAlunno" sort="codice"}
::column{field="codice" label="Codice"}
::column{field="cognome" label="Cognome"}
::column{field="classe" label="Classe"}
::column{field="percorso" label="Percorso"}
::/table
::/if-any

## In elenco: :count{path="alunni"}

::table{path="alunni" search filters="classe,percorso,ordine" sort="classe" page-size="20"}
::column{field="codice" label="Codice"}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="classe" label="Classe"}
::column{field="percorso" label="Percorso"}
::column{field="scadenzaCertificazione" label="Certificazione fino al"}
::column{field="oreSupporto" label="Ore" align="end"}
::/table

## Certificazioni: quando scadono

::calendar{path="alunni" field="scadenzaCertificazione" view="agenda" tooltip="{codice} — {classe}"}
**{codice}** {classe}
::/calendar

::/page

::page{title="Modelli" icon="template"}

# Modelli di PEI e PDP

I modelli **cambiano**: per norma, e per delibera del collegio. Sono righe, non
codice, e ogni sezione porta la sua versione — un documento già approvato resta
leggibile e ristampabile con il modello con cui fu redatto.

::form{path="modelli-aggiunti" id="modSezione"}
::input{field="tipo" legend="Tipo" required pattern="PEI|PDP" message="PEI oppure PDP"}
::input{field="ordine" legend="Ordine di scuola" help="Vuoto per il PDP, che non ne ha uno."}
::input{field="sezione" legend="Chiave della sezione" required help="Senza spazi: è il nome con cui i contenuti la citano."}
::input{field="titolo" legend="Titolo mostrato" required}
::input{field="guida" legend="Testo guida" help="Che cosa si scrive qui. È la riga che fa risparmiare più tempo di tutte."}
::input{field="ordinamento" type="number" legend="Ordine" min="1" max="99"}
::input{field="obbligatoria" type="checkbox" legend="Obbligatoria"}
::input{field="versione" legend="Versione" placeholder="2026.1"}
::save{label="Salva la sezione"}
::/form

::if-any{path="modelli-aggiunti"}
::table{path="modelli-aggiunti" deletable editform="modSezione" sort="ordinamento"}
::column{field="tipo" label="Tipo"}
::column{field="sezione" label="Sezione"}
::column{field="titolo" label="Titolo"}
::/table
::/if-any

## I modelli in uso

::table{path="modelli" search filters="tipo,ordine" sort="ordinamento" page-size="20"}
::column{field="tipo" label="Tipo"}
::column{field="ordine" label="Ordine"}
::column{field="ordinamento" label="N." align="end"}
::column{field="titolo" label="Sezione"}
::column{field="guida" label="Testo guida"}
::column{field="versione" label="Versione"}
::/table

::/page

::page{title="Redazione" icon="edit"}

# Redazione

Un documento è l'insieme dei suoi **contenuti**: una riga per sezione compilata, con
chi l'ha scritta e quando. Si compila una sezione alla volta, si salva, si riprende.

Anno scolastico in corso: **:value[annoScolastico]{ref="#annoScolastico"}**

::textfield[annoScolastico]{value="2026/2027"}

::form{path="contenuti" id="modContenuto"}
::input{field="alunno" type="ref" path="alunni" label="codice" legend="Alunno" required}
::input{field="anno" legend="Anno scolastico" required value="2026/2027"}
::input{field="tipo" legend="Tipo di documento" required pattern="PEI|PDP" message="PEI oppure PDP"}
::input{field="sezione" type="ref" path="modelli" label="titolo" legend="Sezione" required}
::input{field="testo" legend="Testo della sezione" required help="Scrivi in modo osservabile: che cosa si vede, in quale contesto, con quale supporto."}
::input{field="redattore" legend="Redatto da" required}
::input{field="stato" legend="Stato" pattern="bozza|in revisione|approvato|" message="bozza, in revisione, approvato"}

L'assistente **riscrive un testo che hai già scritto tu**. Non propone contenuti, non
formula ipotesi, non valuta l'alunno: riformula. Se non c'è un modello configurato,
il pulsante lo dice e il modulo funziona lo stesso.

::ai-rewrite{form="modContenuto" field="testo" style="in termini osservabili e misurabili, centrati sulla persona, senza gergo clinico" label="Riformula in termini osservabili"}

::save{label="Salva la sezione"}
::/form

::if-any{path="contenuti"}
## Sezioni scritte: :count{path="contenuti"}

::table{path="contenuti" search deletable editform="modContenuto" filters="tipo,stato" page-size="15"}
::column{field="alunno" label="Alunno"}
::column{field="tipo" label="Tipo"}
::column{field="sezione" label="Sezione"}
::column{field="redattore" label="Redattore"}
::column{field="stato" label="Stato"}
::column{field="updatedAt" label="Aggiornata"}
::/table
::/if-any

## Cerca nella banca delle formulazioni

Ricerca **per significato**, non per parola: «non riesce a stare attento a lungo»
trova l'obiettivo sull'attenzione anche se non contiene nessuna di quelle parole.
L'indice si costruisce su questo dispositivo e non lo lascia.

::ai-search{rag="banca.testo" placeholder="Che cosa vuoi dire, con parole tue"}

::table{path="banca" search filters="tipo,ambito" page-size="12"}
::column{field="tipo" label="Tipo"}
::column{field="ambito" label="Ambito"}
::column{field="testo" label="Formulazione"}
::/table

::form{path="banca-aggiunte" id="modBanca"}
::input{field="tipo" legend="Tipo" required pattern="compensativo|dispensativo|obiettivo|strategia|valutazione" message="compensativo, dispensativo, obiettivo, strategia, valutazione"}
::input{field="ambito" legend="Ambito o disciplina"}
::input{field="testo" legend="Formulazione" required}
::save{label="Aggiungi alla banca d'istituto"}
::/form

## Quanto si somigliano i documenti

Un PEI copiato è un PEI contestabile. Il blocco confronta i testi a coppie e segnala
quelle che condividono una quota eccessiva di parole. Non impedisce niente: dice.

::python{data="contenuti,alunni" writes="somiglianze" manual}
```python
import re

alunni = {a["id"]: a for a in data["alunni"]}

def parole(testo):
    return set(w for w in re.findall(r"[a-zà-ÿ]{4,}", (testo or "").lower()))

righe = []
for c in data["contenuti"]:
    p = parole(c.get("testo"))
    if len(p) >= 8:
        righe.append((c, p))

result = []
for i in range(len(righe)):
    for j in range(i + 1, len(righe)):
        a, pa = righe[i]
        b, pb = righe[j]
        if a.get("alunno") == b.get("alunno"):
            continue
        if a.get("sezione") != b.get("sezione"):
            continue
        comuni = len(pa & pb)
        unione = len(pa | pb)
        quota = comuni / unione if unione else 0.0
        if quota < 0.6:
            continue
        result.append({
            "id": "sim-%d" % (len(result) + 1),
            "alunnoA": alunni.get(a.get("alunno"), {}).get("codice", a.get("alunno", "")),
            "alunnoB": alunni.get(b.get("alunno"), {}).get("codice", b.get("alunno", "")),
            "sezione": a.get("sezione", ""),
            "quota": "%.0f" % (quota * 100),
        })

result.sort(key=lambda r: -int(r["quota"]))
print("%d coppie di sezioni che si somigliano oltre il 60 per cento." % len(result))
if not result:
    print("Nessuna: i documenti scritti finora sono distinti.")
```
::/python

::if-any{path="somiglianze"}
::table{path="somiglianze" sort="quota" dir="desc"}
::column{field="alunnoA" label="Alunno"}
::column{field="alunnoB" label="e alunno"}
::column{field="sezione" label="Sezione"}
::column{field="quota" label="Parole in comune %" align="end"}
::/table
::/if-any

::/page

::page{title="Misure" icon="task-list"}

# Misure per disciplina

**Questa pagina è pensata per essere condivisa da sola.** Contiene la riga che ogni
docente curricolare compila per la propria disciplina, e nient'altro: nessun quadro
clinico-funzionale, nessuna osservazione sulle dimensioni.

::form{path="misure" id="modMisura"}
::input{field="alunno" type="ref" path="alunni" label="codice" legend="Alunno" required}
::input{field="disciplina" legend="Disciplina" required}
::input{field="docente" legend="Docente" required}
::input{field="obiettivi" legend="Obiettivi della disciplina"}
::input{field="personalizzazione" legend="Personalizzazione" help="Contenuti ridotti, differenziati, o nessuna."}
::input{field="compensativi" legend="Strumenti compensativi adottati"}
::input{field="dispensative" legend="Misure dispensative applicate"}
::input{field="verifica" legend="Modalità di verifica"}
::input{field="valutazione" legend="Criteri di valutazione"}
::save{label="Salva la riga"}
::/form

::if-any{path="misure"}
::table{path="misure" search deletable editform="modMisura" filters="disciplina,docente" page-size="20"}
::column{field="alunno" label="Alunno"}
::column{field="disciplina" label="Disciplina"}
::column{field="compensativi" label="Compensativi"}
::column{field="dispensative" label="Dispensative"}
::column{field="verifica" label="Verifica"}
::column{field="valutazione" label="Valutazione"}
::/table

Righe compilate: **:count{path="misure"}**.
::/if-any

::if-empty{path="misure"}
Nessuna riga ancora. Ogni docente compila la propria disciplina dal modulo qui sopra.
::/if-empty

::/page

::page{title="Obiettivi" icon="target"}

# Obiettivi e verifiche

::form{path="obiettivi" id="modObiettivo"}
::input{field="alunno" type="ref" path="alunni" label="codice" legend="Alunno" required}
::input{field="ambito" legend="Dimensione o disciplina" required help="relazione, comunicazione, autonomia, cognitiva — oppure il nome della disciplina."}
::input{field="descrizione" legend="Obiettivo" required help="Che cosa si vede quando è raggiunto."}
::input{field="partenza" legend="Livello di partenza"}
::input{field="strumenti" legend="Strumenti e strategie"}
::input{field="criterio" legend="Criterio di verifica" help="Come si stabilisce che è raggiunto: quante volte, in quale contesto."}
::input{field="esitoIntermedio" legend="Verifica intermedia" pattern="raggiunto|parzialmente raggiunto|non raggiunto|riformulato|" message="raggiunto, parzialmente raggiunto, non raggiunto, riformulato"}
::input{field="dataIntermedia" type="date" legend="Data della verifica intermedia"}
::input{field="esitoFinale" legend="Verifica finale" pattern="raggiunto|parzialmente raggiunto|non raggiunto|riformulato|" message="raggiunto, parzialmente raggiunto, non raggiunto, riformulato"}
::input{field="dataFinale" type="date" legend="Data della verifica finale"}
::input{field="note" legend="Note"}

::ai-rewrite{form="modObiettivo" field="descrizione" style="in termini osservabili e misurabili: che cosa si vede, in quale contesto, con quale supporto" label="Riformula l'obiettivo"}

::save{label="Salva l'obiettivo"}
::/form

::if-any{path="obiettivi"}
::board{path="obiettivi" group-by="esitoFinale" columns=",raggiunto,parzialmente raggiunto,non raggiunto,riformulato" min="16rem" editform="modObiettivo"}
**{descrizione}**

{alunno} · {ambito}
::/board

::table{path="obiettivi" search filters="ambito,esitoFinale" page-size="15"}
::column{field="alunno" label="Alunno"}
::column{field="ambito" label="Ambito"}
::column{field="descrizione" label="Obiettivo"}
::column{field="esitoIntermedio" label="Intermedia"}
::column{field="esitoFinale" label="Finale"}
::/table
::/if-any

## Proposta di risorse per l'anno successivo

È la sezione con cui si chiude la verifica finale, e la riga che alimenta la
richiesta di organico.

::form{path="risorse" id="modRisorsa"}
::input{field="alunno" type="ref" path="alunni" label="codice" legend="Alunno" required}
::input{field="anno" legend="Per l'anno scolastico" required placeholder="2027/2028"}
::input{field="oreSostegno" type="number" legend="Ore di sostegno proposte" min="0" max="40" required}
::input{field="oreAssistenza" type="number" legend="Ore di assistenza proposte" min="0" max="40"}
::input{field="sussidi" legend="Sussidi richiesti"}
::input{field="motivazione" legend="Motivazione" required}
::input{field="deliberata" type="date" legend="Deliberata il"}
::save{label="Registra la proposta"}
::/form

::if-any{path="risorse"}
::table{path="risorse" search deletable editform="modRisorsa" sort="alunno"}
::column{field="alunno" label="Alunno"}
::column{field="oreSostegno" label="Sostegno" align="end"}
::column{field="oreAssistenza" label="Assistenza" align="end"}
::column{field="sussidi" label="Sussidi"}
::/table

Totale proposto: **:sum{path="risorse" field="oreSostegno"}** ore di sostegno e
**:sum{path="risorse" field="oreAssistenza"}** di assistenza.
::/if-any

::/page

::page{title="GLO" icon="people-group"}

# Incontri del GLO

::form{path="glo" id="modGlo"}
::input{field="alunno" type="ref" path="alunni" label="codice" legend="Alunno" required}
::input{field="tipo" legend="Tipo di incontro" required pattern="approvazione iniziale|verifica intermedia|verifica finale|straordinario" message="approvazione iniziale, verifica intermedia, verifica finale, straordinario"}
::input{field="data" type="date" legend="Data" required}
::input{field="ora" type="time" legend="Ora"}
::input{field="partecipanti" legend="Partecipanti" help="Nome e ruolo, separati da virgola. La presenza si annota nel verbale."}
::input{field="odg" legend="Ordine del giorno"}
::input{field="verbale" legend="Verbale"}
::input{field="deliberazioni" legend="Deliberazioni"}
::input{field="stato" legend="Stato" pattern="convocato|svolto|verbalizzato|" message="convocato, svolto, verbalizzato"}
::save{label="Salva l'incontro"}
::/form

::if-any{path="glo"}
## Calendario d'istituto

::calendar{path="glo" field="data" by="tipo" time="ora" form="modGlo" tooltip="{alunno} — {tipo}"}
**{alunno}** {tipo}
::/calendar

::table{path="glo" search filters="tipo,stato" sort="data" dir="desc" deletable editform="modGlo" page-size="15"}
::column{field="data" label="Data"}
::column{field="alunno" label="Alunno"}
::column{field="tipo" label="Incontro"}
::column{field="partecipanti" label="Partecipanti"}
::column{field="stato" label="Stato"}
::/table
::/if-any

::if-empty{path="glo"}
Nessun incontro in calendario.
::/if-empty

## Firme

Della firma si registra **che è stata raccolta**, da chi e come. Non è una firma
digitale qualificata e non finge di esserlo: è il registro di un procedimento, e il
documento firmato resta quello che la scuola conserva.

::form{path="firme" id="modFirma"}
::input{field="alunno" type="ref" path="alunni" label="codice" legend="Alunno" required}
::input{field="documento" legend="Documento" required pattern="PEI|PDP" message="PEI oppure PDP"}
::input{field="soggetto" legend="Chi firma" required}
::input{field="ruolo" legend="Ruolo" required help="docente di sostegno, coordinatore, genitore, dirigente, specialista"}
::input{field="data" type="date" legend="Data"}
::input{field="modalita" legend="Modalità" pattern="in presenza|su dispositivo|cartacea acquisita|" message="in presenza, su dispositivo, cartacea acquisita"}
::input{field="dissenso" legend="Dissenso motivato" help="Se c'è, si scrive. Un dissenso non registrato è un dissenso che tornerà."}
::save{label="Registra la firma"}
::/form

::if-any{path="firme"}
::table{path="firme" search filters="ruolo,documento" deletable editform="modFirma" sort="data" dir="desc"}
::column{field="alunno" label="Alunno"}
::column{field="documento" label="Documento"}
::column{field="soggetto" label="Chi"}
::column{field="ruolo" label="Ruolo"}
::column{field="data" label="Data"}
::column{field="dissenso" label="Dissenso"}
::/table
::/if-any

::/page

::page{title="Cruscotto" icon="dashboard"}

# Stato dei documenti

Quante sezioni obbligatorie mancano, alunno per alunno. È la vista del referente a
fine ottobre.

::python{data="contenuti,alunni,modelli" writes="stato-documenti" manual}
```python
alunni = data["alunni"]
modelli = data["modelli"]
contenuti = data["contenuti"]

def sezioni_attese(alunno):
    tipo = "PEI" if alunno.get("percorso") == "PEI" else "PDP"
    if tipo == "PEI":
        return [m for m in modelli
                if m.get("tipo") == "PEI"
                and m.get("ordine") == alunno.get("ordine")
                and (m.get("obbligatoria") or "").lower() in ("true", "1", "si", "sì", "yes")]
    return [m for m in modelli
            if m.get("tipo") == "PDP"
            and (m.get("obbligatoria") or "").lower() in ("true", "1", "si", "sì", "yes")]

result = []
for alunno in alunni:
    attese = sezioni_attese(alunno)
    scritte = set()
    stati = []
    for c in contenuti:
        if c.get("alunno") != alunno["id"]:
            continue
        if (c.get("testo") or "").strip() == "":
            continue
        scritte.add(c.get("sezione"))
        stati.append(c.get("stato") or "bozza")
    fatte = sum(1 for m in attese if m["id"] in scritte)
    totale = len(attese)
    stato = "non avviato"
    if fatte and fatte < totale:
        stato = "in corso"
    elif totale and fatte >= totale:
        stato = "approvato" if all(s == "approvato" for s in stati) and stati else "completo"
    result.append({
        "id": "st-" + alunno["id"],
        "codice": alunno.get("codice", ""),
        "classe": alunno.get("classe", ""),
        "ordine": alunno.get("ordine", ""),
        "percorso": alunno.get("percorso", ""),
        "attese": str(totale),
        "scritte": str(fatte),
        "mancanti": str(max(0, totale - fatte)),
        "percentuale": "%d" % (100 * fatte / totale) if totale else "0",
        "stato": stato,
    })

per_stato = {}
for r in result:
    per_stato[r["stato"]] = per_stato.get(r["stato"], 0) + 1
print("%d documenti seguiti." % len(result))
for stato in sorted(per_stato):
    print("  %s: %d" % (stato, per_stato[stato]))
```
::/python

::if-any{path="stato-documenti"}
::cards{path="stato-documenti" min="14rem" group-by="stato"}
**{codice}** — {classe}

{scritte} sezioni su {attese} ({percentuale}%)
::/cards

::chart-bar{data="stato-documenti" x="codice" y="scritte,mancanti" stacked height="18rem"}
::/if-any

# Riepilogo d'istituto

**Senza nominativi.** Conta, non elenca: è quello che serve al Piano Annuale per
l'Inclusione e alla richiesta di organico, e non c'è motivo perché contenga un nome.

::python{data="alunni,risorse,stato-documenti" writes="riepilogo" manual}
```python
def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

alunni = data["alunni"]
result = []

def voce(gruppo, chiave, valore):
    result.append({
        "id": "r-%d" % (len(result) + 1),
        "gruppo": gruppo, "voce": chiave, "valore": str(valore),
    })

for percorso in sorted(set(a.get("percorso", "") for a in alunni)):
    voce("Percorsi", percorso, sum(1 for a in alunni if a.get("percorso") == percorso))
for ordine in sorted(set(a.get("ordine", "") for a in alunni)):
    voce("Ordini di scuola", ordine, sum(1 for a in alunni if a.get("ordine") == ordine))
for classe in sorted(set(a.get("classe", "") for a in alunni)):
    voce("Classi", classe, sum(1 for a in alunni if a.get("classe") == classe))

voce("Risorse", "Ore di supporto assegnate quest'anno",
     sum(intero(a.get("oreSupporto")) for a in alunni))
voce("Risorse", "Ore di sostegno proposte per l'anno prossimo",
     sum(intero(r.get("oreSostegno")) for r in data["risorse"]))
voce("Risorse", "Ore di assistenza proposte per l'anno prossimo",
     sum(intero(r.get("oreAssistenza")) for r in data["risorse"]))
voce("Risorse", "Alunni con trasporto dedicato",
     sum(1 for a in alunni if (a.get("trasporto") or "").lower() in ("true", "1", "si", "sì")))

for stato in sorted(set(s.get("stato", "") for s in data["stato-documenti"])):
    voce("Stato dei documenti", stato,
         sum(1 for s in data["stato-documenti"] if s.get("stato") == stato))

# Le certificazioni in scadenza si contano, non si nominano.
scadenze = [a.get("scadenzaCertificazione", "") for a in alunni]
voce("Certificazioni", "In scadenza entro il 2026",
     sum(1 for s in scadenze if s and s < "2027-01-01"))

print("%d voci di riepilogo, nessun nominativo." % len(result))
```
::/python

::if-any{path="riepilogo"}
::table{path="riepilogo" filters="gruppo"}
::column{field="gruppo" label="Gruppo"}
::column{field="voce" label="Voce"}
::column{field="valore" label="Valore" align="end"}
::/table
::/if-any

::/page

::page{title="Stampe" icon="print"}

# Stampe

Codice dell'alunno da stampare:

::textfield[alunnoSel]{placeholder="al-001"}

## Estratto operativo per il consiglio di classe

Una pagina: misure, strumenti e criteri di valutazione. **Niente quadro
clinico-funzionale, niente osservazioni sulle dimensioni, niente certificazione.** È
quello che serve in aula e in sede d'esame, ed è tutto quello che serve.

::columns{min="24rem" id="estrattoOperativo"}
### Estratto operativo — misure e strumenti

::list{path="alunni" filter="id=#alunnoSel" limit="1"}
**{codice}** — classe {classe}, {ordine}, percorso {percorso}
::/list

::table{path="misure" filter="alunno=#alunnoSel"}
::column{field="disciplina" label="Disciplina"}
::column{field="compensativi" label="Strumenti compensativi"}
::column{field="dispensative" label="Misure dispensative"}
::column{field="verifica" label="Verifica"}
::column{field="valutazione" label="Valutazione"}
::/table

Il presente estratto riporta esclusivamente le misure, gli strumenti e i criteri di
valutazione deliberati dal consiglio di classe. Non contiene dati relativi alla
salute.
::/columns

::print{target="estrattoOperativo" landscape label="Stampa l'estratto operativo"}

::print{target="estrattoOperativo" repeat="alunni" key="alunnoSel" landscape label="Stampa l'estratto di ogni alunno"}

## Il documento intero

::columns{min="24rem" id="documentoIntero"}
### Documento

::list{path="alunni" filter="id=#alunnoSel" limit="1"}
**{cognome} {nome}** ({codice}) — classe {classe}, {ordine}

Percorso: {percorso}. Certificazione: {enteCertificazione}, del
{dataCertificazione}, con scadenza {scadenzaCertificazione}.
::/list

::list{path="contenuti" filter="alunno=#alunnoSel"}
#### {sezione>modelli.titolo}

{testo}

*Redatto da {redattore} — {updatedAt}*
::/list

#### Obiettivi

::table{path="obiettivi" filter="alunno=#alunnoSel"}
::column{field="ambito" label="Ambito"}
::column{field="descrizione" label="Obiettivo"}
::column{field="criterio" label="Criterio"}
::column{field="esitoIntermedio" label="Intermedia"}
::column{field="esitoFinale" label="Finale"}
::/table

#### Firme

::list{path="firme" filter="alunno=#alunnoSel"}
{ruolo}: {soggetto} — {data} ({modalita})
::/list
::/columns

::print{target="documentoIntero" label="Stampa il documento"}

::/page

::page{title="Decisioni" icon="info"}

# Decisioni prese, e perché

**I modelli non sono nel codice.** Cambiano per norma e per delibera. Quelli seminati
seguono le dimensioni della prospettiva bio-psico-sociale ICF per il PEI e le sezioni
che quasi ogni istituto adotta per il PDP: **vanno confrontati con il modello
effettivamente deliberato dal collegio** prima di redigere un documento vero.

**Non si archivia nessuna diagnosi.** Della certificazione restano ente, data e
scadenza. Il caricamento di referti è disattivato per costruzione: non c'è un campo
file in nessun modulo di questa app, e questa è una scelta, non una mancanza.

**L'AI riformula e cerca, non giudica.** Le uniche due direttive AI qui dentro sono
`::ai-rewrite`, che riscrive un testo già scritto da un docente, e `::ai-search`, che
cerca nella banca delle formulazioni. Non c'è nessuna direttiva che classifichi un
alunno, che proponga un obiettivo al posto del GLO o che formuli una previsione. Con
un modello locale (Ollama) nulla lascia il dispositivo; **con un fornitore remoto, il
testo che stai riformulando viene inviato a quel fornitore** — e per un documento di
questo tipo la scelta consigliata è una sola, il modello locale.

**Il controllo d'accesso per ruolo non è in questo documento.** La pagina *Misure* è
costruita per essere condivisa da sola, il che è una separazione per costruzione, non
per permesso. La separazione forzata è quella degli spazi condivisi della piattaforma.
Prima di usare l'app su dati veri va deciso chi apre che cosa: non è una decisione che
il documento possa prendere.

**Le somiglianze si segnalano, non si impediscono.** Due sezioni che condividono oltre
il 60 per cento delle parole sono probabilmente la stessa sezione incollata due volte.
La soglia è nel blocco, si cambia in una riga.

**Il blocco delle firme registra un procedimento, non firma.** Non c'è firma digitale
qualificata, e non ci sarà: quella richiede un certificato e un dispositivo, e
simularla sarebbe peggio che non averla.

**Il documento non si blocca da solo dopo l'approvazione.** Lo stato *approvato* è una
riga, non un lucchetto: la piattaforma non ha un meccanismo per rendere immodificabile
una collezione di questo browser. Dove serve davvero, la sola risposta onesta è
esportare il documento e conservarlo altrove.

::/page
