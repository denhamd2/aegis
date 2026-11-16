# Editable paired animation review sources

`running_grapple_inverted_drop.blend` contains the CC0 base mesh/rig and the
two editable actions accepted for the current bounded wrap/turnover pass.
The canonical reproducible authoring path is
`game/tools/blender/wrestling_clips.py`, with immutable approach pose inputs
in `game/tools/blender/running_drop_approach_baseline.json`. Rebuilds regenerate
these actions from that source; edits made only in the native review file
must be transferred back to the canonical pose table before export.

Source timing is30fps, GLB sampling60fps. Gameplay owns root trajectories.
Acceptance evidence and remaining landing/retarget limitations are in
`gauntlet/refs/ff_initiative_2026_11_14/batch3/running_drop_reauthor/`.
