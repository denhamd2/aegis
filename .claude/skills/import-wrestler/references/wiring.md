# Wiring a model into the game

`WrestlerController` does not know about any specific model. It probes the node
above the `AnimationPlayer` for methods and falls back when they are absent, so a
new model is a script plus two scene files — no controller changes.

## The interface

Implement these on a `Node3D` script (`game/core/match/<name>_model.gd`), modelled
on `game/core/match/roman_model.gd`. All five are optional; the fallback for each
is what the base rig needs, so implement only what differs.

| method | called from | what happens without it |
| --- | --- | --- |
| `get_game_skeleton() -> Skeleton3D` | `_find_model_skeleton()` | falls back to the first `Skeleton3D` found by name — wrong on a multi-skeleton model |
| `apply_physique_height(height: float)` | `_ready()`, after `_find_model_skeleton()` | scales only the one skeleton, resizing part of the character inside the rest |
| `adapt_animation_library(source, source_skeleton := null) -> AnimationLibrary` | `_adapt_animation_library()` | the library is used verbatim, unconverted |
| `game_bone_name(game_bone: String) -> String` | `_skeleton_bone_name()` | game bone names are passed through unmapped, so IK and pose code find nothing |
| `uses_universal_attire() -> bool` | `_uses_universal_attire()` | treated as `true`, and `WrestlerAttire.build()` paints generated trunks onto a model that already has clothes |

Two of these are silent when subtly wrong, which is why they are worth naming:

- **`adapt_animation_library`** — see `traps.md` §Retarget. The controller calls
  it with **one argument** for the paired poses and strike clips. If the second
  parameter defaults to something that skips the conversion, those two libraries
  stay inverted while the `.glb`'s own library looks fine.
- **`apply_physique_height`** — the controller only calls it if
  `model.has_method("apply_physique_height")`. A typo in the name is not an
  error; it is a silent fallback to the single-skeleton path, and the symptom
  shows up rounds later as a bald crown.

The model script's `_ready()` is where material repairs, runtime geometry and the
animation-library copy belong. Split anything needing a real renderer behind
`DisplayServer.get_name() != "headless"`, so headless test runs stay clean.

## Scene files

Two, mirroring `scenes/roman_model.tscn` and `scenes/roman_match.tscn`:

```
[node name="<Name>Model" type="Node3D"]   script = <name>_model.gd
  [node name="Armature" type="Node3D"]
  [node name="Source"]                    instance = <name>.glb
  [node name="AnimationPlayer" type="AnimationPlayer"]
```

The `AnimationPlayer` must be a direct child of the scripted node —
`WrestlerController` finds the model as `anim_player.get_parent()`, which is what
makes the duck-typing above resolve.

Then a match scene setting `character_model_scene` on both wrestlers. Set
`is_ai = true` on `WrestlerA` as well: `match.tscn` leaves it as the human slot, a
passive wrestler never presses grapple and loses every tie-up, and the grapple
chain is then unreachable in the one scene named for the model.

`WrestlerController._install_character_model()` instantiates the scene as a child
named `CharacterModel` and applies a **180° yaw** to it. That yaw is pinned by
`tests/test_wrestler_model_orientation.gd`. If your rig's forward is already −Z,
the yaw is wrong for it — change it deliberately and update the test, don't
cancel it with a second rotation somewhere else.

## Animation mixer ownership

**Two `AnimationMixer`s must never write the same `Skeleton3D`.** Every animation
bug in this project is a violation of that rule or an over-correction of it:

1. Both the wrestler's own `AnimationTree` and the paired-grapple rig active →
   whichever processes later in tree order silently wins each frame, and the
   paired animation is invisible *while genuinely playing*.
2. Silencing the `AnimationTree` during grapples → every bone the paired clip does
   not cover snaps to bind pose for the whole move. A worse bug.
3. The actual rule: the conflict was never about both systems being active, only
   about both writing **the same data**. The paired clip needs only the two root
   transforms. Remove the bone tracks and the ownership hack disappears.
4. Bone-level paired performance therefore lives in a **separate library**
   (`paired_poses.tres`, clips named `<move>__attacker` / `__defender`) played by
   each wrestler's own tree, while the root clip stays on the match-level player.
   Same clip length, both started on the same physics tick, so they stay in sync
   with no new machinery. A move with no recipe resolves to `""` and falls back,
   so it degrades rather than breaks.

Set `callback_mode_process` to `ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS` on every
mixer. The default is wall-clock paced, so frame-labelled captures will not
reproduce across render framerates.

A one-shot clip override must be **consumed**, not queued. A version that left the
request pending when its transition never happened (a hit that knocked the
wrestler down instead) spent it on an unrelated hit later — measured mis-picking
2 of 10 landed moves.

Presentation driven from the controller's `_physics_process` stops during a
paired move, because `GrappleRig._suspend()` calls `set_physics_process(false)` on
both bodies. Grip IK was frozen for the entire duration of every paired move for a
whole round because of this — the blend sat pinned at 1.00 through a suplex.
Anything that must track during a move is driven from the rig's own
`_physics_process`.

## If the rig has no clip for something

Two techniques, in order of preference:

**Pose-stitching.** The base rig ships 43 CC0 clips containing nearly every pose a
wrestling throw needs — a crouch-and-drive, a load, an overhead extension, an
airborne body, a limp one, an impact. Sample poses out of them at measured times
and sequence them. Split it like the `MoveDef` split: a recipe file of
`{t, clip, at, bones}` entries with the measured pose table in its header, and a
generator that derives its track list from a real clip on the rig rather than
hardcoding paths. Output committed, byte-identical across runs. Every pose is a
real frame of real animation; the recipe only chooses and sequences, which is what
keeps them human-looking with no hand-typed quaternions. See
`game/tools/anim/build_paired_poses.gd`.

**Know when stitching cannot reach.** 43 clips and not one throws a leg — measured,
the highest a foot ever gets relative to the hips is −0.22 m. A first stitched
kick rendered as a man throwing a punch, because the only thing moving was
Sprint's arm swing. The answer was to pose the leg on a real stance, finding axis
and angles by rotating `thigh_l` about each axis in turn and reading the foot back
through FK, then verifying on the generated clip itself independently of
rendering.

**FK over a clip's own tracks is a measuring instrument.** It is how a strike
range of 1.8 m was shown to be half a metre of clear air (the fist reaches
0.76 m; with a 0.4 m capsule radius the honest reach is ~1.16 m). And nothing
scales an `AnimationNodeAnimation`, so a state's tick count and its clip's length
must be made to agree by generating the clip — not by hoping.
