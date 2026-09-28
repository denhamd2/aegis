# The animation gap: what makes 2K26's animation and match play work, and our plan

## Context

David has hit the same kinds of animation defect again and again:
- a tie-up that played as two backbends;
- a knee to the gut where the victim leaned away from the knee;
- limbs overlapping other bodies;
- wrestlers gripping thin air 2 m apart.

He asked for deep research into what makes WWE 2K26's animation and two-man
moves smooth and natural, and for recommendations, feasible with our tooling,
to reach that standard.

Our tooling is:
- Godot 4.6 with SkeletonIK3D, SkeletonModifier3D and AnimationTree;
- headless bpy 4.2 with pose tables in `wrestling_clips.py` and the IK in
  `rig_pose.py`;
- GDScript probes and tests;
- no motion capture.

## What 2K26 does (research)

**Real performers, both halves captured together.**
- Every move is performed by pro wrestlers and stunt performers (Micah and
  Tracy Taylor, indie talent) in 2K's Petaluma studio, then cleaned up by
  hand.
- Both men are captured at once, so where they touch is right by
  construction.
- Moves are re-shot until they feel right. The shopping-cart feature was
  "slow and clunky", so they went back to mocap.

**Moves depend on position and size.**
- Different moves play depending on where the attacker is relative to the
  opponent: head, arms, legs, corner, ropes.
- Height, weight and strength differences each need handling.
- The series chose "a middle ground" between warping bodies into place (the
  old teleporting) and ignoring alignment.
- Weight classes limit which moves can be done to whom.

**Flow between actions.**
- 2K26 adds "more natural reactions and animations in-between actions".
- Chain wrestling and "seamless" reversals are driven by stamina.
- Players can steer holds with light inputs ("immersive control") instead of
  watching a canned clip.

**Impact feel.**
- Better depth of field, less camera dead zone, camera shake on impacts, and
  full-screen effects.

**Industry technique behind this class of result.**
- Root motion shared between the pair, with sync points.
- Motion warping, which bends root motion so the two land exactly aligned.
- Contact-aware IK.
- Motion matching and inertialized blending for transitions.

## What our audit found

The problems David sees trace back to five gaps.

1. **Poses are authored blind.**
   - About 15 documented bugs of the same kind: pitch sign backwards, mirrored
     bones, a twist the wrong way (`wrestling_clips.py:15, 521, 684, 1131,
     2142, 2221, 2433`; `rig_pose.py:99`).
   - Every one was found by a human looking at a frame. No gate checks what a
     pose *means*.
2. **Paired moves carry no contact data and do no size fitting.**
   - Trajectories are fixed metres, with the pair at ±0.40 m.
   - Hands reach the other man only through a generic grip IK (chest or hips).
   - `test_paired_poses.gd` checks structure but never contact or overlap.
3. **Nothing stops bodies passing through each other.**
   - Each body is a single capsule, and physics is suspended during a paired
     move.
   - Overlap is only detected by probes (`limb_clearance.gd`, `move_qa.gd`).
4. **Transitions are crude.**
   - Every state is connected to every other, with one 0.1 s crossfade.
   - No transition clips, no foot IK, and no additive hit reactions.
5. **Volume.**
   - About 138 authored clips and 37 paired moves, against 2K's thousands of
     mocap moves.
   - We cannot mocap, so each move has to be right by construction instead.

## Recommendations, in order of payoff

### Phase 0: finish what is in flight (this session)

- **Cody's eyes.**
  - `tools/assets/rig_cody_eyes.py` adds Eye_L/Eye_R, and
    `CodyModel.aim_eyes` hooks them up. Measured with the tracking on: 0°
    off target, against 24–27° staring ahead.
  - Still to do: run the full suite, add a test, then commit and push.
- **Roman blink.**
  - Procedural upper eyelids: a skin-toned spherical cap, 1.08× the eyeball
    radius, measured off the eye mesh at load.
  - Hung on the head bone, not the eye bone, so the lids do not roll with the
    gaze.
  - Rotates down to close: 60 ms to close, 90 ms to open, every 2–6 s from a
    seeded RNG. Presentation only.
  - Verify on the `broadcast_shot` close-ups.
- **AgX.**
  - Make the capture harness render its mask frame with a linear tonemap, so
    the measurement is valid under AgX.
  - Switch `match.tscn` to AgX and re-solve with `tonemap_exposure`, sweeping
    it until the mat is 0.43–0.49.
  - Re-measure every band, then update `VISUAL_BAR.md` and `aaa_gap.md`.

### Phase 1: stop shipping bad poses (automated gates) -- DONE

Built as `PoseLint` (13 defects found and fixed) and `PairClearance`. The
pair check found 32 of 37 moves with bodies inside each other by up to 26 cm.
These are held by a ratchet (`PairClearanceBaseline`), the queue for Phase 2.

This matters most, because it catches the whole class of bug David keeps
finding.

1. **Pose lint in the bake.** A new file, `tools/anim/pose_lint.gd`, run by a
   test. It samples every clip frame through FK on the base rig and checks:
   - Lean direction against intent. Each clip entry gets a tag,
     `intent={"lean": "forward"|"back"|"upright"}`, in `wrestling_clips.py`.
     This catches the sign bugs.
   - Joint limits: no elbow or knee hyperextension, head pitch and yaw within
     human range, and no spine twist past about 45°.
   - Feet: no foot below the mat, and no planted foot sliding (reuse
     `gait_audit.gd`).
   - Self-intersection: a hand or forearm inside its own torso capsule.
   - Silent reach clamps: `_two_bone_ik` targets past 0.995 of reach are
     reported (reuse `reach_audit.py`).
2. **Pair lint.** Extend `test_paired_poses.gd`, reusing the capsule-limb
   model from `tools/probe/limb_clearance.gd`:
   - Sample both halves of every paired move and fail on overlap past 3 cm
     between one body's limbs and the other's torso or head.
   - Check declared contacts (see Phase 2): the hand is within 5 cm of its
     target bone during each contact window.
3. **Auto contact sheets.**
   - Any change to `wrestling_clips.py` or `paired_recipes.gd` renders side
     and front sheets through `clip_shot` / `paired_shot` into the scratchpad.
   - The clip gate (`test_clip_authoring_gate.gd`) message points at them. A
     human still looks, but the frames are already there.

### Phase 2: two-man moves that fit (2K's "natural together") -- IN PROGRESS

Done so far:
- Runtime separation (`PairSeparator`), which solves overlap each tick after
  the animation.
- A measured trajectory fit (`PairedFit`), with keys inserted where it peaks
  mid-air.
- Contact data and contact IK: `PairedContacts` says what each move holds
  (neck, waist, legs, facelock, wrist, or nothing for a strike), the grip IK
  aims there, and `GrappleRig._pull_into_reach` draws the defender up to
  25 cm into reach, undone if it would put him inside the attacker.

Paired moves within the overlap limits went from 5/37 to 36/37. Hands on
their hold: 14 of 21 holding moves within 5 cm (median), strikes hands-free;
the 7 that turn or roll through the hold are on a ratchet
(`PairClearanceBaseline.GRIP`). Refitting `PairedFit` with the pull included
was tried and rejected: it doubled the in-reach frames but drove grip arms
through bodies (30/37). Still to do:
- the walk-in lead-in;
- a check with Roman, Cody and Kenny's real sizes.

1. **Contact-first paired authoring**, standing in for capturing both men
   together:
   - A new `tools/blender/paired_clips.py` poses both skeletons in one shared
     Blender scene per move.
   - The defender is solved first. The attacker's hands and feet are then
     targets *relative to the defender's bones*. For example, the knee targets
     the defender's `spine_02` on frame 18, and `hand_r` targets his
     `neck_01`.
   - Contact is right by construction. Each move exports the pose pair plus a
     contact track: bone, target bone, and frame window.
   - Migrate the 37 recipes in order of how often they are seen: tie-up,
     grapple holds, suplex, slam, Cody's moves.
2. **Runtime contact IK.**
   - Generalise `_aim_grip_targets` / `_aim_collar_and_elbow` in
     `wrestler_controller.gd` into a data-driven `ContactIK` that reads each
     move's contact track.
   - Keep SkeletonIK3D per limb, which is documented as working where
     TwoBoneIK3D did not.
   - Add leg chains for knees, stomps and foot plants.
3. **Size fitting (motion warping).**
   - In `grapple_rig.gd`, scale the pair offset and the trajectory's
     horizontal keys by the two men's measured statures (`Roster` values
     `stature_m`, `physique_height`).
   - Warp the root during the lead-in, so a taller man's lift and a shorter
     man's reach still meet at the contact bones.
   - The contact IK removes the remaining error.
   - Add weight classes to gate moves: `MoveDef.weight_class_min/max`
     already exist; enforce them.
4. **Walk-in instead of slide-in.**
   - Replace `_lead_in`'s 10-tick lerp with a short root-warped setup step:
     the attacker steps into position, and the defender is pulled by the grip.
   - Use a per-family setup clip (front grapple, rear, corner, downed) so each
     move starts from a matching grip.

### Phase 3: smooth flow between actions

1. **Transitions.**
   - Replace the all-to-all 0.1 s crossfade with tuned per-edge fades plus
     curves (`AnimationNodeStateMachineTransition.xfade_curve`).
   - Add transition clips for the most-seen edges: hit → stagger → recover,
     and getup variants.
   - Implement inertialization as a SkeletonModifier3D that decays the pose
     offset captured at the switch. This is the modern standard, and it
     removes blend "mush" and pops.
2. **Foot IK.** A SkeletonModifier3D that plants feet on the mat when the
   clip marks contact, to remove the slide and float that retargeting and
   stature scaling introduce.
3. **Hit reactions.**
   - Directional and height-aware variants: head, body, legs; front, back and
     side.
   - An additive flinch layer (AnimationNodeAdd2) so small hits play over
     movement without interrupting it.
   - Hit-stop of 2–3 frames on impact, plus the existing camera shake cue.
4. **In-between life.** Head and neck look-at toward the opponent (extend
   `EyeAim` to neck and head with limits), idle variations, an additive
   breathing and fatigue slump driven by stamina, and selling between moves.

### Phase 4: 2K26 match-play systems (gameplay)

- **Position-context moves:** front, rear, at the head or legs of a downed
  man, corner, ropes. The move chooses its pair offset, and it only plays
  when the geometry fits.
- **Reversals brought back as paired counters:**
  - Each authored under the Phase 2 pipeline.
  - Windows linked to stamina, as in 2K26.
- **Chain-wrestling input inside holds:** d-pad steering of a hold, like
  2K's "immersive control", instead of a canned clip.
- **AI "in-between" behaviour:** pacing, selling, and playing to the crowd
  (`CrowdReaction` already exists).

### Honest limits

- **No mocap here.** Phase 2's contact-first authoring is the substitute.
- **Volume.** We will not match 2K's thousands of moves. Quality per move is
  achievable.
- **Optional data source.** The CMU motion-capture database is free to use and
  has some two-person clips. It could feed locomotion and reactions through
  bpy retargeting, but this needs network access and a licence and credits
  check first.

## Critical files

- **Authoring:** `game/tools/blender/wrestling_clips.py`, `rig_pose.py`, and
  the new `paired_clips.py`.
- **Paired runtime:** `game/core/grapple/grapple_rig.gd` and
  `resources/animations/paired_recipes.gd`.
- **Controller:** `game/core/match/wrestler_controller.gd` (grip IK,
  `_build_animation_tree`, `ANIMATION_BLEND_TICKS`).
- **Gates:** `tests/test_paired_poses.gd`, `test_clip_authoring_gate.gd`, and
  the new `tools/anim/pose_lint.gd`.
- **Reuse:**
  - `tools/probe/limb_clearance.gd` (capsule limbs);
  - `tools/anim/gait_audit.gd`;
  - `tools/blender/reach_audit.py`;
  - `tools/probe/clip_shot.tscn`, `paired_shot.tscn`, `pose_probe.tscn`;
  - `EyeAim` and `RomanHeadShape` as the SkeletonModifier3D pattern.

## Verification

- **Each phase:**
  - Full gdUnit suite green.
  - The new lint tests fail on a deliberately flipped pitch or overlapping
    limb before the fix, and pass after.
  - Side and front contact sheets checked for every changed clip.
  - A live-match probe (`pose_probe.tscn`) of the tie-up, a grapple and a hit.
- **Phase 2:** contact error at each contact frame under 5 cm for Roman vs
  Cody, and for a mismatched pair (Kenny).
- **Phase 3:** `gait_audit` foot-skate numbers improve. No pose pops larger
  than 5 cm per tick at state switches, measured by `move_qa.gd`.
- **End to end:** a recorded match video sent to David for review.
- Commit and push to `claude/whats-next-2goay1` at the end of each phase.

## Sources

- [2K26 Ringside Report: gameplay](https://wwe.2k.com/2k26/ringside-report/gameplay/)
- [GamingBolt: 15 new features](https://gamingbolt.com/wwe-2k26-15-new-features-worth-knowing)
- [Bleacher Report review](https://bleacherreport.com/articles/25403138-wwe-2k26-review-gameplay-impressions-videos-and-top-features)
- [Slam Wrestling: behind the scenes of 2K26 (mocap iteration)](https://slamwrestling.net/interviews/made-by-fans-for-fans-behind-the-scenes-of-wwe-2k26/)
- [Backstage: WWE wrestlers on mocap](https://www.backstage.com/magazine/article/wwe-wrestlers-video-game-motion-capture-7903/)
- [Motherboard: how 2K17 fixed animation awkwardness](http://motherboard.vice.com/read/wwe-2k-17-improved-animation-system)
- [Unreal: Motion Warping](https://dev.epicgames.com/documentation/en-us/unreal-engine/motion-warping-in-unreal-engine)
- [GDC: Motion Matching and the Road to Next-Gen Animation](https://gdcvault.com/play/1023280/Motion-Matching-and-The-Road)
- [GDC: UFC 2009 physics and animation](https://www.gdcvault.com/play/1012304/The-Next-Generation-of-Fighting)
