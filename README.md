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
- Irish whip, running attacks, and reversals have FSM states but aren't yet
  driven by the referee or AI. Submission was in the same boat as of this
  writing, but is now wired end to end (see "Feature: wire submissions into
  the referee and AI" below) — pin/kickout and submission/tap-out are both
  real, reachable win-condition paths now.
- Tie-up resolution was a placeholder rule (lower player index wins) as of
  this writing; now a real mash contest — see "Feature: fix the tie-up
  resolution placeholder" below.

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
- **Phase 3 (remainder)** — 16 of the 18 paired grapple/reversal moves
  (see below: three so far — suplex, signature backbreaker, finisher
  piledriver — have real first-pass paired animations; the AI/tie-up path
  to actually reach them in a live match is a separate,
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

## Phase 3 progress: two more paired moves (backbreaker, piledriver)

`resources/animations/paired_moves.tres` replaces `grapple_suplex.tres` as
`GrappleRig`'s single `AnimationLibrary` — same "" (default) library key so
`animation_player.has_animation(move.animation_pair_id)` keeps working by
bare name, now holding three clips instead of one: `grapple_suplex`
(unchanged), and two new ones, `signature_backbreaker` and
`finisher_piledriver`, filling in the animations for `MoveDef` resources
that already existed and were already wired into `match.tscn`'s
`signature_move`/`finisher_move` exports but had no clip to play (falling
back to `GrappleRig`'s grey-box timer path — no visible animation).
`finisher_move` itself wasn't wired into `match.tscn` at all before this;
it is now, on both wrestlers. **2 of 18 required moves now have real
animations, up from 1.**

Built with the same script-authored, root-transforms-only approach as the
suplex (`../WrestlerA`/`../WrestlerB` `POSITION_3D`/`ROTATION_3D` tracks
only, no bone tracks — see `grapple_rig.gd`'s class doc for why bone
tracks on a paired clip are a trap). Backbreaker: pulled in, hoisted across
a raised knee (peak height ~1.55, well below the suplex's ~2.4 overhead
hold — this move never lifts higher than shoulder height), arched, then
lowered flat onto the mat past the attacker's far side. Piledriver: pulled
in, hoisted fully inverted (peak height ~2.2, same order as the suplex's
overhead hold), driven down between the attacker's legs, then rolled out
flat.

**A real geometry bug, caught and fixed before shipping, not smoothed
over:** the root sits at the wrestler's feet, so a rotated body's far end
(the head, `BODY_HEIGHT` = 1.8 units away) sits at world height `root_y +
BODY_HEIGHT * cos(flip)` — whenever that's negative, the far end is below
the mat, not just clipped into it but fully invisible (backface-culled by
the floor). A first-draft backbreaker curve dropped the root height to
near-zero *before* its rotation had finished swinging through the
vertical-inverted range, so most of the defender's body computed to a
negative world height every frame during the back half of the drop — direct
OpenGL captures (`xvfb-run --rendering-driver opengl3`, a temporary
in-scene harness calling `GrappleRig.begin()` directly, same verification
method as the suplex) showed only the attacker standing alone, with a
single stray limb fragment on the mat where the rest of the body should
have been — not a bind pose this time, a body that had gone almost
entirely below the floor. The piledriver's descent had the identical bug
for the same reason (its own height curve dropped below the clearance
`BODY_HEIGHT * |cos(flip)|` needs at that instant). Fixed by keeping each
move's height key at or above that clearance requirement at every sampled
point — for the backbreaker, by never rotating past ~115° off horizontal
in the first place (it's a knee-height rack, not an overhead hold, so nothing
requires it to swing through a full inversion); for the piledriver, by
matching the suplex's own already-proven height/rotation pairing instead of
inventing a steeper new one. Re-verified with the same direct-capture method
after the fix: both moves now show a fully separated, fully visible
defender at every sampled tick from grab to landing.

Verified against the real Godot binary: 7/7 unit tests still pass with the
new scene wiring (renamed `AnimationLibrary` resource, added `finisher_move`
export on both wrestlers). Direct-invocation OpenGL captures (bypassing
AI/RNG, same method noted above) confirm both new clips render correctly
mid-move — no bind-pose limbs, no invisible/underground body parts — at
15%, 50%, and 85% through each animation.

Honest gaps, not smoothed over:
- **This is 2 more of 18 required moves** (12 grapple + 6 reversal per
  `ARCHITECTURE.md`'s scope), same first-pass grey-box caveat as the
  suplex: biomechanics are plausible, not motion-captured, and a gauntlet
  builder should expect to retune the curves with the animation visible,
  not blind.
- **Not directly confirmed firing via their own momentum-gated path in a
  live match** (i.e. specifically observed as the clip `GrappleRig` played,
  not just that damage/momentum totals climbed) — verified here only via
  direct `GrappleRig.begin()` invocation. The follow-up fix below confirms
  grapples in general now fire rapidly and reliably in a live match and
  push a real match all the way to a knockdown/pin, which makes it very
  likely `can_signature()`/`can_finisher()` do eventually pick these over
  the base grapple (momentum passes both the 60 and 100 thresholds within
  the first several landed grapples at `grapple_suplex.tres`'s own 18
  momentum-gain per hit), but that specific selection wasn't independently
  logged and confirmed this pass.
- **What happens in the few ticks right after each animation ends, once
  `GrappleRig` hands control back to each `WrestlerController`'s own
  physics, was not verified end-to-end** — only checked here via the same
  direct-invocation harness that bypasses the controller's own
  `_resolve_grapple_move()` FSM handoff, so it doesn't exercise the real
  post-move transition path. The suplex's existing live-match path (once
  it fires) already goes through that handoff correctly; these two moves
  should too by the same wiring, but it wasn't independently re-confirmed
  this pass.

## Bugfix: every landed grapple dealt zero damage

Went looking for why a live match still didn't seem to progress even after
the AI/tie-up fix above, expecting to find grapples firing rarely. An
instrumented run of the real match scene (state transitions + `_pending_hits`
size + total damage, logged every tick — not a direct `GrappleRig.begin()`
harness this time, the ordinary AI/physics path) found the opposite: the AI
reaches a tie-up almost immediately (~t44) and a grapple resolves roughly
every 65 ticks after that, forever — 3600 ticks logged, seed after seed,
without a single knockdown. The tie-up→grapple cadence itself was never the
problem.

The actual bug, confirmed by logging `_pending_hits` and `combat.total_damage()`
side by side: `WrestlerController._resolve_grapple_move()` puts the defender
into `MOVE_EXEC` (required — `GRAPPLE_HOLD` can't legally reach `HIT_REACT`/
`DOWN` directly per `WrestlerFSM.LEGAL_TRANSITIONS`), then applies the hit
through the same deferred `_pending_hits` queue strikes use.
`MatchReferee._resolve_pending_hits()` checks the *target's own current
state* against `UNHITTABLE_STATES` before applying damage — and `MOVE_EXEC`
is on that list, for an unrelated reason (stopping a wrestler already
mid-strike-startup from taking a second simultaneous hit same-tick). Since
the defender is sitting in the `MOVE_EXEC` we *just put them in*, every
queued grapple hit was silently dropped the instant it was queued: logged
data showed `b_pending` cycling `1 -> 0` every cycle while `b_dmg` stayed
`0.0` for the full 3600-tick run. With grapple damage never landing, and the
AI permanently within `tie_up_range` after the first successful tie-up (so
`WrestlerAI` never has a distance-triggered reason to strike again either —
see its own `distance > tie_up_range` gate), nothing after the first tie-up
could ever push total damage toward the 200 needed for `_go_down()`. Every
match was a closed loop by design of the two fixes interacting, not a rare
edge case.

Fixed by having `_resolve_grapple_move()` apply the defender's damage
directly (`opponent.combat.apply_damage(move)`) and drive the
`HIT_REACT`/`DOWN` follow-up itself, instead of routing through
`_pending_hits`. That queue exists specifically so `MatchReferee` can
arbitrate two wrestlers landing hits on each other in the *same* tick
regardless of scene-tree node order (see its own doc comment) — a grapple
has exactly one deterministic attacker already fully resolved by the time
`_resolve_grapple_move()` runs, so there's no ordering race to arbitrate and
no reason to pay the `UNHITTABLE_STATES` cost that queue carries.

Verified against the real Godot binary: 7/7 unit tests still pass. Re-ran
the same instrumented method: `b_dmg` now climbs `28.0 -> 56.0 -> 84.0 ->
112.0` across four consecutive landed grapples (28 = `grapple_suplex.tres`'s
`damage_head + damage_torso + damage_arms + damage_legs`, exactly as
expected), with the defender correctly cycling `MOVE_EXEC -> HIT_REACT ->
IDLE` each time instead of snapping straight back to `IDLE` untouched.

**Follow-up: confirmed end-to-end, not just arithmetically likely.** The
first pass at a longer run timed out (real-wall-clock-paced headless
physics makes a 90-second match's worth of ticks slow to simulate without
`--fixed-fps`) — re-ran the same instrumented match with `--fixed-fps 600`,
which decouples physics from wall-clock pacing (5 seeds x 90 game-seconds
completed in ~16 real seconds). **All 5 seeds (1-5)** reached a real
knockdown and a correctly-started pin: `b_dmg` crossed the 200 threshold
(204.0 in every seed tested) and both wrestlers landed in
`PIN_ATTACKER`/`PIN_DEFENDER`, not stuck looping. None reached a full
pinfall *win* inside the 90s window — expected, not a new gap: this is the
already-documented, separately-scoped kickout-escapes-nearly-every-attempt
balance issue (`ARCHITECTURE.md` reserves that kind of tuning for gauntlet
rounds), not something this fix touches.

**Also worth flagging:** an earlier commit's own verification note (the
"AI never actually grappled" bugfix above) claims a confirmed "real
knockdown" across 8 seeds. Given `UNHITTABLE_STATES` (with `MOVE_EXEC` on
it) predates that commit — `git log -S` traces it to `812c7d3`, well before
`7072628` — that specific knockdown claim looks hard to reconcile with what
this session found: no code path available at that time could have pushed
damage to 200 through grapples (they were broken the same way), and reaching
it through strikes alone would need ~40 landed jabs at 5 damage each, far
more than a short pre-tie-up approach produces. Left as-is rather than
edited after the fact — flagging the discrepancy here instead, since this
session's own re-verification is what should be trusted going forward, not
retroactively rewriting what an earlier one claimed.

## Bugfix: kickout escaped nearly every pin attempt

Picked up the balance gap the previous entry deliberately left alone: once a
pin genuinely starts, the match should sometimes end in a real pinfall. The
prior 5-seed `--fixed-fps 600` run confirmed pins were starting correctly but
never once closed out within 90 seconds.

Root cause, found by reading the actual mechanics rather than guessing at
numbers: `PinMinigame` (`game/core/minigames/pin_minigame.gd`) is a timed
fill-meter — a marker sweeps `[0,1]` twice across the 180-tick pin
(`MatchReferee.PIN_COUNT_TICKS`), and the defender needed 30 accumulated
ticks of "input held AND marker inside the target window" to escape. That
was designed assuming a press-limited, human-speed input signal (a human's
`strike` only reads `true` on the exact tick of a *new* press —
`Input.is_action_just_pressed`). But `WrestlerAI.poll_input()`
(`game/core/ai/wrestler_ai.gd:24-27`) returned a literal `true` held for
*every* tick of `PIN_DEFENDER`, with no reaction delay and no re-press
requirement — the AI was never actually playing the timing minigame, just
banking every qualifying tick the marker happened to sweep through. Doing
the math on what a correctly rate-limited input could achieve against a
30-tick threshold showed it would need 20-33 presses/second sustained for
3 seconds — not achievable by a human or a reasonable AI stand-in, so this
wasn't a single-file fix: the input model and the threshold were two
independently-authored pieces that had never actually been exercised
together.

Fixed both sides together:
- `WrestlerAI` now presses like a human would: a `kickout_reaction_ticks`
  delay (10 ticks) before the first attempt, then re-presses no faster than
  `kickout_press_interval_ticks` apart (5 ticks), and only when the marker
  is actually in the target window at that tick — the same information a
  human sees on the minigame's own marker/target-zone UI, not omniscience.
  No RNG involved, so `ReplaySystem`/capture-harness determinism is
  unaffected.
- `PinMinigame.PROGRESS_THRESHOLD` dropped from 30 to 12 — calibrated
  against the rate-limited policy above, not picked in isolation.

Verified two ways. A new `game/tests/test_pin_minigame_kickout.gd` (5 new
unit tests, 12/12 total passing alongside the existing suite) drives
`WrestlerAI._should_press_kickout()` directly against `PinMinigame.tick()`
across the window fractions `kickout_window_fraction()` actually produces:
a badly damaged defender (window 0.05) essentially never escapes, a
high-momentum-attacker pin (window 0.3) rarely does, and the band
0.3→0.35→0.4→0.45→0.5 is neither flat-0% nor flat-100% and never gets
*easier* as the window narrows — the direct regression check for the
original bug, which made every window in that band ~100%. A separate test
locks in the actual mechanism fix: presses are provably rate-limited, never
held every tick.

Then a live-match probe (`--fixed-fps 600`, same wrapper-scene pattern as
the prior entry, extended to a 300s-per-seed budget) against real
`match.tscn`, all 5 seeds (1-5): **every seed now reaches a genuine pinfall
win** (`match_won` fires with `method="pinfall"`), something no seed did
before this fix at any tested duration. Per-attempt logs show plausible,
non-degenerate press counts (11-12 out of a 180-tick pin, never 0 and never
~180), confirming the AI is actually playing the rate-limited minigame
rather than trivially winning or losing it.

**Follow-up: the flat-0.40-forever gap noted above was a second, separate
bug — not a deeper tuning question.** Traced it by logging every FSM state
change around a pin cycle instead of guessing: on a kickout, `_end_pin()`
resets the defender straight to `DOWN` and the attacker straight to `IDLE`
— and since they're still standing right next to each other from the pin
that just ended, `MatchReferee._check_for_cover()` (which only checks
current state and distance, nothing else) re-matched and started a *new*
pin on the very next physics tick, every time:
```
t803 A: PIN_ATTACKER -> IDLE        B: PIN_DEFENDER -> DOWN   (kickout succeeds)
t804 A: IDLE -> PIN_ATTACKER        B: DOWN -> PIN_DEFENDER   (pin_started again — same numbers)
```
The defender's `GETUP_TICKS` timer got set but never once ran down —
`DOWN`'s own per-tick countdown (`_process_down()`) never got a second tick
before the referee already restarted the pin — and the attacker's AI never
got a chance to throw a new strike or grapple either, since its own
`poll_input()` sees the opponent as still `DOWN` and just walks in for
another cover. So `combat.total_damage()` and attacker `combat.momentum`
were frozen at whatever they were at the *original* knockdown for the rest
of the match: not a saturation or formula issue, a state-machine one — the
`DOWN -> GETUP -> IDLE` recovery sequence those constants clearly intend
was being skipped entirely after every kickout.

Fixed with a `_cover_eligible` flag on `WrestlerController` (default
`true`, so a genuine fresh knockdown is still immediately coverable, which
is correct): `MatchReferee._end_pin()` clears it on a kickout, and
`_process_timed_state()` restores it once the wrestler actually reaches
`IDLE` again (the shared handler for both `GETUP -> IDLE` and
`HIT_REACT`/`STUNNED -> IDLE`, harmless to set unconditionally there since
it's already `true` in the latter two cases). `_check_for_cover()` now
requires it alongside its existing checks.

Re-ran the same live 5-seed probe after this fix: the window now genuinely
moves between attempts instead of repeating —
`t648 dmg=204.0 window=0.396 ... -> KICKOUT` then
`t991 dmg=218.0 window=0.335 ... -> PINFALL`, in every one of the 5 seeds —
confirming a real hit lands (`dmg` 204.0 → 218.0) and narrows the window in
the gap between pin attempts, exactly as `kickout_window_fraction()`
intends. All 5 matches now resolve in **2 pin attempts** instead of the
previous run's 2-88, and finish by roughly t1150-1172 instead of dragging
out to t7000-14700 — a real near-fall followed by a real finish, not a
long coin-flip grind. Full unit suite (12/12, including the new kickout
tests above) still passes unmodified; this fix touches
`match_referee.gd`/`wrestler_controller.gd` state handling only, not
`combat_system.gd`'s formula or the kickout-minigame calibration.

## Feature: wire submissions into the referee and AI

Submission code has existed for a while — `WrestlerFSM.State.SUBMISSION_ATTACKER`/
`SUBMISSION_DEFENDER`, `SubmissionMinigame` (a deterministic dual-ring
break-point race), `CombatSystem.submission_break_rate()`, and
`WrestlerController.begin_submission()` — but nothing ever called it.
`MatchReferee`'s own doc comment claimed it drove "pin or submission
resolution"; in reality it had zero references to submission anywhere.
Previously logged as a known Phase 2 gap: "submissions have FSM states and a
minigame, but aren't yet driven by the referee or AI." This pass wires it up
end to end and, in the process, found and fixed two real bugs verification
turned up rather than guessed at.

**Bug 1 — dead on arrival:** `WrestlerFSM.LEGAL_TRANSITIONS` had no entry
transitioning *into* `SUBMISSION_ATTACKER` from any state. The first time
anything called `begin_submission()`, its own `fsm.transition_to(SUBMISSION_ATTACKER)`
would have hit the `assert()` in `WrestlerFSM.transition_to()`. Never caught
because nothing had ever exercised the path. Fixed by adding
`SUBMISSION_ATTACKER` to `LEGAL_TRANSITIONS[IDLE]` and `[LOCOMOTION]`, in the
same place `PIN_ATTACKER` already sits in both.

**Bug 2 — a guaranteed-loss race, same category as the kickout bug above:**
`submission_break_rate()`'s `limb_factor` is `1.0 + limb_damage/100`, so the
attacker's rate is always >= 1.0 even on a fully undamaged limb. The
existing `defender_rate := 0.9` constant loses that race unconditionally —
attacker reaches the break point at `100/1.0 = 100` ticks worst case,
defender at `100/0.9 = 111` — the attacker always arrives first, regardless
of which limb or how damaged it was. Deciding *when* to attempt a submission
also needed a rule: added `CombatSystem.most_damaged_limb()` and a
`SUBMISSION_LIMB_THRESHOLD = 70` (70% of `MAX_LIMB_DAMAGE`) gate in
`MatchReferee` — a downed opponent's most-damaged limb crossing that
threshold triggers a submission attempt on that limb instead of a pin. That
gate means the attacker's *realistic* rate at the moment a submission can
even start is never below `1.0 + 0.70 = 1.7`, so `defender_rate` was
retuned to `1.8` — inside the actual reachable band, not the theoretical one
— to make it a genuine contest instead of another guaranteed one-way race.

New `test_submission_minigame.gd` (4 cases) confirms the retuned rates
produce a real contest across that band (defender favored at the threshold
floor, attacker favored at a fully-capped limb, not flat one way across
it) and that the defender's hold input is load-bearing (never holding never
escapes). `CombatSystem.most_damaged_limb()` got its own 2 cases in
`test_combat_system.gd`. Full suite: 18/18, 0 errors, 0 failures.

**Bug 3, caught only by the live probe, not the unit tests:** the unit
tests exercise `SubmissionMinigame`'s rate math directly and passed cleanly
— but the first live 5-seed `--fixed-fps 600` run showed every single
submission attempt ending in an escape, regardless of how damaged the
targeted limb actually was. Root cause: `begin_submission()`'s
`combat.submission_break_rate(target_limb)` reads `combat` unqualified,
which is `self` — the **attacker's own** `CombatSystem`, not the
defender's. The attacker's own limb is rarely damaged on the same limb it's
targeting, so `attacker_rate` was silently floored near 1.0 every time,
regardless of the defender's real damage. Fixed by calling it on
`defender.combat` instead. This is exactly why this project verifies
against the real Godot binary rather than trusting a plan and unit tests
alone — this bug lived entirely in *which instance* a correct-looking method
call was made on, invisible to both.

Live 5-seed verification after the fix: no illegal-FSM-transition
assertions fire, and every seed reaches a genuine submission win
(`Match won by WrestlerA via submission`) around t699. Honest gap, not
smoothed over: all 5 seeds play out identically, and pin never triggers in
this default match. Both are explained, not mysterious — this project's
tie-up resolution is a known placeholder ("lower player index always
wins," already logged as a Phase 2 gap), so the same wrestler is
deterministically the grapple attacker every match regardless of which
side is AI-controlled; and the current 4-move default roster (jab, suplex,
backbreaker, piledriver) damages torso hardest across the board, so torso
reliably saturates to its own 100-damage cap before total damage ever
reaches the 200 needed for a knockdown — meaning `SUBMISSION_LIMB_THRESHOLD`
is always crossed at torso's absolute ceiling in this specific roster, not
at some mid-range value, and `SubmissionMinigame` has no RNG of its own to
vary that fixed outcome. To confirm the pin branch (unchanged by this
pass, just moved into the same decision function,
`_check_for_downed_opponent_action()`) was not broken by the refactor, it
was independently re-verified with `SUBMISSION_LIMB_THRESHOLD` temporarily
forced unreachable: all 5 seeds still reach a real pinfall, at the same
`dmg=204.0 -> 218.0` progression already confirmed above, then reverted.
Whether submissions should be reachable at less-than-fully-capped limb
damage in real play is a moveset-tuning question (`MoveDef` damage ratios
across limbs, `ARCHITECTURE.md`'s designated tuning surface), not a code
question — left as an open gauntlet-round gap alongside
`SUBMISSION_LIMB_THRESHOLD`/`defender_rate` themselves, both still
first-pass values.

## Feature: fix the tie-up resolution placeholder

`WrestlerController._process_tie_up()` resolved every single tie-up with a
hardcoded rule: "whichever wrestler entered the tie-up first (lower
player_index...) wins" — in practice `WrestlerA` won every tie-up in the
game, regardless of anything either wrestler did. Already a named Phase 2
gap, and it became directly visible this session: the submission-wiring
live probe above showed all 5 seeds playing out byte-identically, entirely
because of this rule.

The placeholder's own comment already named the intended replacement — "a
stand-in for a reaction-time contest" — and `gauntlet/refs/timings.md`'s
tie-up section backs that up: the reference footage shows a "grapple-contest
reticle UI visible continuously" for at least 1.07s before the clip cuts
away unresolved (a lower bound only, explicitly caveated as not a full
measurement). So the real reference game treats this as an active,
on-screen contest, not an instant lookup.

Built a real interactive mash contest: new `TieUpMinigame` — unlike
`PinMinigame`/`SubmissionMinigame` (each has one automatic side and one
mashing/holding side), this one is symmetric: **both** wrestlers press
`grapple`, and whichever accumulates `PROGRESS_THRESHOLD` (10) qualifying
presses first becomes the grapple attacker. Since it's a shared two-party
contest with no natural single owner, resolution moved off the individual
wrestlers' own `_physics_process()` (which only worked by both wrestlers'
identical timers happening to stay in lockstep) and into `MatchReferee`,
matching the same pattern already established for pin/submission
(`_tick_pin()`/`_tick_submission()`) — both sides' input is read from one
shared tick, not two independent ones. `WrestlerAI` got a rate-limited mash
policy (`_should_press_tie_up()`, same reaction-delay/press-interval shape
as the kickout one) so it presses `grapple` at a human-plausible rate
during the contest, not held every tick.

New `test_tie_up_minigame.gd` (3 cases) confirms the more-frequent presser
wins, a single press alone isn't enough, and the contest is fully
deterministic (no RNG anywhere in `TieUpMinigame` — a pure function of both
sides' press ticks). Full suite: 21/21, 0 errors, 0 failures.

Live 5-seed `--fixed-fps 600` verification: no illegal-FSM-transition
assertions anywhere in any of the 5 runs. In the project's default match
config (`WrestlerA` passive, `WrestlerB` AI-controlled — the same config
every live probe this session has used), `WrestlerB` now wins every tie-up
(`a_progress=0.0 b_progress=10.0`, resolved at tick 83, ~1.4s) —
**flipping** the old bug (a fixed, unconditional `WrestlerA` win) into a
*causally real* one: whoever actually contests wins, and here that's the
only side that ever presses anything. Matches still resolve correctly
end-to-end afterward (grapple → damage → eventual submission win, same
shape as the prior section, just with the winning side now flipped to
match who's actually fighting). Honest note, not smoothed over: this
config still produces identical results across all 5 seeds, for the same
reason already documented above — a fully passive wrestler and a
deterministic AI leave nothing for `match_seed` to actually vary here.
`TieUpMinigame`'s own unit tests (above) already confirm the mechanism
supports either side winning, symmetrically; the live match's one-sided
result is a property of this specific default config, not of the fix.
`PROGRESS_THRESHOLD`, `tie_up_reaction_ticks`, and
`tie_up_press_interval_ticks` are all first-pass values, open to later
gauntlet-round retuning like the kickout/submission constants before them.
