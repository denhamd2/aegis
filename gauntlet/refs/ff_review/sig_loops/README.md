# Signature and finisher parity loops (Kenny, Cody, Roman)

## The ask (owner, 13 and 14 Nov)

> "Here is a reference video of all finishers and signature moves from AEW
> Fight Forever. I want you to run the same loop as above to get to 10/10, on
> Kenny, Cody and Roman's signatures and finishers. Judge each move against
> the criteria you used for the previous moveset."

> "Give me a handover for this loop work … I want it to run 5 loops."

Roman is not in Fight Forever. His Spears are judged against Ricky Starks's
Spear, the cleanest spear in the compilation.

## The reference

- **Video:** "AEW Fight Forever: All Finishers / Every Wrestler's Signatures
  & Finishers", 23:09, 1280×720 at 59.94 fps, 613 MB. It is the owner's file
  on Google Drive, id `1SYI-phi8Ci-WmbtxqtFEswarYHfhKGqc`, so it is not in the
  repo. Download it into its own folder:

  ```
  curl -sS -L -o sig.mp4 \
    "https://drive.usercontent.google.com/download?id=1SYI-phi8Ci-WmbtxqtFEswarYHfhKGqc&export=download&confirm=t"
  ```

- **Segments:** the video runs roughly alphabetically, with no name cards.
  - Cody: 6:13–6:43.
  - Kenny: 10:14–11:13.
  - Hobbs: 17:01–17:30.
  - Starks: 18:24–18:38.
- **Stills:** `ref_strips/` has 10 fps strips of every move, named with the
  absolute second they start at.

## What was scored, and where

The move list is `moves.txt`, one row per move:

```
name  MoveDef  ref-start  ref-impact  ref-end
```

All times are seconds into the video. There are 14 rows, covering the
following moves.

**Cody**
- Disaster Kick, 375.3 → 376.3: a run-up and a leaping horizontal kick to the
  head; both men crash down.
- Cross Rhodes, 380.4 → 384.95:
  1. a collar-and-elbow tie-up;
  2. a front facelock with the arms hooked, held about 100 frames;
  3. a vertical-suplex lift until the man is upside-down, held;
  4. a sit-out spike.
- Figure-four, 388 → 395: grab the legs, step over, spin, sit back and hold.

**Kenny**
- V-Trigger, 615.0 → 615.8: a run-in knee to a standing man, who stays on his
  feet.
- Snap Dragon suplex 2, 619.8 → 622.3: a long full nelson, then a snap
  release backwards. Kenny stays on his feet; no bridge.
- Snap Dragon suplex 3, 625.8 → 627.9: the same move from another camera.
- Running V-Trigger 3, 630.5 → 632.35: a sprint across the ring into a man
  kneeling in the corner.
- Running V-Trigger 1, 658.4 → 659.45: off the ropes, a leaping knee to the
  face.
- One-Winged Angel, 636.8 → 640.85: a clinch, a fireman's-carry lift, a hold
  and turn of about 110 frames, then a drop onto the head.
- Powerbomb/V-Trigger combo, 644.8 → 648.1 for the bomb, 649.7 for the knee:
  the bomb, the man sits up, and Kenny runs in with the knee.

**Roman** (all four judged against Starks's Spear, 1104.4 → 1105.5)
- Spear: run-up, a hands-up gesture, a near-horizontal dive with the shoulder
  into the midsection, and both men down, Roman on top.
- Running Spear.
- Superman Punch into Spear.
- Corner Spear.

## How to run a loop

1. **Fix.** Edit the move's authored clip pair in
   `game/tools/blender/wrestling_clips.py` (`FF_*_Attacker` and
   `FF_*_Defender`, `Cody_Cutter_*`, `CR_*` and so on). Edit its trajectory in
   `game/resources/animations/paired_recipes.gd`, and its timings in
   `resources/moves/**/<move>.tres`.
   - Clips are authored at 30 fps and exported at 60.
   - `game/tools/blender/wrestling_clips.py`'s `_back_fall`, `_flip`,
     `_yawed`, `_body`, `pose()` and `P()` are the building blocks.
   - See `Arm_Hook_*` (move 7, six loops from 3.5 to 7.0) for a recent
     example.
2. **Bake.** Run these under one lock, in order:
   1. `python3 game/tools/blender/wrestling_clips.py`, with Blender's bpy;
   2. `godot --headless --path game --import`;
   3. `-s res://tools/anim/build_paired_moves.gd`;
   4. `-s res://tools/anim/build_paired_poses.gd`;
   5. `build_paired_moves` again;
   6. `FIT_ONLY=<move ids> godot --headless --path game tools/anim/fit_paired.tscn`,
      twice, each pass followed by `--import` and `build_paired_moves`;
   7. `build_strike_clips`.

   Then re-pin the sha of `wrestling_clips.py` in
   `game/tests/test_clip_authoring_gate.gd`.
3. **Render.** `GODOT=… VIDEO=…/sig.mp4 OUT=… sig_loop.sh <loop> [names]`
   writes `sheet_<name>.jpg`: the reference strip on top, ours underneath.
4. **Review.** Use a reviewer subagent per wrestler, read-only, with
   `reviewer_brief.md`.
   - It scores Speed, Cadence, Smooth, Like-for-like and Sell out of 10, and
     the overall is their mean.
   - It gets at most 5 numbered fixes per move.
   - Give it the previous loop's score and feedback, and what changed.
5. **Gate.** Run `test_pair_clearance`, `test_paired_poses`,
   `test_paired_moveset`, `test_sixty_fps`, `test_clip_cadence`,
   `test_pose_lint` and `test_clip_authoring_gate`.
   - Expect no new failures against main.
   - At 15 Nov, main's known failures in this set were the Cross Rhodes grip
     (0.094 m) and `running_grapple_inverted_drop`, which has since improved
     on main.
6. **Deploy.** Deploy each wrestler's batch when it has finished its loops,
   with a README entry quoting the owner.

**Run five loops per move,** or stop early at 10. Record every score in
`scores.md`.

## Fix the harness before loop 2

Three of loop 1's low scores are the render tool's fault, not the move's:

- **Running moves have no run-in.** `paired_shot` places the pair at the
  clip's start gap. Add a `--run-in` option that starts the attacker about
  3.5 m back and runs him in, as `strike_pair_shot.gd`'s run-up does.
- **The figure-four is staged standing.** The defender must start supine,
  with Cody at his feet.
- **The Corner Spear had no corner.** Use `paired_shot --corner`.

Also, the sheets space 10 frames evenly over our move and over the
reference's window. Place the contact column at our real impact frame; the
reviewers judged timing from the frames because the labels were misleading.

## Loop 1 (13 Nov): scores and the reviewers' fixes

| Move | S | C | Sm | L | Sell | Overall |
|---|---|---|---|---|---|---|
| Cody Disaster Kick | 4 | 3 | 4 | 2 | 4 | 3.4 |
| Cody Cross Rhodes | 1 | 1 | 3 | 1 | 2 | 1.6 |
| Cody Figure-four | 1 | 1 | 4 | 0 | 0 | 1.2 (harness) |
| Kenny V-Trigger | 4 | 3 | 5 | 3 | 2 | 3.4 |
| Kenny Snap Dragon 2 | 2 | 2 | 4 | 3 | 5 | 3.2 |
| Kenny Snap Dragon 3 | 2 | 2 | 4 | 2 | 5 | 3.0 |
| Kenny Running V-Trigger 3 | 2 | 1 | 5 | 1 | 2 | 2.2 |
| Kenny Running V-Trigger 1 | 4 | 2 | 5 | 2 | 2 | 3.0 |
| Kenny One-Winged Angel | 2 | 3 | 5 | 6 | 5 | 4.2 |
| Kenny Powerbomb/V-Trigger | 2 | 2 | 3 | 3 | 2 | 2.4 |
| Roman Spear | 3 | 3 | 4 | 3 | 4 | 3.4 |
| Roman Running Spear | 2 | 2 | 2 | 3 | 2 | 2.2 (harness) |
| Roman Superman Spear | 2 | 3 | 2 | 3 | 2 | 2.4 |
| Roman Corner Spear | 2 | 2 | 2 | 2 | 2 | 2.0 (harness) |

The sheets are in `loop1/`. Biggest gap per move:

**Cody**
- **Disaster Kick:** ours is a standing kick from close range.
  - Start about 2.5–3 m out: two strides, a tuck skip, then a near-horizontal
    leap at 1.3–1.5 m, legs first, foot to the head.
  - Both men go down: Cody onto his side or back by contact +24, and stays
    down.
  - Lengthen to about 120 frames.
- **Cross Rhodes:** the branch's rolling-cutter re-key is the wrong move.
  - Rebuild it as the video shows:
    1. a square tie-up of about 66 frames;
    2. a front facelock with the head under Cody's arm and arms hooked, about
       100 frames;
    3. the lift to fully inverted in about 18 frames;
    4. hold inverted for about 66 frames;
    5. drop to a sit-out in about 9 frames, the head driven between Cody's
       thighs.
  - About 273 frames to impact.
  - Main still has the older Tiger Driver-flip version. The re-key stays off
    main until this is right.
- **Figure-four:** with the harness fixed to start the defender lying down:
  1. a leg grab of about 60 frames;
  2. a step-over and spin of about 90 frames;
  3. sit back about 30° with the shins locked, held about 210 frames;
  4. the defender propped on his elbows, slapping the mat.

  About 420 frames in all.

**Kenny**
- **All three V-Triggers are one shared clip.** They should be three moves:
  - **V-Trigger:** a run-in of about 36 frames, a knee at face height with
    both feet off the mat, and the man reels and stays standing.
  - **Running V-Trigger 3:** the defender kneels in the corner; Kenny sprints
    about 55 frames, and the man slumps into the corner.
  - **Running V-Trigger 1:** off the ropes, a leaping knee at about 1.6 m;
    the man doubles over and stays standing.
- **Snap Dragons:**
  - Hold the full nelson about 90 frames from behind.
  - No bridge: Kenny stays on his feet, or drops to one knee at most.
  - A fast release of about 18 frames; the man lands on his upper back and
    neck, then rolls to his side.
  - In Snap Dragon 3 the man is lifted horizontal. Keep him on his feet.
- **One-Winged Angel:** lengthen to about 243 frames to impact.
  - A clinch and lift of about 60 frames.
  - Hold on the shoulders and turn for about 110 frames.
  - Drop for about 25 frames, his head reaching the mat as Kenny's hips do.
- **Powerbomb/V-Trigger:**
  - Hoist for about 180 frames, held at the top about 20.
  - Bomb at about frame 198.
  - The man sits up; Kenny backs off about 2 m and runs in with a knee to
    the seated man's head.
  - About 312 frames total.

**Roman (every Spear)**
- Roman drives into the legs and carries on through, landing beyond the man.
  It should be:
  - a run of about 3.5 m;
  - a hands-up gesture about 15 frames before contact;
  - a dive at contact −5 frames, near horizontal, shoulder to the navel;
  - the man folds backward, and both go down together in about 18 frames,
    Roman landing on top across his waist, kneeling to about +40.
- The defender floats about 0.3 m in several frames. Ground him.
- The Corner Spear should crush an upright man into the buckles, not floor
  him.
