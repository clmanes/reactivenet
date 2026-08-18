---
title: "Composable apps, shared data spaces, and sync with no secrets in the file"
description: "July's news: catalog solutions become suites of micro apps, apps share data with your consent, and multi-user sync no longer writes anything into the document."
date: 2026-07-14
author: "Cosimo Luigi Manes"
translationKey: "app-componibili-spazi-condivisi"
cover: "/img/blog/app-componibili-spazi-condivisi.jpg"
coverAlt: "Planning Your Online Course v2"
coverAuthor: "giulia.forsythe"
coverAuthorUrl: "https://www.flickr.com/photos/59217476@N00"
coverSource: "https://www.flickr.com/photos/59217476@N00/8186356402"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

July was a busy month for Reactive. Three connected changes reshape how apps are built, combined and shared — always with the same compass: **your data stays yours, on your device**.

## Build big things out of small apps

Every catalog solution is now a **suite of composable micro apps**: quick entry on your phone, a dashboard on your desk, one address book feeding everything — each piece does one job and does it well. Open the suite in one click from the catalog page, keep only the pieces you need.

Macro apps can also **integrate with each other**: Compass (CRM) and Tally (quotes and invoices) share the same client list; enter a client once and find it in both. And the AI assistant can create systems of micro apps on request: describe the workflow, and it generates apps that work as a team.

## Shared data spaces, with your consent

The mechanism under the hood is the **shared data space**: apps declaring the same space read and write the same collections, on the device. No silent automatism: on first open every app asks for your consent, revocable at any time; without it, the app works normally on its own private data. In the gallery, a colored tag groups at a glance the apps sharing a space.

## The file no longer contains secrets

The third change runs deepest. Multi-user sync — end-to-end encrypted, no accounts — no longer writes the access key into the document: the key lives in a **local registry in your browser** and travels only in the invite link, in a **QR code** to scan, or in the **local backup** you can copy or save to a file.

What this means in practice:

- **sharing the file no longer gives away the data** — an app can be published, exported, passed around without a second thought;
- the share link carries app and access together, and whoever opens it decides explicitly whether to **join** before a single byte leaves the device;
- shared spaces go multi-user with the same gesture: one invite, and the whole suite syncs with your group;
- documents shared in the past keep working: the key is migrated automatically (and removed from the file) on first open.

## Where to start

Browse the [solutions catalog](/en/app/), read the [step-by-step guide](/en/guida/sintassi/), or open [the app](https://app.reactivenet.ai) directly and tell the assistant what you need — in one sentence.
