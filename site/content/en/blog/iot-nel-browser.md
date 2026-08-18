---
title: "Apps meet the physical world: sensors, actuators and IoT"
description: "Eleven new directives connect Reactive documents to real devices: MQTT for sensors and actuators, Bluetooth LE, a serial port for Arduino and ESP32, NFC tags and the phone's own sensors — still no server, still nothing to install."
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

Until now a Reactive app worked on data typed in, imported, or fetched from the open-data service. From today it can **listen to the physical world**: a temperature sensor publishing over MQTT, a Bluetooth scale, an ESP32 plugged into USB, an NFC tag, the phone’s accelerometer. And it can **command it** too: a switch in the document that turns on a real light. As always, everything runs in the browser: no server to install, no account, data stays on the device.

## The principle: readings are data like any other

Every IoT directive pours its readings into the **reactive store** — a key for the latest value, a collection for the history — and from there everything Reactive already does applies: tables, aggregations, conditionals, Python charts, even the AI directives that summarize or answer questions about the data. A thermometer becomes a chart in three lines of text:

```md
::mqtt-sub[temp]{topic="home/living/temp" into="readings"}

Now: :value[temp] °C — average :avg[readings]{field="value"}

::python{data="readings"}
import matplotlib.pyplot as plt
plt.plot([float(r["value"]) for r in data["readings"]])
::/python
```

## MQTT: the universal channel

MQTT is the lingua franca of IoT — Home Assistant, Tasmota, ESPHome and virtually every microcontroller speak it. Three directives bring it into documents, in every browser:

- `::mqtt-sub` **subscribes a topic**: each message updates a key and/or is appended to a history collection (JSON payloads become row fields).
- `::mqtt-pub` **publishes on click**, with a fixed value or one taken from a field of the document.
- `::mqtt-bind` **binds a key to a topic both ways**: a `::toggle` in the document drives the actuator, and the state published by the device realigns the toggle.

The broker is declared once in the frontmatter (`mqttServer: wss://...`) and only endpoints travel in the document — **never credentials** — the same principle as sync keys.

## Bluetooth, serial, NFC: the device in front of you

For nearby objects you don’t even need a broker:

- `::ble` connects to a **Bluetooth LE** device (battery, heart rate, environmental sensors…) and receives live notifications; `::ble-write` sends commands — an LED on an ESP32 turns on from a line of Markdown.
- `::serial` reads the **USB port**: the lines an Arduino prints with `Serial.println` are appended to a collection (JSON lines become fields), `::serial-send` talks back. The perfect bridge between an electronics classroom and a living spreadsheet.
- `::nfc` reads **NFC tags** with the phone: surveys, inventories, attendance by tapping the phone on a tag.
- `::motion` and `::ambient-light` use the **phone’s sensors**: accelerometer and ambient light, live in the store.

The browser acts as the guarantor: Bluetooth, serial and NFC start **only from a user click**, never automatically.

## What about REST? `::iot-poll`

For devices exposing an HTTP API (Shelly, Tasmota, or any JSON service) there’s `::iot-poll`: it polls the endpoint at regular intervals and keeps the collection aligned with the current state. One practical caveat: the app is served over HTTPS, so local-network `http://` endpoints are blocked by the browser — for local traffic the MQTT broker remains the main road.

## What you can build

- **Home dashboard**: temperature and humidity over MQTT, toggles driving the lights, a Python chart of the daily trend — shared with the family through multi-user sync.
- **Classroom lab**: every desk with an ESP32 over USB, measurements appending into a table, live averages and charts; the document IS the lab report.
- **Inventory with a phone**: NFC tags on the shelves, `::nfc` into a collection, `::ai-classify` categorizing the items.
- **Workshop monitoring**: `::iot-poll` on smart plugs, thresholds with `::show`, an AI summary of the week’s consumption.

As with the rest of the platform, the editor helps: the new directives are **in the autocomplete** (with attributes and descriptions) and the AI assistant knows them and suggests them when you describe an app that talks to devices.

All the details are in the [syntax guide](/en/guida/sintassi/) and the [directives guide](/en/guida/direttive/).
