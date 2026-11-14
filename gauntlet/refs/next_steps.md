# Aegis prioritised backlog

## Current status: Kenny batch published; visual acceptance remains open

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
| 3 | 8 | Existing signature/finisher impact shake — **published in `bf053267`** | High | S–M | Strong broadcast payoff for limited scope. Trigger only at actual impact, respect settings, stay brief, and never pause animation. |
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
