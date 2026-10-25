# Contact, contested shots and keeper response — 21 October 2026

Scope: an incremental gameplay pass under BR-002/021 (items 2/21 of 25),
BR-008 (8/25) and BR-009 (9/25). All remain in progress.

## Reference and motion contract

Use the existing PES-style gameplay plan and archived football references.
Applied the project `create-player` animation-production and diagnosing-bugs
workflows, consulting the shared Blender animation, rigging and Godot-export
guides. Inspected the current visual controller, imported rig, contact metadata
and the original keeper action authoring code. This pass changes runtime
coordination, decisions and visual timing; it changes no Blender curves,
geometry, rest transforms, weights, kit textures or the shared 19-clip library.

Priority gaps: moving kicks losing their contact window, first-time shots
expiring, follow-through blocking combinations, centre-only AI shooting, and
keeper prediction/reaction/contact inconsistencies. General stride/plant
quality, authored low/diving saves and final likeness are separate open gates.

## Reproduced failures and fixes

- A live shared 11v11 footballer missed a sprint pass and shot; their marker
  gaps were 0.532 m and 0.858 m. A jogging shot fired at a 0.351 m gap.
  The shot approach reused post-collision speed as a permanent speed cap,
  while sprint control continued its long touch during the wind-up. A bounded
  setup stride now follows the independent rolling ball and uses a shorter
  preparation touch. The twelve human/AI standing/jogging/sprinting cases each produce
  one kick, with marker gaps of 0.081–0.166 m in the focused regression.
- A ball beside the stationary player's body could be kicked at a toe gap of
  0.838 m. Root distance now authorizes approach only. The marker opens a
  maximum 65 ms assistance window and the real toe must come within 0.28 m
  of the physical ball. No ball or player position snap is used.
- The dribble spring could pull a ball from behind a turning player through
  his body. A reachable touch arc now applies both to the caller and to nearby
  candidates in control arbitration. Balls under the feet remain gatherable;
  a farther rear ball stays free while the body turns into reach. The mirrored
  midfield-to-shot scenarios pass after this correction.
- A released shot command expired before an incoming friendly pass arrived;
  shots could not interrupt receive settle or previous follow-through.
  Incoming shot intent now buffers, holds its charged power and schedules
  the authored contact. Redundant anticipation is skipped for fast first-time
  returns rather than playing the entire clip at extreme speed; actual clip
  playback is capped at 1.5× for these accelerated starts. The first-time shot
  produces one impulse with no trap; 8.5/18 m/s pass fixtures also require real
  foot contact. A new pass arms its pending contact after synchronous cleanup
  of the previous action, preventing that cleanup from erasing the new kick.
- Both teams rejected a free corner when a defender covered the goal centre.
  AI now evaluates five points inside the posts and passes the selected lane
  through to the actual shot. An immediate defender covering all lanes still
  discourages shooting. The mirrored physical test produces one shot per
  team while the defender closes, at about 0.11–0.14 m boot gaps. A trailing
  defender also forced a blind backward outlet despite clear goalward space;
  only a frontal challenge now justifies that backward escape. The actual
  midfield-to-shot regression again reaches a physical shot under pressure.
  Staggered tactical steering preserves a kicker's setup direction until
  contact by facing the live ball, without the old post-collision zero-speed cap.
  Clear edge-of-area looks use an editable 22 m default range and modestly
  distance-adjusted power. Committed recovery excludes new AI ball actions;
  an unavailable clip cannot consume the normal action cooldown.
- Rolling shots were projected below the turf; close saves ignored reaction
  time; balls already behind or moving away could be saved; the visible save
  started after impact. Ground-aware predictions, goal-angle positioning,
  reaction and approach checks, bounded standing reach and advance pose timing
  now apply to both keepers. They face the ball while shuffling. Hard shots
  are parried toward a side with fewer nearby rebound threats; slow claims
  retain the existing physical hold/distribution path. Selecting a keeper
  manually continues reflex timing without replacing keyboard movement.
  A short release interval also lets a low parry escape the keeper's own
  dribble assistance while opponents can still attack the rebound immediately.

## Match evidence

All full-match runs below use the actual 11v11 scene, 60 Hz simulation dt,
three-minute match clock, all actors on AI and the existing accelerated test
runner. Counts are observed contacts, not sampled decisions. These physics
runs are not guaranteed deterministic or evidence of statistical balance.

| Run | Shots home/away | Contested shots home/away | Saves home/away | Goals home/away | Sampled stationary-ball seconds |
| --- | --- | --- | --- | --- | --- |
| Baseline before this pass, home kickoff | 0/0 | Not instrumented | Not instrumented | 0/0 | 0 |
| Final pass, home kickoff | 0/2 | 0/2 | 1/0 | 0/1 | 0 |
| Final pass, away kickoff | 5/2 | 4/1 | 1/2 | 1/0 | 0 |
| Final pass, home kickoff repeat | 0/2 | 0/2 | 1/0 | 0/1 | 0 |
| Final pass, away kickoff repeat | 5/2 | 4/1 | 1/2 | 1/0 | 0 |

"Contested" means an opposing outfielder was within 5 m at the shot impulse.
The final runs total 18 shots (10/8 by team), 14 contested attempts, 8 saves and
4 goals. Machine-readable results are in [match_metrics.json](match_metrics.json).
The 0/2-shot home-kickoff fixture is retained: sustained balance and broader
play-quality acceptance remain open. Repeats here reproduce the same counts;
they do not establish a distribution across many match conditions. Canceled
contacts after a loss of reach remain valid football outcomes; these checks do
not force every animation to kick the ball.

## Verification and remaining work

Focused regressions cover live moving kick geometry, off-axis rejection,
first-time pass/shot buffering, receive/follow-through interruption, weighted
turns, stop/resume, AnimationTree playback, original pass/receive/shot markers,
mirrored contested lane choice/execution and keeper reaction/prediction/parry.
The retained 4v4 keeper and contact fixtures remain regression coverage.

Moving Web evidence is captured on the Kilmore pitch through
`scenes/review/gameplay_feel_review.tscn`; its driver pauses actual physics
checkpoints rather than setting standalone animation poses. The normal game
still opens at the title screen. Software WebGL evidence covers rendering and
integration, not native M1 frame rate or visual parity.

The final browser check passes with no console errors. Review the actual
[moving pass](contact_pass.gif), [shot](contact_shot.gif) and
[keeper response](keeper_response.gif); [web_motion_report.json](web_motion_report.json)
records the 24 checkpoints and physical contact events. These are 10 fps
checkpoint previews of 60 Hz simulation, with the other actors paused and
software-renderer shadows disabled. The standing keeper clip still needs
dedicated low-save and diving follow-ups.

Next gameplay acceptance: improve consistently sparse 11v11 attacking runs and
support without weakening defensive cover (BR-008, 8/25); inspect final-mesh
stride/plant transitions (BR-021, 21/25); author and integrate low/diving keeper
actions on the shared rig (BR-009, 9/25). Native human playtesting and M1
1080p/60 fps performance remain pending.
