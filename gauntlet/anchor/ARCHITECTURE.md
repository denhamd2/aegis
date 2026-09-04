# ARCHITECTURE.md — the contract

This is the contract gauntlet builders may not violate. A slice can change
almost anything about *how* it hits the bar; it cannot change the things
listed here, because other slices and the capture/evidence pipeline depend
on them holding.

## Engine

- Godot **4.6.3-stable**, Forward+ renderer, **Jolt** physics (4.6 default).
- GDScript throughout. Only drop to C# if profiling proves GDScript is the
  bottleneck for a specific system — not as a default choice.

## Determinism (hard requirement)

- All gameplay logic runs in `_physics_process`, at a **fixed 60 Hz** tick
  (`physics/common/physics_ticks_per_second = 60` in `project.godot`).
- Gameplay RNG is seeded per match (`ReplaySystem.start_recording(seed)` /
  `start_playback(replay)`). Never call `randf()`/`randi()` bare in gameplay
  code — always go through a seeded `RandomNumberGenerator`.
- Input comes from **either** a live device **or** a `ReplayResource` —
  never both in the same run. Gameplay code reads input exclusively through
  `ReplaySystem.get_input(player_index, live_input)`, never the `Input`
  singleton directly, so recording and playback exercise the same code path.
- Rigid-body simulation (ragdoll settle, rope wobble, crowd debris, cloth)
  is **cosmetic only** and must never feed back into gameplay state
  (damage, momentum, FSM transitions, positioning that gates a move). Jolt
  is not guaranteed bit-identical across platforms; the moment cosmetic
  physics touches gameplay state, replays stop being deterministic.
- Same seed + same replay must always produce the same
  `ReplaySystem.compute_end_state_hash()`. This is enforced by
  `game/tests/test_determinism.gd` and re-checked by every capture's
  evidence gate.

## The FSM is authoritative

- `WrestlerFSM` (`game/core/fsm/wrestler_fsm.gd`) is the single source of
  truth for what a wrestler is doing. Systems (combat, camera, minigames)
  read FSM state; they do not maintain parallel state machines.
- `LEGAL_TRANSITIONS` is the whole legality contract. An illegal transition
  is a bug, not a case to special-case — call `transition_to()` and let the
  assert fire in debug builds. Do not wrap it in `if` checks that silently
  swallow illegal transitions.

## GrappleRig owns paired moves

- Any move driven by a two-skeleton matched animation (tie-up throws,
  suplexes, slams, paired reversals) goes through `GrappleRig`
  (`game/core/grapple/grapple_rig.gd`). It is the only system allowed to
  suspend a `CharacterBody3D`'s physics processing and directly set both
  wrestlers' transforms.
- Strikes, solo locomotion, and getups are single-character and driven by
  each wrestler's own `AnimationTree` — they do not go through `GrappleRig`.

## MoveDef is the tuning surface

- Per-move timing, damage, and gating data lives in `MoveDef` resources
  (`game/resources/move_def.gd`), not hardcoded in scripts. Gauntlet
  builders fixing a timing/feel gap edit `.tres` instances of `MoveDef`,
  not code, wherever possible. This is what makes a timing slice
  independently judgeable without a code review.

## Capture and evidence gate

- `tools/capture/run_capture.sh` drives Godot's Movie Maker mode
  (`--write-movie --fixed-fps`) headless under `xvfb-run` on the **same
  rendering method the game ships** (Forward+, via the Vulkan driver — see
  the renderer rule below), plus `CaptureHarness` (`game/core/capture/capture_harness.gd`)
  dumping labeled PNG frames at beat offsets (`tie_up`, `apex`, `impact`,
  `pin_start`, `three_count`).
- Every capture produces `capture_manifest.json`. `tools/capture/evidence_gate.py`
  validates it — frame count, non-black-frame ratio, HUD presence, replay
  end-state hash — **before any critic sees the capture**. A manifest that
  fails the gate voids the round; it does not count as a loss, and the
  ratchet does not move.
- **The renderer rule is about the pipeline, not the rasteriser.** This
  replaces the earlier flat ban on llvmpipe for visual slices, which
  conflated two different defects and blocked the visual slices outright:
  under it, priorities 2 and 3 of `VISUAL_BAR.md` went unjudged for two full
  rounds because no admissible capture could be produced at all.

  What actually invalidates a visual judgement is rendering through a
  **different pipeline than the game ships**. `project.godot` ships
  `forward_plus`; a `gl_compatibility` capture has no SSAO, no SSR, no
  SDFGI, no volumetric fog, and tonemaps differently, so its pixels are not
  the game's pixels. Whether a *GPU* or a CPU rasterised those pixels
  changes their speed, not their values.

  This was measured before it was written down. The same scene, the same
  `measure_silhouette.py`, one frame apart:

  | | mat | mat↔A | mat↔B | A↔B |
  | --- | --- | --- | --- | --- |
  | `gl_compatibility` | 0.458 | 0.292 | 0.291 | 0.001 |
  | `forward_plus` | 0.172 | 0.094 | 0.044 | 0.050 |

  Every visual number this project recorded before that measurement was
  read off `gl_compatibility` — a renderer the game does not ship.

  So: **`forward_plus` captures are admissible for visual slices whatever
  rasterised them**, carrying a recorded `software_rasterised` caveat when a
  CPU did. `gl_compatibility` captures stay void for a visual slice. And
  **no software capture, of either pipeline, may support a performance
  claim** — frame cost is exactly the thing a CPU rasteriser gets wrong.

  Every manifest records `pipeline` (from
  `RenderingServer.get_current_rendering_method()` — the project *setting*
  is not evidence, it reads `forward_plus` even during a Compatibility run),
  `rendering_driver`, `video_adapter`, `gpu_backed` and `software_rasterised`.
  `evidence_gate.py --visual` (`VISUAL_SLICE=1 run_capture.sh`) enforces all
  of it, so the rule does not rest on whoever remembers how the capture was
  run.

## Reference-driven tuning

- `gauntlet/refs/` is measured, not remembered. Anything a builder or critic
  cites as "how WWE 2K does it" must trace to a file under `gauntlet/refs/`
  (`timings.md`, `camera.md`, `hud.md`, `feel.md`, or a labeled frame under
  `refs/frames/`). No citation, no claim.
- Where a bar can be stated as a number, state it as a number:
  `tools/refs/measure_frame.py` measures a reference still and one of our
  own captures the same way, so "silhouette readability" and "the
  background is empty" are gaps with sizes rather than opinions.
- `gauntlet/refs/VISUAL_BAR.md` and `FEEL_BAR.md` are the one-page anchor
  docs every visual/feel slice is judged against. Keep them short enough
  that a fresh-context critic can hold the whole bar in mind.

## Third-party assets

- **Permitted: Everything goes, no limits.

## Scope

- Vertical slice: one 1v1 exhibition match, two wrestlers, complete core
  loop (strikes, tie-up, grapple chains, irish whip, reversals, momentum →
  signature → finisher, pin kickout, submission, ref, win conditions, AI
  opponent). Match variety, roster, creation suite, and career are out of
  scope until this slice is anchored end to end.
