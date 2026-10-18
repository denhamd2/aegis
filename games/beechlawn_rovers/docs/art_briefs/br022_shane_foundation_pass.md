# Shane: joint-fit and body foundation pass

2026-10-17. **BR-022, item 22 of 25 remains in progress.** Technical foundation checks pass; body/face likeness and complete kit acceptance remain open. This is not an AAA-quality approval or an active-roster replacement.

The 2026-10-18 [body, face and tailored-kit pass](br022_shane_body_face_tailored_pass.md) supersedes this intermediate asset. Counts below describe the earlier foundation export; the machine-readable validation report now tracks the latest GLB.

## Direct Blender changes

The active builder now uses `tools/blender/beechlawn/shane_anatomical_foundation.py` through the existing `build_shane_denham_player.py` entry point. The rejected input Blender source is retained at `tools/blender/beechlawn/archive/shane_denham_before_joint_fit.blend`. The licensed source OBJ remains untouched.

| Before | After |
| --- | --- |
| The raw neutral macro base was used directly and its chest anatomy did not match the reference. | Apply the official CC0 MakeHuman adult-male macro blend before joint extraction. Source targets, original headers and hashes are archived under `references/third_party/makehuman/morphs/`. |
| The MakeHuman surface faced local -Z while the existing toe bones point +Z. Limb coordinates were independently stretched and shifted with thresholds. | Use +Z forward for the body and kit. Derive 52 temporary fitting segments from the licensed OBJ's anatomical joint helpers, bind the original anatomy there, then fit it offline into the existing game rig's rest pose. Delete the temporary rig before export. |
| Body and kit weights were not normalized reliably because the pruning loop reused live Blender RNA assignments after editing them. | Snapshot group/weight values before edits; retain at most four positive deform weights and normalize them. Garment weights are interpolated from the fitted body triangles. |
| Torso proportions were changed with sharp coordinate cutoffs. | Start with the official male anatomical form, then use continuous, limited waist/belly and cheek/jaw fields. Clothing boundaries follow its actual anatomical landmarks. This is an initial fit toward Shane's solid adult build, not a measured final silhouette match. Hands, neck/head relationship and individual proportions still need closer comparison. |
| Shorts were primarily a material region on the skin; socks and boots were independently placed capsules/ellipsoids. | Separate fit-test shirt, shorts, socks and boot surfaces derived from the licensed clothing helper and fitted against the actual body. Royal-blue socks follow the kit-board choice; the boots contain the feet and their rest soles reach approximately 1.5 mm above the nominal ground plane. |
| Sparse clothing and independently sampled weights allowed the body to break through during bends. | Refine the clothing mesh offline, transfer body-triangle weights, and remove deeply covered body faces with overlap margins. Reproducible source anatomy is preserved. Tailored seams, hems, ribbed cuffs and final cloth shapes remain future work. |
| The sleeve UVs sampled one UV point, giving an undefined tangent basis for fabric bump. | Use two independent sleeve UV coordinates. White speckling is removed; the complete kit still needs its planned panel unwrap. The temporary registration now reveals the crest and back #8. |
| Head and body had inconsistent placement/shading, and procedural head skin lacked an exported base color. | The neck boundary comes from the same fitted anatomical surface with matching weights. Head and body use the same explicit exportable skin base color; no portrait is attached to the face. This is plain foundation skin, not completed reference skin texturing. |
| The character builder forced the 60-fps source library to export at 30 fps. | Keep the source library's 60-fps authoring rate. Existing action keys are unchanged; the exported durations now agree with the authored timeline instead of being doubled. Ball-contact validation in gameplay remains a separate gate. |

All fitting, subdivision, weight interpolation and garment projection happen during the offline Blender build. There is no added runtime cloth, physics or IK work.

## Validation performed

- Blender 4.3.2 direct build and GLB export succeeded.
- Compared all 65 production bones' rest matrices, endpoints and parents with the original animation-library rig: unchanged.
- Compared all 15 existing actions' keyframes, handles and interpolation with the original: unchanged. No new animation was authored.
- All exported-source mesh vertices have normalized positive deform weights, at most four per vertex.
- Verified the face and toe directions agree and checked the boot sole's rest height.
- Checked three sample frames per existing action (45 pose samples). The 54 shared head/body boundary vertices remain coincident; evaluated mesh positions remain finite and within the structural bounds check.
- Inspected actual GLB animation time ranges against all source action ranges at 60 fps. Skin has an explicit PBR base color.
- Forced Godot editor reimport, then passed `shane_denham_import_smoke.gd`, including the checked clips, skin-color fallback and shot-duration regression check.
- Current export: **37,716 triangles, 10 material surfaces, 65 bones**. The previous export contained 41,204 triangles and 15 surfaces. These counts do not establish an M1 frame rate.

Machine-readable evidence: [`br022_shane_foundation_validation.json`](br022_shane_foundation_validation.json). The report includes the actual GLB checksum and per-action pose/timing probes.

## Render evidence and remaining visual issues

Current body reviews use a fixed 2.1 m orthographic framing at mid-body height; portrait views retain their perspective lens. Front direction is corrected to the rig's actual front. `--neutral` applies an unkeyed arms-down review pose; it is not a new animation. Clip renders play the actual clips without that neutral-pose override.

- [Neutral front](shane_denham_08_neutral_front.png)
- [Neutral clay front](shane_denham_08_clay_neutral_front.png)
- [Neutral profile](shane_denham_08_neutral_profile.png)
- [Neutral back](shane_denham_08_neutral_back.png)
- [Neutral three-quarter](shane_denham_08_neutral_threequarter.png)
- [Previously problematic idle, frame 44](shane_denham_08_idle_f44_front.png)
- [Sprint, frame 10](shane_denham_08_sprint_f10_front.png)
- [Shot, frame 18, profile](shane_denham_08_shotright_f18_profile.png)

The review still fails the final likeness/garment/motion gate:

1. The face remains generic, the eyes/brows and mouth need reference-specific work, and the hair is still a scalp cap. Preserve geometry-led likeness work; do not reintroduce a portrait overlay.
2. Body proportions need a closer pass against the matched views, especially hands and the head/neck/shoulder relationship. The helper-derived kit is a fit-test surface, not finished tailoring.
3. Collar, raglan panels, sleeve/cuff endings, shorts folds/crotch, sock tops, boot construction, artwork scale and color calibration still need the detailed kit pass. The helper-derived shirt also has chest creases/self-overlap visible in clay; replace those with deliberate front-panel topology. Some pinching and overlap artifacts remain visible in moving poses.
4. The existing sprint action has an overly wide/T-pose-like arm silhouette. The shot also exposes awkward arm/hand presentation. These are inherited action-content issues revealed by the review; preserving the source action data is not an animation-quality pass. Route their later motion polish through BR-003/BR-021 without changing football simulation logic.
5. Godot close/broadcast gameplay review, final mesh/ball contact, 4v4/22-character profiling, and target-Mac 60-fps acceptance remain open. On integration, replace `FootballerVisual.set_team_color()`'s blanket surface/body overrides with kit-specific material handling; otherwise the merged hair/eye surfaces and exposed body skin would receive a team tint. The prototype remains out of the active roster.

## Reproduce

Run from repository root. Use explicit Python failure exit codes and shell deadlines so an error cannot be mistaken for a successful Blender exit.

```sh
timeout 90s blender -b --python-exit-code 1 --python tools/blender/beechlawn/build_shane_denham_player.py
timeout 60s blender -b --python-exit-code 1 --python tools/blender/beechlawn/validate_shane_foundation.py
timeout 90s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --neutral --body-views
timeout 60s godot --headless --editor --path games/beechlawn_rovers --import
python3 games/beechlawn_rovers/tools/run_smoke_tests.py shane_denham_import_smoke.gd
```

Next: finish the BR-022 body/head proportion gate in the current matched views, then proceed to the planned face/hair sculpt and purpose-built kit. The complete sequence remains in [`br022_shane_likeness_and_kit_plan.md`](br022_shane_likeness_and_kit_plan.md).
