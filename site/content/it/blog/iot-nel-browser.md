---
title: "Le app incontrano il mondo fisico: sensori, attuatori e IoT"
seotitle: "Sensori, attuatori e IoT nel browser"
description: "Undici direttive collegano le app ai dispositivi reali: MQTT, Bluetooth LE, porta seriale per Arduino ed ESP32, NFC e i sensori del telefono. Senza server."
date: 2026-07-16
author: "Cosimo Luigi Manes"
translationKey: "iot-nel-browser"
cover: "/img/blog/iot-nel-browser.jpg"
coverAlt: "Nerd-Tographer Desk Ornament"
coverAuthor: "Zach Dischner"
coverAuthorUrl: "https://www.flickr.com/photos/35557234@N07"
coverSource: "https://www.flickr.com/photos/35557234@N07/9698639550"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Finora un’app Reactive lavorava su dati scritti a mano, importati o arrivati
dal servizio dati open. Da oggi può **ascoltare il mondo fisico**: un
sensore di temperatura che pubblica via MQTT, una bilancia Bluetooth, un
ESP32 collegato via USB, un tag NFC, l’accelerometro del telefono. E può
anche **comandarlo**: un interruttore nel documento che accende una luce
vera. Come sempre, tutto nel browser: nessun server da installare, nessun
account, i dati restano sul dispositivo.

## Il principio: le letture sono dati come gli altri

Ogni direttiva IoT riversa le letture nello **store reattivo** — una chiave
per l’ultimo valore, una collezione per lo storico — e da lì in poi vale
tutto quello che Reactive sa già fare: tabelle, aggregazioni, condizionali,
grafici Python, perfino le direttive AI che riassumono o rispondono a
domande sui dati. Un termometro diventa un grafico con tre righe di testo:

```md
::mqtt-sub[temp]{topic="casa/salotto/temp" into="letture"}

Adesso: :value[temp] °C — media :avg[letture]{field="value"}

::python{data="letture"}
import matplotlib.pyplot as plt
plt.plot([float(r["value"]) for r in data["letture"]])
::/python
```

## MQTT: il canale universale

MQTT è la lingua franca dell’IoT — la parlano Home Assistant, Tasmota,
ESPHome e qualunque microcontrollore. Tre direttive la portano nei
documenti, su qualsiasi browser:

- `::mqtt-sub` **sottoscrive un topic**: ogni messaggio aggiorna una chiave
  e/o si accoda a una collezione-storico (i payload JSON diventano campi).
- `::mqtt-pub` **pubblica al click**, con un valore fisso o preso da un
  campo del documento.
- `::mqtt-bind` **lega una chiave a un topic in due direzioni**: un
  `::toggle` nel documento comanda l’attuatore, e lo stato pubblicato dal
  dispositivo riallinea il toggle.

Il broker si dichiara una volta sola nel frontmatter (`mqttServer: wss://...`) e nel documento viaggiano **solo endpoint, mai credenziali** —
lo stesso principio delle chiavi di sincronizzazione.

## Bluetooth, seriale, NFC: il dispositivo davanti a te

Per gli oggetti vicini non serve nemmeno il broker:

- `::ble` si collega a un dispositivo **Bluetooth LE** (batteria, frequenza
  cardiaca, sensori ambientali…) e riceve le notifiche in tempo reale;
  `::ble-write` invia comandi — un LED su un ESP32 si accende da una riga
  di Markdown.
- `::serial` legge la **porta USB**: le righe stampate da un Arduino con
  `Serial.println` si accodano in collezione (le righe JSON diventano campi),
  `::serial-send` risponde. È il ponte perfetto tra un’aula di elettronica
  e un foglio di calcolo vivo.
- `::nfc` legge i **tag NFC** col telefono: censimenti, inventari,
  registrazione presenze appoggiando il telefono al tag.
- `::motion` e `::ambient-light` usano i **sensori del telefono**:
  accelerometro e luminosità ambientale, in diretta nello store.

Il browser fa da garante: Bluetooth, seriale e NFC partono **solo da un
click dell’utente**, mai in automatico.

## E il REST? `::iot-poll`

Per i dispositivi che espongono un’API HTTP (Shelly, Tasmota, o qualunque
servizio JSON) c’è `::iot-poll`: interroga l’endpoint a intervalli regolari
e tiene la collezione allineata allo stato corrente. Un’avvertenza pratica:
l’app è servita in HTTPS, quindi gli endpoint `http://` di rete locale sono
bloccati dal browser — per il traffico locale il broker MQTT resta la via
maestra.

## Cosa ci si costruisce

- **Cruscotto di casa**: temperatura e umidità via MQTT, toggle che
  comandano le luci, grafico Python dell’andamento giornaliero — condiviso
  in famiglia con la sincronizzazione multi-utente.
- **Laboratorio in classe**: ogni banco con un ESP32 via USB, le misure che
  si accodano in tabella, medie e grafici in tempo reale; il documento È la
  relazione di laboratorio.
- **Inventario col telefono**: tag NFC sugli scaffali, `::nfc` in
  collezione, `::ai-classify` che categorizza gli articoli.
- **Monitoraggio di officina**: `::iot-poll` sulle prese smart, soglie con
  `::show`, riassunto AI dei consumi della settimana.

Come per il resto della piattaforma, l’editor aiuta: le nuove direttive
sono **nell’autocompletamento** (con attributi e descrizioni) e l’assistente
AI le conosce e le propone quando descrivi un’app che parla coi dispositivi.

Tutti i dettagli nella [guida alla sintassi](/guida/sintassi/) e nella
[guida alle direttive](/guida/direttive/).
