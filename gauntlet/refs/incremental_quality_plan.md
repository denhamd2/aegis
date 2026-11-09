# Aegis: incremental quality and gameplay improvements

Owner-approved plan, restored from chat on 7 November 2026. The owner subsequently requested an impact-versus-effort reprioritisation.
The [current backlog](next_steps.md) now controls execution order, including
older open follow-ups; this plan retains stable IDs and acceptance criteria.
Both supersede older handoff ordering where it conflicts.

## Goal and release process

Deliver smoother, more varied wrestling with Fight Forever’s gameplay pace,
stronger broadcast presentation, and realistic characters and lighting.
Target **60 fps on a MacBook M1 with 16 GB memory**.

The original prerequisite was to release the uncommitted entrance, camera,
trouser and mat-contact changes after their targeted checks. Those changes
were not present in this fresh clone. The owner subsequently instructed
**“ship the latest”**: use the latest `main` as the baseline. At the initial baseline verification on 7 November,
`main` and the published `mac-latest` release both referenced
`492ab0b049a875e29ce2742232d39733645b9046`; the release contains `Aegis.zip`.
This establishes publication of that baseline, not recovery of another
workspace's uncommitted changes or native M1 visual/performance acceptance.

Complete outstanding work in the ranked order in [the backlog](next_steps.md). **Owner update: keep focused
commits and group related priorities into small batches, with one validation
and Mac deployment per batch.** The numbers below remain stable scope IDs, not current priority ranks.
Verify that the published Mac release references the batch commit before
starting the next batch. Published batches are 1, 2–3 (HUD/ending), 4–6 (AI/running offence)
and 8 (impact shake).
The backlog ranks the remaining batches by impact, effort and dependencies.
Update the backlog with completed work and remaining limitations. Large move
families and the remaining catalogue ship in separately validated small batches.

**Owner update, 7 November:** deploy the validated changes for review on the
owner's Mac, then continue the priorities. A cloud GPU/full-arena comparison is
not a publication prerequisite. Keep focused correctness checks and available
component renders; mark native appearance and M1 performance as awaiting owner
review. Continue after verifying each published Mac commit without waiting for
that review unless new feedback or a demonstrated fault changes the scope.

## Scope and acceptance by stable ID

Effort is relative: **S** small, **M** medium, **L** large.

| ID | Change | Effort | Acceptance |
| ---: | --- | :---: | --- |
| 1 | **Crowd lighting** | M | Match the [three AEW references](crowd_lighting_2026_11_07/README.md): bright ring, readable front rows, progressively darker seating and shadowed upper stands. Tune crowd emission and spill independently of ring exposure. |
| 2 | **HUD cleanup** | S | Remove central white move-name flashes. Give the flashing Finisher indicator a dedicated readable position that cannot overlap wrestler names. |
| 3 | **Post-match ending** | S | Go directly from the finish to the winner’s celebration. The loser remains down through the celebration; no ending replay or recovery into combat. |
| 4 | **Move variety and psychology** | M–L | Reduce vertical-suplex dominance and repeated moves. Use the existing match phases, wrestler identity, damage, position and stamina to select coherent offence. |
| 5 | **Roman’s Spear** | M | Repair the existing setup and running-finisher path. Roman attempts the Spear when it is earned and a legal opportunity exists; attempts may still miss or be countered. |
| 6 | **Rope-running attacks** | M | A successful rebound continues into a suitable running attack when the opponent is in range. Invalid opportunities lead to a natural recovery or repositioning rather than an abrupt stop. |
| 7 | **Faster validation and Mac-only delivery** | M | Profile the suite, reduce repeated setup and introduce affected-subsystem test selection. Retire Web publishing after checking dependencies; retain native Mac builds and relevant shared code. |
| 8 | **High-impact camera shake** | S–M | Repair and tune the existing shake system rather than adding another one. Brief, restrained shake occurs at actual signature/finisher impacts, respects camera settings, and never freezes animation. |
| 9 | **Weapon-retrieval separation** | S–M | Reserve apron retrieval locations. Two wrestlers choose different available locations; reservations clear on completion, interruption or cancellation. |
| 10 | **Extinguisher pickup artefact** | S–M | Remove the polygonal cloud when Aubrey initially picks up the extinguisher. Spray appears only during its intended action and remains correctly positioned. |
| 11 | **Cody’s entrance elbow and pyro** | M | Correct the elbow through the stoop and transitions. Move the relevant pyro cue to the WHOA moment, without duplicate firing when he first appears. |
| 12 | **All three entrance walks** | M | Audit Roman, Cody and Kenny across stage, ramp, turns and transitions. Match travel speed to stride, maintain planted contacts and correct sliding or floating. |
| 13 | **Punches, kicks and lariats** | L | Review every active variant against available Fight Forever footage. Correct knee/elbow direction, anticipation, contact, follow-through and recovery. Release corrections in small move-family batches. |
| 14 | **Cross Rhodes** | M–L | Reauthor both wrestlers’ motion against the existing Fight Forever reference: correct hold, rotation, descent, impact and release. Review both bodies together at normal speed and in sampled frames. |
| 15 | **Cody’s moonsault setup** | M | Fix arm deformation during the rope pose and transition into the top-rope moonsault. Validate the real Cody mesh, hand placement and full animation blend. |
| 16 | **Two-sided ladder climbing** | M | Provide rungs and usable climbing routes on both sides. Align approach, hands, feet, ascent and descent; handle occupancy safely. |
| 17 | **Ladder and table camera coverage** | M | Add a bounded ladder-top pose and close camera coverage. Frame table breaks around the actual impact, keeping both bodies and the table readable before returning to gameplay coverage. |
| 18 | **Uninterrupted poses** | M | AI opponents respect designated presentation poses. Protection lasts only for the authored sequence and clears on cancellation or state exit; it does not create indefinite invulnerability. |
| 19 | **Blood adjustment** | S | Increase the default blood setting by one existing scale step, capped at its maximum. Preserve saved user choices and the OFF setting. |
| 20 | **Sweat assessment and tuning** | S–M | Compare early-, middle- and late-match renders. Increase exertion sweat modestly where it improves realism, using existing masks and materials without making skin uniformly glossy. |
| 21 | **Kenny’s likeness** | L | Improve body proportions, facial structure, hair silhouette and material response against the supplied character references. Preserve rig compatibility and review neutral and animated poses. |
| 22 | **Remaining Fight Forever moves** | L | Reconcile the existing reference catalogue against genuinely completed animations. Implement every remaining catalogued move in small batches, including both roles, contacts, recovery and gameplay wiring. Deploy each completed batch. |

## Gameplay and animation implementation

- Extend the existing AI and match-flow systems. Record attempted and landed
  moves so repetition can be diagnosed separately from failed setups.
- Exclude recently used power moves when another appropriate move is legal;
  penalise overused move families across a longer history. Keep fallback choices
  legal when positioning or damage limits the available moves.
- Preserve deliberate sequences such as combinations and repeated body-part
  work. Escalate larger offence through the match phases, with recovery, covers
  and breathing space between bursts.
- Investigate finisher and rope-run failures through selection, navigation,
  state transitions and contact. Fix the failing stage instead of simply
  raising selection probabilities.
- Author animation corrections at their source and regenerate dependent
  resources. Validate both attacker and defender, root motion, joint direction,
  contacts, mat clearance and transitions.
- Use the existing move definitions, camera settings and material settings.
  No new public API is planned; any required additions remain backward compatible.

## Validation and performance

Use the least expensive test that can establish the result:

1. **Headless mannequin checks** for AI decisions, repetition, timing,
   contacts, joint limits, mat clearance and state transitions.
2. **Lightweight real-character renders** for retargeting, clothing,
   deformation, face and body likeness.
3. **Full arena captures** for lighting, camera composition, effects and
   broadcast presentation.
4. **Native M1 measurements** for performance claims. Cloud or software-rendered
   results cannot establish Mac frame pacing.

For AI changes, replay a fixed set of Cody–Roman matches in both slot orders,
then cover Kenny’s matchups. Compare move distributions, repeated sequences,
finisher opportunities and attempts, rope-run outcomes and match completion.

For test optimisation, measure suite and setup costs first. Reuse safe fixtures,
avoid loading a full arena for pure logic, separate report destinations for
concurrent runs, and retain complete regression runs for broad animation or
gameplay changes.

Measure against the **16.67 ms frame budget**, including frame-time spikes,
memory pressure and demanding scenes with crowds, ladders, tables, blood and
effects. Keep animation updates consistent with the established simulation
timing. Report native performance as unverified until measured on the target
hardware.

## Permanent project rules

These conventions are summarised in the root `AGENTS.md`:

- Rank multiple requests by impact, effort and dependencies.
- Keep focused commits; validate and deploy related batches incrementally.
- Treat M1/16 GB performance, smooth animation, Fight Forever pacing and
  broadcast quality as continuing requirements.
- Use expert game-design judgement and reference-led animation, modeling,
  lighting and materials work. Do not claim personal employment or credits
  on Fight Forever or WWE 2K.
- Read only relevant files and skills, batch independent inspections, retain
  concise handovers, and rerun expensive checks only when changes or unresolved
  risks justify them.
- Investigate official guidance applicable to GPT‑6.1 Sol before adding
  model-specific practices; record supported recommendations separately from
  project measurements. Do not infer model-specific advice from its name.
- Preserve the approved entrance direction: fewer cuts, front/side walking
  coverage, a slightly below-waist lens, wide entry and handover coverage, and
  close poses and faceoff.

Defaults: Mac is the delivery platform; only the ending replay is removed;
existing in-match replay settings remain applicable. The remaining-moves
scope is the established Fight Forever reference catalogue.

## Release ledger

| Release | Status | Validation, publication and remaining limitations |
| --- | --- | --- |
| Baseline | Published | `492ab0b049a875e29ce2742232d39733645b9046` verified against `mac-latest` on 7 November 2026. Other-chat uncommitted changes were unavailable; owner chose latest main. Native M1 performance remains unverified. |
| 1 | Published for owner Mac review | `d59d830dc51b7ec4bccd89dbd0e0167f7e3f0402`: Mac workflow succeeded; `mac-latest` tag SHA verified and `Aegis.zip` present (982,707,267 bytes). 34 focused cases and both shader renders pass. Arena appearance and M1 performance await owner review. |
| 2–3 | Published for owner Mac review | HUD cleanup and direct winner celebration; focused commits `f5d64bf` and `14e90c0`. 35 distinct focused checks pass; HUD renders reviewed at 1280×720 and 640×360. Mac workflow 42384661693 succeeded at `6eab898999edc72821a774ffb4518da0dea5150c`; exact tag SHA and `Aegis.zip` (982,707,469 bytes) verified. Native appearance/performance await owner review. See [validation](presentation_2026_11_07/validation.md). |
| 4–6 | Published for owner Mac review | Move variety/psychology, earned Spear opportunities and rope-running follow-through. 99 focused cases pass; baseline and final seeded matrices each complete all 12 matches. Published `c805d2d551a70e566262ba6ac05ea6f4370e9c4a`; Mac run 42405043123 succeeded, exact tag SHA verified, `Aegis.zip` present (982,718,501 bytes). Full gameplay CI at `d419e04` has since passed; exact published-commit CI 42405043131 was still running at the backlog update. Publication proceeded on the owner’s immediate-deployment instruction. See [validation](ai_running_offence_2026_11_07/validation.md). Native appearance/performance await owner Mac review. |
| 7 | Implemented; publication check pending | Affected-suite selection with conservative full-suite fallbacks, a JUnit suite profiler wired into CI, Godot setup skipped when no suite is affected, three Python-only jobs merged into one checkout, and Web publishing retired after a dependency audit. 28 selector/profiler self-tests pass locally. Godot, CI timing and native performance were not run from Termux. See [validation](ci_2026_11_08/validation.md). |
| 8 | Published for owner Mac review | Slam shakes on the move's own contact frame rather than the finisher's 60% constant; a big signature blow takes the larger trauma cue instead of stacking to the finisher ceiling; the `signature_*` fallback matches `_arm_impact_shake`. Published `bf053267128f95bdc0420521d3756f1d30b1e530`; CI 42419291422 passed, Mac run 42419291426 succeeded, exact `mac-latest` tag SHA and `Aegis.zip` (982,718,615 bytes) verified. Focused tests were added but not run locally (no Godot on Termux). Native feel awaits owner review. |
| 13a | Source re-keyed and pose-audited; build and visual validation pending | Jab (18 f / 30 ticks, contact 6), cross, gut punch, Bionic Elbow and dropdown uppercut meet the combat-timing phases, keep their contact ticks, and are audited with a bpy-free rig solver: gaze within 9° at contact, contact geometry within 2.3 cm of the stored volumes, cross lead hand held at 0.54/0.50/0.46 m, gut punch rising 0.16 m, Bionic Elbow elbow-led at 1.497 m, uppercut upright at 1.600 m, all poses within PoseLint limits. `measure_contact_offsets.gd` now measures `lowerarm_*` tips so an elbow-led clip reports the elbow; only the Bionic Elbow flips, its reach becomes 1.068 m. **No GLB or strike bake was regenerated here** — this workspace has no Blender/bpy or Godot binary. Mac steps: regenerate `wrestling_clips.glb`, import, rebake `strike_clips.tres`, re-run the offset tool, run the focused gates and render the five clips. See [validation](punch_corrections_2026_11_08/validation.md). |
| 9–10 | Implemented; tests and renders pending | Apron retrieval spots are reserved 1.1 m apart in a static claim table, refused while occupied, chosen clear by the AI, and released on completion, interruption, cancellation and node exit; the player sees `APRON TAKEN · STEP ALONG` when the spot is claimed. The extinguisher's built-in polygonal Cloud root is hidden; foam leaves the horn's muzzle marker; the horn is aimed onto the man and rolled until the tank stands up (independent check: horn within 0.02°, tank-up +0.966 against the old −0.922 at one holder yaw); the prop stays hidden until the grab, is carried through the return and hidden at her spot. `gdlint` parses every edited file; the two new focused tests and the fire/carry renders await the Mac. See [validation](weapons_2026_11_08/validation.md). |
| 9–22, X1–X3 | Ranked / open | See the [impact-versus-effort backlog](next_steps.md) for current ranks, related batches, dependencies, legacy follow-ups and native acceptance work. Original IDs remain stable; the old numeric order is superseded. |
