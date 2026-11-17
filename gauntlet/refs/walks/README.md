# Walks: Roman, Cody and Kenny

The owner, 16 Nov: "create a walk test for Roman, Cody and Kenny. Especially
for their walks to the ring, but also during gameplay. They should look natural
with their leg, body and arm movements during a walk, not robotic."

- `game/tools/anim/walk_metrics.gd` measures a baked walk and holds the gates.
- `game/tests/test_walks_look_natural.gd` is the test. Its `KNOWN_FAILS`
  ledger is exact both ways.
- `game/tools/probe/walk_quality.gd` prints every number (`metrics.txt` in each
  folder).
- `game/tools/anim/walk_sheets.sh` renders the contact sheets: one gait cycle
  at 8 even steps, side view above, front view below.

| Sheet | Walk | Speed |
|---|---|---|
| `roman_Walk_Slow_Look` | Roman's walk to the ring | 0.5 m/s |
| `cody_Walk_Crowd` | Cody's walk to the ring | 1.2 m/s |
| `kenny_Kenny_Walk` | Kenny's walk to the ring | 1.1 m/s |
| `roman_Entrance_Walk` | generic entrance and face-off walk-in (all three) | 1.6 m/s |
| `*_Walk_Stalk` | gameplay walk (all three, one clip) | 3.5 m/s |
| `roman_Run_Jog` | gameplay jog outside the ring | 4.2 m/s |
| `roman_Run_Drive` | gameplay run | 7.0 m/s |

## Before (main 12cd89f1): independent reviewer's scores /10

| Walk | Score | Main problem |
|---|---|---|
| Roman Walk_Slow_Look | 4 | paces; pelvis and chest turned the wrong way |
| Cody Walk_Crowd | 4 | paces; mincing 0.52 m steps at 138/min |
| Kenny Kenny_Walk | 5 | paces; the loosest torso |
| Entrance_Walk | 3 | a skipping jog: no double support, 10% flight; dead pelvis; sole slides (0.84x) |
| Walk_Stalk | 2 | high-knee running legs at 225 steps/min, frozen 'zombie' arms, 0.80x skate |
| Run_Jog | 4 | arms in phase with the legs; rigid spine; no sway |
| Run_Drive | 3 | arms in phase with the legs; 0.75x skate; forearm crosses the chest |

All seven paced: the hands swung with the leg on their own side. The pelvis
and the shoulders also turned the wrong way against the stride: a sign error
in `_heavy_gait` and `_gait` (`wrestling_clips.py`). Full review:
`before/review.md`.

## After (17 Nov, part 2)

All seven walks pass every gate. The `KNOWN_FAILS` ledger is empty; the
numbers are in `after/metrics.txt` and the sheets in `after/`. The
independent after-scores are pending.
