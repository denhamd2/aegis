# aegis

An original 3D wrestling vertical slice (Godot 4.6, Forward+, Jolt), built
with the Gauntlet Loop pattern — builder/critic rounds judged against a
measured reference corpus.

The game ships fully original wrestlers, movesets, and branding. WWE 2K
footage is used only as a *measurement* reference (frame timings, camera
framing, HUD layout) — no extracted models, textures, audio, or likenesses
enter this repo.

## Layout

- `game/` — the Godot project. Core systems live in `game/core/`
  (`fsm/`, `grapple/`, `combat/`, `minigames/`, `camera/`, `replay/`,
  `capture/`); `game/resources/` holds the `MoveDef` tuning surface;
  `game/assets/characters/` holds the CC0 retargeting base mesh (see its
  `CREDITS.md`); `game/tests/` holds gdUnit4 tests.
- `gauntlet/anchor/ARCHITECTURE.md` — the contract gauntlet builders may
  not violate. Read this first.
- `gauntlet/refs/` — the reference corpus: measured timings, camera
  behavior, HUD layout, and feel, all traceable to footage under
  `gauntlet/refs/raw/` (gitignored — drop clips locally).
- `gauntlet/status/` — `slices.json` + the generated
  `gauntlet-status.html` tracking every gauntlet slice's round count,
  verdict, and current largest gap.
- `tools/capture/` — the capture harness driver (`run_capture.sh`), the
  evidence gate (`evidence_gate.py`) that must pass before any critic sees
  a capture, and the status-page generator.

## Current phase

**Phase 0 (anchor infrastructure)** is scaffolded: project skeleton, core
system stubs, replay/determinism plumbing, capture harness, evidence gate,
CI, and the architecture contract.

**Phase 2 (grey-box MVP)** is scaffolded on top of it: `game/scenes/match.tscn`
wires two capsule wrestlers (`wrestler.tscn`), a box ring (`ring.tscn`),
`MatchCamera`, and `MatchReferee` into a playable loop — locomotion, strikes,
tie-up → grapple → move → hit-react/down, pin cover → kickout minigame →
three-count win, and one scripted AI opponent (`WrestlerAI`).

This has been verified against a real Godot 4.6.3-stable binary (headless),
including running full matches under `--fixed-fps` (which decouples
simulation from wall-clock time — ~27x faster than real time here) to
actually watch matches play out rather than guess from reading code. That
process is what caught every bug below; each was found by an actual
contradiction in simulated match state, not by inspection.

**A full match now reaches a three-count.** `godot4 --headless --path game
--fixed-fps 6000 scenes/match.tscn` prints `Match won by WrestlerB via
pinfall` in a couple of real seconds. Getting there required fixing, in
order of discovery:
- Untyped-Variant compile errors, and exported `Node`-typed fields silently
  staying null when assigned via `NodePath` in a flat `.tscn` (fixed by
  resolving explicit `NodePath` exports in `_ready()` — this also caught
  `WrestlerController.ai` never actually being wired to its `AI` child node).
- `GrappleRig` never resolving without a paired animation clip; the grapple
  move resolver discarding the attacker's chosen move; an AI range-priority
  bug that meant tie-ups never triggered; `CombatSystem` leaking orphan
  `Node` instances (now `RefCounted`).
- A striking wrestler could keep re-hitting an already-`DOWN` opponent,
  re-triggering `_go_down()` and resetting the getup timer forever — added
  an `UNHITTABLE_STATES` gate.
- The AI never sought a pin cover at all — added "opponent is down, walk
  in" behavior.
- The actual root cause of one wrestler never taking damage: `strike_move`
  is one shared `MoveDef` **resource** loaded once from a `.tres` and
  referenced by both wrestlers, and the code was tracking "has this attack
  already landed" via `move.set_meta("applied", ...)` on that shared
  resource — both wrestlers were fighting over the same flag. Fixed by
  moving that flag onto the wrestler instance instead of the resource.
- Momentum ("→ signature → finisher") was being applied to the defender
  taking damage instead of the attacker landing the hit — split
  `CombatSystem.apply_move()` into `apply_damage()` (defender) and
  `apply_momentum()` (attacker).
- `PinMinigame`'s kickout marker sweeps its entire range once per attempt,
  so "marker enters the window" as a bare win condition meant every pin
  auto-kicked-out before a three-count could land, regardless of window
  size. Replaced with a fill-meter: kickout progress only accumulates on
  ticks where the window is entered *and* the defender is actually
  pressing, and must cross a threshold — so window width (driven by
  attacker momentum and defender damage) now actually matters.
- Wrestlers kept processing input after the match ended and threw an
  illegal FSM transition trying to act from `PIN_DEFENDER` — both freeze
  (`set_physics_process(false)`) on `match_won`.

`gdUnit4` v5.0.0 (the tag CI originally pinned) doesn't compile against
Godot 4.6 — CI now pins v6.2.1, confirmed working (7/7 tests, 0 errors, 0
failures, 0 orphans).

Known Phase 2 gaps, honestly:
- Not played by a human yet — verification above is scripted/AI-vs-passive
  simulation, not a playtest with a gamepad. Whether the match *feels*
  right is unconfirmed regardless of whether it mechanically completes.
- Two identical AI opponents (same stats, same seed, no tie-breaker) can
  still deadlock in a mutual-knockout loop — confirmed separately from the
  real one-AI-vs-one-passive-player scenario above, which does complete.
  Not fixed; noted as a real gap for whenever match-vs-match AI matters.
- `GrappleRig` has no paired animation library yet (Phase 3), so it falls
  back to resolving on the move's frame count via a timer instead of an
  `AnimationPlayer` signal — replace once paired clips exist.
- Irish whip, running attacks, reversals, and submissions have FSM states
  and (for submission) a minigame, but aren't yet driven by the referee or
  AI — pin/kickout is the only win-condition path wired end to end.
- Tie-up resolution is still a placeholder rule (lower player index wins).

## Phase 3 progress: retargeting base mesh

`game/assets/characters/wrestler_base.glb` (and `_root_motion` variant) is
Quaternius's **Universal Animation Library** (Standard, CC0) — a 65-bone
skinned humanoid rig with 43 animations (`Idle`, `Walk`, `Jog_Fwd`,
`Sprint_Loop`, `Punch_Jab`, `Punch_Cross`, `Hit_Chest`, `Hit_Head`,
`Death01`, `Roll`, …). `wrestler_bone_map.tres` maps 52 of its bones onto
Godot's `SkeletonProfileHumanoid` (fingers/root partially unmapped — no
equivalent bones on this rig or no canonical slot). `scenes/wrestler.tscn`
now instances this mesh as the visual, with the original `CapsuleShape3D`
kept for collision only; `WrestlerController` autoplays `Idle` on ready so
it doesn't sit in bind pose.

Verified against the real Godot binary: imports cleanly, a real
(non-headless, OpenGL/llvmpipe) render shows the mesh in a proper idle
pose at ring scale (not a capsule, not a T-pose), and the full match
still completes via pinfall with the mesh wired in — 7/7 unit tests still
pass. See `game/assets/characters/CREDITS.md` for attribution and the IP
guardrail note (stand-in mesh only — no WWE-derived assets).

**Per-state animation switching now goes through a real `AnimationTree`
blend graph**, the long-term design `ARCHITECTURE.md` calls for — not a
direct `AnimationPlayer.play()` switch anymore. `WrestlerController`
builds an `AnimationNodeStateMachine` at runtime in `_build_animation_tree()`:
one `AnimationNodeAnimation` per `WrestlerFSM.State` that has a usable clip
(`STATE_ANIMATIONS`), and one `AnimationNodeStateMachineTransition` per
`WrestlerFSM.LEGAL_TRANSITIONS` edge between two such states, cross-fading
over 6 ticks. Built from those two tables at runtime rather than hand-authored
as a `.tscn` sub-resource graph, so it can't drift from the FSM's actual
state/transition set. `_on_fsm_state_changed` now calls
`AnimationNodeStateMachinePlayback.travel()` instead of `play()` directly —
xfade sequencing and state ordering are the engine's job.

Verified against the real Godot binary: 7/7 unit tests and full-match
pinfall completion still hold with the tree wired in, and a real OpenGL
render captured 12 ticks into `STRIKE` shows the wrestler genuinely
mid-`Punch_Jab` (fists up, weight forward, arm extended) — confirming the
state machine is actually driving the blended pose, not just leaving the
player on its previous clip. `WrestlerFSM.State.keys()`-driven mapping
still covers every state that has *a* usable clip on this rig — most are
close matches (`HIT_REACT` → `Hit_Chest`, `DOWN`/`PIN_DEFENDER` →
`Death01`); a few are honest placeholders standing in for content that
doesn't exist yet (`TIE_UP`/`GRAPPLE_HOLD` → `Interact`, `FINISHER` →
`Sword_Attack`, `GETUP` → `Roll`, the closest-available ground-to-standing
clip in this library, not a real getup animation). Transition curves
beyond a flat cross-fade, and the paired grapple animations below, are
still real remaining work.

Critically, **no paired grapple animations exist yet** — this
single-character rig covers locomotion, strikes, and getups, but the
plan's "no free CC0 paired grapple animations exist" constraint still
holds: those 12 grapple + 6 reversal moves still need authoring in
Blender as two-rig scenes, which is Blender work I haven't attempted.

Still open before the gauntlet (Phase 4) can start:

- **Phase 1** — populate `gauntlet/refs/` from real WWE 2K (or WWF No
  Mercy emulator, as fallback) footage. Currently placeholder/pending.
- **Phase 3 (remainder)** — ring/arena art and the paired grapple/reversal
  animation authoring above (the `AnimationTree` blend graph is now done).

See `gauntlet/anchor/ARCHITECTURE.md` for the full contract and
`gauntlet/refs/VISUAL_BAR.md` / `FEEL_BAR.md` for the anchor docs each
gauntlet round is judged against.
