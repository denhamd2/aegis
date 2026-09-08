---
name: import-wrestler
description: >
  Import a new 3D wrestler/character model (.glb, .gltf, .fbx) into the aegis
  Godot game so it plays as a wrestler — auditing the asset, rigging it if it
  arrives unrigged, repairing its materials and textures, mapping its bones,
  getting the base rig's animation libraries onto it, wiring it into
  WrestlerController, and verifying it on rendered frames. Use this skill
  whenever the user drops a new character model into the project or mentions
  importing, adding, wiring up, or "getting in the
  game" a wrestler, character, or 3D model — and also when debugging an
  already-imported one that renders magenta, bald, upside-down, backwards,
  T-posed, inverted, with skin poking through clothes, with a floating or
  misplaced beard or hair, or with animations that play head-down. Those symptoms
  are almost never what they look like, and this skill carries the measured
  causes.
---

# Importing a wrestler

A previous import (Roman Reigns) took seven passes and four rounds of user
complaints for faults that were all knowable from the asset in the first hour.
This skill exists so the next one takes one pass. Work the phases in order —
each rules out a class of fault so the next phase's evidence means something.

## Four rules that decide almost everything

**A transform-space assertion cannot verify what the camera sees.** Facing was
reported fixed on a measured `forward · to-opponent = 1.0`; the number was right
and the rendered character disagreed with the node by 180°. A drift test showed
the beard-to-head offset was *constant*, which was read as "correct" and reported
back to the user twice; it was constant **and** wrong — a fixed offset is exactly
what a 5%-larger head under an unscaled beard produces. Measurements tell you
*what*. Only a rendered frame tells you *right*. Close every appearance claim on
pixels.

**When three defects are reported, look for one cause first.** "Bald crown",
"holes in the trousers" and "misplaced beard" were chased separately across four
rounds through mip-averaging, alpha thresholds, LOD and mesh-hiding. All three
were one line: height was applied to one skeleton and the model was rigged on
two. Before starting pass N+1 on a symptom, ask what single upstream fact would
produce every symptom at once.

**Audit the asset before writing adapter code.** Nearly every bug below was
visible in a dump of the model's meshes, materials, textures and skeletons. They
were instead discovered one render at a time.

**Check the model is rigged at all, before planning anything.** The Cody Rhodes
model arrived as a *statue*: 14 flat sibling meshes, no `skins` array, no
`JOINTS_0`/`WEIGHTS_0` on any primitive, no node with children, no animations.
Nothing in the game could pose it, and Phases 3–5 had nothing to operate on. It
is one line of the audit's output and it decides whether this is an import or a
rigging job. See **Phase 0.5**.

## Phase 0 — audit, before anything else

```bash
godot4 --headless --path game --import
godot4 --headless --path game tools/probe/audit_model.tscn \
    -- --glb res://assets/characters/<name>.glb
python3 .claude/skills/import-wrestler/scripts/inspect_textures.py \
    game/assets/characters/<name>*.png
```

Everything the audit prints with a leading `!!` is a finding that will produce a
visible defect if left alone. Read the whole output before deciding anything, and
write the findings down — the summary block at the end of the mesh table is the
work list for Phase 2.

What to extract, and why each matters:

- **How many skeletons, and which meshes ride which.** More than one means
  `apply_physique_height()` must scale *all* of them (Phase 3). Expect the split
  to be body against *everything worn*, not head against body.
- **Materials with no base colour**, and whether an unreferenced colour map
  exists elsewhere in the asset. Count the images the `.glb` embeds against the
  ones materials name — that is how you tell "unwired" (reconnect it) from
  "absent" (an honest flat tint, not an invented texture).
- **Albedo slots holding packed data maps.** `inspect_textures.py` confirms:
  R and B carrying near-identical data with a different G is a mask packed into
  green, and as albedo it renders magenta by definition.
- **Where the origin sits.** Feet-origin models hang their whole length below the
  mat when pitched flat at `y = 0` — the "he sinks into the ring" report.
- **Which axis its own locomotion clips call forward.** Godot's forward is −Z.
- **Its bone names**, against the base rig's, which is what `BONE_MAP` is.

## Phase 0.5 — is it rigged? If not, rig it

The audit prints `!! no Skeleton3D at all -- this is not a rigged model` when the
supplied file is a static mesh. That is not a defect in the asset so much as a
different job, and it is the user's call how to handle it: ask before spending
hours. The options, with the trade-off that actually decides it:

- **Rig it onto the base rig** (`tools/assets/rig_static_wrestler.py`). No bone
  map and no animation retarget are needed afterwards, because the bones it ends
  up with *are* the base rig's. Quality is good but not hand-rigged.
- **Get a rigged version of the same model.** Best quality; costs a round-trip.
- **Mixamo.** Good auto-rigging, but its `mixamorig:` names differ, so it needs a
  bone map and a real retarget — Phase 4 in full.
- **Use it as a static prop.** Cheap, and not a playable wrestler.

`tools/assets/rig_static_wrestler.py` runs Blender headless through `bpy`
(`pip install bpy==4.2.0` — no Blender install needed) and reports every
measurement it makes. Read its module docstring before running it: it records
which of the obvious approaches were tried and rendered and do not work.
Its output is a `.glb` whose skeleton carries the base rig's bone names and
hierarchy but rests in the supplied model's own pose.

The two things to check on its output, both of which it prints:

- **Every vertex carries a weight.** An unweighted vertex is not merely deformed
  badly; it stays pinned at the origin while the body walks away.
- **The fit check** — no bone sitting outside the flesh it drives. It caught a
  measurement bug of mine (arms reported as pointing straight up) before
  anything was bound to them.

## Phase 1 — land the files, unwired

Put the `.glb` and its textures in `game/assets/characters/`, record provenance
in `game/assets/characters/CREDITS.md`, and commit that on its own. A commit that
lands binaries and also changes behaviour is one nobody can review or bisect.

Check the `.import` settings while here: `generate_lods` is on by default, and a
decimated alpha card is not a smaller card — it is one whose mask has been
averaged toward transparent, so the whole thing falls under the scissor. That is
what made two wrestlers from one model look like different men at different
distances.

## Phase 2 — materials, from the audit's work list

Do these as **surface overrides in the model script**, never by editing the
`.glb`. The supplied asset then stays exactly as supplied, and every repair is
visible as code with its reason beside it. Copy the shape of
`game/core/match/roman_model.gd`: `ALBEDO_FIXES`, `HAIR_FIXES`, `HIDDEN_MESHES`,
`GROW_FIXES`, all applied in one `_fix_materials()` pass.

- **Packed map in an albedo slot** → rebuild as white RGB plus the mask channel
  as alpha, and tint at runtime. White RGB keeps the colour a one-line change
  instead of baking it into a 2048² file. `tools/assets/build_roman_hair_alpha.py`
  is the working precedent.
- **A card with no albedo and transparency disabled** → it cannot render as hair
  or cloth under any threshold; it draws as an opaque slab and z-fights the real
  card. Hide it, unless a mask for it exists somewhere in the asset.
- **Strand cards** → `cull_mode = CULL_DISABLED` (single-sided geometry seen from
  both faces), and clamp `lod_bias` so the mask survives distance.
- **Sparse mask** → measure coverage against a mask on the same model that
  already reads correctly, with `inspect_textures.py --coverage`. The number
  tells you which fix is even possible; read `references/traps.md` §Alpha before
  choosing, because three of the four obvious moves cannot work and one of them
  makes a moustache render as a slab.
- **Scissor vs blend** → a scissor is a binary keep/drop and throws away the soft
  card edges, which on a scalp are concentrated at the hairline. Blend the parts
  with an edge to recover (`ALPHA_DEPTH_PRE_PASS`); leave thin isolated strands
  seen edge-on on the scissor, where blending shows sorting seams worst.

## Phase 3 — skeletons and scale

Implement `apply_physique_height()` on the model script so it scales **every**
skeleton the model is rigged on:

```gdscript
func apply_physique_height(height: float) -> void:
	for skeleton in _animation_skeletons():
		skeleton.scale = Vector3.ONE * height
```

`WrestlerController` calls this when the model offers it and otherwise falls back
to scaling the single skeleton `get_game_skeleton()` returns — which is the bug
this method exists to prevent. Note that `_find_body_skeleton()` and
`_animation_skeletons()` both key off the target rig's *hip bone name*; that name
comes from your `BONE_MAP` and will differ per model, so update it rather than
copying `"J_Hips"` blindly.

`grow_amount` on clothing is a legitimate tool for genuine skinning disagreement
under deformation, but it must never be load-bearing for a scale mismatch — when
it is, it hides the real cause for four rounds. If you pick a value that works on
the first try, say in the comment that it is not a searched minimum.

## Phase 4 — animations: retarget only if the rig is foreign

**First decide whether a retarget is needed at all, because the wrong answer in
either direction produces a wrestler that looks subtly, confusingly wrong.** The
question is not "do the rest poses differ" — it is "is this a different rig".

- **Different rig** (different bone names, different hierarchy, different bone
  rolls — `roman_reigns.glb`, or a Mixamo auto-rig): retarget. **Read
  `references/traps.md` §Retarget before writing it** — it has the exact
  conversion, the multiplication order that looks half-right and is wrong, and
  why the `source_skeleton` parameter must not have a default.

- **Same rig, different bind pose** (the output of `rig_static_wrestler.py`:
  identical bone names, identical hierarchy, resting in the model's own A-pose):
  **do not retarget.** Copy the keys verbatim and rewrite only the node paths.
  In Godot an animation track sets a bone's local pose directly, so identical
  local poses down an identical hierarchy give identical *global* poses. The rest
  pose defines the BIND pose, which the mesh's skin already accounts for.

Converting in the second case applies the pose offset twice. Rendered, that is a
wrestler standing with correct legs and head and his **arms folded across his
waist** — which reads as a broken retarget and is in fact a retarget that should
not be there. `CodyModel._install_animations()` carries the worked example.

The tell that distinguishes them, and it is cheap: if the target's bone names are
the base rig's names, you are in the second case.

Then check the forward axis. If the rig's own forward-locomotion clips translate
along +Z, yaw the model node 180° and pin it with a test, or every wrestler
renders facing away from the man he is aimed at.

## Phase 5 — wire it into the game

The model script is duck-typed: `WrestlerController` probes it for methods and
falls back when they are absent. The full contract, the scene files to create,
and the exact controller call sites are in `references/wiring.md`. Read it when
you get here rather than inferring the interface from `roman_model.gd`, because
two of the five methods have failure modes that are silent when you get them
subtly wrong.

## Phase 6 — verify, in this order

1. **Bare render first.** This bisects the two big failure classes and takes a
   minute:

   ```bash
   godot4 --headless --path game tools/probe/bare_render.tscn \
       -- --scene res://scenes/<name>_model.tscn --bones <hips>,<chest>,<head>,<foot>
   ```

   Correct here and wrong in a match ⇒ the retarget. Wrong here too ⇒ the asset
   or its import. Guessing between those costs days.

2. **Then frames, under a real renderer.** Headless saves no images.

   ```bash
   xvfb-run -a --server-args="-screen 0 1280x720x24" godot4 --path game \
       --rendering-driver opengl3 --resolution 1280x720 \
       tools/probe/bare_render.tscn -- --scene res://scenes/<name>_model.tscn \
       --out /tmp/bare
   ```

   Look at the face close-ups specifically. Every hair, beard and eye defect
   found so far was invisible in a full-body frame.

3. **Then a real match**, which is the only thing that proves the wrestler is
   playable rather than merely well-formed:

   ```bash
   godot4 --headless --path game scenes/<name>_match.tscn --fixed-fps 6000
   ```

   Expect a finish line and no script errors. Give it 20+ minutes — a match at
   6000 fps still takes a while, and a short timeout looks exactly like a hang.

4. **Then the extreme poses**:

   ```bash
   xvfb-run -a --server-args="-screen 0 800x600x24" godot4 --path game \
       --rendering-driver opengl3 --resolution 800x600 \
       tools/probe/extreme_poses.tscn -- --scene res://scenes/<name>_match.tscn \
       --out /tmp/extreme
   ```

   Standing shots cannot show clipping; a head on the canvas or a body inverted
   mid-slam is where clothing and hair push through the mat.

5. **Then the suite**, and prove the change is presentation-only: run seeds 1, 2,
   3, 5, 7, 11 and show identical winners, finishes, tick counts and min-Y before
   and after. Determinism is the thing an art change must not touch.

Between generating any texture and looking at anything, run
`godot4 --headless --path game --import`. Godot renders the texture cached in
`.godot/imported/`, not the file you just wrote. This cost two comparison renders
and nearly a published wrong conclusion.

## Writing it up

Record what you could not close, with the measurement that bounds it — "only
15.8% of the mask is non-zero, so opacity cannot add coverage that is not there;
closing the rest is new art, not a repair". Every such note saved a later round
from re-deriving it. And when the user says it still looks wrong after you have
measured that it is fine, they are describing something real: the measurement
was sound and the inference from it was not. Go and look at the frame.

## References

- `references/traps.md` — the retarget maths, the alpha-coverage decision, and
  the Godot engine traps (IK nodes that silently do nothing, poses that read as
  rest, the import cache). Read §Retarget before Phase 4 and §Alpha before the
  mask work in Phase 2.
- `references/wiring.md` — the model/controller interface contract, scene files,
  and the animation-mixer ownership rule. Read before Phase 5.
- `scripts/inspect_textures.py` — channel triage and alpha coverage.
- `game/tools/probe/audit_model.tscn` — the Phase 0 asset audit.
- `game/tools/probe/bare_render.tscn` — the Phase 6 bisection probe.
