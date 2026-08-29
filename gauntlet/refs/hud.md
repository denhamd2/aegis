# hud.md — measured, not remembered

Status: **seeded from static reference screenshots, plus one real gameplay
clip** (`gauntlet/refs/raw/video/wwe2k26_footage_01.mp4`, WWE 2K26, 30fps —
see `timings.md`). The clip confirms the promotional-still HUD layout below
matches actual gameplay (`hud/gameplay_hud_full.jpg`, a frame pulled
straight from the clip: star-rating meter top-left, corner vitality bars,
same green/red-segment damage rule) — but *fill animation* (easing,
flash-on-threshold, damage-tick delay) still needs frame-stepping a visible
damage event, not just a static pull, and stays pending below. Reference
crops: `gauntlet/refs/hud/vitality_bar_full_health.png`,
`vitality_bar_damaged.png`, `vitality_stamina_stacked.png`,
`match_quality_meter.png`, `tag_movelist_panel.png`,
`gameplay_hud_full.jpg`.

## Meter positions
- Health/vitality: bottom-left corner for the player-1-side wrestler,
  bottom-right for the player-2-side wrestler, inset a small margin from
  the screen edge — consistent across every screenshot in this corpus
  (2-wrestler singles and a 2v2 tag shot alike). This matches
  `MatchReferee`/HUD conventions this project should aim for (nothing here
  contradicts a simple corner-anchored layout).
- Momentum/finisher: not a separate on-screen meter in most shots — see
  "Fill animation behavior" below. `vitality_stamina_stacked.png`
  (Orton vs. Cena) is the one reference showing a second, stacked bar under
  vitality (blue/orange, partially filled) plus a small colored icon at the
  plate's bottom-left corner — read as a stamina-or-finisher-charge meter,
  not confirmed which from a still.
- Stamina (if present): see above — present in at least one HUD variant,
  absent (or merged into vitality) in others. The corpus isn't consistent
  enough to call this settled; likely a mode-dependent HUD (this project's
  MVP should default to the simpler single-bar-per-wrestler layout seen in
  `vitality_bar_full_health.png`).
- A separate **match-quality meter** (5-star rating + fill bar,
  `match_quality_meter.png`) appears top-left in one shot — a crowd/meta
  rating system, not a per-wrestler vitality readout. Out of scope for this
  project's MVP (`ARCHITECTURE.md` scope is the core match loop, not a
  post-hoc quality score) but noted so it isn't confused with a gameplay
  meter if it shows up in future footage.

## Sizes
- Each wrestler's name-plate + bar reads as roughly 15-20% of screen width,
  proportioned wider than tall (a squat rectangle, not a square icon) —
  consistent across every corner-HUD shot in the corpus.
- (pending — exact pixel/DPI-relative sizing needs a known reference
  resolution and a frame-stepped source, not a scaled promotional still)

## Colors
- Vitality bar: green when healthy. Damage is shown as a **revealed red
  segment** at the depleted end of the bar, not a full-bar recolor or
  gradient — compare `vitality_bar_full_health.png` (solid green) against
  `vitality_bar_damaged.png` (green remaining, red revealed at the
  depleted end). This is the one concrete, cross-shot-consistent color rule
  in this corpus.
- Secondary stamina/finisher bar: blue in one wrestler's HUD, orange in the
  other's, in the one shot that has it (`vitality_stamina_stacked.png`) —
  reads as a per-wrestler accent color rather than a fixed meaning-to-color
  mapping; not enough samples to call this a rule.
- Match-quality meter: gold stars on a dark background, gold fill bar.
- Name-plate background: dark, low-contrast panel behind white name text in
  every shot — legible against both the light ring mat and the darker
  crowd/entrance backgrounds seen across this corpus, which is the
  `VISUAL_BAR.md` "HUD legibility... across a full match's lighting range"
  bar in miniature (small supporting evidence, not a full verification —
  that still needs real in-match lighting range footage).

## Fill animation behavior
- Easing, flash-on-threshold, damage-tick delay: **(pending — needs
  frame-stepped video.)** A still can show that damage is a revealed
  segment (see Colors above) but nothing about how it animates getting
  there.
