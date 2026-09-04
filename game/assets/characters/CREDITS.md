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

## Reference: user-supplied brawler stills (measurement only)

Two user-supplied character stills (full body + head close-up) serve as the
visual bar for the variant-2 brawler outfit, the same way WWE 2K footage
serves `gauntlet/refs/` as measurement: framing, palette, and silhouette
proportions are matched, with no text or branding reproduced. Output is
procedural BoneAttachment3D geometry + flat materials (buzz hair, procedural
face boxes, denim shorts, striped waistband, green bands, steel chain collar
+ dog tags, black/white boots) on the CC0 mannequin. Face placement rests on
one documented assumption (WrestlerAttire.FACE_FORWARD); a capture must
confirm which way the Head bone faces before the face is judged.

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

## roman_reigns.glb (wired through scenes/roman_match.tscn)

Source: **user-supplied Google Drive file** (a "ROMAN REIGNS" `.blend` +
texture set, author and licence unknown — supplied by the repo owner, not
downloaded from a store). Converted with Blender 4.2.23 to
`roman_reigns.glb` (cameras/lights stripped, both armatures kept, no
animations — the file carries none); Godot extracts the 14 embedded
textures as the sibling `roman_reigns_*.png` files on import.

Contents (verified in-engine): 19 skinned meshes (body, head, hair, eyes,
teeth, top/bottoms, shoes, wrists), **two** armatures — 114 bones and 471
bones (hair chains) — standing ~1.85m, so scale already matches the game's
1.8m subject. Bone names are `J_`-prefixed (`J_Hips`, `J_Spine1`, ...), NOT
the universal rig names above. `roman_model.tscn` adapts the two-armature
asset, maps the `WrestlerAttire`/IK bone lookups, and retargets the game's
animation clips (none ship with this model). It maps
the shared animation library onto both Roman skeletons and `roman_match.tscn`
makes the asset playable. The supplied asset's author and licence remain
unknown and must be confirmed before redistribution.
