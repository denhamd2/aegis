# Free-kick polish — BR-019 (19/27, in progress)

Approved scope: aiming/shot variety, wall behavior and taker approach/contact.
BR-015/016 supply restart/rule boundaries; BR-021 supplies shared motion. This
pass leaves celebrations, identities, heads, bodies, kits, existing source rig
and ordinary open-play shot/gait curves intact. Protected baseline: 417cc9e.

## Reference and motion contract

Owner's original `references/stadium_supporters_2026_10_25/2-70149.jpg` shows a
short angled approach, a compact facing wall, visible goal and restrained aim
cue. It guides composition/spacing, not copied animation data. Existing actual
shared walk/jog/shot actions remain the sources for approach/strike. Two original
60 Hz shared-rig brace/jump-pose actions are added in an animation-only GLB;
physical jump and horizontal approach remain fixed-tick gameplay movement.
No new skeleton, mesh, material, texture, runtime IK or root-motion authority.

Five baseline gaps: no approach; loose 1.1m root contact/deferred marker; static
centered four-player wall; serial-only free-kick choices; goal-height overrides
low-shot behavior and ignores planned direction/spin. Native before/after views
use the same pitch-side camera and unchanged daylight, with wider wall/flight
coverage and a closer contact review. Blender pose render verifies the changed
brace geometry; native captures verify actual shared players and live ball.

[IFAB Law 13](https://theifab.com/laws/latest/free-kicks/) guides 9.15m opponent
clearance and 1m attacking clearance from a wall of three or more defenders.
This is scoped direct-free-kick polish, not complete indirect/advantage/offside
rules. Preserve honest keeper/physical wall contact, misses and cancellations.

## Implemented slice

A 0.58s fixed-tick approach uses the existing calibrated gait, then the existing
shared right-foot strike. The actual imported pose supplies the taker's stance
offset; markers use the physics/immediate path, with a short anatomical grace
window and <=22cm live-toe check. A displaced ball produces a genuine miss and
returns to preparation without a fallback impulse or accumulating aim meshes.
Short free-kick passes also approach, avoiding a 1.5m commit-time teleport.

Direct-free-kick decisions evaluate visible keeper position and actual defender
lanes, with distance/angle-based shot/delivery selection. Power, curl and low
remain physically distinct. A discrete damped ballistic estimate targets the
goal plane; skill/charge-dependent placement error permits honest misses. Curl
uses an outward launch with actual side spin; ground rolling spin is cancelled
for airborne free-kick strikes. No keeper intent, forced outcomes or shot quotas.
The 18-dot preview shows intended flight without revealing execution error.

The 3/4-player wall covers the near side and faces the ball; the keeper covers
the open side. Opponents stay back and attackers clear the wall. Original
60 Hz brace/jump poses retain the exact 65-bone source rest. Wall reaction reads
the released ball's real velocity before timing a bounded CharacterBody hop;
low deliveries do not cause a synchronized blind jump. Physics resumes after
landing, with interruption/restart cleanup. The source master, existing rigs,
heads, kits and original motions remain protected by `protected_tree.txt`.

Blender reviews show only the unchanged shared source body with a diagnostic
source head; they certify the new wall pose, not individual facial likeness.
Native review uses the actual roster, both venues and unchanged daylight.
Headless tests establish rule/contact/miss/flight logic; cloud Forward+ software
captures establish visual integration. Native M1 feel and 1080p60 remain open.

## Review evidence and checks

- [Baseline wide motion](native_before/motion.mp4) and [updated wide motion](native_wide/motion.mp4): same Kilmore fixture, camera, daylight, power and target.
- [Arena contact motion](native_contact/motion.mp4): finesse approach and actual toe contact; [aim preparation](native_aim/key.png) shows the guide before release.
- [Blender brace](WallBrace1.png), [early jump](WallJump5.png) and [late jump](WallJump23.png) verify the original poses on the unchanged source body.

Native sequences are 640×360 Forward+ on llvmpipe, sampled at 10 frames/s
from 60 Hz physics (six steps per draw). They are integration evidence, not
60 fps animation smoothness, Metal parity or hardware performance evidence.
Each capture folder retains its complete controller/adapter metadata.

Planner/contact checks cover both attack directions and both venues. Actual
toe gaps are approximately 0.123m; the elevated-shot wall hop is 0.201m, while
low deliveries stay grounded. Further cases cover legal spacing, goal-plane
flight, visible-keeper target choice, distinct shot styles, stationary dead
ball, one impulse, displaced-ball retake, short-pass approach and cancellation.
Ten related regression fixtures pass, including the other restart kinds,
discipline, bilateral strikes, advanced shots, replays/results, shared gait and
roster resources. Normal window-close audio checks pass for both actual 11v11
venues and four audio-loop modes. Logic fixtures retain Godot's known cached
resource exit diagnostics; strict actual-startup close checks remain clean.
All 775 tracked baseline character/Blender files retain their Git blob hashes.

The complete 180s match passes with celebrations/replays unskipped: 16,505
physics ticks, seven shots and four contested shots per team, two saves per
keeper, and normal results. The first 180s host deadline expired during cleanup;
the bounded rerun passes in 231.6s on this shared host with a 240s deadline.
Only the runner's wall-clock allowance changes; match length, 60 Hz physics,
presentation and assertions remain intact. See [validation.json](validation.json).

BR-019 (19/27) remains in progress for broader aerial contest/strike polish.
Next acceptance: BR-025 (25/27, in progress), review the packaged free kicks
on the target M1 for input feel, animation and sustained 1080p60.
