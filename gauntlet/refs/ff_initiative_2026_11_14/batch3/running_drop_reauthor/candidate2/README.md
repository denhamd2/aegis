# Candidate2: inverted turnover and medial right-forearm sweep

Status: authored candidate, NOT accepted or published. Main owns actual Godot
pair contact/retargeted clearance, review captures, tests and integration.

## Correction to candidate1

Candidate1 misread230.82 as a horizontal backward bump. Enlarged reference
landmarks show the defender's dark-haired head below/right of his waistband;
230.95 shows the legs above the waistband. Candidate1's flat horizontal carry
is rejected. Its49–55 shoulder-contact interpretation is also withdrawn:
230.65 supports a brief upper-body sweep, but not continuous shoulder support
through230.82. See `../reference_landmarks` and main's reference_review.md.
Sparse frames cannot prove an exact contact interval; current conservative
runtime diagnostic samples the49 snapshot only. No new hip grip is invented.

Candidate2 preserves free left-arm windup, changes right wrist49 from lateral
+.25m to medial−.08m so the forearm crosses the shoulder line, and follows
through toward the moving hips rather than holding both hands at the waist.
Defender rotates through45°51,85°53,125°55 and155°59, with bent legs during the
turnover then boots above the hips near impact. Explicit59.5/60/60.5 breakdowns
preserve skull clearance while settling the upper back. Both original66
handoffs remain. Approach0–30, catch37, impact59 and total2.2s are unchanged.

## Frozen artifacts

- `/tmp/aegis-running-wrap-candidate2.glb`, SHA256
  `056b5dbb40e1bd286decfaeb43b8d5aca0535728dfe6dfc22f6153bf6d35b01c`;
  307400bytes, exactly2roles,195channels perrole,2.2s. Dynamic tracks133samples
  at60Hz; constant tracks2samples.
- Editable native `/tmp/aegis-running-wrap-candidate2.blend`, two actions plus
  the CC0 base mesh,3.44MB. This is a review artifact, not a production library.
- Canonical builder `game/tools/blender/wrestling_clips.py` and frozen source
  fixture `game/tools/blender/running_drop_approach_baseline.json`.

The source fixture records original authored pose INPUTS/provenance, not a
read of generated game resources. Blender's nonlocal AUTO smoothing meant
that truncating the old action changed even earlier handles. Reconstructing
the complete original action then copying its keys/handles through32 preserves
all delayed source30 channels. This fixture is immutable across candidates.
It does not overwrite the newly authored later body/arm animation.

## Validation evidence

- `source_curve_audit.json`: every60Hz tick33–66, base skin minimum by region,
  actual FK joints, and scalar-curve approach equality0.0.
- `raw_export_boundary_audit.json`: published-vs-candidate GLB approach0–30
  translation/quaternion-component deltas exactly0.0 for BOTH roles. End66
  differs only float noise(~8e-8 quaternion,7nm translation).
- Source59 head minimum13.22mm; inverted upper-back clearance112.8mm. The
  source does not claim a flat back bump on59. Source60 back minimum6.25mm;
  overall back minimum4.84mm61. No head/back mesh penetration33–66.
- Small toe intersections remain: A8.91mm39.5,D10.68mm48.0. These are visible
  in the audit and need real-model review; they are not masked as a body pass.
- No generic waist IK or pull is requested. Runtime should measure the actual
  right forearm/shoulder snapshot without forcing a palm target or assuming
  continuous late support. Actual roster contact remains unverified here.

`build_candidate.py` reproduces the native, mesh audit and scoped GLB:

```sh
blender -b --factory-startup --python \
  gauntlet/refs/ff_initiative_2026_11_14/batch3/running_drop_reauthor/candidate2/build_candidate.py
```

Or export only the source clips using the canonical command:

```sh
AEGIS_ONLY_CLIPS=Run_Grapple_Attacker,Run_Grapple_Defender \
AEGIS_CLIP_OUTPUT=/tmp/aegis-running-wrap-candidate2.glb \
blender -b --factory-startup --python game/tools/blender/wrestling_clips.py
```

Do not replace the full production GLB with this two-clip file. Full source
regeneration, all-other-clips parity, per-move both-role six-beat side/match
sheet and independent QA remain required before publication. Native M1
performance and full move-quality acceptance are not established by these
source checks.
