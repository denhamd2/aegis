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

## Roman face findings (measured off roman_reigns.glb, fixed at runtime)

Parsed the shipped binary rather than guessing from renders (19 meshes,
16 materials, 14 images, 114-bone body + 471-bone hair rigs):

- `M_Head` carries ONLY `wrinkles_normal`; the face colour map (`Image`:
  brows, beard stubble, lips, Samoan tattoo layout, verified by viewing)
  is embedded but referenced by NOTHING. `headhair_mask` is likewise
  orphaned.
- The `beard` material and all four hair materials point albedo at
  `*_rai` PACKED DATA textures (green and alpha channels all zero across
  all 4M pixels; red/blue hold roughness-ish values). Result: magenta
  beard, purple hair, and the three BLEND hair masses sample the zero
  alpha and vanish. (`M_Hair_Entrance` is OPAQUE, so it stays visible.)
- `M_EYE` has no texture and no vertex colours (all vertex colours in the
  file are pure white): flat glossy-white eyeballs, roughness 0.
- `M_Teeth` / `M_Tongue` / `M_MouthBag` have NO material: default grey.
  Eye bones (`J_Eye_L/R`) and teeth/tongue bones exist; the base animation
  library drives none of them (the base rig has no such bones either).
- All seven `*_nrm` textures import without the normal-map flag, so their
  vectors decode as sRGB colour.
- `BONE_MAP` had no `spine_01` entry although `J_Spine1` exists, so every
  base animation driving it was silently discarded.

`roman_model.gd` corrects all of it at runtime (the .glb is user-supplied
and is never hand-edited): orphan face map restored onto the head,
data-texture albedo links replaced with flat colours + forced opaque
double-sided, geometric iris/pupil spheres on the eye bones from
bind-pose-measured offsets (eyeballs ~2.5cm, bone ~6mm behind mesh
centroid), flat teeth/mouth materials. `.import` sidecars carry the
normal-map flags. Covered by `test_roman_model.gd` (BONE_MAP + remapped
tracks, iris/pupil attachments at measured offsets, import flag contents);
rendered appearance belongs to the critic with a capture, not to these
tests.

## cody_rhodes.glb (wired through scenes/cody_match.tscn)

Source: **user-supplied Google Drive file** (`cody-rhodes.zip`, 180 MB,
supplied by the repo owner; author and licence unknown, not downloaded from
a store). The archive holds `source/Cody Rhodes.glb` (100 MB) plus a
`textures/` folder that duplicates the twelve images already embedded in the
.glb, so only the .glb was used.

Provenance signals worth recording: the material and image names are content
hashes (`xmaterial_*`, `ximage_*`) except one, `head_shared_inside_mouth_iw9`
-- `iw9` is Infinity Ward engine naming. This has the shape of a game rip.
As with `roman_reigns.glb`, the author and licence are unknown and must be
confirmed before redistribution.

**The supplied asset is a statue.** Verified in the glTF itself, not inferred
from a render: no `skins` array, no `JOINTS_0`/`WEIGHTS_0` on any primitive,
no node with children, and no animations -- 14 flat sibling meshes, 74213
triangles, in centimetres, in a relaxed A-pose. Nothing in the game could
pose it.

`tools/assets/rig_static_wrestler.py` produces the committed
`cody_rhodes.glb` from it: the base rig's own 65-bone hierarchy fitted to the
A-pose, skin weights transferred from `wrestler_base.glb`'s mannequin, the
supplied geometry left undeformed, and textures capped at 2048 on a side
(the source's 4096-square skin atlas put the file at 104 MB, over GitHub's
100 MB per-file hard limit; the result is 54.7 MB). The script's own log
records every measurement it made.

What the audit found in the supplied materials: **nothing**. All twelve carry
their own base colour, none points albedo at a packed data map, none is
untextured. Both tattoos -- the "Dream" script on the left pec and the
American-flag skull on the neck -- are in the asset's textures and render.
`cody_model.gd` therefore has no material-repair pass at all, which is this
asset being in better shape than `roman_reigns.glb`, not a repair skipped.

The rigged skeleton keeps the base rig's bone names and hierarchy but rests
in the model's own A-pose. That is a BIND-pose difference, not a retarget
problem: identical local poses down an identical hierarchy give identical
global poses, so the animation keys are copied verbatim and only their node
paths are rebased. See the note on `CodyModel._install_animations()` for why
converting them through rest space instead is wrong, and what it looks like.

## kenny_omega.glb

Source: user-supplied Google Drive archive (`model.zip`, containing
`source/finalized.zip`), December 2022 vintage. As with `roman_reigns.glb` and
`cody_rhodes.glb`, the author and licence are unknown and must be confirmed
before redistribution.

The supplied file is a **photogrammetry scan of a physical action figure**, and
that shows in every measurement of it. It is not a game asset that happens to be
unrigged; it is a scan, with a scan's strengths and a scan's damage.

**What was supplied.** A binary FBX 7700 inside two nested zips, with a
4096-square diffuse and a 4096-square normal map beside it. One mesh, 285,913
vertices, 571,794 triangles, one material. Watertight -- 0 non-manifold edges,
0 boundary edges, and 99.86% of its vertices in a single connected shell, which
is markedly healthier than the Cody asset's 224 shells and 6251 non-manifold
edges. It arrives **upside down**, **yawed 44 degrees** off the axes, and
**0.176 units tall**, because the thing scanned is 17.6 cm of plastic.

**The audit found no material faults.** One material, base colour and normal map
both properly wired, no packed data map in an albedo slot, no untextured slot,
no alpha card. `kenny_model.gd` therefore has no material-repair pass, the same
way `cody_model.gd` does not. A scan has exactly one surface and paints
everything onto it, which costs fidelity but removes that whole class of defect.

**Two scripts produce the committed file.** `tools/assets/fbx_to_static_glb.py`
converts it (the rigger reads only glTF), stands it upright, squares it to the
base rig's frame -- arms along X, toes along -Y, both measured off the rig
rather than assumed -- drops 7 loose scan fragments totalling 402 vertices, and
decimates to 150,000 triangles. That target is deliberately well above Cody's
74k: a photogrammetry atlas is thousands of tiny UV islands and every island
boundary is a seam the collapse decimator smears across, so it does not tolerate
what a hand-authored atlas does. Measured silhouette drift from the decimation,
at ten heights from ankle to crown, is at worst 0.41%.
`tools/assets/rig_static_wrestler.py` then fits the base rig's own 65-bone
hierarchy to the pose, transfers weights from `wrestler_base.glb`'s mannequin,
leaves the supplied geometry undeformed, and caps both textures at 2048.

As with Cody, the rigged skeleton keeps the base rig's bone names and hierarchy
but rests in the model's own pose. That is a BIND-pose difference, not a
retarget problem, so the animation keys are copied verbatim and only their node
paths are rebased -- see `KennyModel._install_animations()`.

**Known limits of the source, which no adapter code can fix.** The face is soft
and the hair is a solid blob at close range; the lighting of the room it was
scanned in is baked into the diffuse and will not respond to the arena lights;
and the figure's pointing right hand is frozen into the mesh, so his fingers
keep that gesture in every animation.
