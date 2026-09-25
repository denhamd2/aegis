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
- `game/scenes/roman_match.tscn` — playable Roman model variant using the
  supplied character asset and the shared controller/animation systems.
- `gauntlet/anchor/ARCHITECTURE.md` — the contract gauntlet builders may
  not violate. Read this first.
- `gauntlet/refs/` — the reference corpus: measured timings, camera
  behavior, HUD layout, and feel, all traceable to footage under
  `gauntlet/refs/raw/` (gitignored — drop clips locally). `refs/ring.md`,
  `refs/stage.md` and `refs/arena.md` additionally record the external ring,
  entrance set and ice-hockey arena the build's *look* is matched to; like the
  footage, they are reference-only and no asset from them is committed.
- `gauntlet/status/` — `slices.json` + the generated
  `gauntlet-status.html` tracking every gauntlet slice's round count,
  verdict, and current largest gap.
- `tools/capture/` — the capture harness driver (`run_capture.sh`), the
  evidence gate (`evidence_gate.py`) that must pass before any critic sees
  a capture, and the status-page generator.
- `tools/blender/` — `arena_bowl.py`, which builds the seating bowl and shell
  (`game/assets/environment/arena_bowl.glb`) from the constants in
  `game/core/arena/arena_builder.gd`, and `build_arena.sh`, which runs it. The
  .glb is committed; Blender is not needed to build, run or test the game.
- `.github/workflows/` — `ci.yml` (gdUnit4 suite, evidence-gate fixtures,
  status-page staleness) and `pages.yml` (the playable Web build).

## The front end

The game boots into `game/scenes/title.tscn` — the landing screen: the
wordmark, a menu (FIGHT / CONTROLS / QUIT), and the wrestler select that
picks the two men who walk to the ring. The roster lives in one table,
`game/core/ui/roster.gd`, and holds the two characters the repo has models
for; adding a third is an entry plus its model scene, and nothing in the
screen names a wrestler.

The whole screen is drawn rather than built from themed Control nodes (see
`game/core/ui/title_screen.gd` for why), so it lays out identically at any
resolution, including whatever size the browser canvas happens to be. The
controls card reads the live `InputMap`, so a rebind in `project.godot`
cannot leave it lying.

`game/scenes/play.tscn` is unchanged and still goes straight to a match with
no menu — it is what `tools/capture/` and the probes point at.

Two probes cover the screen:

```
xvfb-run -a godot4 --path game --resolution 1600x900 \
    tools/probe/title_shots.tscn -- --out /tmp/title.png   # every phase
xvfb-run -a godot4 --path game --resolution 1280x720 \
    tools/probe/title_launch.tscn -- --out /tmp/launched.png  # pick -> match
```

`tools/probe/title_video.tscn` records the whole opening — landing screen,
select, VS card and the match it launches — as a frame sequence to encode:

```
xvfb-run -a godot4 --path game --resolution 1280x720 --fixed-fps 30 \
    tools/probe/title_video.tscn -- --out /tmp/frames --match-seconds 45
ffmpeg -framerate 30 -i /tmp/frames/f_%05d.jpg -c:v libx264 -crf 21 \
    -pix_fmt yuv420p out.mp4
```

`--fixed-fps 30` against the project's 60Hz physics is two physics ticks per
rendered frame and a fixed delta, so one saved frame is exactly 1/30s of match
time and encoding at 30 plays back at real speed. Frames are JPEG: a minute of
720p PNG is over a gigabyte, and the difference does not survive H.264 anyway.
Recording is far slower than real time under llvmpipe — budget ~20 minutes of
wall clock for a 50-second capture.

### Is anybody floating?

`tools/probe/floating_probe.tscn` takes each wrestler's **lowest bone in world
space, every tick**, and reports the highest that per-tick minimum ever gets:

```
godot4 --headless --path game --fixed-fps 6000 \
    tools/probe/floating_probe.tscn -- --seeds 1,2,3 --budget 20000
```

A man standing, lying, rolling or being thrown always has some part of him at
or near the canvas; a man floating has none. Written because the retarget bug
that parked Roman's whole body at y=2.0 through every knockdown was invisible
to every other instrument in the repo — `ladder_probe` and `pin_probe` read
state and signals, and the fault was entirely in where the bones were.

A brief excursion is the game working, so the report distinguishes them: an
excursion above 1.20m has to last 30 ticks (half a second) to count as a
float. Measured on seeds 1-3 after the fix, every excursion is inside
`GRAPPLE_HOLD` and lasts 6-15 ticks — a man in the air mid-throw.

### The roster is what the AI probes fight

The four AI-vs-AI probes — `ladder_probe`, `pin_probe`, `feel_probe` and
`reachability_probe` — attach roster wrestlers through the same
`TitleScreen.configure_match()` call the title screen launches a match with.
They default to **Roman vs Cody**, and take `--wrestlers` to say otherwise:

```
godot4 --headless --path game --fixed-fps 6000 \
    tools/probe/ladder_probe.tscn -- --seeds 1,2,3
godot4 --headless --path game --fixed-fps 6000 \
    tools/probe/ladder_probe.tscn -- --seeds 1,2,3 --wrestlers cody,roman
```

Each run prints the pair it fought before its first seed, and an id that is
not on the roster stops the probe rather than falling back to a default —
a probe that quietly fought somebody else has measured nothing.

`scenes/match.tscn` stays the light fixture with no model on it: the suite
instantiates it in ten places, several per test, and `roman_reigns.glb` alone
is 52MB. The models are attached per run, in the probe.

**This does not move any measurement in this README.** Combat resolves from
MoveDefs and the seed, never from the mesh, and `ladder_probe --seeds 1,2,3`
returns byte-identical output before and after the change — same winners,
tick counts, momentum peaks and state histograms. It costs load time only:
41s to 54s for three seeds.

## Playing it in a browser

`.github/workflows/pages.yml` exports the `Web` preset from
`game/export_presets.cfg` and publishes it to GitHub Pages on every push to
`main` or the active working branch.

**That build is for playing, not for judging.** Two differences from the
build every measurement in this README was taken on:

- **It renders on `gl_compatibility`.** `project.godot` asks for
  `forward_plus`, but Godot's Web platform falls back to the compatibility
  renderer, and `gauntlet/refs/VISUAL_BAR.md:64-86` is explicit that a
  `gl_compatibility` frame cannot judge this project's visual bar — the
  exposure anchor and every silhouette number were solved on `forward_plus`.
  Expect the ring to read differently in the browser than in the captures.
  Never cite a Pages screenshot as visual evidence.
- **It is single-threaded.** `variant/thread_support=false` in the preset,
  because Godot's threaded Web build needs `SharedArrayBuffer`, which needs
  COOP/COEP response headers, which GitHub Pages does not send. Threads off
  is what lets it load there at all.

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

## Roman Reigns: immediate next implementation block

The Roman variant's new content is real, but the project still has one
explicit Phase 3 gate to clear before the Roman package can be defended as
"playable": the live match path must reliably reach the paired moves, not
just the direct harness path. The immediate execution plan is:

1. Finish the missing Phase 1 reference measurements in `gauntlet/refs/`:
   - strike active/recovery timing
   - reversal window length
   - three-count cadence
   - ring-crossing run speed
   - feel/input latency
2. Stabilize the normal tie-up → grapple path in the live match flow:
   - AI closing behavior
   - grapple eligibility checks
   - move selection and handoff back to the FSM
3. Complete the remaining paired Roman grapple/reversal moves to bring the
   library up to the `ARCHITECTURE.md` scope.
4. Validate each move through the real match loop, not just through direct
   `GrappleRig.begin()` harnesses.
5. Tune the move timing and damage/momentum values only after the live path is
   trustworthy, using the measured corpus as the source of truth.

This is the current Phase 3 bottleneck for Roman Reigns: content exists, but
it still needs to be proven reachable and calibrated in the actual match
loop before the build is ready for gauntlet tuning.

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
pass. See `game/assets/characters/CREDITS.md` for attribution and the
provenance note (stand-in mesh only — no WWE-derived assets).

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
- Bowl rake and truss layout trace to **no reference measurement**; they are
  coverage decisions, held to the same rule as the momentum ladder. Stage
  proportions now trace to `gauntlet/refs/stage.md`, and the bowl's *plan*,
  seat value and stair nosings to `gauntlet/refs/arena.md` — which is what
  that sentence used to say was missing. Its rake, row counts and tier heights
  are still coverage decisions and are not claimed otherwise.
- The hall is built to **rink scale** — 60.96 x 25.91m of ice with 8.53m
  corners, the ring in the middle of it, the boards and the bowl measured out
  from there, and ~1,490 folding chairs filling the floor between the
  barricade and the boards. `gauntlet/refs/arena.md` has the derivation.
- The hall is **empty** — the two-box crowd impostors were removed on
  request, and the seats themselves (individual, at `SEAT_PITCH`, with the
  aisles left clear) are what fills it. That closes this bullet's old
  complaint that the crowd had no faces, no limbs and no reaction to the
  match by removing the crowd, not by fixing it; a hall with people in it
  again is a separate slice and would start from
  `arena_builder.gd`'s history. The stage has no branding and no entrance
  sequence uses it.

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

## Match the ring and ringside to an external reference (round 4)

Not a gauntlet round. A direct instruction: make the ring and the ringside
area look like [this Sketchfab
model](https://sketchfab.com/3d-models/wrestling-ring-76f8cc19b9ad458685313bad672ea49c)
as closely as possible.

**The asset is not in this repository and never will be.** Sketchfab's API
reports `isDownloadable: false` with no licence grant. It is matched by hand as
a *visual reference*, which is exactly the treatment `gauntlet/refs/` already
gives the WWE 2K stills, and what `ARCHITECTURE.md`'s IP guardrail requires.
The observations are written down in `gauntlet/refs/ring.md`; the image is not
committed, per the convention in `refs/raw/README.md`.

Three decisions were taken with the user before any code moved: ringside is in
scope but the entrance stage, truss and upper bowl are not; the palette matches
the reference *fully*, branding included; and the lighting rig is untouched.

### What changed

The ring was a branded broadcast ring and is now a plain one. Canvas: the blue
field, the chevron centre mark, the two secondary marks and the painted border
are gone, leaving white canvas with wear, scuff streaks and deep panel seams.
Ropes: thin, black, near-taut, no tape wrap. Posts: square matte-black slabs,
axis-aligned, no steel caps. Turnbuckles: the 0.37 × 1.13m branded vinyl pads,
their straps and buckles and the whole `_pad_vinyl()` texture are deleted, and
each rope now ends in a sleeve and a clevis. Skirt: flat neutral grey, no print
band, no folds. Steps: their own `ring_steps` key, bare bright metal.

Ringside: the barricade became a run of discrete panels with cap rails and
outward legs; the slab got its scored panel grid; and the first four rows of
the lower bowl were flattened onto the floor and filled with 470 imported
folding chairs on their own MultiMesh — pointedly *not* sharing the crowd's
material, because `_crowd_material()` is a vertex shader that bobs whatever it
touches and a breathing chair is worse than no chair.

### The result: the silhouette bar, finally

All four of `VISUAL_BAR.md`'s figures are inside their bands, for the first
time on the renderer the game actually ships:

| | before | after | reference |
| --- | --- | --- | --- |
| mat luminance | 0.359 | **0.456** | 0.43–0.49 |
| mat ↔ wrestler A | 0.208 | **0.306** | 0.24–0.31 |
| mat ↔ wrestler B | 0.199 | **0.296** | 0.24–0.31 |
| wrestler ↔ wrestler | 0.009 | 0.010 | 0.00–0.07 |

This is not a lighting fix and no lighting was touched. It is arithmetic the
ring owned the whole time: the blue mat rendered *below* its own exposure
anchor, and a wrestler cannot sit 0.24–0.31 beneath a mat that is only at
0.359 — the ceiling was the mat. A white canvas raised it.

The value was solved, not picked. Two measured points (linear albedo 0.402 →
0.359 and 0.801 → 0.590) fit `rendered ≈ 0.692 · L^0.719` through this
tonemap, and 0.46 comes back as effective albedo ≈ 0.78 sRGB. The first pass
at a white mat, taken by eye, landed at 0.590 — overshooting as badly as the
blue one undershot.

### The cost, booked rather than buried

Measured on `wide_broadcast` against the same reference still:

| | before | after | reference |
| --- | --- | --- | --- |
| saturation | 0.311 | 0.216 | 0.306 |
| warm/cool | −0.337 | −0.153 | −0.333 |
| coarse detail | 0.209 | 0.137 | 0.343 |
| fine detail | 0.361 | 0.320 | 0.614 |
| void_fraction | 0.015 | 0.024 | 0.010–0.066 |

Saturation and warm/cool went from dead-on to clearly outside. That is the
instruction, not a slip. The reference is near-monochrome, the mat is 212k of
921k pixels in that frame, and replacing a blue mat carrying a high-contrast
mark with a neutral white one carrying wear cannot move those numbers any
other way.

What could honestly be recovered was recovered. The ringside tints were pulled
*halfway* back toward the hall's cool push rather than all the way to neutral,
at identical linear luminance so `_house_lit()` returns the same energy and the
house level is untouched. And the canvas seams were widened from 1.4cm to 4cm —
a number set by the measurement rather than by the thing being modelled, since
coarse detail is read off a heavily downscaled frame in which a 1.4cm seam does
not exist at all. That bought coarse detail 0.124 → 0.137. Going further would
mean putting decoration back on the mat, which is the thing the instruction
removed.

### Two things the white mat exposed

Both were already there and both were hidden by the blue.

The canvas weave has a 4-texel period, and its normal map re-lights it every
frame — which is precisely what that normal map is *for*, and precisely why the
two thread directions resolved into diagonal corduroy across the entire mat the
moment the field went white. Fixed by jittering each thread's own weight so the
pattern cannot beat with the pixel grid, and by cutting `CANVAS_RELIEF` from
4.0 to 1.5.

`ring_post` carried Metal032, which brings a *polished-metal roughness map*,
and a roughness map multiplies the scalar — so raising `roughness` to 0.94 did
nothing and the posts kept a hard vertical specular streak that read as moulded
plastic. The key now carries no map at all, which is also what the reference
shows: flat black padding returns almost nothing.

### Unchanged, and verified so

Suite 216/216, 0 failures, 107 orphans, exit code 101 — byte-identical to the
pre-round baseline, `test_determinism`, `test_replay_roundtrip`,
`test_camera_framing` and `test_wrestler_colorway` included. No
`CollisionObject3D` was created, moved or resized: the four `ring_ropes` bodies
`wrestler_controller.gd` bounces off, the 6m mat, the mat surface at y = 0 and
the ropes at ±3.1 are all where the measurement chain left them.

### Not judged here

- **The folding chair has no licence.** It arrived as a bare FBX with no
  licence file, no author and no source URL. This was raised against
  `ARCHITECTURE.md`'s "'free to download' is not a licence" rule, and the
  project owner decided to use it anyway. Recorded in
  `assets/environment/CREDITS.md` under its own heading rather than filed
  beside the CC0 scans, so nobody later mistakes it for one.
- **Material believability** remains UNJUDGED under llvmpipe, as every previous
  visual round has said.
- **No performance claim.** 470 chairs at 1448 triangles is 680k triangles in
  one draw call, on top of everything already in the hall. It was never
  measured on hardware and nothing here claims it is cheap.
- **`fine detail` is still far short** (0.320 against 0.614) and this round did
  not close it. Cutting the weave's relief to kill the corduroy cost some of
  it; `normal_scale` was returned to 0.75 to get part of that back, which is a
  compromise between two defects rather than a fix for either.

## Gauntlet: the Roman model's face and hair (round 2)

Not a scheduled round either. The user looked at a pair of art shots and asked
why one of the two Roman Reigns was bald and appeared to have holes in his
trousers, then — after a Sketchfab reference of the source model — why the
hair, beard, eyes and eyebrows were all sitting in the wrong place. Seven
passes.

### One bug was behind three of the four complaints

The model is rigged on **two** skeletons, and the split is not head-vs-body,
it is **body against everything worn**: 114 bones drive body, head, eyes, mouth
and teeth; 471 bones drive bottoms, beard, hair, wrist tape and shoes.

`WrestlerController` applied `physique_height` to `get_game_skeleton()`, and
`_find_body_skeleton()` selects `bone_count < 200` *by design* — so the
471-bone skeleton was never scaled at all. Measured on a live match:

| | body skeleton | worn skeleton |
| --- | --- | --- |
| WrestlerA | 0.98 | 1.00 |
| WrestlerB | 1.05 | 1.00 |

That single line explains all three reported defects at once. B's head was
inflated 5% inside hair that stayed at 1.0, so his scalp pushed through the
crown and he rendered bald while A, at 0.98, did not — one model, two heights,
reported as "they look like different men". The same mismatch pushed the body
through the trousers, which is the tan blotching on the thighs and shins that
had previously been patched with `GROW_FIXES` as though it were a skinning
disagreement. And it sat the beard on a face 5% larger than the beard was
fitted to.

The fix is `RomanModel.apply_physique_height()`, which scales every skeleton
the model is rigged on. `WrestlerController` falls back to the old
single-skeleton path when the model does not implement it, so the base rig is
untouched.

### The user was right twice, and I said otherwise twice

A drift test showed the beard-to-head offset was **constant**, and I read
"constant" as "correct" and reported back, twice, that the beard was not
misplaced. It was constant *and* wrong: a fixed offset is exactly what a
5%-larger head under an unscaled beard produces. Both times the user said it
still looked wrong, and both times they were describing the real bug. The
measurement was sound; the inference from it was not.

### The rest of the face

- `hair_ALPHA_skinned_001` (`Material.012`) had **no albedo texture at all**
  and drew as a solid slab z-fighting the real hair. Hidden — and confirmed to
  render nothing even when un-hidden and handed a mask.
- `eyelash_skinned` had no mask and was the black bar across the eyeball;
  `eye_caruncle_skinned` was sampling the *body* atlas and was the pink
  crescent under the lid. Both hidden. The eye reads correctly on the existing
  iris and pupil geometry.
- Beard and scalp moved from `ALPHA_SCISSOR` to `ALPHA_DEPTH_PRE_PASS`. A
  scissor threshold is a binary keep/drop; strand cards need the gradient.
- The beard mask was repainted by **interleaving horizontally-shifted copies**
  of itself, taking ≥0.5 alpha coverage from 0.0963 to ≈0.29 against the scalp
  mask's 0.3204. That adds strands *between* strands. Dilation was tried first
  and is wrong: at radius 7 it fattens each existing strand until the moustache
  renders as a slab.

### Verified

Hair- and beard-to-head offsets are constant to four decimal places across 200
frames of live match (the change at frame 200 is a yaw permuting x and z at
identical magnitude, not drift). QA leg shots are clean front and side, both
wrestlers, across faceoff, tie-up and action. Suite 246/246 throughout.

### Process note worth keeping

Godot serves textures from `.godot/imported/`, so a plain run renders the
**old** mask after the generator has written a new one. Two comparison renders
were wasted and a wrong conclusion nearly published — "dilation does nothing" —
before the cache was suspected. `godot4 --headless --path game --import`
between generating and looking. It is now written at the top of
`tools/assets/build_roman_hair_alpha.py`.

### The probe earned its keep on its first working frame

`extreme_poses.gd` ran properly for the first time and immediately falsified a
claim written two commits earlier. The comment above `GROW_FIXES` said the
0.006 grow "still covers ordinary skinning disagreement in extreme poses". It
does not: HIT_REACT, WrestlerB, frame 17 has an open hole at the hip with skin
through it.

That is *not* the scale bug coming back — the systematic 5% mismatch is gone,
and this residual is ordinary skinning disagreement under deformation. The
bottoms grow went 0.006 → 0.018, which closes the hole on the same seeded
frame with no visible inflation at the waistband or knee. 0.018 is not the
minimum; it was tried first and worked, and the intermediate values were never
rendered. The comment now says so.

Hair and beard hold up across all three states the probe reached (HIT_REACT,
DOWN, GETUP): no clipping through the mat, no detachment, no crown showing.

### What this round did not settle

- **Beard edge definition and the hairline's fringe** are still softer than the
  reference. Both are strand-card *geometry*: no threshold, blend mode or mask
  edit reaches them, so closing the gap means editing the cards themselves.
- **Pin and submission poses are unverified.** `tools/probe/extreme_poses.gd`
  covers DOWN, MOVE_EXEC, HIT_REACT and GETUP — the states a match reaches
  early. The pin states need the momentum ladder climbed first, which does not
  finish under a software rasteriser.
- The probe was committed once **with a parse error** (Variant inference on
  `WrestlerFSM.State.keys()`), which meant a background run failed silently
  while the silence was being attributed to a slow rasteriser. Found with
  `--check-only`; fixed in its own commit rather than amended away.

## Fix: the shipped build was neither Roman nor a clean canvas

Two defects reported off the deployed Pages build, both real, both mine.

### The deployed game was not Roman vs Roman

`project.godot` ships `scenes/match.tscn`, and `match.tscn` never set
`character_model_scene`. So it used `WrestlerController`'s default,
`wrestler_base.glb` — the box-built mannequin. Every Roman frame in this repo
came from `scenes/roman_match.tscn`, which overrides that property and which
**nothing ships**. Ten commits of work on the Roman model reached the
screenshots and never reached the game.

The first attempt set the model on `match.tscn` directly, and CI rejected it:
**246 tests, 2 errors, 6 failures**, all in `test_wrestler_colorway.gd`, all
`null instance` on `.mesh` and `.scale`. That suite reaches into the
*mannequin's* node structure — the gear meshes, the head meshes, the
`Mannequin` MeshInstance3D — and the Roman model has none of them.

Two corrections belong here, because both were asserted before they were
checked. The commit that made this change predicted that suite would "pass,
and measure something the frame no longer contains"; it did not pass, it broke
outright. And the commit that fixed it blamed a **ten-minute** CI slowdown
from the 52MB model. There was no slowdown: the tests step ran **42 seconds**
and failed on assertions. That figure came from polling the GitHub job API
across container suspensions and reading repeated `in_progress` as elapsed
time — the same misreading as the `pgrep` one in the round above, one layer
out.

The split below is still right, and for the reason the failures show rather
than the one first given: a test fixture and the shipped scene were the same
file, and the fixture's structure is load-bearing for a suite that the shipped
scene has no obligation to satisfy.

They are separate now. `scenes/play.tscn` inherits `match.tscn`, attaches the
Roman model to both slots, keeps `WrestlerA` human, and is what
`run/main_scene` points at. `match.tscn` goes back to the mannequin and stays
the light fixture the suite builds against. It is the same split
`roman_match.tscn` already used for the AI-vs-AI probes.

One consequence, stated rather than buried: `attire_body`, `attire_accent`
and `skin_tone` are **inert for rendering in the shipped scene**. The Roman
model brings its own textures and nothing in `RomanModel` reads those
properties. `test_wrestler_colorway.gd` still asserts on them, and still
passes — but it asserts against `match.tscn`, which is no longer what anybody
plays, so it now guards a colourway that reaches no shipped pixel. The same
applies to the `wrestler ↔ wrestler ≤ 0.07` figure in `VISUAL_BAR.md`: two
instances of one model are trivially identical, so that number stops being
evidence of anything. Both want revisiting; neither was changed here.

### The canvas had ruled black lines across it

Round 4 widened the panel seams from 1.4cm to 4cm to buy back the coarse
detail the deleted centre mark had been carrying, and deepened them to a flat
`-0.26` trench with a flat `+0.060` lip. Two hard steps. On a near-white mat
that is five black stripes ruled across the largest surface in the frame, and
that is exactly how it was reported.

The seam is now one smoothed profile — feathered dip, feathered lips — with
the trench cut from 0.26 to 0.10. Measured on the generated texture, the
column contrast across a seam falls from **78 to 45** of 255.

`SEAM_HALF` did not move. Round 4's own note says width is the part that
survives the downscale the coarse-detail metric reads, and depth is the part a
viewer reads as a painted line; this trades the second and keeps the first.

**Not measured: the coarse-detail figure.** Re-running `compare_frame.py`
needs a `wide_broadcast` capture, and captures do not complete in this
environment — the container suspends between turns, so a render that takes
minutes of CPU never accumulates them. The expectation from round 4's own
reasoning is that the drop is small, since width is unchanged. That is a
prediction, not a result, and it is not being recorded as one.

## Feature: depth fog for the browser build (the second attempt)

The hall reads flat in the browser because `FogVolume` is Forward+ only —
Godot's Web platform falls back to `gl_compatibility`, `_build_fog_volumes()`
returns early there, and the far stands end up at the same clarity as the
ropes. `Environment` fog *is* supported on that renderer, so it can put air
back.

**Attempt one failed and is worth recording.** It used the default
`FOG_MODE_EXPONENTIAL`, which begins at the near plane: it fogged the mat and
the wrestlers along with the hall, and the result was a grey wash. It moved
numbers and it made the frame worse, so it was reverted.

`FOG_MODE_DEPTH` is what that attempt lacked. It takes a begin distance, so
the fog can start *beyond the ring* and never touch the subjects. The camera
sits 3.2–9.0m from the pair's midpoint and the far ropes are at most 3.1m past
it, so no ring geometry is ever more than ~12.1m from the lens. `FOG_BEGIN` is
13.0.

The first pass at *this* attempt was also wrong, in the opposite direction:
`fog_light_energy` at 1.0 against a tint of `(0.62, 0.68, 0.86)` made the fog
**add** light, turning a dark arena milky white. The fog colour is the value
distant geometry fades toward, so in a dark hall it has to be dark.
`FOG_ENERGY` is 0.12, landing the tint just under the crowd's own level.

Measured on the same `gl_compatibility` frame, before against after:

| region | before | after | delta |
| --- | --- | --- | --- |
| mat centre | 0.4466 | 0.4466 | **+0.0000** |
| wrestlers | 0.0758 | 0.0761 | +0.0003 |
| near chairs | 0.0247 | 0.0252 | +0.0005 |
| mid crowd | 0.0001 | 0.0024 | +0.0023 |
| upper crowd | 0.0023 | 0.0147 | +0.0125 |

That is the whole claim: nothing in front of the ropes changes, everything
behind them gains depth. **These are compatibility-renderer numbers and
`VISUAL_BAR.md` rules those void for judging the bar — that still stands.**
They are a before/after differential inside one renderer, not a gauntlet
measurement, and they are not offered as one.

Forward+ is untouched and verified so: instantiating `play.tscn` headless
(which reports `forward_plus`) leaves `fog_enabled = false` and
`volumetric_fog_enabled = true`. That same fact means **the test suite never
exercises this path** — headless is Forward+, so the guard always takes the
early return. It is covered by rendered frames only, via
`tools/probe/compat_shot.gd`.

`fog_sky_affect` is 0.0 and that is load-bearing rather than tidiness: the
background is a flat near-black and `VISUAL_BAR.md` bands `void_fraction` at
0.010–0.066. Letting fog lift the void would eat that band directly, and
lifting the void was part of what made both failed passes read as a wash.

## Fix: no lines on the canvas at all

The softened seams still read as lines, and the project owner asked for a mat
without any. They are deleted — not softened again. `_canvas()` now draws
weave, wear noise, the streak fields and the centre traffic darkening, and
nothing with an edge. The `SEAM_*` constants are gone; `CANVAS_PANEL` stays as
the documented 1.2m mill width for whatever models panels next, since the next
attempt should be a normal map or an albedo shift rather than a line.

**The cost, measured rather than warned about.** `compare_frame.py` on the
same fixed-park Forward+ frame, seams against no seams:

| | with seams | none | delta |
| --- | --- | --- | --- |
| edge_density_coarse | 0.1116 | 0.1088 | −0.0028 |
| edge_density_fine | 0.3222 | 0.3176 | −0.0046 |
| tile_contrast | 0.8472 | 0.8471 | −0.0001 |
| mean_luminance | 0.0965 | 0.0968 | +0.0003 |

Far smaller than round 4's framing of the seams would suggest, and the reason
is that most of their contribution had already gone when the trench was cut
from 0.26 to 0.10 in the previous change. What was deleted here was the
remainder.

**These are not comparable to round 4's 0.137.** That figure came from the
`wide_broadcast` shotlist frame; this is `tools/probe/compat_shot.gd`'s fixed
park, which sees a different amount of ring and hall. It is a valid
before/after differential on one identical framing and nothing more. The
shotlist number has not been re-measured.

This is a look decision overriding a measurement, stated as such. If coarse
detail ever has to be recovered it comes from the weave, the wear and the
streaks — not from putting lines back.

## Fix: the apron banner was cropped, and the browser was over-saturated

Three things reported off screenshots. Two were real defects; one was a doubt
that a measurement settled.

### The banner was showing a third of itself

`ApronNorth`/`South`/`East`/`West` used a `BoxMesh`, and Godot unwraps a box
into a **3x2 atlas** — measured, not assumed:

```
outer face (normal 0,0,1):  u=[0.000..0.333]  v=[0.000..0.500]
```

So the apron sampled the **left third, top half** of a 1929x544 banner. The
AEW mark is centred and the right-hand TNT roundel is at the far edge, so
neither was ever inside that window. The `uv1_scale = (2,1,1)` that was meant
to fix the aspect just stretched the crop to `u=[0..0.667]`.

The mesh is a `QuadMesh` now — one face, clean `u=[0..1] v=[0..1]`, verified
the same way. The box's 0.1m of thickness is not missed; `refs/ring.md`
describes a flat hanging skirt.

The first version of this fix then showed the banner **twice** per side, on
the reasoning that one copy stretched across a 7.333-aspect face would be
2.07× too wide for a 3.546-aspect image. That reasoning was right and the
conclusion was not: tiling is not the only way to keep proportions. One copy
now, fitted rather than stretched or repeated —

```
scale.x  = 7.3333 / 3.5460 = 2.0681     the face is 2.07 banners wide
offset.x = -(2.0681 - 1) / 2 = -0.5340  centre it
texture_repeat = false                  clamp, do not tile
```

— which works because both edge columns of the supplied artwork are its own
near-black cloth, sampled rather than assumed: left `(2,2,2)`, right
`(34,38,37)`. The clamp extends that fabric, so the marks sit centred on an
unbroken skirt with no visible join.

A second bug came out with it. `ApronEast` and `ApronWest` both carried
`rotation.y = +1.5708`, which was harmless on a box (all six faces draw) and
would have made West face *into* the ring as a single-sided quad. West is
`-1.5708` now.

### The browser build really was over-saturated

Reported by eye, confirmed by `compare_frame.py`, and the interesting part is
that **the two renderers err in opposite directions**:

| | mean_saturation | reference |
| --- | --- | --- |
| compatibility (browser) | 0.394 | 0.306 |
| forward_plus (native) | 0.201 | 0.306 |

`match.tscn` sets `adjustment_saturation = 1.22`. That lift is right for
Forward+, which sits *under* the reference — and it was being applied to a
renderer already sitting over it. `COMPAT_SATURATION` now overrides it to
**0.82** on compatibility only, same guarded pattern as the depth fog, giving
**0.312 against the reference's 0.306**.

0.82 was solved, not picked, and the first guess was wrong: reasoning that
`0.394 / 1.22 ≈ 0.32` predicted 1.0 would land it, and 1.0 actually measured
0.351. The adjustment is not linear in the way that arithmetic assumed.

### The wrestlers are not floating

Raised as a doubt off a screenshot, which cannot settle it — at that distance
a foot on the canvas and a foot a centimetre above it are the same pixels.
Reading the lowest vertex of each wrestler's rendered mesh in world space,
after 90 frames of live match so the pose is real rather than the spawn frame:

```
WrestlerA  lowest_vertex_y = -0.0121   mesh = shoes_skinned
WrestlerB  lowest_vertex_y = -0.0130   mesh = shoes_skinned
```

The mat surface is `y = 0`. Both are ~1.2cm *below* it — sunk very slightly
into the canvas, not floating above it. That is inside a shoe sole's
thickness and reads as contact. Not a defect, and now measured rather than
argued about.

**Still not judged: the apron's brightness.** The artwork is complete but it
renders dark, because the rig is top-down and the skirt hangs below the mat in
its shadow. Round 4 recorded that a *bright* apron band took `void_fraction`
to 0.002 against the 0.010–0.066 band, so lifting it is a known-dangerous
direction, and `void_fraction` needs the silhouette harness, which does not
complete in this environment. Left alone deliberately rather than changed
blind.

## Fix: apron logos sized and centred, and the feet question settled properly

### Bigger, and centred on the ink rather than the box

The banner rendered once at the artwork's own proportions, and the logos still
read small. The cause was not the mesh or the fit: the **supplied image**
carries wide dark-cloth margins, so the marks occupy only part of a picture
that already spanned the apron full-height. Bigger therefore meant cropping
that margin, not stretching.

Measured off the artwork at a threshold that separates the marks from cloth
highlights: marks span `v 0.246–0.721` (47.4% of image height) and
`u 0.094–0.913`. Holding the no-distortion ratio `scale.x/scale.y = 2.0681`
and solving for the marks filling 70% of the apron's height gives
`scale (1.4012, 0.6775)` — a 1.48× magnification, marks at 70% of height and
58% of width, `scale.x/scale.y` exactly 2.0681 so nothing is stretched.

The first attempt at centring was **subtly wrong and looked it**. Centring the
marks' *bounding box* put it at apron `v = 0.5000` exactly — and it still read
as sitting low, which is what was reported. The reason is that the ink is
bottom-heavy: "WRESTLING" and the mass of the AEW block sit lower than the
sparse "ALL ELITE" line above. The bounding box was centred; the visual weight
was not, landing at `v = 0.5133`. Centring the **brightness-weighted
centroid** (`v 0.4925`) instead moves the art up 0.0090 in v, about 1.3% of
the apron height, and puts what the eye reads on the centre line.

### The wrestlers are standing on the canvas

Asked twice, and the first two answers were built on measurements that do not
support them. Both are recorded in `tools/probe/apron_and_feet.gd` so neither
gets repeated:

- **Mesh AABB** (`-0.0121` / `-0.0130`, reported earlier as settled). For a
  *skinned* mesh `get_aabb()` returns the rest pose and does not follow the
  animation. The tell was there and I missed it: both wrestlers returned the
  same two numbers in completely different poses, across separate runs.
- **Bone global pose.** It does move with the animation, but its heights
  disagree with the rendered frame — during a strike it put `J_Head` *below*
  `J_Hips` with the feet above both, an upside-down wrestler, while the render
  of that same frame shows him upright. Whatever space those poses are in, it
  is not the one the mesh is drawn in.

What settles it is making the question visual: camera above and outside,
looking down at the feet so the near-white canvas fills the frame behind them.
A black boot against a white mat shows a centimetre of gap plainly. **In both
IDLE and STRIKE, for both wrestlers, the soles are in contact.** Supporting
facts from the scene: the canvas mesh top is at `y = 0.0000` and each
wrestler's capsule bottom is at `y = 0.0000`.

An intermediate test — camera *at* mat level, so the canvas is edge-on at the
horizon — appeared to show a 15cm gap and was wrong: at that distance it was
framing the other wrestler's boot at a different depth. It is not in the probe.

## The entrance set: a curved video wall, two lit rings, a floor that reflects

The entrance end of the hall was grey-box, and honestly labelled as such: a
flat 14 x 5.4 box called `StageScreen` with a doc comment explaining that it
was *deliberately* blank ("a logo there would be branding"), two plain boxes
and a lintel for `TunnelMouth`, and a matte deck. The note above at
"Gauntlet: the arena the ring stands in" listed the missing entrance sequence
under what that round did not settle. This round settles the set, though not
the sequence — there is still no walk-out.

The owner supplied five photographs of the AEW *Dynamite* set and the
graphics-package clip that plays on its wall, and asked for the stage to match
them. `gauntlet/refs/ring.md` is explicit that the entrance stage, ramp, truss
and video wall "have no counterpart in the reference", so this work was
unconstrained by the ring reference; the photographs become its reference
instead, and they are committed with the rest of the corpus at
`gauntlet/refs/stage/`, recorded in a new `gauntlet/refs/stage.md`.

The clip is third-party broadcast material carrying a real promotion's marks.
It is filed in `game/assets/environment/CREDITS.md` under provenance
UNVERIFIED, beside the folding chair and for the same reason: the owner's call
on the owner's repository, recorded so nobody reading the tree later mistakes
it for something licensed.

### Godot cannot play MP4, and the fix has a second job

Godot's built-in video backend is Ogg Theora and nothing else, so the supplied
MP4 had to be transcoded. `tools/assets/build_stage_video.sh` is that
conversion, committed rather than run once by hand. Quality 4, measured: q7
encodes the 78-second clip at 53MB and q4 at 23MB with no difference this wall
can show — it is 18m of geometry seen from 28m away through a bloom threshold,
which is not where a bitrate is worth spending.

The script also cuts one still frame, and that still is the more interesting
asset of the two, because it does two jobs that turn out to be the same job:

**Captures must be frame-identical.** `CaptureHarness.ART_SHOTS` exists so
round N and round N-1 can be compared frame for frame, and `stage_wide` looks
straight at this wall. A freely playing video destroys that — the frame on the
wall becomes a function of how fast the machine decoded.

The obvious fix is to play and then seek to a fixed position. That is not
available: **`VideoStreamPlayer.stream_position`'s setter is a no-op for
Godot's built-in Theora backend.** So `StageVideo` does not start the player
at all under `--art-shots`, `--silhouette-shot` or `--capture-output`; it
binds the still through the same code path instead, and every capture then
renders the same pixels by construction. The same still is the fallback when
the clip is missing or fails to decode, which is why it is one asset and not
two.

Verified, by capturing the art shots twice and diffing:

| region of `stage_wide` | pixels differing between two runs | max delta |
| --- | --- | --- |
| the video wall | 0.032% | 10/255 |
| the portal rings | 0.072% | 13/255 |
| the stage deck | 0.013% | 1/255 |

The wall is stable. The *whole frame* is not byte-identical — 1.3% of it
differs — and that predates this change: `crowd_bank`, which contains no stage
geometry at all, differs on 2.6% of its pixels, because the crowd's bob shader
is driven by `TIME`. Worth stating plainly rather than claiming a determinism
the shot list never had.

### The screen's brightness cap, revised on purpose

The old flat panel was capped at a self-emissive level of 0.35, and the note
on it recorded why: at 1.35 the screen owned the frame's top 5% of luminance
(p95 0.633 against the reference still's 0.427) with 36.5% of the blown pixels
inside the one grid cell it occupied.

That measurement was taken of a *blank* panel whose whole area sat at one
value. A picture's mean is far below its peak, and the set is now matched to
photographs in which the wall is plainly the brightest thing in the building.
So the cap was revised upward and re-measured rather than inherited. 1.10 was
tried first and is too much — it clipped the clip's own highlights and the
logo came back as a white slab with the colour gone, which is the same failure
1.35 had. 0.55 is where it landed.

Measured on `forward_plus` at 1280x720, before and after this round:

| | `stage_wide` p95 | `wide_broadcast` p95 | `stage_wide` void | `wide_broadcast` void |
| --- | --- | --- | --- | --- |
| before | 0.420 | 0.485 | 0.001 | 0.009 |
| after | 0.484 | 0.501 | 0.001 | 0.009 |

The broadcast framing — the one `compare_frame.py` defaults to — moved by
0.016 of p95 for a wall that went from blank to carrying a lit picture. The
void fraction did not move at all, and both frames sit *below*
`VISUAL_BAR.md`'s 0.010–0.066 band at both ends of the comparison, so that is
a standing property of these two framings and not something this round did.

The exposure anchor is untouched, which is the number that actually gates the
round:

    mat luminance          0.472   inside reference 0.43-0.49
    mat <-> wrestler_a     0.309   inside reference 0.24-0.31
    mat <-> wrestler_b     0.240   inside reference 0.24-0.31
    wrestler <-> wrestler  0.069   inside reference 0.00-0.07

That is not luck. Every fixture added for this set is **range-limited**, and
the range is the safety mechanism rather than the aiming: the nearest mat
corner to an accent fixture is 18.5m away and every one of them is capped at
12m, so none of them can reach the mat with six metres to spare.
`test_stage_set.gd` and the accent constants' own comments carry that
argument, so a later fixture cannot re-introduce the spill just by being added
without the thought.

### SSR is on, where SSIL and SDFGI stay off

The deck reflects. That needed two edits that are really one: `ssr_enabled` on
the Environment, and `arena_stage_deck` dropped from roughness 1.0 to 0.26 —
SSR shows nothing on a matte floor.

0.14 was the first value, with `ssr_fade_in/out` at 0.15/2.0, and it was a
mirror: the portals came back off the deck with their shapes still legible,
which is a wet floor rather than a lacquered one and pulled as much attention
as the fixtures casting it. 0.26 with 0.4/1.2 blurs the return and lets the
deck hold what is nearest it rather than the whole length of the stage.
Measured over the deck band of `stage_wide`:

| | mean | p95 |
| --- | --- | --- |
| 0.14, fade 0.15/2.0 | 0.068 | 0.255 |
| 0.26, fade 0.4/1.2 | 0.043 | 0.122 |

Still glossy enough for the reflection to exist, which is the property
`test_stage_set.gd` guards rather than the exact value. The deck also sets `roughness_map: false`,
a new `MaterialLibrary` spec flag, because DiamondPlate009's rebanded scan
multiplies the scalar and a deck that mirrors in patches is a floor nobody has
ever mopped.

The Environment's existing comment block rules SSIL and SDFGI out because they
**accumulate over frames**, and `ART_SETTLE_FRAMES` is 3 while
`SILHOUETTE_SETTLE` is 90 — an effect converged in one measurement and not the
other makes the two disagree about the same scene. Godot's SSR is a
single-frame screen-space trace with no temporal accumulation, so it is
identical at frame 3 and frame 90. That is the property that admits it, and
the double-capture diff above is what verified it rather than assuming it.

`gl_compatibility` has no SSR, so the Web build renders that deck as a
low-roughness dark floor with tighter specular highlights and no reflection in
it. `ArenaLighting._apply_compat_environment()` now clears the flag explicitly
on that path — the flag is inert there anyway, and a duplicated Environment
that sets things which do nothing is a worse description of what that renderer
will do. Same class of recorded difference as the fog note above; not a defect
to paper over with a fake mirrored plane.

### Three ways the geometry was wrong first

**The wall was invisible.** Geometry correct, UVs correct, material correct,
and nothing on screen — the panel was being culled. Godot's front faces are
**clockwise** from the front, which `_add_box` has always obeyed without
saying so (its UP face lists corners that run top-left, top-right,
bottom-right when viewed from above), and the new curved emitters listed
theirs the other way. Every one of them now goes through a single `_add_quad`
that takes corners counter-clockwise and reverses once, so the convention
lives in one place instead of in six.

**The bezel surfaced through the picture**, as two dark chevrons across the
top of the wall. The frame was built from the same *sagitta* as the face it
frames, and a wider chord bowed by the same amount is a **different circle**:
the two arcs cross mid-panel. `_sagitta_for()` inverts `_arc_radius()` so the
bezel is built on the picture's own circle, and stays behind it everywhere.

**The portals were the wrong shape three times**, each caught by the owner off
the render, and the sequence is worth recording because every wrong one was a
plausible reading of the same photograph.

They were **closed rings** first: no doorway, and a closed circle reads as a
neon hoop hung on a wall. Then an **omega** — which is simply what you get by
opening a ring with a gap at the bottom, because the curve carries past the
sides and round toward the floor, the ends finish pointing inward, and the
outward feet needed to plant them are exactly an omega's serifs. Then an
**arch on two straight legs**, which fixes the serifs by stopping the curve at
the sides and in doing so stops it reading as a circle at all.

It is **a circle with the bottom cut off by the deck**. The fix was to stop
describing the shape and describe the *situation*: place the circle so its
lowest point sits 0.25m below the deck, and let the tube end wherever it meets
the floor. `_portal_cut_angle()` derives the crossing from that one number, so
the ends cannot float above the deck or bury themselves in it, and the result
is a circle by construction rather than by resemblance — 308 degrees of it,
with a 2.2m opening at deck level.

`test_stage_set.gd` asserts the situation rather than the silhouette: the
tube's lowest geometry sits one tube-radius below the deck, the sweep is
between 280 and 330 degrees, and the deck crossing is below the horizontal on
both sides — which an arch's is not.

The slat fans inside them were wrong twice over. Built `house_lit` first, they
vanished: at hall level, inside an unlit recess, there is nothing for them to
catch — they are strip fixtures in the photographs, so they are self-emissive
now, at 0.26 against the ring's 1.12 so the ring stays clearly the brighter of
the two and the depth survives. Then they rendered as one solid glowing wedge
that pulled the eye off the ring, because 13 slats across 52 degrees are 0.15m
apart at the outer radius and each was 0.18m wide. Narrow strips at a lower
level is the version that reads as what it is: texture inside the portal, seen
and not looked at.

### One thing left alone

The lighting truss crosses the wall from `stage_wide` — the ray from the
camera through the truss at `z = -11, y = 7.6` lands at `y = 10.75` on the
screen plane, inside its upper band. It only became visible when the wall got
bright. It is real geometry in the right place reading as rigging, which is
what an arena looks like, so it stays.

### The wall painted itself over the game

Shipped, deployed, and caught on the live build: the clip was playing across
the middle of the screen, on top of the 3D, as well as on the wall.

`VideoStreamPlayer` is a `Control`, so it has to be parented somewhere that
draws. It was in a `CanvasLayer` at `layer = -128`, on the belief that a
negative layer puts it behind the 3D world. **It does not.** A layer value
orders a CanvasLayer against *other CanvasLayers*; 3D is always drawn behind
every canvas item, so there is no layer value that hides a Control behind the
scene. `expand = false` compounded it: with expand off the player draws at the
clip's native 1280x720 and ignores the 2x2 rect it was given, which is why the
overlay was as big as it was.

The player now lives in a `SubViewport` -- 2x2, `disable_3d`, its texture never
read. That is the only placement that gets both halves: it renders to its own
target and is never composited into the window unless a `SubViewportContainer`
asks for it, while its children still process, so the decoder runs and
`get_video_texture()` fills. Reproduced on `gl_compatibility` before the fix
and confirmed gone on both renderers after it, with the clip still on the wall.

**Why no test caught it** is the part worth keeping. Every suite runs headless,
and `StageVideo` skips the player entirely under the headless display server --
so the branch that shipped the bug was the one branch no test could reach. The
placement is now built by a static `_make_feed()` that needs no renderer, no
clip and no display server, and three tests assert it directly: the player is
under a `SubViewport`, there is no `CanvasLayer` or `SubViewportContainer` in
that subtree, and `expand` is on.

## Fix: the entrance set on the browser renderer, and a test three comments claimed existed

The compatibility renderer has no HDR buffer, so emission above 1.0 clips flat
to white instead of rolling off the Filmic curve the levels were solved
against. Measured before the fix, on the same frame: the portal band rendered
at **2.89x** of forward_plus and the video wall at **1.71x**, while the
house-lit surfaces around them went darker. Three corrections, each measured
separately because the surfaces clip differently:

| | constant | re-measured against forward_plus |
| --- | --- | --- |
| video wall | `COMPAT_SCREEN_GAIN` 0.48 | **0.97x** |
| portal rings | `COMPAT_EMISSIVE_GAIN` 0.46 | **0.86x** |
| stage fixtures | `COMPAT_STAGE_GAIN` 1.0 | mat control **1.02x** |

`_house_lit()` deliberately takes no gain: it targets ~0.015 linear, well under
1.0, so it cannot clip and scaling it would only darken the hall.

`COMPAT_STAGE_GAIN` is 1.0 because `COMPAT_LIGHT_GAIN` (0.15) exists to hold
the mat on `VISUAL_BAR.md`'s 0.43-0.49 anchor, and the entrance fixtures cannot
reach the mat. Scaling them bought the anchor nothing and cost the whole set.

### Three claims in `arena_lighting.gd` that were not true

The file cited `test_stage_lighting.gd` three times. **It did not exist**, and
before writing it no test in the suite referenced `Light3D`, `spot_range` or
`light_energy` at all. Writing it caught two overstatements:

1. *"Every fixture built for the entrance set therefore takes a range of 12m."*
   False for the stage wash, which takes 28m against a nearest mat corner at
   17.25m. It is kept off the canvas by being **aimed away** — 77.5 degrees off
   a 44-degree cone — which is a real guarantee but a weaker one than range,
   because re-aiming is a smaller edit than re-ranging. The test now asserts
   the disjunction (out of range **or** off axis) over all ten fixtures and
   pins the stage wash's reason separately.

2. *"Rec.709 luminance of the old (0.72, 0.74, 1.0) is 0.7581 and of this is
   0.7574, a difference of 0.0007."* All three figures wrong. Re-measured:
   0.7545 against 0.7489, a difference of **0.0056** on raw sRGB components
   (0.0068 linearised) — eight times the claim. It threatens no anchor, because
   that fixture cannot reach the mat, but "hue only" was overstated.

Both comments now carry the measured numbers, and `COMPAT_EMISSIVE_GAIN`'s
"within a few percent" is corrected to the 0.86x it actually reads.

### Open, and deliberately not chased

The backdrop's **far edges** render at **0.20-0.22x** of forward_plus, while
the same panel between the rings — where the accent shafts land — reads 1.09x
and the truss above it 0.99x. That is not one of the three constants (the
backdrop's `_house_lit` reach change from 2.6 to 1.1 is renderer-neutral) and
I could not establish the cause from this frame. It is recorded rather than
tuned away: re-solving one constant to chase a number while another in the same
frame is unexplained is how the comments above came to overstate themselves.

## Cut the moves that did not read, and gave the AI match a shape

The finisher, power and reversal moves were removed — all twelve MoveDefs,
their trajectories, their baked pose clips, and their wiring — because their
generated performances did not hold up on screen. A paired throw that does not
read is worse than no paired throw: it costs the match a second of animation
that says nothing happened. What is left of the paired moveset is three basic
grapples and two signatures.

Removing them made three consequences that had to be handled rather than
absorbed:

- **The reversal mechanic went with its animations.** A reversal cancelled an
  incoming strike and played `reversal_counter.tres` through `GrappleRig`, so
  with the counters gone there was nothing for it to play. `MatchReferee`'s
  `_check_for_reversal`/`_apply_reversal`/`_finish_reversal`, the AI's
  reaction-delay press, and the controller's `_wants_reversal_this_tick` are
  all gone. `MoveDef.reversal_window_start/end` are **kept**: they are measured
  frame numbers (the jab's 8-11 came off the clip's own contact frame), and
  re-measuring them later is more work than carrying them.
- **A signature became unreachable.** `can_signature()` required
  `tier_reached >= Tier.POWER`, and nothing can record a power tier any more —
  so the two signatures still shipped would have been silently dead rather
  than deliberately retired. The gate now asks for a landed grapple.
- **`build_paired_moves.gd` was append-only.** The first five moves' arcs were
  hand-keyed straight into `paired_moves.tres` and the generator only ever
  added to it, so deleting a recipe left its trajectory in the library
  forever. It prunes clips with no recipe now, which makes the library a
  function of the recipe file the way every other generated resource here
  already is.

### The AI match: one grapple, then punches and kicks, then a pinfall

Every close-range decision used to be a seeded coin flip between a strike and a
tie-up, weighted so the grapple chain carried the match. Measured before this
change over three seeds: **four tie-ups and 4 to 11 strikes per match**, and
two of the three matches ended by submission.

The AI now presses grapple only until a grapple has actually landed — read off
`CombatSystem.tier_reached`, which is written the moment a grapple resolves —
and strikes for the rest of the match. The Irish-whip roll in `GRAPPLE_HOLD` is
gone with it: with one grapple in a match, spending it on a whip means matches
that never show a grapple at all. `_begin_irish_whip()` itself is untouched for
a player who presses run in a hold.

The referee no longer chooses between a cover and a submission either. Every
finish is a cover, because a match is supposed to end with one wrestler pinning
the other. The submission subsystem — minigame, both states,
`begin_submission()` — is still wired and still tested; nothing starts one.

Measured after the change, twelve AI-vs-AI seeds, `feel_probe` and
`ladder_probe`:

| | before (3 seeds) | after (12 seeds) |
| --- | --- | --- |
| finishes | 2 submission, 1 pinfall | **12 pinfall** |
| grapple moves per match | 4 | **1.0** |
| strikes per match | 4-11 | **16-42** |
| match length | 673-1679 ticks | 1026-2899 ticks (17-48s) |
| knockdowns per match | — | 1.9 |

### Two more strikes, so the match is not one punch repeated

A match made of strikes needs more than two of them. Both new ones are cut to
their own **measured** contact frame rather than to an assumed one, by a new
`tools/anim/measure_strike_contact.gd` — it rebuilds each frame's pose from the
clip's own tracks over the rest pose and walks the parent chain by hand, for
the reason the existing recipes already record: neither `AnimationPlayer.seek()`
nor `set_bone_pose_rotation()` reaches `get_bone_global_pose()` in a `-s`
script, so every naive sample reads back identical rest values.

- **`strike_cross`** — the rig's own `Punch_Cross`, the only strike not drawn
  from the mocap pack, so it is a visibly different punch rather than the jab
  at another speed. Measured: the right fist peaks **0.683m** in front of the
  pelvis at **t=0.300s** of the 1.0s clip. Retimed by exactly 2/3, which puts
  contact on tick 12.
- **`strike_kick_heavy`** — the same measured roundhouse as `strike_kick` at
  two thirds speed (1.5x its 0.633s bake). Retiming scales the contact frame
  with everything else: 0.133 × 1.5 = 0.200s, tick 12.

Neither lands on the 0.133s the jab does, and that is the point: that figure is
`gauntlet/refs/timings.md`'s measurement of a *jab's* startup, not of every
strike's. A match whose strikes all share a startup is a match with one strike
in it.

### The signature is the finish

A follow-up, and the reason the numbers above moved: the AI now hits a
signature before it covers. It reaches for one — a second tie-up — only when
the opponent is **within one signature of a knockdown**, measured from his
last one rather than from his total (`WrestlerAI._opponent_is_ripe()`, against
the *weakest* move in the signature pool, since the move is drawn by a seeded
pick when the grapple resolves). Momentum crosses `SIGNATURE_THRESHOLD` after
four or five strikes, long before anybody is hurt enough to pin, so an AI that
threw a signature as soon as it could afford one would throw it in the opening
exchange and finish the match with jabs.

That needed one gate changed. `can_signature()` asked for a landed rung below
it, and only the winner of a tie-up lands anything — so the man who lost the
opening lock-up could never throw a signature however long the match ran. The
first attempt at fixing that had him lock up again purely to earn the rung, and
it measured **5.5 tie-ups a match against 8 strikes**: the grapple loop this
whole change exists to get away from. The gate now asks the meter alone. What
keeps a signature from being the first move of a match is that momentum starts
at zero, and `test_combat_system.gd` pins both halves of that.

Measured over twelve seeds afterwards:

| | strikes only | with the signature finish |
| --- | --- | --- |
| finishes | 12 pinfall | 12 pinfall |
| signature fired | 0 seeds | **12 of 12** |
| winner's last move before the pin | strike | **signature in 11 of 12** |
| grapple-chain moves per match | 1.0 | 4.4 |
| strikes per match | 16-42 | 16.7 mean |
| match length | 17-48s | 25-48s |

The twelfth seed ends on a strike, and honestly: that winner had already spent
his signature on an earlier cover the opponent kicked out of, and was back
under `SIGNATURE_THRESHOLD` when the knockdown came. Holding the strikes back
until the meter refilled would stall the match, since landing strikes is where
momentum comes from.

`ladder_probe.gd` reports that "last move before the pin" figure now, and its
chain-order check was wrong after the cut in the other direction — it read a
signature thrown over an empty power slot as a skipped rung, so it reported
every seed as out of order while the order was exactly as intended.

### Left alone, and why

The **signature** moves were not removed — they were not among the ones called
out, and both are now the finish of every AI match (see above).

**WrestlerB wins 9 of 12 seeds.** That skew predates this change (the
before-measurement has him taking 2 of 3) and nothing here addresses it.

## Every animation in the match, authored again from scratch

The clips did not look good, and the reason was not the numbers in them —
it was that nothing in the loop could see them.

The previous pass authored all 29 clips as per-bone Euler degrees against a
remembered axis map. Rendered on the rig for the first time this pass (six
frames each, three camera angles, `bpy` + Cycles CPU — EEVEE cannot open
`libEGL` in this container), it was one defect repeated everywhere:

| clip | what it actually played |
| --- | --- |
| `Idle_Ready` | a mannequin standing still for 57 frames, arms hanging |
| `Tie_Up_Collar` | the same mannequin, small torso twist — two men standing near each other, not a lock-up |
| `Strike_Forearm` | never raised a hand; the "contact" frame has nothing arriving |
| `Pin_Cover` | a hunched crouch that never reaches the man on the mat |
| `Getup_Rise` | **read correctly** — the one clip whose performance lives in the hips rather than the arms |

`upperarm_r.Y` does not raise the arm from a T-pose rest, it lowers it. A
table of joint angles gives you no way to notice that, which is why the
defect survived a pass that was otherwise careful about timing.

### Poses are now positions, not angles

`tools/blender/rig_pose.py` is a solver: two-bone IK for both arms and both
legs, absolute targets in armature space, with a pole for each joint. A pose
says **where the hands and feet are**, in metres, and the joints are solved
to match.

That is the whole point. A pose is now a claim that can be checked on a
rendered frame:

- a foot at `up=0.104` is planted on the mat (measured ankle height)
- a fist at `fwd=0.56, up=1.40` is at the end of a thrown punch, at head height
- a hand at `fwd=0.52, up=1.46` is on the back of the other man's neck
- a hip at `up=0.55` is a knee resting on the canvas — the thigh is 0.400 long

Measured rest geometry it solves against: 1.651 tall, shoulders 1.441,
pelvis 0.917, ankles 0.104, arm reach 0.547, leg reach 0.829.

Three defects came out of the render loop that a table of angles had hidden,
and each is recorded at the line that fixes it:

- **fingers splayed instead of closing.** The curl is about a finger bone's
  local *X*; local Z (tried first) splays them sideways in the plane of the
  palm and renders as a claw. An open hand reads as a slap at any speed.
- **elbows winged out.** The default elbow pole is down and slightly behind
  the hands, not outward.
- **the spine ignored the hips.** Every bone was set to an *absolute*
  armature-space orientation, so the torso stood vertically while the pelvis
  lay back: `Down_Supine` rendered as a man doing a sit-up on the canvas.
  `spine` and `head` now compose with `hips`, cumulatively down the chain.

### What is in the 29 clips

Contact frames are placed at each move's own `startup_frames` fraction, so
retiming in `resources/animations/strike_recipes.gd` lands the hit on the
tick the MoveDef declares — `strike_jab` 9/31 ticks is frame 5 of 16,
`strike_cross` 12/40 is frame 6 of 20, `strike_kick` 8/35 is frame 5 of 20,
`strike_kick_heavy` 12/57 is frame 6 of 29. Timing follows the combat
reference: anticipation 4–8 frames, action 2–4 and always the shortest,
follow-through 4–8, recovery 8–16.

The locomotion cycles are real cycles now — contact, down, passing, up, per
`walk-cycle.md` — authored in place, so the planted foot travels backward
through its stance phase and the engine's translation supplies the ground
speed. `Run_Drive` has a flight phase with nothing on the mat at frames 7
and 17, which is the whole difference between a run and a fast walk. The
idle's feet never move at all, which is what keeps a looping idle from
sliding.

`Strike_Kick_Heavy` finishes by **stepping** the kicking foot back into the
stance rather than sliding it there; the recovery is 40 ticks because the
reference puts a heavy strike's length in recovery, never in a slower action
phase.

### The bake reads a cache, and the cache lies

Rebuilding the `.glb` and re-running the two bake scripts produced a
`strike_clips.tres` that was **byte-identical to the committed one**.
`godot4 --headless -s <script>` does not reimport a changed asset first, so
both generators had been reading the previous import of `wrestling_clips.glb`
out of `.godot/imported/`. The sequence is:

```
python3 game/tools/blender/wrestling_clips.py
godot4 --headless --import                          # <- not optional
godot4 --headless -s res://tools/anim/build_strike_clips.gd
godot4 --headless -s res://tools/anim/build_paired_poses.gd
```

Without the middle line the bakes silently succeed against stale data and
report the right clip count while doing it.

### Godot was throwing away two thirds of every clip

The clips were right in Blender and still wrong in the game, and the reason
was one line in `assets/animations/wrestling_clips.glb.import`:

```
animation/remove_immutable_tracks=true
```

That drops any track whose value does not change *within the clip*. These
clips deliberately pose the whole body and then hold most of it still — so
`Idle_Ready` arrived in Godot with **23 tracks out of 65 bones**, and every
bone it held steady (both legs, both hands, every finger) was silently
deleted and left holding whatever the `AnimationTree` happened to be
blending from. That is precisely the fault
`test_every_authored_clip_poses_the_whole_body` exists to catch, and it
could not see it: the test counts tracks in the baked `.tres`, which is
built from the already-stripped import.

Set to `false`, the same clip imports with 195 tracks (65 bones × position,
rotation, scale) and the fingers survive. `strike_clips.tres` roughly
doubles, to 1.2 MB. That is the correct trade: this project's clips are
whole-body by design, so "the value never changes" is information, not
redundancy.

### How closed a hand is, is a number

The finger curl runs 0 (open) to 1 (fist), and the useful values were read
off rendered frames rather than picked:

| value | reads as |
| --- | --- |
| 0.0 | a flat palm pressing a shoulder into the mat |
| 0.45 | a loose hand hanging off a stunned man |
| 0.6 | a grip closed around a collar, an arm, a waistlock |
| 0.75 | a guard |
| 1.0 | a thrown fist |

Below about 0.5 the fingers are still mostly straight, and the hand reads as
a **claw**, not a grip — the tie-up shipped one pass at 0.3 and looked like
a man about to scratch someone.

### Left alone

Clip **names and lengths are unchanged**, so `strike_recipes.gd`,
`paired_recipes.gd`, both MoveDef tables and the getup's beat positions
(`GETUP_RISE_FAST_TICKS` cuts this clip off partway through, so the beats
are behavioural) all still describe the same clips. Nothing in the FSM,
`GrappleRig` or the MoveDefs was touched.

## The whole venue is built in Blender now

The bowl and the shell were already `tools/blender/arena_bowl.py`'s model. The
ring, the entrance set, the ramp, the truss, the floor and the barricades were
still generated in GDScript with `SurfaceTool`. They are all one pipeline now:

| model | built by | parts |
| --- | --- | --- |
| `arena_bowl.glb` | `arena_bowl.py` | seating bowl, rink, aisles, suite fascia, shell |
| `ring.glb` | `ring.py` | posts, rope terminations, twelve rope spans, apron frame, steel steps |
| `entrance_set.glb` | `entrance_set.py` | stage deck, ramp, backdrop, portals, video wall, truss |
| `ringside.glb` | `ringside.py` | floor slab, decking joints, barricades |

`tools/blender/venue.py` is the shared foundation: the constant parser, the one
game↔Blender frame conversion, and the primitives — bevelled boxes, wedges,
parallel-transported swept tubes, arcs and four-chord lattices.
`tools/blender/build_venue.sh` rebuilds any or all of them.

The split is the one the bowl established. **Blender owns shape. Godot keeps
owning look, physics and anything that moves** — every part is dressed by name
from `MaterialLibrary`, because the hall's tints are solved against measured
luminance targets in `VISUAL_BAR.md` and a colour picked in Blender cannot know
about them. Colliders, the ring canvas texture, the video feed and the seat
instancing all stay in GDScript.

Every dimension is still **read out of the GDScript that declares it**, never
retyped. Four constants that only existed inside an array, a dictionary or a
sum are now plain numbers, because a number the parser cannot see is a number
the mesh would have to duplicate.

### What the move actually bought

Not "it looks better in Blender" — three specific things GDScript could not do:

- **The ramp was a staircase.** `arena_builder.gd` said it outright:
  "axis-aligned boxes are all this file builds". So a 25.7 m ramp falling
  1.45 m shipped as **eighteen 8 cm steps**. The note argued the steps were
  under a pixel of rise from any camera in the shotlist — true of the *treads*,
  false of the **edge**: a stepped ramp has a stepped silhouette against the
  floor from every angle that sees it side-on. It is one wedge now, with a
  fascia down each flank and a nose at the bottom instead of a 1.45 m cliff.
- **The truss was sixteen boxes**, with a comment hoping they would "read as
  truss rather than as bare pipe". Overhead truss is the one piece of an arena
  that is unmistakably a lattice from every angle. It is four chords on a
  square section with alternating diagonals bay by bay.
- **Edges.** Ring posts, apron rails, steps and the stage lip carry real
  chamfers; turnbuckle sleeves and barricade cap rails are round. A perfectly
  sharp 90° edge takes no highlight from the house rig, and a box cap rail
  takes one on a single facet where a tube takes one along its length.

### Two faults found on rendered frames, not reasoned about

- **An open sheet has no outside.** `recalc_face_normals` finds the outside of
  a closed solid; for a sheet it picks a direction, and that direction is
  arbitrary. A sheet facing the wrong way is **invisible** under backface
  culling, not merely dark — the video wall rendered as nothing at all with its
  UVs, its material and its bound still frame all correct. `venue.finish` now
  takes an explicit facing for open sheets and bores.
- **Reversing faces is not the same as winding them correctly.** The reversal
  re-pairs each loop with its UV, and the picture came back on the wall rotated
  180°. Only the picture on the wall settles which way round a UV goes.

### The tests moved with the geometry

`test_stage_set.gd` measured the deleted builder functions directly. Its
invariants now measure the committed model, the way `test_arena_bowl.gd`
measures the bowl — plus two new ones:

- **the wall must FACE the ring**, which is the culling bug above, now guarded;
- **the ramp run must sit at no more than two distinct depths**, which is what
  a wedge is and a staircase is not.

The bezel test keeps its intent in a stronger form. It used to assert that
`_sagitta_for` inverts `_arc_radius`; it now asserts the thing that arithmetic
was *for* — the frame must never surface through the picture anywhere, which is
what went wrong when the two were built on different circles and the wall grew
two dark chevrons across its top.

### A trap worth repeating

`godot4 --headless -s <script>` does **not** reimport a changed asset first, and
neither does a test run. After `build_venue.sh`, run `godot4 --headless --import`
before baking, testing or capturing — otherwise everything downstream keeps
reading the previous import and reports success while doing it.

All four models rebuild byte-identical. 341 tests pass, and every change was
checked against a before shot through `CaptureHarness`'s art shotlist.

## Round: the strikes connect, and the feet stop skating

A review of the animation set against the clips the game actually loads, on
the question "are these smooth and natural, and do punches land with collision
detection". Six defects, all measured, all closed on the numbers rather than on
a description. New tooling under `game/tools/` reproduces every figure below.

### Punches had no collision detection at all

`_in_range(STRIKE_HIT_RANGE)` was the whole hit test: one 1.15 m sphere between
the two capsule **origins**, shared by every strike, evaluated on each tick of
the declared active window. It never asked where the limb was. Three
consequences, each measured on `strike_clips.tres`:

- **One range for four limbs.** The striking limb ends up 0.42 / 0.55 / 0.82 /
  0.82 m in front of the origin for jab / cross / kick / heavy kick. A single
  1.15 m test landed the jab through a third of a metre of clear air and cut
  both kicks short of where the boot actually was. The 1.15 was honest once —
  0.76 m of fist plus the 0.4 capsule — but it was measured on a `Punch_Jab`
  clip that no longer exists.
- **No direction.** `_turn_toward_opponent()` runs only in the idle branch of
  `_process_free_movement()`, and nothing updated facing during `STRIKE`, so a
  punch thrown while strafing away connected.
- **No height.** A boot to the midsection and a jab to the jaw tested
  identically against the opponent's origin.

`MoveDef` now carries a measured `contact_offset` and `contact_radius`, baked
by `tools/anim/measure_contact_offsets.gd`. `_strike_reaches()` places that
sphere in the attacker's own space and intersects it with the opponent's
capsule, so facing and height fall out of the geometry rather than needing
their own gates. It is arithmetic on two transforms — **not** a Jolt query, and
deliberately not a read of the live skeleton, either of which would put
physics or per-model retargeting into gameplay state and break replay hashes.
Moves with no authored volume (grapples, paired moves, timed stubs) keep the
proximity test, which is the right one for them: `GrappleRig` places both
wrestlers itself.

Measured reaches now: jab 1.17 m, cross 1.07, kick 1.37, heavy kick 1.35.

### The jab was rotating away from its own punching arm

The worst clip in the set, and the cause was one sign. Its contact pose twisted
the spine **-16°**, which is the direction that drives the *right* shoulder
forward — on a left-hand jab. That put the left shoulder at fwd **-0.119**,
behind the body's origin, so the furthest the fist could reach was 0.42 m while
the pose table asked for 0.56. That target is 0.685 m from a shoulder with
0.544 m of arm, and `_two_bone_ik` clamps to `(l1+l2)*0.995` and solves along
the direction, so the truncation ate almost the whole forward component.

Frames 5 and 8 both truncated onto the same reach sphere and collapsed into
nearly the same pose, which moved the clip's actual peak to tick 18 — six ticks
past the window `strike_jab.tres` applies damage in. What shipped was 7 cm of
ooze at 2.83 m/s where the cross manages 7.20.

The twist is positive through contact now and the clavicle protracts, which is
what a real jab does with its shoulder. Measured after: **0.305 m of travel at
5.89 m/s, peaking on the declared contact tick.**

The cross is what made this diagnosable rather than guessable: every one of its
targets sits inside the reach sphere, and it measured perfectly through the
identical code path.

`tools/blender/reach_audit.py` now reports this class of defect. It finds **174
of 720 limb targets still beyond reach** across the other clips — worst
`Getup_Rise` f22 at 0.56 m short, then `Finisher_Drive`, `Move_Exec_Impact` and
`Pin_Cover`. Those are not fixed here, but they are no longer invisible.

### The locomotion cycles skated 6.6x and 7.3x

Skate is a **rate** error during the planted phase, not a stride-length one: a
run covers most of its ground in flight, where nothing is planted and nothing
is constrained. Comparing stride against `speed * cycle_time` condemns every
correct run cycle ever authored. What matters is backward travel divided by
time planted:

| | delivered | required | |
| --- | --- | --- | --- |
| `walk_stalk` | 0.42 m/s | `MOVE_SPEED` 3.5 | 6.6x |
| `run_drive` | 2.01 m/s | `RUN_SPEED` 7.0 | 7.3x |

Contact *duration* is the free variable, not stride: the leg caps a planted
foot at about ±0.30 m either side of the hip, so a faster gait is bought with a
shorter, harder contact and more air — which is what sprinting is. Both cycles
are now generated by `_gait()` from the speed they are played at rather than
tabled by hand, because the invariant cannot be held by hand. Measured after:
**walk 3.48 m/s, run 6.87/6.88 m/s.** No gameplay constant changed.

This also closed the loop seam by construction. `run_drive` was popping its
left forearm **0.132 m every 0.667 s** because frame 0 named elbow poles and
the closing frame did not, so the IK solved the same hand target two ways. The
generator computes the closing frame identically to frame 0.

### Contact frames disagreed with the MoveDefs

Three of four strikes applied damage on a tick when the limb was somewhere
else. `startup_frames` now equals each clip's measured peak, with
`total_frames()` held constant so no clip outruns the state that plays it:

| | was | now |
| --- | --- | --- |
| `strike_jab` | 9, peak at 18 | 10 |
| `strike_kick` | 8, peak at 14 | 14 |
| `strike_kick_heavy` | 12, peak at 11 | 11 |

`strike_cross` was already aligned and is unchanged.

### One left open, deliberately

The running attacks have the same misalignment — `running_clothesline`'s arm
peaks at tick 30 and both `running_attack_*.tres` apply damage at 18 — but the
fix is NOT the one applied above, and the suite is what said so. That 18 is
`0.300s`, measured off reference footage (`timings.md`: windup 230.333s,
contact 230.633s), and `test_strike_and_getup_timings.gd` pins it there along
with the 0.73–0.80s recovery. ARCHITECTURE.md's reference-driven tuning rule
makes `gauntlet/refs/` the authority, so the MoveDef is correct and the CLIP is
what disagrees with it.

Closing it properly means retiming `running_clothesline` so the arm peaks on
tick 18, which is a clip-authoring change with its own measurement, not a
number to move here. Its contact offset is therefore baked at tick 18 where
damage actually lands — the limb is 0.382 m out rather than the 0.500 m it
reaches later — giving the move a 0.90 m range, which is honest about the
clip as it stands.

### What was already right

Worth recording, because it is most of the pipeline: Bezier with
`AUTO_CLAMPED` handles throughout, the bake is byte-deterministic, loop flags
are correct in the baked library, `idle_ready` and `tie_up_collar` plant their
feet to within 1–4 cm, hit reactions already route head-vs-torso by damage, and
the 6-tick xfade on a physics-clocked `AnimationTree` is sound.

### New tooling

- `tools/anim/measure_contact_offsets.gd` — bakes each strike's contact point.
  Re-run after **any** change to a clip or to `startup_frames`.
- `tools/anim/gait_audit.gd` — planted-foot rate and loop seams. Fails on
  skate.
- `tools/blender/reach_audit.py` — pose targets the rig cannot reach;
  `--sweep` reports the shoulder geometry that decides a punch's extension.
- `tests/test_strike_contact_volume.gd` — pins the consequences: per-move
  range, no landing backwards, height is read, grapples keep the old test.

### The trap that cost the most time here

A strike's hit rate is **not** a measure of whether the contact test is right.
`strike_connect_probe.tscn` reports the *closest approach* during a strike, not
the gap at the tick contact was tested, so its miss distances cannot be read as
"the fist was this far away and still missed". The test that settles it is the
geometric one, at known transforms — which is what `test_strike_contact_volume`
is for.

## Round: they were fighting side-on the whole time

Follow-on from the strike-contact round above, and the thing it found is bigger
than anything in it.

### The regression I shipped

Making contact per-move broke the AI's spacing, and I did not notice because I
read the wrong number. `WrestlerAI` holds `circle_distance` 1.10 m and gated
strikes on `STRIKE_HIT_RANGE` 1.15 — constants chosen when that single number
was every strike's reach. Once each move reached only as far as its own limb,
the cross topped out at **1.07 m**: the AI stood at 1.10 and every cross it drew
missed by three centimetres.

Fixed in the clip rather than the standoff, because a rear-hand cross thrown off
a rotating torso is the *longer* punch: `Strike_Forearm`'s contact now drives
and protracts the right shoulder the way the jab does mirrored, and reaches
0.679 m against the jab's 0.655. The AI gates on
`WrestlerController.shortest_strike_reach()` — the shortest move in its own pool,
since `_pick_tier_move()` chooses, not the AI. `test_ai_spacing.gd` keeps the
band and the measured reaches agreeing.

That took the hit rate from 24.6% to 27.8%. Which was the clue that the
diagnosis was wrong.

### The actual reason strikes did not connect

`strike_connect_probe` reported miss distances of 0.77–1.15 m, and I read them
as spacing. They are the **closest approach at any point during the strike**,
not the gap on the tick contact is tested — a completely different quantity. The
probe now measures the contact tick itself, and splits misses by cause:

```
misses by cause, measured ON the contact tick:
  out of reach  1      off to the side 49
  gap beyond this move's own reach: median -0.36 m
  angle off the attacker's facing:  median 97 deg
```

**49 of 50 misses were sideways.** The opponent was a comfortable 0.36 m *inside*
reach; the attacker was pointing 97 degrees away from him.

`_process_free_movement()` called `look_at()` on the input direction. For a
wrestler circling an opponent that direction is tangential — so he walked the
circle facing the way he was going, shoulder to the other man, for the whole
match. A wrestler circling an opponent *strafes*: eyes, guard and hips on him,
feet carrying him sideways.

The old hit test hid this completely. A 1.15 m sphere between two capsule
origins does not care which way anyone points, so two men could fight an entire
match side-on and land everything. Directional contact is what made it visible.

`_turn_toward_opponent()` during startup — added in the previous round — could
not dig out of it either: `TURN_RATE_PER_TICK` is 0.12 rad/tick and two men
circling opposite ways swing the bearing between them by ~0.11 rad/tick, so an
attacker entering `STRIKE` 90 degrees off recovers about 8 degrees across a
whole jab. It is the backstop; facing while circling is the fix.

Inside `FACE_OPPONENT_RANGE` (2.5 m — `WrestlerAI.run_engage_distance`, this
project's existing line between a fight and a traversal) a moving wrestler now
faces his opponent. Outside it he looks where he is running.

| | before | after |
| --- | --- | --- |
| strikes landed | 24.6% | **70.7%** |
| missed off to the side | 49 of 50 | **2 of 3** |
| median miss angle | 97° | 63° |

Strikes thrown per match fell from 115 to 41, which is the healthy half of it:
the match now ends because someone gets hurt.

### Two lessons worth keeping

**A probe's number means exactly what it measures.** "Median miss 1.00 m" sent
me looking at spacing for two rounds. The probe reports the contact tick now,
and says in its own output which quantity is which.

**A loose gate hides everything behind it.** Every defect in both rounds was
invisible while contact was a proximity sphere — wrong reach, wrong contact
frame, and a match fought side-on all resolved identically. Tightening the gate
did not cause these; it revealed them.

### Documentation

`gauntlet/anchor/MATCH_FLOW.md` is new: the intended shape of a match — grapple,
strikes, signature, pinfall — what decides each contest, what is deliberately
absent (reversals, submissions, a neutral game) and why, and a table of the
cross-file invariants with the test or tool that enforces each. It owns no
numbers; every quantity is quoted from the file that owns it.

`FEEL_BAR.md` is rewritten. Its priority #1 was reversal windows — a mechanic
that had been removed, judged against a number `timings.md` still lists as
`(pending)`. Every bar now names what settles it, because a bar with no enforcer
cannot be judged, only asserted, which is exactly how that entry survived.

## Round: rendering a frame, which found three things measurement had passed

Every claim in the two rounds above was closed on forward kinematics and
headless probes, with the caveat recorded each time that no frame had been
looked at. Looking at one found three defects, all of which the numbers had
passed cleanly.

Rendered through `tools/probe/clip_shot.tscn` on **forward_plus** (software
Vulkan via lavapipe, so `software_rasterised` applies and no performance claim
is made from it), plus `tools/probe/arena_shot.tscn` for the in-match frame.

### The run had its arms tucked together at the moment a foot landed

`_gait()` phased the arm and hip swing on `sin(2*pi*phase)`. The contact
windows start at phase 0 and 0.5 — exactly where sine is zero — so the arms and
hips were at their NEUTRAL midpoint on both contact frames and at their extremes
mid-flight, which is precisely backwards. It rendered as a man jogging with his
guard up rather than driving. Now `cos`.

The planted-foot rate was correct throughout, before and after. No measurement
in the project could have caught this.

### The wrestlers were walking on points

`foot_*` places the ankle and says nothing about which way the boot points, so
the foot inherited the shin's rotation: a leg swung out in front carried the toe
down with it. Lengthening the stride to fix the skate made a pre-existing fault
much more visible. `_gait()` now drives `ankle_*` through a heel-strike →
toe-off roll, and the rig's rest pose stands with its soles flat, so 0 is flat
regardless of the leg above.

### The sprint was leaning backwards

`Run_Drive` carried `spine=(24, ...)` under a comment reading "torso drives
forward at 24 degrees". Measured, spine lean is negative-forward: at -18 the
head sits 0.159 m in front of the pelvis, at +24 it sits 0.107 m **behind** it.
The clip has been reclining since it was authored and the comment has been wrong
just as long. Now -18, with the head countering the lean and the arm swing
lowered to match (at the old height the lead fist ended up covering the face
once the torso came forward).

`Walk_Stalk` had the same sign and is now upright. Note `STANCE` still carries
+12 — a slight backward lean every clip in the set inherits. Correcting that
moves all 29 and is its own job.

### What the frame confirmed

The facing fix is visible: `arena_shot` puts the two wrestlers squared up
chest-on at 1.13 m, which is what `_turn_toward_opponent()` while circling was
for. The jab reads as a punch — guard closed at rest, arm driven out and torso
rotated at contact.

### A pre-existing bug this turned up

`tools/capture/run_capture.sh` **hangs on the shipped default seed.**
`match.tscn` ships `match_seed = 1`, and seed 1 produces a match where the two
never throw a strike at all — confirmed at 0 thrown over a 20000-tick budget.
The recording step therefore never terminates, so the whole capture/evidence
path is unreachable out of the box.

Verified pre-existing, not caused by this work: the same seed measures 0 thrown
on `2b75477`, the commit before any of it, in a clean worktree. Seeds 2 and 3
finish normally. Not fixed here — it is an AI/reachability bug, not an animation
one — but it is the reason no capture in these rounds went through the project's
own harness.

### The lesson, again

Both previous rounds ended by noting that no frame had been looked at. Three
defects were sitting in the gap that note described, and two of them
(`sin` vs `cos`, and a torso leaning the wrong way for years) are things a
single rendered frame answers instantly and no amount of forward kinematics
ever will. The project's own rule already says this: close appearance claims on
pixels. These rounds are what it costs not to.

## Round: the bowl has people in it

The arena's crowd, modelled in Blender and animated by a vertex shader.

### It had one, and it was two boxes

A crowd was removed in 7b91d0e — impostors, a 0.42 x 0.58 x 0.30 torso with a
0.21 cube on top, one block per seat. It went because `gauntlet/refs/arena.md`
measures an **empty** bowl, and the seats were rebuilt from a rail into ~3,500
individual seats so an empty bowl would read.

`gauntlet/refs/lighting.md` now measures four **full** ones. The two reference
sets disagree about whether this building has people in it, and this follows
the second: measured across the art shotlist, the empty bowl put 3.1% of
`crowd_bank` below 0.01 relative luminance against the references' 38–50%, and
an empty stand is most of that gap.

### What is modelled

`tools/blender/crowd.py`, built and exported with the rest of the hall by
`tools/blender/build_arena.sh`. Nine boxes a person — hips, torso, head, two
arms, two thighs, two shins — posed sitting down, every one a different size,
leaning a different way, with its arms somewhere else. Four arm postures
(hanging, forearms on knees, folded, both up), a per-person lean, knee spread,
and scale from 0.88 to 1.08. 7% are standing, because a row where every head is
at one height is the most obviously generated thing a crowd can do.

Shirt colour and skin tone come from two palettes, jittered per person. The
shirt palette is recovered from the removed crowd, which sized it against a
measurement: the reference crowd sits at relative luminance 0.014, so a bright
crowd is not closer to the reference, it is further from it. Variance is the
point, not brightness.

Placement walks the same curve `build_seat_row` does — same pitch, same aisle
and stage-gap exclusions — at 0.86 fill.

### Budget, which is in vertices and not triangles

A flat-shaded box cannot share a vertex between two faces, so a nine-box figure
is 216 vertices rather than 72. The whole lower tier at that detail exported a
**52 MB** .glb against the hall's 5.6. Two changes brought it to 18 MB:

- **Smooth shading on the crowd only.** Cuts the vertex split, and a softly
  shaded figure at 20m reads as a person where a faceted one reads as a box.
- **LOD by row, not by tier.** The first four rows get the nine-box figure;
  everything behind gets a four-box one that keeps the head-neck-shoulder
  silhouette and the break between torso and lap, and drops the limbs.

840 near figures, 4,874 far, 70 standing. 455k triangles for the hall, up from
102k. That is a real cost and the seats underneath it — 80k triangles of them —
are now mostly hidden, which is the trade 7b91d0e made in the other direction.

### Animation

A vertex shader, which is what the old impostors used and the reason
ARCHITECTURE.md's cosmetic-motion clause is worded as it is: it runs on the
render thread, reads only TIME and the mesh's own attributes, writes nothing
back, and so cannot touch gameplay state or move a replay's end-state hash.
Thousands of skinned spectators is not an option that runs.

The bob is scaled by height above the seat so feet stay planted and heads move
most — a figure translated bodily reads as a hovering cutout — with a lateral
sway on a different period so the bowl does not pulse as one organism.

**The phase is a UV, and that took two attempts.** The old shader keyed off
`INSTANCE_ID`, which worked while the crowd was a MultiMesh; baked into the
bowl's mesh every figure shares one id, and the whole stand would bob in
unison. Colour alpha was the obvious place to put a per-figure phase and it
does not survive: rgb arrives intact, every alpha comes back 1.0, because
nothing in Blender's exporter or Godot's importer preserves an alpha no
material reads as transparency. A UV channel carries it through.

That failure is silent — the shirts still vary, so the bowl looks right and
stands still — which is why `test_arena_crowd.gd` asserts the phase spread
directly rather than trusting the export.

### Measured

`crowd_bank`, relative luminance below 0.01: **3.1% → 11.7%**. The references
are 38–50%, so this is a step, not an arrival: the stands are still
self-illuminated rather than lit (see `lighting.md`'s ablation), which is the
next item and the one that governs.

372 tests pass. The bowl rebuilds byte-identical across two runs.

## Round: the ringside chairs have people in them

The bowl got its crowd last round. The seats nearest the camera — the folding
chairs on the floor, between the barricade and the ring — were still empty,
and there was a half-finished slice in the working tree meant to fill them.

### Instanced, not baked

The bowl's crowd is baked into `arena_bowl.glb` because twenty rows on a curve
means no two people are alike. The floor is the opposite problem:
`arena_builder.gd` already computes a transform for every folding chair
(`_floor_seat_row`), so the fans want to be *instanced* against transforms
that exist. A MultiMesh draws one mesh, so the variety moves: six poses
(`tools/blender/floor_crowd.py`) times per-instance size, yaw and shirt.

The figures are built facing `+Z`, the frame the chair prop is modelled in, so
they drop onto a chair's transform untouched, lifted by `CHAIR_SEAT_HEIGHT`
onto the seat pan. The shader took a `phase_source` parameter because a
MultiMesh instance cannot vary `UV.x`; ringside uses `INSTANCE_ID × φ`.

### Three things were wrong, and only one of them was visible in the code

**The build script did not build the model.** `floor_crowd.py`'s docstring
opened by claiming `build_arena.sh` built it. It built the bowl and `exec`'d.
A committed asset with no reproducible build path is one nobody can safely
change, so the script was extended rather than the docstring corrected.

Extending it exposed why nobody had: *every* exporter here segfaults on exit
under the `bpy` module, after the `.glb` is written and closed. Under
`set -euo pipefail` that aborts a build after its first model — which means
`build_venue.sh all` had been silently building one of four for anyone
without a `blender` on PATH. `tools/blender/bpy_exit.py` leaves via `os._exit`
once the export has returned, so a real crash still surfaces as one.

**The fans rendered as pale white blocks.** Only the frame showed this. The
palette is deliberately written twice — `CROWD_SHIRTS` in GDScript, the same
numbers in `crowd.py` — but the two halves do not arrive the same way.
`crowd.py`'s values go through the glTF importer, which decodes sRGB (0.72
arrives in the mesh as 0.479). A MultiMesh instance colour gets no decode: it
reaches `COLOR` exactly as written, so a linear 0.21 displays around 0.5. Same
palette, two colour spaces, and the ringside crowd came out half a stop bright
in the seats closest to the camera. `_crowd_shirt` now returns
`.srgb_to_linear()`.

**The fans had no faces.** The figures are authored white for cloth and a
darker grey for skin, and none of it was reaching the game.
`floor_crowd.py` never wired a `ShaderNodeVertexColor` or passed
`export_vertex_color="ACTIVE"`, so glTF wrote the layer as `COLOR_1` — a
secondary attribute Godot's importer ignores. Every fan came back one flat
value. `arena_bowl.py` has had the fix since the bowl's crowd shipped; this
is the same two lines.

That last one is the failure `test_arena_crowd.gd`'s header warned about, in a
model written after the warning. It is invisible in Blender, invisible in the
exporter's log, and nearly invisible on a frame. `test_floor_crowd.gd` asserts
it directly: two distinct values per figure, the shirt at 1.0 and the skin
below it. On the model as it shipped, that test fails.

### Measured

378 tests pass (372 before, plus six). `floor_crowd.glb` rebuilds
byte-identical across two runs, and the script's restructuring leaves the other
four models byte-identical too.

`contact_probe --seeds 1,2,3` returns 985/1931/2494 ticks with the crowd and
985/1931/2494 without it — checked by stashing the slice, not by assuming.
Arena geometry does not reach the simulation.


## Round: match the ring to the AEW references

Five changes, all read off the owner's reference photographs, and one of them
moves a measured number.

### The apron edge is a padded roll, not a lip

The edge was a flat 0.2m band in dark neutral grey, described in the code as
"the shadowed lip between a white mat and a dark skirt". The reference has no
such lip. The apron edge is a fat padded bolster; the skirt's own printed
vinyl wraps over it, and the corner chevron runs up the skirt and across the
roll. Flat and dark, it read as a hard black line drawn round the ring.

It is a half-round of radius 0.10 whose axis sits one radius inboard of the
skirt plane, so its widest point is flush with the skirt and its crown stands
proud of the skirt's top edge — which is the thing that tells a padded edge
from a folded one. Mapping u 0..1 per side puts the graphic's chevrons on the
corners, exactly as they land on the skirt below. A flat light strip between
the mat edge and the roll is the apron a wrestler stands on.

Both new quads came out wound backwards on the first try and rendered as
nothing at all; the normals were worked by hand from the cross products rather
than guessed at.

### Two black bars, and where they came from

Reported from a frame after the roll landed. `build_apron` put a dark box
0.17 deep centred on the skirt plane, so its outer face sat at 3.285 — further
out than the roll (3.20) and the skirt (3.20) both. It drew in front of the
new roll as a black band running the whole way round the ring.

It is deleted rather than moved. The roll is the apron edge now and does the
job that lip was standing in for. Its other stated purpose — keeping the strip
dark for VISUAL_BAR.md's `void_fraction` floor — is unaffected in the only
direction that matters: removing a lit surface can let more dark through, and
the floor is a minimum.

### The rope connectors are on the ropes

Two earlier goes were wrong in opposite directions. The sleeve started at 0.115
pointing inward from the post face, which was right for a bare corner and broke
out through the pad's rounded edge once there was a pad; shortening it to 0.055
buried it completely. The reference shows what neither could: a dark clamp on
the white rope itself, at the point it meets the cushion. So the fitting moved
onto the rope, straddling the line where the pad's edge crosses it.

### The steps are silver

Raising the tint from 0.62 to 0.80 did nothing visible. `DiamondPlate009`'s
colour map is a warm rusted steel and it MULTIPLIES, so the steps kept
rendering a muddy tan whatever the tint said. `albedo_map: false` is what
made them silver — the case the library's own `SPEC_DEFAULTS` note describes,
a surface whose tint is the point. The plate's normal and roughness maps still
carry the grid the photograph shows.

### The canvas, and the anchor it moves

The owner supplied the AEW mat artwork; it is mapped 1:1 over the square.

**It takes the mat off its exposure anchor, and this is not hidden.** Measured
on a clean patch of mat in `wide_broadcast`, relative luminance goes from
0.443 mean / 0.466 median to 0.322 / 0.326. The old value sat essentially dead
on the reference 0.46 that an earlier round solved ring exposure against; the
new one is about 30% below it.

Nothing in the suite pins it — 381 tests still pass — because the mat value is
measured by the capture gate, not by gdUnit. The artwork is applied as
supplied rather than quietly brightened to hold the anchor: lifting someone's
supplied art to satisfy a number is a decision for whoever owns the look, not
a silent correction. Re-solving ring exposure against the new canvas is the
fix when that call is made.

### Checked and not changed

The steel steps' POSITION. The reference shows them butted hard against a
corner post, which is where they already stood.

381 tests pass. `ring.glb` rebuilds byte-identical, and
`contact_probe --seeds 1,2,3` is unchanged at 985/1931/2494.


## Round: the post behind the pads, and the connector between them

Both reported from a frame, and the first is a mistake this file has now made
three times in the same corner.

### The post was coming through the cushions

The pad clears the post on the corner diagonal -- that relationship was
already reasoned out and already asserted. The assertion was `pad_inner <
post_inner`, which passed: 4.111 against 4.133, 2.2cm of clearance.

The pads carry a 4.5cm bevel. A bevel pulls the front of a box BACK by up to
its own width, so across most of the cushion's face the post's inner corner
stood through it -- a faint chevron on every pad, visible from inside the ring
and invisible to the test.

This is the third time the same shape of error has been made at this corner:
a fitting that clears a pad's flat face and shows at its rounded edge. The
first two were the sleeve at 0.115 and then at 0.055. So the number moved
where it can be tested: `TURNBUCKLE_PAD_BEVEL` now lives in `ring_builder.gd`
with the clearance it eats into, rather than in `ring.py` with the other bevel
widths, and the test asserts `clearance > bevel` instead of `clearance > 0`.
The pad moved inboard, 3.013 -> 2.979, taking the
clearance to 7.0cm; at the old 3.013 the strengthened test fails.

### There was no connector, because nothing modelled one

The reference's corner is not three plain cushions. Every rope ends in a flat
steel bracket with a row of bolt holes, bolted through the pad into the post,
and it is the only light-coloured thing in a corner otherwise made entirely of
matte black -- which is exactly why its absence read as "featureless" rather
than as "missing part".

Twelve plates, one per rope height per corner, centred ON the pad's inner face
so half the depth is buried and half stands proud: a plate bolted through a
cushion, not a box parked against one. They take the steps' bare steel rather
than the post's paint. `test_every_pad_carries_a_connector_plate` pins the
"stands proud" half, because a plate pushed fully inside the cushion is
invisible and would pass any test that only counted geometry.

*(Superseded -- see "the white blocks come off the turnbuckles" below. The
plates rendered as white blocks and were removed; this round is kept as the
record of why they were added.)*

The rope clamps from the previous round stay: in the reference those are the
black sleeving on the rope either side of the bracket, and they are a
different part doing a different job.


## Round: the AEW mark on the turnbuckle pads

The owner supplied the pad artwork. Placing it took four goes, and three of
the four failures were invisible in the sense that mattered — nothing was
missing, it was just wrong.

### A decal, not a mapping

The pads are bevelled boxes built through `venue.py`'s `_beveled`, and
anything that goes through `finish()`'s `projected` set gets a world-metre
planar projection: right for tiling cloth, useless for landing one logo the
right way up, once, on one face of twelve boxes. So the artwork is a flat quad
with authored UVs sat 4mm proud of each cushion, and the cushion's rounded
silhouette is left alone behind it.

The quad is inset from the pad's full size by the bevel on each side, so it
lands on the flat of the face rather than on the rounding. Those two numbers
are literals rather than `WIDTH - 2 * BEVEL`, because `venue.py` parses its
constants out of `ring_builder.gd` and takes plain numbers only — an
expression there stops the ring exporting at all. A test holds them to what
they mean.

### Three ways to get a quad wrong

**The projection overwrote the UVs.** `TurnbuckleFaces` is excluded from
`projected` now.

**`recalc_face_normals` reversed the winding.** It finds the outside of a
closed solid; each of these quads is an open sheet and its own connected
component, so it had nothing to go on. `finish()` already had `face_toward`
for this, and it cannot help here: it takes one direction per part, and twelve
quads on four diagonals have area-weighted normals that sum to nothing. So
`finish()` grew a third escape, `keep_winding`, for a part whose facing is
authored.

**The authored winding was itself half wrong.** The quads were built from the
same `(-sx, 0, sz)` tangent the pads and connectors use. Either perpendicular
will do for placing a symmetric box, but a quad's winding is a cross product
and its sign follows the parity of `sx*sz` — so two corners of four came out
facing the crowd. `(-sz, 0, sx)` is parity-independent.

None of the three rendered as an absence. The material is two-sided, so a
backwards quad shows its logo MIRRORED — glaring on a letterform, and on any
tiling texture something that would never have been caught. That is why
`test_every_pad_artwork_quad_faces_the_mat` measures the shipped normals
rather than trusting the frame.

### The connectors moved twice

They were centred on the pad face, which was a fair reading of the reference
until the face had artwork on it — a steel plate parked over the middle of the
logo. The reference puts the bracket at the rope end anyway. The first move
kept them 0.20 wide at +/-0.15, which against a 0.43 face left only a sliver
of logo showing through the middle; 0.10 at +/-0.205 puts them on the
cushion's ends where the ropes enter.


## Round: re-solving the exposure anchor

The mat is an exposure ANCHOR, not a bar: VISUAL_BAR.md wants it at 0.43-0.49
relative luminance, because the wrestler figures are absolute luminances and
comparing those to a broadcast still only means anything once the brightest
surface both share is matched. The supplied AEW canvas has a field of 0.636 in
sRGB where the old one was near-white, so the same rig rendered a much darker
mat and the anchor went with it.

### Solved on top_energy, empirically

`arena_lighting.gd` names the lever itself: straight-down top light lands on a
horizontal mat far more than on a standing figure, so it buys mat luminance
without flattening the mat<->wrestler gap the way the key or the rim would.
Measured with `tools/refs/measure_silhouette.py` on forward_plus, which is the
only renderer these numbers mean anything on:

| top_energy | mat | mat<->A | mat<->B |
| --- | --- | --- | --- |
| 5.0 (was) | 0.252 | 0.091 | 0.103 |
| 12.0 | 0.330 | 0.132 | 0.160 |
| 18.0 | 0.387 | 0.160 | 0.201 |
| **24.0** | **0.437** | 0.185 | 0.236 |

Solved empirically rather than by arithmetic, because the curve compresses as
it climbs the filmic shoulder: +0.078 for the first seven units, +0.050 for
the last six.

**The mat was already below its anchor before the canvas landed.** 0.252
against a 0.46 that an earlier round claimed to have reached. So this round
fixes more than the texture change caused, and the honest reading of the
earlier "mat reaches the reference 0.46" is that it did not survive whatever
came after it.

### What the sweep corrected in the file's own comment

`top_energy`'s comment said a standing torso's N.L under a downlight is "near
0". That is true of a chest and false of a wrestler: over the sweep the mat
gained 0.185 and wrestler A gained 0.092, so a figure takes about HALF the
mat's share of straight-down light. Shoulders, heads and forearms are
horizontal too.

That is why the gaps improve a long way and still do not reach 0.24-0.31:
closing them on this lever alone would need the mat near 0.55, outside its own
band. They are a genuine second problem needing a second lever (rim down, or
the wrestler materials), and they were failing before this round at 0.091 and
0.103 -- this leaves them at 0.185 and 0.236, roughly double.

### Checked, not assumed

`void_fraction` is 0.000 before AND after, so the brightening does not breach
VISUAL_BAR.md's 0.010-0.066 floor -- it was already outside it, which is a
pre-existing condition this round neither caused nor fixed. Frame sd rises
0.162 -> 0.238.

`measure_look`'s bright>0.5 goes 2.30% -> 15.56% against references of
1.46-6.12%. That is framing, not exposure: the silhouette shot is tight on the
ring so the mat is a fifth of its pixels, and a mat correctly sitting at 0.437
puts much of that fifth over 0.5. The reference frames it is compared against
are wide bowl shots that are mostly dark crowd. It is recorded here rather
than treated as a pass or a failure, because the two framings are not
comparable and measure_look.py's own docstring says so.


## Round: all four figures inside the band, on the renderer that ships

VISUAL_BAR.md's four figures are, for the first time, all inside their
reference bands on `forward_plus`:

| | before | after | reference |
| --- | --- | --- | --- |
| mat luminance | 0.437 | **0.436** | 0.43-0.49 |
| mat <-> wrestler A | 0.185 | **0.287** | 0.24-0.31 |
| mat <-> wrestler B | 0.236 | **0.253** | 0.24-0.31 |
| wrestler <-> wrestler | 0.051 | **0.034** | 0.00-0.07 |

The earlier "all four inside" result, in the round that built the harness, was
measured on `gl_compatibility` -- a renderer `project.godot` does not ship.
This one is on the shipping pipeline.

### The planned lever did nothing

The round was planned around `rim_energy`, on the strength of its own comment:
*"rim light lands on the wrestlers, and every unit of it CLOSES the 0.24-0.31
gap the bar wants."* That is a sound argument about light, and it is not what
this rig does. Holding everything else fixed:

| rim | mat | mat<->A | mat<->B |
| --- | --- | --- | --- |
| 2.2 | 0.437 | 0.185 | 0.236 |
| 1.2 | 0.435 | 0.184 | 0.235 |
| 0.6 | 0.433 | 0.185 | 0.234 |

Cutting it by 73% moved the gaps by 0.001. The fixtures are aimed across the
ring from behind, so at the spawn standoff they rake the figures at a grazing
angle and barely reach a front-facing silhouette. **So rim was left at 2.2.**
Spending the cool back light that separates a figure from a dark crowd, for
0.001 of a gap, would be paying for nothing. The comment is corrected in place
rather than deleted, because it sent this round down the wrong path first.

### It was never a lighting problem. It was one man's shorts.

Converted to absolute luminance, the failure was an asymmetry, not an offset:
WrestlerA's `attire_body` was a bright blue at 0.587 relative luminance against
WrestlerB's 0.212 -- **2.8x** -- and A was the figure that was furthest out.
Scaling A's attire and accent uniformly by 0.375 (which holds the hue, and so
`MIN_HUE_SEPARATION`) moved A from 0.185 to 0.286 on its own.

### The second dead wire

B was then 0.005 short, so the same treatment was applied to his
`attire_body` -- and the rendered figure did not move by a thousandth.

`WrestlerAttire.variant2_body()` dresses **every** one of its pieces from a
fixed colour (`DENIM`, `BOOT_BLACK`, `SHOE_WHITE`, `STEEL`, `WAIST_*`) or from
the accent. Not one reads `attire_body`. WrestlerB is `body_variant = 2`, so
his `attire_body` has never reached the screen. It is left at its original
value in `match.tscn` with a comment saying so, rather than carrying a
plausible-looking number that does nothing.

He was darkened on `DENIM` instead -- his shorts, the only surface on him
large and bright enough to matter at 0.449 -- scaled by 0.6. That took B to
0.253 and, because B rendered BRIGHTER than A, pulled A<->B *down* from 0.051
to 0.034 rather than widening it.

### A test that is now measuring a dead value

`test_the_two_wrestlers_separate_from_each_other_by_hue` asserts a hue gap
between the two `attire_body` colours. For WrestlerB that value does not reach
the screen, so for him the test pins a number with no rendered consequence --
the same failure mode as the albedo gate this suite already removed, where
"a gate that reads a different quantity from the one it names is not a gate".
It is recorded here rather than quietly rewritten, because deciding what that
test should assert instead is a design question, not a cleanup.

**Worth looking at before the next art pass:** with A in dark navy and B in
dark denim, the two men now read closer in HUE than they did. The bar wants
them close in VALUE and they are (0.034). They still separate by physique,
silhouette and B's green accents -- but the old bright-blue-versus-red
contrast is gone, and that was never what the bar was asking for.

### Checked, not assumed

`void_fraction` 0.000 before and after, unchanged. Whole-frame distribution
essentially unmoved (bright>0.5 15.56% -> 15.32%, p50 0.0294 -> 0.0292).
The frame was looked at: both men separate cleanly from the mat and neither
is muddy.


## Round: the white blocks come off the turnbuckles

The connector plates added a few rounds ago (see "There was no connector,
because nothing modelled one") are removed. `tools/blender/ring.py` no longer
builds `TurnbuckleConnectors`, `ring_builder.gd` no longer carries the
`CONNECTOR_*` constants or the material binding, and `ring.glb` is rebuilt at
8360 triangles.

### Why the part that was added on purpose came off again

The reasoning that added them still reads correctly and still produced the
wrong pixels. The reference's bracket is legible because it is a plate **with
bolt holes** catching a highlight across a matte corner; the shape of it is
what makes it a bracket. Ours had the value and neither of the other two.

At 0.10 x 0.085m, wearing `_bare_steel()`, it was the only bare-steel surface
above the apron -- so against a 0.055 cushion each plate resolved to a plain
white block. Two per rope, six per corner, stacked up the post and brighter
than the AEW artwork they were placed at the ends of specifically to keep
clear. The eye found them before it found the mark, the wrestlers or the mat.

Deleted rather than darkened. A plate that is not brighter than the cushion is
not reading as a plate, it is 96 triangles of nothing; and the honest fix --
modelling or texturing the bolt holes -- is a different piece of work. The
removal note in `ring_builder.gd` says so, so that if it comes back it comes
back with the holes.

### The test inverted rather than deleted

`test_every_pad_carries_its_connector_plates` and
`test_the_connector_plates_clear_the_pad_artwork` are replaced by one
`test_no_pad_carries_a_connector_plate`, asserted off the shipped mesh. A
regenerated `ring.glb` that quietly brings the part back now fails in the
suite rather than in someone's screenshot -- which is how the blocks were
found in the first place.

### Checked

Rebuilt twice, byte-identical both times (md5 88bc953a...), so the mesh still
diffs like the `.tres` bakes. Rendered afterwards through the match camera:
the corners read as three black cushions with the artwork clear and the ropes
running into the clamps, which is what the reference's corner is.


## Round: the mat's artwork, the corner, and the steps

Three corrections in one pass, all of them things the build had modelled and
none of them things it had looked at from the camera that ships.

### The canvas logo read rotated 90 degrees

`_build_canvas` mapped the mat's UV square u to +X and v to +Z. The broadcast
camera is anchored on -X and looks up +X (`match.tscn`), so its screen-right
is +Z and "away from the lens" is +X -- which put the logo's baseline running
directly away from the camera. Every frame of the match had the mark on its
side.

`ring_canvas.png` is drawn upright, so this is a mapping bug rather than an
artwork one, and the fix is a quarter turn of the UV square:

    u = (z + MAT_HALF) / 6    reading direction along screen-right (+Z)
    v = (MAT_HALF - x) / 6    texture-down toward the camera (-X)

Handedness was checked rather than assumed -- from the camera the mat's
(screen-right, screen-up) is (+Z, +X), whose cross product is +Y, the mat's
own normal, so the mark comes out turned and not mirrored. The render settled
it either way: ALL ELITE / AEW / WRESTLING now reads left to right.

### The corner was a pillar with bolsters on it

The post was a 0.155m square column wearing a cap plate 1.22x its own section,
and each rope ended in a cushion 0.52 x 0.24 x 0.30. Against the reference
that is a structural pillar with three bolsters: the cushions were deeper than
they were tall, the 0.35m rope spacing left only 0.11 between them so the
three read as one black column with notches in it, and the plate gave every
corner a lid.

- the post is a tube now, `POST_RADIUS` 0.052 (0.104 across, which is 4-inch
  pipe), `POST_SIDES` 12, capped with a disc proud by 6mm rather than a plate
  overhanging by a quarter of the post's width
- the pads are 0.46 x 0.15 x 0.20, bevel 0.025. The gap between cushions goes
  from 0.11 to 0.20 -- wider than the pad, which is what the reference shows

The depth is a floor, not a taste call. The pad has to clear the post's tube
on its inner face and swallow the rope ends on its outer one, and those two
faces are 0.143 apart before any bevel comes off; 0.20 is about the thinnest
cushion that spans them. `TURNBUCKLE_PAD_XZ` moves 2.979 -> 3.003 so the pad
straddles the post rather than sitting inboard of it, which is also what stops
the white rope ends poking out of the cushions.

### The steps stood at the corner without being in it

They already sat at a corner -- two sets, diagonally opposite, measured at
|z| = 2.924 against a post face at 3.095. What they did not have is the detail
every ring-steps casting has: a **45-degree corner missing from the top
tread**, which is what lets the tread pass the ring post.

Without it a flight can only stop beside a corner. So the flight now runs out
to the apron's own corner at `APRON_OUT`, and the top tread is built as a
notched prism rather than a box, `STEP_CORNER_NOTCH` 0.26 on each leg. On the
corner flank the top tread's stringer starts after the cut so it follows the
notch instead of spanning it.

### Tests

`test_the_steps_stand_at_a_corner_beside_a_post` was measuring the MEAN of the
step mesh's vertices, which moved 7cm when the tread was notched -- because a
notch redistributes vertices without moving the flight at all. It measures the
flight's extent now: far end at the apron's corner, near end a tread width
back. That is the thing the test is named for.

`test_the_top_tread_is_notched_for_the_post` is new and asserted as an
absence: no top-tread vertex lies inside the triangle the cut removes. A test
that counted geometry, or checked a bounding box, would pass just as well on a
square tread.

`test_the_turnbuckle_pad_stands_proud_of_the_post` now takes the post's
nearest point as centre-less-radius rather than as a square corner.

12 cases, 0 failures. `ring.glb` rebuilt at 8120 triangles, byte-identical
across two runs.


## Round: the rig stops being a follow-cam

Six recommendations out of the camera analysis, implemented. The through-line
is that `MatchCamera` had **one shot** — a follow-cam strapped to the pair —
and a televised match does not have one shot.

### 1. The reference was the wrong promotion, and the wrong medium

`camera.md`'s every number comes from `gauntlet/refs/raw/`, which is WWE 2K
gameplay video and WWE promotional stills. `ring.md`, `stage.md`, `arena.md`
and `lighting.md` are all measured against AEW *Dynamite* photographs. The
camera was the one subsystem calibrated against a different promotion AND a
different medium — a video game rather than a broadcast — and the file did not
say so. It says so now, at the top, before anything else.

`aew_grand_slam_broadcast.png` has been in the repo since the lighting pass.
`lighting.md` measures its luminance distribution; nobody had measured its
**framing**. Measured now, by the same pixel-grid method the rest of the file
uses:

| quantity | value | how |
| --- | --- | --- |
| subject fill | 0.072 | the standing referee spans rows 412–467 of 768 |
| depression | ~40° | the mat is a square seen corner-on; its projected diagonals give 42.5° and 38.5° |
| stage side | frame left | screen and portal left of the ring, desk right |

And the honest part: all four AEW stills are establishing wides or floor-level
ringside. **There is still no AEW reference for the framing a match is covered
in.** That gap is named in `camera.md` rather than papered over, with the
arithmetic to re-solve the master's lens the moment one arrives.

### 2 & 3. A hard camera, and a lens that belongs to the shot

These are one change, because the second is what makes the first possible.

The rig's `fov` lived on the Camera3D, so the lens was a property of the
CAMERA rather than of the shot it was taking — which is exactly why there
could only ever be one shot. `shot_fov()` now returns the lens per mode.

That matters because distance and focal length are independent, and the
difference is the whole look of a broadcast. Holding a wrestler at the same
fraction of frame from 29m instead of 3.5m takes a long lens, and the
compression it brings — a flat wall of crowd stacked behind the ring — is the
single most recognisable property of a master shot. A 32mm lens from the back
of the bowl frames the building.

`Mode.HARD_CAM` is anchored at (-28.5, 8.3, 0), and that is **not a framing
choice** — it is a seat in the building `arena_bowl.py` already builds:
`BOWL_STRAIGHT_X` 4.425 + `BOWL_FIRST_ROW` 10.13 puts row 1 at 14.56 out,
twelve `ROW_RUN` 0.95 rows plus `CONCOURSE_DEPTH` 2.6 reach 28.56, and twelve
`ROW_RISE` 0.48 rises over `FLOOR_Y` -1.10 reach 8.26. It looks down at 14.4°.
The lens is 14°, a 98mm equivalent, which frames a wrestler at 0.247 — between
the reference's 0.072 establishing fill and the handheld's measured 0.32–0.41
standoff, which is where a master belongs.

The framing solve had to stop reading the live `fov` in the same breath. The
containment guard and the fill fit both reproduce measurements taken on a
41° lens; solved against the master's 14 the guard demanded 8.6m where the fit
wants 6.7, so the engineering limit started choosing the shot. Caught by the
test that exists to catch exactly that.

### 4. The handheld stays low, and that is now correct

The recommendation was "raise the follow-cam above the top rope, OR accept it
as the ringside handheld and let the hard camera be the master". Taking the
second branch, because it is the more faithful one and it costs no
measurement: a real ringside handheld **does** shoot through the ropes. The
1.45m eye height camera.md measured is right for what that shot now is. It is
the master, 30m out and 8m up, that has to see over them — and it does.

What did change is the handheld's BEARING. It used to be read back off the
camera's own position, which worked only while nothing ever moved the camera.
One cut to the hard camera and the off-axis 3/4 angle `match.tscn` was placed
for would have been gone forever; the handheld's bearing is its own property
now.

### 5. The commentary desk

The cheapest missing thing in the wide shot, and it was missing because
nothing had ever taken a wide shot. `aew_low_angle_led_wall.jpg` shows it from
the floor; `aew_grand_slam_broadcast.png` shows where it sits.

On +Z, which is the master's screen-right — the same solve that turned the
mat's artwork the right way up. Placed by what it has to fit between rather
than by a measurement: apron at 3.20, barricade at 6.00, so a 0.72 desk
centred at 4.40 leaves 0.84 of walkway either side. Fascia, an overhanging
worktop, three monitor boxes. The overhang is the part that does the work — a
desk reads as a desk from the shadow line under its lip, and flush it is a
crate.

### 6. The shot clock

Between events the rig alternates master (7.0s) and handheld (4.5s). Events
pre-empt it and reset it, so a scheduled cut can never land in the middle of a
finish, and a finisher or three-count cut comes out onto the MASTER rather
than onto whatever was on screen before it.

The hold times are **project values and are not defended as measured**.
`camera.md` has marked cut duration pending since it was written, and a still
cannot carry a duration — all four AEW references are stills. What is defended
is the shape: master longer than handheld, both in seconds.

And a cut is now INSTANT. The rig lerped into every mode change, which was
harmless when there was one position to lerp from and is a 28m fly-in now. A
move between two angles is the one thing a vision mixer cannot do.

### Tests

19 in `test_camera_framing.gd`, 4 in a new `test_ringside_desk.gd`.

Two existing ones had to change meaning rather than numbers, which is worth
recording:

- `test_a_cut_still_tracks_the_wrestlers` asserted the camera MOVES when the
  pair does. A hard camera that moves is not a hard camera. It is now
  `test_no_shot_ever_stops_tracking` and asserts what both kinds of shot owe:
  wherever the pair goes, the shot is pointed at them — compared in PLAN,
  because every shot aims above the pair and a 3D bearing to their feet is off
  by 15° even when the framing is perfect.
- the fill and containment tests now state which SHOT they are measuring.
  Fill is a property of a shot, there are four, and the rig's default is no
  longer the one camera.md measured.

`ringside.glb` rebuilt at 1528 triangles, byte-identical across two runs.
Every shot closed on a rendered frame through the rig's own camera.

### The fog's invariant, which the master broke

Worth recording because it is the kind of thing that stays broken quietly.

`arena_lighting.gd`'s depth fog (compatibility renderer only — forward_plus
uses the volumetric rig) documents its `FOG_BEGIN` of 13.0 as chosen so that
no ring geometry is ever inside the fog: "the camera sits 3.2-9.0m from the
pair's midpoint and the far ropes are at most 3.1m past that midpoint, so no
ring geometry is ever more than ~12.1m from the lens."

The hard camera is 28.5m out, which puts the far side of the ring ~32m from
the lens — nineteen metres inside a fog begin written to stay outside it. A
constant cannot be right for both shots: 13.0 is what gives the handheld its
depth, and anything that clears the master's ring would leave the handheld's
barricade unfogged, which is the whole reason the fog exists.

So it tracks the shot, the same way the lens does — `_process` sets
`fog_depth_begin` to the camera's own distance plus the ring's reach, floored
at the measured 13.0. At the handheld's 3.2-9.0m the floor wins and every
number measured on that shot is untouched; at the master's 28.5 the ring falls
outside the fog exactly as the note always claimed.

## Round: the pose was reclining and the punches landed on a man who did not move

Two reports, one root cause between them. "Cody and Roman are standing in a
weird pose"; "when punches land, check the opponent is hit and recoils".

Three instruments were needed before any of it could be argued about, because
every existing one looked at a single wrestler or at a number with no picture
attached.

### The probes

`tools/probe/pose_compare.tscn` plays one clip on every rig the game ships —
the mannequin, Cody, Roman — through each model's own adapter, samples the live
skeleton, and normalises by that rig's own height so a taller model does not
read as a different pose. It also reports how far each bone travels from frame
0, which is the number a reaction lives or dies on.

`tools/probe/exchange_shot.tscn` squares two roster models up at a distance the
move's own measured reach covers, throws one strike, and grabs **every tick**
from wind-up to recovery with both FSM states and the contact geometry printed
beside each frame. Roman to Cody: the jab's contact lands on frame 10 and Cody
is in `HIT_REACT` on tick 11; the cross lands on 12 and he reacts on 13. The
hit machinery was never the suspect and now there is a picture of it working.

`tools/probe/clip_shot.tscn` was **lying**. It borrowed the authored library
onto a roster model raw, and those tracks name `Armature/Skeleton3D:<bone>`,
which resolves on the mannequin and on nothing else. Every track silently
failed to resolve, so the probe rendered Cody's bind pose and Roman's flat T
and labelled them with clip names. It goes through the model's adapter now and
counts resolving tracks per clip, loudly. Two clean-looking contact sheets,
neither of them of a clip.

### Roman was standing 22 cm short of the pose

Measured on `Idle_Ready`: Cody's hands land within **0.0 cm** of the
mannequin's and Roman's **22.1 cm** below them, while his head and pelvis track
to within a centimetre. So the torso retarget was sound and the arms were not.

The cause is a rest-**pose** difference on top of the rest-**orientation** one
`RomanModel`'s conversion already handles. Read off the two skeletons:

| bone | base rig | Roman |
| --- | --- | --- |
| upperarm | y 1.441 | y 1.396 |
| lowerarm | y 1.441 | y 1.330 |
| hand | y 1.441 | y 1.270 |

The base rig rests in a flat T. Roman rests in an A, the arm descending 0.126 m
across its span — about 15°. Preserving each key's offset from its own rig's
rest preserves that 15°, and since these clips are authored as absolute hand
positions in metres solved against the base rig's geometry, what has to survive
the retarget is where the hand *ends up*.

So each bone's rest is aligned first: Roman's rest bone direction rotated onto
the base rig's, measured between the bone and its first mapped child rather
than read off a bone axis, which the two rigs disagree about anyway. The roll
correction is untouched — this removes only the swing. After: hands 4.6 cm out,
and the residual is constant from frame 0 onward, which is Roman's own
proportions (his shoulders sit at 0.925 of his height against the mannequin's
0.984) rather than the retarget.

### The sign was upside down, and had been since the clips were authored

`rig_pose._euler()`'s docstring says a positive pitch "bows forward". It does
the opposite. Measured off the rest pose, one axis at a time, head taken
relative to pelvis:

| pose | head |
| --- | --- |
| spine lean −30 | 0.241 m in **front** of the pelvis |
| spine lean 0 | 0.055 m in front |
| spine lean +30 | 0.133 m **behind** it |
| hips pitch −30 | 0.374 m in front |
| hips pitch +30 | 0.278 m behind |
| head pitch ±30 | moves the head bone's origin under 2 cm either way |

That last row matters on its own: head pitch aims the face, it does not carry
the skull across the frame. What carries a head is the spine chain underneath
it — which is why a reaction table reading `head=(-24, …)` looked, on paper,
like a man being knocked backwards and measured as 6.4 cm.

`Run_Drive` found this in its own clip and fixed itself — "needed a negative
lean and for years had a positive one" — and its note says the stance still
carried +12, a recline every clip inherits, "because correcting that moves all
29 and is its own job". The wrong docstring then sent the next authoring pass
the same way round again. The **text** is fixed rather than the sign: every
clip is expressed against this convention, and flipping it would move the lot.

### What changed, and what it measures

**The stance.** `spine` 12 → −10, so a wrestler at rest is coiled over his
front foot instead of reclined off it: his head sat 4.5 cm *behind* his pelvis
and now sits 8.0 cm in front. The guard widens with it, from 0.30 m apart —
inside the 0.384 m shoulder width, elbows pinned to the ribs, rendered as a man
holding something in front of his chest — to 0.45 m.

**The reactions.** `Hit_React_Head` moved the head **6.4 cm** while
`Hit_React_Torso`, on the same rig through the same code path, moved it 33.8 cm
— a head shot shifting the head a fifth as far as a body shot is "the opponent
is hit and nothing happens", and it is a comparison inside this clip set rather
than an appeal to how a punch ought to look. It was leaning the wrong way *and*
taking five frames to get there, against `combat-animation.md`'s "2–4 frames
impact pose, snap to impact". Impact now lands on frame 2 and holds to 4.

The two reactions are now separated by **direction** rather than size: a head
shot drives the head 0.20 m backward off his heels, a body shot folds him 0.12 m
down around it. Head travel 36.0 cm and 22.6 cm respectively — which is the
head shot measuring *larger*, because a torso rocking back off a forward-leaning
stance sweeps a wider arc than one folding down. Size was the wrong thing to
assert and the test says so.

**The strikes.** All four lean forward through the punch rather than back, and
the two kicks lean *away* from the boot as the counterweight they were already
described as being. The punches hold the stance's own lean through contact
rather than bowing further into it: bowing carried the head out with the fist
and the punch stopped reading, while the measured reach never moved.

`Tie_Up_Collar` and `Grapple_Hold_Neutral` were tried the same way and put
back. Poses here are absolute hand positions, so leaning the chest in carries
the shoulders toward the hands and folds the arms up — the reach that makes a
lock-up read is worth more there than the lean, and the rendered frames said
so. That is the general shape of this file: the sign being wrong does not make
every value that compensated for it wrong.

### What holds it

`tests/test_clip_readability.gd` asserts what the clips **do**, in centimetres,
rather than what they are made of. `test_authored_clips.gd` already checks that
every clip exists, is the right length, loops when it must and poses the whole
body — all of which was true of a reaction that moved the head 6.4 cm. The new
floors are set below measured values, to catch a clip going quiet again:

| clip | measured | asserted |
| --- | --- | --- |
| `Hit_React_Head` head | 36.0 cm | > 15 cm, and backward > 0.15 m |
| `Hit_React_Torso` head | 22.6 cm | > 15 cm, and down > 0.08 m |
| `Strike_Jab` left fist | 31.7 cm | > 15 cm, and further than the right |
| `Strike_Forearm` right fist | 43.1 cm | > 15 cm, and further than the left |
| stance | head 8.0 cm ahead of the hips | > 4 cm |
| guard | hands 0.45 m apart | > 0.38 m |

Re-measured after the rebake (`tools/anim/measure_contact_offsets.gd`), every
strike's limb now peaks on exactly the tick its `MoveDef` applies damage: jab
0.654 m, cross 0.679 m, kick 0.820 m, heavy kick 0.818 m. The four `.tres`
offsets that moved are updated, `gait_audit` passes, and the glb rebuilds
byte-identical.

### What the match measures, and two things it does not

`tools/probe/strike_connect_probe.tscn` over eight AI-vs-AI seeds, after:

| seed | thrown | landed | |
| --- | --- | --- | --- |
| 2 | 22 | 16 | 73% |
| 3 | 19 | 13 | 68% |
| 6 | 18 | 12 | 67% |
| 7 | 20 | 12 | 60% |
| 8 | 14 | 11 | 79% |

Seeds 2 and 3 are **identical, thrown for thrown and landed for landed**, to
the same probe on the same seeds before any of this — which is the check that
matters for a change to `MoveDef.contact_offset`: the clips moved, the match
did not. The rest of the misses are `unhittable`, a man already down, which is
suppressed by design.

Two things that probe reports and this round did not fix, named rather than
averaged away:

- **Seeds 1 and 5 throw nothing at all** — 0 strikes over a 20 000-tick
  budget. That is not a 0% connect rate, it is no data, and the probe prints it
  as though it were the former.
- **Seed 4 throws 404 and lands 4%**, running to the budget without the match
  ending, with 383 misses filed "off to the side" at a median angle of 0° off
  the attacker's facing — i.e. facing him, inside reach, and no contact. The
  same seed threw nothing at all on the build before this one, so there is no
  clean before/after to compare it against.

Both are about match flow and AI spacing rather than about what a clip looks
like, which is why they are here as findings instead of in the diff. **They
are fixed in the round below.**

## Round: a man fell out of the ring, and nothing could see it

The two findings the previous round wrote down and did not fix. Both turned
out to be instruments lying rather than the match misbehaving — and behind one
of them, a real defect that had been eating a match at a time.

### Seeds 1 and 5 threw nothing: the match was never in the tree

`strike_connect_probe` added each match with `get_tree().root.add_child(scene)`
from inside an `await` continuation of its own `_ready()`. The scene root will
not take a child while it is setting its own up, so that call failed — on the
**first seed of every run and only that one** — with

```
ERROR: Parent node is busy setting up children, `add_child()` failed.
```

one line into a log nobody reads, and then measured a match that did not
exist. It reported as `seed 1 thrown 0 landed 0 (0%)`. "Seeds 1 and 5" was
never about those seeds: both were simply first in their list.

`contact_probe.gd` already documents this trap and `title_launch.gd` is
credited with finding it. This probe just never got the fix. It now defers the
add and waits for `is_inside_tree()`.

The reporting is fixed alongside it, because a percentage cannot tell "nobody
landed a punch" from "nobody threw one". A seed that threw nothing now prints
`NO DATA` with the reason, is excluded from the total, and makes the probe
exit non-zero.

### Seed 4 landed 4%: he was 411 km below the mat

Traced tick by tick. At t2416 of a `GRAPPLE_HOLD`, WrestlerB starts stepping
out — 2.28, 2.54, 2.74, 2.89, 2.98, 3.04, 3.07 — past the mat's own edge at
3.0. There is no floor collider out there: `scenes/ring.tscn`'s floor is 6 m
square and the arena floor has none. He fell for the remaining 17 000 ticks and
finished **411 490 m** below the ring.

Everything downstream then read as something else. The match could not end,
because a pinfall needs the attacker within `COVER_RANGE` of a downed man.
Every strike thrown at him was filed as a miss "off to the side" at a median
**0°** off the attacker's facing — facing him, horizontally inside reach,
separated only in a dimension the miss report does not print. That one seed
contributed 383 of the 386 misses in a four-seed run and took the measured
connect rate from 70% to 10%.

The route out is `GrappleRig`. It **suspends** both bodies for the length of a
paired move and drives their transforms from the clip, so neither one collides
with anything — the rope walls are not in that code path at all. Its clamp is
on the pair's **midpoint** (`RING_HALF_EXTENT` 2.0); each wrestler then sits an
authored offset away from it, and the offsets reach past the mat.

So the clamp is per wrestler now, reached from both paths that can move one:
`WrestlerController.keep_inside_the_ring()`, called after `move_and_slide()`
and from `GrappleRig._physics_process()` for the bodies it has suspended.

`RING_KEEP_IN` is 2.6 — `MAT_HALF` 3.0 less the 0.4 capsule, so his far side is
exactly on the edge. It sits deliberately *outside* what the ropes already
enforce (their inner faces are at 2.95, so `move_and_slide()` holds a walking
man at 2.55), which is the point: it never fights the ropes, it only catches a
body that was never asked to collide with them. The vertical clamp is one-sided
— nothing legitimately goes below the mat, and a ceiling would flatten every
throw in the set.

### And the probe could not tell a finish from a stall

Printing "NEVER FINISHED" for the first time turned it on for all eight seeds
at once, which is how the third bug surfaced:

```gdscript
var over := false
referee.match_won.connect(func(_w, _m): over = true)   # assigns to a COPY
```

GDScript lambdas capture locals **by value**. `over` never became true, `if
over: break` never fired, and every match this probe has ever run went the full
20 000-tick budget whatever happened in it. `contact_probe.gd` and
`floating_probe.gd` both use a one-element Array for exactly this reason; this
one did not.

### Eight seeds, after

| seed | thrown | landed | |
| --- | --- | --- | --- |
| 1 | 16 | 12 | 75% |
| 2 | 22 | 16 | 73% |
| 3 | 19 | 13 | 68% |
| 4 | 24 | 15 | 62% |
| 5 | 33 | 24 | 73% |
| 6 | 18 | 12 | 67% |
| 7 | 20 | 12 | 60% |
| 8 | 14 | 11 | 79% |

**69.3% overall, eight seeds out of eight producing data, eight out of eight
reaching a finish.** Seed 4 went 4% → 62% and now throws 24 strikes rather than
404. The remaining misses are ordinary: 5 out of reach, 9 off to the side at a
median 59° off the attacker's facing — real whiffs at a real angle, not an
artefact of a man in low orbit.

`tests/test_ring_containment.gd` holds it: the extent leaves the whole body on
the mat and stays clear of the ropes, a wrestler put outside on any axis comes
back, one below the mat is put on it and stops falling, one lifted above it is
left alone, one already inside is not nudged at all, and the rig contains the
bodies it has suspended. 411 tests pass.

## Round: a body slam, and three things that were making every throw read wrong

The power rung comes back with one move, `power_bodyslam`, keyed in Blender
beat for beat against its partner like the two signatures. The moves cut
earlier were stitched out of borrowed clips and did not read; this one was
iterated on rendered frames until it did. Getting it to read turned up three
defects that were already in every paired move and every knockdown, which is
most of what this round is.

### The throw

36 frames, 1.2 s. Lock-up, the attacker ducks in with an arm through the
legs, scoops, and the victim tips forward over the arm and rolls onto his
back in the cradle. He is held flat across the attacker's chest at 1.12 m,
hangs a beat, and is dropped flat on his back.

The victim is carried **along his own axis** and it is the attacker who turns
90 degrees under him. The man being thrown has to land lying the way
`Down_Supine` lies, or the knockdown that follows spins him a quarter-turn on
the mat; turning the attacker instead puts the victim across his chest, which
is where a body slam carries a man. The height is all bone pose -- no root
leaves the mat -- so the trajectory stays clear of the airborne-landing
invariant in `build_paired_moves.gd`.

A grapple that did not knock a man down used to hand him a standing
`HIT_REACT`, which stood a slammed man straight up out of the clip's last
frame. `MoveDef.leaves_defender_down` puts him in `DOWN` for
`THROWN_DOWN_TICKS` (45) instead. It is **not** a knockdown: it leaves
`_damage_at_last_knockdown` alone, emits nothing, and he is not
cover-eligible, so a mid-match slam neither moves the finish nor hands out a
free cover. The slam and both signatures set it; the clinch knee, which ends
on its feet, does not.

The AI reaches for it once a match: a third reason to lock up, only inside the
band between `POWER_THRESHOLD` and `SIGNATURE_THRESHOLD` (past it the same
tie-up would draw a signature mid-match) and only for the man who won the
opening lock-up, since `can_power()` still asks for a landed grapple. One try,
won or lost (`WrestlerAI._wants_power_tie_up()`).

### 1. The man being thrown stood a quarter-turn away from the thrower

`GrappleRig._transform_track_into_pair_frame()` discarded the defender's
whole root rotation key, to stop the root pitching and rolling. But every
defender key is authored at yaw -90 -- that is what makes the two face each
other -- so through **every** paired move the defender faced the pair frame's
-Z while the attacker faced him down its X. Measured: attacker facing
(-1, 0, 0), defender (0, 0, -1), on the clinch knee and both signatures. Every
authored defender half was playing 90 degrees off its partner. It now keeps
the yaw and drops only pitch and roll (`GrappleRig.defender_root_yaw()`).

### 2. `SUPINE` was face down

Authored as `hips=(-84, 0, 0)` under a comment reading "hips rolled back",
which is the pitch-sign mistake the previous round found in `STANCE`: a
negative hips pitch tips a man **forward**. Measured through the probe, the
downed man's chest pointed at (0.03, -1.00, 0) -- into the canvas. Every
knockdown, cover and pinfall was played on a man lying on his front, lower
legs sticking up behind him.

The fix is the smallest one that makes him supine without moving him: the
same pitch, rolled 180 degrees about his own spine. His head and pelvis stay
where they were, so the cover placement and the getup -- both measured off
where he lies -- are unchanged. `Getup_Rise` gains one key (frame 5, on his
side) so the half-turn back onto his front is a roll and not a quaternion
guessing its way round. The two signatures' landings now settle into it.

### 3. Every lock-up swung the pair 90 degrees and stacked them

The pair frame's -Z pointed from attacker to defender, but every trajectory
stands them at +/-0.40 along its **X**. And the lead-in slid both men to the
frame's origin -- the same point -- before the clip's first key threw each
0.4 m sideways and turned them a quarter-turn in one tick. The frame's -X is
now the line they were standing on, and the lead-in slides each man to his
own first key (`GrappleRig._role_start()`).

### Measured

Twelve AI-vs-AI seeds, `ladder_probe`, against the same seeds on the build
before this round:

| | before | after |
| --- | --- | --- |
| finishes | 12 pinfall | 12 pinfall |
| power move landed | 0 matches | 12 matches |
| grapple moves / match | 4.8 | 5.7 |
| strikes / match | 15.9 | 13.9 |
| knockdowns / match | 2.1 | 2.1 |
| length | 914-3206 ticks | 1983-3755 ticks |

Worth saying plainly: the "1.0 grapple moves per match" earlier in this log
is out of date -- the build before this round already threw 4.8, including
two to four signatures from the winner. That is not this round's to fix, and
it is recorded rather than tuned.

`strike_connect_probe` (its three default seeds): 67.1% landed, against 69.3%
over eight seeds last round. The misses that moved are `unhittable`, which is
a slammed man lying on the mat, as designed.

### Tools

- `tools/probe/paired_shot.tscn` takes `--side`, `--orbit DEG` and `--lit`,
  and holds its camera against `MatchCamera`, which had been cutting away
  from it mid-move. `state_shot` holds its camera the same way.
- `tools/blender/clip_sheet.py` renders any clip's keys on the mannequin in
  Cycles on the CPU, in about four seconds, under flat light. It is how
  `SUPINE` was caught: at match distance and under arena light a man on the
  mat is a few dark pixels either way up.

### Open, and deliberately not chased

The same sign mistake is still in clips this round did not need to touch:
`Pin_Cover` (the coverer leans back where the comment says "chest low"),
`Getup_Rise` past frame 10 (reclines as it rises), and the backbreaker and
neckbreaker defenders' mid-air beats. Each moves when its sign is flipped, so
each is its own job with its own renders. The cover also lands beside the
downed man rather than across him.

424 tests pass. The glb, both paired libraries and `strike_clips.tres` rebuild
byte-identical.

## Round: the cover leans in, and the get-up rises forward

Two clips that play in every match still carried the pitch-sign mistake the
previous rounds found in `STANCE` and `SUPINE` -- a positive lean tips a man
**back**. Both were fixed on `tools/blender/clip_sheet.py` contact sheets
first and then on the real match through `pin_shot`.

### Pin_Cover

Written as "chest low, weight through both arms into his shoulders", keyed at
hips 10-36 and spine 26-53: the coverer knelt beside the man he was pinning
with his torso tipped back away from him, arms stretched forward and down --
a man bracing not to fall over backwards. The leans are negative now, and the
palms are placed off the downed man's measured bones: from where the cover
kneels, the far shoulder is 0.75 m in front, the near one 0.35 m, both 0.15 m
toward the head and 0.22 m off the mat.

**The placement was wrong too.** `COVER_TOWARD_HEAD_M` was +0.90 along the
downed man's +Z, measured off a pose that has since been flipped end for end
and then rolled face-up. `pin_shot`'s bone print on this build:

| bone | local |
| --- | --- |
| Head | (0.00, 0.22, -0.69) |
| spine_03 | (0.00, 0.20, -0.42) |
| upperarm_l / _r | (+/-0.20, 0.14, -0.55) |
| pelvis | (0.00, 0.18, 0.00) |
| foot_l | (0.16, 0.11, +0.50) |

The body runs up **-Z**, so +0.90 knelt him past the man's boots. It is 0.40
toward the head now (level with `spine_03`), 0.55 out, and he faces square
across the body rather than at the pelvis, so his chest reaches over the
downed man's chest. `test_pin_cover_placement` asserts the new sign and the
square-across facing.

### Getup_Rise

The all-fours, one-knee, crouch and rising keys all reclined -- he came up
tipped back off his own knee. Leans negated, heads rebalanced to look ahead;
every key keeps its frame number, because the fast rise
(`GETUP_RISE_FAST_TICKS`) cuts this clip short and moving a beat changes what
a fast getup is. Side-on he now reads: back, side, tucked, over his hands,
over the planted foot, up.

### Measured

Twelve AI seeds: 12 pinfalls, each by the same wrestler as before, match
lengths within a few ticks except where a kickout's re-cover now starts from
the new spot (seed 12, +215 ticks). 424 tests pass; every bake rebuilds
byte-identical.

Still open from last round's list: the backbreaker and neckbreaker defenders'
mid-air beats.

## Round: the two signatures, the right way up

The last clips carrying the pitch-sign mistake (a positive lean tips a man
**back**; see `STANCE`) were both signatures -- the moves every AI match ends
on. Both were rebuilt against side-on and end-on `paired_shot --side --lit`
renders.

### Neckbreaker

The attacker reclined while "driving it to the mat", and the victim's root
trajectory lifted him 0.45 m on a back-drop arc pitched to -85. GrappleRig
keeps only the yaw of a defender's root key, so the pitch was discarded and
the lift was not: rendered, the victim floated straight up, draped over the
attacker's back and came down on his face.

Now nobody leaves the mat. The attacker takes the head and wrenches it down
and across to his right hip, bent over it with his knees giving; the victim
is dragged forward, twisted over (the forward-pitch-then-roll `SUPINE` and
the body slam use) and lands flat on his back with his head beside the
attacker's right boot. The trajectory is roots only -- `y` is 0 throughout.

### Backbreaker

The victim, "arched backward over the knee", was draped face-down over the
attacker's shoulder and went in head-first; its arc was hand-keyed straight
into `paired_moves.tres`, lifting his root 1.55 m with a pitch the rig threw
away.

It is built on the body slam now, deliberately: `Backbreaker_*` take
`Bodyslam_*`'s first 20 frames (the scoop, the roll onto his back across the
chest), then the attacker drops onto his right knee and brings the victim
down with the small of his back across the raised left one -- 0.20 to his
left, 0.28 in front, about 0.52 up -- arched face-up, head and legs hanging
either side. He hangs a beat and is poured off onto the mat into `SUPINE`.
The trajectory is generated from `TRAJECTORIES` like the others, and is
1.2 s where the old one was 1.0. A fix to the lift is now a fix to both
moves.

### Measured

Twelve AI seeds: 12 pinfalls, every one by the same wrestler as last round;
lengths move by a few ticks with the longer backbreaker. 424 tests pass,
including the no-root-under-the-mat and tucked-body clearance gates; every
bake rebuilds byte-identical.

That closes the list of sign-flipped clips this log has been carrying.

## Round: a cooler key, and the mat back on its anchor

### First: every render this session had been on the wrong renderer

A fresh container has no Vulkan driver. Godot says so in one line --
`Your video card drivers seem not to support the required Vulkan version,
switching to OpenGL 3` -- and carries on, so `--rendering-driver vulkan`
silently produces `gl_compatibility` frames, which VISUAL_BAR.md already
records as meaningless for the bar. On the commit whose round logged the mat
at 0.436, the fallback measured **0.341**; with `mesa-vulkan-drivers`
installed (lavapipe) the same commit measures 0.436, 0.287, 0.253, 0.034 --
the logged figures exactly. The evidence gate exists to fail that capture, and
it would have. **Install `mesa-vulkan-drivers` before measuring anything
visual**, and check for `Vulkan ... Forward+ ... llvmpipe` in the log.

Poses and motion do not depend on the renderer, so the animation rounds'
renders stand.

### Where the build actually was

On forward_plus, `fdb48e5`:

| | now | reference |
| --- | --- | --- |
| mat | 0.406 | 0.43-0.49 |
| mat <-> A | 0.265 | 0.24-0.31 |
| mat <-> B | 0.132 | 0.24-0.31 |
| A <-> B | 0.133 | 0.00-0.07 |
| warm/cool (wide_broadcast) | -0.109 | -0.333 |

Not a regression in the rig: the hard-camera round widened the silhouette
shot (the wrestlers went from 29k and 57k pixels to 6k and 17k) and nobody
re-measured. At that framing B faces the key bare-chested and reads twice A.

### What changed

The key and top were warm on purpose ("a warm key against a cool rim
separates a figure") and the frame measured warm for it -- the largest colour
gap against the broadcast still. Swept on wide_broadcast; the shipped pair is
where warm/cool comes inside tolerance before saturation overshoots:

| key / top | warm/cool | saturation |
| --- | --- | --- |
| (1.0, .975, .93) / (.95, .965, 1.0) | -0.109 | 0.273 |
| (.93, .965, 1.0) / (.90, .945, 1.0) | -0.196 | 0.342 |
| **(.88, .945, 1.0) / (.86, .93, 1.0)** | **-0.237** | **0.368** |
| (.86, .93, 1.0) / (.84, .92, 1.0) | -0.261 | 0.392 |

Cooling costs luminance, so `top_energy` was re-solved on the anchor:

| top | mat | mat<->A | mat<->B | A<->B |
| --- | --- | --- | --- | --- |
| 24 (warm) | 0.406 | 0.265 | 0.132 | 0.133 |
| 30 | 0.422 | 0.277 | 0.146 | 0.131 |
| **36** | **0.454** | **0.297** | **0.172** | **0.125** |

wide_broadcast, before -> after: warm/cool -0.109 -> -0.237 (reference
-0.333, now inside tolerance); mean luminance 0.141 -> 0.153 (0.168);
histogram distance 0.085 -> 0.087.

### Not closed, and why

- **B's gap (0.172) and A<->B (0.125)** are still out. That is B's colourway
  at this framing, not the rig -- the last time it was closed, it was closed
  on his gear -- and changing how a wrestler looks is the owner's call.
- **Highlights p95 0.641 against 0.427.** In wide_broadcast p95 *is* the mat,
  seen nearer its lit centre than the silhouette shot sees it. The anchor
  outranks it (lighting.md), so it rose with the anchor.
- **Saturation 0.368 against 0.306**, 0.002 past the critic threshold. The
  next step cooler fixes nothing that is out and puts it further over.
- **Fine and coarse detail** did not move (0.414 / 0.223 against 0.614 /
  0.343). They are geometry and texture, as lighting.md already measured --
  no light changes them.

424 tests pass.

## Measured, not changed: why the winner throws two to four signatures

Twelve AI seeds on the current build: the winner lands 2-4 signatures and the
last move before the pin is a signature in 11 of 12. Seed 2's trace shows the
shape -- a neckbreaker at 64 damage knocks the man down at 102, he kicks out
(the window is still wide at that damage), strikes, then the same neckbreaker
twice in a row, the second one pinned.

Three pacing rules were tried in a scratch checkout and **none shipped**:

| rule | winner's signatures | finish is a signature | note |
| --- | --- | --- | --- |
| as built | 2-4 | 11 / 12 | same move back to back |
| cap 2 landed, 3 strikes apart | <= 2 | 3 / 12 | loser's tie-ups become clinch knees |
| cap 2 attempts each, 3 strikes apart | <= 2 | 2 / 12 | matches longer, two winners change |
| 3 strikes apart, no cap | 0-3 | 4 / 12 | in two seeds the man with both signatures lost |

The signature is the finish *because* it is thrown repeatedly: any rule that
thins it out hands the finish to a strike. Which a match should be -- one
signature and a strike finish, or the repeated signature -- is a design call
for the owner. MATCH_FLOW.md now says so, and describes the power move.
