# Parallel move pipeline (9 November 2026)

The slow shared step is the single Blender bake and Godot import, not the
thinking. Parallelise the independent work around it; keep the shared build
single-writer.

## Roles

| Role | Owns | Must not do |
| --- | --- | --- |
| Integrator (main) | Merge patches, edit the shared clip file, bake, import, rebuild paired/strike resources, run gates, commit, push, deploy | Delegate the shared files to workers |
| Move worker (general) | One move in its own worktree: reference frames, clip keys, recipe, MoveDef, reference notes, per-move sheet | Bake, import, edit `wrestling_clips.py` on another worker's branch, commit or push |
| Visual reviewer (Nemotron) | Frame-by-frame evidence per move: contact, poses, sell, speed, effects | Score or edit |
| Art director (DeepSeek V4 Pro) | Score each move on the eight factors, give specific feedback | Edit or bake |

## Batch flow

1. **Reference extraction — parallel.** Workers pull 60 fps frames, timings,
   contact poses, sell and effects into `gauntlet/refs/video_refs/<group>/`.
2. **Draft authoring — parallel.** One worker per move in its own worktree.
   Each returns a patch limited to that move's clips, recipe and MoveDef.
3. **Pre-bake art-director desk review — parallel.** Before the shared bake,
   each worker returns its timing table, contact tick, pose keys, sell plan and
   effects plan. The art director reviews them against the reference frames and
   rejects structural errors (wrong limb, wrong contact tick, missing weight,
   missing sell) while a fix is still cheap. This pass cannot judge mesh
   deformation, silhouette or actual contact; those wait for the bake.
4. **Integration — single writer.** The integrator merges only the patches that
   passed the desk review, checks key order and pose limits, and runs **one**
   bake and import for the batch.
5. **Build and gates — single writer.** Rebuild strike/paired resources, run
   the focused gates, then render one sheet per move.
6. **Post-bake review — parallel.** The visual reviewer describes each sheet
   against its reference; the art director scores each move on animation,
   poses, effects, selling, attacking, realism, speed and power. This is the
   final visual gate; the pre-bake pass does not replace it.
7. **Fix loop — parallel per move.** Each worker applies its own feedback in
   its worktree. Re-integrate, re-bake, re-score. Repeat until 10/10.
8. **Delivery — single writer.** One commit and Mac deployment per batch; add
   every reference, sheet and score to the ledger.

## File ownership

| File | Owner |
| --- | --- |
| `game/tools/blender/wrestling_clips.py` | integrator only; workers return patch files |
| `game/resources/animations/paired_recipes.gd` | integrator only |
| `game/resources/animations/strike_recipes.gd` | integrator only |
| `game/resources/moves/ff/<move>.tres` | move worker (new file) |
| `gauntlet/refs/video_refs/<group>/` | reference worker |
| `gauntlet/refs/ff_review/moves/<move>.png` | visual reviewer / renderer |
| `gauntlet/refs/ff_visual_qa_ledger.md` | integrator |

## Batch order

1. Strikes and kicks (high, low, strong, combinations).
2. Selling and knockdowns.
3. Irish whip, rebound and running.
4. Grapples, strong/rear, transitions, dragging, throws.
5. Ground, corner, top rope, rope, apron, springboard.
6. Taunts, signatures, specials, stolen finishers.

## Scoped pose pre-flight

A full bake is about 15 minutes, and PoseLint samples all 300+ clips after it.
Do not pay that twice for one bad hand pose.

After the author patches are merged and before the full bake:

1. Bake only the batch's new clips to a throwaway GLB:
   `AEGIS_ONLY_CLIPS=<Clip_A>,<Clip_B> AEGIS_CLIP_OUTPUT=/tmp/batch.glb blender
   -b --python game/tools/blender/wrestling_clips.py`.
2. Import it and run PoseLint (or the pose probe) on those clips only.
3. Fix hand-through-torso and below-mat defects in the source.
4. Run the single full bake once the scoped poses are clean.

This is the cheap gate that would have caught the rana defender's hand and the
whip setup hands before the first full whip bake.

## Current batch

- Delivered: the seven-strike batch (faac7316).
- In delivery: the six whip/rebound pieces, with the corrected hand poses and
  rebound/running wiring.
- In the integration branch: German suplex, delayed vertical suplex, Olympic
  slam and the corner cravat/head strike, all desk-reviewed; scoped pose
  pre-flight next.
- Next: the universal impact-presentation pass (see
  `impact_presentation_plan.md`).
