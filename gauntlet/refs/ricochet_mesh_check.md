# ricochet_mesh_check.md — inspecting his clips on his mesh

Working sheet for the one check `ricochet_moveset.md` leaves open: whether the
clips named there look right **on his mesh**, not just in the move data.

Not part of the submission patch. The submission is
`gauntlet/refs/ricochet_moveset.md`; this is the sheet you hold while looking.

## Why this is the check that matters

His rig is a 65-bone Mixamo skeleton retargeted onto the base rig, and the rig
report records a **+16.7% arm reach mismatch**. Every number in the moveset doc
(startup, recovery, active frames, head/torso damage) survives a bad retarget
untouched — the MoveDef does not know the hands are in the wrong place. So the
frame data cannot catch this class of bug and this sheet has to.

What a 16.7% reach error looks like in practice: on a grab, the attacker's hand
stops short of the target's head or goes through it. That is the single most
likely visible defect in this set, which is why the arm-led moves come first.

## Before looking

- Read `startup` and `recovery` out of the `.tres` for each clip. The FF library
  is 28–60 startup, 6 active frames, 34–40 recovery, but per-clip numbers are
  what the frames below are relative to, and guessing them wastes the pass.
- Set up so a frame is a frame: standalone or PIE at a fixed camera, gameplay
  at 60 Hz, and capture at 60 fps. A 30 fps capture of a 6-frame active window
  shows three frames of the contact.
- Note the `PlayerStart` and arena scale. `BP_ThirdPersonCharacter_C` was at
  Z=110 in the open level, the meshes are 400× scaled props — if he reads as a
  giant or a child against the ring, that is a scale finding, not a rig one.

## The pass, in order

Frames are written relative to the clip: **A1** is the first active frame (the
first frame after startup), **A6** the last one, **R1** the first recovery
frame, and **L** the last frame of the clip.

| # | Clip | Move | Frames | What to look at | Fail signature |
|---|---|---|---|---|---|
| 1 | `ff/sling_blade_3` | Hidden Blade | A1–A6, then R1–R5 | The striking elbow's arc against the head height of a standing target | Elbow passes above the head or swings wide of it; shoulder collapses into the chest at A1 |
| 2 | `ff/poison_rana_1` | Poisonrana | frames 1–10 of startup, A1–A6 | Where the hands close: both should meet the target's head, not hover in front of it | Hands visibly apart, or passing through the head; the grab reads as mime |
| 3 | `ff/avalanche_poison_rana` | Avalanche Poisonrana | startup to A1, A6 to R1 | Same grab, plus the height: hands must be at head height of a **seated** man, higher than #2 | Grab lands at standing height — the move reads as a standing rana played in the corner |
| 4 | `ff/slingshot_cutter` | Oscutter | the run/rebound frames, A1–A6 | The lead arm reaching back for the neck across the body | Arm crosses too far (over-reach) or stops short; the body then travels past a hand that isn't attached to anything |
| 5 | `ff/splash_630` | 630° Senton | whole startup (54 f), A1–A6, recovery (40 f) | Rotation count and air time. Two full rotations, landing before recovery starts | Lands a frame early so the second rotation completes on the mat; or hangs so long the 40-frame recovery reads as a freeze |
| 6 | `ff/kick_combo` | Kick combo | first 20 of 60 startup frames | Whether the startup winds up or stands still. 60 frames is the longest startup in the library | He waits in a neutral pose before the first kick — the sequence should be legible inside the startup, not after it |
| 7 | `ff/diving_shooting_star` | Shooting Star Press | frames 1–12, A1–A6 | Lower-back arch at the apex, arms tucked in on the rotation | Arch flattened by the retarget (the classic Mash/Stretch casualty); arms trailing behind the head |
| 8 | `dive_moonsault` | People's Moonsault stand-in | A1–A6 | As #7, one rotation | Same |

## Then the four things that are not per-move

1. **Foot sliding.** Root motion against capsule: in a running entry (kicks #6,
   slingshot #4) the feet should plant. Sliding means the retarget kept the
   source stride length against a differently-scaled body.
2. **Hand interpenetration at contact.** Look at A1–A3 only. Deeper than a
   couple of centimetres into the target's head or neck is a retarget offset,
   not a pose choice.
3. **Pops at the seams.** R-last into the next clip, and the loop point of any
   idle. A pop is a rotation offset the retarget did not carry over.
4. **Elbow and shoulder inversion.** Watch for the forearm rotating through the
   upper arm on the arm-led moves (#1–#4). This is the one that usually shows up
   as "smooth but wrong" and is easy to miss at 60 fps — scrub it.

## Recording what you find

For each row: clip, frames looked at, verdict (clean / reads wrong / broken),
and one sentence of what the frame showed. Anything that fails needs the frame
number, because a fix lands on the clip or the retarget and the frame number is
what says which.

## Two ways to get the frames

- **At the editor**, which needs no code: PIE or standalone in the open level,
  record the pass, scrub it. This is the fast path.
- **Through the bridge**, which needs the plugin to grow four commands — a
  skeletal-mesh and bone read-out, `play_montage` with a start time, a pose
  query at a given frame, and a screenshot returned inside the response. The
  command the bridge has today, `take_screenshot`, writes to the editor
  machine's disk and returns only the path, so nothing comes back to the other
  side of the tunnel. Sketches for those four are in
  `ricochet_plugin_commands.md`.
