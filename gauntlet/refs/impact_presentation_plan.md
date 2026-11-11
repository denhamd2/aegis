# Universal impact-presentation pass

Status: designed 9 Nov 2026; not implemented. This is the pass that takes
effects and selling from the current 4/10 floor to the 10/10 bar, for every
move rather than per clip.

## Presentation law

One pure function, `WrestlerController.impact_spec(move, strength, tier,
weapon_impact)`, returns `{ticks, trauma, vfx, sell}`.

| Band | Examples | Hit-stop | Trauma | VFX | Sell |
| --- | --- | --- | --- | --- | --- |
| Light | jab, chop, gut punch, ground fist | 0 | 0.0 | small flash | existing light react |
| Medium | cross, hook, front kick | 1 | 0.20 | flash + 6 sparks + sweat on head shots | existing medium react |
| Heavy | heavy kick, bionic elbow, clinch knee, weapon blow | 2 | 0.45 | flash + 10 sparks + spray + dust | existing heavy react |
| Signature | tier SIGNATURE or `signature_` key | 2 | 0.75 | full burst | KNEE/DOWN + ImpactSell profile |
| Finisher | tier FINISHER | 3 (landing only) | 1.0 | largest full set | authored sell + profile |

Paired throws freeze only on grounded landings, at the contact fraction, never
mid-air. Light never shakes the camera and never freezes.

## Seams

- `wrestler_controller.gd`: replace `hit_stop_ticks_for` with `impact_spec`;
  keep `hit_stop()`/`Inertializer.freeze` as the only freeze mechanism. Emit a
  presentation-only `impact_landed` signal from `_resolve_pending_hits` and
  `_take_ground_hit`.
- New `impact_presentation.gd` director: subscribes to both wrestlers, owns the
  paired-move contact scheduler (poll `grapple_rig.progress()` against the
  camera's `impact_fraction`), coalesces same-tick hits, skips fired-up
  defenders, and calls the VFX pool. Writes no game state.
- New `impact_vfx.gd`: 10 pooled `CPUParticles3D` emitters + 3 flash quads,
  seeded, 256 live-particle cap, no dynamic lights. Flash, sparks, sweat spray,
  mat dust.
- `match_camera.gd`: band trauma in `_on_move_landed`; arm GRAPPLE/POWER paired
  shakes instead of only signature/finisher.
- `impact_sell.gd`: add class profiles (`back_bump`, `front_bump`) keyed off the
  paired id and `down_face_first`, never stacking on authored or surface
  profiles, still DOWN-state only.
- `strike_recipes.gd`: `reaction_for` routes leg-dominant damage to `hit_knee`;
  `sell_for` maps it to `sell_gut`.

## Tests

- Update `test_hit_flinch_and_life` bands: jab 0, cross 1, kick 1, kick_heavy 2,
  superman 2, cross_rhodes 3.
- New `test_impact_presentation`: purity per band, fired-up suppression,
  same-tick coalescing, paired grounded-only freeze, VFX budget (200 impacts,
  <= 256 live particles, pooled node count), replay-hash determinism, sell
  mapping and suppression.
- Extend `test_camera_fight_forever` for medium/heavy trauma and POWER armed
  shake.
- Visual set: one capture per band, both roles, match cam plus close/side, and
  a slow-motion contact capture proving freeze starts on the contact frame.

## Do not

- Stop or seek the AnimationTree/clip/FSM; freeze the Inertializer only.
- Freeze aerial contacts, light hits, or more than 3 ticks.
- Add per-hit nodes, dynamic lights, or GPU particles on the compat path.
- Let class sell profiles stack on authored or surface selling.
