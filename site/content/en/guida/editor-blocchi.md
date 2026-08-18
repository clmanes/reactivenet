---
title: "Block editor"
description: "The same directives edited as blocks, with the slash menu, drag and drop and the frontmatter as a form."
weight: 40
translationKey: "editor-blocchi"
---

The same document is written in two ways: as Markdown source, or as blocks in
the style of Notion. **The two editors are never mounted together** — it is an
invariant the code enforces and a test verifies.

In the block editor the directives and the frontmatter are **real blocks**: they
are created, edited and deleted like any other, from the slash menu, from the
block handle, or by dragging them. Every component in the registry has its own
block, `:value` is inline content, and the frontmatter is a block of its own.

## Nesting is indentation

Anything indented under a component block becomes its content, and that block is
written back as a container. There is nothing to declare in advance: a block
inserted from the slash menu is born a leaf, and becomes a container the moment
something ends up underneath it.

## The frontmatter becomes a form

In block mode the frontmatter is edited as a form, from the ⓘ button in the bar,
and the editor receives the body alone.

This is not a convenience: the block editor has no way to represent a
frontmatter block, and putting one through its Markdown converter would turn it
into a paragraph or a horizontal rule. The form belongs to block mode alone — in
Markdown mode the block is right there in the text, and a second way to edit it
would be two truths about the same data.

The order of the keys and the quotes are preserved: `version: "1.0"` stays a
string and does not become the number one.

## The price: the conversion is by hand

The block editor's Markdown converter knows none of these types and escapes what
it does not recognise, so **both directions are written by hand**, block by
block, delegating to the editor only for ordinary blocks. Markdown → blocks
splits the source on the directives it finds; blocks → Markdown renders ours and
calls the converter for the rest. A container's body is parsed by recursing into
our own splitter, not by handing it to the editor, which would make literal text
of it.

## What is lost, and why it is not a defect to fix

The conversion to blocks is **lossy in both directions** — the library's API is
literally called `blocksToMarkdownLossy`. Running a document through the blocks
turns `$$` math and anything else without an equivalent block into ordinary
paragraphs, and it shows immediately in the preview.

It is inherent to the library, not a ReactiveNET bug. Anyone working on a
document full of math or exotic directives treats it as Markdown source, and
that is why both editors exist.

A paragraph containing an inline directive is rebuilt by hand, because the
editor would drop the node: inside *that* paragraph the character formatting is
lost. It is the narrowest place to pay the price.
