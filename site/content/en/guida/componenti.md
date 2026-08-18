---
title: "Spectrum components"
description: "The 92 Adobe Spectrum components available as directives, with their typed attributes and the icons."
weight: 30
translationKey: "componenti"
---

Every Adobe Spectrum component is available as a directive under its own tag
without `sp-`: the slider is `::slider`, the badge is `::badge`, the accordion
is `::accordion`.

```markdown
::badge[Draft]{variant="neutral"}
::progress-bar{label="Volume" progress="#volume"}
::divider{size="m"}
```

And, where they have content, as a block with a body:

```markdown
::accordion{density="compact"}
::accordion-item{label="How does nesting work?" open}
Every close says what it ends.
::/accordion-item
::/accordion
```

Composition follows Spectrum's own: an accordion holds accordion items, a tab
group holds tabs, a menu holds menu items. There are no per-component special
cases.

## One registry, four consumers

A script reads the Custom Elements Manifests that ship with the library and
extracts **92 components and 482 attributes**, each of them typed: flag, number,
choice or text. A union of string literals in the manifest (`'text' | 'value'
| 'none'`) becomes a *choice* with its allowed values — and that is what makes
it possible to report a wrong value instead of leaving the element to ignore it
in silence.

From that one list come: the construction of the element and the validation of
its attributes, the list of what the sanitiser lets through, the blocks of the
block editor and the completions. Adding a component is a library upgrade, not a
code change.

ReactiveNET's directives are **in the same registry**, described in the same
shape, and they come first: a name that collided with a Spectrum component
resolves to the directive the renderer actually handles.

## The component documents its own attributes

The registry carries 482 of them across 92 components, generated from the
manifests, and the editor is the place to read them: typing `::` offers every
directive, typing `{` the attributes of that component with their types and
defaults, typing `="` the values a choice attribute allows. What is offered is
what works, because the list is the same one the renderer validates against.

A page listing them would be out of date the day the library is upgraded.

## The icons

`icon: calendar` in the frontmatter and `::page{icon}` draw from the same set of
Spectrum icons. How they are shipped is the interesting part: the elements are
not an option — 1096 custom elements are 4.3 MB. The *drawings* are extracted
into a single lazily loaded chunk and the *names* into a list the registry
offers as a choice, so a name outside the set is refused rather than drawing
nothing.
