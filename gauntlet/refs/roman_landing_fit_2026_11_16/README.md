# Roman running-drop impact fit — 16 November 2026

Publication: focused validation complete; Mac publication pending. Includes the
newer Kenny loop-4 commit `ec72208` without replacing its animation assets.

Roman's retargeted defender clip now receives a measured, character-specific
hips translation during source frames 55–63. The source Blender motion, root tracks,
rotations, attacker, shared animation library and other characters are unchanged.
Both Roman skeletons receive the same model-space displacement through their
own parent axes: body localY and worn/hair approximately localZ. Adaptation
bakes this once into private clips; there is no gameplay-time skinning/solver.

## Measurements and verification

The old coarse floor diagnostic counted `lambert1_skinned` and `Ringlets` hair
as head/back support. Roman's blank-material `body_skinned` is internal tongue
geometry. The new diagnostic separates those surfaces from skin and gear, and
stops arm/leg ancestry before classifying torso support. Hair remains visible;
it simply cannot establish skull contact. Boots remain protected measurements.

| Actual controller clock | Before: head skin | Fitted: head skin |
| --- | ---: | ---: |
| source frame 59 | 0.2461m | 0.0211m |
| source frame 59.5 | 0.1923m | 0.0080m |

- **37/37 focused checks pass**, including both imported parent axes, unchanged
  approach/handoff and rotations, 120Hz interpolation samples, source/mesh
  fingerprint tripwires, release/grip timing, swapped roles and authoring gates.
- Dense real-controller probes cover impact, actual completion and12 Down-state
  samples. Roman's physical playerA and playerB impact minima both equal0.0211m.
- Intermediate body/root phase samples, with simulation still 60 Hz, have minimum
  protected skin/gear clearance0.01258m within source frames 55–63.5. This is an offline
  diagnostic phase shift, not a gameplay clock change.
- A simple smooth pulse failed the dense floor bounds; the shipped constrained
  Bezier envelope avoids that penetration. It has zero endpoint velocity and
  acceleration before sampling into linear animation keys. Added keys are120Hz;
  existing keys outside the window and all rotations retain their values.
- Pair capsules remain within existing tolerances: body overlap0.016m
  (prior0.011m), arms0.062m; the authored frame49 forearm contact remains valid.
- Seven bare Forward+ side captures show the inverted impact reaching the floor
  without obvious new deep interpenetration. Sparse captures do not establish
  continuous recovery quality. Two repeated Vulkan null-material groups occurred
  at renderer shutdown after the final capture; GdUnit also reports shutdown
  resource-leak warnings despite all 37 assertions passing.

`baseline_roman.json` and `baseline_cody.json` retain the original probe labels;
Roman hair/tongue classifications above supersede their coarse `cosmetic` flags.
Final traces use the corrected classifiers, active blend shapes and post-modifier
bone snapshots. Bone/morph timestamps and pose clocks must match the sampling
physics frame; skinning uses the final skeleton world frame after all callbacks,
including any later PairSeparation translation. The mat plane is worldY0.
The observed body evaluation is one60Hz tick behind the reported body-player
clock; the generator accounts for this measured half-source-frame lag.

## Reproduce

From the repository root, with Godot4.6.3 imported resources:

```
godot --headless --path game --fixed-fps 60 tools/probe/landing_fit_probe.tscn -- --wrestlers cody,roman --out /tmp/landing.json
godot --headless --path game --fixed-fps 60 tools/probe/landing_fit_probe.tscn -- --wrestlers cody,roman --half-tick --out /tmp/landing-half.json
godot --headless --path game --fixed-fps 60 tools/probe/landing_fit_probe.tscn -- --wrestlers roman,cody --swap-roles --out /tmp/landing-swapped.json
python game/tools/anim/fit_roman_landing.py gauntlet/refs/roman_landing_fit_2026_11_16/baseline_roman.json
```

The last command requires NumPy/SciPy (measured with SciPy 1.17.0), only for offline
regeneration. `envelope_generation.json` records the baseline digest and fitted
coefficients; runtime constants normalize by Roman's default roster stature.
`fingerprints.json` records measured implementation/assets. Refit and rerun the
surface probes after changing the source performance, Roman mesh/rest or adapter.
`paired_shot.tscn --controller-finish` enables the real Down-state handoff for
render review; historic direct-rig captures keep their old behavior by default.

## Remaining limitations

This is an impact fit, **not full running-drop acceptance**. At source frame 65 Roman's
boots are already0.0538m below the mat while his back is0.1084m above it. A uniform
translation cannot fix both; the fit returns to zero before that phase. Late
boots/back need source pose or anatomical correction, not more whole-body lowering.
The original Cody-defender baseline also has head/torso/boot penetration; no Roman
profile is applied to Cody or Kenny. Their own anatomical fitting remains open.

Visual QA observed a recovery orientation excursion between late active and Down
captures. This profile does not change rotations and is zero in that interval;
consecutive-frame/normal-speed review is still needed before accepting recovery.
The torso through55, early toes, rig teardown lifetime and full reference-led
acceptance remain open. Native Mac appearance, feel and M1 frame pacing await
owner review/measurement; no 10/10 or 60 fps claim is made.
