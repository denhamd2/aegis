# Character asset credits

## wrestler_base.glb / wrestler_base_root_motion.glb

Source: **Universal Animation Library** (Standard tier) by [Quaternius](https://quaternius.com)
([itch.io](https://quaternius.itch.io/universal-animation-library))

License: **CC0 1.0 Universal** (public domain dedication) —
https://creativecommons.org/publicdomain/zero/1.0/

No attribution is legally required, but Quaternius asks supporters to
consider https://www.patreon.com/quaternius.

This is the placeholder-quality retargeting base for Phase 3 (per
`gauntlet/anchor/ARCHITECTURE.md`) — 65-joint skinned humanoid rig, 43
included animations (locomotion, strikes, hit reactions, death/roll).
`_root_motion` has root displacement baked into the animation tracks;
the non-suffixed file has root motion disabled (in-place animations) for
use where the game code drives displacement instead.

This is a stand-in reference/base mesh only; the wrestler likenesses,
movesets and branding built on top of it are original. No WWE-derived
assets are used here.

## Drop-in slot: distinct superhero bodies (not yet downloaded)

`WrestlerController.body_variant` (0 = hair + headband, 1 = mask + eye band)
plus `physique_bulk` / `physique_height` already give the two men different
head identities, builds, and heights from the single mannequin above. When
real body variety is wanted, the CC0 slot is:

- **Universal Base Characters** by Quaternius (CC0 1.0) —
  https://quaternius.com/packs/universalbasecharacters.html
  (mirror: https://quaternius.itch.io/universal-base-characters).
  6 game-ready models (Superhero / Regular / Teen, M+F, ~13k tris), humanoid
  rig, glTF + FBX. Superhero Male is the wrestler-proportioned base.
- **Universal Animation Library 1 + 2** (CC0 1.0) for animation breadth —
  https://quaternius.com/packs/universalanimationlibrary.html.

To land a new base: export the chosen model as `.glb` next to this file
(e.g. `wrestler_superhero_b.glb`), keep bone names on the universal humanoid
rig (`pelvis`, `Head`, `calf_l/r`, `foot_l/r`, `lowerarm_l/r` — the names
`WrestlerAttire` and the IK rig resolve), reuse `wrestler_bone_map.tres`, and
point one `match.tscn` wrestler at it. Record the file, source URL, author,
and licence here at import time per `gauntlet/anchor/ARCHITECTURE.md`.
