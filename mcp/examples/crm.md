---
appId: ricetta-crm
title: Clienti e contatti
description: "Un piccolo CRM: anagrafica dei clienti e diario delle interazioni."
lang: it
---

::page{title="Clienti"}

# Clienti

::form{path="clienti"}
::input{field="nome" legend="Nome" required}
::input{field="email" legend="Email" type="email"}
::input{field="telefono" legend="Telefono" type="tel"}
::input{field="note" legend="Note" help="Come li abbiamo conosciuti, cosa cercano."}
::save{label="Salva cliente"}
::/form

::if-empty{path="clienti"}
Ancora nessun cliente: il primo si aggiunge qui sopra.
::/if-empty

::if-any{path="clienti"}
:count{path="clienti"} clienti.

::table{path="clienti" search deletable editform sort="nome"}
::column{field="nome" label="Nome"}
::column{field="email" label="Email"}
::column{field="telefono" label="Telefono"}
::/table
::/if-any

::/page

::page{title="Interazioni"}

# Interazioni

::form{path="interazioni"}
::input{field="cliente" type="ref" path="clienti" label="nome" legend="Cliente" required}
::input{field="quando" type="date" legend="Data" required}
::input{field="esito" legend="Esito" required help="Preventivo inviato, ordine, da richiamare…"}
::save{label="Registra"}
::/form

::if-any{path="interazioni"}
::list{path="interazioni" sort="quando" dir="desc" deletable}
**{cliente>clienti.nome}** — {quando}: {esito}
::/list
::/if-any

::if-empty{path="interazioni"}
Nessuna interazione registrata: la prima si aggiunge qui sopra.
::/if-empty

::/page
