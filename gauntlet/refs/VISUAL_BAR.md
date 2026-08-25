# VISUAL_BAR.md — one-page anchor

The single page every visual-quality gauntlet critic holds in mind. Keep it
short. Update it only from measured reference material (`gauntlet/refs/`),
never from memory of "what WWE games look like."

**Status: placeholder — fill in once `gauntlet/refs/frames/` has labeled
reference frames from Phase 1.**

## What "ours" must match, in priority order

1. Silhouette readability at match-camera distance (both wrestlers legible
   mid-grapple, not just in idle poses).
2. Lighting consistency: ring lighting reads as one scene, not
   independently-lit props.
3. Material believability at the resolution/distance the match camera
   actually uses — not close-up turntable quality.
4. HUD legibility against the ring background across the a full match's
   lighting range (entrance flash, ring lights, replay/finisher cuts).

## What it explicitly does not require

- Photorealism. The bar is WWE 2K's presentation *language* (framing,
  lighting consistency, HUD clarity), not its polygon/texture budget.
- Matching any specific WWE 2K wrestler's likeness, moveset, or branding —
  see the IP guardrail in `gauntlet/anchor/ARCHITECTURE.md`. A critic that
  flags "doesn't look like [real wrestler]" is out of scope by design.

## Known gap sources to check first

- Software-rendered (llvmpipe) captures cannot judge this bar — see
  ARCHITECTURE.md. Confirm the capture was GPU-backed before citing a
  visual gap.
