---
title: "What is Reactive: your app in one sentence, private by design"
seotitle: "What is Reactive: your app in one sentence"
description: "The inaugural post: what Reactive is, how a plain text document becomes a working app in your browser, and why your data never leaves your device."
date: 2026-07-13
author: "Cosimo Luigi Manes"
translationKey: "cos-e-reactive"
cover: "/img/blog/cos-e-reactive.jpg"
coverAlt: "Always Writing"
coverAuthor: "mrsdkrebs"
coverAuthorUrl: "https://www.flickr.com/photos/56041749@N02"
coverSource: "https://www.flickr.com/photos/56041749@N02/6812988091"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Welcome to the Reactive blog. For the first post, let’s start at the beginning: **what exactly is Reactive?**

## A document that becomes an app

Reactive turns a plain text document into a working application — forms, tables, calculations, charts — right in your browser. You write on the left, the app comes to life on the right, as you type. No server, no account, nothing to install: open the page and you’re already working.

The text is Markdown, the same dead-simple format used for notes and documentation, enriched with small **declarative tags**: a line like `::input{field="name"}` becomes a text field, `::table{path="clients"}` a table with search, sorting and CSV import/export built in. The data you enter stays in your browser, kept separate app by app, with backup and restore to a file whenever you want to take it with you.

## The assistant that writes it for you

You don’t need to learn the syntax: describe the app you need — _“a time sheet for my practice”_, _“a home budget”_ — and the AI assistant builds it before your eyes, applying the changes by itself (with Undo always one click away). And the AI can live **inside** the apps too: summaries that refresh when data changes, forms that fill themselves from a photo, semantic search over your attachments.

The house rule applies here as well: the model runs **on your device** — in the browser or with Ollama on your computer. No data roaming the world.

## You don’t start from scratch: the catalog

The [catalog](/en/app/) collects ready-to-use vertical solutions — CRM, invoicing, inventory, practice scheduling, school, public offices, everyday life. Each one is a **suite of composable micro apps** sharing a data space: the client list you enter once feeds quotes, deals and deadlines. Open a suite in one click, keep the pieces you need, customize the rest with AI or by hand.

## Collaborating, without giving up privacy

An app is a file: share it with a link and whoever opens it gets a working copy. If you want to work **on the same data**, turn on sync: changes travel end-to-end encrypted through a relay that only forwards unreadable packets — nobody, not even us, can read what you write. The access key stays on your device and travels only in the invite (a link or a QR code): the file itself never contains secrets.

## Why it’s built this way

Privacy in Reactive is not a setting: it’s the architecture. There are no servers holding your data, no accounts to breach, no “us” that can peek. It’s also why the service is **free**: there’s no infrastructure making you pay with your data or a subscription.

If you want to try it, [open the app](https://app.reactivenet.ai) and write one sentence. If you want to understand how it works underneath, start from the [guide](/en/guida/sintassi/). And on this blog we’ll tell, release after release, where the project is heading.
