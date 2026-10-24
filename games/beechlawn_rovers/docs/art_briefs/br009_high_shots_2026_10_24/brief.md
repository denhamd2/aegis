# BR-009 — high-shot saves

BR-009, item 9 of 27, remains in progress. This pass fixes the owner's report
that keepers could not save high shots. Distribution animation and native Mac
play-quality/performance acceptance remain open.

## Confirmed causes and changes

The initial travelling-ball fixture saved only two of eight reachable high
central/corner shots across the two actual keeper rigs. A height-cutoff-only
probe changed none of those outcomes. The old overhead pose reached roughly
1.91 m, all high shots selected that central pose, and save commitment stopped
the lateral movement needed to meet a corner shot. The 2.25 m root-relative
height limit also excluded part of the 2.44 m goal.

Three original Blender clips now provide overhead reach and left/right high
dives on the unchanged shared skeleton. They are an animation-only add-on;
the shared body, heads, kits and existing motion libraries are preserved.
The actual exported wrist extension determines the physical take-off height.
Godot supplies bounded vertical/lateral launch velocity through CharacterBody
movement and gravity, while save recovery still blocks ordinary locomotion.
The root is not teleported to the ball.

Longer-range shots exposed a second timing failure: the first implementation
peaked and landed before arrival. Take-off delay and animation preparation now
align the jump apex and glove extension with the predicted arrival. The
existing reaction delay, handling legality and hand-contact window still gate
the save. High central fast balls may be tipped over the bar; other reachable
contacts retain the existing catch/parry selection. Recovery ends with natural
landing and restoration of the standing collider.

## Validation

- `keeper_high_shots_smoke.gd`: 18 cases on both real keeper rigs. All 12
  reachable high shots save; all six unreachable, late or over-bar shots remain
  unsaved. The cases include short and longer arrivals, both lateral sides,
  landing/collider restoration and tips physically clearing the bar.
- Seven existing regression checks pass for low/diving saves, high crosses,
  legal handling/recovery, distribution, possession skills and shot contact.
  See `checks/regressions.log` for the eight-test suite including the new case.
- Three exported actions start at 0 s, end at 1.3 s and use the original
  65-bone rest transforms. Source authoring is 60 Hz; full extension is at
  0.25 s before runtime preparation scaling. All 24 protected assets retain
  their pre-pass hashes. See `animation_audit.json` and `export_audit.json`.
- All six full matches pass the existing chance gate: 34/24 physical shots,
  58.6%/41.4% shot share, both teams qualifying in 6/6 fixtures. Each side has
  contested attempts in every match. The earlier Boardeaux zero-shot fixture
  does not recur. Keep cross-machine/human consistency open rather than
  treating one cloud run as universal balance proof. See `ai_chances/summary.json`.

The short-arrival negative fixture uses the physics-calibrated flight solver.
The generic launch helper clamps flight time to 0.35 s, which made an earlier
"late" fixture arrive after the reaction delay. The corrected test asserts the
actual crossing precedes reaction, rather than trusting its requested time.

## Native review and limits

[Four-save review](native/high_saves_review.mp4) and
[contact still](native/match_broadcast.png).

The actual 11v11 scene is loaded, with unrelated actors parked for four
isolated real-ball sequences: John overhead tip, John high left, Boardeaux
overhead tip and Boardeaux high right. Native metadata records all four glove
contacts, with swept hand gaps of 0.211–0.226 m. The reviewed contact frames
show overhead/sideways extension; the sequence includes take-off and recovery.
This is controlled contact evidence, separate from the full-match chance test.

Godot 4.6.3 Forward+/Vulkan, Xvfb, Linux llvmpipe software GPU, 640×360. The
64-frame review samples 60 Hz physics at 10 frames/s over 6.4 simulated seconds.
It establishes native engine appearance and live contact, not 1080p60 Mac
performance or final AAA goalkeeper animation. Existing headless shutdown
warnings about ObjectDB/resources remain. The existing Mac download has not
been rebuilt with this pass; the football Web version remains retired.

## Sources and workflow

The archived John goalkeeper sheet and both goalkeeper kit/glove sheets remain
the appearance references in `references/README.md`; no body/kit/head redesign
is part of this fix. Motion is original, authored with headless Blender 4.3.2
using create-player, Blender animation/rigging and Godot export guidance.
No extracted PES motion or paid assets are used.

Source: `tools/blender/beechlawn/author_keeper_high_saves.py` and
`football_keeper_high_saves.blend`. Runtime: `goalkeeper_controller.gd`,
`football_player.gd` and `footballer_visual.gd`. Reproduction/probes are retained
in `before.json`, `height_probe.json`, `long_range_probe.json` and `after.json`.

Next: BR-021 (21/27, in progress), stride and foot-plant polish with moving-ball
contact rechecks. BR-008 (8/27) retains cross-machine/human chance acceptance;
BR-009 retains distribution motion and native Mac match acceptance.
