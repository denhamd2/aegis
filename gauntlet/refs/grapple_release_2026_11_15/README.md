# Running-drop fitting and grip release — ready for publication review

Implemented in GrappleRig and the existing paired recipe; no animation source,
MoveDef damage/timing, body-root ownership or public controls change. Scope is
removing the unwanted fitting lift and stopping late grip IK during release.
The asymmetric load/wrap choreography remains a separate source correction.

## Behavior and evidence

- Preserve existing3D fitting through source55, including the opposite-order
  critical52.5frame. Then snapshot each actor's cosmetic separationY and release
  it with a smooth curve through55–59. All pushes, pull/repair/rollback and
  no-contact settling share that constraint and existing .10/.45m caps.
- Constraint stays at zero through recovery; next begin resets it. No new clock,
  damage event, gameplay RNG, animation pause or physics ownership system.
- Existing grip countdown is scheduled at111/132. Actual measured trace: full
  grip54.5, fade begins55, zero by58, impact59. This accounts for the existing
  presentation/player order without changing scheduling for other moves.
- **33 distinct focused cases pass**:32case run plus one additional actual-pair
  clock regression in the separate7case release suite. Original reports are
  preserved; overlapping6cases are counted once. The no-contact settle negative
  control fails exactly its two expected assertions, with zero errors.
- Mannequin body/arm maxima .031/.061m; Cody→Roman .052/.147m; Roman→Cody
  .034/.077m. These remain unchanged versus the published source3 baseline;
  Cody's earlier load-arm issue is not declared fixed. Pre55 serialized joint
  coordinates differ at most1μm (trace precision). Both separationY values are
  zero at impact59 for all three cases.
- Hold37–55 is reported separately from release55–59. Unconditional median
  contact error and reachable counts remain problematic on real wrestlers;
  fewer required hold samples during release are not scored as a better hold.
- Post-IK release wrist step peaks .091/.100/.099m per60Hz tick, below the
  existing .20m pop bar. Sampled post-IK core/limb joints remain above .069m.
  This does not certify mesh clearance or native smoothness.

## Visual review

Independent visual-qa: **partial improvement; full-move acceptance pending**.
Matched1.966667s side frames show a lower handoff/less hover. The authored impact
pose still remains airborne. Wrist/torso projection overlap remains, so zero IK
weight does not prove clean visual disengagement. No obvious new knee inversion
or floor breakthrough appears in either wrestler order. Side view plus game
camera retain7beats/both roles; the bare game-camera framing remains too wide
for contact judgement. Opposite-order turnover/impact/recovery were also viewed.

| Dimension | Review |
| --- | --- |
| Smoothness | Unknown visually from stills; bounded wrist-step data available. |
| Pose accuracy | Handoff improves; original load hand roles still mismatch reference. |
| Physical realism | Hover reduced; full knee/body clearance remains open. |
| Weight/impact | Authored airborne impact/settling remains open. |
| Attacker choreography | Arm follows descent; clean visual separation unverified. |
| Defender selling | Reaction/recovery needs normal-speed review. |
| Timing/speed | Actual sample clocks verified; perceived pace unaccepted. |
| Presentation | Side views useful; bare wide views do not establish arena appearance. |

[Measurements](measurements.json), [unique validation count](validation_summary.json),
[focused run](focused_32.xml), [actual-clock suite](height_clock_7.xml).
Capture/test shutdown resource/material warnings remain recorded. No whole-suite
all-green, AAA/10/10, completed-move or native M1 performance claim. Owner approved commit, push and Mac publication for this batch. Exact release
verification is pending.

Next: reference-led source reauthoring of right forearm upper wrap/left free arm,
then contact binding measured against that choreography. Do not force both
wrists to a new symmetric shoulder target or hide failure by loosening limits.
