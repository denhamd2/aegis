# Running inverted-drop source candidate — ready checkpoint

State: authored scoped candidate only. Production animation library/paired bakes
have not been replaced. Integration and actual visual/gameplay acceptance wait
for publication verification of the preceding runtime-role/library batch.
Kenny source/art work is paused and all its uncommitted assets are preserved.

## Established failure and clock correction

The real GrappleRig probe reproduces body overlap0.090m, arm0.061m and median
waist hold0.019m. The overlapping segments are attacker's pelvis–spine against
defender's left calf–foot. The historical `@1.25` output is elapsed ticks divided
by MoveDef total ticks, INCLUDING entry; it is not seconds. The initial catch
attribution was wrong and was corrected before any source animation edit.

Diagnostic instrumentation records actual paired player time: elapsed165ticks,
entry45ticks, paired1.983333s, authored frame59.5. This is just after impact118,
not catch74. Baseline role points and logs are adjacent. Main confirmed the
corrected source scope58–63. No catch/load pose or timing is changed.

## Existing source/reference reused

- Canonical original pose source: `game/tools/blender/wrestling_clips.py`,
  `Run_Grapple_Attacker` / `Run_Grapple_Defender`, with `rig_pose.RigPoser`.
- Existing body-frame `_body`, `_yawed`, measured limb reach, source NLA/action
  export and 60fps sampling remain authoritative. No proprietary clips imported.
- Actual timestamped reference panels in
  `gauntlet/refs/ff_review/references/running_grapple_inverted_drop.png` show
  catch230.23, load230.48, inversion230.82, impact230.95, raised-boots sell231.10.
- The historical Cross Rhodes sheet must not be treated as one homogeneous
  reference: its first row visibly says TIGER DRIVER'98, second CROSS RHODES.
  It cannot justify copying the first row's inversion as verified Cross Rhodes.
- OWA source impact40/30=80/60=1.333s and total2.2s are confirmed. The old
  0.9/1.9s reference was measured at10fps from the owner's59.94fps compilation.
  Original video is absent locally, so this audit does not claim a new frame
  measurement or retime it. Catalogue rear-grapple versus MoveDef front metadata
  and reused Samoan carry require a dedicated two-role reference pass.

## Candidate changes

Attacker key59 shifts the pelvis back2cm and opens the torso by6degrees after
release. Defender58/59 gives the near left leg a reachable outward flare and
matching knee plane, instead of sweeping the narrow shin channel through the
lifter; defender63 keeps the leg wider through the sell. Hip/head inversion and
impact height stay unchanged. Source recipes through55 and final66 are intact.
Only these two clips changed among317 recipe hashes; exact changed keys are
A59 and B58/59/63. Root trajectories, MoveDefs, PairedFit, Contacts and runtime
animation ownership are untouched by this source slice.

The new left ankle target is reached within0.000001m at58/59/63; hip-to-ankle
at58/59 is0.8085m, inside measured0.829m leg reach, with26degrees knee bend.
Attacker's modified59 keeps both ankle targets at0.104m. Existing unmodified
right-leg clamping is recorded separately in the source reach audit; it is not
presented as newly fixed or a passing complete deformation review.

## Export and integration boundary

```
AEGIS_ONLY_CLIPS=Run_Grapple_Attacker,Run_Grapple_Defender \
AEGIS_CLIP_OUTPUT=/tmp/aegis-running-drop-candidate.glb \
blender -b --factory-startup --python game/tools/blender/wrestling_clips.py
```

Candidate is307400bytes, SHA256
`55e06564110005021234611081b5a65827130da6936003adbce09678a61b6544`.
It has exactly2animations,133samples each, 1/60s spacing,2.2s duration.
Do NOT replace the full production wrestling_clips.glb with this partial file.
The main agent owns scoped pose-library integration/merging, import and tests.
Existing build_paired_poses.gd hardcodes AUTHORED and iterates all moves; scoped
candidate source/selection support is needed for efficient iteration, then a
reproducible final production export/merge. No full-library rebake was run here.

## Pending acceptance

- PairClearance after integration: body<=.05m, arm<=.08m, waist hold<=.05m,
  plus actual clockwise sample and both Cody/Roman slot orders.
- Cadence/pose/60fps checks, both skeletons, planted feet, head/mat contacts,
  transitions and unchanged catch74/impact118/end132.
- Actual front/side-close and broadcast captures at exact beats including
  74/132,118/132 and119/132; at least6readable beats with both roles. Default
  sheet fractions skip the exact impact. The legacy render_move_sheet.sh forces
  OpenGL; use paired_shot directly through Forward+/Vulkan instead.
- Expert review across the initiative's eight dimensions, then focused
  deterministic integration checks and publication only by the main agent.

No after-clearance/visual/AAA/10/10 or native-M1 performance claim is made.

## Integration checkpoint after runtime release0ef511b

The preceding runtime-role/library batch is now published and verified. Main's
scoped pose builder reports exactly2changed animations among146paired-role
animations. This does not establish clearance or visual acceptance yet.

Main's fresh real Cody→Roman BASELINE differs from the default authored-rig
case: body0.052m, arm0.147m, waist median0.030m/p900.086m (23inreach,289out),
worst arm excess0.067m at actual1.5667s / authored47. This is a load-phase
arm/contact defect outside the approved58–63landing correction. Keep it open
for a separate evidence-led fix; do not claim a whole-move pass if the landing
improves. The main agent is measuring this candidate on the default rig and
both real roster orders; no source expansion or tolerance change was made.

## Candidate2 and validation-parity correction

Candidate1 was not accepted: provisional measures improved the default rig but
regressed a real roster body case. Architect subsequently found an absolute
loader mismatch: it resampled30fps and removed immutable tracks while production
imports60fps/keep. Therefore previous candidate/runtime numbers and rendered
poses are diagnostic only, invalid for attributing source differences. Preserve
them as history rather than claiming a win or a confirmed source regression.

Candidate2 is now frozen at /tmp/aegis-running-drop-candidate2.glb. It restores
A59 torso and B63 sell exactly to baseline, changing only B58/59 to a compact
heel-back/bent-knee release with less lateral flare. Both role clips are still
exported and reviewed together. Corrected scoped bake at
/tmp/aegis-running-drop-candidate2-poses-60.tres uses generate_scene(state,60.0,
false,false); actual inspection confirms133moving keys per role,2.2seconds.
Canonical baseline parity and corrected default/both-roster measurements are
still required before source attribution or acceptance. No further source edits
will be made until that evidence arrives. Candidate2 notes/logs are in its own
subdirectory; candidate1 keys/export history remain preserved.


## Integration checkpoint: importer parity and candidate2 rejection

Earlier absolute GLTFDocument bakes were not production-equivalent: they used
30Hz by default and bypassed the scene importer's optimizer even after60Hz
was specified. Their numeric/visual comparisons are provisional diagnostics,
not valid source-only acceptance. The builder now accepts an actually imported
PackedScene; the isolated project copies production import settings. Canonical
res:// versus isolated canonical import produces exactly identical poses in
all146 entries. A small import helper preserves this workflow without importing
the arena or editing the game's cache.

Early omission of cosmetic Arena/LightRig/reflections in PairClearance matches
the full-scene published Cody→Roman numbers exactly (.052body/.147arm, waist
median.030,p90.086). The corrected candidate2 runs take13.08/19.92/19.51seconds
for mannequin/Cody→Roman/Roman→Cody on this host; these are tooling timings,
not native game performance.

Candidate2 is rejected with the production-equivalent importer: mannequin
body.060 atsource62, Cody→Roman .105 at63.5, Roman→Cody .034. The new conflict
is attacker right thigh/calf against defender left calf/foot. Cody→Roman arm
.147 and median hold.030 remain unchanged. Published poses are restored; no
new animation is committed or deployed. Next authoring awaits source-baseline
parity and architectural analysis of the58–66 trajectory after two failures.

## Candidate3 frozen; runtime cause under review

Candidate3 is saved and documented under candidate3/. It guards a coupled
outward knee/ankle release and preserves canonical curves before55/final66.
Its raw export passes the source-boundary comparison, but no runtime acceptance
is claimed. Runtime trace now confirms significant separator Y lift on the
published original (.329m at59,.278m at63), plus whole-body placement-history
changes between source variants. Further source compensation is paused while
architect/main test separator/pull policy against the unchanged source.
