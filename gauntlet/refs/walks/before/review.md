(Independent reviewer, walks BEFORE fixes; read-only.)

Main finding: every clip paces. The arms swing WITH the same-side leg (verified from Cody's boot flag, Kenny's wrist tape and Roman's front frames), so the probe's "hands +0.6..+0.99" reading is correct and the "opposes the legs at 159 deg" joint-space reading is misleading. The whole yaw chain is inverted: hips -0.97..-1.00 (natural +1); entrance shoulders +0.77..+0.95 (natural -1). Likely cause: the thigh and upperarm local axes have opposite sign conventions, so "opposite" in Euler numbers comes out in phase. Fix: negate the upperarm swing (or shift it half a cycle), negate pelvis yaw, and in the gameplay clips re-key the chest to counter the pelvis.

Shared problems:
- Dead pelvis in Entrance, Stalk, Jog and Drive (sway 0, roll about 0).
- Rigid gameplay spine (4.6-6.9 deg total).
- No visible heel strike: the leading foot lands flat, and foot pitch is an identical 22 deg in all three entrance walks.

Scores: Roman Walk_Slow_Look 4, Cody Walk_Crowd 4, Kenny Kenny_Walk 5, Entrance_Walk 3, Walk_Stalk (all 3 men) 2, Run_Jog 4, Run_Drive 3.

Per clip:

**Roman Walk_Slow_Look**
- Flip the arm phase; keep 15-20 deg of swing and the arms abducted about 10-12 deg.
- Stance knee 5-10 deg at strike and mid-stance; 55-60 deg in swing. It currently stays at 27-65 and he creeps.
- Flip pelvis yaw (about 5 deg) and add a chest counter of 4-6 deg.
- Counter-key the neck yaw at about -0.8 of the pelvis+chest yaw so the head is steady under the slow look-around.
- Heel strike about 15 deg dorsiflexion, rolling to 25-30 deg at toe-off.

**Cody Walk_Crowd**
- Flip the phase. Remove 15-20 deg of forward upperarm bias, so the swing runs about 25 deg forward to 15-20 deg back, past the thigh.
- Elbow 15-30 deg.
- Step about 0.65 m at about 110 steps/min (cycle about 1.1 s), double support 0.2-0.25. It is currently 138 steps/min, 0.52 m, double support 0.5: mincing.
- Flip pelvis yaw (6-7 deg) with a chest counter of 8-10 deg; 1-2 deg of chest roll toward the planted side.

**Kenny Kenny_Walk** (best; loosest torso)
- Flip the phase and remove about 15 deg of forward bias; keep the 43 deg amplitude.
- 100-105 steps/min at about 0.65 m step.
- Flip pelvis yaw; chest counter at about 1.5x the pelvis.
- His hair floats on head turns: a weights issue, not this job's; note it only.

**Entrance_Walk** (1.6 m/s, all three men; it is a skipping jog: duty 0.45, double support 0, flight 0.10)
- Flip the phase.
- Foot on the ground about 60% of the cycle, with 10-20% double support: cycle about 1.0-1.1 s at a 0.8 m step, no flight.
- Pelvis lateral shift 3-4 cm (once a cycle), roll 4-6 deg, dip about 3 cm.
- Flip pelvis yaw; chest counter at about -1.5x.
- Chest pitch 3-5 deg forward; level the head (he leans back, chin up).
- Fix the 0.84 skate: a step about 15% longer, or play at about 1.35 m/s.

**Walk_Stalk** (gameplay, 3.5 m/s: high-knee running legs at 225 steps/min, flight 0.25, zombie arms with the elbow frozen at 66-78 deg, 0.80 skate)
3.5 m/s is above the walk-to-run transition, so either:
- (a) slow it to about 1.8-2.0 m/s as a real walk, or
- (b) make it a proper jog: elbow 80-95, upperarm 30-35 deg each way in opposite phase to the legs, about 165-170 steps/min.

Either way:
- knee lift 60-65 deg, not 75;
- flip the arm phase and pelvis yaw;
- chest counter 6-8 deg;
- pelvis sway 2-3 cm and roll about 4 deg;
- match the step to the speed (about 25% longer).

**Run_Jog** (4.2 m/s)
- Arms a full half-cycle out of phase with the same-side thigh; keep the amplitude.
- Step 1.2-1.3 m at 175-180 steps/min (flight about 0.35, now 0.64).
- Forward spine/chest pitch 5-8 deg.
- Chest counter-yaw 8-10 deg against pelvis yaw about 5 deg, with the pelvis sign flipped.
- Pelvis sway about 1 cm; tighten the lateral foot placement.

**Run_Drive** (7 m/s)
- Cap the upperarm swing at 60-70 deg total; elbow 80-100 (110 at the back).
- Add 5-10 deg of abduction so the hands stay outside the midline (the right forearm currently crosses the chest).
- Phase exactly opposite the thigh.
- Forward lean 10-15 deg.
- At toe-off: stance knee 10-15 deg and about 40 deg of ankle plantarflexion.
- Fix the 0.75 skate: a longer step, or play at about 5.3 m/s.
- Flip pelvis yaw and add a chest counter.
