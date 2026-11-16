# Running drop: authored asymmetric wrap and backward bump

Status: FIRST CANDIDATE ONLY. Source audits are complete; actual game pair
contact, retargeted mesh clearance and per-move visual QA remain pending.
Production animation library has not been replaced by this specialist.

## Reference and authored direction

Use the TOP VIDEO row of
`gauntlet/refs/ff_review/references/running_grapple_inverted_drop.png`.
The lower row is historical Aegis output. The sparse video panels show a
free left-arm windup at230.48, right forearm across the shoulder/chest line
at230.65, backward/horizontal turnover at230.82, disengagement and bump at
230.95, and sell at231.10. They do not support the former symmetric waist
carry. Anatomical right/left attribution is clearest in the rear-view
230.65/230.82 panels; hidden catch-palm contacts remain uncertain.

The existing gameplay id is retained. Timing remains2.2s, approach through
source30, catch37, impact59 and end66. Source frames are30fps; export samples
are60fps. The reference timestamps are approximate sparse-panel matches,
not newly measured full video.

Both roles are now authored together. Attacker's left arm opens/free through
43–55, while right wrist rises to shoulder height at49. Defender stays upright
through47, arches backward, is near-horizontal at55, then takes an upper-back
bump at59. Explicit59.5/60 spine/hip breakdowns prevent the shoulder blades
from dipping under the mat while the hips unfold. End66 is the original
SUPINE_AWAY/standing handoff. Root trajectory remains gameplay-owned; the
local pelvis moves only within that trajectory.

Source wrist intentions (right,forward,up metres in the base rig):

| Frame | Attacker right wrist | Attacker left wrist |
|---:|---|---|
|37|(.23,.57,1.25)|(-.26,.47,1.20)|
|43|(.30,.49,1.32)|(-.62,-.04,1.27)|
|47|(.30,.58,1.43)|(-.45,-.10,1.04)|
|49|(.25,.64,1.48)|(-.34,-.02,.90)|
|51|(.27,.65,1.36)|(-.32,-.08,.90)|
|55|(.24,.60,1.10)|(-.32,-.03,.88)|
|59|(.31,.17,.86)|(-.32,-.02,.94)|

The intended contact diagnostic is RIGHT forearm (elbow→wrist) proximity to
the defender's near/left shoulder/upper-chest surface. A palm on the chest
centre is not equivalent. Do not apply generic bilateral waist IK/pull to
this candidate; both the free left hand and release must follow authored
motion. No defender supporting grip is established by the reference.
Actual runtime49–55 support coverage is UNVERIFIED. Local root-gap estimates
suggest late-turnover underreach is possible; measure that before another
internal pelvis/arm revision. This candidate does not claim matching contact.

## Source and reproducibility

Canonical source: `game/tools/blender/wrestling_clips.py`.
The former defender-only `_guard_running_release_curves` is replaced by a
pair approach guard. It restores exact historical scalar curves/handles
through30, including lagged source30 arm/neck keys at31..32. Later body/arms
are not overwritten by the old C3 leg-only guard. Contact/landing poses use
exact timing and clamped Bezier handles. No other clips use the new option.

```sh
AEGIS_ONLY_CLIPS=Run_Grapple_Attacker,Run_Grapple_Defender \
AEGIS_CLIP_OUTPUT=/tmp/aegis-running-wrap-scoped.glb \
blender -b --factory-startup --python game/tools/blender/wrestling_clips.py
```

`build_candidate.py` additionally saves the editable two-action native
`/tmp/aegis-running-wrap-candidate1.blend`, samples actual skinned base-mesh
clearance at every60Hz tick from33–66, and writes `source_curve_audit.json`.
Its export and the canonical scoped command are byte-identical. The native
file is a review artifact; no full production GLB is replaced here.

## Cheap validation and limits

- Both approach curves0–30: maximum scalar difference exactly0.0 at60Hz.
- Two clips only, both2.2s; nonconstant tracks sampled at60Hz.
- Base-mesh impact59: upper-back minimum4.743mm; head42.147mm above mat.
- Post-bump59.5: upper-back minimum0.067mm; head45.762mm above mat.
- No head/back mesh penetration across sampled33–66 in either role.
- Small source toe intersections remain: attacker8.91mm at39.5; defender
  14.76mm at64.5. These are recorded, not hidden by a body-only clearance.
- Base-mesh checks do not establish Cody/Roman/Kenny contact, clothing
  clearance, grounded real-mesh landing, smooth runtime playback or likeness.
- Full per-move both-role side/match-camera sheet and independent verdict
  remain required. No AAA/complete-move or native M1 performance claim.

Guides applied: `.claude/skills/blender-animation/SKILL.md`,
`.claude/skills/animation/SKILL.md` and its combat timing reference, and
`.claude/skills/godot-export/SKILL.md`. This uses actual installed Blender4.3.2;
no Blender UI/MCP or external paid service was used.
