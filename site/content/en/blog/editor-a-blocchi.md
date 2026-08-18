---
title: "Write your app like a document: the block editor is here"
description: "Reactive's new default editing mode: build your document like on Notion, block by block. Every widget is a card with fields to fill in, the / menu suggests everything you can insert in your language, and an AI block generates widgets in place from a sentence. The code is still there, one click away — you just don't have to start from it anymore."
date: 2026-08-04
author: "Cosimo Luigi Manes"
translationKey: "editor-a-blocchi"
cover: "/img/blog/editor-a-blocchi.jpg"
coverAlt: "From Harpel's Typograph"
coverAuthor: "Double--M"
coverAuthorUrl: "https://www.flickr.com/photos/49879584@N00"
coverSource: "https://www.flickr.com/photos/49879584@N00/4619880040"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Until now, building an app with Reactive meant writing the document: plain text for the text, and a few special lines — the directives — for the interactive parts. It works, and it’s the heart of the system. But the first time you face `::form{path="expenses" id="f1"}`, a fair question comes up: _do I really have to learn this?_

As of today, you don’t. Opening an app for editing you’ll find the new **Blocks** view: the document builds like a modern note-taking editor, block by block. Headings are headings, paragraphs are just typed. And the interactive parts — a form, a table, a chart, a map — are **cards** with a clear label: _Element_, _Section_, _Code_, _Settings_.

## Fill in, not syntax

Each card shows its options as a small form: the collection to save into, the button label, the number of columns. Yes/no options are toggles, closed choices are dropdowns. Change a value and the preview beside it updates on its own: the app is alive while you build it.

Sections truly contain their pieces: a form shows its fields inside itself, one within the other, and you can drag them to reorder. The app settings — name, title, language — are a form too, at the top of the document.

## The menu that knows everything

Typing **/** brings up the full list of what you can insert: the classic blocks (headings, lists, images) and every Reactive widget, each with a short description **in your language** — English, Italian, Spanish, French, German, Portuguese or Chinese. Type `/table`, pick, fill in the fields. Done.

## And if you don’t know where to start, ask

The **✦ AI** button (or `/ai`) opens a special block: describe what you want in words — _“a coffee counter with a +1 button and today’s total”_ — and the assistant generates the right blocks at that exact spot in the document, already filled in and working in the preview. It uses the same AI engine as the chat: the one on your own computer, if you’d rather nothing leaves your device. And when the model writes widgets imprecisely — it happens — Reactive repairs them on its own before inserting.

## The code hasn’t gone anywhere

The **Code** view is still there, one click away: same document, same single source. Whatever you touch in the blocks shows up in the Markdown, byte for byte where you didn’t intervene — because the app _is_ still that text file you can save, share as a link, keep under version control. That’s Reactive’s promise, and the block editor doesn’t change it: it just makes it easier to keep.

Open [app.reactivenet.ai](https://app.reactivenet.ai), pick an app and hit ✎ Edit: the Blocks view is waiting.
