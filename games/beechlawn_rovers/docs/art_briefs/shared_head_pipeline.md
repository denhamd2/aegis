# Shared updated head — BR-022 (22/27, in progress)

Owner approved using Shane's updated neutral head as the shared starting point,
with independent player likeness changes and hairstyles. This is pipeline and
roster integration, not approval of all players as finished likenesses.

The initial `shane_photo_head.blend` neutral head, eyes, skin UV/material
and reusable smile were promoted into `footballer_head_master.blend`. Preserve the 65-bone
production bind pose, neck seam, body and animation library. Store a revision
snapshot, topology and coordinate fingerprints; apply each player's sparse
sculpt changes during the offline build. A topology fingerprint alone cannot
identify a changed Basis, so stale coordinate deltas must fail or explicitly
rebase against a recorded compatible revision.

Shane, John, player Des and referee Des now have independent saved sources
and nonempty captured sculpts. Their ongoing likeness work is recorded in
[the current finish brief](realism_finish/brief.md). Other identities retain
the common starting head, names, numbers, roles, kits and reference mapping.
Every roster identity has a separate editable recipe/delta slot.
Unchanged heads share the same runtime mesh; create unique exports only when
individual offsets exist. Keep expressions independent from identity.

Hair is selected separately: Shane's crop, John's swept blonde-highlighted
hair, player Des's side/back horseshoe and the referee's sparse grey hair and
moustache. The eleven away aliases deliberately share player Des. Other crop
placeholders remain until individual work; they are not approved likenesses.

Acceptance: demonstrate a compatible common Basis edit propagating to two
independently sculpted heads while retaining both sets of personal offsets;
reject incompatible topology or unrecognised Basis; keep neck, UVs, weights and
expression offsets intact; verify the actual assembled 22 players plus referee
have one skeleton each and preserve kit/role/selection behavior. Capture the
real Godot roster and portrait. Native M1 performance remains unmeasured.

## Authoring and regeneration

Commands run from the repository root. The live common source is
`tools/blender/beechlawn/footballer_head_master.blend`. The older
`shane_photo_head.blend` and its refinement script preserve the pre-promotion
Shane iteration; rebuilding that old source does not update the roster master.
Initial promotion is a one-time operation and refuses to overwrite the master.

For a **common improvement**, edit the master in Blender, using neutral Basis
for shape changes and moving expression coordinates with the identity edit.
Preserve topology, UVs, weights, bind transforms and the neck below local Y154cm,
including its shading normals. Then regenerate:

```sh
blender -b --python-exit-code 1 --python tools/blender/beechlawn/build_roster_heads.py
```

For an **individual likeness**, open its existing production source first.
Only create a work source when no newer artist source exists. Edit its neutral
Basis and capture it (substitute that actual source path in the second command):

```sh
# Edit the neutral Basis in the current john_orourke_head.blend in Blender.
blender -b --python-exit-code 1 --python tools/blender/beechlawn/build_roster_heads.py -- --capture-player john_orourke --sculpt tools/blender/beechlawn/john_orourke_head.blend
```

This captures head and eyeball offsets and rebuilds all recipes.
Editable sources record player and master revision; capture rejects a stale
revision or the wrong player. Existing work files are never overwritten by
`--edit-player`. After a common master change, archive the old work file and
generate a fresh one from the rebased recipe. Persistent authored changes live
in versioned `head_pipeline/deltas/`; keep meaningful sculpt work sources in the
player's asset folder as well. An empty recipe uses the common GLB, avoiding
duplicate head/skin textures for unchanged players. Expressions keep their
relative deformation rather than inheriting another player's expression pose.

`head_pipeline/roster.json` maps each identity to profile paths, independent
delta and hair choice. Four retained Bordeaux fixture IDs explicitly alias the
Des Feeney recipe. All 24 other slots are independent (23 squad entries,
including reserve Paddy, plus the referee). `master.json` and immutable
`bases/<revision>.json.gz` snapshots let the builder rebase known compatible
common position changes. Topology or UV/weight changes require an explicit
transfer, not automatic index reuse. New shared materials export on every build.

`roster.json` holds the current hair choices; runtime `custom` hair selects a
separate compatible package. Refit the groom after a skull/hairline edit.
Paddy's reserve profile uses bald. `build_roster_heads.py` verifies current
saved source coordinates against the captured delta and copies its materials
and expressions. Uncaptured newer edits fail; existing artist sources are not
silently replaced by the legacy bootstrap. Geometry-only close-up packages
reuse normal-package atlases; shared Fullness morphs retain per-instance values.

## Verification and limits

`shared_head_evidence/regeneration.json` records two different synthetic sculpts
rebuilt over a common edit, retained expression offsets/neck/UV/weights, stale
Basis rejection and unchanged master. These synthetic sculpts are test fixtures,
not invented player likenesses. `build.json` records all 28 recipes and the
24 independent slots. A no-edit John authoring/capture round trip also produced
empty offsets without changing other profiles.
The sculpt build preserves the neck's custom corner normals while recalculating
the changed facial surface; the regeneration check verifies that shading seam.

Run the mesh check, then import and the production roster checks:

```sh
timeout --kill-after=3s 60s blender -b --python-exit-code 1 --python tools/blender/beechlawn/validate_roster_head_build.py
timeout --kill-after=3s 180s godot --headless --editor --path games/beechlawn_rovers --import
python3 games/beechlawn_rovers/tools/run_smoke_tests.py shane_head_variant_smoke.gd shared_head_roster_smoke.gd shared_roster_resources_smoke.gd shared_pose_safety_smoke.gd
```

The first Godot test checks imported head/eye/hair bindings and five motion
clips. The roster test checks all 22 players plus referee, shared meshes,
independent overrides, bald selection and appearance reconfiguration. The other
checks preserve common kits, independent playback and pose safety. The release
workflow includes the head/roster checks; Blender is only an offline authoring
dependency. New portraits use the real `FootballerVisual` profile path through
native Forward+ (`tools/capture_native.py`). The following Web evidence is
historical; football Web delivery is retired. Neither establishes M1 frame times.
The saved Shane, Des and John portraits confirm the head/hair/kit selections.
`shared_head_evidence/match/title_web_check.json` records a real Chromium
Play/Watch run with keyboard kickoff, zero/one human control, return to title
and no console errors; both assembled match frames are saved beside it.

Shane's neutral geometry was unchanged by the initial promotion; subsequent
individual sculpts are independent offsets. The shared pipeline subtask is
complete; BR-022 stays in progress for reference-led
likeness, hair, kit/collar polish and native performance/visual acceptance.
