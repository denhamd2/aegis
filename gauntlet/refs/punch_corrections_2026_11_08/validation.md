# Punch corrections, batch 13a (8 November 2026)

Source-only change to `game/tools/blender/wrestling_clips.py`. The baked
`assets/animations/wrestling_clips.glb` and `resources/animations/strike_clips.tres`
have **not** been regenerated: this workspace has no Blender/bpy and no Godot
binary (verified: `import bpy` fails, no `godot4`/`blender` on PATH).

## What changed

Five punch-family clips were re-keyed to the combat-timing reference
(anticipation 4–8 frames, action 2–4 and always shortest, follow-through
4–8, recovery 8–16), with the head counter-turned so the eyes stay on the
man at contact.

| Clip | Length / contact frame | Phases now |
| --- | --- | --- |
| `Strike_Jab` | 18 f, contact 6 (tick 10 of 30) | anticipation 4, action 2, follow-through 4, recovery 8 |
| `Strike_Forearm` | 20 f, contact 6 (tick 12) | anticipation 4, action 2, follow-through 5, recovery 9 |
| `Strike_Gut_Punch` | 22 f, contact 7 (tick 14) | anticipation 5, action 2, follow-through 6, recovery 9 |
| `Strike_Bionic_Elbow` | 27 f, contact 15 (tick 30) | shimmy anticipation 12, action 3, follow-through 4, recovery 8 |
| `Strike_Dropdown_Uppercut` | 24 f, contact 11 (tick 22) | drop anticipation 9, rise/action 2, follow-through 4, recovery 9 |

Supporting changes:

- **Jab** retimes 18 authored frames to 0.500 s (30 ticks) and
  `strike_jab.tres` gives one recovery tick back (17 → 16). Contact remains
  tick 10.
- **Cross** keeps the lead hand on the opponent's shoulder through impact
  (0.54 m forward at contact, 0.50 at the first follow-through, 0.46 at the
  late one) instead of retracting it.
- **Gut punch** drives the fist up 0.16 m between load and contact, landing
  under the ribs at 1.14 m; `strike_gut_punch.tres` offset moves with it.
- **Bionic elbow** is now an actual elbow strike: the forearm folds and the
  **elbow** leads at head height (fwd 0.59 m, up 1.50 m) with the hand tucked
  at 0.35 m/1.45 m. It starts and ends on READY, like every other strike.
  `measure_contact_offsets.gd` now includes `lowerarm_l/r` in its candidate
  tips, so the tool measures the elbow for an elbow-led clip and still picks
  the hand/foot for every other strike (verified below). The MoveDef offset is
  the measured elbow point (0.213, 1.497, -0.594). Reach becomes 1.068 m,
  above `min_standoff` (1.05) but 3 cm inside `circle_distance` (1.10), so
  Cody’s AI closes 3 cm more to land it.
- **Dropdown uppercut** no longer leans back at contact (spine pitch 0, was
  +8), holds the head on target, and moves its follow-through key to frame 15.
- `test_clip_authoring_gate.gd` re-pinned to the new `wrestling_clips.py`
  digest.

## Verification performed here

A bpy-free implementation of the rig solver (`rig_pose.py`'s armature-space
targets, clavicle follow and two-bone IK) was built against the rest joints in
`wrestler_base.glb`. It reproduces `RIG_FACTS` and the existing measured
contact offsets, which is what makes its numbers usable:

```
pelvis height 0.9167, shoulder 1.4408, ankle 0.1037 (err < 0.001 m)
upperarm 0.2744, lowerarm 0.2726, thigh 0.4003, calf 0.4295
cross / gut / dropdown contact offsets reproduce the shipped .tres values
```

Audit of all five clips (`RESULT: ALL CRITERIA PASS`):

```
contact geometry  jab 0.040/0.660/1.460 (err 0.023), cross exact,
                  gut exact, bionic elbow exact, uppercut exact
eyes on target    -6.3 / +8.3 / +8.6 / +7.9 / 0.0 degrees at contact
phases            4+2+4+8, 4+2+5+9, 5+2+6+9, 12+3+4+8, 9+2+4+9
cross lead hand   0.54 / 0.50 / 0.46 m forward at f6/f8/f11
gut punch rise    0.160 m between load and contact
bionic elbow      elbow up 1.497 m, elbow leads hand by 0.244 m forward
uppercut          spine pitch 0 deg, hand up 1.600 m
pose lint         neck bend 13-15 deg (max 75), hand-to-torso >= 0.69 m
mat clearance     lowest ankle 0.104 m on every key
readability       striking limb travels 0.43-0.67 m; other hand 0.13-0.36 m
strike speed      jab 10.7, cross 13.0, gut 11.0, elbow 5.5, uppercut 8.0 m/s
tip selection     hand_l / hand_r / hand_r / lowerarm_r / hand_r
                  (only the bionic flips to the elbow)
```

Also performed: `python3 -m py_compile` and an AST check of the five clips
(strictly increasing frames, valid pose keys, contact frames present), and the
authoring-gate digest was matched against the file.

The `blender-specialist` review was attempted twice and could not run: the
pinned free model reported "Free usage limit reached". It was not rerouted to
another model.

## Required on the Mac (not run here)

1. `python3 game/tools/blender/wrestling_clips.py` (bpy) — regenerate
   `assets/animations/wrestling_clips.glb`.
2. `godot4 --headless --path game --import`.
3. `godot4 --headless -s res://tools/anim/build_strike_clips.gd`.
4. `godot4 --headless -s res://tools/anim/measure_contact_offsets.gd` — expect
   the bionic elbow offset above and the other strikes unchanged; paste if a
   value differs by more than a centimetre.
5. Focused gates: `test_clip_authoring_gate`, `test_authored_clips`,
   `test_clip_cadence`, `test_clip_readability`, `test_strike_clips`,
   `test_strike_contact_volume`, `test_pose_lint`, `test_ai_spacing`.
6. Render `tools/probe/clip_shot.tscn` for the five clips and review both
   bodies and the contact frames at match distance and close range.

Pixel-level confirmation remains the only step that can move this from the
measured score below to a final art score.
