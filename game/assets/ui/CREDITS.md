# UI assets

## title_key_art.png — THIRD-PARTY MARKS AND LIKENESSES, supplied by the project owner

The title and wrestler-select background (`core/ui/title_screen.gd`,
`KEY_ART`), 1672x941, drawn cover-fit behind every phase of the title screen.

It carries **third-party trademarks** -- the AEW mark and the *Fight Forever*
title treatment -- and the **likenesses of two real performers**. It ships
with no licence, no author and no provenance, on the same terms as the ring
and arena artwork recorded in `assets/environment/CREDITS.md`: in the build
because `ARCHITECTURE.md` permits third-party assets, fine for a prototype
and for internal capture, and **not cleared for distribution**.

Used as supplied. The only processing is a lossless PNG re-save.

## lower_third_plate.png — supplied by the project owner

The ring-entrance name plate (`core/ui/entrance_lower_third.gd`, `PLATE`).
Supplied as a 2172x724 image with a transparency checkerboard PAINTED into
it -- it had no alpha channel. The checker was keyed out by flood-filling the
grey, low-saturation pixels connected to the image border (so the plate's
dark interior could not be eaten), eroding one pixel, feathering 0.8 px, and
cropping to the plate: 2103x455. No other processing. Ships with no licence
or author, on the same terms as the key art above.

# Fonts

## Teko (assets/fonts/Teko-Variable.ttf)

The entrance lower third's typeface, the owner's choice. **SIL Open Font
License 1.1** -- licence text alongside as `assets/fonts/OFL-Teko.txt`.
Copyright 2023 The Teko Project Authors
(https://github.com/googlefonts/teko); fetched from google/fonts, `ofl/teko`.
A variable font whose weight axis runs 300-700; the lower third uses 700,
Bold, which is Teko's heaviest -- there is no ExtraBold cut.
