# Camera impact shake follow-up

Owner reprioritized camera shake on15November. This repairs the existing
system; it does not introduce a second shake system or change move/gameplay
clocks. Standing instruction: "Commit and deploy any changes." Mac publication atfb01d89 is verified: run43761306666 succeeded, exact
mac-latest tag and uploaded ZIP confirmed. See mac_publication.json.

## Result

All three coverage modes schedule paired signature/finisher impact through the same
existing clock, independent of shot holds, previous trauma or cut preference.
The removed broadcast finisher writer could wait for its shot/previous shake.
The SLAM shot also no longer tops up a scheduled throw pulse after decay or
replays it when the shot arrives late. Standalone SLAM cuts retain fallback.

A controller emits move_landed after GrappleRig releases a completed move.
A short-lived, consumed/expired completion cache prevents that notification
from causing another pulse. Qualifying moves without a delivered scheduled
cue retain their landed-event fallback; ordinary paired holds stay steady.
Existing camera-cut decisions are preserved.

OFF cancels existing trauma and drops/consumes new cues, so enabling shake
later does not replay an old hit. LOW/HIGH and their saved choices are retained.
Strengths/decay remain unchanged: signature trauma.75, finisher1.0, scale1.0/1.8,
linear trauma decay3.5/s with squared displacement. An isolated signature
pulse expires around.214s and a finisher around.286s. New tests bound offsets
under.2 and keep a real root AnimationPlayer advancing under all three settings;
no time-scale, pause, simulation-rate or animation-speed changes are introduced.

The running inverted drop's startup is the catch at source37. Its authored
impact is59, so camera-only recipe metadata uses59/66 instead of37/66.
MoveDef/gameplay/reversal timing and every animation asset remain unchanged.
Character-specific landing fit remains open: this is an authored impact cue,
not a claim that the existing Roman mesh is now grounded at59.

## Validation and evidence

45 distinct focused cases pass:31 camera/finisher/set-piece cases and14 paired
pose-wiring cases. New lightweight fixtures use the real GrappleRig progress
and AnimationPlayer clock, avoiding arena setup. The isolated published-code
negative control reproduces the timing, duplicate-writer and OFF regressions;
see negative_control_summary.json. Its continuity-case failure is the old OFF
cue banking, not evidence that the old code froze animation.

Independent read-only architecture review found no remaining material issue in
cue ownership, completion ordering/expiry, OFF handling or animation continuity.
The final combined45-case report is focused_results.xml; logs and envelope
samples are adjacent. No full-suite-green, native frame-pacing or visual
feel acceptance is claimed. Native feel awaits owner review on the Mac.

## Research boundary and retained coverage

The previous GitHub interface research does not establish a complete per-move
Fight Forever shake specification; universal shake is not inferred from it.
Aegis retains impact-based coverage: medium/heavy blows, weapons, downing
throws, signatures/finishers and major set pieces. Light jabs and ordinary holds
do not receive an impact pulse merely for existing/finishing. Reference/source
basis is gauntlet/refs/ff_initiative_2026_11_14/README.md, with the authored
running-drop beat documented in that initiative's batch3 review.

Next: resume the remaining backlog in
owner priority order. Landing-fit diagnosis remains queued; no landing changes
are included here.

## Integration

A newer Kenny animation batch8cb7576 landed during this repair. It is retained
when integrating the camera changes. All45 camera/finisher/set-piece/pose cases pass
on the combined tree; this camera work does not reauthor
those independently produced animations. Envelope data is sampled from the
actual camera code by envelope_probe.gd, not a separate visual implementation.

Upstream8cb7576 already has a failing full CI run43757652691, before this
camera repair; its Mac build43757652690 succeeded. The combined camera/pose
focused checks are the delivery gate here. No full-CI-green claim is made.
