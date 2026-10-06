# Cody's entrance vs WWE 2K26: review and improvement plan

The owner asked for the same review as Roman's (`roman_entrance_aaa_plan.md`): animation,
camera, lighting and smoothness, against the WWE 2K26 Cody entrance in
`raw/video/cody_roman_2k26.mp4` (0-145 s). Sources:
- a contact sheet of that window every 3 s;
- 1 s sheets of the stage (20-61 s) and 0.5 s sheets of the walk (61-78 s);
- our own capture (`tools/probe/entrance_shots`, every 90 frames, Vulkan, 1280x720).

## What 2K26 does

**Animation.** He comes out of thick smoke in a white portal, walking slowly at the lens.
- **On the stage:** open-palmed "come on" arms, a 3/4 turn to one side of the building, the
  kneel at the front of the stage, then standing with his arms wide.
- **Down the ramp:** a confident, upright, open-chested walk. The arms swing free with a
  slight bend at the elbow, and the head turns and holds on each side. He points a fan out
  and yells at the crowd; each gesture rises and falls over about half a second.
- He never moves robotically. Every limb is in continuous motion.

**Camera.** About 17 cuts in about 150 s, so 8-9 s per shot.
- Front full body in the smoke (27-33 s), then a profile 3/4 (36-39 s).
- The kneel: a low front, full body (42-48 s).
- One very wide shot from the ramp (51 s), then arms wide, front (54-60 s).
- The walk:
  - a long waist-up hold walking at the lens, the screen filling the frame behind him
    (61-69 s);
  - over the shoulder on the jacket's crest (70-73 s);
  - a low front with the ramp's LED blinders (74-76 s);
  - close at the barricade (78-81 s).
- Then low ringside and in-ring angles, and a single high wide of the bowl at the end.

**Lighting.** The stage is high-key: the white portal and his flag art put light all over
him. Down the ramp the arena is dark, but he is always exposed front and back.

## What ours does (measured)

**Lighting: no gap.**
- His white and red gear reads in every shot of the capture.
- The generic fixes from Roman's round already ride with him: the camera key, the ramp wash
  and the brighter walk keys. The smoke emergence (frame 9 of our sheet) is already the
  2K26 picture, white portal and arms out.

**Camera: one bad shot.**
- `CODY_WALK_SHOTS` still had `arena_high` (our frame 21): a dot on a dark ramp, the shot
  Roman's cut lost.
- There was no close front shot on the walk.
- The name card already keeps to 4 s (`RAMP_CARD_TICKS`, per wrestler).

**Smoothness: the same engine cause as Roman's, already fixed.** `tools/probe/motion_cadence
-- --who cody` at 120 fps: 119 of 240 drawn frames held without the smoothing, 0 with it.

**Animation: the walk is the gap.** `Walk_Crowd` was still the old procedural `_gait()`,
measured as the largest per-frame change in a joint's turn rate (deg/frame²):

| Problem | Measurement | Cause |
| --- | --- | --- |
| Knees snap every step | 16-18 | Roman's old walk was 6. The swing arc (sin^0.55) leaves the mat with a snap, and the legs hit full extension (99.5%, clamped) at heel strike and push-off. |
| Posture | | Leaned back 7° (spine pitch + is backward) with the head thrown back: the same fault as Roman's arms-back walk. |
| Foot roll | | Used the inverted shared ankle constants, so the back boot bent the wrong way, as Roman's did. |
| Arms locked straight | | Hands set below reach, so the forearm sat dead still then snapped. |
| Gesture arm kicks | 24-33 | The arm went up and down in 8-14 frames (about 3 m/s). A shoulder-girdle bug (below) made it jump by the chest's turn as it came down. |

**Shared defect found on the way.** RigPoser's clavicle follow (the body-morph round)
aims the clavicle from the armature's rest, not from where the chest carries it. Below 60° of arm elevation the clavicle inherits the chest; above it, it was
absolute. Any raised arm on a leaning or turning chest jumped by the chest's turn as it
crossed 60°. Roman's walk also had his arms locked straight for most of the cycle (hands
just below reach).

## Plan, and what was done

1. **Smoothness.** Done in Roman's round, for both men; verified for Cody (119 → 0 held
   frames).
2. **Re-author his walk on `_heavy_gait`** (the continuous gait Roman's walk was rebuilt on).
   Same 26-frame cycle and 1.2 m/s, so the director's cycle hand-offs are unchanged.
   - Upright, open chest; hips drop at double support (`low_at`), which also keeps the long
     stride within the legs' reach.
   - Heel rise, a Hermite swing, sway over the planted foot, shoulders against hips, head
     stabilised.
   - Foot roll the right way round. Arms within reach, with a slight bend, swinging a
     little behind the shoulders.
   - Gestures rise and fall over 20 frames on a smootherstep, travelling in front of him;
     the elbow pole blends from the solver's own; the point is in reach.
   - Gate: knees and thighs 18 → 6, gesture arms 33 → 7.5 (bar 8 at his tempo,
     `test_codys_walk_has_no_jerks`).
3. **Shoulder follow carried by the chest, opt-in** (`clav_carry`, used by Cody's walk).
   Made the default, it moved the grapples' hands 1-6 cm off their fitted holds
   (test_pair_clearance) and a re-fit made the spears worse, so the grapples keep
   the shoulders they were fitted on.
   - **Roman's walk hands up 5 cm:** no locked-arm frames; his walk incl. forearms now 3.9
     (bar 4.5).
4. **2K26 camera grammar on the walk.** `steadicam_front` (8 beats), `over_shoulder`,
   `face_walk`, `barricade_track`; `arena_high` gone.
5. **Verify and ship.**
   - Gates: pose lint, pair clearance, the full suite.
   - Renders of the walk.
   - The Mac build for the owner's eyes.

Left as they are, on purpose:
- **`Whoa_Arms` and `Fists_Down` keep their snap** (12.5 and 31). They are the accents on
  the pyro hits: a throw and a punch, not a walk.
- **The stage set's own portal art stays** (the slice's set is original, not 2K26's flag
  wall).
