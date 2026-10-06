# Roman's entrance vs WWE 2K26: review and improvement plan

Owner note: the ramp walk is too dark, and the animation feels janky, "almost like stop
motion". Compared against the WWE 2K26 Roman entrance in `raw/video/cody_roman_2k26.mp4`
(145-295 s, contact sheet every 3 s) and our own capture (`tools/probe/entrance_shots`
from `pyro_stage`, every 45 frames, Vulkan, 1280x720).

## What 2K26 does

**Lighting.** The arena is dark, but Roman is always well exposed. A bright, soft key from
the front and above lights his face and chest on every walking shot. The huge cyan/blue
TC screen behind him acts as a rim and backdrop. LED blinder boxes line both ramp edges.
At ringside, warm light picks out him and the front row. He is never a silhouette, and
never a small dark figure in a wide shot.

**Camera.** Long, slow holds of about 6-9 s. The core shot is waist-up, walking toward a
lens that tracks backward ahead of him, with the bright screen filling the background
(176-206 s). It cuts to a telephoto head-and-shoulders close-up, then over-the-shoulder at
ringside, then a low hero shot in the ring. The very wide shot appears only once, and it's
lit.

**Animation.** Mocap: a heavy, deliberate stride. The hips rise and fall and sway side to
side, the shoulders counter-rotate, and the arms hang slightly out with a small, lagging
swing. Head turns are slow, with long holds. Weight transfer is continuous, never
start-stop.

## What ours does (measured)

**Lighting.**
- The side-high and arena-high shots (frames 1260-1350 and 1800-1845) show him as a tiny,
  near-black figure on an unlit ramp.
- The side shots (1890-1980) light only his front-right; his far side and back fall off
  to black.
- The close-ups are flat and low-contrast.
- The average frame brightness matches 2K26 (69 vs 69). The difference is where the light
  lands: 2K26 puts it on him, ours puts it on the set.

**Camera.**
- `ROMAN_WALK_SHOTS` includes `ramp_side_high` and `arena_high`, which frame him tiny and
  dark.
- The name card stays up for 10+ s over the walk.
- There's no waist-up shot walking to the lens with the wall behind him, which is 2K26's
  signature shot.

**Animation: the jank has two causes.**

1. **Engine: stop-motion stutter.** These all run at 60 Hz in physics:
   - the AnimationTree (`ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS`, wrestler_controller.gd);
   - the director's root motion (`_physics_process`);
   - the camera.

   Physics interpolation is off and `physics_jitter_fix=0`. On a 120 Hz Mac display, or
   whenever frame times vary, each pose is held for an uneven number of frames, which
   reads as stop motion.
2. **Clip: a robotic gait.** `Walk_Slow_Look` (procedural `_gait`, 0.5 m/s, 48-frame cycle):
   - pelvis bob is 0.8 cm (a real slow walk is about 3-4 cm), with no side sway;
   - hip yaw is 3° and spine counter-twist 5°;
   - the hands barely move (7 cm);
   - double support is 58% of the cycle, so the body almost stops between steps;
   - foot swings start and stop abruptly (thigh velocity jumps 6°/frame in one frame);
   - at the loop seam the head snaps 28° back to centre in 6 frames, every 4.8 s.

## Plan, in order of impact

### 1. Smooth motion (engine) — fixes "stop motion" on every platform
- Turn on `physics/common/physics_interpolation`, so the root and camera move smoothly
  between ticks. Check the camera's `reset_physics_interpolation()` on cuts.
- Evaluate animations at render rate, not physics rate, during entrances and post-match.
  The match keeps physics rate for determinism.
- Gate: a 120 Hz probe capture measuring the variance of per-frame displacement on his
  hand and head. Target: no repeated-pose frames.

### 2. Re-author Roman's walk (`_methodical_walk`)
- Heavier, more continuous gait at about 0.6 m/s:
  - pelvis bob 3 cm, side sway 2.5 cm;
  - hip yaw 7°, shoulder counter-rotation 9°;
  - double support down to about 35%;
  - eased foot lift and plant;
  - arms slightly out (lats), with a 10-12 cm swing lagging the shoulders by about
    4 frames.
- Head: slow eased looks with long holds, and a loop seam that returns to centre over
  20+ frames. Use two or three cycle variants so the repeat isn't readable.
- Gate: a walk-jerk test (maximum per-frame angular acceleration per bone), plus a foot
  slide check against the director's 0.6 m/s.

### 3. Light him like 2K26
- A camera-relative key: a soft front key that rides the active shot (about 30° off axis,
  above eye line), so he's exposed on every angle. Raise the walk key and back light, and
  widen their cones so his side and back never go black.
- LED blinder boxes along both ramp edges and a ramp floor wash, so the wide shots read.
- Stronger rim from the wall's colour while it's behind him. Slightly less house dim on
  the ramp (0.5 → 0.65).
- Face: more key contrast and a specular lift on the skin, so the close-ups aren't flat.
- Gate: masked luminance on his body in each walk shot of at least about 80% of the 2K26
  equivalent beat.

### 4. 2K26 camera grammar
- Replace `ramp_side_high` and `arena_high` in `ROMAN_WALK_SHOTS` with:
  - a waist-up backward track, wall behind (7 s);
  - a telephoto face close-up (5 s);
  - a 3/4 low track (6 s);
  - over-the-shoulder at ringside;
  - one lit high wide only.
- Hold 6-9 s and ease every move.
- Name card: shorter (about 4 s) and set clear of his body.

### 5. Verify and ship
- Side-by-side contact sheet against the 2K26 beats, the motion gate, the lighting gate,
  the full suite, then the Mac build for the owner's eyes.

## Model guidance for executing this
- Sonnet for steps 1, 3, 4 and 5 (wiring, tuning, renders, tests).
- Opus for step 2, the walk re-authoring.
