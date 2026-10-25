# BR-022 shared garment construction finish

Item 22/25 remains in progress. Continue the live 39ba9fd source and its shared
65-bone rig / 19 actions; preserve all independent head packages and kit images.
Use create-player, director/reference-match, character/modeling, retopology,
UV and rigging guidance with headless Blender/bpy; no Blender MCP is connected.

References: home kit `file_000000000da0824386b7ef8edd3a9c79.png` and Bordeaux
`file_000000008a9881f49c8ce1ebe2521b75.png` in the archived Drive originals.
The home shirt has a clean, narrow sewn lower edge with restrained drape;
Bordeaux's short sleeves end above naturally exposed forearms. The upper back
and armholes should deform as joined fabric without sharp inverted folds.
The supplied graphics, centered Uhlsport and Thomas Loomes & Co stay registered.

Prioritized baseline gaps:
1. Bare-arm ray samples miss skin beneath short sleeves (8 of 12 missing).
2. Folded/inverted lower-shirt faces and disconnected edge ribbons create a
   torn-looking hem even in idle.
3. Rear axilla pinches during arm flexion; current nine-pose inversion counts
   are recorded by the preceding shared_shoulder_fit validation.
4. Cloth still copies some anatomical bulges at the shoulder blades.
5. Individual facial likeness and final material approval remain separate.

Repair the missing skin, replace defective local cloth topology where needed,
and smooth joint weights without changing bone rests or action curves. Keep
UV chart registration outside replaced regions; map new faces to the existing
2K atlas. Prefer fewer clean quads over subdividing damaged anatomy. Keep
roughly the existing all-variant triangle budget, allowing a small skin patch.
No runtime cloth solver. Reuse the established matching front/back/kit cameras,
light and fixed nine-pose sheet, then the actual Godot roster appearance path
and assembled Play/Watch match. Native Mac/M1 acceptance stays pending.

## Implemented construction pass

The earlier anatomical body mask had already removed most of both forearms;
this predates the previous shoulder pass. A rest-surface probe reproduced the
holes at 8 of 12 points. The source validator was extended before applying the
fix and failed on the production source at x=-42 cm (`--python-exit-code 1`).
The same 12 probes now pass on the actual saved source.

Only the missing arm region is reconstructed from the project's archived CC0
MakeHuman OBJ/morphs through its existing anatomical fitter and current bone
rests. The older Blender archive confirmed wrist coordinates, but already had
trimmed mid-arms, so it is not the donor. Existing skin positions, UVs, weights
and corner normals are retained; the maximum normal quantization difference is
below 0.0002. No earlier body, head or animation source replaces production.

The shirt's bottom 11.5 cm is rebuilt as six connected quad rows and a folded
2 mm edge with an inner return. One hundred disconnected hem ribbons are
removed; the original cuffs and neck binding remain. Both sleeve variants use
the existing UV atlas. The chest sponsor, crest, manufacturer and back print
are retained, with no image repainting or additional draw objects.

The low, recessed rear axilla is reshaped into a smoother gusset (maximum
movement about 5.1 cm), pinned outside that local area. A broad Laplacian
smoothing trial and direct weight-only trials were rejected because they
worsened the diagnostic in most poses. This is a targeted geometry correction;
the current shoulder weights, bone rests and all 19 clips stay unchanged.

The same upper-shirt cohort improves in all nine sampled poses:
- Idle: 116 → 70.
- Sprint: 122 → 77.
- PassRight: 128 → 123.
- ShotRight: 123 → 99.
- GroundedSlideTackle: 240 → 199.
- GetUpFromProne: 173 → 147.
- KeeperSet: 112 → 60.
- KeeperSave: 156 → 129.
- Turn90Right: 118 → 72.

These counts support visual review; they do not prove all-pose perfection.
Remaining shoulder-blade shape, sleeve fit, garment micro-detail and individual
likeness remain open under BR-022. Source renders use the diagnostic base head;
the Web review must use the actual roster head and appearance resources.

The exported source remains at 65 bones, 19 clips and 16 mesh parts. All-variant
geometry falls from 67,710 to 67,284 triangles despite restored skin. This is
not a measured per-actor draw cost or native M1 performance result.


### Waistband overlap found in the Web review

The first connected-hem candidate still showed a curved black band. A probe of
actual evaluated idle geometry reproduced shorts in front of the shirt at
(-8, 102) and (-4, 102) cm. The new source validator failed on that candidate
before the correction. The generated outer hem rows now maintain 6.5 mm of
clearance from the shorts, with a falloff above the waist; the inner return is
built from the corrected outer edge. This removes the overlap without changing
the shorts, kit images, animation or body shape. Review the final captures,
not the rejected first-pass images.


Validation commands use `blender -b --python-exit-code 1 --python ...` so an
assertion exits nonzero instead of Blender reporting a successful process.
The retained skin and waistband cases were both observed failing before their
respective fixes. The final validator checks all 12 skin probes and 20 posed
shirt/shorts overlap samples, normalized weights, the 65-bone/19-clip export,
head sculpt compatibility and non-T-pose locomotion. The maximum local waist
clearance adjustment is 2.685 cm; 6.5 mm is the target gap, not the displacement.


## Final integration evidence

Five actual Web captures cover Shane, Bordeaux close/full body, John in a save
pose and the referee, without browser errors. The final shirt/shorts boundary
is continuous in the close view, and the short-sleeve arms are present through
the wrist. These asset views disable sun shadows for the software renderer.
The nine-pose sheet and neutral renders use the production Blender source;
source base heads are strictly garment diagnostics. Web views use the separate
current head packages. Do not infer facial likeness from either garment review.

Both Play and Watch modes, correct human-player counts, kickoff, options,
return to menu and layout checks pass in the assembled 23-actor Web scene.
The bounded shared-head, shared-resource, pose-safety and 11v11 checks also
pass. `runtime_validation.json` records their scope and the before/after
regression cases. Native Mac execution and M1 performance remain pending.

Next BR-022 acceptance: match shoulder/sleeve silhouette and cloth drape to the
kit sheets before individual head/keeper likeness production. This construction
pass closes the missing-arm and waistband-overlap regressions; it is not final
reference matching or an all-pose cloth approval.
