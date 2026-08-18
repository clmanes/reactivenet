---
title: "Describe the part, the AI draws it: Reactive's CAD becomes a configurator"
seotitle: "Reactive's CAD becomes a configurator"
description: "The ::cad directive gains automatic sliders, print dimensions and weight, SVG/DXF export for laser cutting, and an AI bar that rewrites the OpenSCAD code."
date: 2026-07-20
author: "Cosimo Luigi Manes"
translationKey: "design-with-ai"
cover: "/img/blog/design-with-ai.jpg"
coverAlt: "painter's house, isfahan, iran october 2007"
coverAuthor: "seier+seier"
coverAuthorUrl: "https://www.flickr.com/photos/94852245@N00"
coverSource: "https://www.flickr.com/photos/94852245@N00/2087845614"
coverLicense: "CC BY"
coverLicenseUrl: "https://creativecommons.org/licenses/by/2.0/"
---

Five days ago the `::cad` directive brought [parametric 3D parts to the browser](/en/blog/pezzi-3d-nel-browser). Today it levels up: from generator to **interactive configurator**, with one addition that changes how you design altogether — **describe the part in plain language, and the AI writes the OpenSCAD code for you**.

## Sliders build themselves

OpenSCAD has always had a standard syntax for declaring adjustable parameters: the _customizer_ annotations. Reactive now reads them and builds the controls on its own:

````md
::cad{data="boxes"}
```
w = 30;        // [10:100]
wall = 2.4;    // [0.8:0.4:5]
kind = "hex";  // [hex, round, square]
lid = true;
cube([w, w, 20]);
```
::/cad
````

`w` becomes a **slider** from 10 to 100, `wall` a slider with a 0.4 step, `kind` a **select**, `lid` a **toggle**. Drag, and the part regenerates — without losing your viewpoint: the camera stays put while the part changes under your eyes. The form wired to the collection remains the place for saved configurations: add a row and the sliders jump to its values.

## Dimensions, volume and grams of filament

Below the preview there’s now a chip with the part’s **bounding box**, its **volume** and the **estimated PLA weight** — handy to see at a glance how much filament a print will cost. Downloads got more honest too: the preview runs in fast mode (`$preview`, like OpenSCAD’s F5), while “Download STL” always does a **final full-quality render**.

## From 3D to laser cutting: `mode="2d"`

Not everything gets printed: plenty gets cut. With `mode="2d"` the directive takes flat geometry (`square`, `circle`, `polygon`, `projection()`…) and exports **SVG and DXF** instead of STL — the formats laser cutters and CNC routers expect:

````md
::cad{mode="2d"}
```
side = 40; // [20:120]
difference() {
  square([side, side/2], center=true);
  circle(d=side/4);
}
```
::/cad
````

Same reactivity, same sliders, SVG preview with dimensions in millimetres.

## Describe the part, the AI draws it

The biggest addition is the **AI design bar**: with `ai="true"` a text field appears under the block. Type _“add 4 through holes, 3mm, near the corners”_ and the assistant’s AI engine — the one you already know from the chat: an in-browser model, local Ollama, or a compatible API — **rewrites the OpenSCAD code**, streaming it in front of you.

The clever part is what travels with your request without you thinking about it: the current code, the current parameter values and — if the render failed — **the last OpenSCAD error**. “It doesn’t compile” becomes “ask the AI to fix it”. And the model is instructed to expose dimensions as customizer annotations: generated code arrives **with its sliders already built**.

The AI’s code never touches the document: it lives alongside the app’s data, and the “Original code” button restores the author’s version in one click. In our tests, _“add 4 holes near the corners”_ produced the four holes — plus three new sliders (`hole_r`, `inset`, `extra_len`) to tune them.

## File import, too

A field uploaded with `::file` in a collection declared in `data` lands in the engine’s filesystem, and the variable carries its name: in the code, just `import(drawing);` to customize a user-uploaded model — an engraving on an STL base, an SVG outline to extrude.

All of it, as always, in a Markdown document: no server, no install, and the OpenSCAD engine (~10MB) downloads from the CDN only on first use and stays cached for offline. Open the [app](https://app.reactivenet.ai), drop in a `::cad` block and try asking for a part.
