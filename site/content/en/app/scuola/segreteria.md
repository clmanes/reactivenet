---
title: "School office"
translationKey: "app-segreteria"
seotitle: "School back-office dashboard: cases, deadlines, staff counters"
appid: "segreteria"
weight: 50
description: "The operational dashboard of a school's administrative office: cases with configurable types and deadlines, a kanban view, a calendar of statutory obligations, contractual leave counters, fixed-term contracts, purchasing and inventory, reports and printing."
lead: "It replaces neither the ministry's systems nor the official register: it covers what today lives in shared spreadsheets, network folders and sticky notes — where a case is, who is working it, what falls due when, which counters are spent."
shots:
  - src: segreteria-scadenzario.jpg
    alt: "The Deadlines page: the table of recurring obligations ordered by due date, with area, owner and status."
    caption: "The recurring obligations in date order, with the area and who answers for each. No program knows your school's own calendar: the dates are written once and stay from year to year."
  - src: segreteria-personale.jpg
    alt: "The Staff page: the staff table with payroll number, surname, first name, category, contract type, percentage and end date."
    caption: "Staff with their contract and part-time percentage: this is what the counters read, and it is also the list of who has an end date coming."
  - src: segreteria-contatori.jpg
    alt: "The Staff page: the counters table by person and item, with value, limit and unit."
    caption: "The contractual counters, person by person: leave due, taken and left, suppressed holidays, permits. Every item carries its limit beside it — it is the question \"am I square?\" with the answer next to it."
tags: ["Business managers", "Administrative staff", "Head teachers", "Back office"]
---

The app is written in Italian, for Italian schools and their terminology.
Everything below describes what it does.

## Where it sits, first of all

This app **does not replace or reimplement** the ministry's systems, the legally
compliant document register, digital preservation, the class register or budget
accounting. Where one of those is needed it holds a **reference** and an export, not a
pretend implementation: the register number is the real one, assigned elsewhere,
because a number generated here would be a number no register knows.

It covers the coordination layer missing between the ministerial software and the
administrator's memory.

## What it does

**Case types are data.** Name, area, deadline in days, checklist and whether the head
teacher signs: a new type is created from a form in under five minutes, with no code
touched. Twelve arrive ready-made.

**Cases are dragged.** A kanban by state, where moving a card writes that state onto
the case, and a dense table with combinable filters beside it.

**The obligations calendar** arrives with fifteen typical items of a school year — as
editable data, not as code, because the dates change every September.

**Counters are computed.** Leave due, taken and remaining, statutory permits, short
permits to make up, days of sickness and of care leave. Entitlements are scaled by
part-time percentage, and the contractual parameters sit in one table at the top of the
block: they change with every renewal, and that is the line to correct.

**A block says what is wrong**: cases past their deadline, contracts ending within
thirty days, expired supplier certificates, obligations past their notice period,
counters over the limit — one screen, ordered by severity.

**Three AI directives, none irreversible.** One fills a case draft from a sentence,
which a person reviews and saves; one assigns the area choosing between four and
discarding anything outside the list; one rule written in words is compiled once and
then runs with no model at all.

## No health data

Of an absence it records the **type under the contractual coding** and the days. Of a
medical certificate it records the reference, not the certificate. Sickness is counted
in days and care leave is a number: what lies behind either does not enter this app.

## What it does not do, and says so

It does not register documents officially, send mail, pay, transmit or sign digitally.
A case deadline is a date you write, not a calculation. It has no per-role access
control: where one area must not see another's data, the answer is two apps, or the
platform's shared spaces.
