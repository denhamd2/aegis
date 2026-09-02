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
  (`--write-movie --fixed-fps`) headless under `xvfb-run` with the OpenGL3
  (llvmpipe) driver, plus `CaptureHarness` (`game/core/capture/capture_harness.gd`)
  dumping labeled PNG frames at beat offsets (`tie_up`, `apex`, `impact`,
  `pin_start`, `three_count`).
- Every capture produces `capture_manifest.json`. `tools/capture/evidence_gate.py`
  validates it — frame count, non-black-frame ratio, HUD presence, replay
  end-state hash — **before any critic sees the capture**. A manifest that
  fails the gate voids the round; it does not count as a loss, and the
  ratchet does not move.
- **llvmpipe captures are sufficient for timing and feel slices only.**
  Ring/materials/lighting critics need GPU-backed captures — run those on
  real hardware, not CI. Do not judge visual-quality slices on software
  renders. Every manifest records `video_adapter` and `gpu_backed`, and
  `evidence_gate.py --visual` (`VISUAL_SLICE=1 run_capture.sh`) voids a
  software-rendered capture for a visual slice rather than leaving the rule
  to whoever remembers how the capture was run.

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

## IP guardrail

- Original wrestlers, movesets, and branding only. WWE 2K/No Mercy
  references are for **measurement** (frame timings, camera framing, HUD
  layout) — never for extracted models, textures, audio, or likenesses.
  Ripped-asset sources are off-limits, full stop.

## Scope

- Vertical slice: one 1v1 exhibition match, two wrestlers, complete core
  loop (strikes, tie-up, grapple chains, irish whip, reversals, momentum →
  signature → finisher, pin kickout, submission, ref, win conditions, AI
  opponent). Match variety, roster, creation suite, and career are out of
  scope until this slice is anchored end to end.
