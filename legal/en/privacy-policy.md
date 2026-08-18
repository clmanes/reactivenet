---
title: "Privacy policy"
translationKey: "legal-privacy"
description: "Who processes your data when you use ReactiveNET, which data, for how long and with what rights. The short answer: almost nobody, because the apps run in your browser."
version: "1.6"
updated: "2026-08-18"
---

# Privacy policy

Provided under Articles 13 and 14 of Regulation (EU) 2016/679 (the «GDPR») and
Italian Legislative Decree 196/2003 as amended by Legislative Decree 101/2018.

## 1. Data controller

**Cosimo Luigi Manes**, a natural person, running the ReactiveNET project in a
personal capacity and not as a business
Address: Via Gherardo Robertoni, 5 — 73012 Campi Salentina (LE), Italy
Tax code: MNSCML86R23B506P
Email: info@reactivenet.ai

No Data Protection Officer has been designated: the processing falls under none
of the cases in Article 37(1) GDPR, as there is neither regular and systematic
monitoring on a large scale nor large-scale processing of special categories of
data. For any matter concerning personal data, write directly to the controller
at the addresses above.

## 2. The principle that explains most of this policy

ReactiveNET is a platform for building applications that **run inside the
browser of the person using them**. The documents describing the apps, and the
data those apps collect, are saved in the browser's local storage (IndexedDB) on
the device: **they do not pass through us, are not copied to our servers, and we
have no access to them**. The only thing the application measures is the visit,
in aggregate form and through Pirsch Analytics (§ 3.2); documents, collection
rows and content still never pass through the controller, and there is no code
that would make them do so.

It follows that, for ordinary use of the app, the controller **processes no
personal data**. What remains are the processing operations described below,
which concern the website and a few optional features.

Anyone who builds an app with ReactiveNET and uses it to collect other people's
data is an independent controller of that processing: see § 3.11.

## 3. Processing operations, purposes and legal bases

### 3.1 Browsing reactivenet.ai

For the operation and security of the service, the hosting provider records
technical request logs: IP address, date and time, resource requested, response
code, user agent, referrer.

- **Purpose**: serving the requested pages, diagnosing faults, detecting and
  countering abuse and attacks.
- **Legal basis**: the controller's legitimate interest in the security and
  continuity of the service (Article 6(1)(f) GDPR).
- **Retention**: 30 days, save for such further time
  as is needed to establish an abuse already detected.

### 3.2 Traffic statistics (Pirsch Analytics)

The website reactivenet.ai and the application app.reactivenet.ai measure
visits with **Pirsch Analytics**, a service of Emvi Software GmbH (Germany),
configured without cookies and without any storage on the device. Pirsch does
not retain the IP address: it uses it, together with the user agent, to compute
a non-reversible digest with a random element regenerated every day, which
serves only to avoid counting the same visit twice within the same day and
which the following day can no longer be linked to anything. Data is processed
and stored on servers located in Germany. On the website and in the application
alike, the browser loads the measurement script from `api.pirsch.io` and sends
the counts there, so it contacts that domain directly: in doing so it exposes
its own IP address and user agent, which Pirsch uses as described above and does
not retain. No document and no app data travels in that request. Pirsch acts as
a processor.

- **Data**: page visited, referrer, date and time, country, device type, browser
  and operating system, language; on the website, pressing certain buttons
  (opening the platform, opening or downloading a catalogue app, copying the
  MCP address, the GitHub and LinkedIn links) is counted as an anonymous event,
  with no data about who pressed it.
- **Purpose**: knowing, in aggregate form, which content is read, so as to decide
  what to write and what to fix.
- **Legal basis**: the controller's legitimate interest in aggregate measurement
  of its own site (Article 6(1)(f) GDPR). No consent is required under Article
  122 of Legislative Decree 196/2003 because there is neither access to
  information stored on the terminal nor any persistent identifier: see the
  cookie policy.
- **Retention**: aggregate data, kept for 24 months.

### 3.3 Using the application

No processing by the controller of documents and data. Documents, collection
rows, and language, theme and palette preferences stay in IndexedDB on the
device. They are deleted from within the app itself or by clearing the site's
data in the browser. The one exception is the aggregate visit statistic
described in § 3.2.

### 3.4 Sharing links

An app can be shared in two ways.

The **long link** carries the whole document in the address *fragment* (the part
after `#`), which by the way the web works **is never sent to any server**:
whoever receives the link receives the app, and no intermediary records its
contents.

The **short link** deposits the document on one of our servers, **encrypted by
the browser before it is sent** (AES-GCM): the key travels in the link fragment
and never reaches us. What remains on the server is an unreadable blob, an
identifier, and the date it was last opened.

- **Data**: the document's content, encrypted and not accessible to the
  controller; the date it was last opened; technical logs as in § 3.1. If the
  author puts personal data in the document, that data is inside the encrypted
  blob and the controller is unable to read it.
- **Purpose**: allowing an app to be shared with a short address.
- **Legal basis**: performance of a service requested by the data subject
  (Article 6(1)(b) GDPR).
- **Retention**: **120 days from the last time it was opened**, then automatic
  deletion. A link never reopened expires 120 days after it was created.

### 3.5 Accounts and shared spaces

Anyone wishing to synchronise an app between several people creates an account
on our service. The account is **deliberately pseudonymous**: we do not ask for
an email address, there is no browsable directory of users, and each person sees
only their own profile. Members of a space can see the chosen display name and
public key of those who share it with them.

Synchronised content (document and rows) is **end-to-end encrypted** by the
browser: the server holds ciphertext it cannot decrypt, plus the metadata needed
to make it work — who wrote a change, when, in which space, with which role.

- **Data**: chosen username, password (stored as a hash), display name, public
  key, memberships and roles, encrypted changes with their date and author,
  technical logs as in § 3.1.
- **Purpose**: providing synchronisation and access control.
- **Legal basis**: performance of the contract with the data subject (Article
  6(1)(b) GDPR).
- **Retention**: for the life of the account. Deletion of the account or of a
  space is requested from the controller and entails erasure of the related data
  within 30 days.
- **Warning**: the password is the only key to the encrypted content. Anyone who
  loses it without the recovery code loses access to their shared spaces. There
  is no reset procedure, because any such procedure would be a back door into
  the encryption, and so there is none.

### 3.6 Open-data service

The `::od-*` directives query a service of ours that exposes Italian public
datasets, read-only. The requests contain the (parameterised) query and no app
data: **rows saved on the device are not sent**. The service records technical
logs as in § 3.1, for capacity and security.

- **Legal basis**: legitimate interest in the security and continuity of the
  service; performance of the data subject's request as regards the query itself.
- **Retention**: 30 days.

### 3.7 Maps and address lookup

A document using the `::map` directive downloads map tiles from
`tile.openstreetmap.org`, a service of the **OpenStreetMap Foundation** (United
Kingdom): their server receives the device's IP address and the user agent.

**Geocoding — turning an address into coordinates — looks locally first.** The
coordinates of Italian street numbers come from the national street and
house-number archive (ANNCSU), which is hosted on our own data service: for an
Italian address in a municipality the archive covers, **the text searched for
never leaves this infrastructure and no third party receives it**.

Only when the local lookup finds nothing — an address abroad, or in one of the
municipalities for which ANNCSU carries no coordinates — does the request go on
to `nominatim.openstreetmap.org`, and in that case their server receives the IP
address, the user agent and **the text of the address being searched**. This
happens only for documents that use that feature, and the controller receives no
copy of those requests. The OpenStreetMap Foundation's own privacy policy and
usage policy apply.

### 3.8 Python packages

A `::python` block declaring `packages` downloads the requested packages from
`cdn.jsdelivr.net` (jsDelivr). The Python interpreter is served from our own
site; additional packages are not, because they weigh as much as the whole
application. The CDN receives the device's IP address and the name of the
package requested. No code and no app data leave the device: the Python code is
executed locally, in WebAssembly inside the browser.

### 3.9 MCP server

The MCP server lets an AI assistant write and check an app. It is a service of
pure functions: it receives the text of the document to validate and returns the
result, **storing nothing** and with no access to any browser. Technical logs as
in § 3.1 remain.

### 3.10 The AI assistant inside the application

The application contains an assistant that writes apps on request. It is **off
until it is configured**, and how it is configured decides whether anything
leaves the device at all:

- **A model on your own computer** (Ollama, say, listening on `localhost`): the
  conversation never leaves the machine. There is no provider, there is no key,
  and the controller receives nothing.
- **A remote provider** (`https://api.openai.com` by default, or any other
  address you enter): the user's browser talks to that provider **directly**.
  The controller is not in the middle, receives no copy of the conversations and
  keeps no record of them.

With a remote provider, what goes to that provider is: the question as written,
the whole conversation so far, and — when the assistant consults them in order
to answer — **the list of apps in this browser and the complete text of the open
app's document**. Anyone keeping personal data inside an app's *document* should
know that asking the assistant to change that app means sending its text to that
provider.

**The `ai-*` directives inside an app use the same model, and with a remote
provider they also send rows.** These are the directives with which an app can
summarise a collection, answer questions about its own data, fill a form from a
sentence, classify rows, rewrite a text or search by meaning. What travels
depends on the directive, and is in every case **a sample of the rows** rather
than the whole collection:

- the text of the field or row the directive is working on;
- a sample of the rows of the collections the directive declares it reads;
- for semantic search, the text of the rows and **the textual content of the
  attachments** named, sent once to build the index, which is then kept on that
  device only;
- for describing an image, the image itself.

With a **model on your own computer**, none of this leaves the machine. For apps
handling personal data — and all the more so special categories of data — that
is the only configuration the controller recommends, and it is why the local
model is offered as an equal choice rather than as a curiosity.

An app containing no `ai-*` directives sends **no** rows: outside those
directives the assistant does not read the saved rows (§ 3.11).

The API key is the user's own and stays **in IndexedDB on that device**: it is
never sent to the controller, who cannot see it and could not recover it. Treat
it as a credential on your own machine — anyone sharing a computer, or importing
third-party apps containing code (`::python`) into their browser, should choose
the local model, which has no key at all.

That processing is governed by the privacy policy of the chosen provider and the
controller is not a party to it. The assistant's requests to the MCP server
(§ 3.9) carry the text of the document to be checked and nothing else.

### 3.11 Data collected by apps built by users

Anyone who builds an app with ReactiveNET and uses it to collect other people's
data — a registration form, a register, a contact list — is an **independent
controller** of that processing: they choose the purposes and means, and the
information notice, the legal basis, the retention periods and the answers to
data subjects' requests fall on them. The platform's controller has no access to
that data and is unable to act on it. Where such an app is synchronised in a
shared space, the platform's controller acts as a **processor** for the sole
purpose of storing the encrypted data: that relationship is governed by the
Article 28 GDPR data processing agreement, available on request.

### 3.12 Contact requests

Anyone writing to the controller — for information, reports, or to exercise
their rights — provides the data contained in their message.

- **Purpose**: replying and, where appropriate, acting on the request.
- **Legal basis**: legitimate interest in responding to requests received;
  pre-contractual measures at the data subject's request where the message
  concerns an offer.
- **Retention**: two years from the last exchange, unless the correspondence
  documents a contractual relationship.

## 4. Whether providing data is required

No data need be provided to read the website or to use the application. The data
marked as required in § 3.5 must be provided to create an account: without it
the service cannot be provided.

## 5. Recipients and processors

Data is neither sold nor transferred to third parties. It may be processed, on
our behalf and on our documented instructions, by the providers essential to
delivering the services, appointed as processors under Article 28 GDPR:

| Provider | Role | Where |
| --- | --- | --- |
| Aruba S.p.A. | hosting of the website, of the application and of the sharing, synchronisation and open-data services, technical logs, email | Italy |
| Emvi Software GmbH (Pirsch Analytics) | website and application traffic statistics | Germany |

Data may also be disclosed to public authorities where disclosure is required by
law or requested in the forms provided by law.

An up-to-date list of processors is available on written request to the
controller.

## 6. Transfers outside the European Union

Services are hosted in the European Union and the processors listed above are
established there: the controller carries out no transfer of personal data to
third countries. Should a transfer become necessary, it would take place on the
basis of a European Commission adequacy decision, where applicable, or of the
standard contractual clauses under Implementing Decision (EU) 2021/914, together
with the supplementary measures assessed case by case, and this notice would be
updated before the transfer took place. A copy of the safeguards can be obtained
by writing to the controller.

The same holds, more markedly, for the AI provider chosen in the assistant
(§ 3.10): the user enters the address, the user's browser sends the conversation
with the user's own key, and the controller is neither a party to that
processing nor able to observe it. Anyone who wants no transfer at all should
use a model on their own computer, as described in that section.

Requests to OpenStreetMap (§ 3.7) and jsDelivr (§ 3.8) are not transfers carried
out by the controller: they are requests the user's browser makes directly to
those services when the document being opened calls for them.

## 7. Automated decision-making and profiling

There is none. No data is used to build profiles, for advertising profiling, or
for automated decisions producing legal effects or similarly significantly
affecting people.

## 8. Children

The services are not directed at children under fourteen and do not solicit
their data. A parent or guardian who believes a child has provided data may
write to the controller: the data will be erased without delay.

## 9. Security

The technical and organisational measures adopted under Article 32 GDPR are
described in the «Security policy», which forms an integral part of this notice:
end-to-end encryption of synchronised content, encryption in transit, output
sanitisation and a Content Security Policy with Trusted Types, structural
minimisation (data stays on the device), and system access limited to the
controller.

## 10. Data subjects' rights

The rights of access (Article 15), rectification (Article 16), erasure
(Article 17), restriction (Article 18), portability (Article 20) and objection
(Article 21) are recognised, the last in particular with regard to processing
based on legitimate interest.

They are exercised by writing to info@reactivenet.ai. A reply is given
without undue delay and in any case within one month, extendable by two months
for complex requests, with notice of the extension.

One limit must be stated plainly: **for end-to-end encrypted content and short
links the controller can neither read nor rectify anything**, because it does
not hold the keys. It can delete them, and does so on request.

The right remains to lodge a **complaint with the Italian Data Protection
Authority** (Garante per la protezione dei dati personali, Piazza Venezia 11,
00187 Rome — garante@gpdp.it) or to bring proceedings before the courts.

## 11. Changes

This notice may be updated when services or providers change. The version and
date at the top say what you are looking at; substantial changes are
communicated to registered users before they take effect.

---

Version 1.4 — 14 August 2026. In the event of any discrepancy between the
Italian and English versions of this document, the Italian version prevails.
