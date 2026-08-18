---
title: "3D comes to your apps: models, augmented reality and printable parts"
description: "Two new directives bring the third dimension to Reactive: ::model displays 3D models with an augmented-reality view, ::cad generates parametric parts with OpenSCAD — a form becomes the parameter panel and the STL is ready for your printer."
date: 2026-07-15
author: "Cosimo Luigi Manes"
translationKey: "pezzi-3d-nel-browser"
cover: "/img/blog/pezzi-3d-nel-browser.jpg"
coverAlt: "BEETHEFIRST personal 3D printer"
coverAuthor: "Creative Tools"
coverAuthorUrl: "https://www.flickr.com/photos/33907867@N02"
coverSource: "https://www.flickr.com/photos/33907867@N02/13603739274"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Reactive apps gain the third dimension. From today a document can **display interactive 3D models** — with an augmented-reality view on supported devices — and, above all, **generate parametric 3D parts** with OpenSCAD, right in the browser, ready to download as STL for your 3D printer. As always: one line of text, no server, nothing to install.

## A 3D model in one line: `::model`

The `::model` directive shows a glTF/GLB model inside the app: rotate it with a finger or the mouse, zoom in, and on compatible phones a button places it in **augmented reality**, right on your table:

```
::model{src="https://example.com/statue.glb" alt="Roman statue"}
```

For AR on iPhone and iPad just add the USDZ variant (`ios-src="statue.usdz"`). The viewer is downloaded only by documents that use it, and `src` can be a reactive reference: a dropdown that switches models, a catalog that shows the selected piece.

## Parametric parts with OpenSCAD: `::cad`

The big one. OpenSCAD is the makers’ language for describing solids with code; Reactive runs it **in the browser** (WebAssembly) and wires it into its reactive system. The code lives in a block inside the directive, like `::python` — and the fields of the **last row** of the collections declared in `data` become variables of the code:

````
::form{path="box" id="p"}
::input{form="p" field="w" type="number" placeholder="Width"}
::input{form="p" field="h" type="number" placeholder="Height"}
::add-form{form="p" path="box" label="Generate"}
::/form

::cad{data="box"}
```
w = 30; h = 20;
cube([w, h, 10], center=true);
```
::/cad
````

The form becomes the **part’s parameter panel**: enter width and height, hit Generate, and the model regenerates in the interactive 3D preview. The button next to it downloads the **print-ready STL**. Assignments in the code (`w = 30;`) act as defaults while the collection is empty.

Nothing of the language is missing: **fonts** for `text()` (engravings, labels) and the **MCAD** and **BOSL2** libraries (gears, threads, screws) are already mounted. The engine (~10MB) downloads on first use and stays cached: from then on it works offline too.

## What you can build with it

- **The counter-top configurator** — a craftsman or a small workshop describes the part once (a bracket, a spacer, a custom box) and the customer fills in three fields: the STL comes out without anyone opening a CAD program. With sync enabled, customer requests become rows of a shared collection.
- **The technology class** — in one lab hour every student starts from the same document, changes the parameters, watches the solid take shape and brings their own keychain to the school printer. Geometry you can touch.
- **The catalog with an in-home preview** — a furniture maker or a ceramist shows pieces with `::model`: customers rotate them, zoom in and place them in augmented reality on their own table before ordering.
- **The spare part you can’t find anywhere** — the broken knob, the discontinued hook: describe it once with four parameters and reprint it whenever needed, in whatever size is needed.

## And the editor writes with you

Alongside 3D comes **autocompletion** in the editor: typing `:` picks directives from a menu with descriptions and pre-filled snippets (Tab jumps between fields), inside braces the right attributes for each directive are suggested, in the frontmatter the app keys — and inside a `::cad` block the completion speaks OpenSCAD: `cube`, `cylinder`, `difference`, the transforms and the special variables, signatures at a glance.

All of this is already in the app: [open it](https://app.reactivenet.ai) and try the syntax in the [guide](/en/guida/sintassi/), or start from the [directives guide](/en/guida/direttive/).
