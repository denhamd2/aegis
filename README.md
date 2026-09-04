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
- Strikes now read and connect properly, but how *often* a wrestler should
  strike rather than grapple traces to no reference measurement — see "Fix:
  strikes that connected with air, and the kick the rig didn't have" below.
  The kick is also a posed leg on a borrowed stance, not an animation
  anyone authored.
- Both finishes are reachable now and the three-count follows the measured
  cadence — see "Fix: the match could only end one way" below. What is not
  settled is the *split*: how often a real match should end by pinfall
  rather than submission traces to no measurement, so the constants that
  decide it were chosen to make both happen, not to match anything.
- Not played by a human yet — verification above is scripted/AI-vs-passive
  simulation, not a playtest with a gamepad. Whether the match *feels*
  right is unconfirmed regardless of whether it mechanically completes.
- Two identical AI opponents (same stats, same seed, no tie-breaker) used to
  be flagged as a mutual-knockout deadlock risk; investigating it found the
  real mechanism was different (a scene-tree-order bug in tie-up entry, not
  a hang) — fixed, see "Fix: AI-vs-AI tie-ups were decided by scene order,
  not contest" below.
- `GrappleRig` now has all 18 paired moves `ARCHITECTURE.md` scopes (12
  grapple + 6 reversal), each with a root trajectory and both role pose
  clips, reachable through per-tier seeded move pools — see "Feature: the
  moveset ARCHITECTURE.md scopes, all 18 of it" below. Nothing falls back
  to the grey-box timer any more. They are authored but **not tuned**:
  frame data, damage and momentum are internally consistent by tier and
  trace to no reference measurement, which under `ARCHITECTURE.md`'s
  reference-driven-tuning rule means none of the numbers may be defended
  as "how it should feel" yet.
- Irish whip, running attacks, and reversals had FSM states but nothing
  drove them, as of this writing — now wired end to end with real rope
  collision physics, see "Feature: irish whip, running attacks, and a
  hidden reversal-window consumer" below. Submission was in the same boat
  earlier and is also now wired (see "Feature: wire submissions into the
  referee and AI" below) — pin/kickout, submission/tap-out, and the whip
  loop are all real, reachable paths now. The AI didn't *initiate* a whip
  or attempt a reversal itself when the base feature shipped; it now does
  both (see "Feature: AI whip and reversal decisions" below) — first-pass,
  seeded, momentum-gated and reaction-delay-gated respectively, not tuned
  against any reference data (`gauntlet/refs/timings.md` marks both
  reversal-window length and run speed "pending").
- Tie-up resolution was a placeholder rule (lower player index wins) as of
  this writing; now a real mash contest — see "Feature: fix the tie-up
  resolution placeholder" below.
- Grapples used to be posed with borrowed single-character clips (attacker
  lifts, defender goes limp) over paired clips that animated only the two
  root transforms. The five existing paired moves now have authored,
  per-role, full-body bone tracks generated by a checked-in pose-stitching
  pipeline — see "Feature: real bone-level paired performance, stitched from
  the clip library" below, which also covers the two live bugs it exposed
  (grip IK frozen for every paired move; thrown bodies ending half a metre
  under the mat). The breadth followed in "Feature: the moveset
  ARCHITECTURE.md scopes, all 18 of it".

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

## Fix: AI-vs-AI tie-ups were decided by scene order, not contest

README's own "Known Phase 2 gaps" named a real risk: "two identical AI
opponents, same stats, same seed, no tie-breaker, can deadlock in a
mutual-knockout loop." Testing it directly (both wrestlers set `is_ai =
true`, live 5-seed `--fixed-fps 600` probe against real `match.tscn`) found
matches do complete every time — no hang — but every single tie-up was won
by the same wrestler (`WrestlerB`), every seed, by exactly one tick
(`TieUpMinigame` progress at resolution was always `(a=9.0, b=10.0)`, never
closer). Not a coincidence: `WrestlerController._process_free_movement()`
used to force the *opponent* directly into `TIE_UP` via
`opponent.fsm.transition_to(...)`, called from whichever wrestler's own
`_physics_process()` happens to run first in the scene tree (always
`WrestlerA`, first child under `Match`). The forced wrestler's FSM state
changes mid-tick, before its own `_physics_process()` has run — so if it's
later in the scene tree, its `WrestlerAI.poll_input()` sees `TIE_UP`
already in effect and starts counting mash ticks one tick early, every
time. With two AI instances using identical, jitter-free mash timing (no
RNG in that policy, by design), that one-tick head start was the entire
contest.

Fixed in two parts, matching the pattern already used for pin/submission
entry:
- **Entry moved into `MatchReferee`.** Wrestlers now just record intent
  (`_wants_tie_up_this_tick`, mirroring `_kickout_input_this_tick`); a new
  `MatchReferee._try_start_tie_up()` — running after both wrestlers'
  `_physics_process()` for the tick, same reasoning already established for
  `_resolve_pending_hits()`'s deferred-hit queue — decides when to actually
  transition both wrestlers into `TIE_UP`, uniformly, on a tick where
  neither side has already acted. This also keeps the illegal-transition
  guard the old inline version had (both wrestlers must already be in a
  state `WrestlerFSM.LEGAL_TRANSITIONS` allows into `TIE_UP`), just
  relocated to the new call site.
- **`WrestlerAI.setup_jitter(match_seed, player_index)`** applies a small
  (±2 tick), deterministic per-instance offset to `tie_up_reaction_ticks`/
  `tie_up_press_interval_ticks`, derived from `(match_seed, player_index)` —
  not per-tick RNG, so `ReplaySystem` determinism is unaffected. Wired in by
  `match_setup.gd` for any wrestler with `is_ai = true`. Without it, two
  identical AI configs tie on literally every single tie-up even after the
  ordering fix above (confirmed: reran the fix with jitter disabled first,
  saw exact `a_prog == b_prog` ties every time). With it, two AI opponents
  now genuinely diverge per match seed.
- **Explicit, seeded tie-break** (`MatchReferee._break_tie_up_tie()`) for
  the case both sides still cross `PROGRESS_THRESHOLD` on the exact same
  tick — now a real, reachable case rather than a hypothetical, since
  jitter narrows but doesn't eliminate it. Resolved with a seeded coin flip
  (`match_seed` + the current tie-up's tick count), not by which branch an
  `if`/`elif` happens to check first — that was the original placeholder
  bug's own shape, and leaving it implicit here would have just relocated
  it rather than fixed it.

New tests: `test_wrestler_ai_jitter.gd` (3 cases — jitter is deterministic
per `(match_seed, player_index)`, two different `player_index` values
diverge across a range of seeds, jitter never produces a non-positive
interval) and `test_match_referee_tie_break.gd` (2 cases — the tie-break is
deterministic per `(match_seed, tick)`, and both wrestlers can win it across
a range of seeds). Full suite: 26/26, 0 errors, 0 failures.

Live verification, real Godot binary, both wrestlers `is_ai = true`, 5
distinct match seeds (previously-undiscovered bug: the existing probe
pattern's `-- --match-seed=N` CLI flag was never actually read by
`match_setup.gd`, so every earlier "multi-seed" run in this session,
including the original tie-up fix above, silently ran the same seed=1 five
times — harmless for those fixes since they weren't testing seed-driven
variance, but worth naming since it's exactly the kind of stale assumption
this fix depends on getting right; the wrapper `.tscn` now sets `match_seed`
directly as a scene-property override instead):
- All 5 seeds resolved (no timeout, no illegal-FSM-transition assertions),
  with genuinely different match lengths (1107–1226 ticks) — no longer
  byte-identical.
- The winner varies by seed: `WrestlerB` won 3/5, `WrestlerA` won 2/5 — the
  direct confirmation the outcome is no longer pinned to one side by scene
  order.
- Confirmed the default human-vs-AI `match.tscn` config (only `WrestlerB` is
  AI) still resolves correctly after the refactor — unaffected by this fix
  in practice (a passive player never presses grapple), but the entry path
  it depends on changed, so this was checked directly rather than assumed.

`TIE_UP_JITTER_TICKS` (±2) is a first-pass value, same caveat as the other
tuning constants above — open to retuning once this matters for real
gauntlet-round balance rather than just breaking a deterministic tie.

## Feature: a power-tier grapple move, and a hidden attacker/defender bug

Continuing the "one more paired move" pattern from the backbreaker/
piledriver pass: the existing three paired moves (`grapple_suplex`,
`signature_backbreaker`, `finisher_piledriver`) turned out not to be
interchangeable options but a strict momentum-gated priority ladder inside
`WrestlerController._process_grapple_hold()` — `finisher_move` if
`combat.can_finisher()` (momentum >= 100), else `signature_move` if
`combat.can_signature()` (momentum >= 60), else the ungated base
`grapple_move`. There was no rung between the base grapple and signature
tiers, so a fourth `grapple_*.tres` file on its own would have been
unreachable content, the same "no live match currently reaches this"
gap already flagged for the original suplex before referee wiring fixed
it. Making a new move actually playable meant extending the ladder, not
just authoring a clip: added `CombatSystem.POWER_THRESHOLD := 30.0` /
`can_power()`, a new `@export var power_move: MoveDef` on
`WrestlerController`, and one more rung in `_process_grapple_hold()`
between the base grapple and signature checks. `power_bodyslam` fills it —
attacker lifts the defender to a shoulder-height carry (peak ~1.25, well
below the suplex's ~2.4 overhead hold or even the backbreaker's ~1.55) and
slams flat. Deliberately kept the swing angle capped at 90° (never
inverted), the same geometry-bug class the backbreaker pass already caught
once (`grapple_rig.gd`'s class doc: a rotated body's far end sits at
`root_y + BODY_HEIGHT * cos(flip)`, negative once flip passes 90°) — capping
the swing avoids it outright rather than tuning around it. Authored the
same script-driven way as the other three (`Quaternion` composition rather
than hand-typed components, to build correct unit quaternions by
construction instead of by arithmetic care), root-transform-only tracks, no
bone tracks.

**A real bug found while verifying it, not specific to this move:**
`GrappleRig`'s paired clips are authored once against fixed node names —
every existing clip's tracks target the literal `../WrestlerA` (always the
grounded/lifting role) and `../WrestlerB` (always the thrown role), not
"attacker"/"defender". A direct-invocation probe running the new move twice
— once with `WrestlerA` as the real attacker, once with `WrestlerB` — found
the unmodified clip always applied the lifter's motion to whichever node is
literally named `WrestlerA`, regardless of who was actually attacking: with
`WrestlerB` as the real attacker, the clip lifted the *attacker* into the
air and left the defender standing on the mat, exactly backwards. This
isn't new to `power_bodyslam` — it's latent in all three prior clips too —
and it's no longer a hypothetical: this session's earlier tie-up fix made
`WrestlerB` (the AI in the default match config) a genuine, reachable
grapple attacker, not just `WrestlerA`.

Fixed in `GrappleRig`: `begin()` now calls `_play_retargeted()`, which
duplicates the clip's `Animation` resource, rewrites its two wrestler
tracks' `NodePath`s to point at the real attacker/defender nodes for this
call (`WrestlerA`-named track → attacker, `WrestlerB`-named track →
defender), swaps the duplicate into the shared `AnimationLibrary` under the
same name for the duration of the move, and restores the original
afterward. Never mutates the original `Animation` in place — it's one
`Resource` instance shared by every match/replay, the same shared-Resource
hazard `MoveDef`'s own doc comment already flags elsewhere in this
codebase. Confirmed fixed via the same direct-invocation probe, both
attacker/defender directions: the lifter's motion now always follows the
real attacker regardless of which physical node that is, with matching
OpenGL-captured poses either way (see `_apply_root_motion()`'s neighboring
code — root motion itself remains a no-op either way, since no
`root_motion_track` is configured on this project's `AnimationPlayer`, an
existing, unrelated detail this fix didn't touch).

Verified against the real Godot binary:
- New `test_grapple_move_selection.gd` (5 cases: each momentum tier boundary
  selects the right move, and a missing `power_move` falls back to the base
  grapple) plus 2 new `can_power()` boundary tests in
  `test_combat_system.gd`. Full suite: 33/33, 0 errors, 0 failures.
- Direct-invocation OpenGL capture (`xvfb-run --rendering-driver opengl3`,
  same method as the suplex/backbreaker/piledriver passes) at 4 ticks
  through the move, both attacker directions: no bind-pose or negative-
  height invisibility bugs, correct lift/carry/slam posing throughout, and
  (after the fix above) motion correctly follows the real attacker either
  way.
- Live 5-seed `--fixed-fps 600` probe against real `match.tscn` (default
  config, `WrestlerB` AI): `power_bodyslam` is reached and selected in
  every seed at momentum 40–50, sitting cleanly between `grapple_suplex`
  (momentum 4–22) and `signature_backbreaker` (momentum 60) in the observed
  move sequence, with matches still resolving cleanly to a submission win
  and no illegal-FSM assertions.

`power_bodyslam.tres`'s frame/damage/momentum values are a first-pass
estimate, same caveat as every other `MoveDef` constant in this project —
open to retuning once this matters for real gauntlet-round balance. This
brings the paired-move count to 4 of the 18 `ARCHITECTURE.md` scopes (12
grapple + 6 reversal) — 14 remain, all still on `GrappleRig`'s grey-box
frame-count fallback.

## Feature: irish whip, running attacks, and a hidden reversal-window consumer

`WrestlerFSM.LEGAL_TRANSITIONS` already had every edge this needed
(`GRAPPLE_HOLD -> IRISH_WHIP`, `IRISH_WHIP -> [RUN, HIT_REACT]`,
`RUN -> RUNNING_ATTACK`, `RUNNING_ATTACK -> [IDLE, HIT_REACT, DOWN]`) but
`WrestlerController` had zero handling for `IRISH_WHIP` and a dead case for
`RUNNING_ATTACK` (it called `_process_active_move()`, but nothing ever
called `_start_move(RUNNING_ATTACK, ...)` to enter it). `"reversal"` was
read from input every tick and never consumed anywhere, despite
`MoveDef.reversal_window_start/end` and `is_in_reversal_window()` already
existing and being unit-tested in isolation — `strike_jab.tres` even
already had a real window (6-9) waiting on a consumer that never showed up.
`scenes/ring.tscn` had decorative rope meshes but no collision on them at
all. Chose real rope collision + physics rebound over a scripted/timed
abstraction (the option this project would otherwise default to, matching
pin/submission/tie-up's own timer/threshold abstraction style) — a
deliberate scope decision, not a "more work" default.

**The loop, matching what the FSM table already encoded:** attacker whips
the defender into `IRISH_WHIP` (real velocity launched toward the ropes);
the defender physically collides with a rope, rebounds
(`velocity.bounce(normal) * IRISH_WHIP_REBOUND_DAMPING`), and the FSM
legally carries them into `RUN`; a fixed-tick autopilot phase
(`IRISH_WHIP_RETURN_TICKS`) steers them back toward the *original attacker*
with real `RUN_SPEED` velocity rather than handing control back
immediately (which would let normal movement-input processing stomp the
rebound's velocity the very next tick); once in range, a `strike` press
fires `RUN -> RUNNING_ATTACK`, resolving through the same
`_process_active_move()` path `STRIKE` already uses. No new input action —
holding `run` while resolving a grapple in `_process_grapple_hold()` whips
instead of the normal power/signature/finisher-tier resolution.

**Reversal**, for the first time, actually reads
`reversal_window_start`/`end`: the target of an in-flight `STRIKE` or
`RUNNING_ATTACK` can press `reversal` while the attacker's move is inside
its own reversal window to cancel the incoming hit, force the attacker into
`HIT_REACT`, and keep the move's momentum as a small comeback reward — not
a full counter-move system, just negating the hit. `MOVE_EXEC` (a
grapple move resolved via `GrappleRig`) is deliberately excluded:
`_resolve_grapple_move()` enters and resolves `MOVE_EXEC` synchronously
within one `_physics_process()` call, no ticks pass in between, so by the
time a referee tick runs, a grapple-driven `MOVE_EXEC` is already over —
there's no multi-tick window for a reversal to observe without restructuring
how grapple moves resolve, which is out of scope here.

**Scene-order bias, a third time this session:** reversal's outcome
depends on reading the *opponent's* same-tick state
(`_active_move`/`_move_ticks_remaining`), the same shape already fixed
twice this session (tie-up entry, pending-hit resolution) by deferring to
`MatchReferee`, which runs after both wrestlers' own `_physics_process()`
each tick. Each wrestler only captures `_wants_reversal_this_tick` intent
during its own tick (in `_process_free_movement()` for a free-standing
wrestler, and — a detail easy to miss — also in `_process_grapple_hold()`'s
non-attacker early-return, since a grapple's defender sits in
`GRAPPLE_HOLD`, not a free-movement state, while the paired move plays);
`MatchReferee._check_for_reversal()` checks both wrestlers after both have
acted and applies it. Running-attack triggering stays wrestler-local — only
the rebounding wrestler is ever in `RUN` in this flow, so there's no
symmetric scene-order race to fix there the way there was for tie-up entry.

Building the direct-invocation live probe surfaced a real bug in the
probe itself worth naming honestly: an early version wrote
`_wants_reversal_this_tick` directly from the probe's own coroutine,
between physics frames — which raced wrestler A's own
`_process_free_movement()` (reading real, always-`false` `Input` state in
headless mode) and got silently clobbered before `MatchReferee` ever saw
it, so the reversal never fired. Driving the real `Input.action_press()`
path hit the same wall (likely a physics-tick vs. input-processing cadence
mismatch under `--fixed-fps` headless). Fixed by calling
`referee._check_for_reversal()` directly from the probe at the moment the
window opens, rather than racing the engine's own scheduled call to it —
the move/FSM state being checked (wrestler B's real, physics-driven
`RUNNING_ATTACK` progress) stayed entirely live; only the moment the
referee's own check function ran was manually triggered.

Verified against the real Godot binary:
- New `test_running_attack_selection.gd` (5 cases: fires when in range with
  strike pressed, and each individual gate — no strike, out of range, no
  `running_attack_move`, unhittable opponent — correctly blocks it) and
  `test_match_referee_reversal.gd` (4 cases: reverses inside the window,
  does not outside it, does not without reversal intent, does not out of
  range). Full suite: 42/42, 0 errors, 0 failures.
  (Both new test files needed `add_child()` on their `WrestlerController`
  instances, not just `auto_free()` — `CharacterBody3D` defers
  `global_position` to the physics server, which only exists once a node
  is actually inside a `SceneTree`; outside the tree, `global_position`
  writes silently no-op, discovered when a "does not fire out of range"
  test failed because the position change never took effect.)
- Live direct-invocation probe inside a real `match.tscn` context (real
  ring collision, real referee, `WrestlerB` still genuinely AI-controlled):
  attacker forced into `GRAPPLE_HOLD` and whipped via
  `_process_grapple_hold({"run": true})` — everything downstream ran for
  real. Position/velocity trace showed a genuine physical rebound (not a
  teleport): launched at 9.0 m/s, climbed to ~2.1m by tick 10, bounced
  around tick ~17 near the rope's 3.1m collider, then RUN_SPEED-steered
  back at exactly -7.0 m/s. `WrestlerB` (AI) pressed `strike` on its own
  once back in range — confirming the existing distance-based opportunistic
  strike logic already covers landing a running attack with *no* AI code
  changes needed, since `RUN` was already in `poll_input()`'s allowed-state
  gate. The hit landed cleanly at tick 39 with no illegal-FSM assertions in
  the no-reversal trial; in the reversal trial, arming reversal at
  frame_offset 7 (inside `running_attack_clothesline.tres`'s 7-12 window)
  correctly cancelled the hit, transitioned the attacker to `HIT_REACT`
  instead of landing, and credited the reverser 10.0 momentum — no
  `MOVE_LANDED` signal fired at all.
- Regression check: re-ran the earlier power-tier-reachability probe (5
  seeds, default match config, unrelated to this feature) unchanged —
  identical `LANDED`/`MATCH_WON` sequences and tick counts to before this
  change, confirming the shared code paths this touched
  (`_process_free_movement()`, `_process_grapple_hold()`) didn't disturb
  normal play. (First attempt at this regression probe accidentally
  replaced `match_setup.gd`'s own script on `match.tscn`'s root node
  instead of wrapping it — the same mistake this session's own history
  already flagged once before — caught by an all-seeds 20000-tick timeout,
  fixed by wrapping instead of replacing.)

`IRISH_WHIP_LAUNCH_SPEED` (9.0), `IRISH_WHIP_REBOUND_DAMPING` (0.85),
`IRISH_WHIP_RETURN_TICKS` (45), and `running_attack_clothesline.tres`'s
frame/damage/momentum/reversal-window values are all first-pass —
`gauntlet/refs/timings.md` explicitly marks reversal-window length and
ring-crossing run speed "pending" (no reference footage found), so none of
this is cited, just chosen to land somewhere contested rather than
degenerate. Confirm/retune later against real reference capture, not by
feel. Honest gaps, not smoothed over: the AI never *initiates* a whip
(never presses `run` during its own grapple decision) and never attempts a
reversal — both reachable-but-basic-AI gaps, consistent with how
`TIE_UP_JITTER_TICKS` was flagged earlier. Grapple-move (`MOVE_EXEC`)
reversal isn't reachable either, for the structural reason described above
(synchronous resolution, no multi-tick window) — only `STRIKE` and
`RUNNING_ATTACK` are.

## Feature: AI whip and reversal decisions

The irish whip feature above deliberately scoped the AI out: `WrestlerAI.
poll_input()` never set `"run": true` during its own `GRAPPLE_HOLD` (so it
never whipped) and never set `"reversal": true` (so it never attempted a
reversal) — confirmed directly: `poll_input()` had no `GRAPPLE_HOLD` case at
all, falling through the generic `if not controller.fsm.is_in([IDLE,
LOCOMOTION, RUN]): return {}` guard, and nothing in the free-movement branch
ever set `"reversal"`.

**Whip decision:** a new `GRAPPLE_HOLD` case in `poll_input()`, attacker-only
(mirrors `WrestlerController._process_grapple_hold()`'s own early return for
the non-attacker side — the defender has nothing to press mid-grapple, and
grapple-move (`MOVE_EXEC`) reversal is structurally unreachable regardless,
per the base feature's own writeup). Never whips once
`combat.can_power()` is already true — spending a grapple on a whip (no
direct damage) instead of the stronger power/signature/finisher escalation
would waste earned momentum. Below that threshold, a seeded coin flip
(`whip_chance`, default 0.3) deterministic per `(match_seed, player_index,
_grapple_attempts)` — a new per-instance counter, incremented each grapple
attempt, giving each one its own reproducible-but-varying roll rather than
repeating the same outcome all match (same shape as
`MatchReferee._break_tie_up_tie()`'s `match_seed * 4096 + tick` seeding,
keyed off an attempt counter since a whip decision is one-shot per grapple,
not per-tick).

**Reversal decision:** a new per-tick check in the free-movement branch
reads the opponent's `_active_move`/`fsm.current_state`/
`_move_ticks_remaining` (already public fields) and, when the opponent is
in `STRIKE` or `RUNNING_ATTACK` with the computed frame offset inside
`is_in_reversal_window()`, tracks how long the window has been open. Only
presses `"reversal"` once that exceeds `reversal_reaction_ticks` (default
2) — the same reaction-delay shape as `kickout_reaction_ticks`/
`tie_up_reaction_ticks` (a stand-in for human reaction time), sized small
on purpose: existing windows are only 4-6 ticks wide (`strike_jab.tres`
6-9, `running_attack_clothesline.tres` 7-12), so the AI can plausibly still
land it before the window closes, not so it's guaranteed. A real but
imperfect response, not a trivial dominant strategy.

**A real bug found by turning this on, not introduced by it:** the first
live AI-vs-AI probe hung on 4 of 5 seeds (20000-tick timeout, no match
ever completing) once whips started happening. Instrumented position/state
logging traced it to `scenes/ring.tscn`'s rope `CollisionShape3D`s: sized
to match only the *visual* rope height (0.25-1.45) when they were added,
which was never actually tested against a wrestler at anything but a
freshly-reset Y position. Live play found wrestlers can settle at a
noticeably drifted Y position after certain paired-move hit-reactions
(observed as low as -0.5) — the paired clips' final keyframes aren't
necessarily a standing pose, and nothing resets root height afterward (a
pre-existing gap this pass doesn't fix at the source, just works around).
A wrestler whipped from that drifted height flew straight underneath the
rope collider forever — confirmed via a direct position/velocity trace
showing X growing unbounded tick after tick while Y stayed pinned at the
drifted value. Fixed by making the collider generously tall (8.0m,
centered on the rope's existing y=0.85 anchor) rather than chasing the
exact drift range. All 5 seeds resolved cleanly afterward.

Verified against the real Godot binary:
- New `test_wrestler_ai_whip.gd` (3 cases: never whips at/above
  `POWER_THRESHOLD`, deterministic per `(match_seed, player_index,
  attempt)`, both outcomes occur across a range of attempts — the direct
  regression guard against an always-on/always-off degenerate roll) and
  `test_wrestler_ai_reversal.gd` (4 cases: no press before the reaction
  delay elapses, presses once past it inside the window, resets when the
  opponent leaves the move state, never presses outside the window at
  all). Full suite: 49/49, 0 errors, 0 failures.
- Live AI-vs-AI probe (both wrestlers `is_ai = true`, matching the method
  established for the earlier tie-up work), 5 seeds, `--fixed-fps`: whips
  happened in 4/5 seeds (0-2 per match), reversals landed in 3/5 seeds,
  normal power/signature/finisher escalation happened in all 5 — not
  degenerate either direction. All 5 matches resolved cleanly (no
  illegal-FSM assertions) after the rope-collider fix above.
- Regression check against the *default* human-vs-AI `match.tscn` config
  (the baseline used throughout this session): match length and exact
  landed-move sequence changed from before this pass (e.g. seed 1: 970 ->
  1168 ticks) — traced this down before accepting it, since a silent
  length change is exactly the kind of thing worth double-checking rather
  than shrugging off. Confirmed it's the AI legitimately choosing to whip
  the passive `WrestlerA` sometimes now (previously impossible), not a
  bug: `WrestlerA` gets thrown, has no AI/reversal/running-attack logic of
  its own (passive), settles somewhere near `WrestlerB` once the whip's
  return-autopilot phase ends, and `WrestlerB` re-approaches and strikes
  again before resuming its normal escalation — a real, expected behavior
  change, not a regression, and both wrestlers still resolve to a clean
  submission win with no errors either way.

`whip_chance` (0.3) and `reversal_reaction_ticks` (2) are first-pass values,
same caveat as every other tuning constant in this project —
`gauntlet/refs/timings.md` has no whip-decision or reversal-reaction-time
citation to tune against yet. This closes the "AI never initiates a whip or
attempts a reversal" gap the base feature flagged; the AI still doesn't
attempt a grapple-move reversal specifically, but per that feature's own
writeup, no wrestler (human or AI) can — it's structurally unreachable.

## Feature: a paired reversal-counter animation, and a physics-capsule bug it exposed

Continuing the "one more paired move" pattern: reversal previously just
snapped the countered attacker straight to `HIT_REACT` with no distinct
visual — a real, working mechanic (see the base feature above) with no
payoff to look at. `reversal_counter` fills that in: the reverser braces
and shoves, the countered attacker stumbles backward and dips toward the
mat before recovering, authored the same script-driven way as the other
four paired clips (`Quaternion` composition, root-transform-only tracks).
Unlike those four, there's no fixed "attacker"/"defender" MoveDef slot for
it — a reversal can be thrown by either wrestler against either move type —
so `MatchReferee._apply_reversal()` now calls the *reverser's own*
`GrappleRig` reference directly (reverser in the "attacker"/lifter role,
countered wrestler in the "defender"/thrown role), the same
`GrappleRig.begin()` entry point every other paired move already uses.
Finalizing `HIT_REACT`/momentum now waits for `grapple_finished` (the same
async shape `_process_grapple_hold()`/`_on_grapple_finished()` already use)
instead of resolving immediately — added `MatchReferee._reversing`, guarding
`_check_for_reversal()` from re-triggering on a later tick against the same
still-`STRIKE`/`RUNNING_ATTACK`-state attacker before the animation finishes
(would otherwise hit `GrappleRig.begin()`'s "already active" assert on the
very next referee tick).

**A real bug found live, not introduced by the content itself:** the first
AI-vs-AI probe with this move wired in hung on 2 of 5 seeds, always right
after a reversal landed. Instrumented per-tick logging during the
`HIT_REACT` window found the countered wrestler drifting ~0.74m downward in
Y over 20 ticks — with `velocity` reading exactly `(0,0,0)` on *every
single tick* of the drift, ruling out the first, more obvious suspect
(leftover velocity from the whip-return autopilot or a rope bounce, which
got fixed anyway — see below). The real cause: this clip's original final
keyframe left the countered wrestler's rotation tipped ~90° (representing
"knocked flat"), and paired clips retarget directly onto the
`CharacterBody3D` root, so that rotation carries the wrestler's own
collision *capsule* along with it — tipped that far, the capsule partly
submerges in the floor collider once physics resumes, and Jolt's
de-penetration response drags the whole body downward hunting for a new
resting position, exactly matching the observed zero-velocity drift.
Fixed by having the final keyframes recover back toward upright (peaking
near -90° mid-fall, same as `power_bodyslam`'s own momentary peak, but
settling around -30° by the end) rather than staying tipped over — the
same "peak-then-recover" shape `power_bodyslam` already used safely,
which this draft's tail hadn't followed.

**A second, real but ultimately unrelated bug fixed along the way:**
while chasing the above, found `WrestlerController._start_move()` (backing
`STRIKE`/`MOVE_EXEC`/`RUNNING_ATTACK`/`HIT_REACT`) never reset `velocity`
on entry — any of those states can be entered with stale velocity still
sitting on the body from whatever came before (most concretely, the
whip-return autopilot's `RUN_SPEED` steering, or a rope bounce's
`velocity.bounce(normal)`, which can carry a small off-axis component if
the collision isn't a clean face hit), silently consumed by
`move_and_slide()` on every subsequent tick in a state that never manages
velocity itself. Didn't turn out to be this bug's cause (velocity was
confirmed zero throughout), but it's a real latent hazard independent of
the animation fix — fixed by zeroing `velocity` in `_start_move()` itself,
and kept even though the specific hang it was first suspected of causing
turned out to have a different root cause.

Verified against the real Godot binary:
- Extended `test_match_referee_reversal.gd` with
  `test_reverses_via_paired_animation_when_grapple_rig_present` (4 cases
  covering the no-`grapple_rig` synchronous fallback already existed; this
  adds the async path: `_reversing` is true and the attacker hasn't moved
  to `HIT_REACT` yet immediately after `_check_for_reversal()`, then
  resolves correctly once `grapple_finished` fires). Full suite: 50/50, 0
  errors, 0 failures.
- Direct-invocation OpenGL capture (same method as every prior paired-move
  pass), both reverser-identity directions: clean posing throughout, no
  bind-pose or invisible-limb bugs, matching motion regardless of which
  wrestler reverses (confirming `_play_retargeted()`'s fix from the
  power-tier pass still holds here too).
- Live AI-vs-AI probe, 5 seeds, `--fixed-fps`: reversals landed in 3/5
  seeds, all 5 matches resolved cleanly to a submission win with no
  illegal-FSM assertions and no hangs, after both fixes above.
- Regression check against the default human-vs-AI `match.tscn` config:
  same clean resolution as before this pass (submission win, ~1150-1270
  ticks depending on seed), confirming the `_start_move()` velocity-reset
  change didn't disturb normal play.

This brings the paired-move count to 5 of the 18 `ARCHITECTURE.md` scopes
(12 grapple + 6 reversal) — 13 remain. `reversal_counter.tres`'s frame data
is a first-pass placeholder like every other `MoveDef` constant in this
project; it's cosmetic-timing-only here since `_apply_reversal()` doesn't
read its damage/momentum fields at all (the reversed move's own momentum is
what the reverser keeps, per the base feature).

## Fix: four defects a real capture showed, and the one that wasn't a bug

A 15-second AI-vs-AI capture reviewed on video turned up four complaints —
the wrestlers start facing away from each other, they never grapple, they
"point at each other," one "clichés into a fall to the mat," and one partly
sinks into the ring. Chasing each one against the running engine (a live
instrumented probe over 6 seeds, plus frame-stepped OpenGL captures) found
three real bugs, one already-documented placeholder, and one confidently-
argued diagnosis that measurement flatly disproved.

**The wrong one, recorded because it nearly shipped.** The obvious cause for
"pointing" looked like `STATE_ANIMATIONS`: the table asks for `Idle`, `Walk`,
`Sprint`, `Push` and `Crouch_Idle`, and parsing `wrestler_base.glb`'s JSON
chunk directly shows the library containing `Idle_Loop`, `Walk_Loop`,
`Sprint_Loop`, `Push_Loop`, `Crouch_Idle_Loop`. Since `_build_animation_tree()`
skipped a missing clip with a bare `continue`, that would have silently
de-animated IDLE/LOCOMOTION/RUN — most of a match's runtime — which fit the
symptom exactly. It is also wrong: Godot's glTF importer strips the `_Loop`
suffix on import (it marks the clip as looping), so all 18 mappings resolve.
Writing the guard test *before* the fix is what caught it — the test passed
on the unmodified code. `tests/test_state_animations.gd` is kept as the
regression guard, and the silent `continue` is now a `push_error()`, since
the failure mode it hides is real even though it wasn't happening here.

**1. Spawn facing (real).** `match.tscn` had `WrestlerA` at `(-1.5,0,0)` with
an identity basis (forward `-Z`) and `WrestlerB` at `(+1.5,0,0)` yawed 180°
(forward `+Z`), while their separation runs along **X** — both perpendicular
to the line between them. Measured live: forward dotted with the direction to
the opponent was exactly `0.0` on tick 1. Nothing corrected it, because
`_process_free_movement()` only called `look_at()` inside
`if direction.length() > 0.1`, aiming at the *movement* vector, and hits and
tie-ups gate on distance with no facing term. Fixed by rotating both spawn
transforms to face along X, and by adding
`WrestlerController._turn_toward_opponent()` — a fixed-rate yaw toward the
opponent on any tick with no movement input, stepped per physics tick rather
than by wall clock so `ReplaySystem` determinism is unaffected. Both spawns
now measure `1.0`.

**2. "They never grapple" (not a bug — a legibility problem).** The
instrumented run shows the opposite of what the video suggests: tie-up at
tick 45, `GRAPPLE_HOLD` at 120, then six completed paired moves (suplex ×3,
bodyslam ×2, backbreaker) before a submission finish. They grapple
constantly. What's missing is that the FSM stays in `GRAPPLE_HOLD` for the
whole throw and `GRAPPLE_HOLD` maps to the `Interact` placeholder clip, so
both wrestlers hold a one-armed reaching pose — which is also the literal
source of complaint 3, "they point at each other." The paired clips carry
only `position_3d`/`rotation_3d` tracks on the two root nodes (by design, see
`grapple_rig.gd`'s header — an earlier attempt at bone tracks left every
un-animated bone stuck in bind pose), so a suplex moves the bodies through a
correct arc while the skeletons never do anything grapple-shaped. Left as-is:
this is the 13-remaining-paired-moves content gap, not a logic fault.

**3. "Clichés into a fall to the mat" (working as coded).** `DOWN` and
`PIN_DEFENDER` map to `Death01`. Already flagged as a placeholder above;
unchanged this round.

**4. Sinking into the ring (real, three compounding causes).** Measured
before the fix: the defender spent **1536 of 1800 ticks** off the mat, and
the post-whip low point was **y = -0.50**.
- *The mat wasn't at y=0.* The ring `Floor` box is 0.2 thick centred at the
  origin, putting its top surface at `y = +0.1`, while the wrestler capsule's
  bottom — the feet — sits at the body origin `y = 0`. Everything that placed
  a wrestler at `y=0` (spawns, `GrappleAnchor`, every baked paired-move
  position track) put it 0.1 m under the mat. Fixed with a single
  `position = Vector3(0, -0.1, 0)` on the `Ring` root, which moves floor,
  ropes, colliders, posts and apron together and makes `y = 0` mean "standing
  on the mat" everywhere.
- *Paired clips left the body rotated.* `grapple_suplex` ends with the thrown
  wrestler at **pitch 90°**, and the collision capsule is rigidly attached to
  the `CharacterBody3D` — so an upright capsule ends up lying horizontal, half
  of it below the mat, and the floor depenetrates it upward by exactly one
  radius. Confirmed live: the defender rose from `y=0` to `y=0.400127` over
  three ticks with **zero velocity**, contact normal straight up, collider
  named `Floor`. `GrappleRig._level_bodies()` now rebuilds both bases from
  yaw alone before resuming physics — lying down is a *pose* (DOWN's clip),
  never a body orientation. README already records this same mechanism biting
  `reversal_counter`, where it was worked around by re-authoring that one
  clip; this handles it for every clip including the unwritten ones.
- *Nothing ever pulled anyone back down.* `move_and_slide()` ran every tick
  but `velocity.y` was never written anywhere in the codebase — there was no
  gravity at all — so any vertical displacement was permanent. That is why
  the older post-whip drift persisted instead of self-correcting.
  `_apply_gravity()` now applies Godot's default 9.8 m/s² whenever the body
  is off the floor. Paired moves are unaffected, since `GrappleRig._suspend()`
  disables `_physics_process` on both bodies for the duration.

Also fixed alongside: `GrappleRig._separate_bodies()` pushes the pair apart to
their combined capsule radii plus a 0.15 m margin before physics resumes — 4
of the 5 paired clips finish closer together than one capsule diameter
(`finisher_piledriver` ends 0.14 m apart, `signature_backbreaker` 0.28 m).
Exact tangency was measured to be insufficient on its own: at precisely 0.8 m
the defender still climbed to `y=0.4`, because `move_and_slide()` treats the
shallow upper part of the attacker's lower capsule cap as walkable floor.

Verified against the real Godot binary: 58/58 unit tests pass (8 of them new,
across `test_state_animations.gd` and `test_wrestler_facing.gd`, both with
zero orphans); 6 seeds (1, 2, 3, 5, 7, 11) all complete with zero script
errors and a min Y of -0.026 m; off-mat ticks dropped from 1536 to ~254, and
those remaining are legitimate mid-throw airborne arcs. A fresh 1280×720
OpenGL capture shows the pair squared up and standing on the mat at tick 0,
and suplexes that read as throws.

**Still open, named rather than quietly dropped:** `GrappleRig._align_to_anchor()`
teleports both wrestlers to the anchor — the world origin — for every paired
move, wherever they were standing. Fixing it means making the paired clips'
position tracks relative to the anchor instead of absolute in `Match` space,
which is a change to the animation authoring convention rather than a code
fix.

## Fix: the rig was mounted backwards, and grapples had no poses

A second video review of the same capture still reported no facing, no
grappling, "one keeps falling whilst the other one is pointing," intermittent
stacking, and — the useful detail — *"when the other falls I don't see the
attacker hitting him or lifting him up."* Three real causes, all confirmed
against the running engine and against rendered frames.

**The measurement lesson first, because it caused a wrong "fixed" claim.**
The previous round reported facing solved on a measured
`forward · to-opponent = 1.0`. That number was correct and the conclusion was
wrong: it measures the `CharacterBody3D` node, and the *rendered character*
disagreed with the node by 180°. A transform-space assertion cannot verify
what the camera sees. Anything about how the game *looks* now has to be
checked by opening rendered frames.

**1. The character model faced backwards.** Parsing
`assets/characters/wrestler_base_root_motion.glb` directly, the rig's own
forward-locomotion clips translate its `root` node along **+Z**: `Walk_Loop`
`dZ=+1.3`, `Jog_Fwd_Loop` `dZ=+5.0`, `Sprint_Loop` `dZ=+5.5`, all with
`dX=0`. Godot treats **-Z** as forward, which is what every `look_at()` and
`-basis.z` in this project assumes. `scenes/wrestler.tscn` had no
compensating rotation on `CharacterModel`, so aiming a wrestler at his
opponent rendered him facing exactly away — visible in the capture as both
wrestlers extending an arm *outward, past each other* during a tie-up, and as
the "attacker" standing pointing away from the man he had just thrown. Fixed
with a 180° yaw on `CharacterModel`, guarded by
`tests/test_wrestler_model_orientation.gd` so it doesn't get tidied away.

**2. Both roles played the same clip through a grapple.** Paired clips
animate only the two root transforms, and the FSM stays in `GRAPPLE_HOLD` for
a whole rig-driven move (`MOVE_EXEC` never fires — confirmed live), where
`STATE_ANIMATIONS` mapped both wrestlers to the `Interact` one-armed reach.
So the attacker did an idle gesture while the victim's rigid body arced past
him: mechanically a suplex, visually nobody grappling anybody. Added
`ATTACKER_STATE_ANIMATIONS` / `DEFENDER_STATE_ANIMATIONS` overrides on top of
the shared table — attacker `PickUp_Table` (a real bend-and-lift), defender
`Death01` (limp) — resolved through `clip_for_state()` and applied by
pointing the state-machine node at the right clip just before travelling.
Each wrestler builds its own `AnimationNodeStateMachine`, so this is
instance-local and needs no duplicated transition edges;
`MatchReferee._resolve_tie_up()` already assigns `_is_grapple_attacker`
before transitioning either FSM, so the role is known when the signal fires.
`TIE_UP` also moved from `Interact` to `Push`, a two-armed shove that reads
as a collar-and-elbow lock-up.

**3. Every paired move teleported the pair to ring centre.**
`GrappleRig` aligned both wrestlers onto `GrappleAnchor`, which has no
transform override in `match.tscn` and therefore sits at the world origin.
`_compute_pair_transform()` now builds a per-call frame at the pair's own
midpoint, yawed along the attacker's facing and clamped inside the mat (a
suspended body ignores collision for the clip's duration, so a throw started
against the ropes would sweep through them). `_play_retargeted()` bakes that
frame into the duplicated clip's keys — positions by the transform, rotations
by its yaw — so the animation doesn't drag the pair back to the origin on its
first frame. Baking into the copy the rig already duplicates keeps playback
deterministic and avoids a post-animation hook that would have to run after
the `AnimationPlayer` child updates, which node order doesn't give us.

Verified against the real Godot binary: 69/69 unit tests pass (11 new across
`test_state_animations.gd`, `test_wrestler_model_orientation.gd` and
`test_grapple_rig_placement.gd`, all with zero orphans); seeds 1, 2, 3, 5, 7
and 11 all complete with zero script errors and no Y regression (min
-0.026 m, off-mat ticks unchanged at ~250-300, all mid-throw arcs). And
this time **checked on the pixels**: a fresh 1280x720 capture shows a genuine
collar-and-elbow tie-up with hands meeting and feet braced, an attacker bent
under the victim mid-lift, and moves playing where the wrestlers stand.

**Still the real gap:** these are borrowed single-character clips, not two
rigs gripping each other. Genuinely interlocked paired animation — hands on
the opponent, weight transferring between them — still needs bone tracks
authored in Blender against two rigs, which is the same content gap as the
13 unwritten paired moves. `grapple_rig.gd`'s header records why bone tracks
can't simply be added to the existing clips.

## Feature: grip IK, so the hands actually land on the opponent

The paired grapple clips animate only the two root transforms, and each
wrestler's skeleton is posed by its own single-character clip, which has no
idea another body exists. So an attacker performed a lifting motion *near*
the defender and never touched him — the "I don't see the attacker hitting
him or lifting him up" complaint, which no amount of clip-swapping fixes.

Two `SkeletonIK3D` chains per wrestler (`upperarm_* -> hand_*`) now pull the
hands onto the opponent while gripping. `SkeletonIK3D` derives from
`SkeletonModifier3D`, so it runs *after* the `AnimationMixer` writes the pose:
the clip supplies the body, IK places the arms on top. Contact is therefore
emergent, and holds for every move including the 13 paired clips still
unwritten, instead of being keyframed one clip at a time. The rig is built at
runtime next to `_build_animation_tree()`, for the same reason that is —
derived from the bone names rather than drifting from them, and no editable
children needed on the instanced `.glb`.

Targeting: a squared-up wrestler grips the opponent's `spine_03` (upper
chest); a lifting attacker grips `pelvis` instead, because mid-throw the
victim's chest is overhead and behind and reaching for it puts the arms
nowhere useful. Each target is *clamped* onto its arm's reach sphere rather
than rejected when out of range — measured, an arm spans 0.547 m while the
paired clips hold the two bodies 0.8–1.2 m apart, so a hard reach test never
engages at all. Clamping gives the honest in-between: arms fully extended
toward the opponent when he's beyond reach, hands genuinely on him once he
isn't. Blend ramps by a fixed step per physics tick, never a wall-clock lerp,
so `ReplaySystem` determinism is unaffected.

### Three engine traps this hit, all worth knowing

- **`TwoBoneIK3D` does nothing on this build.** It is the modern,
  non-deprecated node and was the first choice. In an isolated three-bone
  skeleton with the chain resolved, the target set, `influence` at 1 and
  `active` true, the tip bone never leaves its rest pose. `SkeletonIK3D`
  lands the same tip within 0.005 m of the same target. Hence the deprecated
  node.
- **`Skeleton3D.get_bone_global_pose()` returns the *pre-modifier* pose.** A
  custom `SkeletonModifier3D` that demonstrably rotates a bone still reports
  its rest position through that call, while a `BoneAttachment3D` on the same
  bone reads the real, post-modifier position. This very nearly buried the
  whole approach: it made a working modifier look broken. Measure modifier
  output with a `BoneAttachment3D`, or by rendering.
- **`BoneAttachment3D` deadlocks against an IK modifier on the same
  skeleton.** Fine for the isolated diagnosis above; adding one to a wrestler
  that has grip IK hangs the process. So the unit tests cover the rig and the
  targeting maths only, and the pose itself is verified by rendering.

Also: configure `root_bone`/`tip_bone` *before* adding the `SkeletonIK3D` to
the tree. Each assignment rebuilds the solver chain immediately, so setting
them on an already-parented node makes the first one resolve the other end to
`-1` and log `build_chain` errors every frame while doing nothing.

Verified against the real Godot binary: 82/82 unit tests pass (13 new, zero
orphans); seeds 1, 2, 3, 5, 7 and 11 all produce **identical** match outcomes
to the build without IK — same winners, same finishes, same min Y (-0.026 m),
same off-mat tick counts — confirming this is presentation-only and cannot
change a match. And checked on the pixels: close-up renders show the hands
interlocked in a tie-up and the attacker's arms wrapped round the victim's
waist during a lift, where the same frames without IK show arms hanging in
the clip's own pose.

**Still not a full two-body performance.** IK places the hands; it doesn't
produce weight transfer, counter-balance, or a defender who grips back.
Genuinely interlocked paired animation remains the content gap, and is the
same work as the 13 unwritten paired moves.

## Feature: real bone-level paired performance, stitched from the clip library

The gap the section above ends on — "IK places the hands; it doesn't produce
weight transfer, counter-balance, or a defender who grips back" — is closed
for the five existing paired moves. `paired_moves.tres` used to be the whole
performance: two `position_3d`/`rotation_3d` tracks per move on the two
`CharacterBody3D` roots, with each skeleton independently playing a borrowed
solo clip (`PickUp_Table` for the attacker, `Death01` for the defender) that
had no idea another body existed. Now every move has an authored, per-role,
full-body pose track: 55 bone rotations plus the pelvis translation, keyed
through the throw.

### Why pose-stitching, and not Blender

Blender is not installed here, and installing it would not have helped with
the part that is actually hard. Hand-animating 18 moves × 2 roles × 65 joints
is the work; the file format is not. The rig already ships **43 CC0 clips**,
which between them contain almost every pose a wrestling throw needs — a
crouch-and-drive (`Push`), a load (`PickUp_Table`), an overhead extension
(`Sword_Attack`), an airborne body (`Jump`), a limp one (`Death01`), an
impact (`Jump_Land`). So poses are *sampled* out of those clips, at measured
times, and sequenced.

Two files, mirroring the `MoveDef` split between tuning data and code:

- **`game/resources/animations/paired_recipes.gd`** — the tuning surface. Per
  move, per role, a list of `{"t": <time in the output clip>, "clip": <source
  clip>, "at": <time to sample it>, "bones": {<per-bone Euler nudges>}}`. The
  file header carries the measured table of which `at` values in which clips
  give which pose, so a retune is a two-number edit, not a search.
- **`game/tools/anim/build_paired_poses.gd`** — the generator. Run
  `godot4 --headless -s res://tools/anim/build_paired_poses.gd` from `game/`.
  It derives its track list and paths from a real clip on the rig rather than
  hardcoding them, evaluates every rotation track and the pelvis position
  track of each source clip at `at`, applies the recipe's offsets, and writes
  one key per bone per beat. Output is
  **`game/resources/animations/paired_poses.tres`**, committed, and
  byte-identical across runs.

Every pose in the result is a real frame of real animation; the recipe only
chooses and sequences them. That is what keeps them human-looking without a
single hand-typed quaternion.

### The constraint that shaped the design

**Two `AnimationMixer`s must never write the same `Skeleton3D`.** So the
generated bone tracks cannot live in `paired_moves.tres` alongside the root
tracks — that clip is played by the `AnimationPlayer` on `Match`, and each
wrestler's own `AnimationTree` already owns its skeleton. Instead each move
becomes three clips:

```
grapple_suplex             paired_moves.tres  -> the two root transforms, on Match
grapple_suplex__attacker   paired_poses.tres  -> bone tracks, on wrestler A's own tree
grapple_suplex__defender   paired_poses.tres  -> bone tracks, on wrestler B's own tree
```

`paired_poses.tres` is registered as a named library on each wrestler's
`AnimationPlayer` at `_ready()`, so clips resolve as
`paired/grapple_suplex__attacker`. `GrappleRig.begin()` starts both halves on
the same physics tick and the generator gives them the same length as the
root clip, so they stay in sync with no new synchronisation machinery. A move
with no recipe resolves to `""` and falls back to the old borrowed clip, so
this degrades rather than breaks.

### Two live bugs the measurements exposed

Neither was visible without instrumenting the running match, and one of them
was a defect in what shipped last round.

- **Grip IK was frozen for the entire duration of every paired move.**
  `GrappleRig._suspend()` calls `body.set_physics_process(false)` on both
  wrestlers — and `_update_grip_ik()` was being driven from the controller's
  `_physics_process`. So the IK targets and the blend weight froze at their
  last tie-up values the instant a grapple started, which is precisely when
  they need to track. Measured: the defender's blend sat pinned at `1.00` for
  a whole suplex. `GrappleRig` now drives `update_paired_presentation()` on
  both bodies from its own `_physics_process` while a move is active; the
  same blend now ramps `1.00 -> 0.00` across the throw as intended. The grip
  IK from the previous section never actually tracked an opponent
  mid-grapple until this fix.
- **Every throw ended with the victim 0.55 m under the mat.** Measuring the
  defender's basis at the end of a suplex gave `Y = (0.00, 0.01, -1.00)` — a
  90° face-down pitch that the trajectory never undid. Because the model's
  origin is at its **feet**, a body pitched flat at root `y = 0` hangs its
  entire length below the mat, until `_level_bodies()` snapped it back a tick
  after the clip finished. That is the "he partly sinks into the ring" report.
  Fixed as content, in `paired_moves.tres`: for every wrestler whose position
  track peaks at `y >= 0.30`, the rotation keys at and after landing are set
  back to that track's first key. Quaternion shortest-arc interpolation makes
  this *continue* the rotation to a full 360° rather than reversing it, so
  the flip still reads as a flip. The victim's pelvis now ends at `+0.06`.

Both are guarded by tests: `test_thrown_bodies_land_upright()` is strict for
bodies that actually leave the mat, and `test_no_move_ends_with_a_body_on_its_face()`
is the looser 45° invariant that catches the class of bug for everything else.

### One recipe fix that only the pixels showed

The suplex apex originally sampled `PickUp_Table@0.80` for the attacker.
That is a waist-height carry — and with the victim's hips up at 1.6 m, IK
clamped the attacker's arms at full stretch *below* him, which reads exactly
like he let go at the top. Swapped for `Sword_Attack@0.40`, an overhead
extension, and re-rendered. No test would have caught this; it is why the
close-up render pass exists.

### Verification

Against the real Godot binary: **96/96 unit tests pass** (14 new in
`game/tests/test_paired_poses.gd`), orphan count unchanged at the
pre-existing baseline of 105. Seeds 1, 2, 3, 5, 7 and 11 produce **identical**
winners, finishes, tick counts, min Y (-0.026 m) and off-mat counts to the
build before this change — presentation-only, as intended. An instrumented
AI-vs-AI run confirms all five moves fire, both roles receive their generated
clips, and each move's defender grip window is the length its recipe asks
for. And on the pixels: six-beat close-up contact sheets for all five moves
show a braced clinch with interlocked hands, a load, a lift, an inverted apex
with contact maintained, impact, and the victim flat on the mat.

**What is still missing** is breadth, not depth: 5 of the 18 moves
`ARCHITECTURE.md` scopes have this treatment. The other 13 still have neither
a `MoveDef` nor an animation and resolve on a timer.

## Feature: the moveset ARCHITECTURE.md scopes, all 18 of it

The section above closed the depth half of the paired-animation gap for the
five moves that existed. This closes the breadth half. `ARCHITECTURE.md`
scopes **12 grapple + 6 reversal** paired moves; there were 5, and the other
13 had neither a `MoveDef` nor an animation, so they fell through
`GrappleRig.begin()`'s grey-box branch and resolved on a bare timer.

New: `grapple_hiptoss`, `grapple_snapmare`, `grapple_armdrag`,
`power_spinebuster`, `power_gutwrench_slam`, `power_fireman_carry_drop`,
`signature_neckbreaker`, `finisher_facebuster`, and the reversals
`reversal_hiptoss_counter`, `reversal_arm_wringer`, `reversal_duck_under`,
`reversal_back_body_drop`, `reversal_go_behind`. Each is a `MoveDef`, a root
trajectory, and attacker/defender pose recipes.

### One move slot per tier was the actual blocker

Authoring 13 moves would have produced 13 unreachable files: a wrestler had
exactly one `MoveDef` per tier (`grapple_move`, `power_move`,
`signature_move`, `finisher_move`), and `MatchReferee` one
`reversal_counter_move`. So each tier gained a pool alongside its slot, and
the attacker draws from `[the tier's move] + pool` at the moment he commits.

The draw is **seeded, not random** — `match_seed * 8192 + player_index * 131
+ draw count`, following `WrestlerAI.setup_jitter()`'s established shape and
deliberately using different multipliers so the two decisions don't move in
lockstep. Which move plays feeds damage and momentum and therefore the match
result, so an unseeded draw would break replay determinism outright. An
empty pool returns the tier's own move every time, which is exactly the
behaviour before pools existed; a pooled move whose weight-class range
excludes this opponent is skipped.

### Trajectories are generated too, and in degrees

`paired_moves.tres` holds each move's *root* half: a position and rotation
track on each of the two `CharacterBody3D` nodes. Hand-keying 13 more of
those as quaternion arrays was not reviewable, so
**`tools/anim/build_paired_moves.gd`** bakes them from a `TRAJECTORIES`
block in `paired_recipes.gd` where a rotation key is `[t, pitch, yaw, roll]`
in **degrees**. A full flip is then a legible run of pitch values
(`0, -90, -200, -310, -360`) instead of a column nobody can retune.

The generator only writes the clips named in `TRAJECTORIES`. The original
five arcs stay hand-keyed and untouched, verified byte-identical after a
run — a re-run cannot perturb an arc a shipped match outcome depends on.

It also enforces two invariants that exist because both were violated in
practice:

- **A thrown wrestler must land upright.** Any arc peaking at y >= 0.30 must
  end at the rotation it started at. This is the suplex bug from the section
  above, now impossible to reintroduce.
- **No root key may sit below the mat.** Discovered here, the hard way. The
  first generated pass took the match's minimum body height from -0.026 m to
  **-0.260 m** across every seed, because the new arcs expressed crouches,
  knee-drops and kneeling finishes as *root dips* — and the model's origin is
  at its feet, so a negative root y is not a crouch, it is his feet through
  the canvas. Those all belong in the bone recipe, where the pelvis drops
  inside a body whose feet stay planted. With the arcs flattened to mat level
  and the crouch left to the poses, minimum height is back to -0.024 m.

  Enforcing that invariant then failed on **`finisher_piledriver`**, which
  ships with the attacker's knee-drop authored as a root dip to -0.15 m. It
  had never shown up in a seeded run because a finisher needs momentum no
  AI-vs-AI match reaches before a submission ends it. Fixed rather than
  excused: the test asserts the invariant across every clip, including the
  hand-keyed ones.

### Verification

**109/109 unit tests pass** (13 new in `game/tests/test_paired_moveset.gd`),
orphans unchanged at the pre-existing baseline of 105. The new suite covers
the moveset matching ARCHITECTURE.md's count, every animation having a
`MoveDef` and every paired `MoveDef` having both recipes, trajectories keying
both roots and spanning their whole clip, the mat-level invariant, the draw
being reproducible from the seed and reaching more than one move, weight-class
filtering, and — the one that would have caught the unreachable-files
mistake — every authored move actually being reachable from `match.tscn`.

Unlike the previous commit this one is **expected to change match outcomes**,
because moves that used to resolve on a grey-box timer now resolve on an
animation signal, and because the draw introduces variety where there was
one move per tier. Checked accordingly, over seeds 1, 2, 3, 5, 7 and 11:
every match completes, no script errors, no wrestler leaves the mat, minimum
body height back at baseline, and each match now draws **4-8 distinct moves**
where it previously replayed the same handful.

Rendered all 13 at six beats. The throws read as throws — clinch, load,
inverted apex with contact kept, descent, impact, victim flat — and the
reversals read as reversals, with both men staying on their feet through a
turn, a duck-under or a go-behind.

**What is honestly still missing** at the end of all this: the moves are
authored, not *tuned*. Frame data, damage and momentum values are internally
consistent by tier but trace to no reference measurement —
`gauntlet/refs/timings.md` still marks the relevant entries pending, and
`ARCHITECTURE.md`'s reference-driven-tuning rule means none of these numbers
may be defended as "how it should feel" until they do.

## Fix: the evidence gate, the replay chain, and the HUD were all fiction

`ARCHITECTURE.md` has two sections describing machinery this repo did not
have. Reading the call graph rather than the prose:

| The contract says | What was there |
| --- | --- |
| "Same seed + same replay must always produce the same `compute_end_state_hash()`", enforced by `test_determinism.gd` | `ReplaySystem.advance_tick()` had **no callers** — `current_tick` sat at 0, so a recording overwrote frame 0 every tick and playback fed that one frame to the whole match. `test_determinism.gd` hashed a hand-built dictionary twice and never ran a match |
| "Every capture produces `capture_manifest.json`… validated **before any critic sees the capture**" | `CaptureHarness.configure/on_tick/finish` had **no callers**; nothing parsed `run_capture.sh`'s `--capture-replay`/`--capture-output`; no manifest was ever written |
| The gate checks "HUD presence" | There was **no HUD** — no `CanvasLayer`, `Control` or `Label` in any scene — though `gauntlet/refs/hud.md` sat measured and unused |
| `run_capture.sh` drives Movie Maker mode | It passed `--headless` alongside `--write-movie`. Headless renders nothing |

So `run_capture.sh` exited 2 ("round is void") on every invocation it had
ever had. Three commits, in dependency order, make it real. The replay and
HUD halves have their own sections above; this one is the gate.

### Beats come from the match, not from a table

`configure(output_dir, replay, beat_frames)` wanted a `label -> tick` map,
which nothing could ever have supplied: no one knows before a match which
tick its apex or its pinfall lands on. Each beat is now taken the first time
its event fires — `tie_up` when both wrestlers are in `TIE_UP`, `apex` half
a clip after `grapple_started`, `impact` on `move_landed`, `pin_start` on
`pin_started`, `three_count` on a pinfall.

### The pin path was unreachable, which is why no capture could pass

Two of the five beats are pin beats, and **zero of 24 seeded AI-vs-AI
matches ever attempted a pin.** Not luck — structure. A wrestler was knocked
down at 200 total damage (`MAX_LIMB_DAMAGE * 2.0`); `MatchReferee` routes a
downed opponent to a submission once his worst limb passes 70 and to a pin
otherwise; and every `MoveDef` loads torso damage heaviest, so torso was far
past 70 long before the total reached 200. Every knockdown was therefore a
submission, and the entire pin/kickout system — minigame, three-count,
tuning notes, tests — was reachable only by forcing it.

Knockdown is now its own constant, `WrestlerController.KNOCKDOWN_DAMAGE`,
set below the damage at which one limb crosses the submission threshold, so
an early knockdown is a pin and a late one is a submission. Measured across
twelve seeds: 0 pin attempts before, 1–2 per match after. This is a
*reachability* value and the code says so — `gauntlet/refs/timings.md` has
nothing to measure it against, and it is chosen as what makes both finishes
occur, not as a claim about feel.

A pin**fall** still never happens: kickouts remain easy by design
(`PinMinigame.PROGRESS_THRESHOLD` was deliberately lowered to 12 in an
earlier round so kickouts were achievable at all), so every pin is escaped
and the match goes on to a submission. Making a pinfall a realistic finish
is kickout balance, which is a tuning slice, not this one.

### So the manifest expects what the match could reach

Demanding all five beats from every capture would void every capture this
project can produce — not because the capture is broken but because the
match legitimately had no pinfall in it, and a gate that fails on correct
input is not a gate. `tie_up`, `apex` and `impact` are always required; the
two pin beats are required only if a pin or a pinfall actually happened, and
skipped ones are named in the manifest with their reason so a critic can see
what the capture does and does not show.

### `hud_present` is measured, and the first version of it was wrong

The gate exists to catch a capture that *claims* a HUD, so this had to come
off the pixels. The first version sampled the two bottom corners for luma
variance, reasoning that a dark plate with bright bars stands out.

The negative test — hide the HUD, re-run, the gate must fail — **passed
anyway**. At the apex beat the bottom corners hold the bright ring mat
against the dark hall and measure 0.61 range with no HUD at all. Measured
across every beat frame of both runs, the real separator is the vitality
bar's green: 41–42% of each corner probe with the HUD, **0.0% without it, on
every frame**. That is what it keys on now.

### Verification

**136/136 unit tests pass** (10 new in `game/tests/test_capture_gate.gd`),
orphans unchanged at the pre-existing baseline of 105. The reachability test
fails against the old knockdown threshold with the diagnosis printed in
full, and the two `hud_present` tests use the exact synthetic frame that
fooled the variance check.

End to end, for real: `tools/capture/run_capture.sh` records a replay,
replays it under `xvfb-run` with the OpenGL3 driver, dumps four labelled
beat frames, writes a manifest, and `evidence_gate.py` prints **`EVIDENCE
GATE: PASS`** — the first time in this project's history. Hiding the HUD and
re-running prints **`EVIDENCE GATE: FAIL (round is void) — hud_present is
false`**.

Unlike the two commits before it, this one **changes match outcomes**, because
`KNOCKDOWN_DAMAGE` is a gameplay value. Checked accordingly over seeds 1, 2,
3, 5, 7 and 11: every match completes, no script errors, nobody leaves the
mat, minimum body height no worse than baseline, and pins now occur in every
match.

## Fix: strikes that connected with air, and the kick the rig didn't have

"Still glitchy for the moves" — so this is what measuring the strikes found,
all of it verified against the running game rather than read off the code.

### Punches landed from well outside a punch's reach

`STRIKE_HIT_RANGE` was **1.8 m**. Running forward kinematics over
`Punch_Jab`'s own tracks puts the fist **0.76 m** ahead of the wrestler's
origin at its contact frame, and the opponent's capsule radius is 0.4 m, so
a punch can honestly reach a body centred up to ~1.16 m away. An
instrumented match recorded strikes landing at **1.60 m** — more than half a
metre of clear air between the fist and the man taking the damage. Now
1.15 m, and the same instrumentation records them landing at 0.95 m.

### The punch was cut off at 38% of itself

`strike_jab.tres` ran 20 ticks (0.333 s) while `Punch_Jab` is 0.87 s, so a
third of the punch played and the arm cross-faded back to idle still
travelling forward. Nothing scales an `AnimationNodeAnimation`, so the clip
and the MoveDef simply disagreed and the FSM won.

Clips are now generated to match the state that plays them
(`tools/anim/build_strike_clips.gd`, recipes in
`resources/animations/strike_recipes.gd`), in three kinds: a **trim** (keys
past a cutoff dropped), a **retime** (all key times scaled), and a
**stitch** (a pose sequence sampled from other clips, with optional
per-bone offsets — the same technique the paired grapples use).

The jab is retimed by 0.13/0.22 so its contact frame lands on tick 8. That
is not arbitrary: `gauntlet/refs/timings.md` measures a real strike's
startup at ~4 frames of 30 fps footage, 0.13 s, and this clip contacts at
0.22 s. After the retime the animation and `startup_frames` finally
describe the same punch. `STUNNED` and both hit reactions are generated the
same way — `STUNNED` ran 45 ticks against an 0.43 s clip, so the pose froze
for the last 19.

### Everyone flinched identically

Every hit played `Hit_Chest`, so a jab to the jaw and a spinebuster to the
ribs produced the same reaction. The reaction is now chosen from where the
move did its damage — head-dominant hits snap the head, everything else
folds the body.

Wiring that up exposed why it looked broken even after the clips were
right: `_on_fsm_state_changed()` **overwrote** the node's clip with the
static table value immediately after `_play_strike_clip()` and
`_play_hit_reaction()` set it. Every kick played the jab and every reaction
played the torso flinch, while the generated clips themselves were fine all
along. Clip requests are now a one-shot override the handler consumes.
Making it strictly one-shot mattered too: a first version left a request
queued when its transition never happened (a hit that knocked the wrestler
down instead), and it was then spent on an unrelated hit later — measured
mis-picking 2 of 10 landed moves.

### The rig has no kick, and no pose to build one from

43 clips and not one throws a leg. Measured: the highest a foot ever gets
*relative to the hips* is **−0.22 m** — `Jump_Start`'s airborne tuck, still
below the pelvis. `Sprint`'s "raised" foot is a stride at ground level. A
first attempt stitched from those rendered as a man throwing a punch,
because the only thing moving was Sprint's arm swing.

So the leg is posed on top of a real stance, with the axis and angles found
by rotating `thigh_l` about each axis in turn and reading the foot back
through FK:

| pose | result |
| --- | --- |
| `thigh_l −70, calf_l +90` | knee at hip height, heel tucked — the chamber |
| `thigh_l −75, calf_l 0` | foot 0.80 m high, 0.78 m forward — a front kick to the body |
| `thigh_l −25, calf_l +25` | foot just off the mat — the step |

Verified on the generated clip itself, independently of rendering: the foot
rises to 0.70 m high and 0.73 m forward at tick 9, and the hands never move.

### The AI threw one punch per match

Strikes were only possible between `tie_up_range` (1.4 m) and
`strike_range` (1.6 m) — a 0.2 m shell a closing wrestler crosses in two
ticks — and once inside 1.4 m it grappled, every time. An instrumented
match bore that out exactly: one strike exchange at tick 20 during the
opening approach, then twenty grapples and not another punch thrown. The AI
now chooses between striking and tying up in close, on a seeded draw, and
only when the opponent is actually inside a fist's reach — a test caught
that tie-up range (1.3 m) reaches further than a strike can land (1.15 m),
which would have put the whiff straight back in.

### Verification

**148/148 unit tests pass** (12 new in `game/tests/test_strike_clips.gd`),
orphans unchanged at the pre-existing baseline of 105. Rendered side-on at
3-tick intervals: the jab plays its full arc into the opponent's head, and
the kick chambers, extends and recovers. Over seeds 1, 2, 3, 5, 7 and 11
every match completes, no script errors, nobody leaves the mat, minimum
body height at or better than baseline, and each match now lands **3–10
jabs and 6–13 kicks** where it previously landed one strike in total.

This changes match outcomes — strikes are gameplay — and makes matches
longer (1500–3100 ticks against 1000–1700), because a strike does less
damage than the grapple it replaces. Whether that trade is the right one is
a feel question, and `gauntlet/refs/timings.md` has nothing to settle it
with: the strike-to-grapple ratio traces to no reference measurement.

## Fix: the match could only end one way

Every match ended by submission — **twelve of twelve seeds, zero pinfalls**.
The pin path had a kickout minigame, a three-count, a HUD count, its own
tests and its own tuning notes, and had never once decided a match. Three
separate things were wrong, each found by instrumenting a real match rather
than reading the code.

### The kickout curve was calibrated for damage no match reaches

`kickout_window_fraction()` scaled against `MAX_LIMB_DAMAGE * 4.0` — 400,
every limb destroyed. Measured: wrestlers are knocked down between **101 and
184** total damage, and across that entire range the window only moved from
0.59 to 0.46. So every pin was escaped. Scaled to the range matches actually
occupy (`KICKOUT_DAMAGE_REFERENCE = 200`), the same span now runs 0.39 down
to 0.05 — early covers are kicked out, late ones are not.

### The referee sent a spent wrestler to a submission

The rule was "worst limb past 70 → submission", with no upper bound — so a
knockdown became a submission exactly when the man was most pinnable. Traced
over one match: knockdowns at 101, 111, 121 and 136 all became pins the
defender escaped, and the first at 146 became the submission that ended it.
A worn-down opponent is now covered instead (`PIN_PREFERENCE_DAMAGE`).

### Two fixed thresholds cannot produce two finishes

Flipping the rule flipped the outcome — **12 of 12 pinfalls, no
submissions**. The reason is measurable: the worst limb tracks total damage
at a near-constant **~0.49** at every knockdown, so any pair of fixed
thresholds on those two quantities is really one threshold, and whichever
finish it selects is the only one that ever happens. A hard threshold on a
monotonically rising quantity is not a decision, it is a schedule.

So the thresholds now deliberately *overlap*, and inside the overlap a
seeded draw decides whether the attacker covers or reaches for the hold —
the same shape as the grapple-tier and counter draws, and reproducible from
the match seed like everything else that changes a result.

That exposed one more stale number: `defender_rate` was a flat **1.8**,
chosen when holds only started above 70 limb damage (an attacker band of
[1.7, 2.0], so 1.8 sat inside it). Lowering the threshold to 55 moved the
band to [1.55, 2.0] and left 1.8 above almost all of it, so every submission
the referee started was one the defender was guaranteed to escape — the old
pin bug, exactly mirrored. It is derived from the constant now, so moving
the threshold again cannot silently make one side unbeatable.

### The three-count was evenly spaced, and a real one isn't

`gauntlet/refs/timings.md` frame-stepped a real three-count at native 30 fps
with no sampling gaps: **"1"→"2" ≈ 1.25 s, "2"→"3" ≈ 1.00 s**. The referee
hangs on the first slap and speeds up into the third. This was an even
1.00 s apart — the one shape the reference says it does not have. The count
now follows the measured schedule.

The same measurement also caught how the digits *render*: "1" is on screen
~0.63–0.67 s and "2" ~0.37–0.43 s, with a silent gap of ~0.55 s before the
next pops in. So the count is not a number sitting there incrementing — it
flashes, disappears, and comes back, which is most of what makes a
three-count tense to watch. The HUD does that now.

The lead-in from the cover to "1" is still 60 ticks and is the one number
here that no measurement covers — the reference clip's count starts
on-camera at "1".

### Verification

**151/151 unit tests pass**, orphans unchanged at the pre-existing baseline
of 105. The reachability test was rewritten: it used to assert a wrestler
goes down *before* any limb qualifies for a submission — the property that
made pins possible at all — and now asserts the stronger one that both
finishes are reachable, deriving the crossing point from the move's damage
split rather than stepping to it in 28-damage chunks, which is too coarse
to separate two thresholds twelve apart.

Over sixteen seeds: **11 pinfalls and 5 submissions**, no timeouts, with 0–3
near-falls per match and matches running 747–2052 ticks (12–34 s). Before
this it was 12 submissions, 0 pinfalls, 0 near-falls that mattered.

Outcomes change throughout — this is the finish, so that is the point. What
is *not* settled: the split between the two finishes, `PIN_PREFERENCE_DAMAGE`,
`SUBMISSION_ESCAPE_LIMB` and the 50/50 draw are all reachability values
chosen so both endings occur, and `gauntlet/refs/` has nothing measuring how
often a real match should end each way.

## Gauntlet: opening the visual slices (round 1)

Twelve gauntlet slices had sat at round 0 since Phase 0 with the same
largest gap — "phase 4 not yet started." This opens three of them:
**ring/arena presentation**, **wrestler look & materials**, and **HUD/UI**.

Two things had to happen before a visual round could mean anything.

### The rule about software renders had nothing enforcing it

`ARCHITECTURE.md` says llvmpipe captures are good for timing and feel
slices only, and `VISUAL_BAR.md` says to "confirm the capture was
GPU-backed before citing a visual gap." Nothing recorded which renderer
produced a capture, so there was no way to confirm it: the rule rested
entirely on whoever ran the capture remembering how they ran it, and the
evidence gate — the thing that stands between a capture and a critic —
could not tell a GPU frame from an llvmpipe one.

Every manifest now records `video_adapter` and `gpu_backed`, and
`evidence_gate.py --visual` (`VISUAL_SLICE=1 tools/capture/run_capture.sh`)
voids a software-rendered capture for a visual slice. Void, not lost: the
ratchet does not move and the round is re-run on hardware with a GPU. CI
covers both directions against fixtures.

**This applies to the round below.** Every capture here is llvmpipe, so
lighting consistency and material believability — priorities 2 and 3 of the
visual bar — are **not judged**, and the slices record them as unjudged
rather than passed.

### "Silhouette readability" was not a measurable claim

The bar's first priority is "silhouette readability at match-camera
distance," which is exactly the kind of thing `ARCHITECTURE.md`'s
reference-driven-tuning rule exists to stop a critic asserting from taste.
`tools/refs/measure_frame.py` makes it a number: relative luminance
(Rec. 709, linearised sRGB) of named regions, plus a `void_fraction` for
how much of a frame is flat, featureless background. The same code reads a
reference still and one of our own captures, so the two are comparable.

Measured off `frames/wide_standoff_broadcast_angle.jpg`, and this shaped
everything below: a wrestler separates **from the mat by value** (ΔL
0.24–0.31, both wrestlers darker than the mat) and **from the other
wrestler by hue** — the reference's two wrestlers are only 0.070 apart in
value. Those are two different mechanisms and copying one for the other
gets it wrong.

### What the first real look at the game found

Nobody had looked at a rendered frame of this project against that bar. The
baseline capture, measured:

| | baseline | after round 1 | reference |
| --- | --- | --- | --- |
| ΔL wrestler A ↔ mat | **0.014** | 0.172 | 0.240–0.310 |
| ΔL wrestler B ↔ mat | 0.156 | 0.170 | 0.240–0.310 |
| ΔL wrestler ↔ wrestler | 0.142 | 0.002 (by design — hue instead) | 0.070 |
| flat-void fraction | **0.618** | 0.289 | 0.010–0.066 |

- **Both wrestlers were the same man.** They instance the same `.glb` with
  the same CC0 placeholder materials, so the apex frame of a paired move —
  the money shot of the whole grapple system — was a single orange blob.
  One of them was also 0.014 in luminance from the mat he was standing on,
  which is no silhouette at all.
- **62% of the frame was flat nothing**, at standard deviation 0.000 across
  the entire upper third. Not "dark" — the reference is dark up there too —
  but empty: no arena was modelled above mat level.
- **The vitality bar was measuring a match this game does not play.** It
  divided damage by `MAX_LIMB_DAMAGE * 4.0` (400) while
  `kickout_window_fraction()` had been rescaled to
  `KICKOUT_DAMAGE_REFERENCE` (200), so a wrestler at the 101–184 damage a
  knockdown actually happens at showed **54–75% health**. Its own comment
  claimed the two shared a denominator, and the test asserting that passed
  anyway — at 400 damage the kickout window is clamped to its floor either
  way, so both halves were true of different scales. A test that cannot
  fail when its property becomes false is not testing it.

### What round 1 changed

- Per-wrestler attire colourways (`attire_body` / `attire_accent` on
  `WrestlerController`), applied as **surface overrides duplicated from the
  mesh's own materials** — both wrestlers share one `Mesh` resource, so
  writing to its materials colours both, the same shared-resource trap that
  once made a `MoveDef`'s "applied" flag leak between wrestlers. There is a
  test that the shared material is still the `.glb`'s own.
- The mat holds its value but is tinted, so the darkened attire has
  something to read against — the reference's mat/wrestler relationship,
  not a colour preference.
- A grey-box arena: barricades, two raked crowd tiers with a generated
  noise albedo (generated, not captured — IP guardrail), hall walls and
  rafters. House light on the crowd is carried by the material rather than
  by lights aimed at the stands, because a fill rig out there would spill
  onto the mat and ring lighting belongs to a different slice.
- The HUD divides by `KICKOUT_DAMAGE_REFERENCE`, and each plate carries a
  flash of its wrestler's own `attire_accent` — read off the wrestler, not
  copied into the HUD, so the man in the ring and the bar in the corner
  cannot drift apart. The reference plates carry a portrait in that slot;
  there are no portraits yet, so it holds something the game can source.

`test_wrestler_colorway.gd` asserts both halves of the measured
relationship against the shipped match scene, on albedo, so it needs no
renderer — which is the point, given the renderer rule above.

### Verification

**156/156 tests pass**, orphans unchanged at the pre-existing baseline of
105. Three captures were run end to end through `run_capture.sh` and the
evidence gate; the numbers in the table above are `measure_frame.py` output
on their `tie_up` beat frames, not estimates.

### What this round did not settle

- Every capture was llvmpipe, so **lighting consistency and material
  believability are unjudged**, by the rule this round added enforcement
  for. Those need a GPU round on real hardware.
- Silhouette separation improved twelvefold and is still **below the
  reference band** (0.17 against 0.24–0.31). Closing it further means
  changing ring lighting, which is the unjudged variable above — so it
  stops here rather than being tuned blind on a software render.
- The void fraction is 0.289 against a 0.010–0.066 reference. The arena is
  no longer nothing; it is grey-box boxes. No entrance stage, no ring skirt,
  no crowd motion.
- **Camera framing is still at round 0, and round 1 found the bug it starts
  from:** `MatchCamera.cut_to_finisher()` and `cut_to_three_count()` have no
  callers anywhere in the project, and both set a mode whose only effect is
  to make `_physics_process` return early. So the scripted cuts `camera.md`
  measures are not merely unimplemented — calling one would freeze the
  camera for the rest of the match.
- The wrestlers are one CC0 mannequin at two tints. No distinct body types,
  no faces, no attire geometry.

## Gauntlet: camera framing (round 1)

The visual round left camera framing at round 0 with the bug it starts from
already found: `MatchCamera.cut_to_finisher()` and `cut_to_three_count()`
had **no callers anywhere**, and both set a mode whose only effect was an
early `return` at the top of `_physics_process`. The scripted cuts
`camera.md` measures were not merely unimplemented — calling either one
would have frozen the shot for the rest of the match.

The framing was worse than the cuts. `distance = clamp(separation * 1.6,
4.0, 9.0)` evaluates to 2.24m at tie-up range, which clamps to the 4.0m
floor, so the camera sat at its minimum through every grapple in the match
and a wrestler filled **0.29** of the frame. Measured against the
reference, that is *wider than its widest shot* at the closest moment of
the fight.

### Fill is the measurement; distance is what gets solved

`gauntlet/refs/camera.md` gained numbers a still can actually give up —
read off the frames with a pixel grid:

| framing | subject fill | far mat edge |
| --- | --- | --- |
| strike exchange (`mid_strike_exchange.jpg`) | 0.675, 0.708 | ~0.59 |
| wide standoff (`wide_standoff_broadcast_angle.jpg`) | 0.32, 0.41 | ~0.66 |
| impact spot (`close_impact_table_spot.jpg`) | — (prone) | ~0.49 |

This also **corrects** that file's earlier reading, which called the strike
exchange "roughly half the frame height." Measured, it is closer to
two-thirds.

FOV is not derivable from a still, and fill does not settle it either —
fill is a function of *both* focal length and distance. One more measured
statement pins the pair: the standoff camera sits "just outside the near
ropes", which in this ring is ~3.2m from centre. The lens that puts a 1.8m
subject at 0.69 fill from ~3.5m is **41° vertical**, and Godot's 75°
default cannot reach the measured fill without putting the camera 1.7m from
the wrestlers — inside the ring.

Running the projection backwards through both frames at that lens gives
(0.74m apart → 3.49m out) and (2.58m → 6.73m), so the camera's response to
separation is the line through them:

```
distance = 2.19 + 1.76 * separation
```

Two points, two parameters, nothing free. Worth being clear about what that
is worth: the separations are *derived*, not observed — they depend on the
fill measurement and on a FOV that is itself derived. It is defended as
reproducing two measured frames, not as a measurement of how a real camera
tracks. A separate containment guard keeps both men on screen past the
distance the fit can reach (corner to corner is 8.49m in this ring, where
the fit wants 17.1m against a 9.0m ceiling); its width limit is labelled in
the source as an engineering value, explicitly not a reference number.

### The ropes

All twelve rope segments were red/white/blue — a boxing convention. Every
rope in every reference frame is white, clearest in the near-rope foreground
of the standoff shot, so they are white now, and they read as a framing
element instead of three coloured stripes competing with the wrestlers'
colourways.

Camera height was then set by what it puts in frame rather than picked off
`camera.md`'s "chest-to-head" range. Measured by unprojecting the near ropes
at a range of heights: at 1.65m only the top rope lands inside the frame; at
**1.45m** the top and middle both do. The bottom rope sits 24° below the
view axis and cannot be recovered without backing off further than the
measured fill allows. The trade is the horizon — 0.622 of frame height
against 0.599 at 1.65m — which sits between the reference's 0.59 and 0.66,
where an intermediate shot should be.

| | before | after | reference |
| --- | --- | --- | --- |
| subject fill, tie-up range | 0.29 | 0.51 | — (interpolated) |
| subject fill, measured separations | 0.29 | 0.66 / 0.36 | 0.675–0.708 / 0.32–0.41 |
| flat-void fraction | 0.618 | **0.110** | 0.010–0.066 |

Note what that last row now means: most of the drop from 0.289 came from
the 41° lens cropping the hall out of frame, not from more arena being
built. The ring/arena slice's recorded gap says so.

### The cuts fire, and one of them cannot

Unit tests cover the mode logic. What they cannot show is whether a live
match ever *reaches* a cut — and this repo's history is a list of systems
that were correct and never called, so a probe ran five seeds and logged
every mode transition.

**Correction, found by the next section's probe:** those five runs loaded
`match.tscn` directly, which leaves `WrestlerA` on the human slot with
nothing driving it — `MatchSetup` only forces both sides onto the AI when
it is recording a replay. They were AI-vs-*passive* matches, not AI-vs-AI,
and WrestlerA landed zero moves in all five. The conclusions below hold and
were re-confirmed on real AI-vs-AI matches, but the momentum figure quoted
here was measured one-sided; see the corrected numbers in the next
section.

`THREE_COUNT_CUT` fires in four of five seeds, and the camera **moves while
cut** — the freeze is genuinely gone.

`FINISHER_CUT` fired **zero times**, and the reason is not the camera:

- Peak momentum across those five matches was **50–59**.
  `SIGNATURE_THRESHOLD` is 60 and `FINISHER_THRESHOLD` is 100, so neither
  the signature nor the finisher tier fired in any match.
- Reaching a finisher needs momentum at its absolute ceiling. A signature
  costs exactly 60 and is checked immediately below the finisher in
  `_pick_tier_move()`, so a wrestler who reaches 60 spends it at his next
  grapple; closing the remaining 40 needs roughly seven strikes landed with
  no grapple in between.

So **the top two rungs of the move ladder do not fire in a real match**.
That is a combat-tuning finding, not a camera one, and it is left as-is
rather than quietly rebalanced from inside a camera slice — but it means the
finisher cut is wired and unobservable, and the HUD's momentum threshold
ticks mark two rungs nobody reaches.

The return to `FOLLOW` after a three-count cut is unit-tested but not
observed live either: every pin in those seeds was the winning one, so the
cut correctly persisted to the end of the match and never had a kickout to
return from.

### Verification

**166/166 tests pass**, orphans unchanged at the pre-existing baseline of
105. Framing assertions go through `Camera3D.unproject_position()` —
projection maths, no renderer — so they hold under the headless CI run that
`ARCHITECTURE.md` forbids judging visual slices on. Three captures were run
end to end through `run_capture.sh` and the evidence gate; every number
above is `tools/refs/measure_frame.py` output or a pixel-grid read, not an
estimate.

### What this round did not settle

- FOV is derived, not measured, and the fit's separations are derived from
  that same FOV. A frame-stepped clip with a known render resolution could
  measure both properly.
- Cut *duration* is not invented — a finisher cut lasts as long as its
  paired move, a three-count cut as long as the pin — but `follow_speed`,
  `cut_speed` and the cut's aim point are project values, and `camera.md`
  still marks ease curves pending.
- The camera holds whichever side of the ring it started on; nothing cuts
  around the axis, and no reference measurement covers when it should.
- The bottom near rope is out of frame at every framing the fill
  measurement permits.

## Fix: the move ladder was scaled to a meter no match fills

`ARCHITECTURE.md` names "momentum → signature → finisher" as part of the
core loop. It was not in the loop. Four authored moves —
`signature_backbreaker`, `signature_neckbreaker`, `finisher_piledriver`,
`finisher_facebuster` — and their paired animations could not appear in a
match, and the HUD's momentum threshold ticks marked two rungs nobody
reached.

### What was actually wrong

Found by the camera slice's probe, then measured properly. First, a
correction to how that probe ran: loading `match.tscn` directly leaves
`WrestlerA` on the human slot with nothing driving it — `MatchSetup` only
forces both sides onto the AI when recording a replay — so the first runs
were AI-vs-**passive**, and WrestlerA landed zero moves in all seven seeds.
Re-run with both sides on the AI:

| | winner's momentum earned | landed moves |
| --- | --- | --- |
| seven AI-vs-AI seeds | 59, 63, 64, 64, 64, 75, 64 | 7–13 |

`SIGNATURE_THRESHOLD` was **60** and `FINISHER_THRESHOLD` was **100**.

Two things follow, and the second is the real bug:

- A winner crosses 60 on the move that *finishes the fight*. In all seven
  seeds **peak momentum equalled total momentum earned**, which means
  nothing was ever spent: the meter passed the signature gate and the match
  ended before another grapple could draw on it.
- `FINISHER_THRESHOLD` was `MOMENTUM_MAX`. A finisher needed the meter
  pinned at its ceiling, while a signature costing 60 sat one branch below
  it in `_pick_tier_move()` — so any wrestler who used his moveset spent the
  meter before it could fill. The top rung was unreachable by construction,
  not by tuning.

This is the same mistake the kickout window had before
`KICKOUT_DAMAGE_REFERENCE`: a scale no match ever occupies.

### The fix

The ladder is expressed against `MOMENTUM_REFERENCE` — the momentum a match
actually affords a winner — instead of against the meter's ceiling:

| | was | now |
| --- | --- | --- |
| power | 30 | 12 |
| signature | 60 | 24 (costs 8) |
| finisher | 100 (= ceiling) | 32 (costs 32) |

The economy feeds back on itself, which took two measured iterations rather
than one: firing the ladder shortens the match, so a winner now earns 40–55
instead of 59–75. At a finisher threshold of 45 the signature fired in all
ten seeds and the finisher in **none** — peak momentum landed at 27–44, one
point short. At 32 it fires.

Over ten AI-vs-AI seeds, where the top two tiers previously fired in zero:

| tier | matches it fires in |
| --- | --- |
| power | 9 / 10 |
| signature | 6 / 10 |
| finisher | 5 / 10 |

Finishes stay varied — 4 pinfalls, 6 submissions — and matches run
629–1899 ticks.

### Invariants, so this fails loudly next time

`test_momentum_ladder.gd` asserts the shape rather than the feel: no tier
sits at the meter's ceiling; the tiers are ordered; the whole climb
(signature + finisher) fits inside what a match affords — the check that
would have caught 60 + 100 against 64 earned; no move costs more than the
tier that unlocks it; and a signature must not price the finisher out of the
rest of the match.

### What this did not settle

- Every number here is a **reachability** value. `gauntlet/refs/` measures
  nothing about how often a wrestler should hit a signature or a finisher,
  so none of them may be defended as how it should feel.
- A match reaches a signature **or** a finisher, rarely both: the two gates
  sit 8 apart, so a wrestler who passes 24 without grappling sails to 32 and
  takes the finisher instead. Real matches usually build through one to the
  other.
- `MOMENTUM_REFERENCE` is kept at the pre-change 64 because that is the
  economy the fractions were derived against; post-change earnings settle at
  40–55. Re-deriving it from the new figure would chase its own tail.

## Gauntlet: the arena the ring stands in (round 2)

`slices.json` opened the ring/arena slice at "reference wins" with a gap line
that undercut its own headline: flat-void fraction had dropped 0.618 → 0.110,
but *"most of the later drop came from the camera slice's 41-degree lens
cropping the hall out of frame, not from more arena being built."* The hall was
four rotated boxes with a noise texture on them.

### Build or download

The first question was whether to download an arena rather than build one.
Searched Sketchfab's downloadable index (via its API), itch.io, Quaternius,
Kenney and OpenGameArt. The answer was build, and the licence rule was widened
to CC0 + CC-BY (`ARCHITECTURE.md`) to make sure that answer was not just an
artefact of a narrow filter. It was not:

- **Branded arenas are barred and would be anyway.** `WWE2K22_WCCW_ARENA` is a
  157k-triangle rip of shipped game assets; `Def Jam Arena` likewise; the
  WrestleMania stage models are trademarked trade dress. Someone tagging a rip
  CC-BY does not make it theirs to licence.
- **The best-looking generic candidate was not generic.** "Wrestling Ring
  Arena" (10k tris, CC-BY) has a **WWE RAW logo baked into its apron texture**.
- **No CC0 or CC-BY arena *bowl* exists at all** — every wrestling result is a
  *ring*, which `ring.tscn` already has.
- **The one clean, usable hit was not worth it.** "Low poly stadium/sports
  arena seats" (CC-BY, 5 chair props) is real and unbranded, but at ~776 tris a
  seat the ~500 empty seats in the bowl would cost 400k triangles — four times
  the whole arena's budget — for chair silhouettes sitting behind seated crowd
  figures 12–30m away in a dark hall.

The decisive argument is not scarcity, though. **The ring's dimensions are
load-bearing for measurement.** `camera.md` derives the 41° lens from the ropes
sitting at 3.1m; `match_camera.gd` picks its 1.45m eye height by unprojecting
those rope heights; `test_camera_framing.gd` pins `MAX_SEPARATION := 8.49` to
the 6m mat and `grapple_rig.gd` pins `RING_HALF_EXTENT := 2.0` to it. Dropping
in third-party ring geometry invalidates that whole chain. So the ring did not
change at all — the hall was split out into `scenes/arena.tscn`, generated by
`core/arena/arena_builder.gd`.

What *was* downloaded is textures: four CC0 ambientCG materials
(`assets/environment/CREDITS.md`), Color and Roughness only at 512px. Normal
and AO maps were skipped deliberately — see "what this did not settle".

### What the hall is now

A 20-row raked bowl (12 lower, concourse, 8 upper) with ~3,900 spectators in
one `MultiMeshInstance3D`, an entrance stage with ramp, tunnel mouth and video
wall on the −Z side the default camera looks down, and an overhead truss.
95k triangles total, built in under a millisecond.

All cosmetic: nothing in `arena_builder.gd` creates a `CollisionObject3D` or
joins a physics layer, and the crowd's idle bob is a vertex shader reading only
`TIME` and `INSTANCE_ID`, so it cannot reach `compute_end_state_hash()`.

### Three bugs the measurements caught

The first capture made the number **worse** — 0.125 → 0.265. More geometry than
before, most of it too dark to count as anything. Chasing that found three real
defects, none of which inspection would have shown:

1. **The house light was computed in the wrong colour space.** Emission
   resolves as `srgb_to_linear(albedo) * energy`, but the compensation divided
   by the *sRGB* luminance. Same formula, six-fold different result depending on
   albedo: the stage backdrop rendered at 0.0026 linear against a 0.014 target
   while the bowl's brighter albedo landed on 0.017.
2. **The concourse was not cut around the stage.** The seating rows were, the
   walkway between the tiers was not, so it closed the gap the rows left and
   walled the entrance off — a solid block filling the centre of frame behind
   the ring. Found with a false-colour render, not by reading the code.
3. **Ambient was credited too generously.** It returns far less on vertical
   faces than on upward-facing treads, so the bowl's risers sat below the void
   floor while its treads sat on target — one material reading two ways
   depending on which way a face pointed. Emission now carries the house level,
   which is orientation-independent.

The house level itself is not a taste call: `VISUAL_BAR.md` measures the
reference footage's crowd at relative luminance **0.014**, and
`measure_frame.py` counts a pixel as void below **0.0025**. A real arena's
stands sit about five times above the void floor — dim, but never black.

### Measured

| beat | void before | void after |
| --- | --- | --- |
| tie_up | 0.110 | 0.007 |
| impact | 0.127 | 0.009 |
| apex | 0.176 | 0.009 |
| pin_start | 0.149 | 0.011 |
| three_count | 0.065 | 0.006 |
| **mean** | **0.125** | **0.008** |

Regression: gdUnit4 **172/172, 0 errors, 0 failures** (unchanged from
baseline); matches complete on seeds 1, 2, 3, 5 and 7 with **zero illegal FSM
transitions** and both finish types; and the recorded replay's
`replay_end_state_hash` is **byte-identical** to the pre-change baseline
(`176140666b5d…`), which is the direct evidence that none of this reached
gameplay. Capture wall-time went 2m58s → 3m25s on llvmpipe.

### What this did not settle

- **0.008 is now below the reference band's 0.010 floor.** We have marginally
  *fewer* black pixels than broadcast footage does. This number is no longer a
  gap to close and should not be pushed further.
- **Lighting consistency and material believability remain UNJUDGED.** Every
  capture here is llvmpipe and `evidence_gate.py --visual` voids them for a
  visual slice. The CC0 materials are therefore *unevaluated, not validated* —
  no claim is made that the hall looks good, only that it is covered and lit to
  a measured level. `VISUAL_SLICE=1 tools/capture/run_capture.sh` is the command
  to re-run on GPU hardware; it is expected to fail here, for the renderer
  reason and no other.
- Normal/AO maps were skipped because they would cost llvmpipe fill rate to
  serve a bar that cannot be judged. One line per material to add back.
- Bowl rake, stage proportions and truss layout trace to **no reference
  measurement** — `gauntlet/refs/` measures nothing about arena architecture.
  They are coverage decisions, held to the same rule as the momentum ladder.
- The crowd are two-box impostors: no faces, no limbs, no reaction to the
  match. The stage has no branding and no entrance sequence uses it.

## Gauntlet: wrestler look & materials (round 2)

The only slice still reading "reference wins". Its gap line: *"one CC0
mannequin at two tints, no distinct body types, no faces, no attire geometry,
one material per man"*, with silhouette separation at 0.172 dL against the
reference's 0.24–0.31.

### The measurement was comparing two different things

`test_wrestler_colorway.gd` asserted that a wrestler's **albedo** sat 0.24–0.31
in relative luminance from the mat's albedo — and passed, at 0.379. But
0.24–0.31 is a number `tools/refs/measure_frame.py` read off **rendered pixels**
of a reference still. Albedo and rendered luminance are not the same space, and
the gap was not small: the shipped build measured **0.161** in its own frames
while passing a suite that claimed 0.379. A gate reading a different quantity
from the one it names is not a gate.

So the band moved to where it can be measured. `--silhouette-shot <prefix>` on
the capture harness renders the standoff plus a segmentation mask keying the
mat and each wrestler (gear included), and `tools/refs/measure_silhouette.py`
averages the beauty frame inside each key — the same three pairings
`VISUAL_BAR.md` tabulates, off our pixels. A mask rather than rectangles,
because a rectangle over a wrestler also catches mat, rope and shadow.

That tool had to live in the harness, not in a `-s` script: a `-s` SceneTree
script does not register the project's `class_name` globals, so every script
with a typed `WrestlerController` field fails to compile there,
`_apply_colorway()` never runs, and both men render in the .glb's own gold. The
first version measured exactly that and reported the two wrestlers as
identical — an artefact of the probe.

### The band was unreachable, not just missed

First measurement of the real build:

| | ours | reference |
| --- | --- | --- |
| mat luminance | 0.276 | 0.46 |
| mat ↔ wrestler A | 0.253 | 0.24–0.31 |
| mat ↔ wrestler B | 0.137 | 0.24–0.31 |
| wrestler ↔ wrestler | 0.116 | ≤ 0.07 |

**Our mat rendered at 0.276.** A wrestler cannot sit 0.24–0.31 *below* a mat
that dark — the ceiling is 0.276. The ring rig went 2.2 → 4.5, which is what
makes the absolute comparison mean anything at all: these are absolute
luminances, so a broadcast still and our render are only comparable once the
brightest surface they share is matched. Spot range is 10m and the arena bowl
starts at 9m, so the hall is untouched (its void fraction is unchanged at
0.008).

The blue/red split had its own cause: the ring light is warm (1, 0.96, 0.88),
so red attire gains and blue loses. The colourway had been chosen in albedo
space, where that does not show up.

### Skin is the mechanism the reference is describing

The deeper problem was the one the gap line named. The mannequin is a single
skinned mesh with **one colour over the whole body**, so a wrestler's average
luminance *was* his attire colour — and an attire colour dark enough to clear
the mat by 0.24 puts the two men far more than 0.07 apart the moment their
hues differ. Those two halves of the reference cannot both hold on a
monochrome body.

A real wrestler is mostly **skin** — a mid value — with saturated gear over
part of it. That is what lets both men sit at the same luminance while their
colours differ. So the mannequin's body became skin and the colourway moved
onto gear that is actually there: `core/match/wrestler_attire.gd` builds 15
pieces per man — trunks, belt, boots over calf and foot, boot cuffs, kneepads,
elbow pads, wristbands — as bone attachments.

Geometry rather than a texture because the rig's UV layout is unknown, and
bone attachments follow the pose through every paired move. Every bone on this
rig runs **+Y toward its child** (verified off the .glb), so a piece is placed
by naming its bone and how far along it sits. `BoneAttachment3D` resolves its
bone from its *parent*, so grouping the pieces under a tidy `Attire` node left
the whole outfit piled at the wrestler's feet — each attachment has to be a
direct child of the `Skeleton3D`.

### Measured

| | before | after | reference |
| --- | --- | --- | --- |
| mat luminance | 0.276 | **0.458** | 0.46 (anchor) |
| mat ↔ wrestler A | 0.253 | **0.290** | 0.24–0.31 |
| mat ↔ wrestler B | 0.137 | **0.291** | 0.24–0.31 |
| wrestler ↔ wrestler | 0.116 | **0.001** | ≤ 0.07 |

All four inside the band. Regression: gdUnit4 **175/175, 0 errors, 0 failures**
(172 before, plus three new); seeds 1, 2, 3, 5, 7 all finish with **zero
illegal FSM transitions**; the replay end-state hash is **byte-identical** to
the pre-arena baseline; and the arena slice's void fraction is unmoved.

`test_wrestler_colorway.gd` now asserts the renderer-independent *mechanisms*
rather than a number it cannot see: skin darker than the mat (at an albedo
threshold, explicitly not the reference's rendered 0.24), the two complexions
within 0.07 of each other, hue separation, that the gear carrying the colourway
exists, and that the two men are built differently.

### What this did not settle

- **wrestler ↔ wrestler at 0.001 is arguably tuned too flat.** The reference's
  own two men differ by 0.07; ours now differ by nothing. Inside the band, but
  it is the edge of it, and it was not aimed at.
- **No faces, and one body.** Both men are still the same CC0 mannequin; their
  builds differ only in gear width (`physique_bulk` 0.94 vs 1.12), because
  `test_wrestler_model_orientation.gd` rightly pins `CharacterModel` to no
  scale and real proportion work needs Blender.
- **The gear is untextured cylinders.** Grey-box, and sized against the rig's
  own proportions — `gauntlet/refs/` measures nothing about gear proportions,
  so none of it may be defended as how it should look.
- **Lighting consistency (priority 2) and material believability (priority 3)
  stay UNJUDGED**, as they were: every capture is llvmpipe and
  `evidence_gate.py --visual` voids it. Raising the ring rig to 4.5 is a
  lighting change whose *measurable* consequence is checked and whose
  appearance is not.

## Gauntlet: the grapple chain (round 1)

The slice's gap line had sat at "phase 4 not yet started" since Phase 0, with
one concrete complaint appended after the momentum ladder was rescaled:

> a match reaches a signature OR a finisher rather than both: they sit 8
> apart, so a wrestler who passes the signature gate without grappling sails
> to the finisher instead

That is exactly what a probe found, and two mechanisms behind it — neither of
them the threshold arithmetic the gap line blamed.

`game/tools/probe/ladder_probe.tscn` runs AI-vs-AI matches headless and
records, per seed, which tier every landed move was drawn from, the momentum
trace, FSM state entries, and how the match ended:

```
godot4 --headless --path game --fixed-fps 6000 \
    tools/probe/ladder_probe.tscn -- --seeds 1,2,3 --trace
```

A wrapper scene rather than a `-s` script, for the reason the wrestler-look
round documented: a `-s` SceneTree script does not register the project's
`class_name` globals, so every script with a typed `WrestlerController` field
fails to compile there.

### Both rungs never fired, and the reason was not the 8-point gap

Ten seeds on the shipped build: a signature fired in **3**, a finisher in
**7**, and **both in 0**. Every one of those seven finishers was thrown by a
wrestler who had never landed a signature — the rung was skipped, not spent.

The gap line's arithmetic is right as far as it goes. The signature band is
`SIGNATURE_THRESHOLD`..`FINISHER_THRESHOLD`, 24 to 32, eight points wide. But
a tier gate is only ever *read* at a grapple, and momentum keeps rising
between grapples: a power move gains 10–12 and strikes gain 4–6 apiece, so a
wrestler earns 10–20 between two consecutive grapples. Seed 2's trace shows it
plainly — a jab carried him from 32 to 36, and the next grapple resolved as a
finisher from a man who had thrown no signature.

A band narrower than the momentum earned between two reads cannot be observed.
Widening it would be tuning a number nobody measured to paper over that, and
the same class of bug would come back the moment any gain changed.

**Ordering is a property of the chain, so the chain records it.**
`CombatSystem.tier_reached` holds the highest rung a wrestler has actually
*landed* this match, and each gate now asks for the rung below it as well as
the momentum to pay: a power move needs a landed grapple, a signature needs a
landed power move, a finisher needs a landed signature. Recorded on landing
rather than on selection — a grapple that gets reversed was never thrown.

A move's tier is still which slot it was drawn from (`MoveDef` carries no tier
field), so `WrestlerController.tier_of()` reads it back off the pools, and
`is_finisher()` — which `MatchCamera` uses to decide whether a cut is worth
taking — is now one case of it rather than a second, separate answer to the
same question.

### The chain barely ran at all, because knockdown was a latch

The bigger finding was in the state-entry counts. Both wrestlers entered
`GRAPPLE_HOLD` **exactly three times, in every single seed** — a suspiciously
flat number for a system with seeded per-match variation — while 6 to 13
strikes landed. A match was playing two or three of the eighteen authored
paired moves and then producing no more tie-ups at all.

The cause: knockdown was `combat.total_damage() >= KNOCKDOWN_DAMAGE`. That is
a test on a quantity that only ever rises, so the first crossing latched it
true for the rest of the match and **every later hit, a 4-damage jab
included, put the man back on the mat**. From ~100 damage onward the match was
strike → knockdown → cover → kickout → getup → strike, because the AI's
"opponent is down, walk in" branch owns every tick a wrestler spends down.

This is the same shape as the bug the previous round fixed in the kickout
window and the one before it in the momentum ceiling: a *scale* or an *event*
expressed as a bare comparison against a running total. A knockdown is an
event, so it is now measured from the last one — `_damage_at_last_knockdown`,
and a wrestler goes down again once he has taken another `KNOCKDOWN_DAMAGE`
*since*. Damage itself still accumulates untouched, so the pin and submission
gates that read it are unaffected.

### Measured

Ten AI-vs-AI seeds (1–10), same seeds and same budget before and after:

| | before | after |
| --- | --- | --- |
| seeds where a signature fired | 3 | **9** |
| seeds where a finisher fired | 7 | **4** |
| seeds where both fired | **0** | **4** |
| seeds where the chain skipped a rung | 7 | **0** |
| grapple moves per match (mean) | 2.8 | **3.6** |
| strikes per match (mean) | 6.6 | 9.2 |
| knockdowns per match (mean) | 1.3 | 0.6 |

All ten seeds still reach a real finish (pinfall or submission), both finishes
still occur, and the chain is walked in order in every seed that climbs it.
The finisher becoming *rarer* is the honest consequence of no longer being
reachable by skipping: it is now the fourth grapple of a chain rather than a
gate a jab can cross.

Regression: gdUnit4 **190/190, 0 errors, 0 failures** (175 before, plus
fifteen new); seeds 1, 2, 3, 5, 7 all finish with **zero illegal FSM
transitions**; and a recorded replay played back twice produces a
byte-identical end-state hash
(`83ae893794d5f9ea8a2b26feb45460d5e18c596c50cde7a4acc49d1b083219db`). The
hash *changed* against the pre-round baseline, which is expected and not
hidden — this round deliberately changes what a match does; determinism is the
contract, not the value.

### What this did not settle

- **The chain is tight against what a match affords.** A full climb needs four
  grapple resolutions and a match now affords 3.6 on average, which is why the
  finisher lands in 4 seeds of 10 rather than most. That ratio is an artefact
  of the constants, not a measured target: `gauntlet/refs/` says nothing about
  how often a real match should reach a finisher.
- **Nothing here is reference-tuned.** `POWER_THRESHOLD`, `SIGNATURE_THRESHOLD`
  and `FINISHER_THRESHOLD` are unchanged and remain reachability values; the
  frame data, damage and momentum on all 18 paired moves still trace to no
  measurement. `timings.md` marks strike active/recovery and reversal-window
  length pending, and has nothing at all on strike-to-grapple ratio.
- **A match can still be won almost entirely with jabs.** Seed 8's winner
  finished on 66 unspent momentum having landed one grapple and one power
  move, taking the match with 8 strikes. Strikes feed the same meter the
  grapple chain spends, and `close_strike_chance` (0.45) is an unmeasured
  first-pass value.
- **Paired-move *quality* is untouched.** This round is about whether the
  chain runs and in what order. Whether the 18 moves read well — the other
  half of the slice's name — needs a GPU-backed capture, and every capture
  here is llvmpipe, which `evidence_gate.py --visual` voids for exactly that
  judgement.
- **Still AI-vs-AI.** No human has played a match on a gamepad.

## Gauntlet: the pin and the kickout (round 1)

This slice had never had a round — its gap line was still Phase 0's "phase 4
not yet started" — but the code was further along than that implied, and the
reference corpus already held a frame-exact three-count. So the round started
by measuring both sides of that comparison rather than either alone.

`game/tools/probe/pin_probe.tscn` runs AI-vs-AI matches headless and
reconstructs every fall and every hold: the count each cover reached, whether
the defender kicked out and how much of the meter he filled, the window he was
given and the damage and momentum that produced it, both submission rates, and
the method the match ended on.

```
godot4 --headless --path game --fixed-fps 6000 \
    tools/probe/pin_probe.tscn -- --seeds 1,2,3 --trace
```

`MatchReferee` exposes no signal for a fall ending, so episodes are rebuilt by
polling `is_pin_active()`/`pin_count()` once per physics frame — enough,
because the referee latches the count for exactly the reason the HUD needs it
latched.

### The count was already measured; the lead-in into it was not

`COUNT_TICKS = [60, 135, 195]` puts the slaps 1.25s and 1.00s apart, which is
the cadence `timings.md` frame-stepped at native 30fps with no sampling gaps.
That half was right, and the entry in `timings.md` claiming "no
referee/pinfall-count system exists in code to compare against" was simply out
of date — corrected in this round.

The first number was not measured. `match_referee.gd` said so itself: the
lead-in from the cover to "1" "keeps its existing 60 ticks and is the one
number here still owed a measurement". So this round measured it, walking the
same pinfall backwards from the known "1" onset at 1091.000s:

- **cover applied — 1087.400s** (`frames/pin_cover_applied.jpg`)
- **referee settles into counting position — ~1089.467s**
  (`frames/pin_ref_in_position.jpg`)
- **count "1" — 1091.000s**

That is **3.60s** cover-to-"1", and the interesting part is the split:
**~2.07s of it is the referee walking across the ring.** This project has no
referee actor — nobody crosses anything, a cover starts where the footage has
him already down — so the comparable half is the **~1.53s** from
referee-in-position to the first slap, i.e. 92 ticks. `COUNT_TICKS[0]` is now
92, and the count no longer starts half a second early. Adopting the whole
3.60s would have imported two seconds of an actor that does not exist here.

While frame-stepping that window, the pin's on-screen UI got recorded into
`hud.md` too: the cover puts exactly two things on screen, the count digit and
an "L1 / CANCEL" prompt that arrives at 1089.067s — with the referee, not with
the cover. **No marker, no target window, no defender-side fill bar anywhere
in the sequence**, which is what this project's `PinMinigame` is built out of.
That is one instance and it is logged as one: this cover ended in a clean
three-count with no kickout, so a defender-side meter that only appears when
the defender is contesting would be absent for exactly that reason.

### Lengthening the count moved the kickouts, which is the real finding

Making the fall 227 ticks instead of 195 without touching anything else made
every kickout land *before* the referee's first slap instead of after his
second. `PROGRESS_THRESHOLD` (12.0) had been calibrated against a 195-tick
fall — its own comment says as much — so a longer count with an unchanged bar
is simply an easier one, and an escape stopped reading as a near-fall at all.

The bar is rescaled by the same 227/195 the fall grew by (12.0 → 14.0) and
`test_pin_count_schedule.gd` now guards the coupling rather than either
number, because this is the same shape of defect the previous two rounds
found: two constants that must move together, with nothing making them.

### The submission was a comparison wearing a contest's clothes

Ten seeds, five holds, every single one resolving in **61–63 ticks** with the
loser's ring at **0.96–0.99** of its break point. A photo finish every time is
not a close contest; it is a tell.

The mechanism: `attacker_rate` rose with the targeted limb (`1.0 + limb/100`)
while `defender_rate` was **flat** (`1.0 + SUBMISSION_ESCAPE_LIMB/100` = 1.6),
and the referee only starts a hold in a narrow band of limb damage straddling
that same crossover. So the two rates were always within a couple of percent
of each other, both bars climbed monotonically to the same break point, and
the outcome was `limb > 60.0` — a threshold comparison, decided before the
first tick, with the defender's input contributing nothing but "held".

Two changes, both keeping the crossover the old code was built around:

- **The defender's rate now mirrors the attacker's around
  `SUBMISSION_ESCAPE_LIMB`** instead of sitting flat. He still wins exactly
  when the limb is under 60 — that property has its own doc comment and is
  preserved — but the margin now grows with the damage instead of being the
  same sliver everywhere.
- **A dead heat is resolved by a seeded flip.** With mirrored rates a limb
  sitting exactly on the crossover makes them identical, and 2 of 10 seeds
  landed there. `_tick_submission()`'s `if/elif` was quietly awarding those to
  the attacker — "the attacker wins ties" as a rule nobody chose, hidden in
  the checking order. That is the tie-up bug this project already fixed once,
  and it is fixed the same way.

`BREAK_POINT` moved 100 → 240, which is the one number here with a
measurement behind it: 240 at the crossover rate is 150 ticks, and
`timings.md` frame-stepped a real hold at **~2.5s** (673.00s → 675.5s) from
applied to the referee's break signal. Holds now run 146–151 ticks. Read the
caveat in `timings.md` before treating that as settled — it is a rope-break
cycle rather than a hold played to a tap, and it is a single instance.

### Measured

Ten AI-vs-AI seeds, same seeds and budget on both sides.

| | before | after |
| --- | --- | --- |
| kickouts landing at the "2" or later | 3 of 3 | 3 of 3 |
| falls reaching a three-count | 6 | 6 |
| hold duration | 61–63 ticks (1.02s) | **146–151 ticks (2.44s)** |
| loser's ring at the end of a hold | 0.96–0.99 | **0.94–1.00** |
| dead heats resolved by `if/elif` order | 2 | **0** |
| pinfall / submission / unfinished | 6 / 4 / 0 | 6 / 4 / 0 |

The count schedule is the part that actually moved against the reference:
the lead-in went from 1.00s to the measured 1.53s, and a fall from 3.25s to
4.53s in total.

Regression: gdUnit4 **205/205, 0 errors, 0 failures** (190 before, plus
fifteen new — a suite pinning the count schedule to `timings.md`, a suite for
the submission tie-break, and a rewritten submission-race suite). Ten seeds
finish with zero illegal FSM transitions. A recorded replay played back twice
gives a byte-identical end-state hash
(`4523f7af52c3f99110629ca4d4593753f5068c24288e4efaf6ad87919b146439`); it
differs from the previous round's, as it must, since this round deliberately
changes what a match does — determinism is the contract, not the value.

### What this did not settle

- **The submission still isn't a contest, it's a steeper comparison.** Both
  rings climb monotonically off constant rates; the defender's only input is
  "held", which the AI holds every tick and a human would too. There is no
  decision in it — no timing, no target, nothing like `PinMinigame`'s window
  or `TieUpMinigame`'s press race. The slope makes the *result* legible; it
  does not make the hold playable.
- **The referee's own gating band is what flattens it.** Holds start only
  where `SUBMISSION_LIMB_THRESHOLD` (55) and `PIN_PREFERENCE_DAMAGE` (140)
  allow, which is a limb band of roughly 55–65 straddling the crossover — so
  however steep the slope, every hold in practice starts near the tie. Both
  of those constants are reachability values.
- **Four of ten matches still end on the first knockdown**, ~10s in, because
  a submission is available there and resolves the moment it starts. Nothing
  in `gauntlet/refs/` measures how long a match should run or how many
  near-falls it should have, so this round did not touch it.
- **A match still has one or two covers, and a kickout only in 3 of 10
  seeds.** The second fall of a match is always at the 0.05 window floor
  (damage past `KICKOUT_DAMAGE_REFERENCE`), so it is arithmetically
  unescapable — the fall is a formality. Whether that is right is not
  measurable against anything in the corpus.
- **`PROGRESS_THRESHOLD`'s base 12.0 is still unmeasured.** What changed is
  that it can no longer drift when the count length does; how hard a kickout
  should be remains a first-pass value.
- **The kickout minigame has no UI.** The HUD draws the count and the hold
  meter and nothing the defender could play a kickout against, so the
  minigame in this slice's name is currently unplayable by a human. The
  reference frames don't settle what that UI should be either — see the
  caveat logged in `hud.md`.
- **Still AI-vs-AI.** No human has played a match on a gamepad.

## Gauntlet: locomotion & strike feel (round 1)

`gauntlet/refs/timings.md` had carried a "pending" on strike active/recovery
through two searches. Both had ended the same way: the source clips are
continuous mutual trading, with no window where one wrestler strikes an
opponent who isn't striking back. This round went looking a third time, and
found one.

`game/tools/probe/feel_probe.tscn` measures the cadence side: how long every
FSM state actually lasts in ticks, how landed strikes are spaced inside an
exchange, and how far apart the two men are over a whole match.

```
godot4 --headless --path game --fixed-fps 6000 \
    tools/probe/feel_probe.tscn -- --seeds 1,2,3 --trace
```

Durations come from observed state occupancy rather than from reading the
constants back, so a state that ends early reports what it actually was.

### An isolated strike, at last

`wwe2k26_footage_01.mp4`, 230.3s–231.5s: Lesnar throws a big cocked overhand
blow at an opponent standing passively who never counters, and the camera
holds one continuous shot across the whole action — which in this clip is
close to the longest available, since it cuts roughly every two seconds in
this region. Every frame inspected at native 30fps:

- **windup start 230.333s** (`frames/strike_heavy_windup_start.jpg`; still
  neutral one frame earlier)
- **contact 230.633s** (`frames/strike_heavy_contact.jpg`)
- **guard reset ~231.367s** (`frames/strike_heavy_guard_reset.jpg`), settled
  into a neutral stance by ~231.433s

So **startup ~0.300s (9 frames), contact-to-fight-ready ~0.73–0.80s**, whole
action ~1.03–1.10s.

**The finding is not the numbers, it's that they disagree with the other
instance.** The jab measured at 668.3s has a ~4-frame startup; this has ~9.
Strike frame data in the reference is not one number, which means any single
startup shared across strike moves is wrong by construction. This project
shares `startup_frames = 8` between `strike_jab.tres` and `strike_kick.tres`.
The jab's 8 is the measured one — `timings.md` still said it was 6, stale
since someone already adopted the measurement — and the kick's is unexamined.

`running_attack_clothesline.tres` is this project's heavy strike, and it was
paced like a light one: startup 14 ticks against a measured 18, and recovery
16 ticks (0.267s) against a measured 0.73–0.80s — about a third of it. A
heavy strike whose recovery is a third of the reference's isn't a
commitment, it's a jab that hurts more. Now 18 and 46.

Video cannot separate *active* from *recovery* — a hitbox has no visual
signature — so the measured quantity is `active_frames + recovery_frames`
together, and the test asserts it that way.

### The getup was measured against the wrong constant

`timings.md` measured two getups and was explicit that they are a two-speed
mechanic rather than sample variance: ~2.10s rising by himself, ~1.14s with
an "R1 INSTANT RECOVERY" prompt visible at rise-start. It then compared both
against `WrestlerController.GETUP_TICKS = 90` and concluded the project sat
"between the two measured speeds".

That was the wrong quantity. `GETUP_TICKS` is how long a wrestler lies
**prone**; the rise itself was an unnamed literal `20` inside
`_process_down()` — **0.33s, about a sixth of the measured default rise** —
applied identically whether he beat the count or the timer simply ran out.
The project had the two-speed distinction on the prone side (an input cuts
`DOWN` short) and then threw it away on the rise.

Both are named now, and the rise carries the two numbers the corpus asked
for: `GETUP_RISE_TICKS = 126` (2.10s) and `GETUP_RISE_FAST_TICKS = 68`
(1.14s), chosen by whether the wrestler pressed his way up. Measured over
ten seeds, `GETUP` went from 20 ticks flat to 126.

### Measured

Ten AI-vs-AI seeds, same seeds and budget on both sides.

| | before | after |
| --- | --- | --- |
| `GETUP` duration | 20 ticks (0.33s), always | **126 ticks (2.10s)** |
| heavy strike, contact to fight-ready | 21 ticks (0.35s) | **51 ticks (0.85s)** |
| `STRIKE` duration | 31.2 ticks mean | 31.2 ticks mean |
| landed strikes / match | 9.2 | 7.7 |
| gap between strikes in an exchange | 30.8 ticks (0.51s) | 30.8 ticks (0.51s) |

Regression: gdUnit4 **216/216, 0 errors, 0 failures** (205 before, plus
eleven new pinning the getup pair and both strikes' frame data to
`timings.md`). Ten seeds with zero illegal FSM transitions. A recorded replay
plays back twice to a byte-identical end-state hash
(`4523f7af52c3f99110629ca4d4593753f5068c24288e4efaf6ad87919b146439`).

### What this did not settle

- **The AI never runs, so the running attack never happens.** `RUN` entered
  6 times in ten matches and every one of them was the *whipped* wrestler's
  rebound autopilot; `RUNNING_ATTACK` entered **zero** times. `input["run"]`
  is only ever set inside `GRAPPLE_HOLD` by the whip decision, so a standing
  AI has no way to charge. An authored move with its own `MoveDef`, its own
  reversal window and its own tests never fires in AI-vs-AI play — which
  also means this round's retune of it is measured against the reference but
  unexercised in a match. Giving the AI a charge behaviour needs a frequency
  nobody has measured, so it is named here rather than guessed at.
- **The fast getup is likewise unexercised.** A human can press up; the AI
  has no policy for it, so all four rises in ten matches took the default
  2.10s. How often a wrestler should take the quick recovery is unmeasured.
- **There is no neutral.** `IDLE` was entered 218 times for a mean of **3.2
  ticks** — the wrestlers blip through it between actions and never stand
  in it. Mean separation over whole matches is **0.96m** against a
  1.15m strike range, and the two never get further apart than 3.29m in a
  ring several times that wide. So there is no spacing, no circling, no
  standoff: two men permanently inside punching distance. Whether that is
  wrong is not measurable against `gauntlet/refs/` — ring-crossing run speed
  is still marked pending there, after a survey that found no usable sprint
  — but it is the largest single difference between how this plays and how
  the footage looks.
- **`MOVE_SPEED` (3.5) and `RUN_SPEED` (7.0) remain unmeasured**, for the
  same reason: nothing in the corpus times a wrestler crossing the ring.
- **The jab's own active/recovery is still unmeasured.** The isolated
  instance is a heavy blow; a jab's recovery needs a jab, and the two
  differ by more than 2x in startup so one cannot stand in for the other.
  `STUNNED_TICKS` (45) gets a lower bound only — the struck man is doubled
  over for ≥0.4s with no citable end frame.
- **Still AI-vs-AI, and `FEEL_BAR.md` says that is not enough.** A feel
  slice is signed off only after a human plays a match on a gamepad. Nobody
  has.

## Gauntlet: the renderer every visual number was measured on

Two visual slices had sat at "contested" for two rounds with the same
sentence in each gap line: *lighting consistency and material believability
remain UNJUDGED — every capture is llvmpipe and `evidence_gate.py --visual`
voids them for this slice.* That reads like a hardware problem waiting on
better hardware. It was not.

### The rule was aimed at the wrong thing

`ARCHITECTURE.md` barred software renders from visual slices. But two
different things had been rolled into one word:

- **The pipeline** decides what the renderer can do at all. Forward+ has
  SSAO, SSR, SDFGI and volumetric fog and tonemaps one way; Compatibility
  has none of them and tonemaps another. Its pixels are not the game's
  pixels.
- **The rasteriser** decides how fast those pixels arrive. A CPU is slow.
  It is not wrong.

`project.godot` ships `forward_plus`. `run_capture.sh` forced
`--rendering-driver opengl3`. So every capture this project has ever taken
went through the pipeline the game does not ship — and the ban on software
rendering, which was about the *other* variable, is what stopped anyone
noticing, because it meant no visual capture was ever examined closely.

The manifest could not have caught it either. `rendering_driver` was read
from `ProjectSettings`, which reports `forward_plus` during a Compatibility
run too. It is now `RenderingServer.get_current_rendering_method()`, which
reports what actually ran.

### What the shipping renderer measures

Same scene, same `measure_silhouette.py`, one frame apart:

| pair | `gl_compatibility` | `forward_plus` (ships) | reference |
| --- | --- | --- | --- |
| mat luminance | 0.458 | **0.172** | 0.43–0.49 |
| mat ↔ wrestler A | 0.290 | **0.094** | 0.24–0.31 |
| mat ↔ wrestler B | 0.291 | **0.044** | 0.24–0.31 |
| wrestler ↔ wrestler | 0.001 | **0.050** | 0.00–0.07 |

Round 2's headline — *all four figures inside the reference band* — was
true of a renderer nobody plays on. On the shipping one, three of the four
are outside it and the mat sits at 37% of its exposure anchor. `void_fraction`
moves the same way: 0.008 on Compatibility, **0.063** on Forward+, which
retires round 2's warning that the number had gone below the reference floor
and must not be pushed further. It had not.

One figure got *better*. A↔B is 0.050 against the reference's own 0.070,
where Compatibility flattened it to 0.001 — so round 2's note that the two
men were "arguably tuned too flat" was an artefact of the renderer, not of
the colourway.

And one thing only Forward+ shows: `_house_lit()`'s emission compensation
**over-returns**, so the crowd is now the brightest thing in the frame. The
reference's crowd sits at 0.014, *behind* bright ropes.

`test_wrestler_colorway.gd` never failed through any of this, and was right
not to: it asserts renderer-independent albedo mechanisms. That is exactly
why it kept passing while the rendered numbers were wrong. A test that
cannot see the defect is not a broken test; it is a test of something else.

### The rule now

`forward_plus` is admissible for a visual slice **whatever rasterised it**,
carrying a recorded `software_rasterised` caveat. `gl_compatibility` stays
void. And **no software capture of either pipeline may support a performance
claim** — frame cost is precisely what a CPU rasteriser gets wrong, so the
gate grew `--performance` for that half. CI asserts all four cases.

Nothing here says the game looks good. It says the game can now be looked at.

### Three tools the loop did not have

Every measurement in the repo read *named regions* — this mat, that
wrestler. Nothing compared a whole frame to a reference frame, which is
what priorities 2 and 3 of `VISUAL_BAR.md` actually are.

- **`tools/refs/compare_frame.py`** compares the statistics a look is made
  of — tone percentiles, local contrast, saturation, warm/cool balance, edge
  density at two scales — rather than pixels, because our frame and a
  broadcast still share no geometry, pose or camera, so a pixel diff would
  measure the framing and nothing else. It letterboxes-crops first; the wide
  standoff reference is mostly black bars.
- **`--art-shots`**, six fixed cameras (wide broadcast, ringside low, ring
  corner, mat close, stage wide, crowd bank). A beat capture frames whatever
  the match was doing, so two rounds of a slice never look at the same
  pixels and "did this round improve the ring" is not answerable from them.
- **`tools/gauntlet/round_check.sh`** — suite, evidence gate and replay hash
  as hard gates, every measured bar reported against a stored baseline.

Priorities 2 and 3 have numbers for the first time, and they are not close:

| | ours | reference |
| --- | --- | --- |
| fine detail (edge density) | 0.145 | 0.567 |
| coarse detail | 0.097 | 0.312 |
| highlights (p95) | 0.206 | 0.427 |
| saturation | 0.218 | 0.306 |
| mean luminance | 0.083 | 0.168 |

The highlight figure is the one to read twice: at p95 0.206 against 0.427,
essentially nothing in our frame carries a specular highlight.

### Verification

gdUnit4 **216/216, 0 errors, 0 failures**. The capture passes
`evidence_gate.py --visual` under the amended rule and prints its caveat.
`replay_end_state_hash` is recorded as the baseline for every round that
follows, which is how a cosmetic change proves it stayed cosmetic.

### What this did not settle

- **Nothing about how the game looks has changed yet.** This round moved the
  measuring apparatus, not the pixels. Every gap above is still open.
- **The exposure anchor has to be re-solved on Forward+**, and that is a
  lighting job. The ring rig going 2.2 → 4.5 in round 2 solved a
  Compatibility exposure problem.
- **No performance claim is available from this machine at all**, and none
  is made. Volumetric fog, lightmaps and crowd LODs all cost real frame time
  that is unmeasured here.
- `compare_frame.py`'s tolerances are engineering values chosen to flag
  roughly the right things. They trace to no reference measurement.

## Gauntlet: the ring, its lighting and its materials (round 3)

Three builders in parallel, in separate worktrees with disjoint file
ownership, each running its own bounded loop against `VISUAL_BAR.md`, with
this session as the standing critic between rounds. The first round of any
visual slice ever judged on the pipeline the game ships.

### What landed

- **Lighting** (`core/lighting/arena_lighting.gd`, new). A real rig replaces
  emission-as-lighting: ring key and top fill on the truss, a cool rim pair, a
  twelve-fixture house wash aimed outward at the bowl, a stage wash, and fog
  volumes the key fixtures light through. Tonemap, glow and SSAO on the
  Environment; ambient down from 0.35 to a bounce floor of 0.06.
  `_house_lit()` survives, demoted from *the* lighting to a floor for faces no
  fixture reaches — with the argument, which is correct, that emission has no
  falloff, casts no shadow and puts no rim on anything, so a hall lit by it
  cannot satisfy priority 2 in principle.
- **Materials** (`core/materials/material_library.gd`, new). One resolver for
  named materials: full map sets, texel density expressed as a physical
  `tile_metres` rather than a repeat count, metallic asserted 0.0 or 1.0 in
  code, mipmaps back on. Candidate colour maps were *scored* rather than
  chosen by eye — rescaled to the pixel size their tile actually occupies in
  the wide shot and run through the edge count — and four of six measured
  0.000–0.034 at that scale, i.e. flat colours with a file behind them.
- **The ring** (`core/ring/ring_builder.gd`, new). Sagging rope tubes at three
  heights, turnbuckle pads with straps and buckles, post caps, a pleated
  apron, steel steps, and a woven canvas carrying an original centre mark. The
  frozen dimensions are asserted at runtime rather than merely commented, and
  the ring's colliders stay authored in `ring.tscn` untouched: rope *sag* is a
  displacement of the rendered mesh only.

### Measured

Forward+, software-rasterised, against `wide_standoff_broadcast_angle.jpg`:

| | before | after | reference |
| --- | --- | --- | --- |
| saturation | 0.220 | **0.311** | 0.306 |
| mat luminance | 0.172 | 0.359 | 0.43–0.49 |
| highlights p95 | 0.210 | 0.473 | 0.427 |
| mean luminance | 0.083 | 0.111 | 0.168 |
| fine detail | 0.327 | 0.273 | 0.614 |
| coarse detail | 0.212 | 0.202 | 0.343 |
| void fraction | 0.063 | 0.015 | 0.010–0.066 |

gdUnit4 **216/216**, and `replay_end_state_hash` **byte-identical** — which
is the whole evidence that three agents rebuilding the look of the game
touched no gameplay.

### The critic's own tools were wrong twice, and a builder caught both

This is the part worth keeping. `compare_frame.py` was written here to give
priorities 2 and 3 numbers for the first time. A builder disputed its output
instead of accepting it, and was right twice:

1. **It compared a 1280×720 render to a 640×364 still without resampling.**
   Edge density is a rate per pixel, so our frame spread the same incident
   over four times the area. One unchanged frame measures 0.147 native and
   0.315 at the reference's size.
2. **It thresholded an absolute *linear* gradient.** A surface cannot produce
   a gradient larger than its own level, so at the 0.014–0.020 linear the
   house-lit hall renders at, the threshold demanded 50–70% local contrast
   while the mat cleared it with 2%. Measured: edges registered on 0.089 of
   dark pixels against 0.199 of bright ones — a 2.2× bias against exactly the
   surfaces the arena is made of.

Both fixed. The deficit survives at about **1.8×**, stable across every
threshold tried, so the direction was right and only the magnitude was wrong.
Every number this project published from the broken version — including the
briefs the builders were working to — was overstated and has been restated.

A third caveat, found while tuning: the video wall owned 36.5% of the
above-p95 pixels, and dimming it cost fine detail **0.361 → 0.273**. A large
blown rectangle against a dark backdrop manufactures edges and glow
gradients, so edge density can be inflated by the very defect being fixed.
The lower number is the honest one.

### What this did not settle

- **The exposure anchor is still unfinished.** The mat reads 0.359 against a
  0.43–0.49 band. It moved a long way from 0.172 and it is not there.
- **Fine detail is 0.273 against 0.614**, the largest open gap on the board,
  and it went *down* on the landed build for the reason above.
- **The turnbuckle pads are the wrong shape** — full-height squared-off
  towers where a real pad is a fat cushion at rope height. They dominate the
  ring-corner shot.
- **The crowd is still two-box impostors**, and at ring-corner range they read
  as flat rectangles. **Ringside is still a black void**: no announce table,
  no chairs, no barricade detail.
- **No performance claim is available from this machine**, and none is made.
  Volumetric fog, a twelve-fixture wash and 1K map sets all cost frame time
  that is unmeasured here.
- Fixture count, fog density, rope sag depth and turnbuckle proportions trace
  to **no reference measurement**. They are coverage decisions, named as such.
