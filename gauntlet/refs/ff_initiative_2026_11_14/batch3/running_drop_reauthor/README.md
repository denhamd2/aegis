# Running-drop authored wrap and boot arc

Owner approved committing, pushing and deploying all current changes. Final
candidate4 is published atbf785ec;72 focused cases pass. Mac run43753948084
succeeded; exact mac-latest tag and uploaded ZIP verified.
[Publication receipt](mac_publication.json).
This is a bounded animation improvement, not full-move acceptance.

## Result and source

The attacker performs an authored right-forearm upper-body sweep with a free
left arm, instead of runtime bilateral waist forcing. The defender's boots
follow a rising arc through the inverted turnover. Recovery closes the fingers
gradually rather than curling all26 chains in the final three frames.
Gameplay roots, duration2.2s, impact59, approach and handoff remain unchanged.

Use only the TOP VIDEO row of `../../../ff_review/references/running_grapple_inverted_drop.png`.
Independent reference review corrected the rejected horizontal-backbump reading:
at55/59 the defender is inverted. The clearly observed49 upper-body wrap is
measured as forearm-to-shoulder surface proximity. The occluded later grip is
not enforced as a speculative continuous shoulder hold. See `reference_review.md`
and annotated `reference_landmarks/`.

Canonical authoring: `game/tools/blender/wrestling_clips.py` and immutable
`running_drop_approach_baseline.json`. Editable native:
`tools/blender/animations/running_grapple_inverted_drop.blend`.
Full317-clip GLB SHA256:
`bd77d216984dba1b990a38ddc43b7879b78785bccde12040ecdcd1c517304374`.
All315 unrelated clips are bit-exact; the two selected clips match frozen4.
Only the two intended roles change among146 baked roles. Approach0–30 is
exactly preserved; end66 differs only export float noise. Current authoring
inputs, including the baseline fixture, are pinned by the existing guard.

## Validation

`final_validation/` contains21 runtime +51 resource/authoring cases, all passing.
Coverage includes both real wrestler orders, independent raw body/arm limits,
required contact coverage/coherent clocks/penetration, actual wrist IK weights,
release countdown/height, role retargeting, full-body wiring,60Hz samples,
cadence, joint limits and deformation guards. The final imported selected clips
have zero holds/snaps. Attacker mean summed-speed jerk is39.43 versus47.35
published; defender39.70 versus32.88. These are diagnostic measures, not a
normal-speed visual acceptance score. No thresholds/budgets were relaxed.

| Pair | Maximum body overlap | Maximum arm overlap |
|---|---:|---:|
| Mannequin |.0250m|.0476m|
| Cody→Roman |.0109m|.0617m|
| Roman→Cody |.0180m|.0521m|

Both real orders and mannequin have zero forearm surface gap at49. Signed
penetration remains visible and is checked separately; a1µm numerical epsilon
handles float32 roundoff at an exact limit. See candidate3 runtime traces;
candidate4 changes only attacker finger tracks, with all body/arm/defender
tracks exactly unchanged. Final recovery captures inspect the actual4 import.

## Review and remaining work

Independent visual QA accepts the improved wrap/boot arc for bounded Mac review.
55 has boots above hips/head below hips, but the torso remains more horizontal
than reference. Final source correction removes the measured recovery snap.
Stills do not prove motion smoothness, exact release timing or weight of impact.

Landing fit remains open: Roman head/back skin minima at59 are.187/.284m above
mat, reaching near contact around61 (head−.001m/back.041m). Bone minima and
skin minima are different measures. Isolated FK reproduces the live retargeted
landmarks, so no global pelvis change or guessed constant offset is justified.
Next is a measured move/defender-specific landing fit across the entire55–66
interval, all roster cases and unchanged catch/carry/handoff. Early real toes
reach about−.049m and handoff other surfaces−.0215m; these remain open.
Rig teardown lifetime, normal-speed recovery and native M1 performance are also
unverified. Prior Kenny-beard and commentary test failures remain outside this
batch;72 focused passes do not establish full-suite green.

Capture/import shutdown material/resource/socket warnings are preserved in logs.
The disk-full export was discarded; the complete retry passed exact parity.
Mac publication receipt records the exact commit, uploaded ZIP and digest.
