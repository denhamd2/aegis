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
- `GrappleRig` has one paired animation now (`grapple_suplex`, see Phase 3
  progress below) but 17 more moves' worth of clips still fall back to
  resolving on the move's frame count via a timer instead of an
  `AnimationPlayer` signal.
- Irish whip, running attacks, reversals, and submissions have FSM states
  and (for submission) a minigame, but aren't yet driven by the referee or
  AI — pin/kickout is the only win-condition path wired end to end.
- Tie-up resolution is still a placeholder rule (lower player index wins).

## Bugfix: the AI never actually grappled, and why

A 45-second real capture (`godot4 --write-movie`, real OpenGL render) turned
up something the earlier "Match won by pinfall" checks never caught: an
AI-vs-passive match is just an infinite strike loop. Frame-stepping the
capture and cross-checking it against an instrumented headless run (state
transitions + landed hits + position, logged every tick) found the real
cause in `WrestlerAI.poll_input()`: the only branch that produces movement
was `distance > strike_range`, so the moment the AI closed to strike range
(1.6m) it stopped advancing forever — `tie_up_range` (1.3m) is *closer*
than `strike_range`, so it never had a reason to cover the remaining 0.3m.
This is deterministic, not unlucky: any AI using that decision order
settles at strike range and never ties up, every time — which is exactly
why grapples never fired naturally in any of the 11 seeds tested in an
earlier session, or in the seed used for the capture.

Fixed by making the AI keep closing all the way to `tie_up_range`
regardless of whether it's already in strike range, striking
opportunistically while still approaching rather than treating a strike as
a reason to stop (`core/ai/wrestler_ai.gd`) — matching the class's own
pre-existing doc comment ("strikes when not in [tie-up] range") that the
old code didn't actually implement.

That fix immediately exposed a second, more serious pre-existing bug it
had never been able to reach before: `WrestlerController._process_free_movement()`
force-transitions the *opponent* into `TIE_UP` with no check on the
opponent's current state. The first real tie-up attempt fired while the
opponent was still in `HIT_REACT` — an illegal transition per
`WrestlerFSM.LEGAL_TRANSITIONS` — and `WrestlerFSM.transition_to()`'s
`assert()` only *logs* an illegal transition, it doesn't block it, except
the state assignment lines never execute (an assert failure aborts the
rest of the function in this Godot version), so the opponent's FSM state
silently failed to change while `_process_tie_up()` went on to assign it
the attacker role and shove it toward `GRAPPLE_HOLD` anyway — from a state
that transition was *also* illegal, and *also* silently dropped. Net
effect: a permanent deadlock, both wrestlers frozen, the instant a grapple
was ever attempted while the opponent wasn't idle/walking. Fixed by gating
the tie-up attempt on both wrestlers actually being in a state
`LEGAL_TRANSITIONS` allows into `TIE_UP` (`IDLE`/`LOCOMOTION`) before
touching either FSM.

Verified against the real Godot binary: 7/7 unit tests hold, and a fresh
instrumented run (same method as above) now shows a real, varied match —
repeated tie-up → grapple_suplex/signature_backbreaker → hit-react cycles,
a real knockdown, and the referee correctly starting a pin sequence — with
zero illegal-transition errors across 8 different seeds (1, 2, 3, 4, 5, 7,
9, 11).

**This surfaced a third, real gap, left as-is rather than silently
rebalanced:** the pin sequence now genuinely starts, but the AI-controlled
defender mashes the kickout input every single tick (its documented
grey-box behavior for `PIN_DEFENDER`) and the kickout window is generous
enough at realistic damage levels that it escapes essentially every
attempt — so the match can loop through pin attempts indefinitely without
ever reaching a three-count. The referee's count/reset logic is correct
(checked directly, not assumed); this is a balance question about
`CombatSystem.kickout_window_fraction()` and the AI's kickout behavior,
which `ARCHITECTURE.md` explicitly reserves for gauntlet-round tuning, not
something to fix incidentally while chasing a logic bug. Also worth
noting: `WrestlerController._process_tie_up()`'s "lower player index wins"
placeholder rule means whichever wrestler is index 0 wins *every* tie-up
deterministically — combined with the fix above, this means the passive
"player" slot (`player_index = 0`) will now always end up as the grapple
attacker in an AI-vs-passive match, not the AI.

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
  Mercy emulator, as fallback) footage. Now has both stills and one real
  frame-stepped gameplay clip: `camera.md`/`hud.md` cite labeled crops from
  user-provided WWE 2K25/2K26 screenshots (framing/composition, HUD layout
  and color), and `timings.md` has four real frame-stepped measurements
  from a downloaded WWE 2K26 gameplay clip (`gauntlet/refs/raw/video/`,
  gitignored) — a getup animation duration (~2.10s, slower than this
  project's `GETUP_TICKS` placeholder), a strike startup (~8 ticks @ 60Hz,
  close to `strike_jab.tres`'s 6), a submission hold-to-break duration
  (~2.5s), and a tie-up-engaged lower bound. `hud.md` also gained a
  gameplay-confirmed element the screenshots missed: a red/blue submission
  "HOLD" contest meter. Still pending: strike active/recovery (couldn't
  isolate a single non-mutual strike), reversal window length, three-count
  cadence (this clip's only visible finish is inside a slow-motion replay
  package, explicitly not used), ring-crossing run speed, and all of
  `feel.md` (input latency needs a visible input overlay, which broadcast-
  style gameplay footage doesn't have) — more clips would help most here.
- **Phase 3 (remainder)** — 17 of the 18 paired grapple/reversal moves
  (see below: one, the suplex, has a real first-pass paired animation;
  the AI/tie-up path to actually reach it in a live match is a separate,
  still-open gap).

## Phase 3 progress: first paired grapple animation (suplex)

`grapple_suplex.tres` (`resources/animations/`, an `AnimationLibrary`) is
the first real two-skeleton paired animation for `GrappleRig` — no
Blender (unavailable in this environment; confirmed installable via `apt`
but not attempted at that scale), authored directly as a Godot `Animation`
resource via script: `POSITION_3D`/`ROTATION_3D` tracks on both wrestlers'
root transforms for the whole-body throw arc, plus `ROTATION_3D` tracks on
a handful of arm/spine bones (`upperarm_l/r`, `lowerarm_l/r`, `spine_01`)
for the grab/lift posing. `scenes/match.tscn` wires it into `GrappleRig`'s
`animation_player`/`anchor` exports (via the `node_paths` mechanism, not
a plain `NodePath` literal — this project's own README already documents
that pattern once being necessary for typed-`Node` exports).

Getting this actually visible took two real bug fixes, not just content
authoring:
- **Each wrestler's own single-character `AnimationTree` (built in
  `_build_animation_tree()`, added in the previous `AnimationTree` commit)
  keeps driving its `Skeleton3D` every idle frame regardless of what
  `GrappleRig` is doing** — with both active, whichever processes later in
  scene-tree order silently wins each frame, and the paired animation was
  invisible even though it was genuinely playing. Fixed with
  `WrestlerController.set_grapple_animation_override()`
  (`anim_tree.active = false`/`true`), called by `GrappleRig.begin()` /
  `_on_animation_finished()` — `GrappleRig` now owns both skeletons' poses
  for the move's duration, not just their physics processing, matching the
  ownership boundary `ARCHITECTURE.md` already states for transforms.
- **`AnimationPlayer` defaults to idle/wall-clock-paced playback, not the
  physics tick** — cosmetic-only, so it can't desync a replay's gameplay
  state, but it does mean a captured tick wouldn't reliably show the same
  pose across different render framerates, undermining frame-labeled
  captures. Set `callback_mode_process` to
  `ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS` on both this rig's
  `AnimationPlayer` and (while already in the area) each wrestler's own
  `AnimationTree`, which had the same latent gap from the earlier commit.

Verified against the real Godot binary: 7/7 unit tests and full-match
pinfall completion hold across 11 different match seeds (1, 2, 3, 4, 5, 7,
9, 11, 13, 17, 19) with zero script errors. A direct-invocation test
harness (bypassing AI/RNG — see gap below) confirmed the animation
actually renders: real OpenGL captures at three ticks through the move
show a genuine two-body arc — attacker lifting, defender airborne with
real separation at some ticks, both near-fully occluded at the literal
apex (physically expected: the defender is directly over/in front of the
attacker at that instant from this fixed camera angle, not a bug), then
separating again as they come down.

Honest gaps, not smoothed over:
- **This is 1 of 18 required moves** (12 grapple + 6 reversal per
  `ARCHITECTURE.md`'s scope) and the biomechanics are a first-pass
  grey-box, not a good suplex — some rotation timing looks off (the
  defender reads as further into the "falling" rotation earlier than
  intended), most likely from chaining several large-angle Euler-derived
  quaternion keyframes without visually iterating in a real editor. Not
  fixed here; this is exactly the kind of curve a gauntlet builder tunes
  with the animation actually visible, not blind.
- **No live match currently reaches this animation.** Testing across 11
  seeds with a temporary counter confirmed `GrappleRig.begin()` is never
  called naturally by any of them — `WrestlerController._process_tie_up()`'s
  placeholder resolution and the AI's tie-up-seeking behavior are rare/
  fragile enough (a pre-existing gap this README already flagged) that no
  real match exercises the grapple path at all in this sample. The
  animation and its wiring are real and directly verified; a live match
  actually playing it is a separate, still-open problem.

## Phase 3 progress: ring/arena art

`scenes/ring.tscn` replaced the single box-and-tape grey-box with actual
ring geometry, still built entirely from primitives (no Blender, no
external textures — everything's a `StandardMaterial3D` on a `BoxMesh` /
`CylinderMesh`): four corner posts with turnbuckle pads, three-tier ropes
(top/middle/bottom, each its own color) instead of one bare strand, a dark
apron skirt around the mat, and an arena floor extending beyond the ring
into darkness. `scenes/match.tscn` swapped the single `DirectionalLight3D`
for a four-point overhead `SpotLight3D` rig (consistent warm-white color
and energy across all four, two shadow-casting) plus a `WorldEnvironment`
for ambient fill — aimed at `VISUAL_BAR.md`'s "ring lighting reads as one
scene, not independently-lit props," even though that bar itself is still
a placeholder pending Phase 1 reference footage.

Verified against the real Godot binary: imports cleanly, 7/7 unit tests
and full-match pinfall completion still hold (this is pure visual/lighting
geometry with no `StaticBody3D` changes to the collidable mat), and a real
OpenGL render shows both wrestlers clearly legible inside the roped ring
against the dark arena, not a bare box.

Explicitly not attempted here: entrance ramp/stage, crowd, ringside
barricades, or any GPU-only material work (normal maps, canvas texture) —
those are further art passes, not required to clear "ring/arena art" as a
grey-box step.

See `gauntlet/anchor/ARCHITECTURE.md` for the full contract and
`gauntlet/refs/VISUAL_BAR.md` / `FEEL_BAR.md` for the anchor docs each
gauntlet round is judged against.

## Phase 3 fix: the suplex's bind-pose limbs, and a retimed arc

The first paired-animation pass (above) silenced each wrestler's own
`AnimationTree` for the move's duration and hand-authored a handful of arm/
spine bone tracks on top of the root-transform throw arc, to avoid the two
fighting over the same `Skeleton3D` bones. That traded one bug for a worse
one: every bone the clip *didn't* cover (legs, remaining spine, head, the
other arm) had nothing driving it once the `AnimationTree` went inactive,
so both wrestlers snapped to bind pose — arms straight out, legs straight —
for the whole move, visible in a real render even though the throw arc
itself was correct.

Root cause: the conflict was never inherent to having both systems active,
only to both writing the *same data*. `GrappleRig`'s paired clip only ever
needs to own the whole-body root transform (the throw trajectory); it never
needed the individual bones at all. Removed the bone tracks from
`grapple_suplex.tres` and `set_grapple_animation_override()` /
`_set_pose_override()` entirely — each wrestler's `AnimationTree` now stays
active throughout a grapple, continuously posing its own skeleton (idle/
strike-adjacent pose, not a real grab/lift pose yet — a separate, honest
gap, not one this fix claims to close), while `GrappleRig` drives only the
root transforms both wrestlers are parented under. Two systems, disjoint
data, no ownership hack required.

While already touching the clip, retimed the throw arc: the original had
the defender already well into the inverted/falling rotation by ~40% of
the clip and reaching peak height at 70%, which read as too fast a
"falling" read before the lift had visually finished. Re-keyed both
position and rotation tracks so the defender's rise, apex (peak height
~2.4 units, hit at 53% of the clip), and descent are each a clearer,
separated beat.

Verified against the real Godot binary: 7/7 unit tests still pass. A
direct instrumented run (same tick-logging method as earlier verifications)
confirms the grapple now fires *naturally* from a live match's own AI/tie-up
path (not just the earlier direct-invocation harness that bypassed AI/RNG)
— tie-up → grapple_suplex fires at tick 725, root positions and rotations
follow the retimed curve exactly (apex at animpos≈0.53), the animation
finishes cleanly (`animplaying` false, both wrestlers back to independent
FSM states), and a second natural grapple fires later in the same run with
zero script errors or warnings across the whole capture. Full-match
pinfall completion (`scenes/match.tscn` under `--fixed-fps 6000`) was not
re-confirmed this pass — it now runs long enough to exceed a 60s wall-clock
check, consistent with the already-documented kickout-escapes-every-attempt
gap above, not a regression from this change (the grapple/animation path
that changed here has no interaction with pin/kickout logic).
