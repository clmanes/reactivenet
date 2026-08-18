---
title: "Security policy"
translationKey: "legal-security"
description: "How the platform is protected, what the provider is unable to read, and how to report a vulnerability without risking consequences."
version: "1.0"
updated: "2026-08-13"
weight: 60
---

<!-- GENERATO da site/scripts/sync-legal.mjs — non modificare qui.
     La fonte è legal/en/security-policy.md: modifica quella e rilancia lo script. -->

Provided under Article 32 GDPR as regards technical and organisational measures,
and serving as a **coordinated vulnerability disclosure policy**.

## 1. The main security measure is an absence

App data stays in the browser of whoever uses it. There is no central store of
documents, no central store of rows, no telemetry. The risk of a mass breach of
users' data is reduced by construction, not by configuration: **an archive that
does not exist cannot be exfiltrated**.

What sits on our systems is little, and encrypted: the documents behind short
links and the changes in shared spaces, encrypted by the browser before they are
sent, with keys that never reach us.

## 2. Technical measures

**End-to-end encryption.** Shared spaces encrypt content on the device; the
server holds ciphertext and the metadata needed to distribute it. Revoking
access rotates the epoch key, so that the revoked member cannot read what is
written afterwards: what they have already read cannot be called back, and that
is a limit of cryptography, not a choice.

**Encrypted short links.** The document is sealed with AES-GCM; the key travels
in the address fragment, which the browser sends to no server. An attempt to
tamper with the blob fails authentication and is not imported.

**Defence against cross-site scripting.** This is the principal threat model,
because the platform's very function is turning text somebody wrote into HTML.
The defences are layered so that none is load-bearing on its own: unsafe URLs
are not representable in the type system; generated HTML must pass through
DOMPurify before it reaches the document; values saved by apps are inserted as
**text**, never as markup; a Content Security Policy with no `unsafe-inline` and
no `unsafe-eval` for scripts, with Trusted Types, closes the road to anything
that might slip past the earlier layers; expressions in documents are evaluated
by a purpose-written parser, not by `eval`.

**Isolation of Python execution.** Python code in documents is run by CPython
compiled to WebAssembly, in a separate worker, with a time limit after which the
worker is terminated: an accidental infinite loop does not take the application
with it.

**Transport and headers.** All traffic is over HTTPS with HSTS.
`X-Content-Type-Options`, `X-Frame-Options: DENY`, `frame-ancestors 'none'`,
`Referrer-Policy: no-referrer`, cross-origin isolation and a `Permissions-Policy`
disabling camera, microphone, geolocation and the other unused permissions are
all in force.

**Server-side access control.** Collection rules and service hooks check the
role of whoever writes: a read-only participant cannot write, and the refusal
happens on the server, not in the interface.

**Authentication.** Passwords are stored as hashes. Accounts are pseudonymous
and there is no browsable directory of users.

## 3. Organisational measures

System access is restricted to the provider, with multi-factor authentication
wherever the supplier offers it. Dependencies are updated periodically, and out
of turn whenever a vulnerability is published affecting a component in use.
Code changes go through a review of the diff, and the security rules described
above are covered by automated tests that fail the build — among them a check
that the policy served to static hosts matches the one declared in the
configuration, because a divergence there would be invisible to every local
check.

## 4. Reporting a vulnerability

Reports are welcome and taken seriously.

**Where**: security@reactivenet.ai
**Public key for encrypted messages**: not available

**What to write**: the component affected, the steps to reproduce, the impact
you believe it has and, if possible, a minimal proof of concept. Italian or
English are both fine.

**Timing**: acknowledgement within **5 working days**; assessment and a fix plan
within **30 days**; coordinated public disclosure, ordinarily no later than
**90 days** from the report or when the fix is available, whichever is sooner.
Reporters are credited publicly if they wish.

**No bounty**: there is no reward programme. This is not to devalue reporters'
work; it is so as not to promise what would not be honoured.

### 4.1 Scope

**In scope**: `reactivenet.ai` and the provider's subdomains, the ReactiveNET
application, the sharing and synchronisation services, the open-data service,
the MCP server, and the published source code.

**Out of scope**: third-party services (hosting provider, video conferencing
platform, OpenStreetMap, jsDelivr), apps written by users and their content,
social engineering against the provider or its clients, physical attacks,
resource exhaustion (denial of service), and reports produced by an automated
scanner without a demonstration of concrete impact — including the usual
findings about missing headers, advertised versions or accepted ciphers.

### 4.2 Commitment to reporters

For research conducted in good faith within the scope above, complying with the
rules below, the provider **will not pursue legal action** and will not report
the activity to the authorities, treating it as authorised:

- access only the data strictly necessary to demonstrate the vulnerability, and
  stop as soon as the demonstration is made;
- do not access, copy, modify or delete other users' data — if it happens
  incidentally, stop and say so in the report;
- do not degrade the service, and run no load or exhaustion testing;
- do not disclose the vulnerability before the agreed date;
- use only your own test data.

This commitment concerns the provider's own actions and cannot extend to third
parties' rights or to the assessments of the judicial authorities.

## 5. Personal data breaches

Where a breach entails a risk to people's rights and freedoms, the provider
notifies the **Italian Data Protection Authority within 72 hours** of becoming
aware of it (Article 33 GDPR) and, where the risk is high, informs the data
subjects without undue delay (Article 34 GDPR). Every breach, including those
not notifiable, is recorded with its circumstances, effects and the measures
taken.

Where the provider acts as a **processor** on behalf of a client, it informs the
controller **without undue delay and in any event within 24 hours** of becoming
aware of the event, with the information the controller needs to comply in turn.

## 6. `security.txt`

The following file should be published at
`site/static/.well-known/security.txt` and refreshed before it expires:

```
Contact: mailto:security@reactivenet.ai
Expires: 2027-08-13T00:00:00.000Z
Preferred-Languages: it, en
Canonical: https://reactivenet.ai/.well-known/security.txt
Policy: https://reactivenet.ai/note-legali/sicurezza/
```

---

Version 1.0 — 13 August 2026. In the event of any discrepancy between the
Italian and English versions, the Italian version prevails.
