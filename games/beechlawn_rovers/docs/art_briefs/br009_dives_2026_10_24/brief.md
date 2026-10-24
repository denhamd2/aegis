# BR-009 — full-stretch diving saves

Item 9 of 27, in progress. Approved scope: bilateral low, medium and high
full-body dives, physical sideways movement, glove contact, landing and get-up
on both existing keepers. Keep original/free motion, current bodies, kits,
heads, the 65-bone rig, shot power, reaction delay and anatomical reach.

## Baseline and production direction

The actual 11v11 travelling-ball fixture has twelve reachable wide shots and
four unreachable/late controls. Before this pass, low and medium wide shots
miss on both sides. The high saves use a 23-degree lean. Medium poses already
roll the torso, but commitment prevents the physical lateral movement needed
to reach these shots; low wide shots select a crouching reach.

Priority gaps: lateral push-off, horizontal silhouette, height-specific glove
extension, a distinct side landing, and a staged brace/kneel/get-up rather than
simply reversing to idle. Add six original animation-only clips on the existing
shared rig. Preserve the near-body catches/low reaches and central overhead
tip; select full dives for wider intercepts. Godot owns the real trajectory
and independent ball. Keep a native close review and wider pitch context.

Appearance references remain John O'Rourke's archived keeper character/kit
sheets and Boardeaux's Feeney keeper kit, indexed in `references/README.md`.
Static sheets establish proportions and garment/glove presentation, not motion
timing. No PES motion is extracted. Apply create-player, Blender animation,
rigging and Godot export guidance through headless Blender/bpy.

## Acceptance

Real travelling-ball tests must show measured glove contact, sideways travel
during commitment, whole-body extension, natural landing, recovery gating and
standing-collider restoration. Preserve genuine unreachable/late misses and
the earlier central high tips, near saves, slow cross claims and handling
rules. Review complete native sequences rather than treating a contact still
as animation approval. Linux software Vulkan does not close M1 appearance or
1080p60 performance acceptance.

## Implemented and verified

Six original 60 Hz clips add low/mid/high extension in both directions. Authored
torso rolls are 80/75/60 degrees; clips have distinct side landing, brace,
kneel and rise poses over 1.8 s. The existing near-body and central overhead
actions remain. Wider intercepts select the full dive, while measured glove
height/span determine bounded CharacterBody take-off and lateral velocity.
The independent ball still needs the existing legal swept glove contact.
There are no rating/reaction/reach boosts or keeper/ball teleports in a save.

`keeper_full_dive_smoke.gd` now passes all twelve reachable bilateral low,
medium and high shots, plus four genuine unreachable/late misses. At these
contacts, committed sideways travel is approximately 0.81/0.95/1.10 m and
whole-body roll reaches 79.7/74.8/59.8 degrees. Both keepers land naturally,
finish recovery and restore their standing collider. `before.json` and
`after.json` record the transition from eight low/mid misses and leaning high
saves to the complete result. World-space measurement corrects for the GLB
skeleton's rotated local axes.

All seven selected smoke checks pass: full dives, the earlier 18 high-shot
cases, existing diving/high-cross behavior, live hand contact, handling/
recovery, catch/distribution and moving possession skills. See
`checks/regressions.log`. All six full matches pass the existing chance gate:
26/23 shots, contested attempts from both teams in every fixture and a
53.1%/46.9% shot share. The matches record 15/13 saves. This single cloud run
does not establish cross-machine or human match quality. Detailed metrics are
in `ai_chances/summary.json` and the final validation record.

The animation-only export contains six 0–1.8 s actions, 65 unchanged bone rest
transforms and no mesh. All 26 protected body/head/motion assets retain their
pre-pass hashes. Source: `tools/blender/beechlawn/author_keeper_dives.py` and
`football_keeper_dives.blend`; runtime add-on: `keeper_full_dives.glb`.

## Native review

[Six-save sequence](native/full_dives_review.mp4) and
[contact still](native/match_broadcast.png).

The actual 11v11 scene contains 22 players and the referee, with unrelated
actors parked for isolated real-ball reviews. Both keepers perform low,
medium and high dives in mirrored directions. All six physical save contacts
are recorded, with swept glove gaps of 0.086–0.226 m. Reviewed frames include
extension, turf landing, brace and return to ready stance. The camera stays
fixed during each sequence so sideways movement remains visible.

Godot 4.6.3 Forward+/Vulkan, Xvfb, llvmpipe software GPU, 640×360; 144 frames
sample real 60 Hz physics at 10 frames/s over 14.4 simulated seconds. These
controlled fixtures establish native motion/contact, not final AAA animation,
human match feel or M1 1080p60. Existing headless ObjectDB/resource shutdown
warnings remain. The current Mac download has not been rebuilt with this pass.

BR-009 remains in progress for distribution motion and native Mac match
acceptance. Next: BR-021 (21/27, in progress), stride/foot-plant polish and
moving-ball contact rechecks; BR-008 (8/27) retains match consistency acceptance.
