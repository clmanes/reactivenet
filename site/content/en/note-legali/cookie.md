---
title: "Cookie policy"
translationKey: "legal-cookie"
description: "This site uses no cookies. The app uses your browser's local storage to hold your apps, which is where they belong. Here is what is in there and how to clear it."
version: "1.4"
updated: "2026-08-18"
weight: 20
---

<!-- GENERATO da site/scripts/sync-legal.mjs — non modificare qui.
     La fonte è legal/en/cookie-policy.md: modifica quella e rilancia lo script. -->

Provided under Article 122 of Italian Legislative Decree 196/2003 and the
«Guidelines on cookies and other tracking tools» of the Italian Data Protection
Authority (decision of 10 June 2021, no. 231).

## 1. What this document covers

The law does not speak only of cookies: it speaks of **any storage of
information on the user's device, and any access to information already
stored**. That includes `localStorage`, `sessionStorage`, IndexedDB, the service
worker cache and passive identification techniques. This document covers them
all, because the distinction that matters is not the name of the technology but
**what it is for**: if it serves to deliver the service the user asked for it is
technical and requires no consent; if it serves to follow a person across sites
and over time it requires prior consent.

## 2. The website uses no cookies

The pages of `reactivenet.ai` **set no cookies at all**, neither technical nor
third-party, and store nothing in `localStorage`. There is nothing to accept,
and that is why there is no banner: a banner asking consent for nothing is an
obstacle, not a protection.

Fonts are served from our own domain: there is no request to any external font
service. There are no third-party embedded videos, social buttons, advertising
pixels or third-party iframes.

## 3. Cookieless statistics: Pirsch Analytics

Visits to the website `reactivenet.ai` and to the application
`app.reactivenet.ai` are counted with **Pirsch Analytics** (Emvi Software GmbH,
Germany), chosen because it is possible to measure a website without following
the people who read it.

- **It sets no cookies** and writes nothing to the device: neither on the
  website nor in the application does Pirsch store or read anything on the
  terminal.
- **It does not retain the IP address.** It uses it together with the user agent
  to compute a non-reversible digest, with a random element that changes every
  day: it serves only to avoid counting the same visit twice within the same
  day, and the next day it can no longer be linked to anything.
- **It does not identify** anyone and does not follow a person across different
  sites or different days: there is no persistent identifier.
- **The data stays in Germany**, on European Union servers.

What is recorded: page visited, referrer, date and time, country, device type,
browser, operating system, browser language. On the website, pressing certain
buttons is additionally counted as an **anonymous event**: opening the
platform, opening or downloading a catalogue app (with the app's name), copying
the MCP address, the GitHub and LinkedIn links. The event says which control
was pressed and nothing about who pressed it, with the same guarantees as
above: no cookie, no persistent identifier. Nothing else. On the website and in
the application alike, the script is loaded from `api.pirsch.io` and the counts
are sent there: the browser contacts that domain directly, exposing its IP
address and user agent, which Pirsch uses as above and does not retain. It is
the one contact with a third party that always happens, and it does not depend
on what a document contains.

Since neither on the website nor in the application is there storage on the
terminal or access to information stored there, **no consent is required**
under Article 122 of Legislative Decree 196/2003. The processing of the resulting aggregate data rests on the
controller's legitimate interest (Article 6(1)(f) GDPR), against which the right
to object may always be exercised by writing to info@reactivenet.ai.

Many browsers send the *Do Not Track* or *Global Privacy Control* signal: Pirsch
honours it and does not count those visits.

## 4. The application: IndexedDB, and why it is not tracking

The ReactiveNET application saves, **in the user's browser**, via IndexedDB:

| What | Why |
| --- | --- |
| The documents of the apps installed in that browser | they are the apps: without them there is nothing to open |
| Collection rows (the data the apps gather) | it is the user's data, and it stays where they put it |
| Language, light/dark theme, chosen palette | so the choice need not be made again on every visit |
| Session credentials for shared spaces, for those who use them | so as not to sign in again on every visit |

These are all **technical purposes**: they deliver exactly the service the user
asked for by opening the app, and none of that information is sent to us or to
anyone else. They require no consent, and are described here so that users know
their device holds their data and that they are the ones who can erase it.

The project **does not use `localStorage` or `sessionStorage`**, as an
architectural rule. Anyone inspecting developer tools on `localhost` may see
entries written by other projects on the same port: they are not ours.

## 5. Service worker and offline use

The application is a progressive web app: a service worker keeps a local copy of
the interface files so that apps keep working without a network and open
quickly. The cache holds **application code**, not personal data and not user
content. It is cleared by uninstalling the app or clearing the site's data in
the browser.

## 6. Third-party requests that depend on the app's content

Some features, and only if a document uses them, trigger a request to an
external service. They are not tracking tools and store nothing on the device,
but the third party receives the IP address as it would for any visit to a site.

| Service | When | What it receives |
| --- | --- | --- |
| `tile.openstreetmap.org` (OpenStreetMap Foundation) | the document uses `::map` | IP address, user agent, the map area requested |
| `nominatim.openstreetmap.org` (OpenStreetMap Foundation) | the document looks up an address **and the local lookup did not find it** (address abroad, or a municipality with no ANNCSU coordinates) | IP address, user agent, **the text searched for** |
| `cdn.jsdelivr.net` (jsDelivr) | a `::python` block declares `packages` | IP address, package name |

An author who uses neither maps nor Python packages publishes an app that, apart
from the measurement in § 3, contacts nobody.

## 7. How to erase what is stored

- **From the app**: delete a single app from the gallery, or export it and then
  delete it; the data panel offers backup and deletion of collections.
- **From the browser**: settings → privacy → site data → `reactivenet.ai` →
  delete. This removes IndexedDB and the service worker cache.
  **Any app not saved elsewhere is lost**: it is on the device and we hold no
  copy of it.
- **Private browsing**: everything saved is erased when the window closes.

## 8. Changes

If the site or the app should one day use cookies or tools requiring consent,
this document will be updated **first** and consent will be collected through a
compliant mechanism, with the ability to refuse without losing access to the
content.

---

Version 1.2 — 14 August 2026. For the full picture of processing
operations see the «Privacy policy». In the event of any discrepancy between the
Italian and English versions, the Italian version prevails.
