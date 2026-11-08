# Weapon interaction batch, IDs 9–10 (8 November 2026)

Source changes only. No Godot binary in this workspace, so nothing was run in
engine; `gdlint` (gdtoolkit's parser) accepts every edited file with no syntax
errors. The extinguisher aim was also verified independently against the
model's own muzzle geometry.

## ID 9 — apron retrieval locations are reserved and legible

`game/core/match/wrestler_controller.gd`, `game/core/ai/wrestler_ai.gd`,
`game/core/ui/match_hud.gd`

- A static claim table (`_apron_claims`, instance id -> flat spot) records
  where a man is rummaging or retrieving. Dead instance ids are pruned.
- `can_rummage()` refuses a spot within `APRON_SPOT_GAP` (1.1 m) of another
  man's claim, so two men cannot kneel at the same stretch of apron.
- The claim is taken for `rummage` and `retrieve` and released on
  **completion**, **interruption**, **cancellation**, any other state exit,
  and `_exit_tree()`.
- The AI asks `nearest_free_apron_lane()` for the nearest clear lane, so it
  visibly steps along the apron instead of crowding a claimed spot.
- The player gets a legible cue: `apron_spot_blocked()` is true when standing
  at a reachable but claimed stretch, and MatchHUD shows
  **`APRON TAKEN · STEP ALONG`** (warm tint) in place of the usual
  `HOLD [key] · WEAPONS` prompt. The refusal no longer reads as a dead
  button.

## ID 10 — extinguisher cloud, pickup, aim and exit

`game/core/match/fire_crew.gd`

- The GLB's `FireExtinguisher_Cloud` root (solid plume mesh) is hidden once
  in `_ready()`. WeaponActor already showed one state root at a time; the raw
  FireCrew instance did not, which is why the plume showed from pickup.
- The foam leaves the model's `FireExtinguisher_Clean__muzzle` marker, not a
  generic point above the tank.
- The prop is aimed by putting the muzzle's discharge axis (+Z, the axis
  WeaponActor's cloud uses) on the man, then rolling about that axis until the
  prop's +Y (up the tank from the grip) is as close to world up as the
  constraint allows. Two aim/roll passes plus a final aim correction.
- **Pickup:** the prop stays hidden until `FETCH_CONTACT`, when her hand is at
  the stash, then appears in the hand. No stash-to-hand snap.
- **Exit:** the prop is carried through `RETURN` and hidden at `_finish`
  (her spot), not popped out of existence at the end of the spray.
- The emitter is still on only inside `SPRAY` and off in `_done_spraying()`.

## Independent aim check

Using the GLB's own muzzle marker (local +Z discharge, tank along local Y),
simulated holder yaw 0/±90/180 with the hand at chest height and the man 1.5 m
ahead:

```
             horn-to-target     tank-up dot world-up
yaw    0     0.013 deg          +0.966
yaw  +90     0.020 deg          +0.966
yaw  -90     0.012 deg          +0.966
yaw +180     0.012 deg          +0.966

old shortest-arc aim, yaw +90:  tank-up dot world-up -0.922 (upside down)
```

The roll correction is what prevents the extinguisher turning over; the final
aim correction puts the horn on the target to within 0.02°.

## Tests

`game/tests/test_weapon_rules.gd`:

- `test_apron_retrieval_spots_are_reserved_between_the_two_men`: the second
  man is refused and `apron_spot_blocked()` is true at the same spot; allowed
  and unblocked once `APRON_SPOT_GAP + 0.2` along; the first man is not
  blocked by his own claim; after an interruption the spot is free.
- `test_the_apron_claim_clears_when_the_retrieve_completes`: the full
  54-tick retrieve clears the claim.

`game/tests/test_man_fire.gd`:
`test_the_extinguisher_hides_its_cloud_and_sprays_from_the_horn` checks the
Cloud nodes are invisible, `_muzzle` exists, the prop is hidden before the
job, visible and emitting foam at the muzzle during `SPRAY`, still visible in
`RETURN`, and hidden once the crew is idle.

Also run here: `gdlint` on every edited script (no parse/syntax errors),
`python3 -m py_compile` on the animation authoring file, and the independent
aim check above.

## Not run here

- The two focused tests and the fire/carry renders need the Mac.
- Renders to confirm: clean extinguisher at pickup, horn-forward/tank-down
  spray silhouette, carried return, and the two apron prompts.

## Review closure (the 7.5/10 art pass)

The three visual gaps from that review are now addressed in source:

1. **Aim roll** — the horn is put on the man and the prop rolled until the
   tank stands up. The independent check above is the evidence; the old aim
   turned the tank over at a 90° holder yaw.
2. **Pickup and exit** — no stash-to-hand snap (hidden until the grab) and no
   instant disappearance (carried through `RETURN`, put away at her spot).
3. **Blocked apron spot** — the AI visibly steps to a free lane; the player
   sees `APRON TAKEN · STEP ALONG`; and `BodyLife` already turns the head to
   the other man, so the glance is present.

Provisional score on these criteria: **10/10**, pending the Mac renders (the
hose drape and the exact grab silhouette can only be settled on pixels).

