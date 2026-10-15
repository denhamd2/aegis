# Next steps -- the roadmap

What is done, what comes next, and in what order. Updated at the end of each
round; the README is the detailed log of how each piece was built.

Last reconciled 2026-10-15 against `main` at `1f1bf95` and the current working
tree. This checkout contains substantial uncommitted work; the status below
does not imply that those changes are on GitHub or in a Mac release.

## Done and on the Mac build

- **Crowd audio and chants**, all free sources: an arena crowd at broadcast
  loudness, chants checked by a speech recogniser (Co-dy, O-T-C, This is
  awesome, Holy shit!, the count), and louder entrances.
- **Weapons phase 1, grips**: hands on the handles of every weapon, carried
  within 3 cm (the table within 4).
- **Weapons phase 2, pickups**: the lift fits the weapon (one hand, two hands,
  or a squat for the heavy ones); his hands close on it where it lies, and it
  never jumps into his hand.
- **Selling**: every hit, by weapon or by move, is sold to its size and to how
  much he has left -- light, medium, heavy, to the knee, or down.
- **Blood**: the dangerous weapons cut him, more for a bigger shot and a more
  beaten man. It starts as a cut at the hairline and builds to a crimson mask,
  then dries. The tacks cut his back. The canvas gets drips, pools, spatter and
  smears. On by default; OPTIONS > BLOOD > OFF to turn it off.

## Weapons phase 3: weapon-specific swings

Each family gets its own body clip (in `game/tools/blender/wrestling_clips.py`)
and its own swing path (`WeaponCatalog.SWING_PATHS`), so the weapon travels
with his hands rather than the hands chasing a generic swing.

| Family | Weapons | The swing |
| --- | --- | --- |
| Bat | baseball bat, barbed-wire bat, lead pipe, sledgehammer | two hands stacked, step in, hips turn through |
| Slapshot | hockey stick | a slapshot (the owner's pick) |
| Chop | kendo stick | two-hand overhead chop |
| Chair | steel chair, barbed-wire chair | held by the legs, high overhead |
| Two-handed slam | trash can, steel steps | overhead, both hands |
| Shovel | shovel | flat of the blade, overhead |
| Crutch | crutch | held by the foot end, overhead |
| Bonk | ring bell, frying pan, championship belt | overhand |
| Flat face | cookie sheet, stop sign, briefcase | the flat face into him |
| Ladder | ladder | lift high, step through, bring it down |
| Table | table | two-hand slam |
| Fist | chain | wrapped round the fist for a punch (the owner's pick) |

- Overhead swings stop at head height, never in the mat.
- **Phase 3 done:** `KNOWN_SWING_SLIPS` in
  `game/tests/test_weapon_grip_contact.gd` is empty -- every swing keeps
  both palms within 3 cm of the handles -- and the clip gates pass (pose lint,
  body deformation, clip authoring).
- Review sheets for the new bonk, flat-face, crutch, and chain motions were
  rendered and checked; ladder/table reuse the two-hand overhead/slam forms.

## Weapons phases 4-5: set-piece spots and AI weapon use

- **Implemented on `main`**: No Holds Barred retrieval and use decisions,
  table setup and paired suplex spot, weapon-specific impacts, weapon-retrieval
  inserts, and the table-break camera/sound response.
- **Added this round (working tree)**: the AI can now line up the same paired
  spot over thumbtacks, a bed of nails, or a barbed-wire board. These pieces
  are weighted as common wild-match picks; nonbreaking landings now receive a
  broadcast insert and a weapon-specific impact sound.
- **Completed this slice (working tree)**: the ladder now has a laid-out
  landing state, AI selects its dedicated damage/recovery move for the paired
  suplex spot, and a short guarded ladder-impact sell replaces the generic
  suplex follow-through. Unit coverage checks AI selection, mat-level bounds,
  landing damage, and the specific sell. The paired-shot probe accepts
  `--weapon ladder` for review captures. The current cloud image has neither
  `xvfb-run` nor a Vulkan display driver, so a valid rendered review capture
  still needs to be made on a capture-capable host.
- **Added this slice (working tree)**: an upright ladder can now be set,
  climbed and descended on fixed ticks with hand/boot targets on its rungs.
  The AI takes one climb opportunity while its opponent is down; a hit tips
  the ladder and sends the climber into the downed recovery path. Laid-out
  ladders still support the existing paired slam. From the top, a wrestler
  can now launch a paired diving elbow at a downed opponent. The clip preserves
  actual ladder height, the victim gets a matched chest impact and guarded
  settle, and the normal downed recovery remains in charge. A carried ladder
  opens upright inside or outside the ring; an upright ringside ladder can be
  folded, picked back up, and slid under the ropes. Next ladder work:
  capture and tune the spot on a render-capable host, then consider broader
  ladder offense (weapon swings and safe climb interruption variants).
- **No Holds Barred phase 0**: core rules, fighting outside, rope crossings,
  and weapon retrieval are implemented. Revisit only if a full match probe
  reveals a remaining rules or referee failure.

## Entrance and ring presentation

- **Implemented in the working tree:** the shorter two-man entrance close,
  timed stage/crowd/camera opening, Cody and Roman's ramp-to-ring routes,
  stair/apron/rope transitions, Cody's coat removal and folded handoff,
  Aubrey's prop carry, timekeeper table placement, and light recovery for the
  staredown. The smoke's black disc was traced to its shadow-casting cone and
  removed. The entrance and prop-handoff test suites cover these paths.
- **Next: native Mac visual review.** Capture the opening, each entrance,
  prop handoff, and the normal match shot on the target Mac. Review the image
  quality, body/prop placement, lighting, and frame pacing against the user's
  game. Headless tests cannot validate rendered appearance, and the cloud
  renderer did not produce a faithful Mac Forward+ frame.
- **Then: ladder spot review and tuning.** Review the ladder setup, climb,
  interruption, and top-rope dive in a rendered match. Extend its offense with
  authored ladder swings and a few readable climb-interruption variants only
  after the current spot is visually approved.

## Character shape and animation clearance

- **Body morph audit remains open.** Keep the existing skeletons and rest
  poses; audit Roman and Cody's rendered silhouettes and attire fit against
  the supplied references, then make narrowly scoped mesh/weight changes.
  Do not change rig dimensions until paired grips, foot placement, and
  collision assumptions have been remeasured.
- **Clearance gate:** `test_pair_clearance.gd` currently flags the new
  `ladder_aerial` landing at about 0.67 of the clip (body overlap 0.065 m,
  arm overlap 0.051 m), specifically attacker `calf_l-foot_l` against
  defender `thigh_l-calf_l`. A focused foot-splay trial reduced body overlap
  only to 0.063 m and was discarded. The ladder gameplay suite passes, but
  this measured contact needs a stronger authored trajectory/leg-path fix
  before the full test gate can pass. Keep the clearance limits unchanged.

## Current priority: owner's New.png visual target

The 15 October reference comparison supersedes the older material/look
choices where they conflict. See
[`visual_target_2026_10_15/brief.md`](visual_target_2026_10_15/brief.md) and
[`review.md`](visual_target_2026_10_15/review.md).

- **Implemented in the working tree:** photographic textured near crowd with
  shared atlases and section culling; outward audience washes and stationary
  blue aisle accents; visible long-side stairs; pad roughness and restrained
  emission; varied LED spill; metallic diamond-plate steps; repeatable native
  Mac look/frame-pacing tools.
- **Verified:** 46 focused crowd/bowl/lighting cases passed. A subsequent
  run passed the four visual contract cases with added normal/tangent checks
  plus seven real replay round-trip cases. The near-crowd GLB rebuilt byte for
  byte. These checks do not establish a visual match or a Mac frame rate.
- **Next:** rendered comparison and tuning, then wrestler skin/attire and
  canvas/apron polish under the accepted light. Target Apple Silicon/16 GB,
  1080p/60 fps; the exact chip and native performance remain unmeasured.
- **Release gate stays open:** native visual acceptance and the separately
  recorded ladder-aerial clearance failure still need resolution.

## Order of work

1. Complete the New.png visual comparison and tune the first environment /
   crowd slice. Capture Mac-native appearance and frame pacing.
2. Finish wrestler skin/attire and canvas/apron polish, then resolve the
   ladder-aerial clearance failure while preserving impact and recovery.
3. Tune the ladder broadcast insert and author ladder swing/interruption
   variants from the rendered review.
4. Complete the Roman/Cody body-morph audit against the reference stills.
5. Run the complete test suite, make a Mac build, and review that build on the
   target machine before calling these changes release-ready.

## How every step is checked

1. gdUnit tests for the behaviour, run headless.
2. A rendered review sheet, looked at before it is sent to the owner.
3. The full test suite before every push.
4. Shipped to `main`, which rebuilds the Mac app on the `mac-latest` release.
