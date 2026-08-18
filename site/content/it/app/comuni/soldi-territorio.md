---
title: "Conti pubblici del territorio"
translationKey: "app-soldi-territorio"
seotitle: "Conti pubblici del territorio: bilanci comunali, PNRR e appalti"
appid: "soldi-territorio"
weight: 10
description: "Dove vanno e da dove arrivano i soldi pubblici del tuo comune: spesa ed entrate per cassa, saldo e autonomia finanziaria, i progetti di coesione e PNRR, le gare d'appalto e chi le vince. Otto pagine su dati ufficiali MEF-RGS, ANAC, DIPE e Agenzia per la Coesione."
lead: "Un comune si capisce dai suoi flussi di cassa. Otto cruscotti su fonti ufficiali — spesa, entrate, progetti finanziati, appalti — con la classifica regionale, la previsione e le anomalie calcolate nel tuo browser."
shots:
  - src: soldi-territorio-comune.jpg
    alt: "La pagina «Il mio comune»: la ricerca del comune e quattro schede con spesa, variazione, posizione in classifica e costo del debito."
    caption: "Si scrive il nome del comune una volta sola e tutte le pagine seguono quella scelta: qui Bologna, 1.078 milioni pagati nel 2025, 2.763 € per abitante, 39ª su 330."
  - src: soldi-territorio-mappa.jpg
    alt: "La coropletica dei comuni dell'Emilia-Romagna colorata per spesa per abitante."
    caption: "I 330 comuni della regione colorati per spesa pro capite: è così che si capisce se una cifra è alta, guardandola accanto alle altre."
  - src: soldi-territorio-appalti.jpg
    alt: "La pagina «Appalti»: l'elenco delle gare con amministrazione, importo, data, vincitore e ribasso, con i filtri per procedura."
    caption: "Le gare del territorio con chi le ha vinte e a quale ribasso, filtrabili per procedura — dal comune soltanto o da tutta la provincia."
tags: ["Comuni", "Amministratori", "Giornalisti", "Open data", "SIOPE", "PNRR", "ANAC"]
---

## Cosa fa

Si scrive il nome di un comune e le otto pagine si riempiono di dati ufficiali,
agganciati fra loro dal codice ISTAT.

**Il mio comune** è la scheda d'insieme: spesa dell'ultimo anno chiuso e sua
variazione, spesa per abitante, posizione nella classifica regionale, esposizione
debitoria. Sotto, la coropletica dei comuni della regione colorata per spesa pro
capite — dove il tuo si vede in mezzo agli altri, che è l'unico modo per sapere
se una cifra è alta o bassa.

**La spesa** e **Le entrate** aprono i due lati del bilancio di cassa: le
categorie SIOPE anno per anno, il confronto con le fasce demografiche della
regione, il saldo fra incassi e pagamenti, l'autonomia finanziaria — quanta parte
delle entrate il comune produce da sé — e quanto incassa da sanzioni.

**PNRR e progetti** mette in fila quello che è stato finanziato: i temi su cui i
fondi di coesione sono arrivati, i singoli progetti con il loro stato di
avanzamento e il beneficiario, e gli interventi censiti in OpenCUP con il
soggetto titolare. **Appalti** guarda le gare degli ultimi due anni: importi,
procedure di affidamento, quota PNRR, e per ciascuna chi se l'è aggiudicata con
quale ribasso.

**Analisi** è la parte che calcola invece di mostrare: la previsione della spesa
sui cinque anni chiusi, le anomalie individuate da un Isolation Forest con la
sensibilità regolabile, e i comuni dal profilo di spesa più simile al tuo —
utile per capire con chi ha davvero senso confrontarsi. **Esplora** lascia al
lettore la tabella pivot, e **Fonti** dichiara ogni dataset con la sua licenza.

## Da dove vengono i dati

| Fonte | Cosa fornisce | Copertura |
| --- | --- | --- |
| MEF-RGS — SIOPE / OpenBDAP | incassi e pagamenti per cassa di ogni comune | serie storica, ultimi anni chiusi |
| Agenzia per la Coesione — OpenCoesione | progetti finanziati, temi, stato, beneficiari | cicli di programmazione |
| DIPE — OpenCUP | interventi pubblici con soggetto titolare e costo | dal censimento CUP |
| ANAC | gare, importi, procedure, aggiudicatari e ribassi | **2024–2025** |
| ISTAT | confini comunali per le mappe | — |

## Quello che l'app non dice, e perché

L'archivio ANAC nel magazzino copre due anni: la pagina Appalti non è la storia
degli appalti del comune, è quello che si è mosso nel biennio, e la pagina lo
scrive. La previsione della spesa poggia su cinque punti — sono i cinque
esercizi chiusi disponibili — quindi è un'estrapolazione, non un bilancio di
previsione. I dati SIOPE sono flussi di **cassa**: dicono quanto è stato pagato e
incassato, non quanto è stato impegnato, che è una cosa diversa e spesso più
grande.

## Come si cambia

È un documento Markdown: le interrogazioni si leggono tutte, e cambiarne una è
una riga. Se il tuo comune fa un ragionamento diverso — una categoria di spesa
che vi interessa più delle altre, un confronto con i comuni confinanti invece che
con la fascia demografica — quella è una modifica che si fa da soli, o si chiede
all'assistente.
