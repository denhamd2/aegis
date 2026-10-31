# Beechlawn Rovers development backlog

This backlog turns the supplied gameplay specification into a dependency-aware
build order. It prioritizes a small, genuinely playable match before scaling
to 22 players or expanding the move list. The status reflects the current
prototype; an item is complete only after its acceptance checks pass.

For art-, animation-, environment-, camera-, or lighting-related backlog
items, use the archived references and skill workflow in
[`art_reference_implementation_plan.md`](art_reference_implementation_plan.md)
and [`../references/README.md`](../references/README.md) before implementation.

## Dense face form and connected smile study — 30 October 2026

BR-022 (22/27, in progress): a six-identity dense landmark sculpt preview did
not improve photographic likeness; the stronger version distorted neutral
faces. A connected, weighted lip-loop pilot on Robbie and David created a real
mouth opening but produced visible neutral seams and unnatural smiles. The
[source and comparison review](art_briefs/br022_dense_form_connected_mouth_2026_10_30/brief.md)
records the rejected previews. Shipping scores remain 4–7/20, and v0.5.10
remains the Mac release. Next: individual mouth, eye, cheek, skin and groom
sculpting against stronger multi-angle references, then front/turned native
likeness review. BR-025 (25/27, in progress) still owns target-Mac appearance
and sustained 1080p60 acceptance.

## Mouth topology and native integration study — 30 October 2026

BR-022 (22/27, in progress): the current neutral face has no mouth opening.
An isolated recess-and-dental candidate passed source geometry checks but
failed imported native smile appearance; a genuine 53-face opening and UV-fit
lip overlay also failed visual review. The
[source and native study](art_briefs/br022_oral_topology_2026_10_30/brief.md)
preserves the repeatable pilots, captures and precise topology fault. No
production character asset was changed. Next: author a clean individual lip
loop/cavity topology and neutral-to-smile sculpt, then individual eye/cheek
forms for all six before a new native likeness review.

Next acceptance: BR-022 (22/27, in progress) six-identity photo/native gate;
then BR-025 (25/27, in progress) packaged target-Mac appearance and 1080p60.

## Five further likeness studies — 30 October 2026

BR-022 (22/27, in progress): five additional bounded Blender previews tested
lower-face form, Smile deformation, registered photo skin detail, Robbie's
groom and neutral eyelids. None passed comparison with the supplied original
photos; the current strict likeness scores remain 4–7/20. The
[five-round review](art_briefs/br022_five_rounds_2026_10_30/brief.md) preserves
the previews, scripts and reasons for rejection. No new head source or GLB
entered the game, and no new Mac version was published. The next production
step is a mouth-capable head topology and individual eye/cheek sculpt, followed
by six native portrait reviews against the original photos.

Next acceptance: BR-022 (22/27, in progress) six-identity photo and native
likeness gate; then BR-025 (25/27, in progress) packaged target-Mac appearance
and sustained 1080p60.

## Original-photo landmark fit — 29 October 2026

BR-022 (22/27, in progress): the six saved hero heads now have a repeatable
original-photo landmark fit. It adjusts bounded face, jaw, nose and lower-face
forms while keeping the shared master, rig, UVs and neck join intact. Six
normal/near heads and grooms were rebuilt and audited. The
[fit review](art_briefs/br022_landmark_fit_2026_10_29/brief.md) records the
measurements, Blender comparisons and imported Forward+ portraits. Landmark
error fell, but the faces still fail the requested 20/20 likeness gate. The
failed open-mouth prototype did not enter the game. The next Mac build is
deferred until the owner reviews an actually convincing likeness pass.

Next acceptance: BR-022 six-identity mouth, skin and groom visual review,
then BR-025 (25/27, in progress) packaged target-Mac appearance and 1080p60.

## Six-player likeness refinement — 29 October 2026

BR-022 (22/27, in progress): the six saved head sculpts received another
reference-led form, eyelid, lower-face and groom pass. The neutral sources,
individual deltas, normal/near exports and skin maps were regenerated while
the shared body, 65-bone rig and player/referee identities stayed intact.
The [29 October review](art_briefs/br022_likeness_2026_10_29/brief.md) records
source audits, before/after native portraits, art scores and a rejected
tooth-showing smile trial. The native portraits still fail the requested
20/20 likeness target; expressive mouth anatomy, more individual facial
sculpting and groom/skin realism remain open under BR-022. This revision has
not been released on Mac because the visual gate remains open.

Next acceptance: BR-022 likeness review against the archived photos, then
BR-025 (25/27, in progress) target-Mac appearance and 1080p60 performance.

## Character realism review — 28 October 2026

BR-022 (22/27, in progress), v0.5.10 follow-up: the original Robbie Roden and
David Murray smiling photos are now archived and identified; their saved heads
have photo-guided cheek/jaw and hairline revisions, with short stubble for
Robbie. All six selected faces received a bounded eyelid/mouth/skin/groom
refresh, and the shared body corrective further tapers the belly, sleeves,
hands and boots. The [follow-up review](art_briefs/br022_realism_followup_2026_10_28/brief.md)
records source/export audits, native captures and candid scores. A tooth-showing
test was rejected because the inherited oral topology made it read as clenched
teeth. A new anatomical body/kit source, expressive mouth topology, denser
identity-specific facial sculpt and stronger groom remain necessary for a
20/20 finish. BR-022 stays in progress.

BR-022 (22/27, in progress): six key heads now have four authored form and
surface passes, with independent source and runtime assets for Robbie Roden
and David Murray. A single shared body corrective reduces the blocky torso,
thigh, arm, hand and boot proportions across the 22 players and referee while
retaining the existing rig, animation, UVs and individual Fullness. The
[BR-022 art review](art_briefs/br022_realism_2026_10_28/brief.md) records
before/after native Forward+ images, art-director scores and remaining gaps.
The bodies and faces are improved prototypes; exact reference likeness and
high-end hair/skin finish are still open.

Next acceptance: BR-025 (25/27, in progress), inspect these players and the
combined match on the packaged M1 Pro Mac and measure sustained 1080p60 there.
Linux software Forward+ captures cannot establish target-Mac performance.

## P1 match validation — 27 October 2026

BR-010 (10/27, complete): F3 now reveals live player/ball velocity,
projected collision capsules, AI intents and targets, pass reception targets,
and keeper shot prediction; the view stays off in ordinary play and works in
Play and Watch modes. BR-009 (9/27, in progress) now has a shared-rig keeper
distribution clip for both sides. A held ball follows the throwing glove and
releases once at its 0.5-second physics marker, then the keeper completes the
follow-through. BR-008 (8/27, in progress) retains its tested attacking and
defending decisions: the 4v4 sample made two passes and one shot without a
movement stall; a complete 11v11 match ended 1–1 with nine shots and three
saves. See [P1 evidence](art_briefs/p1_match_2026_10_27/brief.md).

Next acceptance: BR-008 (8/27, in progress), review human-vs-AI tactical
quality and input feel on the M1 Pro Mac, then BR-009 keeper distribution and
BR-025 sustained 1080p60 on the same hardware. Linux Forward+ captures prove
the current cloud visuals and logic, not Mac appearance or performance.

## Shooting and aerial actions — 27 October 2026

BR-019 (19/27, complete in v0.5.6): nearby defenders now prepare real
headers against descending crosses. Eligible forehead and legal goalkeeper
glove contacts share one physical winner, with stable rated ties; a missed
ball receives no forced impulse. A braced challenged-header clip and a
two-hand high-claim/recovery clip use the existing 65-bone rig. Power, finesse
and low shots have distinct left/right 60 Hz body clips, with live boot contact
and the original flight rules. Source export audits, both-direction contact
and keeper checks, native motion captures and complete-match gates are
recorded in [the BR-019 evidence](art_briefs/br019_finish_2026_10_27/brief.md).

Next acceptance: BR-025 (25/27, in progress), review the packaged v0.5.6
motion and input feel on the M1 Pro/16 GB Mac and measure sustained 1080p60.
BR-021 retains broader turning, starts and intro-motion polish. Linux
software Forward+ footage does not close the target-hardware gate.

## Stadium crowd allocation and motion — 27 October 2026

BR-023 (23/27, in progress): v0.5.5 fills all 49,554 modeled Rovers Arena
seats without changing the bowl, aisles or capacity. Separate `support_side`
metadata puts 3,118 Boardeaux supporters in lower NorthEast blocks and adjoining
North blocks 0–1; 46,436 support Beechlawn. Each side has the owner-approved
80/20 team-colour/casual-clothing split. The 12 existing avatars retain their
photographic skin, hair and fabric detail across three VAT detail levels and the
16/32 close-rig pool. Score-aware body reactions, replay restoration and 64
hand-following team-colour flags (36 South, 12 other home, 16 away) are checked.
Kilmore's eight casual spectators remain unchanged. See
[the crowd validation](art_briefs/stadium_crowd_2026_10_27/brief.md).

Next acceptance: BR-025 (25/27, in progress), inspect the v0.5.5 package's crowd
colours, flags, detail transitions and combined 1080p60 performance on the
M1 Pro/16 GB Mac. Linux software Forward+ captures do not close that gate.

## Mac playtest: mowing stripes and pitch glare — 26 October 2026

BR-023 (23/27, in progress): the owner reported weak cut lines and bright glare
in sunny Rovers Arena. Opposite-side view terms cancelled mowing contrast;
strip-sized normal waves further opposed the cuts, while a globally smooth
damp response added a broad pale reflection. The shared maintained-turf colour
now retains a readable mowing signal in all four camera directions. Arena
grass stays rough with restrained specular response; localized Kilmore water,
weather/ball drag, sun, shadows, geometry and texture budgets are preserved.
See [the material/capture review](art_briefs/turf_glare_2026_10_26/brief.md).
Next acceptance: BR-025 (25/27, in progress), recheck sunny Rovers Arena in the
packaged Mac build for pitch readability, glare and sustained 1080p60.

## Free-kick polish — 26 October 2026

BR-019 (19/27, in progress), with BR-015/016/021: free kicks now have a fixed-tick
approach, imported-pose stance alignment and a live boot-contact gate. Short
free-kick passes approach as well; misses reset preparation without a forced
impulse. Intended flight dots, terrain-relative goal aiming, distinct low/power/
curl trajectories, execution error and keeper/lane-aware AI replace serial-only
free-kick target choice. Existing penalty target variety remains separate.

Original shared-rig brace/jump poses support a legal facing wall, attacking
clearance and an open-side keeper position. The wall observes released flight
before reacting; high strikes produce a bounded physical hop and low strikes
do not trigger a blind jump. Head/body/kit/rest and existing motion assets are
preserved. Evidence: [free-kick pass](art_briefs/free_kick_polish_2026_10_26/brief.md).
The broader aerial/strike follow-up is completed in the v0.5.6 section above;
next acceptance is BR-025 (25/27, in progress), native M1 free-kick feel/graphics
and the combined-workload 1080p60 check.

## Recorded match audio — 26 October 2026

BR-024 (24/27, in progress): twenty edited recorded effects replace the synthetic
match bank. Separate park/stadium ambience, goal/save/post/missed-chance reactions,
intermittent stadium chants and recorded rain accompany spatial boot/head/glove,
grass, net/post and single/full-time whistle cues. Field voices stay bounded and
prioritized; whistles duck crowd layers, replays cannot retrigger incidents, and
leaving a match disconnects its event source. Cool Rock remains the menu/intro
track. Options has scrollable source/CC0/CC BY credits.

Automated source, two-venue event and native AudioServer mix checks cover this
slice; see [production evidence](art_briefs/recorded_match_audio_2026_10_26/brief.md).
BR-024 remains in progress: target-Mac listening approval, broader reaction
content and any future licensed commentary are still open. BR-025 (25/27,
in progress) retains the combined-workload M1 1080p60 hardware check.

## Bilateral strikes and attacking choices — 25 October 2026

BR-019 (19/27, in progress): four 60 Hz left-foot strike add-ons mirror actual
Godot-evaluated right-foot motion on the unchanged shared rest. Context chooses
and locks the boot; physical toe contact still gates the impulse. Ground strike
markers evaluate during physics rather than a delayed method callback. Both
feet pass moving/first-time checks, and volley/half-volley contacts cover both
attacking directions with the original bounce/miss guards.

BR-008 (8/27, in progress): attacking decisions compare goal opening with useful
crosses/cutbacks, use safe progressive lanes before frontal pressure arrives and
retain open central shots/free carrying space. Shot style also considers pressure
and a closing goalkeeper. Mirrored controlled decisions pass; full-match gates
and native review are recorded under `art_briefs/left_foot_ai_2026_10_25/`.
The aerial follow-up is completed above; tactical consistency and M1 feel
remain open under BR-008/025.

## Animated supporters, dockside and steady 60 target — 25 October 2026

BR-021 (21/27, in progress): preserve player bodies, likenesses, kits and existing
contact/gait work; reuse the wrestling Rocketbox import principles read-only for
football-owned crowd production. Twelve textured 80-bone adults have nine authored
clips, fitted seated/rise/sit footwork, three animated 3D body LODs and a bounded
16/32-rig near pool. Kilmore has eight animated standing casual spectators.

BR-023 (23/27, in progress): retain 49,554 aligned chairs. The original
44,685-supporter occupancy has been superseded by the full-seat allocation
documented above. Original dockside public realm includes quay walls,
water/channel/crossings, steps, railings, bollards, heritage tower/engine house,
retained rails, eastern plaza, Regent Road and simpler industrial context. The
stadium has a dedicated 7.32 × 2.44 m goal, square box net, separate rear poles and
tension wires; near rope/far grid share live and recorded impact deformation.
Kilmore retains its original weathered goal and environmental profile.

Venue resources own builders, camera landmarks, goals and optional tifo. Stadium
cold open covers exterior/wide/crowd/detail views before the existing walkout and
team/referee presentation. Owner's later tifo addition extends the stadium intro
from 79 to 93 seconds: painted silhouette portrait, white contrast outline,
transparent surround and exact quoted wording, with 7/3.5/3.5-second unfurl/close/
oblique coverage. It clears on skip/finish. Kilmore retains its 70.8-second intro.
No extra generic lower thirds. Exact architecture and owner visual acceptance
remain open; photographic dimensions are estimates.

BR-024 (24/27, in progress): typed match events drive crowd attention and scoring
reactions without changing rules or outcomes. The recorded audio slice above
supersedes the synthetic match bank; target-Mac listening/input approval remains.

BR-025 (25/27, in progress): Balanced 60 defaults to native Metal, MSAA 2×, a
physical-pixel 1080p 3D ceiling and 80–100% adaptive resolution, leaving the HUD
sharp. Custom retains full resolution/optional TAA and cinematic blur. Existing
physics interpolation and fixed 60 Hz authority remain. A native 15-minute
benchmark records CPU/GPU/frame timing and actual resident memory. Missing GPU
telemetry and Linux software rendering cannot pass hardware acceptance.

Production/source/probe evidence: [brief](art_briefs/stadium_supporters_2026_10_25/brief.md).
Next acceptance: BR-025 (25/27), measure the packaged combined workload on the
M1 Pro 16 GB at 1080p; retain 60 fps as a target until that run passes.

## Contextual first touch and receiving motion — 25 October 2026

BR-002 (2/27) and BR-021 (21/27), both in progress: reception is scheduled before generic dribble assistance, with a serial-bound selected-boot contact and carrier-relative cushioning. Move directs the outlet; Ctrl keeps it close and Shift pushes into space. Four original 60 Hz shared actions cover standing/moving left/right contacts. A selected animation layer preserves the support gait and avoids dormant 22-player branch overhead. First-time combinations, misses, ownership loss and reentrant whistle cleanup remain physical and bounded. Sources, native before/after motion and checks: [production evidence](art_briefs/contextual_control_2026_10_25/brief.md).

The previous contextual-receive slice shipped as universal Mac v0.4.2. BR-025 (25/27, in progress) retains native M1 appearance, input feel and 1080p60 acceptance. Further BR-019 (19/27) left-foot strikes/aerial contests and broader BR-021 turn/intro polish remain open.

## Default ball and saved selection — 25 October 2026

BR-023 (23/27, in progress): v0.4.1 adds the reference-led adidas UCL 2026/27 League size-5 ball as default at both venues. The original worn model remains selectable in Options beside Venue; selection persists through Play/Watch, intros, celebrations and recorded replays. Absent/invalid settings migrate to the new ball. The appearance catalogue leaves authoritative physics unchanged. Source references, Blender/PBR construction and native comparisons are in [the ball brief](art_briefs/ucl_ball_2026_10_25/brief.md).

BR-025 (25/27, in progress) is the next acceptance step: validate the v0.4.1 universal Mac package and review the ball, fuller stadium and combined gameplay at 1080p on the M1 Pro. Target hardware frame timing and owner likeness approval remain open.

## Stadium remodel and pitch realism — 25 October 2026

BR-023 (23/27, in progress) now has a complete Hill Dickinson reference-led Rovers building, curved/tapered corner seating, a continuous home end, barrel roof/trusses, glazed/brick/metal exterior and improved turf in both venues. All 25 final native views and actual seating/tread support checks pass. See [the production evidence](art_briefs/hill_dickinson_remodel_2026_10_25/brief.md).

BR-025 (25/27, in progress) is next: verify the v0.4.0 universal Mac package, then profile and visually review the fuller stadium on the M1 Pro at 1080p. Building geometry/shadow work increased; native Mac 60 fps and exact reference likeness remain open acceptance checks.

## Match HUD, assisted control and second venue — 24 October 2026

BR-006 (6/27): the missing automatic-selection acceptance was reopened and
implemented. Real pass markers hand over to ground/through/loft/cross receivers;
defensive interception scoring has hysteresis and a manual override. Goalkeepers,
including home goal kicks, remain automatic. Receiving-run assistance is scoped
to cursor handovers and yields to fresh input, preserving first-time shots.

BR-014 (14/27, in progress): compact black/white scorebug, timer below, two real
identity/stamina strips, distinct shot power and central radar follow archived
`70060.jpg`. F1 opens controls; the original blue intro graphics are independent.

BR-023 (23/27, in progress): Options selects Kilmore Drive or Rovers Arena.
The reference-led Blender arena has 49,554 seat positions, section LOD and instanced
crowd, a maintained striped field, functional shared goals/net impacts and four
corner flags. Venue-owned surface profiles keep park relief/puddles exclusive
to Kilmore. The free BlendSwap model was account-gated; the approved original
modular fallback was used. Native evidence and validation logs are in
[the production brief](art_briefs/match_presentation_2026_10_24/brief.md).

BR-025 (25/27, in progress) is the delivery/acceptance stage: build and verify a
fresh universal Mac package with this work plus the pending heads, skills,
foot plants and keeper saves. Native Mac input/appearance and sustained 1080p60
remain hardware gates. No Web game is built or restored.

## Latest completed gameplay scope — 24 October 2026

BR-021 (21/27, in progress) now has five original shared gameplay gaits with
calibrated foot plants, contralateral arm motion and stepping through fast
braking. Seven steady paces measure 0.023–0.104 m/s low/flat-foot slip. Moving
kick preparation follows carrier velocity while retaining physical contact
guards. Fourteen relevant smoke checks and native 30 fps moving review pass;
see [stride evidence](art_briefs/br021_stride_2026_10_24/brief.md). The latest
six-match chance gate passes at 26/42 shots, both teams qualifying in 6/6.

BR-020 (20/27) retains its completed shielding/skills scope. BR-009 (9/27)
retains the tested high saves and full-stretch dives, with distribution motion
and native Mac acceptance still open. Broader turn/start/intro footwork under
BR-021, match consistency under BR-008 (8/27), and individual likeness under
BR-022 (22/27) remain open.

Next: BR-025 (25/27, in progress), validate the combined movement, contacts,
keeper saves, assisted controls and both venues in the v0.4.0 universal Mac
package. Package metadata identifies its exact source/update time. Native M1
appearance, input feel and 1080p60 still require hardware acceptance.

## Approved Mac playtest improvement pass — 23 October 2026

27 primary items retain their original IDs. The five delivery bundles, evidence
requirements and remaining hardware gates are tracked in
[mac_playtest_improvements.md](mac_playtest_improvements.md). Existing mechanical
smoke passes do not close the owner's visible match-quality findings.

## Approved turf and broadcast follow-up — 23 October 2026

BR-023 (23/27): remove the old sparse weed-like geometry; deliver dense short
near-camera turf with a matching PBR surface, bounded instancing and puddle/mud
exclusion. BR-026/027 (26/27 and 27/27): directed celebration/full-time camera
cuts and alternate slow replay angles; all caption plates share a wider,
centered blue layout. BR-022 (22/27) follows with individual form, groom,
roughness and expression work for Shane, John and both Des identities.
See [the current implementation evidence](art_briefs/broadcast_turf_refresh_2026_10_23/brief.md).
Character likeness and M1 appearance/performance remain separate acceptance gates.

## Current state

Delivery is **Mac-only** as of 2026-10-22. The owner retired the football Web
version, its export preset, release downloads and Pages deployment. Native
Forward+ captures and headless checks replace ongoing browser validation.
Historical Web evidence below is retained as a record, not an active backlog
requirement. The separate wrestling Web game is unaffected.

The standalone Godot 4.6.3 project opens on the Beechlawn Rovers 27 title
screen, offering Play (keyboard vs AI) or Watch (AI vs AI), then launches a
three-minute 11v11 match: ten outfield players and one keeper per side, plus a separate
referee. Shared human body, rig, animation and team/role materials replace the
proxy in this scene. Shane, John and both Des identities have independent editable heads; other
Beechlawn identities retain the common starting head. Final likeness remains open.
The original 4v4 scene remains the regression fixture.

Role-aware 4-4-2 targets, shared-snapshot tactical decisions, player switching including
keepers, contact-timed passing/shooting, kickoff/goal/full-time behavior and
basic boundary restarts are implemented. Full 180-second AI-vs-AI replays
record physical shots, contested attempts, saves, goals and ball stalls;
the [23 October advanced-action follow-up](art_briefs/advanced_shots_2026_10_23/brief.md)
passes the six-match chance gate locally (34/27 shots) and in CI (27/20).
Local qualifiers are 6/6 each; CI qualifiers are 5/6 and 6/6. Counts vary across
machines, so chance consistency and cross-machine replay determinism remain open.
Human play-quality and native Mac acceptance remain open.
The [22 October match repair pass](match_repairs_2026-10-22.md) replaces touchline
ground passes with overhead throw-ins and adds aim/power restarts, basic
contact-evaluated fouls, penalties, cards and reduced teams. Full laws,
advantage/offside, substitutions and additional formations remain open.

The close broadcast camera, scoreboard and radar accompany shallow terrain,
rough chalk, weathered goals/nets, house/tree/car modules and eight spectators.
These are reference-led drafts, not exact likeness or venue acceptance. See
[`11v11_implementation.md`](11v11_implementation.md) and the release evidence.
Native Mac appearance and M1 Pro/16 GB 1080p/60 fps are not yet measured.

The earlier [contact/chance/keeper pass](art_briefs/gameplay_feel_pass/brief.md)
adds bounded moving kick setup, live boot-contact windows, buffered first-time
shots, interruptible follow-through, multiple AI shot lanes and grounded keeper
prediction/reaction. The brief retains all relevant match counts and limitations;
sustained attacking balance remains open.

The [keeper handling/recovery pass](art_briefs/keeper_handling_2026_10_22/brief.md)
fixes legal handling, supported catch selection, committed recovery and slow
own-rebound collection. BR-009 (9/25) stays in progress: original directional
low-save/dive/catch motion and measured hand contact are the next acceptance
check, followed by native Mac play-feel/performance validation.

The [22–23 October aerial-play pass](art_briefs/aerial_play_2026_10_22/brief.md)
brings forward BR-019 (19/25): keyboard R lofts, T crosses and contextual Space
headers, with bounded assistance, receiving runs, chest control and original
shared-rig aerial clips. Contacts validate actual head/chest proximity; the ball
remains independent. Advanced shot/cross variants and contextual volleys/real-bounce half-volleys
now have original shared-rig clips and passing contact/keyboard/native checks;
see the [advanced follow-up](art_briefs/advanced_shots_2026_10_23/brief.md).
Dedicated keeper cross-claim motion, richer aerial contests, left-foot/body
polish and native Mac acceptance remain open.

## Confirmed PES-style direction (2026-10-18)

The owner confirmed gameplay feel first, unmodded PES 2021 at default speed as
reference, strictly free assets, weighted responsive movement, bounded passing
assistance and original Blender animation where needed. The complete Gemini
report and its technical assessment are archived in
[`research/pes2021_gemini_review.md`](research/pes2021_gemini_review.md). Its paid-tool,
rig-replacement, literal engine-port and career-mode instructions are not adopted.
The active follow-on plan is
[`pes2021_gameplay_plan.md`](pes2021_gameplay_plan.md). It incorporates directional
locomotion/layers, first-touch and independent-ball control, role-based AI/duels,
keeper positioning/parries, calibrated airborne drag/spin, reference-led art,
texture import fixes and measured performance acceptance.
BR-021/BR-002 (items 21/2 of 25), both in progress, lead with coherent movement,
reception and contact in the existing full match. Native performance remains
unverified; the existing 25-item scope is retained. These are planned improvements,
not new completion claims.

First focused runtime pass is implemented; see
[`art_briefs/pes_motion_control_pass.md`](art_briefs/pes_motion_control_pass.md).
Sharp-turn touch alignment, single-controller dribble arbitration and pass
interruption of turn recovery have passing regressions. The
[chance/gait follow-up](art_briefs/pes_chance_gait_followup.md) corrects open-shot
rejection under trailing pressure, loose-ball recovery targets and speed-to-gait
mapping. The initial zero-shot run exposed these acceptance gaps; focused checks
now cover both attack directions and the reproduced loose-ball standoff. Source
stride/plant polish, balanced contested attacking flow and final-mesh motion
remain open; no complete gameplay or native performance acceptance is implied.
The 2026-10-18 full-formation buildup follow-up also removes safe-pass
starvation of through-ball decisions. Controlled tests now verify forward pass
progression. The subsequent [attacking-flow corrections](art_briefs/attacking_flow_followup.md)
fix complete-lane scoring, current-carrier selection and stale receiver targets.
Earlier local kickoff variants passed the physical-shot check, including a 1–1 result
from Boardeaux's kickoff. Chance frequency and team balance remain open under
BR-008; a single shot in the other fixture is a regression floor.

## Stack-specific practices to carry through the backlog

- Keep the 60 Hz physics loop authoritative and use the existing physics
  interpolation setting for presentation. On kickoff and goal-restart
  teleports, call `reset_physics_interpolation()` for the moved actors and
  ball so rendering does not blend across the entire field. Godot documents
  this reset requirement for objects repositioned after they enter the tree
  ([physics interpolation guide](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html)).
- Keep tactical target selection separate from movement execution, which the
  current `TeamTacticsController` and `FootballPlayer` already do. For the
  flat pitch, prefer formation targets plus cheap local separation over a
  navigation mesh and 22 continuously avoiding agents; Godot recommends
  staggering navigation queries when agents are needed
  ([navigation performance](https://docs.godotengine.org/en/4.4/tutorials/navigation/navigation_optimizing_performance.html)).
- Preserve shared rigs/material resources and measure before adding per-player
  detail. Profile skinning and animation cost at 4v4 first; if 11v11 profiling
  shows animation overhead, reduce update rates for distant or off-screen
  players before lowering the close players' animation quality
  ([3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)).
- Treat Web Compatibility screenshots as functional/layout checks, not visual
  parity or performance evidence for the Mac Forward+/Metal build. Use fixed,
  repeatable gameplay scenarios and event/range assertions in automated tests;
  Godot physics is not guaranteed deterministic, so tests should not require
  identical rigid-body trajectories across renderers or devices
  ([physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)).
- Continue authoring football actions in Blender with explicit contact frames,
  shared rest pose/scale, and in-place movement where Godot owns locomotion.
  Validate toe/ball contact, player alignment, and clip interruptions in the
  match scene after proxy checks; a clean standalone animation preview is not
  sufficient acceptance for a two-player interaction.

## Recommended order

### P0 — Make the first prototype trustworthy

- [ ] **BR-001 — Mac playtest and controls pass**
  Run the project on the M1 Pro at 1080p. Verify keyboard movement,
  sprint exhaustion, close control, pass/through-pass, shot charging, ball
  bounce, goal-frame collisions and HUD readability. Fix issues found before
  adding more systems. Record average and worst-frame time over a repeatable
  60-second run.
  - Cloud Web smoke pass: added a dedicated Web preset and verified the
    release export starts in Chromium with the Compatibility renderer. Pressing
    E starts kickoff, the match clock advances, F3 shows the 60 Hz/player/ball/
    stamina debug HUD, and holding W+Shift moves the controlled player (8.4 m/s
    in the captured check). A browser screenshot exposed the kickoff prompt's
    poor contrast over the scenery; a dark font outline now keeps it readable.
    The browser test used software WebGL and is
    functional coverage only; it does not establish M1 frame rate or visual
    parity. The local export is `build/web/index.html` (about 49 MiB total).
    Still required: full Mac playtest at 1080p and target-hardware timing.
  - Research decision: use the Web export only for functional smoke coverage;
    keep the M1 Pro run at 1080p as the performance and visual acceptance gate.
    Profile first, then test reduced 3D render scale or Godot 4.6's FSR 2.2 /
    macOS MetalFX options only if GPU timing shows a need. Do not assume the
    22-player target is already performance-bound while the playable is 4v4.
- [ ] **BR-002 — Ball action/contact pass**
  - 2026-10-25, v0.4.2: contextual selected-foot receptions precede dribble assistance; carrier-relative close/carry/sprint outlets, bounded physical reach and robust first-time/whistle cleanup. Dedicated live-ball tests and native comparisons are in `art_briefs/contextual_control_2026_10_25/`. Mac feel remains open.
  - 2026-10-22: Fixed reproduced rolling-ball capsule launches with collision-layer separation; see the [match repair evidence](match_repairs_2026-10-22.md).
  - 2026-10-21: standing/jog/sprint pass and shot contacts each execute once
    within 0.081–0.166 m in the moving regression. Setup touches and approach
    speed preserve boot reach; the marker opens a bounded 65 ms contact window
    with a 0.28 m live-toe limit. An off-axis remote kick is rejected. Incoming
    shots now buffer through arrival and can fire without a trap. See the
    [gameplay pass](art_briefs/gameplay_feel_pass/brief.md). Feel/stride/native
    acceptance remain open; this is progress on item 2/25.
  - 2026-10-18 focused follow-up: grounded touches follow eased facing;
    nearest-eligible-player arbitration prevents competing dribble forces;
    height and post-kick release gates preserve independent ball travel.
    Human/AI reversals, competing callers and authored contacts pass. Full-match
    chance creation still needs assessment; see the motion-control pass above.
  Tune touch distance, sprint touches, rolling resistance, pass/shot power and
  aiming. Buffer pass/shot inputs and prevent actions outside a plausible
  contact window. Synchronize the eventual ball impulse to Blender-authored
  kick contact markers rather than a free-running animation timer.
  - Cloud pass: pass and shot taps now buffer for 0.20 s; kick assistance is
    limited to 1.12 m; shot charging takes 1.0 s to reach full power; goal aim
    respects the player's attack direction. Smoke checks cover buffered
    pass/shot contact and reject a kick at 1.30 m. A 12 m/s ground pass moved
    about 17.8 m over two simulated seconds after reducing excessive rolling
    resistance; 6 and 18 m/s passes covered 8.3 m and 27.9 m. Close-control,
    normal, and sprint touch spacing is now distinct, with continuous capped
    possession assistance and touch events throttled by cooldown. Shot charge
    and directional aim are covered by the new `ball_fundamentals_smoke.gd`.
    The optional Y-Bot visual gates a pass impulse on a Godot method track
    inserted at the Blender-authored contact frame; an integration smoke check
    confirms no early impulse and one physical pass at 0.4 s. This is a
    first-pass event hookup, not final human-mesh contact validation, and the
    M1 check still needs the target Mac.
  - Tuning follow-up: measured close/normal/sprint dribble spacing is
    0.78/0.91/1.15 m; six/twelve/eighteen m/s ground passes travel
    8.30/17.76/27.89 m in two seconds; tap/full shot speed is 12.97/30.00 m/s.
    A first-time pass now starts its authored pass clip when its contact event
    can meet the predicted incoming-ball window, accelerating the clip up to
    5x for a fast arrival instead of waiting for the ball to drift past the
    player. A new live-rigid-body test launches an 8.5 m/s incoming pass and
    confirms one pass impulse at frame 12 (0.200 s) for an 8.5 m/s ball and
    frame 6 (0.100 s) for an 18 m/s ball; both contact clips speed up and emit
    once. Web/headless tests validate this timing path, but animation quality
    and touch feel still need a Mac playtest. The shot action has since gained
    its own Blender contact event; see the BR-003 shot pass below.
  - Research decision: keep the ball physically independent and retain the
    existing force-assisted dribble. Establish reliable pass/shot trajectories
    before considering drag or Magnus-force tuning; only add aerodynamic forces
    if measured ball flight shows a clear need, with coefficients calibrated
    against observed trajectories. Do not enable a custom rigid-body integrator
    for this without a specific requirement. If player movement stalls against
    the ball during contact checks, test collision layer/mask arrangements in a
    minimal scene before changing the match setup.
  - Additional cloud pass: the selected ground/through-pass receiver now gets a
    timed target. When trajectory prediction places the ball at the authored
    right-toe contact window, an attached `FootballerVisual` starts the receive
    clip with a small timing correction from its Blender event metadata. At the
    contact marker, a short mass-scaled impulse cushions the live ball while
    preserving some player movement intent; it does not reposition or attach
    the ball. A buffered pass can interrupt the receive settle. The focused
    receive smoke test verifies intended-receiver triggering, toe/ball gap,
    contact timing, one physical cushion, locomotion restoration and pass
    interruption. Passing, ball-fundamentals, AI-carrier and animation-tree
    smoke checks pass; the Web release export also starts with no page errors.
    The receive event now runs on the actual 4v4 rigged actors. The M1 playtest
    remains outstanding.
- [ ] **BR-003 — Reusable footballer rig and first animation set**
  Use Mixamo Y-Bot as the replaceable rig/import baseline, then verify one
  shared skeleton can represent the Beechlawn outfielders and goalkeeper.
  Establish the Godot skeleton/import convention and a lightweight
  AnimationTree. Add idle, jog, sprint, stop/turn, close control, receive, pass,
  shot, hit/tackle response and get-up clips. Keep gameplay movement
  authoritative in Godot; use in-place locomotion and event markers for ball
  contact. **Cloud pass:** the owner-supplied Y-Bot FBX is preserved and a clean
  GLB exports/imports successfully; Blender and Godot checks confirm its 65
  bones, two skinned surfaces and approximately 1.805 m Y-up height. A reusable
  `scenes/footballer_visual.tscn` blends idle/jog/sprint proxy clips and includes
  pass and first-touch receive actions in an AnimationTree-compatible library.
  Headless checks cover skeleton, clip playback, and contact events. The receive
  clip is 42 frames at 60 fps, contacts at 0.333 s, and its toe tip comes within
  12.3 cm from the incoming ball center (about 1.3 cm beyond its 0.11 m
  radius) in the match-scene harness. A Blender pose sheet
  records ready, contact, and recovery. The proxy render also exposed the
  Y-Bot front axis facing opposite the game attack direction; its reusable
  visual now carries a 180-degree local rig correction, with pass and receive
  arcs measured against that orientation. Remaining: polish gait and foot
  contacts against football reference, replace the robot shell with the human
  visual, author the remaining hit/tackle responses, and validate the existing
  proxy actions on final player meshes.
  The verified Y-Bot scene is now the visual rig for all eight 4v4 actors, with
  team/keeper palette colors and idle/jog/sprint AnimationTrees active in the
  match. Event-gated pass and receive tests now use the scene's real Visual
  nodes: the pass toe is 0.057 m from the ball at 0.4 s and receive cushioning
  triggers once at 0.333 s. A Web play capture shows the rig running in-match;
  it is a Compatibility/SwiftShader view at broadcast distance, not a final
  likeness or Mac-renderer quality check. The import/check stage is complete;
  BR-003 stays open for animation polish and the human visual.
  **Additional cloud gait pass:** the Blender side-view proxy render showed a
  short, low-knee jog/sprint silhouette. I increased the existing in-place
  stride and knee drive modestly, added a small torso counterbalance, and kept
  the existing 2–3 cm pelvis bob. Evaluated foot-bone forward travel increased
  from 0.359 m to 0.438 m for jog and 0.534 m to 0.629 m for sprint; the Godot
  animation-tree smoke test still passes with the imported actions. This proxy
  improvement is now integrated into the 4v4 match. Foot planting at match
  speed and transitions during turns still need a closer visual pass; the Web
  capture is too distant for judging fine gait quality.
  **Braking/idle pass:** Blender pose-sheet review exposed that the imported
  Y-Bot idle left both arms extended in a T-pose. The idle action now bakes a
  relaxed arm position with slight breathing variation, and a new
  `AN_Beechlawn_StopFromRun` clip lowers the centre of mass, plants the support
  foot, catches with the other foot, and settles into the same idle pose. The
  stop is 36 frames at 60 fps with its brake plant at 0.233 s; Blender IK is
  baked to bone curves and creates no runtime IK. Godot starts it when movement
  intent is released above 0.8 m/s, cancels it if movement resumes above
  1.2 m/s, and otherwise restores the locomotion blend at clip completion.
  The animation-tree and live-match smoke tests verify the idle arm pose, stop
  playback, movement interruption, and return to locomotion; pass and receive
  contact integration tests still pass. A Web capture has no browser errors, but its
  distant Compatibility view cannot establish fine motion quality. The stop
  is a first blocking pass; human-mesh proportions, turn transitions, close
  foot-plant review, and M1 visual/performance validation remain open.
  **Directional-turn pass:** authored mirrored `AN_Beechlawn_Turn90Left` and
  `AN_Beechlawn_Turn90Right` actions at 60 fps (36 intervals / 0.6 s). Each
  starts with a short load, catches on a support foot, counterbalances through
  hips/torso/arms, and settles through a small recovery step. Temporary Blender
  IK for the planted foot and ready-arm hand positions is baked to bone curves;
  the exported clips contain no runtime IK or root motion. In Godot, a turn
  action starts after a >~69° change in movement direction while horizontal
  speed exceeds 2.2 m/s; player steering and the root remain physics-owned.
  Blender proxy renders caught and corrected the initial T-pose arms before
  export. Animation-tree and live actor smoke tests verify mirrored playback,
  return to locomotion, and triggering on an in-motion direction change.
  Human-mesh foot sliding and contact, blend feel under a real controller, and
  Mac 60 fps validation remain open.
  **Shot/contact pass:** added `AN_Beechlawn_ShotRight`, a 54-frame in-place
  instep shot at 60 fps with anticipation, support-foot plant, strike, forward
  hinge, follow-through, and recovery. Blender validates the support plant and
  strike-foot target, then bakes temporary foot/hand IK before export. Its
  contact event is at 0.300 s; `FootballPlayer` now queues direction, charge-
  derived speed, and lift, then applies exactly one rigid-body kick only when
  the animation reaches that marker and the ball remains in reach. The new
  integration check measures a 6 mm toe-to-ball-center gap at contact and
  confirms there is no early impulse. Milestone 1, pass/receive contacts, shot
  event, and animation playback checks pass. The proxy action still needs
  review on the final human mesh and Mac; no player-specific left-foot or
  finesse/power-shot variants are authored yet.
  **Close-control pass:** authored a 60-frame (0.983 s) in-place loop with a
  lowered ready stance, alternating small foot touches, and restrained upper-
  body counter-motion. Temporary Blender IK for foot/hand placement is baked
  into the action; the start/end pose seam is checked before export, with no
  runtime IK or root motion. The clip is a separate AnimationTree layer that
  blends in only while close control is held and the player is moving, so
  regular slow locomotion cannot accidentally trigger it. The layer eases in
  and out at 12/s; the underlying idle/jog/sprint speed blend remains intact.
  The animation-tree smoke test, milestone-one, braking/turn, pass, receive,
  and shot contact tests pass. The loop was reviewed on the lightweight Y-Bot
  proxy only; foot contact and close-control feel on the final player meshes,
  ball-touch synchronization in a live match, and Mac 60 fps validation remain
  open.
  **Prone-recovery pass:** Blender authors `AN_Beechlawn_GetUpFromProne`, a
  55-frame (0.9 s) in-place transition from a low, hand-supported prone pose
  through a tucked-knee/half-kneel to an athletic ready stance. Temporary hand
  and foot IK is baked to ordinary bone curves; keyed Hips motion lowers the
  body while the armature root remains fixed. Blender proxy renders are saved
  in `docs/images/y_bot_getup_pose_sheet.png`. Godot exposes this as
  `FootballerVisual.play_get_up()` and the animation-tree smoke test verifies
  playback and return to locomotion. Blender now also authors
  `AN_Beechlawn_GroundedSlideTackle`, a 38-frame (0.617 s) in-place action
  with a compressed approach, grounded side slide, and prone settle, sharing
  its end pose with the get-up start. `FootballPlayer` keeps the 0.62 s
  commitment and 0.18 s ball-contact window authoritative; animation is visual
  only. The visual driver chains the slide into the 0.9 s get-up and holds
  locomotion/actions during recovery. The old `AN_Beechlawn_SlideTackle` clip
  remains in the shared source library but is no longer played for this action.
  Blender proxy renders are saved in
  `docs/images/y_bot_grounded_slide_pose_sheet.png`. Final-mesh ground contact,
  tackle contact alignment, and M1 frame-rate validation remain open.
  - Research decision: keep the current lightweight 1D idle/jog/sprint blend
    and the separately blended close-control loop while these clips
    are being polished and integrated. Keep the 90-degree
    turn as a one-shot action; add a directional BlendSpace2D only after
    backpedal and strafe locomotion clips exist. Add upper-body layering only
    with a tested additive clip and bone mask.
    Retargeting or bone renaming must be verified against the Y-Bot track names
    and rest pose before changing import conventions.
  - Free-motion-source check: CMU subject 10, take 03 (“soccer - kick ball”) is
    archived with its usage terms in `references/animation_sources/cmu/`.
    A Blender 4.3.2 60 Hz retarget trial showed unacceptable pose distortion
    from rest-pose/axis mismatch, so it was discarded before Godot integration.
    It was retained as timing/arc reference for an original right-foot pass
    blocking clip. `tools/blender/author_football_kick.py` uses temporary IK
    for a planted support foot and counterbalancing arms, then bakes and removes
    those constraints. The resulting `AN_Beechlawn_PassRight` clip is 54 frames
    at 60 fps (0.9 s), with contact at frame 24 (0.4 s); see
    `docs/images/y_bot_pass_contact_sheet.png`. The Blender script exports it
    alongside the existing clips in `y_bot_animation_library.glb`, preserving
    their durations when sampling the library at 60 fps. It also writes
    `y_bot_pass_contact.json` from the Blender contact frame. Godot inserts a
    method event at that authored time; the `FootballerVisual` instance on each
    match `FootballPlayer` now gates the physical pass impulse on that event.
    An integration smoke check verifies there is no
    early kick, exactly one ball impulse at 0.4 s, and locomotion resumes. A
    follow-up Godot skeleton measurement exposed that the authored right-foot
    arc moved backward at contact: the toe was 1.14 m from the center ball. I
    corrected the Blender-authored forward arc and regenerated the animation
    library. The integration test now measures the animated toe tip at the event
    and verifies it is within 0.14 m of the ball center; the corrected proxy
    measures 0.057 m horizontal / 0.001 m vertical (0.057 m total), with the physical
    impulse still fired once at 0.4 s. This validates blockout contact geometry,
    not final human-mesh appearance or match-camera readability. The 4v4 scene
    now uses the shared Y-Bot visual on all eight actors; the primitive shapes
    remain as gameplay collision bodies only. Final human-mesh contact, live
    camera review, and M1 performance validation remain outstanding.
    Keep BR-003 open for locomotion refinement, receive/shot/recovery clips,
    shared-rig validation, and in-match visual QA. Do not ship the raw BVH.
  Check Rokoko's free sports mocap set only as optional supplemental material.
- [ ] **BR-004 — Configurable controls and action buffering**
  Keep the first playable match keyboard-only. Put its keyboard mappings in a
  remappable settings resource or UI; defer gamepad mappings until a later
  milestone. Add input buffering/cancellation rules for receive, pass and
  shoot; keep committed actions such as a slide tackle non-cancellable once
  that move exists.

**P0 exit check:** the player can move, keep the ball under control, pass and
shoot with predictable response. Goal-line/frame checks work, and a match-scene
playtest has no stuck bodies or unreported frame-rate failure on the target Mac.

### P1 — Validate football in a small-sided match

- [x] **BR-005 — Player/team data and tuning resources**
  Define reusable player attributes, team colours, roles and formation-relative
  positions as editable Godot resources. Populate Beechlawn with Shane Denham
  (#8), Robbie Roden (#10), David Murray (#5) and John O’Rourke (#1, goalkeeper)
  from their supplied character sheets. Use Des Feeney (#9) as the visual base
  for Boardeaux’s three outfield slots and goalkeeper because only his sheet is
  available; distinguish slots by role/kit details where useful, but do not
  invent names, facial identities or player-specific ratings. Use balanced
  editable defaults until ratings are supplied.
  - Complete: editable player, attributes and team resources now define both
    four-slot rosters. Beechlawn uses the supplied names/numbers; Boardeaux's
    four slots reference Des Feeney as the visual base and leave unsupported
    identities/numbers blank. Attributes stay at neutral 50 placeholders.
    Starting positions are generic 4v4 slots, not claimed real-world player
    positions. Automated checks validate roster size, unique IDs/slots, visual
    bases, and defaults. The 4v4 scene now instantiates these profiles as
    blockout actors; the remaining BR-006 work is match gameplay and flow.
- [x] **BR-006 — Build a 4v4 vertical slice**
  - 2026-10-24: reopened and completed the missing auto-selection implementation
    for the 11v11 match: actual-release recipients, stable defensive interception
    choice, Tab override, keeper exclusion, dismissal repair and Play/Watch
    isolation. Assisted/Manual is persisted. Native Mac feel remains BR-025.
  Add two sides with three outfield players and a goalkeeper each. Use the
  supplied Beechlawn roster and the Des Feeney visual base for all four
  Boardeaux slots. Start the first playable as a short match, with the human in
  control of one Beechlawn outfielder.
  Implement manual/automatic player switching, a visible controlled-player
  marker, and possession changes.
  - Complete for the current 4v4 blockout: all eight actors assemble from the
    team resources; Tab switches among Beechlawn outfielders; close contact can
    change the ball's team touch; play starts from a center kickoff, goal pauses
    restart with the conceding team, and the three-minute open-play clock ends
    at full time. Tests cover kickoff spacing, frozen pre-play state, goal
    pause, and AI restart. Tackling, robust contests and a true opposing
    goalkeeper remain later gameplay systems, not prerequisites to this
    assembly milestone.
- [x] **BR-007 — Passing, receiving and first touch**
  Score teammate targets using stick direction, angle, range, lanes and player
  motion. Add lead passes into space, first-time pass buffering, receiver
  movement and opponent interceptions. Keep assistance bounded by the intended
  direction.
  - Cloud progress: short and through passes now select a teammate in the
    intended arrow-key lane, score range/alignment and nearby opponent lane
    risk, and lead through-balls using receiver velocity. AI receivers make a
    time-limited run toward the predicted target. A pass press buffers longer
    only when a friendly ground ball is approaching the kick window. The AI
    selects a reachable point on a moving ball's short path and only takes
    possession on close contact. `passing_smoke.gd` verifies target selection,
    lead, receiver movement, first-time buffer, interception positioning and
    close-contact possession change. In the 4v4 scene, an incoming pass starts
    the rigged receiver's authored receive clip and resolves a velocity-based
    cushion at its contact marker. Final human player visuals and richer
    interception decisions remain polish work. Keyboard controls remain WASD +
    arrows, E ground pass, Q
    through-ball.
- [ ] **BR-008 — Small-sided attacking/defending AI**
  - 2026-10-27 P1 verification: the 4v4 AI-vs-AI run covered 720 physics
    frames with six moving outfielders, two passes, one shot and no two-second
    stall. Mirrored attack choices, tactical parity, defending and transitions
    pass. A complete 11v11 match produced 2/7 shots, 2/1 saves, a 1–1 result
    and no stationary sample. The human 4v4 milestone smoke covers pass,
    control handover, shot, movement and goal; Mac human-vs-AI play quality
    remains the acceptance check. See the P1 evidence above.
  - 2026-10-26 (8/27, in progress), v0.5.1: mirrored decisions compare narrow
    shots with crosses/cutbacks and release safe progressive passes before
    frontal pressure. Shot styles consider pressure/keeper approach. Twelve
    full matches pass the unchanged chance gate: Kilmore 30/19 shots (both
    qualifying 6/6), arena 27/36 (5/6 and 6/6). Every fixture has contested
    attempts from each team; one arena match has a single home shot. Native
    production cross-to-volley and unskipped presentation pass. Broader tactical
    consistency and Mac feel remain open. See `art_briefs/left_foot_ai_2026_10_25/`.
  - 2026-10-24 stride/contact follow-up: the latest six full matches pass the
    existing chance gate at 26/42 shots, both teams qualifying in 6/6 with
    contested attempts in every fixture. Aggregate share is 38.2%/61.8%.
    Fixture variation remains visible (home-0 is 2/13 shots); retain human,
    cross-machine and tactical-variety acceptance rather than calling this
    universal balance. See `art_briefs/br021_stride_2026_10_24/ai_chances/summary.json`.
  - 2026-10-24 full-dive follow-up: the latest six complete matches qualify
    both teams in 6/6 fixtures, with 26/23 shots, contested attempts in every
    match and a 53.1%/46.9% shot share. Keep native/human acceptance open.
    See `art_briefs/br009_dives_2026_10_24/ai_chances/summary.json`.
  - 2026-10-24 BR-009 follow-up: all six full matches qualify both teams,
    with 34/24 physical shots and a 58.6%/41.4% shot share. Both teams create
    contested attempts in every fixture; the earlier away-2 zero-shot result
    does not recur. No AI quotas, rating changes or weakened keeper contact
    guards were introduced. This is one cloud run, leaving cross-machine
    repeatability and human match quality open. See
    `art_briefs/br009_high_shots_2026_10_24/ai_chances/summary.json`.
  - 2026-10-24 BR-020 follow-up: the final six-match chance gate passes at
    34/19 physical shots, qualifying 6/6 home and 5/6 away. The away-2
    fixture leaves Boardeaux without a shot; investigate its buildup/turnovers
    next while preserving honest contacts and the other five scenarios.
    See `art_briefs/br020_skills_2026_10_24/ai_chances_verified/summary.json`.
  - 2026-10-22: read-only tactical possession, committed AI pass recipients,
    role-based outlet/run/cover support, shared decision timing, neutral
    opposing dribble ties and carrying through trailing pressure now pass
    targeted regressions. Six fixed complete matches qualify both teams in
    6/6 scenarios, with 32/31 physical shots and contested shots for both
    sides in every match. No runtime quotas, attribute boosts or keeper nerfs.
    See [full diagnosis and evidence](art_briefs/ai_attacking_flow_2026_10_22/brief.md).
    Item 8/25 remains in progress for human play-quality/animation acceptance;
    next gameplay priority is BR-009 (9/25), save/parry/recovery refinement.
  - 2026-10-21: the carrier evaluates five goal endpoints so a central blocker
    does not veto a free corner. Immediate full-lane blocks still discourage a
    shot. Both mirrored controlled scenarios deliver physical contested shots;
    clear edge-of-area attempts use an editable range and unavailable actions
    preserve the cooldown. Balanced sustained chance creation remains open
    under item 8/25. See the gameplay pass above for full-match counts.
  - Release follow-up: a mirrored tactical regression exposed straight-ahead
    wide carriers running to the byline. Full 11v11 carriers now gradually
    turn goalward in the final third, retaining width during build-up. Both
    mirrored controlled-attack contact gates now complement full-match stability
    and reported chance metrics; sparse natural-match shooting remains open. See
    [`art_briefs/ai_wide_carry_release_fix.md`](art_briefs/ai_wide_carry_release_fix.md).
  - Attacking-flow continuation: full-path pass scoring preserves open diagonal
    runs; actual kicking reach takes priority over future interception when
    selecting a carrier; successful control and turnovers retire reception
    targets. Three mirrored regressions failed before their respective fixes
    and now pass. Earlier local 180-second kickoff variants passed a physical-shot check,
    while balanced chance creation remains open. See
    [`art_briefs/attacking_flow_followup.md`](art_briefs/attacking_flow_followup.md).
  - 2026-10-18 follow-up: an open goalward shooting corridor is no longer vetoed
    by a nearby defender behind the ball. Primary defenders chase loose balls
    into contact range instead of stopping at a possession-pressure offset;
    support/formation arrival zones are unchanged. Mirrored shot selection and
    a collision-standoff recovery regression pass. See
    [`art_briefs/pes_chance_gait_followup.md`](art_briefs/pes_chance_gait_followup.md)
    for full-match results and remaining tactical-balance limitations.
  Separate team shape, individual decisions and movement execution. Teammates
  offer support and forward runs without clustering; defenders cover lanes,
  mark threats and selectively press. A close-range standing tackle is now
  bound to F for the human player, with a facing/range check, directional ball
  redirection, cooldown and matching AI tackle attempt. `tackle_smoke.gd`
  verifies contact, range rejection and AI transfer. Wide teammates now hold
  separated support lanes and advance on possession; the nearest AI carrier
  moves forward with the ball; defenders not pressing the ball recover
  goal-side in a ball-shifted line. `team_shape_smoke.gd` checks lane spacing,
  carrier intent and goal-side recovery. The nearest outfielder presses the
  ball while the other two greedily take distinct off-ball marks using distance
  and lane alignment; mark targets shade runners from goal and remain goal-side
  of the ball. `defensive_ai_smoke.gd` checks pressure, distinct assignments,
  lane matching and mark positions. Late-game context now lets a trailing side
  add a second presser in the opponent half, while a leading side drops its
  defensive line and keeps a single presser. `tactical_context_smoke.gd` checks
  score, clock and field-zone triggers. Possession changes now start a brief
  transition window: the losing side can counterpress with one player held in
  cover only when a second presser is within 18 m; otherwise the team holds
  shape instead of chasing across the pitch. The winning side gets more direct
  support runs, and the short press expires without resetting on same-team
  touches. `transition_ai_smoke.gd` checks turnover detection, range gating,
  preserved cover, expiry, same-team touch handling and forward support.
  `TeamTacticsController` now computes role/shape targets and
  returns intent data separately; `training_ground.gd` applies those decisions
  as movement requests, while `FootballPlayer` owns movement execution.
  `team_tactics_controller_smoke.gd` checks this separation. Still needed:
  fuller transition choices and authored tackle/success/foul animations. A
  committed G-key slide now advances before contact; ball-first
  contact redirects the live ball, while opponent-first contact emits a foul
  event and HUD call without changing possession. AI uses the same slide option
  outside standing-tackle range only when the defender is closing with a useful
  approach angle on a nearby carrier. `tackle_smoke.gd` checks clean wins, foul
  event, unchanged possession after a foul, AI slide commitment and rejection
  of a stationary challenge. Free-kick handling
  is still BR-016. Running outfielders now apply a brief, strength/balance-scaled
  shoulder response when contesting an opponent-held ball side by side, with a
  pair cooldown and no direct ball-possession change. `shoulder_challenge_smoke.gd`
  checks contact eligibility, balance reaction, cooldown, speed gate and
  possession preservation. Final authored animation polish and match-tested
  tuning remain. The assembled 4v4 scene now has a repeatable AI-vs-AI smoke
  run: after kickoff and 720 fixed physics frames, six outfielders moved more
  than 1 m and both teams had tactical intents; the ball stayed finite and all
  actors remained inside the playable envelope. This verifies basic match
  activity, not match quality or Mac frame pacing. Blender-authored blocking
  clips for a slide tackle (1.00 s) and shoulder-impact sell (0.73 s) are
  exported in `assets/characters/mixamo/y_bot_animation_set.glb`, with their
  editable source at `tools/blender/beechlawn/y_bot_animation_set.blend` and
  repeatable authoring script at `tools/blender/beechlawn/author_defensive_clips.py`.
  They use the verified 65-bone proxy but are not yet wired to slide/tackle
  events. The 4v4 actors now use this rig for locomotion/pass/receive; contact
  and movement remain controlled by Godot. Human playtest, authored-clip polish
  on the final footballer mesh, and tuning under match conditions remain.
  - Additional cloud pass: an individual carrier decision layer now lets an AI
    take a close central shot, release a safe forward through-pass when tightly
    pressed, or keep carrying when neither option is justified. Decisions only
    execute for an AI outfielder with the ball inside the normal kick window;
    action cooldowns prevent repeated kicks, and human-controlled players are
    left alone. `ai_carrier_decision_smoke.gd` verifies the three choices and
    confirms the match layer executes shots/passes and assigns the receiving
    run. Team-shape, defensive-marking, transition, tackle and passing checks
    also pass. BR-008 remains open for broader tactical consistency and actual
    human-vs-AI / AI-vs-AI play-quality review.
  - AI-vs-AI acceptance samples two-second movement windows and reports action
    counts after kickoff. At 720 physics frames (~12 simulated seconds), runs
    consistently show all six outfielders moving and zero movement-stall
    windows, while pass counts vary (one pass in one run, none in another).
    The short-run pass count is diagnostic rather than a hard assertion; the
    carrier scenario test deterministically verifies that safe through-passes
    and close central shots are selected and executed. In a disposable,
    windowed Godot Agent run over 34 simulated seconds, the match produced 4
    passes, 10 tackles, 78 controlled dribble touches and zero movement stalls,
    but no shot. The sample is too short to tune match shot frequency; that
    remains a longer play-quality review. The render probe also now counts
    dribbles because `FootballBall.touched` emits for controlled touches.
  - The rendered probe exposed stale possession being treated as active carrier
    control: AI defenders could tackle a loose ball solely because the last
    touch belonged to the opposing team. AI standing tackles now require an
    opposing outfielder within 1.35 m of the ball; the existing slide rule
    retains a slightly wider 1.55 m carrier window. `tackle_smoke.gd` verifies
    that a close carrier can still be challenged, but stale team possession
    cannot trigger a tackle or consume the cooldown. The 12-second AI-vs-AI
    smoke test no longer treats an occasional absent pass as a failure; it
    checks movement, finite positions, tactical intents and stalls, while
    deterministic action choice/execution remains covered by
    `ai_carrier_decision_smoke.gd`.
- [ ] **BR-009 — First goalkeeper**
  - 2026-10-27 P1 distribution (9/27, in progress): the unchanged 65-bone rig
    gains an original in-place sidearm clip. Both keepers hold the physical
    ball through windup, follow the throwing glove, release once at the 0.5 s
    marker as a hand action, and finish before moving again. Both-direction
    marker, hand gap, interruption, recovery and live save regressions pass.
    Native Linux Forward+ motion shows both sides; target-Mac match feel and
    1080p60 acceptance remain open. See the P1 evidence above.
  - 2026-10-24 full-stretch dives (9/27, in progress): six original shared-rig
    clips add bilateral low/mid/high dives with 60–80-degree whole-body roll,
    physical sideways take-off and staged landing, brace, kneel and rise.
    Twelve reachable travelling shots and four late/unreachable controls pass
    across both keepers; recovery restores the standing collision shape.
    Near-body saves and central overhead tips remain; all seven selected
    regression checks pass. Native footage records six real glove contacts
    through complete dive/get-up sequences. The six-match chance gate passes
    at 26/23 physical shots, both teams qualifying in 6/6 fixtures. See
    [motion/contact evidence](art_briefs/br009_dives_2026_10_24/brief.md).
    Distribution motion and native Mac match acceptance keep this item open.
  - 2026-10-24 high-shot fix (9/27, in progress): the red fixture saved only
    2/8 reachable high shots. A cutoff-only probe did not fix insufficient
    overhead reach, central-only high selection or frozen lateral commitment.
    Three original shared-rig clips now pair with physical jump/lateral launch
    and arrival-synchronized preparation. Longer flights also have delayed
    take-off. The final mirrored cases pass 12 reachable saves and six genuine
    unreachable/late/over-bar misses, natural landing, collider restoration
    and tips physically clearing the bar. Low saves, high crosses, handling,
    skills and shot-contact regressions pass; four native real-ball saves
    show the new glove poses. Reach/reaction/ratings and shooting are unchanged.
    The six-match chance gate also passes with 34/24 shots, both teams
    qualifying in 6/6 fixtures.
    See [diagnosis and evidence](art_briefs/br009_high_shots_2026_10_24/brief.md).
    Distribution animation and native Mac match acceptance keep this item open.
  - 2026-10-22 handling/recovery pass: mirrored regressions reproduce and fix
    speed-only catches at full lateral stretch, handling outside the keeper's
    own area, instant second saves during recovery and failed own-rebound
    gathering. Catch width, standing/stretch recovery and slow-gather speed are
    editable for both teams. Recovery gates locomotion, foot assistance and
    actions; legal hand contacts run before dribbling. Existing reach/reaction
    and neutral ratings remain. See [evidence and open motion gates](art_briefs/keeper_handling_2026_10_22/brief.md).
    This is a mechanics pass using the existing standing-save clip. Directional
    low/dive/catch motion, measured hand contact, distribution animation and
    human/M1 acceptance keep BR-009 (9/25) **in progress**.
  - 2026-10-21: rolling-shot prediction stays above the turf, reaction delays
    gate real saves, and behind/away/unsupported-high contacts are rejected.
    Goal-angle positioning, ball-facing shuffles, advance standing-save pose
    timing and safer parry-side selection pass mirrored 11v11 checks. Existing
    catch/distribution coverage remains. Low/diving clips and broad match/native
    validation remain open under item 9/25; see the gameplay pass above.
  Position between ball and goal, predict shot crossing, react with a readable
  delay, move to reachable saves, and catch/parry/deflect without teleporting.
  Add simple distribution after possession.
  - Cloud progress: both keepers track a goal-centred position; a goal-bound
    shot is projected to the keeper line, filtered against the frame, and met
    after an attribute-scaled reaction delay. The keeper moves through the
    existing CharacterBody controller and saves only inside a short contact
    radius. Fast shots are parried; slower ones are physically held near the
    keeper briefly, then distributed toward a teammate selected for distance
    and passing-lane safety. `goalkeeper_smoke.gd` covers prediction, frame
    rejection, reach, parries, catch, hold and distribution. Authored save and
    throw clips now cover the cloud motion checks; Mac gameplay validation remains.
- [x] **BR-010 — 4v4 match loop and debug views**
  Add kickoff, goal, restart and short-match timer states. Add development
  overlays for player/ball velocity, AI targets, pass target, collision shapes
  and keeper prediction. Keep overlays disabled in ordinary play.
  - Complete: kickoff, goal pause, conceded-team restart and three-minute
    open-play timer are smoke-tested. F3 enables projected ball/player velocity,
    real collision shapes, AI targets/intents, pass targets and keeper
    prediction. It is disabled by default and survives player switches and
    Watch mode. `p1_debug_overlay_smoke.gd` and native Forward+ off/on and
    keeper-prediction captures verify the view.

**P1 exit check:** a short 4v4 game (three outfield players and a goalkeeper
per side) can start, produce purposeful support and
defending, change possession, create shots and saves, score, restart and finish
without AI stalls. Validate the same actions with human-vs-AI and AI-vs-AI.

### P2 — Scale the validated systems to 11v11

- [x] **BR-011 — Formation and role positioning**
  - 2026-10-28: match-local 4-4-2, 4-3-3, 4-2-3-1 and 4-5-1 layouts assign
    eleven team-relative positions without mutating the saved squads or 4v4
    fixture. Defensive and attacking midfielders now have distinct support
    and cover targets; lineup cards follow each formation. See
    [`art_briefs/p2_2026_10_28/brief.md`](art_briefs/p2_2026_10_28/brief.md).
  Add 4-4-2, 4-3-3, 4-2-3-1 and 4-5-1 using team-relative coordinates. Implement
  goalkeeper, centre-back, fullback, defensive/central/attacking midfielder,
  winger and striker responsibilities.
- [x] **BR-012 — Team tactics and transitions**
  - 2026-10-28: editable team width, depth, pressing, directness and tempo now
    drive formation spacing, second-press range, forward runs, pass decisions
    and AI action cadence. Midfield/forward second press keeps the back line
    and holding midfielder in cover. Existing ball-side shift, outlet/runner
    passing triangles and late lead protection remain active. Full default,
    4-3-3/4-2-3-1 and 4-5-1/4-4-2 AI matches reached full time without stalls.
  Add width, depth, pressing, directness and tempo settings. Shift defensive
  shape to the ball, preserve cover, create passing triangles, counterpress
  selectively and make late-game score-aware adjustments.
- [ ] **BR-013 — Efficient 22-player simulation**
  - 2026-10-18: 22 shared human actors plus separate referee validated; teams
    alternate 5 Hz tactical decisions, movement/ball remain fixed 60 Hz. Shared
    mesh/material propagation and independent playback are tested. Target-Mac
    physics/animation frame-time, draw-call and memory budgets remain unmeasured.
  - 2026-10-28: matched 640×360 Linux Forward+ kickoff capture measured 1,208
    draws and 1,157,084 primitives, unchanged from v0.5.7; peak process RSS
    was 4,311,156 KiB (v0.5.7: 4,289,380 KiB). This is software Vulkan and
    does not establish target-Mac sustained 1080p60, physics or animation timing.
  Expand from the validated 4v4 architecture, not a monolithic AI function. Stagger
  tactical decisions, use primitive collisions and shared resources, and
  measure physics, animation, draw calls and memory before adding detail.
- [ ] **BR-014 — Broadcast camera, HUD and radar**
  - 2026-10-28: all nine camera presets, camera direction and HUD/radar
    layout checks pass with the four-formation match. Native Forward+ 720p
    stadium and matched 360p captures retain the supplied 69022/70060
    composition goals; target-Mac camera/input QA remains open.
  - 2026-10-24: native vector black/white match HUD follows `70060.jpg`;
    real identities/stamina/charge, team crests, camera-oriented radar, responsive
    safe margins and F1 help. Existing blue intro graphics remain separate.
  - 2026-10-22: Added the eighteen-second asset/player montage before walkout and fixed the horizontal active-player torus. Native sequence review supplements the existing intro checks.
  - Walkout lineup graphics: home first, then Boardeaux, with eleven reference
    portraits in a 4-4-2, club crests and player-managers Robbie Roden/Des Feeney.
    The original GPT Images panel sits beside the live walk. Each card has
    eleven seconds; skip/natural completion restore kickoff normally. See
    [`art_briefs/lineup_graphics/brief.md`](art_briefs/lineup_graphics/brief.md).
  - 2026-10-21: added a 4.2-second referee reveal directly after the team
    cards, with a close-up of the in-game Des Feeney official and a matching
    GPT-generated blue lower third. It fades in/out and clears correctly on
    the next shot or intro skip; Web capture is saved at
    [`art_briefs/referee_intro/`](art_briefs/referee_intro/).
  - 2026-10-21 follow-up: the starting-lineup camera sweep now lasts 12 seconds
    instead of 4.2, retaining eased starts/stops. Team text is Boardeaux across
    title, scoreboard, restarts and roster shirts; canonical match ownership
    labels and fixtures use that spelling too. Asset filenames/IDs are stable.
  - 2026-10-21: moved all six sideline presets to the opposite touchline while
    retaining their height, distance and FOV. Existing camera-relative keyboard
    control follows the flipped view. Both goal-end/touchline extremes and
    preset switching are covered by the camera regression; see
    [`art_briefs/opposite_broadcast/brief.md`](art_briefs/opposite_broadcast/brief.md).
  Tune the elevated sideline camera to the supplied screenshot; predict long
  passes, keep relevant players visible and frame goalmouth action. Add score,
  clock, phase, controlled-player feedback and a team-coloured tactical radar.
  - 2026-10-18 camera/presentation slice: nine original camera presets, saved
    height/zoom/angle tuning and C cycling. Camera-relative input and invalid
    preference fallback are covered by `broadcast_camera_smoke.gd`. Close
    Broadcast remains the default; see
    [`art_briefs/broadcast_presentation_plan.md`](art_briefs/broadcast_presentation_plan.md).
  **Current camera pass:** 12 m high / 26 m offset, smooth predictive tracking
  and up to 35% widening for long passes. Added a continuously updated tactical
  radar and debug-only touchline, goal and corner capture cameras. Native M1
  camera/input QA remains open.

**P2 exit check:** cloud checks show both full teams preserving recognizable
shape, supporting attacks, recovering on loss, creating and defending chances,
and remaining readable from the camera. Target-Mac camera/input QA and sustained
1080p60 physics/animation/rendering acceptance remain open in BR-013/014/025.

### P3 — Complete match rules and team management

- [ ] **BR-015 — Match state machine and boundaries**
  - 2026-10-22: Added genuine throw-ins and shared aim/power restart preparation, release and recovery; manual and AI paths replace the former ground-pass placeholder.
  - 2026-10-18: whole-ball boundary ownership, goal kicks and corners have
    smoke coverage. A short ground-pass restart substitutes for throw-ins.
    Half-time and complete regulation restart presentation remain open.
  Implement pre-match, kickoff, open play, stoppages, half-time and full-time.
  Detect the whole ball over touchlines and goal lines; award throw-ins, corners
  and goal kicks to the correct side.
- [ ] **BR-016 — Fouls, offside and referee**
  - 2026-10-22: Added contact-based free kicks, penalties, yellows, second yellows and straight reds. Advanced advantage/offside remain open.
  - 2026-10-18: a separate black-kit referee follows play diagonally and stays
    outside player selection/possession/tackle groups. Adjudication is still open.
  Judge tackle timing/contact, advantage and cards. Evaluate offside at the
  teammate's ball-play moment and penalize only involvement. Add visible referee
  reactions and restart placement.
- [ ] **BR-017 — Substitutions and reduced teams**
  - 2026-10-22: Dismissals now remove active actors, update selection/AI/shape and replace a dismissed keeper in role; substitution menus remain open.
  Select eligible substitutes, replace players, refresh role assignments and
  player switching, and keep playing with a dismissed player removed.
- [ ] **BR-018 — Tactical controls and match awareness**
  Expose tactical adjustments in-game and have teams react to score, time,
  formation changes and player count.

**P3 exit check:** a regulation-length match can progress through restarts,
goals, fouls, offside, cards, substitutions, half-time and full-time.

### P4 — Advanced football actions and feel

- [x] **BR-019 — Shooting and aerial actions**
  - 2026-10-27, v0.5.6: deterministic physical aerial contest across eligible
    field-player foreheads and legal keeper gloves, active nearby defenders,
    a dedicated challenged-header and high two-hand claim, and six distinct
    left/right ground-shot style clips. Existing rest/mesh/rules and live
    contact bounds remain. See `art_briefs/br019_finish_2026_10_27/`.
  - 2026-10-26 free-kick follow-up (19/27, in progress): real approach/contact,
    trajectory aiming, distinct power/low/curl, contextual AI and reacting wall.
    Original 60 Hz wall poses retain the shared rest. Both teams/venues have
    live boot/miss/clearance/flight checks; native wide/contact/aim reviews
    remain distinct from M1 acceptance. See `art_briefs/free_kick_polish_2026_10_26/`.
  - 2026-10-26 (19/27, in progress), v0.5.1: four left-foot strike add-ons,
    locked contextual boot choice, physics-time ground markers and unchanged
    live anatomical contact guards. Moving/first-time strikes, both-direction
    volleys/half-volleys and native left shot/volley/cross receiving pass.
    Protected bodies/heads/kits/rests/gaits survive; complete imported left
    poses mirror actual shipping right motion within 0.317 mm. The later
    aerial/strike pass is recorded above; broader plant polish stays BR-021.
    See `art_briefs/left_foot_ai_2026_10_25/`.
  Add driven, finesse, low, first-time and contextual shots; headers, volleys,
  jumps, aerial contests, crosses, lofted passes and goalkeeper cross claims.
  - 2026-10-23 **in progress**: R/T charge-release loft/cross, assisted forward
    recipient selection, near/far-post support, damped airborne prediction,
    AI deliveries, automatic chest receiving and contextual Space headers.
    Original 60 fps Blender clips share the unchanged rig/body; physical jump
    and ≤20 cm anatomical contact checks gate head/chest impulses. Mirrored
    keyboard, flight, contact, miss/cancellation and contested-cross regressions
    pass. Native sequences and full-match results are recorded in
    [aerial-play evidence](art_briefs/aerial_play_2026_10_22/brief.md).
    Follow-up below adds the shot/cross variants and contextual boot strikes.
  - 2026-10-23 advanced pass **in progress**: keyboard Z/X/V select finesse,
    power and low ground shots, or lofted/driven/early T crosses. Independent
    finesse spin, charged strength and bounded attribute/pressure error affect
    flight. Original shared-rig volley/half-volley clips validate actual boot
    proximity; half-volleys require a real ground bounce. AI selects contextual
    strikes and deliveries. A zero-based export plus imported contact-pose
    checks align the new clips with their markers. See
    [implementation/evidence](art_briefs/advanced_shots_2026_10_23/brief.md).
    Follow-up: low-render gait poses now update on the physics clock. Fixed-
    cadence six-match tests pass locally at 34/27 shots, both qualifying 6/6;
    CI passes at 27/20, qualifying 5/6 and 6/6. All 70 regressions, low-render
    pose testing and universal Mac packaging pass; the Mac release is published.
    Cross-machine counts vary; bitwise replay determinism remains unproven.
    Next acceptance: final native/M1 input and motion review; dedicated high
    keeper claims depend on BR-009 (9/25). Left-foot variants followed in
    v0.5.1, and the remaining BR-019 duel/strike work is completed above;
    broader plant polish remains BR-021.
- [x] **BR-020 — Defending and skill moves**
  - 2026-10-24 completed keyboard scope (20/27): retained F standing / G slide tackle, Ctrl jockey,
    J contain and H pressure; added K shielding and U/I/O/P/L/B possession
    skills, including charge-Space then E fake-shot cancellation. Thirteen
    original 60 Hz shared-rig clips preserve current body/head assets. Bilateral
    live-toe contacts, missed/lost possession, collision restoration, shield
    upper-body isolation, clean-tackle counterplay and moving skills pass.
    Native motion and the six-match chance gate pass; Boardeaux qualifies in
    5/6 fixtures, with one zero-shot fixture remaining under BR-008. See
    `art_briefs/br020_skills_2026_10_24/brief.md`; Mac feel remains under BR-025.
  Add jockeying, shielding, teammate pressure, ball roll, step-over, body feint,
  fake shot, drag-back and directional skill turn. Each move must affect control
  or ball position, not just play a cosmetic clip.
- [ ] **BR-021 — Animation contact and blending pass**
  - 2026-10-31 (21/27, in progress): real 11v11 start, moving 90-degree turn
    and reversal toe traces now have a faster but bounded gait blend and
    velocity-led facing during sharp turns. Mean low-foot slip falls
    0.786→0.474, 1.557→0.571 and 1.846→0.784 m/s respectively, with unchanged
    sampled controller path/speed. Native Forward+ moving review, live contact
    checks and seeded match results are in
    `art_briefs/br021_transition_2026_10_31/`. Human play feel, any remaining
    start/turn/intro animation polish and target-Mac acceptance remain open.
  - 2026-10-25, v0.4.2: four original 60 Hz receive add-on clips on the unchanged 65-bone rig; selected leg/upper-body overlay retains supporting gait and phase. One shared-content layer with actor-local selection/filtering replaces costly serial branches. Receive-to-run, both feet, contact and cleanup checks extend the existing stride/turn/brake coverage. Native before/after evidence is retained; broader authored turn/intro motion and M1 acceptance remain open.
  - 2026-10-24 stride/plant pass (21/27, in progress): five original normalized
    shared-rig walk/slow-jog/jog/sprint/close-control loops match stance travel
    to world movement, with phase-aligned blending, lifted recovery, gait-specific
    arm swing and neutral wrists. Seven steady cases measure 0.023–0.104 m/s
    low/flat-foot slip; the earlier 3/6/8.6 m/s cases slid roughly with the root.
    Walking/slow-jog points also prevent below-turf interpolation. Fast braking
    keeps stepping until the final stop pose near rest. Kick preparation now
    damps velocity relative to its carrier, retaining the force cap, arbitration,
    marker and boot-contact guard. All 13 moving strike cases pass, with the
    off-axis miss preserved. Fourteen unique smoke checks, native moving
    evidence and the six-match chance gate pass. The 65-bone rest and all 28
    protected body/head/motion assets survive. See
    [source, native review and results](art_briefs/br021_stride_2026_10_24/brief.md).
    Broader turn/start/intro footwork and native Mac acceptance remain open.
  - 2026-10-23 realism follow-up: render-time skeleton interpolation retains
    authoritative tick poses for live contact and replay capture; staged
    presentation clips evaluate each drawn frame. Contact/replay invariance,
    animation and full-presentation match checks pass. Source gait/contact
    keys are unchanged. Native stride/plant quality and M1 timing remain open.
    See `art_briefs/realism_finish/brief.md`.
  - 2026-10-22: Fixed long-run skating: imported motion resources explicitly loop independently of node settings, with a sustained live-dribble regression.
  - 2026-10-21: first-time pass/shot starts can skip redundant anticipation
    while keeping accelerated playback at 1.5×. Shots can interrupt receive
    settle and new ball actions can interrupt completed contact follow-through.
    Pending pass state is armed after synchronous prior-action cleanup. The
    shared rig and all 19 source clips are unchanged; general stride/plant and
    native final-mesh acceptance remain open under item 21/25.
  - 2026-10-18 T-pose fix: spawning now instantiates a clean player scene;
    duplicating the configured live player reproduced two skeletons per clone.
    Added a one-rig-per-player and immediate startup-pose regression, primed
    the replacement rig before its first frame, and relaxed StopFromRun arms
    in Blender without changing existing leg/root/contact curves. Added shared
    original 60 fps WalkOn/WarmupJog clips for the broadcast intro.
    See `art_briefs/presentation_source_audit.json` and the presentation brief.
  - 2026-10-18 release pass: running direction changes retain the locomotion
    gait instead of playing a planted pivot. Both shared-human pivot clips
    now reuse relaxed idle arms; all non-arm curves and contact timings are
    preserved. The source builder, `.blend` and GLB share the fix. Imported-rig
    pose and moving-turn regression checks pass. See
    [`art_briefs/shared_turn_polish.md`](art_briefs/shared_turn_polish.md).
    General stride/stance calibration and native moving-mesh acceptance remain open.
  - 2026-10-18 gait follow-up: visual blending now matches actual speed to the
    authored jog/sprint points and no longer forces sprint footwork at rest.
    Reference speeds come from each player's movement tuning. Source action
    paths were inspected directly in Blender; stride/plant curves were not
    changed. Final-mesh movement and source-footwork acceptance remain open.
  - 2026-10-18 focused follow-up: inspected shared Blender action curves and
    foot paths; no source curves changed. Pass/shot can interrupt harmless
    turn/stop recovery. In-place moving-turn foot slide, stride/phase matching,
    garment deformation and native moving-mesh acceptance remain open. Evidence:
    [`art_briefs/pes_motion_control_pass.md`](art_briefs/pes_motion_control_pass.md).
  - 2026-10-18: shared-human pass contact checked at 0.075 m from toe to ball;
    idle arms and near-horizontal locomotion arms corrected offline. Keeper set
    and standing save layers share the same 65-bone rig. Full action/deformation
    and target-Mac review remain open.
  Refine foot planting, turning, acceleration/deceleration, action interruption,
  first touch, contact timing and transitions across the animation set. Validate
  at gameplay camera distance with the final rig and moving ball.

### P5 — Art direction, presentation and shipping

- [ ] **BR-022 — Character and kit production**
  - 2026-10-28 realism review (22/27): four staged form/surface passes on six
    key faces, with distinct Robbie/David head and groom assets, plus one shared
    body corrective used by all players and the referee. Native before/after
    images, source/export and motion checks, art-director scores, and remaining
    limitations are in `art_briefs/br022_realism_2026_10_28/brief.md`. Exact
    likeness, finer hair/skin and M1 appearance/performance remain open.
  - 2026-10-24 Shane/John refinement (22/27): corrected portrait roll
    measurements guide individual cheek/jaw/brow/nose/lip forms, larger fitted
    irises, skin relief/roughness and matching scalp/beard boundaries. Shane's
    separate smile uses original fitted upper teeth on the existing head bind;
    neutral occlusion, exposed smile, closure and substitution/replay checks
    accompany native pitch-side views. John's reattached original also exposed
    missing lateral beard coverage: corrected cheek/jaw/sideburn fields and
    surface-normal strand visibility now wrap both sides, with feathered
    density, unchanged warm palette and bilateral native/profile audits. See
    `art_briefs/shane_john_refinement/brief.md`. Individual AAA likeness,
    inherited kit interfaces and target-Mac appearance remain open.
  - 2026-10-23 current pass (22/27): saved individual anatomy/surfaces, shared
    body/garment Fullness (John 0.42, player Des 0.58), matching head/groom
    deformation and close-up geometry reuse the live rig and atlases.
    New original Des side/back photos guide his short horseshoe groom with
    bare crown; both Feeney identities have rounder lid apertures and fitted
    closure. Source/export, independent appearance and native checks accompany
    `art_briefs/realism_finish/`. Individual AAA likeness, collar/shoulder
    openings and target-Mac acceptance remain open; these are not final heads.
  - 2026-10-23: four independent form/groom/roughness/blink/smile refinements have source/export and grounded native checks; exact/AAA likeness and M1 approval remain open. See `art_briefs/broadcast_turf_refresh_2026_10_23/brief.md`.
  - 2026-10-22 native look checks: football now uses its own bounded
    Forward+/Vulkan/Xvfb still runner for primary appearance evidence, adapting
    the wrestling capture principle without touching that project. Four native
    roster portraits and the actual 22-player/referee Close Broadcast scene
    record adapter, quality settings and hashes in
    [the native capture brief](art_briefs/native_forward_plus/brief.md).
    Browser checks remain Web-specific; software Vulkan stills do not close
    the Mac hardware, likeness or 60 fps gates. BR-022 remains in progress
    (22/25); next: use these native portraits for the remaining face/hair form
    corrections, then validate on the Mac when available.
  - 2026-10-22 four-head finishing pass: Shane now has an independent captured
    delta alongside John and the two distinct Des identities. Portrait-guided
    proportions, monotonic lip closure, fitted eyes, separate roughness and
    directional opaque grooms replace the earlier local variants. John's scalp
    has blonde highlights while his beard retains its warm brown palette.
    [Source/export audits and pitch-side review](art_briefs/four_head_finish/brief.md)
    cover the four heads and protected body/rig/animation payloads. This is
    BR-022, item 22 of 25, in progress: detailed likeness, expression and native
    M1 appearance/performance remain acceptance work; the pass is not an AAA
    certification. Next acceptance: review the actual on-pitch front/turned
    portraits against the original photos, then address the remaining forms.
  - 2026-10-22 production workflow review: `create-player` now requires early
    face-form/runtime comparison, source-to-export agreement, continuous neck
    pigment, fitted grooms and explicit final-quality evidence. Its detailed
    head branch records Des/player, referee, skin, shadow and capture lessons;
    kit checks cover actual PBR/role UVs. [The review](art_briefs/create_player_workflow_review.md)
    maps recent findings to the skill and prioritizes Des's remaining facial
    anatomy and hair work. This guidance update does not finish the current
    heads. BR-022 remains in progress (22/25), with polished final players as
    the delivery target and native Mac acceptance still open.
  - 2026-10-22 fair complexion correction: shared body/master and all authored
    head variants now follow the owner's untanned skin direction, with
    individual pink undertones and preserved common neck pigment. Editable
    palette, unchanged body/animation payload audit, anatomical UV checks and
    fixed-light evidence live in [the skin review](art_briefs/fair_skin_review/brief.md).
    Four roster/resource/pose checks pass; final likeness and native Mac
    appearance remain open. BR-022 remains in progress (22/25).
  - 2026-10-22 Des #9 runtime follow-up: removed Compatibility self-shadow
    banding by tuning the shared sun normal bias (0.8 → 1.8), retained the head
    normal map, and preserved common skin texels at the neck interface. The
    failing/passing fixed-camera band check, source/GLB neck comparison,
    portrait/profile/full-body views and ball/goal shadow comparison are in
    `art_briefs/des_feeney_player_likeness/`. Five roster/pose/weather checks
    pass. Individual likeness and native Mac acceptance remain open (22/25).
  - 2026-10-21 Boardeaux Des #9 face/head refinement: player-only sculpt,
    fitted eyes, anatomical UV skin and receded hair/goatee now export together.
    The source/export audit catches the stale captured-delta problem; runtime
    roster/resource/pose checks and actual Web captures are recorded in
    [the Des brief](art_briefs/des_feeney_player_likeness/brief.md). All away
    slots intentionally share this identity; referee Des Sr. stays separate.
    Exact/AAA likeness approval and native M1 validation remain open (22/25).
  - 2026-10-21 pitch-side preview correction: Web and desktop roster reviews
    now use the Kilmore Drive park, match pitch surface, faded markings and
    low perspective cameras. The preview sky is locally lifted to a lighter
    daylight; match weather remains unchanged. Current gallery images show
    players standing on the pitch; the old fixture is retained only as historical
    diagnostic evidence. See `art_briefs/pitch_review_stage/brief.md`. This
    does not close goalkeeper gloves, individual likeness, save motion or
    native M1 acceptance. BR-022 remains in progress (22/25).
  - 2026-10-21 keeper graphics pass: the two actual 11v11 goalkeeper roles
    now use reference-led blue/grey/gold and charcoal shard shirt atlases,
    archived crest/manufacturer/sponsor lettering, role-correct sock binding,
    and profile-driven back names/numbers. Fixed front/back/save views and
    resource/pose/11v11 checks are in `art_briefs/keeper_kit_graphics/`.
    Pattern details are approximations. Glove geometry/material, John/Feeney
    facial likeness and a convincing save animation remain open; native M1
    appearance/performance is still pending. BR-022 remains in progress
    (22/25). Next: model keeper gloves against the archived hand/wrist sheet,
    then revisit individual faces and hair.
  - 2026-10-21 fabric response: original shared knit normal and role roughness
    masks now distinguish shirt/short cloth, socks and front prints, with mip
    filtering on pigment/data maps. Supplied graphics, geometry, rig and all
    19 clips are retained. Matched Blender and real-shadow Web sun/shade checks,
    roster resource/pose checks and Play/Watch pass; see
    `art_briefs/shared_fabric_response/brief.md`. This is incremental; bright
    pale areas, native M1 response and full likeness remain open. The keeper
    graphic follow-up is recorded above. BR-022 remains in progress (22/25).
  - 2026-10-21 collar/raglan finish: a smooth V opening and supporting yoke
    replace the uneven neckline. Narrow fitted raglan strips use the existing
    role-atlas trim colours, and the Blender default pigment now matches the
    runtime home atlas. Actual collar skin regressions fail on the previous
    source and pass in all nine fixed poses; trim inversions are zero.
    Rig/19 clips/skin/head packages are retained. Both sleeve pose sheets and
    actual roster Web evidence are in `art_briefs/shared_collar_raglan/`.
    Fabric/material fidelity, keeper graphics and individual likeness stay open.
  - 2026-10-21 shared shirt silhouette follow-up: fills the anatomical upper-back
    hollow on both sleeve variants and modestly tapers the long forearms with
    skin clearance. Same-cohort fold diagnostics improve overall (994 → 975);
    no topology, UV, weight, rig, clip, skin or kit-image changes. Fixed clay,
    both nine-pose sheets and actual roster Web views document the result.
    Raglan/collar finish, cloth materials and individual likeness remain open.
    See `art_briefs/shared_sleeve_fit/brief.md`.
  - 2026-10-21 shared garment construction: restores missing forearm skin
    beneath short sleeves, replaces the folded lower-shirt strip and separate
    ribbons with connected quad rows/hem, and reshapes the rear underarm gusset.
    The same nine-pose fold diagnostic improves in every pose; all 12 bare-arm
    probes pass. Rig, 19 clips, head packages and supplied kit images remain.
    Further shoulder/sleeve fit and individual likeness remain open. See
    `art_briefs/shared_cloth_finish/brief.md`.
  - 2026-10-20 shoulder/underarm pass: smoother shared arm weights, lower raglan
    yoke and continuous chest surface replace the inflated cap/chest tearing.
    A local UV patch keeps stripe registration; neck interfaces, kit images,
    rig and 19 clips remain. Nine-pose diagnostics improve, with rear axilla
    folds, hem and short-sleeve arm coverage still open. Web Play/Watch pass.
    See `art_briefs/shared_shoulder_fit/brief.md`.
  - 2026-10-20 shared neckline repair: removes disconnected throat scraps and
    the redundant collar ring, fits neck/shoulder cloth clearance and matches
    garment/skin weights while preserving the 65-bone rig and all 19 clips.
    See `art_briefs/shared_kit_repair/brief.md`. Collar/shoulder silhouette,
    underarm folds and individual likeness approval remain open.
  - 2026-10-19 shared-head follow-up: Shane's neutral head/eyes/skin are now the
    common starting master for both teams and referee. Each identity has an
    independent sculpt slot; compatible common changes regenerate with personal
    offsets retained. Separate hair selection preserves Shane's groom and bald
    identities without copying the groom to everyone. See
    `art_briefs/shared_head_pipeline.md` for source, commands and acceptance
    evidence. This completes the shared-head pipeline subtask; individual
    likeness, hair and garment approval remain open under this item.
  - 2026-10-19: Shane original-photo pass adds a separate head/eye/hair package
    on the unchanged shared rig, with a neutral identity and editable restrained
    smile. Integrated into both roster and retained 4v4 profile; likeness remains
    in review. See `art_briefs/shane_photo_likeness/brief.md`. The `/create-player`
    workflow now includes current production checks and removes stale first-pass
    and prototype-only assumptions. Photorealistic title portraits use the
    original David/owner photos and remain separate promotional artwork.
  - 2026-10-18 roster integration supersedes the prototype-only note below:
    a modular shared body/65-bone rig, 17 clips, six role atlases, small identity
    prints, editable height/build and topology-checked head sculpt deltas now
    drive the default 11v11 scene. 67,902 triangles include both sleeve variants;
    this is not a per-actor measured rendering budget. Collar/hem polish,
    individual face/hair likeness and exact keeper graphics remain open.
  Follow the project-local `.agents/skills/create-player/SKILL.md` for each
  reference-led player build; it requires source-to-feature mapping and fixed
  front/profile/three-quarter/broadcast review before accepting the asset.
  Replace the proxy with sheet-matched Beechlawn players: Shane Denham (#8),
  Robbie Roden (#10), David Murray (#5) and goalkeeper John O’Rourke (#1).
  Create a reusable roster/kit workflow. For Boardeaux, use Des Feeney (#9) as
  the supplied visual base for three outfield slots and the goalkeeper; keep
  those slots generic until more references arrive. Match face, proportions,
  hair, number, crest, fabric and skin tone; validate close and broadcast
  views. Build one shared animation rig and vary only mesh/material/kit data
  where practical.
  - Cloud progress: the current Y-Bot 4v4 rig uses the archived team and keeper
    palette values. An earlier primitive-visual pass tested sponsor/crest
    placement, numbers, socks and gloves against the kit object sheets. A
    reference-led Shane Denham #8 Blender/GLB draft now uses a licensed
    anatomical base and geometry-based face without a portrait texture. It
    passes the body/rig coordinate, normalized-weight, shared-neck-boundary
    and authored export-timing checks. The 2026-10-18 body/face/kit pass adds
    compact head/full torso shaping, anatomical facial targets, curved textured
    eyes, opaque short hair, a 2K anatomical head map and complete 2K panel kit.
    S. DENHAM / 8 and the enlarged sponsor are retained. Garments have sewn
    boundaries, loose shorts, cuffs and fitted socks; final counts and captures
    are in `docs/art_briefs/br022_shane_body_face_tailored_pass.md` and the
    checksum-bearing validation JSON. The subsequent likeness/deformation
    cleanup corrects the reversed neck normals, adds a clean CC0 skin bake and
    alpha-tested short hair, and replaces shorts with a fitted quad pattern.
    It removes a measured 125-degree thigh-roll mismatch in the prototype's
    six leg rotation tracks while preserving sampled contact paths. The rig
    stays at 65 bones with 15 clips; all other curves are unchanged. Current
    export: 51,022 triangles / six surfaces. See
    `docs/art_briefs/br022_shane_likeness_cleanup.md`.
    Blender pose/clay captures, Godot import smoke and fresh Web idle/portrait
    captures pass their structural checks. Visual review still exposes jagged
    collar/shoulder edges, a sleeve join and an uneven shirt hem. The prototype
    is still outside the roster: facial likeness/hair, garment cleanup, complete
    motion coverage, gameplay contact and M1 frame-time gates remain open.
    Follow `docs/art_briefs/br022_shane_likeness_and_kit_plan.md`; the next
    acceptance check is the reference-matched face/hair and full-clip garment
    review, before roster integration or duplicating the process to others.
- [ ] **BR-023 — Kilmore Drive and selectable Rovers Arena**
  - 2026-10-27, v0.5.5: fill all 49,554 existing arena seats; place Boardeaux in the 3,118-seat lower north-east allocation; apply each side's approved 80/20 clothing colours through garment-only masks across three VAT levels and close rigs; keep 64 colour-matched, hand-following waving flags and score/replay-aware body motion. Preserve Kilmore's eight spectators, v0.5.4 turf and the bowl/access geometry. Evidence: `art_briefs/stadium_crowd_2026_10_27/`. Target-Mac appearance/performance stays BR-025.
  - 2026-10-25, v0.4.1: reference-led UCL 26/27 League size-5 ball, editable Blender/continuous UV/PBR source, default for both venues and Play/Watch; saved worn-ball option; intro/replay continuity. Cosmetic selection preserves the existing collider and all ball tuning. See `art_briefs/ucl_ball_2026_10_25/brief.md`. Wider venue likeness/M1 remain open.
  - 2026-10-25, v0.4.0: owner-approved complete Hill Dickinson reference-led building replaces the octagonal arena. Distinct stands, tapered/fanned corners, a continuous home end, true-normal terraces, brick/metal/glass exterior, barrel roof/trusses and Rovers signage are authored in Blender. A section/row manifest replaces fixed banks and records actual-mesh seat support. Both venues receive short-turf/material refinement; Kilmore's original terrain, wear, markings and wet physics remain. Reference archive and native evidence: `art_briefs/hill_dickinson_remodel_2026_10_25/`. Exact photographic likeness and native M1 timing remain open.
  - 2026-10-24, v0.3.1: fixed the slanted seat/aisle appearance in the opposing
    stand. Bank-centred columns and continuous stair aisles replace row-relative
    drift; Blender/Godot conversion and inward bank-normal yaw correct all
    chair directions. Original terrace rise and gameplay camera are preserved.
    Exported-data, runtime placement and native GPU readback/captures cover the
    correction; see `art_briefs/arena_seating_alignment_2026_10_24/brief.md`.
  - 2026-10-24: owner-approved large second venue, original modular Blender
    source and GLBs; instanced seating/crowd LOD; maintained field and flags;
    shared functional goals/nets. Persisted venue selection and match-owned
    physics/surface/camera metadata preserve Kilmore. Further arena art polish
    and target-Mac performance remain open.
  - 2026-10-23 field-detail follow-up (23/27): curved 12–24 mm near blades
    and intermediate fins are selected across the field using projected size
    and frustum-prioritised chunks, with shared mud/puddle/paint masks. Default
    drawn detail is bounded at 205,568 triangles (240k resource budget), with
    cut preparation and distant surface detail. Native appearance and M1 frame
    timing are separate gates; see `art_briefs/realism_finish/brief.md`.
  - 2026-10-23: the weed-like tufts are replaced by dense short camera-local turf and matching CC0 normal/roughness detail; bounded residency, mud/water masks and native close views checked. Venue likeness/M1 remain open. See `art_briefs/broadcast_turf_refresh_2026_10_23/brief.md`.
  - 2026-10-23: camera-local curved grass tufts follow terrain and shared mud/water masks, capped at 40k tufts / 240k triangles; native close grass/net views inspected. Exact environment likeness and M1 frame time remain open. See `art_briefs/pitch_audio_2026_10_23/brief.md`.
  - 2026-10-22: Mirrored the exterior penalty arcs and connected physical net impacts to a visible anchored bulge; scored balls keep moving into the net.
  - 2026-10-20 wet goalmouth/weather pass: shared mud/water masks at both goals,
    physical ground-ball resistance and persisted Sunny/Cloudy/Light rain/Mist
    options. Sunny remains sunlit with damp ground. Depth haze is used across
    Web/native; volumetric fog is not a clear-weather requirement. See
    `art_briefs/kilmore_wet_weather.md` for implementation, research and checks.
    Native shadow/performance and faithful backdrop/vegetation approval remain open.
  - 2026-10-19 sky/light pass: owner requested brighter, less-overcast weather.
    A CC0 4K partly-cloudy panorama replaces the blank gradient, with sky fill,
    a matching warm directional sun and cast shadows. Shared editable daylight
    settings serve match and player-review scenes. See
    [`art_briefs/kilmore_sky.md`](art_briefs/kilmore_sky.md) for source, before/after
    captures and validation. Native M1 lighting/performance approval remains open.
  - Satellite-footprint follow-up: added the tapered western green, inset
    back-garden edge, western road/path continuation and nine reused roadside
    houses. Blender/Godot geometry preserves the open 105 x 68 m playing area
    and grass buffer. Property/vegetation realism remains open; see
    [`art_briefs/kilmore_site_footprint.md`](art_briefs/kilmore_site_footprint.md).
  - Pitch-paint follow-up: softened the chalk pigment and reduced specular
    highlights while retaining uneven widths and worn edges. See
    [`art_briefs/chalk_fade.md`](art_briefs/chalk_fade.md) for the broadcast comparison.
  - 2026-10-19 satellite placement correction: a 35 m authored grassy apron
    now separates the road-facing touchline from the footpath; the near road
    edge is 37.75 m away instead of 8.5 m. Street, houses, cars and service
    details move together, trees concentrate near the distant park edge, and
    spectators remain by the touchline. Ground meets the field at grade while
    leaving its terrain relief unobscured. Exact site outline and road bends
    remain open. These distances are reference-led approximations, not survey
    measurements. See [`art_briefs/kilmore_road_setback.md`](art_briefs/kilmore_road_setback.md).
  - 2026-10-18: added shallow matched heightfield/render terrain (under 6 cm),
    broken-width chalk, weathered regulation goals with sagging alpha-test nets
    and a cheap impact ripple, leaf-card trees, textured houses/cars/walls and
    eight human spectators. Roadside is open rather than ringed by a wall.
    Heights and placement are inferred, not surveyed; individual houses/trees
    and precise reference matching remain open.
  Replace the flat pitch/backdrop blockout with locally appropriate worn grass,
  irregular chalk, weathered goal/net, residential houses, hedges, trees,
  roadside/park details, subdued crowd and overcast/evening lighting. Establish
  a reusable Godot venue setup around the Kilmore Drive reference: keep pitch
  dimensions/layout, ground and marking materials, boundary/backdrop dressing,
  and lighting/weather settings separable so later grounds can be assembled
  without duplicating the whole scene. Finish and validate this baseline before
  producing additional venues. Prefer free, properly licensed assets or original
  Blender work; record each asset's source and license. PES-specific stadium
  exporters do not produce Godot-ready assets and are not part of this pipeline.
  - Cloud progress: `scripts/kilmore_drive_venue.gd` now assembles the park
    backdrop around the existing 105 m × 68 m field, with original low-cost
    Blender house, tree and car modules plus wall, hedge, path, road and lamp
    dressing. The editable Blender source and reproducible builder are in
    `tools/blender/beechlawn/`; the imported GLBs are in
    `assets/environment/kilmore/`. This is a first modular blockout, not the
    finished reference-matched environment or an M1-validated render. A first
    web capture exposed and helped fix houses facing away from the pitch; the
    capture now shows their facades, CC0 grass/asphalt textures blended with
    broad wear, roadside and softer overcast light. Tree, car and house assets
    remain visibly stylized and surface/goal wear needs another pass. Asset
    sources/licenses are recorded under `assets/environment/surfaces/ambientcg/`.
    A 4v4 scene smoke test checks module loading, inward-facing facades, licensed
    surface maps, site dressing and kit variants.
- [ ] **BR-024 — Audio and match feedback**
  - 2026-10-26 (24/27, in progress): recorded 20-clip match bank, two venue beds,
    event-prioritized reactions, scheduled stadium chants, rain, 12 priority field
    voices, whistle ducking, replay/full-time isolation and clean menu teardown.
    Source/hash/license catalogue and scrollable credits ship with the game.
    Native AudioServer signal checks cover both venue mixes and independent mute;
    subjective M1 listening acceptance and optional recorded commentary remain
    open. See `art_briefs/recorded_match_audio_2026_10_26/brief.md`.
  - 2026-10-25 (24/27, in progress): owner-selected **Cool Rock** by Kevin
    MacLeod replaces the synthesized menu/intro loop, with CC BY 4.0 credits
    accessible in Options and shipped source/license notices. Recorded kicks,
    referee, net, stadium crowd/chant and goal reaction sources researched;
    this earlier shortlist was integrated in the 2026-10-26 recorded-audio slice.
    See `art_briefs/audio_replacement_2026_10_25/research.md`.
  - 2026-10-23: original CC0 menu/intro music and eleven Foley/ambience/UI clips, typed match events, bounded voices and saved Music/Match/UI buses. Native Movie Maker verifies nonzero unclipped output and bus mute. Blue HUD/intro cleanup and title build identity shipped; native M1 mix/feel approval remains open.
  - 2026-10-18 pre-match slice: approximately 40-second original TV-style intro
    with walk-on, lineup, roster-labelled player/keeper portraits, venue,
    goal/net, fan, chalk/grass, ball and warm-up shots. Options toggle and
    Space/Enter skip; no intro after goals. Play/Watch freeze, restoration and
    kickoff checks pass. Final animation/art polish and the audio/event
    director below remain open. See
    [`art_briefs/broadcast_presentation_plan.md`](art_briefs/broadcast_presentation_plan.md).
  - Title/presentation slice: reference-led GPT Image key art, supplied-kit
    crest, native keyboard/mouse menu, Play/Watch launch modes and saved master
    volume/native fullscreen preferences. Spectator mode keeps all 22 players
    autonomous through either team's goal restart. See
    [`art_briefs/title_screen.md`](art_briefs/title_screen.md). This does not
    complete the remaining audio/event-director work below.
  - 2026-10-21 title refresh: the supplied white/red wordmark replaces the
    native title; red/black/white controls also cover Options. Existing player
    photography and blue/black kits are unchanged. Godot Play/Watch and Web
    1280×720/640×480 checks pass; see
    [`art_briefs/title_red_black_evidence/brief.md`](art_briefs/title_red_black_evidence/brief.md).
  Add distinct ball/player contact, referee, crowd, goal and UI sounds; tune the
  mix so key events remain audible without overwhelming play. Route feedback
  from typed match events rather than screen capture or OCR. Give events the
  context needed by listeners (event type, players involved, match time, score,
  and urgency), then use an audio/commentary director to prioritize important
  moments, select relevant recorded lines, apply per-line and event cooldowns,
  prevent commentary overlap, and duck crowd audio where appropriate. Start
  with gameplay events and audio hooks; add recorded commentary only when
  suitable, properly licensed recordings are available. Verify event routing,
  timing, priority, cooldowns, and mix behavior with test clips before content
  production.
- [ ] **BR-025 — M1 performance and Mac delivery**
  - 2026-10-27 (25/27, in progress): inspect the v0.5.5 crowd and combined match on the packaged M1 Pro/16 GB Mac at 1080p. Validate appearance, detail switching, flag animation and sustained 60 fps with hardware timings and resident memory; cloud software Vulkan confirms integration only.
  - 2026-10-25 (25/27, in progress): v0.4.1 packages both ball choices and venues. Release verification now boots each ball/venue pair from the actual PCK. Native M1 appearance, input feel and sustained 1080p60 remain hardware acceptance checks.
  - 2026-10-24 (25/27, in progress): v0.3.0 combines the tested heads, skills,
    keeper/stride work, assisted controls, monochrome HUD and selectable arena.
    Twelve complete matches (six/venue) pass the chance gate; native Forward+
    screenshots cover both grounds/options/intro. Verify the exported universal
    package and both packaged venue startups, then check input feel, moving
    appearance and sustained 1080p60 on the target Mac. Cloud evidence does not
    close hardware acceptance.
  - 2026-10-18: separate football universal Mac/Web exports and release workflow
    added, preserving the wrestling Pages root and its Mac release. Package
    structure checks do not substitute for native playtesting or 60 fps profiling.
  Profile the full 11v11 build at 1080p on the M1 Pro/16 GB. Target stable 60
  fps; identify CPU/GPU frame-time spikes, memory growth, shader stutter and
  input latency. Optimize only measured bottlenecks. Add a separate Beechlawn
  Mac export/release workflow that cannot replace Aegis builds.

**P5 exit check:** the complete match is legible and attractive at broadcast
distance, stays within the Mac frame-time budget, and can be built/released
without touching Aegis artifacts.

- [x] **BR-026 — Goal and full-time presentation**
  - 2026-10-23 optics follow-up: camera-local cinematic depth of field and
    short motion-vector blur, with cut suppression and exact wide/skip/exit
    restoration, have logic/native Forward+ checks. Optional TAA stays off by
    default; crisp live gameplay retains MSAA. Moving/M1 optical polish remains
    under BR-025; see `art_briefs/realism_finish/validation.json`.
  - 2026-10-23: wide/medium/scorer close cuts, centered blue captions and directed full-time reactions/handshakes now have mirrored/runtime/native checks. See `art_briefs/broadcast_turf_refresh_2026_10_23/brief.md`.
  - 2026-10-23: original shared celebrations/handshakes, winners/draws, own-goal handling, reduced teams, automatic results with Rematch/Title and Space/Enter skip pass logic/native checks. M1 feel remains under BR-025.
  Scorer/teammate reactions, own goals, winner/draw treatment, handshakes and
  a usable Rematch/Title results screen. Original shared animations; skippable,
  clock/rules isolated and valid with reduced teams.
- [x] **BR-027 — Incident replays**
  - 2026-10-23: recorded incident metadata and facial poses support sideline then slow alternate-angle replay; opaque-obstruction selection, gameplay isolation and exact restart restoration pass. See `art_briefs/broadcast_turf_refresh_2026_10_23/brief.md`.
  - 2026-10-23: bounded root/bone/ball/net snapshots, actual runtime head/kit ghosts, rule/audio/clock isolation, natural-stoppage autoplay and exact skip/restore checks pass. Full unskipped match reaches results; native fixture evidence is in `art_briefs/match_outro_replays_2026_10_23/`.
  Collision-free ghost playback from bounded pose/ball snapshots. Goals and
  major incidents replay automatically at natural stoppages; Space/Enter skips.
  Restore the exact pending restart without duplicate events or scores.

## Risks and scope guardrails

- The approved 11v11 pass supersedes the old 4v4-only gate. Retain 4v4
  regression checks and validate full-team movement, AI and performance separately.
- Use original code, rigs, animation and art. The commercial-game references
  guide general feel and camera/control conventions, not copied assets or code.
  Apply a clean-room workflow: use observed behavior and high-level design
  principles as references, while implementing Beechlawn's systems independently.
  Do not make the project depend on PES binaries, extracted PES content, or
  PES-specific archive/export tools. Track provenance and license terms for
  third-party assets before they enter the project.
- Do not add detailed faces, crowds or expensive animation before profiling the
  playable match loop. Use LODs, shared materials, instancing and simple
  collision geometry for the distant park setting.
- Re-run the milestone smoke checks after gameplay changes and record what is
  genuinely playable in the README.

## Confirmed first-slice format

- Initial 4v4 slice is retained for regression; the approved default is now 11v11.
- Keyboard controls only for the first playable; gamepad support is deferred.

## Confirmed character and animation sourcing decision

- Use Mixamo's Y-Bot as the current temporary rig/import base. Its supplied
  robot shell is for pipeline validation only, not the visual target for the
  human player sheets. Keep the character replaceable and record source/license
  with imported assets. Do not treat stock clips as final football-specific
  animation without review and cleanup.
- Check Rokoko's free sports mocap clips as an optional supplement where a
  motion is relevant; availability of a suitable football action is not
  assumed.
- The intended final characters remain the supplied-sheet-matched Beechlawn
  players on a reusable shared rig, with the Boardeaux visual-base approach
  defined above. Temporary assets must not replace those likeness targets.
- Import/retarget through Blender and Godot's glTF pipeline, checking bone rest
  poses, scale, root motion, foot sliding and action contact timing. The
  owner-supplied Mixamo Y-Bot source FBX and cleaned GLB are integrated; no
  usable animation clips or final human player mesh have been integrated yet.

Research references:

- [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)
  and [Mixamo rigging and animation guide](https://helpx.adobe.com/creative-cloud/help/mixamo-rigging-animation.html)
- [Rokoko free sports mocap clips](https://www.rokoko.com/resources/rokoko-mocap-12-free-sports-animations)
- [Godot 3D scene formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
  and [skeleton retargeting](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/retargeting_3d_skeletons.html)

## Confirmed first-slice roster

| Team | Slot | Reference | Notes |
| --- | --- | --- | --- |
| Beechlawn Rovers | Outfield 1 | Shane Denham, #8 | Supplied full character sheet |
| Beechlawn Rovers | Outfield 2 | Robbie Roden, #10 | Supplied full character sheet |
| Beechlawn Rovers | Outfield 3 | David Murray, #5 | Supplied full character sheet |
| Beechlawn Rovers | Goalkeeper | John O’Rourke, #1 | Supplied goalkeeper sheet |
| Boardeaux | Three outfield slots | Des Feeney, #9 sheet | Shared visual base; identities/ratings remain generic |
| Boardeaux | Goalkeeper | Des Feeney sheet | Shared visual base with generic keeper kit/slot data |

The first team-versus-team gameplay milestone is therefore **4v4**, not a
full 11v11 match. This keeps the prototype small enough to validate passing,
switching, tackles, goalkeeper reactions and AI shape before scaling up.
