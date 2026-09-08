# Traps

Everything here was paid for once. Each entry says what the symptom looked like,
because the symptom is never obviously connected to the cause.

- [Retarget](#retarget) — read before Phase 4
- [Alpha](#alpha) — read before the mask work in Phase 2
- [Engine traps](#engine-traps) — IK, poses, the import cache
- [Origin and landing](#origin-and-landing)
- [Rigging an unrigged model](#rigging-an-unrigged-model) — read before Phase 0.5

---

## Retarget

**First: does this model need a retarget at all?** Two different situations look
alike and want opposite treatment.

A *foreign rig* — different bone names, hierarchy or bone rolls — needs the
conversion below. A rig that shares the base rig's bone names and hierarchy and
differs only in its REST pose does **not**: that is a bind-pose difference, and
the mesh's skin already accounts for it. In Godot an animation track sets a
bone's local pose directly, so identical local poses down an identical hierarchy
give identical global poses. Copy the keys verbatim and rewrite only the node
paths.

Converting anyway applies the pose offset twice. Rendered, that is a wrestler
standing with correct legs and head and his **arms folded across his waist** —
which reads as a subtly broken retarget and is in fact a retarget that should not
be there. Both halves of this were built and rendered; `CodyModel` is the
verbatim case, `RomanModel` the converted one.

The cheap tell: if the target's bone names are the base rig's names, it is the
verbatim case.

---

**Symptom:** the model plays every animation upside down. Head at 0.32 m, feet at
1.73 m, mesh torn apart. Or a subtler version: legs look fine, arms are folded
over the head.

**Cause:** a bone track stores a rotation in the bone's *local* space, which is
only meaningful relative to that skeleton's rest pose. Two rigs do not share one.
Copying keys across verbatim hands the target's bones rotations authored against
a different set of rest orientations.

**The conversion:**

```
delta  = src_rest⁻¹ * key
output = tgt_rest * delta
```

A key that matches the source's rest pose then lands exactly on the target's rest
pose instead of somewhere 180° away from it.

**The multiplication order is not a detail.** The pre-multiplied form
`key * rest⁻¹` measures the offset in the bone's *own rotating* frame. It
straightens legs whose rest axes happen to agree and leaves arms folded over the
head — so it looks half-right, which is worse than looking wrong. Take the delta
in the parent's frame and carry it into the target's frame through both parents'
global rests.

**`source_skeleton` must not have a default meaning "skip the conversion".** It
was optional, with `null` meaning "copy verbatim" — precisely the bug the
function exists to fix. The model script passed a real skeleton so the `.glb`'s
own library converted correctly, while `WrestlerController._adapt_animation_library()`
called the same method with one argument for the paired poses and strike clips.
Those two took the null path **in silence** and stayed inverted: grapples and
mocap strikes played head-down while locomotion and tie-ups looked fine, which
reads exactly like a merge regression and is not one. Every library reaching this
method is authored against the base rig, so there was never a caller wanting the
verbatim copy. Resolve the rig on demand instead of abandoning the conversion.

> A default that quietly does the broken thing is worse than a required argument.

**Retarget *every* library**, not just the `.glb`'s own: the base rig's clips, the
generated paired poses, and the imported strike clips all need it. Assert the
coverage in a test.

**Bones missing from `BONE_MAP` are dropped silently.** Print both bone lists (the
audit probe does) and map them once, rather than discovering one missing bone per
render.

**Forward axis.** Godot treats −Z as forward, which every `look_at()` and
`-basis.z` in this project assumes. Determine the rig's own forward from its
root-motion clips, not by eye — this rig's were `Walk_Loop dZ=+1.3`,
`Jog_Fwd_Loop dZ=+5.0`, `Sprint_Loop dZ=+5.5`, all `dX=0`, i.e. +Z. With no
compensating yaw on the model node, aiming a wrestler at his opponent renders him
facing exactly away: visible as both wrestlers extending an arm *past* each other
in a tie-up, and as an attacker standing pointing away from the man he just
threw. Fix with a 180° yaw on the model child node and guard it with a test so it
does not get tidied away.

---

## Alpha

**Symptom:** a beard reads as patches floating high on the cheek with a bare chin
between them, and no eyebrows at all. Or hair that vanishes on the far wrestler
and not the near one.

Measure first, with `scripts/inspect_textures.py --coverage`, against a mask on
the same model that already reads correctly — a beard and a scalp drawn by the
same artist for the same head are the right control. Then read the numbers:

| what the numbers show | what it means | what works |
| --- | --- | --- |
| big gap at ≥0.50, small gap at >0 | the strands exist, too faint to see | alpha gamma (`a**0.40`) — lifts ghosts, invents nothing |
| big gap at >0 as well | the coverage genuinely is not there | interleaving (below) |
| edges lost, hairline receding | the scissor is discarding soft card edges | `ALPHA_DEPTH_PRE_PASS` |
| far wrestler bald, near one fine | mips averaging a sparse mask toward zero | clamp `lod_bias`; alpha-to-coverage needs MSAA and does nothing without it |

**What cannot work, each tried:**

- *Lowering the threshold.* The whole range from 0.16 down to nothing was worth
  half a percent of the texture. A scissor can only ever draw what it already
  draws.
- *Dilation.* A max filter widens each strand and past a couple of texels renders
  a moustache as a solid slab: at 2048² a 7-texel window fattens a 2-texel hair
  into a blob, and a blob does not read as hair however well it matches a
  coverage number.
- *Moving the mesh.* Verify placement against **landmarks on the same model in
  the same pose** (teeth for the mouth line, an eye bone for the eye line) — not
  against the head mesh's AABB, which includes the neck and proves nothing. The
  beard measured −0.55 to 1.37 on a mouth=0/eye=1 scale, exactly the span a
  beard-moustache-brow mesh should occupy. Moving it would have broken a correct
  mesh to chase a symptom.

**Interleaving is what worked.** Composite the mask over horizontally-shifted
copies of itself. A strand-card atlas is a grid of cards whose hairs run
vertically, so a shifted copy lays a new hair into the gap beside each existing
one — at the same length, curvature and taper, *because it is the same hair moved
sideways*. Every strand stays exactly as thin as it was drawn, which is the
difference between a denser beard and a smear. Offsets of `[-5,-2,2,5]` texels
took ≥0.5 coverage from 0.0963 to 0.2917.

**Land just under the reference, not over it.** A beard denser than the head of
hair above it reads as painted on.

---

## Engine traps

**The import cache.** Godot renders the texture cached in `.godot/imported/`, not
the file a generator just wrote. An 11.9% mask and a 29.6% mask produced
near-identical frames, which reads as "dilation does nothing" and is in fact "the
renderer never saw it". Two comparison renders wasted and a wrong conclusion
nearly published. Always run `godot4 --headless --path game --import` between
generating and looking.

**`TwoBoneIK3D` does nothing on this build.** It is the modern, non-deprecated
node and was the first choice. In an isolated three-bone skeleton with the chain
resolved, the target set, `influence` at 1 and `active` true, the tip bone never
leaves its rest pose. `SkeletonIK3D` lands the same tip within 0.005 m of the same
target. Hence the deprecated node.

**`Skeleton3D.get_bone_global_pose()` returns the *pre-modifier* pose.** A custom
`SkeletonModifier3D` that demonstrably rotates a bone still reports its rest
position through that call, while a `BoneAttachment3D` on the same bone reads the
real, post-modifier position. This made a working modifier look broken and very
nearly buried the whole approach. Measure modifier output with a
`BoneAttachment3D`, or by rendering.

**`BoneAttachment3D` deadlocks against an IK modifier on the same skeleton.** Fine
for isolated diagnosis; adding one to a wrestler that has grip IK hangs the
process. So IK unit tests cover the rig and the targeting maths only, and the
pose itself is verified by rendering.

**Configure `root_bone`/`tip_bone` *before* adding a `SkeletonIK3D` to the tree.**
Each assignment rebuilds the solver chain immediately, so setting them on an
already-parented node makes the first one resolve the other end to `-1` and log
`build_chain` errors every frame while doing nothing.

**`--check-only` every script before committing it.** A probe shipped once with a
parse error (Variant inference on `WrestlerFSM.State.keys()`), so a background run
failed *silently* while the silence was being attributed to a slow rasteriser.

---

## Origin and landing

The model's origin is at its **feet**. A body pitched 90° face-down at root
`y = 0` therefore hangs its entire length below the mat — 0.55 m under, reported
as "he partly sinks into the ring".

Fix it as content, in the paired clip: for every wrestler whose position track
peaks above ~0.30, set the rotation keys at and after landing back to that
track's first key. Quaternion shortest-arc interpolation makes this *continue* the
rotation to a full 360° rather than reversing it, so the flip still reads as a
flip.

Guard it with two tests: a strict upright check for bodies that actually leave the
mat, and a looser 45° invariant that catches the class of bug for everything else.


---

## Rigging an unrigged model

Only relevant when the audit says `no Skeleton3D at all`. All of this is measured
on the Cody Rhodes asset by `tools/assets/rig_static_wrestler.py`, whose module
docstring carries the full reasoning; this is the short list of what does not
work, so it is not tried again.

- **Bone-heat ("automatic weights") fails on a supplied model.** It needs a
  closed volume, and a supplied character is a dozen-plus shells — body,
  clothing, boots, hair, eyes, mouth — with open boundaries. Measured: 224
  connected shells, 6251 non-manifold edges of 114445, and 0 of 40448 vertices
  weighted, reported as a *warning* rather than an error. Transfer weights from
  the base rig's own mannequin instead; it is already skinned to these bones.

- **Normal projection (`POLYINTERP_VNORPROJ`) destroys the limbs.** It is the
  textbook mapping when the target is bulkier than the source, and it does fix
  the chest — whose vertices otherwise find the mannequin's *arm* as their
  nearest surface. But an arm vertex's normal points radially out of the arm, so
  its ray crosses open space and lands on the torso or nothing, and the arms come
  out as ragged sheets. `POLY_NEAREST` plus smoothing is worse at the armpit in
  theory and better everywhere visible.

- **Weight smoothing cannot cross a seam.** It travels along edges, and abutting
  shells share no edge — 15588 vertices here sit within 8 mm of a different
  shell. Average weights by *distance* to reach them. Do not merge vertices to
  fix this: it alters the supplied mesh and welds surfaces meant to stay
  separate, such as the lips to the teeth.

- **Do not bake the mesh into the base rig's T-pose.** It is tempting, because
  then the rest poses match and no retarget is needed anywhere downstream. The
  mannequin has a hard clavicle/upperarm weight boundary, and driving a
  61-degree rotation through it tears the deltoids open: 450 vertices on edges
  stretched past 1.6x, split symmetrically across `upperarm_l/r` and
  `clavicle_l/r`, rendered as dark torn patches over both shoulders. More
  smoothing does not touch it (6 passes: 450, 30 passes: 484). Ship the supplied
  geometry undeformed and resolve the rest-pose difference in the loader.

- **A wrong diagnosis worth not repeating:** that tearing was first blamed on
  stale custom split normals surviving the bake — glTF carries per-corner
  normals that Blender does not recompute when a mesh is deformed, which is a
  real trap and was not this one. Clearing them changed nothing. Measure which
  vertices actually moved (`--diagnose`) before theorising about shading.

- **Texture budget.** A supplied model is authored for a renderer with no file
  size limit. A 4096-square skin atlas put this `.glb` at 104 MB, over GitHub's
  **100 MB per-file hard limit**, so it could not be committed at all. Cap the
  textures — but exempt atlases carrying logo or text art, where halving the
  resolution is plainly visible as softened edges while it is invisible on skin
  and cloth.
