# Match behaviour and broadcast repair pass — 22 October 2026

Owner-reported gameplay faults map to BR-002/021 (items 2/21 of 25), rules
BR-015/016/017 (15/16/17), camera/HUD BR-014 (14), and environment BR-023 (23).
These parent backlog items remain in progress; this pass does not certify full
football rules, final animation quality or native M1 performance.

## Reproduced movement faults

A sustained actual-match dribble launched the CharacterBody 1.128 m above the
pitch with 7.173 m/s upward velocity. The same run showed zero changing thigh
poses after frame 180 while travelling at 6 m/s. The ball and capsule shared the
ground collision layer, allowing the capsule to climb the rolling sphere.
Imported locomotion animations also had `Animation.LOOP_NONE` despite their
AnimationNodeAnimation nodes having `loop_mode=LINEAR`.

Players now occupy layer 4, ball layer 2, terrain/frame layer 1, and referee
layer 8. Players resolve terrain/other players; the ball resolves terrain and
player bodies, so it remains independent and can be blocked. Players cannot
use the rolling ball as a floor/platform. Motion libraries are owned per actor;
looping resources are explicitly copied/configured, leaving actions one-shot.
The same regression measures about 0.0014 m maximum ground-height error and
165 changing late leg poses. This proves those reproduced faults are fixed;
stride polish and broader human feel still require moving visual review.

## Match rules and control

A match-scoped restart controller owns preparation, aiming, animation contact,
physical release and follow-through. Whole-ball exits award overhead throw-ins
at both touchlines. Corners/goal kicks retain last-touch ownership. Manual
restarts use WASD aim, hold/release E for throw/pass, Space for free-kick or
penalty shooting; a ground arrow, power meter and contextual controls explain
this. Watch mode takes all restarts automatically. Preparation pauses the
three-minute clock; the clock resumes at release.

Original Blender-authored throw/card actions use the existing 65-bone rig in a
small animation-only GLB; the production body, kits, heads and existing clips
are untouched. The overhead throw release is at frame 39 (38/60 seconds from
export origin). The ball follows the hands only while dead and releases as a
rigid body. Existing kick markers time ground restarts.

Challenge classification uses plausible contact range, facing, relative speed,
ball/opponent order and slide/standing context. Careless contact awards a free
kick, reckless contact a yellow, and excessive-force slides a straight red.
Second yellows dismiss the actor. Defending fouls inside/on the penalty-area
boundary award penalties. Dismissal updates active arrays, selection, collisions,
AI/radar membership and tactical lanes. An emergency keeper receives a copied
keeper role/kit while preserving identity; fewer than seven ends the match.
Direct throw-in/indirect-free-kick goals and restart double touches have special
restart handling. Advanced advantage, offside, substitution menus, and nuanced
DOGSO/handball laws remain outside this pass.

## Net, pitch and introduction

Goals are awarded at whole-ball crossing once; the ball continues physically
into the net during a 1.6-second stoppage. Separate back/side/roof net collision
bodies drive a local speed-scaled bulge and damped recovery shader, with ground
and frame attachment masks. This is bounded visual deformation with collision
proxies, not a full cloth solver. Headless live shots verify contact at both ends.

Both penalty arcs are mirrored toward midfield: radius 9.15 m around each
11 m penalty spot, clipped to the outside of the 16.5 m penalty area. Existing
faded, uneven paint remains. The TorusMesh selection indicator no longer has
the erroneous 90-degree rotation that buried half of it; terrain clearance
protects its circumference.

The new 18-second cold open contains six three-second shots: frame, net, ball,
John O'Rourke, Boardeaux player-manager Des Feeney, and the worn/puddled goalmouth.
The player is explicitly `bordeaux_09`, separate from referee Des Feeney Sr.
Selected weather is respected. Team graphics, referee reveal, readable lineup
pan, skipping and camera handoff remain. Duplicate later detail shots were
removed. Character models and venue artwork are existing assets; these shots
do not constitute new likeness or environment quality approval.

## Validation and delivery

Run the new grounding, discipline, pitch and net checks, updated restart and
intro checks, existing contact/tackle/keeper/AI regressions, and complete short
Watch matches. `tools/capture_native.py --review-mode movement|throw|net|montage`
records actual Forward+ frames and scene metadata. Native software Vulkan
captures show appearance/motion; they do not establish Mac GPU parity or fps.
Use the existing universal Mac export and archive verifier. No football Web
export/deployment or wrestling changes belong to this pass.

Recorded first complete Watch match: full 180-second clock, 12,461 fixed ticks,
1,340.2 m ball travel, shots 7/5, contested shots 5/4, saves 4/5, score 1/1,
zero stationary samples. Counts describe that run, not guaranteed balance.

Final checks: **28 distinct regression scripts pass** across
the recorded suites, including actual 11v11 kick/shot contacts and mirrored
midfield attacks with full opposition. The final two complete Watch matches
produced shots 9/2 and 6/2, contested shots 7/2 and 6/1, saves 2/6 and 2/4,
and scores 0/0 and 0/0, with no stationary samples. These retain an open
BR-008 opposition-balance/chance-quality tuning task rather than claiming
consistent scoring. The earlier 1/1 run is retained above for transparency.

[Native motion/storyboard evidence](art_briefs/match_repairs_2026_10_22/README.md)
and [validation manifest](art_briefs/match_repairs_2026_10_22/validation.json)
record the renderer and package scope. The universal Mac archive was exported
and verified after the final code checks. No Mac device execution occurred.
