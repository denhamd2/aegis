# Approved 11v11 and Kilmore Drive implementation

Owner confirmed both design-interview rounds on 2026-10-18. This supersedes the
old requirement to keep all roster work behind the 4v4 gate. Retain 4v4 as a
regression fixture; the new default target is a three-minute keyboard 11v11 match.

## Decisions and sequence

1. BR-022 (22/25): repair the shared garment; use a common body topology,
   skeleton and animation library, modular heads/hair and role-specific kits.
   Head edits happen in Blender as individual deltas from a versioned base.
   Height/build are editable, and shared asset rebuilds preserve identity data.
2. BR-005/011/013 (5/11/13): start Beechlawn #2–11 and John O’Rourke #1;
   Paddy Mason #69 is a reserve. Start in editable 4-4-2, with provisional
   outfield positions and neutral attributes. Bordeaux has Des Feeney #9,
   generic numbered slots and a distinct keeper slot/kit until more sheets arrive.
3. BR-011–013/016: role-aware support, cover and limited press; one functional
   keeper per team; a separate referee who follows play and is never selected
   or considered a pass/tackle target. Existing kickoff/goal/full-time behavior
   remains the short-match loop; complete foul/offside/card rules remain open.
4. BR-014 (14/25): close local-play broadcast framing, smooth long-pass widening,
   controlled-player feedback and radar. Do not try to show all 22 at once.
5. BR-023 (23/25): actual Street View/satellite layout outranks generated boards
   where inconsistent. Model the residential park boundaries, worn grass and
   irregular paint, weathered 7.32 × 2.44 m goals with sagging nets, trees, parked
   cars and approximately eight spectators. Default to bright overcast.
   Broad gentle terrain and collision agree; fine divots are visual. Heights
   inferred from images are estimates, not measured ground truth. Keep 105 × 68 m
   playable dimensions until a measured source establishes otherwise.
6. BR-021/025 (21/25): verify full human-mesh actions/contact/blends and profile
   23 actors. Web checks cover startup/input/framing; M1 Pro/16 GB 1080p/60 fps
   and native renderer appearance require target hardware acceptance.

## Asset contract

- Shared mesh/skin/animation resources; separate Skeleton3D, AnimationPlayer,
  AnimationTree playback and material parameters per actor.
- Body, head, eyes, hair, clothes and boots retain distinct named mesh parts.
  Team kit changes never tint skin/eyes/hair.
- Team/role kit resources reference shared source art. Individual name/number
  prints are separate small overlays, not copies of a complete 2K shirt atlas.
- Individual head edits use a base topology fingerprint and sparse local vertex
  offsets. Export fails if topology changes; it does not silently discard edits.
- One neutral profile per unknown identity. Player-specific ratings, surnames
  and exact proportions must come from supplied evidence or be labeled provisional.

## Reference-to-asset gaps

Sources are indexed in `references/README.md`: both location boards, the goal
sheet, archived Street View headings, satellite overviews and the pitch zoom,
plus individual character and team/keeper/referee kit sheets. Street View shows
open roadside grass/path/curb, houses, garden walls, utility poles and wires;
the opposite hard boundary differs from that roadside. Do not wrap an identical
wall/hedge around all four edges. Satellite shows overlapping faded markings,
worn strips and bare goal areas. It cannot determine individual bump heights.

Original blockers (now addressed): four-slot validation, slot-specific kickoff/
tactics, merged character detail meshes and blanket Y-Bot tinting. Shane's collar/sleeve/
hem silhouette is unfinished. Existing houses/trees/cars are a stylized blockout.
Compare fixed front/profile/action views and actual broadcast captures after each
major phase; do not label the field or character an exact likeness prematurely.

## Delivery evidence

Implemented: default 22-player match, separate referee, shared modular character,
role kits/prints, roster and reserve resources, basic full-team 4-4-2 decisions,
closer tracking camera/radar, shallow collision-matched terrain, rough chalk,
weathered goals/nets, residential dressing and eight spectators.

Actual automated evidence: full 180 simulated seconds, 11,035 fixed steps,
935.2 m ball travel, 5/1 shots and 1/0 goals, no sampled stationary-ball stall;
22 actors/two keeper controllers/one official; all-eleven manual switching;
terrain ray agreement within 4 mm; correct boundary ownership/restarts;
shared-human pass contact within 7.5 cm; 65 bones/17 clips and normalized weights;
head delta round trip and incompatible topology rejection. Shared meshes/materials
and separate playback retain the intended reuse contract.

See `art_briefs/11v11_release_evidence.md` for screenshots, scope and remaining
art/rules/performance gaps. A simulated match and software Web capture do not
establish native M1 performance or exact visual matching.
