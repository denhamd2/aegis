# BR-019 — advanced shots and cross variants, 23 October 2026

Item 19/25 remains in progress. Continue the current independently simulated
ball, shared humanoid rig, current heads/kits and 60 Hz authoritative gameplay.
References: archived Shane/player/keeper sheets, supplied worn-ball and goal
sheets, gameplay composite and the project's reference implementation plan.
Static sheets establish body/kit/ball scale; they do not supply motion capture.
New clips are original football animation, not extracted PES/EA data.

Five gaps: ground shot profiles are identical; no curved-flight execution;
no lifted-boot volley; no actual-bounce half-volley; only one cross trajectory.
Use create-player/production/animation guidance and blender-director,
blender-animation, animation, rigging and godot-export. Headless Blender bpy
is available. Preserve existing assets and add a separate animation-only library.
Protected-source hashes are recorded alongside this brief.

Implement keyboard modifiers (Z finesse/lofted cross, X power/driven cross,
V low/early cross), preserving R/T and ordinary Space. Select air strikes from
actual ball height/flight/bounce and validate the evaluated boot at the authored
marker. No ball repositioning or wider remote kick reach. Curved shots use a
bounded spin force; ground impact ends airborne curve assistance. Cross variants
retain committed recipients and use distinct ballistic targets/time/runs.

Acceptance: physical shot profiles and curve, actual keyboard modifiers,
mirrored marker-gated volleys/half-volleys, misses/interruption/remote rejection,
whole cross-to-receiving action, existing ground/header/keeper regressions and
six natural full matches. Review full new clips in Blender and native close/
broadcast sequences. Native cloud captures do not establish M1 feel or 1080p60.
Dedicated keeper high-claim animation is a BR-009 dependency, still open.

## Implemented

`ShotPlanner` supplies standard/power/low/finesse and contextual boot-strike
profiles. Neutral default attributes preserve the ordinary shot; shot-power,
shooting/finishing, running and pressure affect special strikes without invented
individual ratings. Finesse uses modest signed spin and a bounded airborne
Magnus force; real landing/stoppage ends curve assistance. Existing shot event,
foot-contact reach, keeper/rules/audio paths remain shared. Ground variants
reuse the current instep swing; distinct finesse/power body motion is future
animation polish, not a new clip claim.

Z/X/V are captured at the start of Space or T charging, so releasing the
modifier before the main button does not silently change the action. R/T and
ordinary Space retain their roles. Space selects a header, volley or rebound
strike from incoming height, trajectory and preparation time. Aerial foot
power can build while Space is held; the authored event times contact.

Original `AN_Beechlawn_Volley` and `AN_Beechlawn_HalfVolley` are animation-only
additions on the protected shared rig. Source frames 1–49 export at 0–0.8 s,
with contact at 0.30 s and evaluated boot targets 0.78/0.20 m above the actor
root. The source body/head in Blender pose stills is the diagnostic source;
current roster Shane is used in native close views. The actor stays grounded;
root movement, independent ball travel, bounce and impulse remain physical.

Cross variants keep aim bounds and committed recipients. Driven deliveries
use a lower/faster fixed-tick ballistic solution and target the striking foot.
Preparation moves the body behind the contact point, with flight-time lead
minus wind-up and braking-aware arrival. Lofted crosses spend longer aloft;
early crosses allow an earlier attacking lane and extra forward lead. AI picks
shot and cross profiles from position/marking, and can head, volley or take a
half-volley when physically reachable. A half-volley requires recorded upward
ground-contact rebound, never just a low ball or a forecasted future bounce.

## Reproduced failures and corrections

- A raw curve fixture initially spawned the ball inside its actor's capsule;
  placing the fixture at real foot distance isolated the intended flight.
- A half-volley setup read velocity before its queued impulse was integrated.
  Waiting one physics step makes the forecast use the actual incoming state.
- Rotating the reported contact normal again missed real turf rebounds on a
  spinning ball. The corrected detector requires a near-turf upward contact
  and downward-to-upward velocity change.
- Volley selection while a standard cross was rising pulled a striker toward
  its later low landing point. Heading preparation now survives the ascent.
- Driven balls exposed continuous-flight forecast error and over-leading a
  sub-second recipient. The new driven launch and foot forecast use the same
  damp-then-gravity fixed-step model. Body targets account for the boot offset,
  wind-up and braking, rather than raising contact reach or warping the ball.
- Fast boot markers need scheduling against the parent/child physics phase
  and tick boundary. Half-volleys retain their separate rebound timing. The
  authoritative 20 cm aerial boot-contact limit is unchanged.
- The exporter retained its first key at 1/60 s while new metadata subtracted
  the source start frame. Explicit zero-based export, GLB key-range assertions
  and imported toe-pose checks now lock the timing contract.
- A final-asset soak reported a 12-second live-ball stall. Four standalone
  repeats did not reproduce that exact event. A focused rutted-turf fixture
  did reproduce grounded crosses reversing both teams' pursuit: root-relative
  height misclassified a ball on adjacent turf as airborne. Ground/air gating
  now uses the surface beneath the ball and recent real rebound; the focused
  regression protects this handoff. The final six-match gate passes below.
  A failed soak now prints metrics and exits, preserving its 12-second limit
  instead of leaving a failed assertion idling until the process deadline.

## Validation scope and remaining work

Focused checks cover all six physical keyboard modifier combinations,
mirrored curve/flight, variable shot power, actual special-shot boot markers,
human and AI volleys/half-volleys, rejection without a bounce, ordinary
contested cross-to-header and driven cross-to-volley sequences, and grounded
recovery. Seventeen selected existing ground/keeper/movement/restart checks
pass. Final six-match metrics and native footage are recorded below. The CI pipeline repeats 70 regression invocations plus
six full short matches before Mac packaging.

BR-019 remains **in progress**, item 19/25. Dedicated high keeper claims depend
on BR-009 (9/25). Left-foot/weak-foot-specific clips, richer aerial physical
contests, finer shot-body motion and native M1 play-feel/performance remain
open; generic source-clay or a passing headless check is not final art approval.

## Final automated match gate

The grounded-recovery regression first fails for both teams (see the archived
red log), then passes with the turf-based guard. Final assets pass the imported
zero-origin duration/toe-pose checks, six physical keyboard variants, mirrored
human/AI boot contacts, no-bounce rejection, ordinary contested heading and
both driven-cross-to-volley cases. Seventeen selected existing regressions
passed before the final ground/air handoff correction; CI repeats all 70 checks.

Six complete final short matches pass the unchanged chance criteria:

| Kickoff / variation | Beechlawn shots (contested) | Boardeaux shots (contested) |
| --- | --- | --- |
| Home / 0 | 6 (5) | 4 (4) |
| Home / 1 | 6 (3) | 3 (1) |
| Home / 2 | 6 (5) | 1 (1) |
| Away / 0 | 4 (4) | 4 (4) |
| Away / 1 | 8 (7) | 2 (2) |
| Away / 2 | 4 (3) | 7 (7) |

Total **34/21** physical shots, share **61.8%/38.2%**; Beechlawn qualifies
6/6 scenarios and Boardeaux 5/6. Both have contested attempts in every match.
One Boardeaux scenario has only one shot and remains an AI tuning limitation.
No 12-second live-ball stalls occur in this final run. Metrics and counts are
observations/tests, not runtime shot quotas or team-specific boosts. The
initial rare soak stall was not reproduced in four standalone repeats; the
confirmed grounded-pursuit defect has its own red/green check. Future failing
soaks retain their actor/ball diagnostic snapshot and exit nonzero promptly.

## Native Forward+ motion review

Four bounded X11/Vulkan captures pass using llvmpipe (LLVM 19.1.7), 640×360.
Each folder contains the untouched capture poster/report/log/manifest, an H.264
sequence and a labeled contact sheet spanning the full clip. Close actions use
one 60 Hz step per frame (60 fps footage); wide sequences use six steps per
frame (10 fps footage). These are controlled integration scenes, not a claim
of natural match frequency or native Mac frame rate.

| Evidence | Actual contact/result |
| --- | --- |
| [Shane volley](volley_close/sequence.mp4) / [sheet](volley_close/contact_sheet.jpg) | 10.3 cm boot gap, grounded preparation/swing/recovery |
| [Shane half-volley](half_volley_close/sequence.mp4) / [sheet](half_volley_close/contact_sheet.jpg) | 12.6 cm gap, recorded bounce 16.7 ms before contact |
| [Driven cross → AI volley](cross_driven_home/sequence.mp4) / [sheet](cross_driven_home/contact_sheet.jpg) | Colly foot delivery 6.8 cm, Damo volley 5.0 cm; recovering defender starts ~5 m away, live keeper |
| [Shane finesse](shot_finesse/sequence.mp4) / [sheet](shot_finesse/contact_sheet.jpg) | Current shared instep swing, 12.5 cm boot gap, curved physical shot and goal against live keeper |

Visual review covers anticipation, strike and recovery across the sequences.
The volley raises the boot without lifting the character root; half-volley
returns to standing after its low rebound strike. The wide capture validates
the entire delivery-to-AI-strike handoff. Existing likeness/cloth/venue gaps
are unchanged. Ground special shots still share the original swing; the new
volley clips remain in need of finer weight transfer/support-foot polish and
native M1 review. No AAA animation or final gameplay-feel approval is claimed.

All four protected rig/body/older-animation hashes remain unchanged. Source
and evidence are committed with the implementation; CI must repeat the full
70-check suite and six-match gate before publishing the universal Mac build.
