# PES-style gameplay improvement plan

Current direction confirmed by the owner in both grill-me rounds, 2026-10-18.
This governs the next improvements to the existing 11v11 prototype. The original
[`11v11_implementation.md`](11v11_implementation.md) remains the integration record;
the 25 primary IDs in [`backlog.md`](backlog.md) remain stable.

## Target and constraints

- Reference: unmodded PES 2021 at default game speed, using observable behavior
  and original implementations. Gameplay feel precedes extra visual detail.
- Preserve the Sunday-league setting, supplied roster/kit/environment references,
  keyboard-first controls, short 11v11 fixture and exactly one keeper per side.
- Strictly free assets and existing/free tools. Author/refine original Blender
  motion when suitable free clips are unavailable. Archive source/license evidence.
- Weighted acceleration, braking and turns with promptly registered commands;
  buffered intent, bounded pass assistance and believable contact timing.
- Retain the shared 65-bone deform rig, independent physical ball and one
  authoritative fixed-60-Hz movement/physics owner. No blanket rig/rest-pose rewrite.
- Target: M1 Pro/16 GB, 1080p, stable 60 fps. Native timing and appearance remain
  unverified; cloud/Web checks cover only their stated scope.

The source recommendation audit and corrections are in
[`research/pes2021_gemini_review.md`](research/pes2021_gemini_review.md). Accepted
ideas below are work to perform, not implemented features or parity claims.

## Execution order and acceptance

### 1. Core locomotion and action presentation — BR-021 (21/25), BR-003 (3/25)

**In progress.** The first runtime coordination pass and direct Blender source
audit are recorded in [the movement/control evidence](art_briefs/pes_motion_control_pass.md).
Turn/stop recovery is interruptible by football actions. The
[chance/gait follow-up](art_briefs/pes_chance_gait_followup.md) corrects the
speed-to-gait mapping: jog at normal running speed, sprint at sprint speed and
idle while stationary regardless of the sprint key. Source stride/plant
work now also includes the [shared moving-turn pass](art_briefs/shared_turn_polish.md):
running direction changes keep their gait, and planted pivot arms are relaxed
offline without changing foot/root/contact curves. General stride/plant
polish and final-mesh moving playback remain the next animation gate. The initial
coordination pass changed no Blender curves; the later source edit is limited to
the pivot arms. Use the existing shared character in a small
Blender mannequin scene, then the final mesh in the match. Inspect deform weights,
rest axes, foot paths and exported timing before changing curves. Fix shared
mesh/garment defects where they obstruct motion review; defer decorative detail.

Incorporate the report's directional movement and layering recommendations:
- Cover idle, acceleration, jog/sprint, deceleration, stops, pivots and turns;
  use facing-relative lateral/backward motion where defending requires it.
- Keep speed/gait and direction consistent. Introduce BlendSpace2D only when
  compatible clips exist, with matched stride phase and clean transitions.
- Use properly authored additive gestures or filtered replacement layers as
  appropriate; preserve pelvis/plant-foot involvement during football actions.
- Preserve code-driven collision movement. Match animation stride to actual
  movement rather than adding an independent root trajectory.

**Acceptance:** fixed front/profile/action views and actual broadcast playback
show stable stance contacts, credible weight transfer and no clear T-pose blend,
foot slide, limb snap or transition pop. Input still registers during movement;
necessary commitments are explicit, and harmless recovery does not lock controls.
Passing structural tests alone does not accept final-mesh motion.

### 2. First touch, dribbling and passing — BR-002 (2/25), BR-007 (7/25)

**In progress.** The initial sharp-turn heading, competing dribble assistance,
airborne foot-reach and post-kick release fixes pass focused checks. The initial
zero-shot full match led to corrections for trailing-pressure shot rejection
and loose-ball recovery. Moving carry-to-shot execution and authored contact
pass. Contested attacking flow still needs broader assessment before accepting
the combined gameplay pass; see the follow-up evidence above.
The [attacking-flow continuation](art_briefs/attacking_flow_followup.md) now
covers full-lane targeting, current-carrier priority and receipt-to-carry/
turnover cleanup. Both kickoff variants pass the physical-shot regression;
balanced chance creation and final-mesh animation acceptance remain open.

Incorporate independent-ball touch control, prompt human intent and bounded
assistance without replacing the existing ball/contact architecture:
- Retain the sharp-turn regression: grounded touch direction must not jump
  across the body before facing catches up. Coordinate intent, facing and touch.
- Use clear possession/touch arbitration so nearby actors do not apply competing
  assistance. Preserve sprint knock-ons and the ability to lose the ball.
- Improve reception and first-time pass/shot transitions, contact-marker timing,
  pass targeting and receiver adjustment; retain plausible reach limits.
- Tune assistance against direction, balance, pressure and available lanes.
  Human responsiveness does not mean an instantaneous remote kick.

**Acceptance:** in the existing match, receive in midfield, turn away, dribble,
pass, make a supporting run, play a through ball and shoot. No ball teleport,
unreasonable kick reach, duplicate kick impulse or unnecessary trap animation.
Opposition can intercept and a reachable keeper can respond. Check both human-vs-AI
and AI-vs-AI, including changes of direction and interrupted/buffered actions.

### 3. Team roles, contests and keepers — BR-008/009/011/012 (8/9/11/12 of 25)

Adopt the report's behavioral ideas as readable original rules:
- Preserve the new goalward-shot corridor and loose-ball retrieval checks;
  distinguish a last-touch marker from an opponent actually in control range.
- Add a small set of tunable behaviors: holding cover, offering an angle,
  running beyond, and arriving late. Preserve team shape and avoid crowding.
- Separate tactical deliberation from time-critical contact/action execution;
  use explicit priorities, cooldowns and buffered intent, not copied tier tables.
- Improve shielding/shoulder contests using position, relative movement,
  balance/strength and ball proximity, with readable outcomes and recoveries.
- Refine goal-angle keeper positioning, reachable interception, catching/parry
  choice and safe rebound direction. Match 1v1 coverage to visible body poses.

**Acceptance:** repeatable scenarios demonstrate supporting runs, retained cover,
plausible interception/duel outcomes and reachable saves. Parrying is not always
perfect. Then run sustained 11v11 play for stalls, possession progression, chances,
restart continuity and goalkeeper failures. Keep 4v4 regression coverage.

### 4. Airborne ball and advanced contacts — BR-019 (19/25), BR-002 (2/25)

After ground behavior is trustworthy, introduce calibrated analytic drag and
Magnus spin for lofted passes, crosses and curved shots. Use consistent units,
flight/ground separation and bounded tuning; reconcile existing damping and
rolling resistance. Preserve the supplied worn-ball visual and sphere collision.
No fluid solver or compulsory 32-panel remodelling is needed.

**Acceptance:** inspect spin sign, flight range/apex, bounce and post/keeper/net
contacts in controlled scenarios. Existing ground passes, dribble feel and goals
retain their acceptance behavior. Add aerial contacts only with matching clips.

### 5. Reference-led visual improvements — BR-022/023 (22/23 of 25)

Incorporate anatomy, cloth construction, PBR and hair-card guidance through
`create-player` and the relevant Blender skills:
- Correct common head/body/garment deformation and reference proportions before
  distributing individual likeness work. Retain modular/shared assets and prints.
- Use reference-appropriate hair cards/alpha tests, fabric normal/roughness maps
  and grounded skin response. Avoid a compulsory muscular template or 4K maps.
- Audit sampled grass/asphalt/kit imports currently lacking mipmaps and VRAM
  compression. Select texture-level settings, filtering and platform formats;
  check thin logos, skin and normals after reimport. This small audit can precede
  the larger art pass where it improves gameplay review.
- Keep Kilmore Drive's daytime lighting and reference surroundings. Treat subtle
  localized moisture as optional later polish, with proper masks and restrained
  roughness; do not map the short fixture blindly to 90 minutes of sweat.

**Acceptance:** source-matched front/profile/kit comparisons plus moving-mesh and
broadcast review; reduced distant shimmer without unacceptable logo/normal loss.
Shared updates propagate; individual head variants remain intact. Native Mac and
Web visuals are assessed separately.

### Continuous performance gate — BR-013/025 (13/25 and 25/25)

Measure physics, AI, animation, draw calls, skinning, shadows, texture memory and
frame-time spikes as systems change. Use shared resources, visibility/LOD and
staggered noncritical decisions before adding runtime complexity. Prototype expensive
ideas offline and prefer baked motion to extra per-frame IK/cloth/hair solvers.

The native 1080p 60-fps target gives approximately 16.67 ms per frame; CPU and GPU
work both need measurement on target hardware, including sustained load. Keep the
23 animated match actors (22 players plus referee) and scenery in the measured scene.
Compare Mobile/Forward+ or lower render scale only for a demonstrated bottleneck.
Godot 4.6 uses FSR2.2 in Forward+; that setup does not transfer to Mobile or Web.

**Acceptance:** recorded target-Mac timings, memory and visible quality, with the
same gameplay scenarios. Web startup/input/capture and package checks remain useful
regressions, not native performance evidence. Hardware-only acceptance stays open
when the Mac is unavailable; independent development/testing can continue.

## Explicit exclusions from this report

No required commercial authoring tools, literal FOX address/bitmask/table port,
forced A-pose or wholesale re-rig, automatic thermal renderer fallback, blanket
4K/triangle mandates, or career/transfer mode expansion. None is necessary to
perform the accepted gameplay-focused work above.

### Original camera and pre-match presentation slice (18 October 2026)

BR-014/021/024: [production/research brief](art_briefs/broadcast_presentation_plan.md),
[archived PES camera/walk-on/crowd/formation references](../references/research/pes2021_presentation/README.md).
Nine camera families and a skippable Sunday-league broadcast intro are implemented.
Team spawning now uses a clean scene instead of duplicating a configured rig.
One-rig/startup-pose, camera-relative input/preferences, original walk/jog and
Play/Watch intro restoration checks pass. Final-mesh gait, cloth deformation,
likeness, venue fidelity and native M1 profiling remain open.
