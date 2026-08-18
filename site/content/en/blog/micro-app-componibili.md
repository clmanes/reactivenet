---
title: "Composable micro apps: building big things out of small pieces"
seotitle: "Composable micro apps, one shared data space"
description: "Tiny apps with a single job, sharing one data space and composing into complete solutions — with your consent, and multi-user with one invite."
date: 2026-07-14
author: "Cosimo Luigi Manes"
translationKey: "micro-app-componibili"
cover: "/img/blog/micro-app-componibili.jpg"
coverAlt: "building blocks: social experience"
coverAuthor: "David Armano"
coverAuthorUrl: "https://www.flickr.com/photos/7855449@N02"
coverSource: "https://www.flickr.com/photos/7855449@N02/4058959195"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Reactive’s catalog solutions aren’t monoliths: they are **compositions of micro apps**. It’s the most important concept in the system, and it deserves a proper explanation.

## What a micro app is

A micro app is a Reactive app with **a single job**: logging an expense, keeping the client list, showing a dashboard. It’s a plain Markdown document — a few dozen lines — that your browser compiles into a reactive app: a form, a view, a total. Minimal interface, zero learning curve, no labyrinthine menus.

Its apparent limitation — “it does one thing” — is its strength: a small app is understood at a glance, modified without fear, and replaced without touching the rest.

## The glue: the shared data space

On their own, micro apps would be islands. What holds them together is the **shared data space**: apps declaring the same space (`dataId` in the frontmatter) read and write the same collections, on your device.

The most concrete example is the “casa” space: the **Quick expenses** micro — three taps on your phone — writes into the same collection that **Piggybank** uses for the balance and **Hearth** for household expenses. One expense entered once, three apps updated. The “studio” space does the same for clients: one address book feeds **Compass**’s deals and **Tally**’s invoices.

Two non-negotiable rules govern the mechanism:

1. **Explicit consent.** Every app asks permission before joining a shared space, on first open. Without consent it still works, on its own private data. And you can revoke anytime.
2. **The document never contains secrets.** The key that makes a space multi-user lives in the browser’s local registry, never in the file: you can share or publish a micro app without giving away access to the data.

## Compose, don’t configure

A catalog suite opens in one click and arrives already composed: dashboard, entry forms, views, address books. But the composition is yours:

- **remove** the pieces you don’t use (each micro app can be deleted without breaking the others);
- **add** micro apps from the catalog — or have the **AI assistant generate them**: it can create whole systems of coordinated micro apps on request;
- **edit** one piece at a time: each micro app remains a plain text file, with its own version and life cycle.

It’s the difference between a management suite you configure and a box of bricks: you don’t adapt yourself to the app, you compose the app around how you work.

## Multi-user with one invite

When collaboration is needed, the whole space becomes shared **with a single gesture**: from the sync menu you generate an invite — a link or a QR code — and whoever accepts works on the same data, in real time, encrypted end to end. No need to invite app by app: one space, one invite. The expense logged on a family member’s phone shows up in the balance on your computer, and no server in between can read a thing.

## Why it beats one big app

- **Simplicity where it matters**: whoever enters expenses sees only the expense form, not an entire management suite.
- **Data coherence**: one entry, zero duplicates, every view updated.
- **Evolvability**: you swap a brick, you don’t rebuild the wall.
- **Portability**: every piece is a file — export it, share it, put it under version control.

Try a composition from the [catalog](/en/app/) — every page shows which micro apps it’s made of — or start from the [guide](/en/guida/sintassi/) to write your own. A few lines of text are enough.
