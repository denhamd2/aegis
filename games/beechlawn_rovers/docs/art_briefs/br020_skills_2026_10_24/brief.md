# BR-020 — Defending and skill moves (20/27)

Scope: retain standing F / slide G tackles, Ctrl jockey, J contain and H
teammate pressure. Add K shielding plus U ball roll, I step-over, O body feint,
P drag-back, L directional turn and B fake shot. Space charge then E cancels
into a fake shot before contact. Aim selects the exit side; arrows remain
available independently of movement. Keyboard-only, original/free assets,
Mac-only, no wrestling changes.

Use create-player's animation-production checks, Blender animation/rigging
and Godot export guidance. Preserve the current head/body/kit assets,
65-bone rest transforms and existing motion/event library. Baseline hashes
are in `protected_before.json`. No extracted PES motion or paid assets.

Thirteen original 60 Hz animation-only clips share the current skeleton:
six left/right actions and an upper-body-only shield loop. Foot contacts map
source frame 19 to 0.30 s after zero-based export. The saved authoring body's
idle includes differently oriented feet; preserve the shipping neutral pose,
then plant the action's soles using bind-foot orientation and actual toe
offsets. Solve the weight-bearing crouch before either leg so supporting
feet remain planted. Preserve quaternion sign continuity and clip endpoints.

Skills require close physical possession and low ball height/speed. A marker
opens a bounded live-toe window; one real impulse changes the independent
ball's exit lane, with normal defender interception and no forced ownership.
Missed contacts, possession loss and stoppages cancel pending touches.
Follow-through can yield to a pass/shot after contact. AI may choose a lateral
roll only during carrying into a nearby frontal defender. No attack quotas,
forced outcomes, rating boosts or forced opponent reactions.

Shielding turns the body away from nearby pressure, reduces movement speed
and lowers shoulder-contact disruption; the upper-body filter preserves
locomotion legs. It does not prevent tackles or incoming possession changes.
A grounded drag-back briefly excludes only its owner's coarse capsule while
the ball passes between the modeled legs. Other players/terrain still collide;
the bounded exception is restored and reset at stoppages.

Acceptance: bilateral actual imported toe contacts, distinct exit trajectories,
no early/duplicate impulse, misses/loss/cancellation, fake-shot suppression,
shield movement/upper-body isolation and tackle counterplay; existing defense,
pass and replay checks; native Forward+ moving review and natural full-match
chance/stall regression. Native M1 motion feel/performance remains a hardware
gate. Final cloud checks and source/evidence hashes are recorded in
`validation.json`; these do not establish native M1 performance.

## Validated results

`export_audit.json`: thirteen clips start at 0 s, twelve skills end at 0.7 s
and the shield loop ends at 1 s. All 21 protected body/head sources and GLBs
are unchanged. The new animation-only GLB is approximately 721 KiB.

`skill_control_smoke.gd`: twelve bilateral live-boot contacts at 0.063–0.065 m;
one impulse each, none before the marker, no remote miss touch or duplicate;
possession loss/stoppage cancellation and drag-back collision restoration;
real-physics keyboard fake-shot cancellation; shield speed trade-off, unchanged
running-leg poses at blend 0/1, cycling legs with the overlay active, and a
clean standing tackle winning the ball. AI chooses a lateral roll against
nearby frontal pressure and preserves an open lane. Existing defensive controls,
standing tackles, passing and recorded facial replay regressions also pass.

The final controller checks additionally reject competing assistance and an
exit touch after a closer claimant wins arbitration. The same shared one-force
guard covers ordinary dribbling and skill preparation.

`native/`: 56 frames through six skill exits and shielding on the actual
pitch/roster asset. Each skill makes one native live-foot contact, all below
0.070 m. CharacterBody height stays within 0.000104 m across the fixture;
the authored approximately 9 cm crouch is visual weight transfer. Six 60 Hz
steps per draw produce a 10 fps simulated-time review in `skills_review.mp4`.
This is scripted diagnostic footage, with unchanged match assets, rather than
a natural match or real-time GPU benchmark. Forward+ / X11 / llvmpipe at 640×360.

`skill_moving_smoke.gd` exercises real braking CharacterBodies with physically
launched rolling balls: 3.36 m/s and 6 m/s entries make one contact each,
at 0.194 m / 0.146 m under the unchanged 0.28 m boot-contact bound. Full-sprint
entry is rejected with a control-pace hint. Setup damping uses velocity relative
to the carrier. `native_moving/` adds sixteen front-angle frames and two native
contacts at those speeds; `skills_moving_review.mp4` retains the moving review.
The stationary videos precede the moving/arbitration follow-up; the final
headless checks and AI batch validate those changes. Their isolated single-actor
setup forces and poses are equivalent to the captured ones.

`ai_chances_verified/summary.json`: the final six full three-minute matches
pass the unchanged chance/stall gate after the moving-control and arbitration
corrections. Beechlawn 34 shots, Boardeaux 19; qualifying
scenarios 6/6 and 5/6, with aggregate shares
64.2% / 35.8%. The away-2 fixture gives Boardeaux zero shots;
this remains an explicit BR-008 consistency task. Thresholds remain test gates,
never runtime quotas. `ai_chances/` preserves the earlier pre-follow-up batch;
`ai_chances_final/` is an intentionally interrupted intermediate check.
Native Mac feel/performance and wider stride/plant polish remain under
BR-021/025. This implementation has not been packaged into a new Mac release.
