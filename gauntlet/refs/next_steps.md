# Aegis prioritised backlog

## Unreal move sync

CI builds a versioned move bundle and checks the Unreal trajectory snapshot.
The snapshot now includes the latest Snap Dragon 3, Cross Rhodes and Mexican
Destroyer data. Reimport and retarget the animation assets, then use the editor
script to refresh and verify the move tables. Engine-specific grapple behavior
and native Unreal parity remain open. [Move sync workflow](../../tools/unreal/MOVE_SYNC.md).

## Cross Rhodes rear hold

Cody reaches for the left wrist and hooks the neck with his right forearm
from behind. The regression measures both contacts through the hold with
Roman, Kenny, and the mannequin. Published and verified for Mac at `1c87df0`.
The landing and recovery follow-up is recorded below. [Implementation and validation](cross_rhodes_opening_2026_11_22/README.md).

## Cross Rhodes descent and wristlock counter

Both Blender role clips keep the established rear hold. Cody follows the
defender farther into the drop before releasing him, and the defender's
head leads the landing before his shoulders and hips settle. The move hands
off to Down in the authored direction and eases into a small forearm guard.
Kenny has an individual fit into the cover.

On the displayed impact sample, Roman's head skin was 0.9 cm below the
mat and Kenny's was 0.9 cm above it. Kenny's back and boots cleared the mat
through the first 12 Down frames. All 50 focused checks passed, including
the opening and closing edges of the wristlock window across both slots. Native
review, tighter control through the inversion and Roman's late boot and leg
clearance remain open. [Side and match-camera samples](ff_review/moves/cross_rhodes.png).
[Unreal timing and fitting cases](../../tools/unreal/GRAPPLE_LIFETIME.md#cross-rhodes-descent-and-wristlock-counter).

## Running inverted drop landing and recovery

The late settle and private Roman and Cody recovery clips address measured
boot, head and back penetration. The original Roman head impact fit is
retained. Published and verified for Mac at `bf25f3f`. [Implementation and validation](running_drop_landing_2026_11_22/README.md).

## Standing reversal audit

Godot binds a standing parry read to the exact incoming strike and expires it
at the end of that strike's window. Live jab contacts cover both player slots,
a restarted jab, and lockout after an early attempt. All 35 focused checks
passed. Mac run [45175251174](https://github.com/denhamd2/aegis/actions/runs/45175251174)
published `5b9c253`. The exact tag, release target and uploaded 1,034,173,123-byte
ZIP were verified. The contact-tick follow-up resolves valid standing
contacts after both wrestlers read input, using the original strike frame
for AI and allowing either slot to start the same parry on the last legal
contact frame. All 60 focused checks passed. Mac run
[45177947449](https://github.com/denhamd2/aegis/actions/runs/45177947449) published
`ae1d641`. The exact tag, release target and uploaded 1,034,173,564-byte ZIP
were verified. Unreal runtime parity remains open.
[Unreal parity cases](../../tools/unreal/GRAPPLE_LIFETIME.md).

## Paired chain grapple counters

The referee resolves both slots against the same chain-read clock. The
defender gets one stamina-charged attempt per read. A successful read
immediately transfers both roles to the existing authored paired hold.
Misses leave the holder's move available. Interrupted reads and cancelled
playback release both wrestlers without landing wear. All 89 focused checks
passed, including authored playback and cancellation in both slots.
[CI](https://github.com/denhamd2/aegis/actions/runs/45181182407) passed.
[Mac run 45181182339](https://github.com/denhamd2/aegis/actions/runs/45181182339)
published `5ea5262`. The exact tag, release target and uploaded
1,034,174,377-byte ZIP were verified.

At seed 1 and 20,000 simulation ticks, the chain-counter tally was five for
Cody–Roman, zero for Roman–Cody, zero for Kenny–Cody and one for Kenny–Roman.
All four reached the tick cap. The prior build also reached it in both
Cody–Roman slot orders, with six and two counters respectively. Native
visual review and broader match-completion validation remain open.

The vertical suplex is covered in the committed throw follow-up.
Other throws, directional attacks and specials still need their own
counter choreography and gameplay integration. Unreal runtime parity
remains open. [Unreal parity cases](../../tools/unreal/GRAPPLE_LIFETIME.md#paired-chain-grapple-counters).

## Committed vertical suplex counter

The defender can escape the vertical suplex during its grounded facelock.
Ticks 6–14 of the paired clip accept one stamina-charged attempt. The
escape cancels the original throw and starts the existing paired waistlock
go-behind with swapped roles. Mistimed or exhausted attempts preserve the
original throw. All 92 focused checks passed. Live AI smoke checks recorded
one reversal press and one counter landing in each slot.
[Mac run 45201991921](https://github.com/denhamd2/aegis/actions/runs/45201991921)
published `f2c98c8`. The exact tag, release target and uploaded 1,034,175,370-byte
ZIP were verified. The [Unreal bundle](https://github.com/denhamd2/aegis/actions/runs/45201992008)
contains the window, counter ID and both source role clips.
Directional and special counters have separate coverage below. Native
transition review and Unreal runtime integration remain open.
[Unreal parity cases](../../tools/unreal/GRAPPLE_LIFETIME.md#committed-vertical-suplex-counter).

## Arm-hook and running Spear counters

Kenny's right-arm sweep can be caught in a wristlock on ticks 20–26.
Either running Spear variant can be caught in a side headlock on ticks 16–22,
before the dive. Both routes cancel the pending impact and use the existing
paired lead-in and role clips. A late Spear attempt still lands the finisher
with its ordinary meter and cover rules. Committed AI reads now use the
move ID and the match phase's reversal scale. The arm-hook counts one
attempt at rig acceptance. All 118 focused checks passed. The 12 seeded
real-roster scenarios covered both slot orders for each roster pairing,
with a counter and a normal landing per pairing. Each counter recorded one
press and preserved both root positions on the handoff.

[Mac run 45207049716](https://github.com/denhamd2/aegis/actions/runs/45207049716)
published `e31b7fd`. The exact tag, release target and uploaded
1,034,175,802-byte ZIP were verified. The [Unreal move bundle](https://github.com/denhamd2/aegis/actions/runs/45207049916)
exports all three MoveDef mappings and both roles of the two replacement
clips. Native transition review and Unreal runtime integration remain open.
[Unreal parity cases](../../tools/unreal/GRAPPLE_LIFETIME.md#arm-hook-and-running-spear-counters).

In the matched seed-1 AI comparison with arena presentation omitted,
Roman–Cody reached the 48,000-tick cap before and after the batch. Cody–Roman
ended with Roman winning by pinfall at tick 27,489 before and 26,399 after.
Both Cody–Roman runs had three Spear attempts. Landings went from three to
two with one side headlock counter in the new build. Each slot order had
three rope runs on both builds. The capped order was fixed in the next batch.

## AI match completion after an interrupted rope run

Roman–Cody seed 1 stalled after Roman fell below the ring. Cody had his
finisher ready while Roman was hundreds of metres below him by tick 26,100.
An interrupted absorb left a rope collision exception active after the
wrestler left the whip state. Ring containment now resumes the tick that
the absorb or return releases its exception. The regression fails on the
previous controller and passes on the fix. All 42 focused checks passed,
including ordinary whips, rope-running attacks, match flow and replay.

With seed 1 and arena presentation omitted, Cody pinned Roman at tick 25,599
in the previously capped order. Roman pinned Cody at tick 25,705 in the
swapped order. Roman and Cody also each pinned Kenny, at ticks 28,308 and
28,214 respectively. Recent power-move repetition varied by slot order.

[Mac run 45211118981](https://github.com/denhamd2/aegis/actions/runs/45211118981)
published `ea08a2a`. The exact tag, release target and uploaded
1,034,175,757-byte ZIP were verified.
[Unreal parity case](../../tools/unreal/GRAPPLE_LIFETIME.md#interrupting-a-rope-absorb).

## Referee and cover resolution

Aubrey picks a fresh route for each cover, joins the current slap if she
arrives during its windup, and moves between swings when the bodies have
shifted. Late kickouts cut the third windup and a completed three-count
retains the follow-through. The measured count schedule stays at ticks 92,
167 and 227. A kickout after two triggers the same scoring and broadcast cue
through input and automatic recovery.

Rope breaks use the settled cover position and verify the selected rope on
the contact tick. The hold or cover releases before the HUD shows ROPE BREAK.
Scripted covers obey the match's stipulation and normal ring boundaries.
Native visual review and [Unreal runtime parity](../../tools/unreal/GRAPPLE_LIFETIME.md#pin-and-rope-break-resolution)
remain open.

All 183 focused checks passed. Both seed-1 Roman–Cody slot orders retained
their pinfall winner, finish tick and recorded move counts from `ea08a2a`.
The [Unreal move sync run](https://github.com/denhamd2/aegis/actions/runs/45215733475)
passed for the shared bundle.

[Mac run 45215733542](https://github.com/denhamd2/aegis/actions/runs/45215733542)
published `047b2c7`. The exact tag, release target and uploaded
1,034,175,347-byte ZIP were verified.

## Grapple cancellation and teardown

Godot releases surviving wrestlers and restores their previous physics state
when the rig or a participant exits or when the move is cancelled. Cancelled
moves clear pending completion callbacks, camera impact cues and replay
capture. All 65 focused Godot checks pass, including camera and replay.
Mac run [45173653558](https://github.com/denhamd2/aegis/actions/runs/45173653558)
published `8d06861`. The exact tag, release target and uploaded 1,034,172,437-byte
ZIP were verified. Broader reversal coverage and the Unreal implementation
remain open.
[Unreal parity cases](../../tools/unreal/GRAPPLE_LIFETIME.md).

## Snap Dragon 3 rear entry and clearance

Kenny starts behind the grounded defender and the rear walk-in preserves their
approach sides. Defender shin clearance improves in all three probe pairings.
The move completes and restores physics in both player slots. Published for Mac
at `0c15f09` with the exact tag and uploaded ZIP. [Validation and remaining hold and landing work](snap_dragon_3_2026_11_22/README.md).

## Mexican Destroyer timing

Published at `6afc76d` with the exact `mac-latest` tag and uploaded Aegis.zip
verified. Both role clips finish with the 2.533 s root track. All 34 focused
tests pass. The real controller delivered the move once and restored physics
for both wrestlers. [Timing, release and CI triage](paired_ci_2026_11_22/README.md).

Continue with the remaining paired contact and source pose failures. Mexican
Destroyer needs hand and cadence corrections plus real-roster clearance work.
The Snap Dragon 3 clearance and entry work is recorded above. Cross Rhodes's
remaining rotation and impact work and walk-arm cadence remain open.

## Published: character-specific Roman impact fit

37 focused checks pass. Roman's real head skin at running-drop impact improves
from24.6cm to2.1cm above the mat (next sample0.8cm), with no new protected-surface
penetration in the fitted window. Both physical slots and intermediate samples
were checked. Mac run [43824387319](https://github.com/denhamd2/aegis/actions/runs/43824387319)
published the batch at `d1c1c3e`. Subsequent releases retain the fit.
[Evidence and remaining anatomical limits](roman_landing_fit_2026_11_16/README.md).

The previous claim that Roman's head reached the mat at61 included hair; actual
skin needs its own measurement. The running-drop landing and recovery batch
above records the later anatomical and Cody-specific corrections. Grapple
lifetime, full move acceptance, and native M1 performance remain open.

## Published: camera impact-shake repair

Owner moved backlog8 ahead of landing fit.45 focused cases pass. One scheduled
cue now covers all camera modes, avoiding shot-delayed/repeated pulses and the
second notification at paired completion. OFF cancels old/new cues; LOW/HIGH
retain their strength and continuous animation. Running-drop shake uses authored
impact59 rather than catch37. [Evidence](camera_shake_2026_11_15/README.md).
Mac run43761306666 succeeded; exact commitfb01d89 and uploaded
Aegis.zip1,033,207,483bytes verified. Latest Kenny work8cb7576 is preserved.
Native shake feel awaits owner Mac review. Later tuning is included in the
Mac build from `29cfb01` onward.

## Previous deployed: authored running-drop wrap and boot arc

Owner requested committing and deploying all current changes. Candidate4 replaces
bilateral waist forcing with an authored right-forearm sweep/free left arm,
corrects the inverted boot arc and spreads finger closure through recovery.
All72 focused checks pass (21 runtime +51 resource/authoring); imported cadence
has zero new holds/snaps.
The full317-clip export preserves all315 unrelated clips exactly; native Blender
source and approach baseline are retained. Mac run43753948084 succeeded: exact commitbf785ec and uploaded
Aegis.zip1,032,800,316bytes verified. [Evidence](ff_initiative_2026_11_14/batch3/running_drop_reauthor/README.md).

The later impact and recovery batches above cover the character-specific fits.
Torso orientation through frame 55, early toe penetration, and normal-speed
review remain open. Preserve roots and the authored approach and catch.

## Previous deployed batch: release fitting and grip timing

Owner approved publication of the implemented runtime running-drop release fix: cosmeticY smoothly returns to zero before impact; grip fades at55 and
is off by58.33distinct focused checks pass, both real pairing maxima preserved.
[Current evidence](grapple_release_2026_11_15/README.md). Exact Mac release
5e4a165 and uploaded ZIP verified; run43698792321 succeeded.
Next source task is the asymmetric right upper-body wrap/left free arm; original
authored impact height, teardown lifetime and full move acceptance remain open.

## 15 November: owner-approved all-changes Mac review build

Owner requested committing and deploying all current changes, including Kenny's
R7/R8 art/source, the bounded running-drop left-leg correction and validation
tools. Mac run43695558573 succeeded; exact mac-latest commitf681d07 and
uploaded Aegis.zip are verified. See the current evidence receipt.
The leg slice improves mannequin overlap .090→.031m without changing real-pair
maxima. No solver experiment is included. Full move acceptance, correct load
hand roles, runtime lift, Kenny beard coverage and the new groom's overall
likeness remain open; the merged commentary cue-selection tests also have two
failing cases. No10/10/AAA claim. [Current evidence](ff_initiative_2026_11_14/batch2/README.md).

## Current grapple delivery

Timing fallback batch `9c1976b` is deployed to Mac; exact release and ZIP verified.
Next approved batch fixes swapped authored-role transforms and isolates
AnimationPlayer libraries between matches/replays. All23 focused cases pass;
Mac release `0ef511b` and uploaded ZIP are verified. Teardown suspension and source contact
corrections remain open. [Evidence and roadmap](ff_initiative_2026_11_14/README.md).

## Current owner priority: Fight Forever gameplay initiative

Owner14November: prioritise synchronisation/grappling and existing animation
quality, then reversals, AI, referee, library and broadcast improvements.
[Current audit, roadmap and first implemented timing fix](ff_initiative_2026_11_14/README.md).
Preserve all pending Kenny assets/likeness work and prior backlog scope.

## Preserved Kenny likeness work

The latest cell work is deployed atb40f772. Owner requested the ambulance next:
remodel in Blender using the supplied screenshots, then perform three independent
judge/revision loops aiming10/10 with honest scores. Preserve doors and match
interactions; [current evidence/ledger](ambulance_judge_2026_11_13/README.md).
Ambulance iterations are complete at7.4/10;6focused cases pass, exact
`fa5c06d` Mac publication verified. After its verified deployment, Kenny likeness (head/face/hair/body)
and an audit of model independence from Cody are the next owner priority,
using three judge/revision loops. [Current Kenny evidence](kenny_judge_2026_11_14/README.md):
all three revisions complete, **4.1 → 4.0 → 4.5 → 4.6/10**. Kenny now owns an editable
Blender source and independent identity profiles/maps/builds; shared neutral
rig/animation code remains. All 78 focused cases pass, isolated rebuild succeeds,
and 74 Cody assets are unchanged. Exact `253603d` Mac publication is verified. Facial likeness,
ribbon-like curls and skin detail remain open; no 10/10 or AAA acceptance.
Owner then requested further Kenny loops: three further rounds scored 4.1 → 3.9 → 4.6, recovering but not beating the
published likeness. They remain uncommitted/unpublished; 78 focused checks pass
on R6. Owner confirmed the four references and reiterated 10/10. R7 now changes
method to a measured neutral head fit in clay and an authored curl groom, with
landmark/silhouette approval before surface detail.
[Continuation evidence](kenny_judge_continued_2026_11_14/README.md).
The cell walking-strip study stays deferred.

## 13 November Blender requirement

Owner requires Blender modeling for the steel cage, Hell in a Cell, ambulance
and casket. Their native sources and exports are implemented; see the
[authoring evidence and remaining visual acceptance](blender_props_2026_11_13/validation.md).
**AAA quality and WWE2K visual parity are not complete.** Continue reference-led
visual refinement and Mac review; retain unfinished priorities3–9 and weapon
families in the current batch ledger.

## 12 November execution update

The owner approved priorities **3–9 from the conversational ranking**, delivered
as five related Mac batches: blood/sweat; weapons/protected poses;
entrances/moonsault; two-sided ladder routes; ladder/table presentation.
See the [current batch ledger](backlog_3_9_2026_11_12/README.md) for validation,
publication and remaining acceptance. New ladder attack variants are deferred.
The older status rows below are historical where superseded by that ledger.

Updated 7 November 2026 at the owner's request: prioritise **impact versus
effort**, with dependencies and validation cost included. This is the current
work order. Original IDs remain stable; they no longer indicate execution order.
The [quality plan](incremental_quality_plan.md) retains the full acceptance
criteria. [Older notes](archive/next_steps_before_2026_11_07_reprioritisation.md)
are historical, including their stale “working tree”, move-count and CI claims.

## Published and remaining acceptance

Latest Mac app: **`253603dfc86b6531549d17cad7b0db3478f3caf0`**, verified
against `mac-latest`, successful [Mac run 43575822777](https://github.com/denhamd2/aegis/actions/runs/43575822777),
`Aegis.zip` 1,026,426,469 bytes.
[Download](https://github.com/denhamd2/aegis/releases/tag/mac-latest).
This includes the Blender prop sources/runtime integration, grip corrections
three cell judge revisions plus wire sampling, the three-round ambulance remodel,
and Kenny’s three-round likeness/identity batch; [current evidence and limitations](cell_judge_2026_11_13/README.md).
Kenny’s three-round likeness/identity batch is published with 78 focused tests
passing; visual acceptance remains open at 4.6/10. Python CI passed, while the
exact-commit broader gameplay suite was still running at publication. The
next unfinished implementation batch is entrances and Cody’s moonsault setup
(original IDs 11–12, 15), followed by two-sided ladder routes and ladder/table
coverage. Owner review may reprioritise the documented likeness gaps.
The bounded cell walking-strip study remains deferred.
Cell likeness remains **8.0/10**, with motion aliasing, close detail and native
Mac performance still open. Earlier release rows below retain their own
validation history; [the current batch ledger](backlog_3_9_2026_11_12/README.md)
records later work and unfinished priorities3–9.

| ID | Published work | Evidence and remaining limits |
| --- | --- | --- |
| Baseline | Latest available main shipped at `492ab0b` | Other-chat uncommitted entrance/camera/trouser/mat-contact work was unavailable. Do not claim it was recovered or shipped. |
| 1 | Crowd fill fades with distance and height independently of ring exposure; `d59d830` | 34 focused cases and isolated shader renders pass. [Evidence](crowd_lighting_2026_11_07/validation.md). Full arena appearance awaits owner Mac review. |
| 2 | Central move flashes removed; Finisher/Fired Up have separate readable positions; `6eab898` | Part of 35 distinct presentation checks; HUD images reviewed at two resolutions. [Evidence](presentation_2026_11_07/validation.md). |
| 3 | Immediate winner celebration, loser remains down, ending replay cancelled; `6eab898` | Same presentation batch. Frequent in-match replay remains available. Owner Mac review remains open. |
| 4 | Attempt-based move/family history and phase-aware working offence; `c805d2d` | In 12 matched seeded games: vertical suplexes 58→54; adjacent big-move repeats 21→15; repeats within the last two big attempts 53→41. Improvement is modest; constrained movesets can still repeat. |
| 5 | Earned close standing Spear opportunities, legal start gates and interrupted-stalk cleanup; `c805d2d` | Running Spears 10→20 in the same comparison; all 20 committed paired moves landed. This sample does not demonstrate missed/countered Spears; approach interruption is tested. |
| 6 | Legal running-attack selection, acceptance-based cooldown, distance-aware return and bounded deceleration; `c805d2d` | Actual-ring rebound and isolated failure/recovery checks pass. Whole-match rope-run success rate is not classified by the probe; rope-run counts were 35→29. |
| 8 | Signature/finisher shake tied to the slam's own contact frame; signature trauma no longer stacked with big-strike trauma; `bf053267` | Focused GdUnit coverage added for contact timing, clamps, 0.75 vs 1.0 trauma, shake OFF and settle-without-pause, but **not executed locally** (no Godot on Termux). CI 42419291422 passed; Mac run 42419291426 succeeded and `mac-latest` points at the commit. Native shake feel awaits owner review. |

IDs 4–6 have **99 passing focused checks** and 12 completed matches per version.
[Evidence and limitations](ai_running_offence_2026_11_07/validation.md).
Full [gameplay CI at `d419e04`](https://github.com/denhamd2/aegis/actions/runs/42403023484)
has passed; gameplay source is identical to the published batch. CI for the exact
published commit [42405043131](https://github.com/denhamd2/aegis/actions/runs/42405043131)
was still running at this update. Publication proceeded on the owner's explicit
immediate-deployment instruction. Do not rerun successful checks without a change
or unresolved risk.

## Prioritised work queue

Impact reflects frequency, visibility and severity across real matches. Effort
is relative: **S** small, **M** medium, **L** large; a large family ships in smaller
batches. These are judgement calls, not measured delivery estimates. Quick wins
are interleaved with larger work so a long animation programme does not delay
all smaller improvements.

| Rank | ID | Work / next deliverable | Impact | Effort | Why here / dependencies |
| ---: | --- | --- | --- | --- | --- |
| 1 | 7 | Faster validation and Mac-only delivery — **implemented in this batch; publication check pending** | Very high enabling impact | M | Reduces the cost of every later batch. Profile setup separately; use safe fixtures and affected-subsystem selection, retain full regressions for broad changes, audit Web dependencies before retiring publishing. Preserve Mac builds/shared code. |
| 2 | 13a | Punch corrections: first active move-family batch — **source re-keyed and pose-audited in this batch; regeneration and focused tests pending on Mac** | Very high | M per batch; L overall | Seen throughout every match. Start with the most visible joint/contact failures against available Fight Forever footage; review both bodies, contacts and recovery. Jab, cross, gut punch, Bionic Elbow and dropdown uppercut now meet the phase, contact-height, gaze, reach and mat-clearance criteria; the Bionic Elbow is elbow-led at head height with the measurement tool extended to measure the elbow. See [validation](punch_corrections_2026_11_08/validation.md). |
| 3 | 8 | Existing impact shake — **follow-up published in `fb01d89`** | High | S–M | Strong broadcast payoff for limited scope. Trigger only at actual impact, respect settings, stay brief, and never pause animation. |
| 4 | 9–10 | Weapon retrieval and extinguisher pickup/effect lifecycle — **implemented in this batch; tests and renders pending on Mac** | High in weapon matches | S–M each | Related prop-interaction batch: distinct reserved apron locations with cleanup; remove pickup cloud and keep spray confined to the authored action. Apron claims are 1.1 m apart, released on completion/interruption/cancellation, with a `APRON TAKEN · STEP ALONG` HUD cue and a visible AI step to a free lane; the extinguisher's Cloud root is hidden, foam leaves the muzzle, the horn aims with a controlled tank-down roll, the prop appears in her hand at the grab and is carried back before being put away. See [validation](weapons_2026_11_08/validation.md). |
| 5 | 19–20 | Blood default and bounded sweat assessment/tuning | Medium | S + S–M | Cheap surface/settings batch before larger reauthoring. Raise blood one capped step while preserving saved choices/OFF. Compare early/mid/late sweat first; tune modestly only if justified and avoid uniformly glossy skin. Do not hold the blood fix for an open-ended material overhaul. |
| 6 | 14 | Cross Rhodes attacker/defender correction | High | M–L | Cody's finish is a prominent identity moment. Reauthor hold, rotation, descent, impact and release together against the existing reference. |
| 7 | 13b–c | Kicks, then lariats, in separate family batches | Very high | M per batch; L overall | Completes the frequent core offence after the first punch pass and quick fixes. Cover every active variant; do not mark ID 13 complete after punches alone. |
| 8 | 18 | Bounded protection for designated presentation poses | High | M | Shared behaviour needed before ladder-top presentation. Clear protection on cancellation/state exit; no indefinite invulnerability. |
| 9 | 11–12 | Cody elbow/WHOA pyro, then all three entrance walks | High | M each | Related entrance-authoring work. First correct Cody's elbow and single pyro cue, then audit Roman/Cody/Kenny stage, ramp, turns, strides and contacts. Preserve approved camera direction. Ship sub-batches if the walk audit grows. |
| 10 | 15 | Cody's rope-pose/moonsault arm deformation | High when used | M | Visible mesh defect in an existing move. Validate the real Cody mesh, hands and complete rope-pose blend. |
| 11 | 16 | Two-sided ladder geometry and climbing routes | High in ladder matches | M | Functional interaction gap; **owner, 9 Nov: "add rungs to the other side of the ladder"**. Both approaches, rungs, hands/feet, ascent/descent and safe occupancy must work before final ladder coverage. |
| 12 | 17 | Ladder-top pose/close coverage and table-impact coverage | High in set pieces | M | **Owner, 9 Nov: "a camera close-up of a wrestler to pose at the top of a ladder".** Depends on 16 for both climb routes and 18 for bounded poses. Frame actual impacts with both bodies and props readable, then return to gameplay. |
| 13 | 21 | Kenny likeness: proportions, face, hair, materials | High | L | Distinctive character payoff but substantial asset/retargeting risk. Use supplied references, preserve rig compatibility and review neutral plus animated poses. |
| 14 | X1 | Roman/Cody body-morph and attire-fit audit | High | M–L | Carried forward from the older backlog. Compare supplied silhouettes; make narrow mesh/weight edits. Remeasure paired grips, contacts and collision assumptions before any rig-dimension change. |
| 15 | X2 | Skin/attire and canvas/apron polish | Medium | M | Carried-forward surface work. Judge under the revised accepted lighting. Fold narrow changes into 20/21/X1 when they share materials or real-mesh validation. |
| 16 | X3 | Broader ladder offence and safe interruption variants | Medium | M–L | Existing ladder dive/laid-out slam are implemented, but need native review. After 16–18 and that review, author the remaining ladder swing/interruption variants rather than replacing the established spot. |
| 17 | 22 | Complete the remaining Fight Forever reference catalogue — **plan drafted; roster-fit moves are all built (29/29), 119 remain for other wrestlers** | High breadth, lower immediate return per move | L programme; small family batches | Reconcile actual motion/contact/gameplay completion, then prioritise current-roster fits and shared families. Audit overlapping catalogue entries during 13/14/15 to avoid duplicate work. Include both roles, contacts, recovery and wiring; deploy every completed batch. See [the FF plan](ff_remaining_plan_2026_11_08.md). |

All original IDs 7–22 remain in scope. **13a/b/c** are delivery slices of ID 13;
**X1–X3** preserve older open work and do not silently expand the roster or the
established move-reference catalogue. Item 22's resources/`is_built()` flags alone
do not establish completed, correct animations; the current catalogue contains 146 entries. The measured ledger is **27/146 built (19 authored `ff_*` clips plus 8 mapped existing moves), all 29 roster fits built, 119 remaining for other wrestlers**; replace the historical “3 of
146 built” claim with the audited per-move completion ledger in
[the FF plan](ff_remaining_plan_2026_11_08.md) before quoting completed-animation progress.

## Parallel acceptance and follow-up track

These remain open across the queue; they do not block publication solely because
the cloud host lacks a GPU or target Mac.

| Follow-up | Impact / effort | Next evidence / response |
| --- | --- | --- |
| Exact-commit CI and demonstrated regressions | Critical / inspect S; fix depends on cause | Record the outcome of CI 42405043131. Any demonstrated regression or owner-reported blocker takes precedence over the ranked feature queue. Do not treat pending CI as passed. |
| Native M1 / 16 GB performance | Critical / M measurement, fixes sized from findings | Measure the 16.67 ms frame budget, spikes and memory pressure in crowds, ladders, tables, blood and effects on target hardware. Cloud timings are not Mac performance evidence. |
| Owner Mac appearance and pacing review | High / S–M review, fixes sized from findings | Review crowd depth/front rows/ring exposure against the three AEW stills; HUD, finish, entrances/handoffs, strike flow, Spear/rope outcomes, skin, arena and motion blur. Use owner feedback to reprioritise concrete defects. |
| IDs 4–6 follow-up if required | High / S–M per diagnosed issue | Repetition remains possible and some matchups can worsen despite aggregate improvement. Mean seeded duration was 439.96→449.81 seconds. Verify perceived pace and failed approaches; distinguish intent, accepted attempts and landings. Do not raise probabilities to mask navigation/contact failures. |
| Ladder-aerial visual acceptance | High in set pieces / M | Numeric clearance checks exist; inspect both real bodies at normal speed and sampled frames, then tune without weakening clearance/impact/recovery checks. Links to 16/17/X3. |
| Wider environment/reference acceptance | Medium–high / M | Preserve applicable New.png arena/stair/LED/steps work while prioritising the newer AEW crowd-lighting references where they conflict. Integrate skin/canvas findings with X2. |

## Work retained as completed or historical

The previous selling backlog is closed: body-part down sells, side-aware head and
uppercut reactions, contact checks, damaged-leg/arm presentation, face-first and
spin-out knockdowns, pain vocals, selling through actions and facial pain shapes.
See [selling plan](selling_plan.md). No new selling defects are inferred here.

Older notes also record implemented crowd audio/chants, weapon grips/pickups and
weapon-family swings, NHB retrieval/use, set-piece impacts, ladder setup/climb/dive,
entrance/handoff paths, FF coverage, the moves already authored, and crowd/arena
material work. Preserve these systems; current numbered defects and native-review
items identify what still needs improvement. The old clip-authoring digest failure
is not carried forward as a current failure: the full gameplay CI at `d419e04`
succeeded. Investigate it again only if a current check fails. Likewise, an older
unfinished/crashed strike probe is historical diagnostic evidence, not proof of a
current gameplay fault; the newer seeded comparison completes all its matches.

## Delivery and validation rules

Keep one focused commit per change and share validation/Mac deployment across a
small related batch. Batch boundaries follow subsystem and validation overlap,
not an arbitrary item count. Confirm the released tag matches the batch commit
before starting the next batch. Documentation-only updates do not need another
Mac build or expensive regression run.

Use mannequin checks for logic, real rigs for deformation/retargeting, full arena
captures for presentation, and native M1 measurements for performance claims.
Author motion at its source and regenerate dependent resources; keep 60 Hz
simulation, Fight Forever pacing and the approved entrance direction. Preserve
existing in-match replay settings. Use seeded comparison and full regressions for
broad gameplay/animation changes; select focused checks for narrow changes and
record pending checks honestly when immediate deployment is requested.
