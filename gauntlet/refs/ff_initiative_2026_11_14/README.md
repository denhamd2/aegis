# Fight Forever gameplay initiative — current audit and execution

Owner-approved implementation initiative,14 November2026. Full scope: [owner request](owner_request.txt). Existing Kenny work
is preserved and unpublished; gameplay changes are staged independently.

## Source and evidence boundary

Reference: https://github.com/peek6/AewFFCustomUProj at
`2eef5e9c86cb1982eb3ea57ce0a6b43729a9e2a7`. Inspected the requested synchronisation,
montage/chain, reversal, moveset, referee, foot-IK, camera and damage headers.
`ELSSSyncMotion.cpp` contains empty methods/default returns. These are interface
clues, not verified Fight Forever algorithms. No proprietary animation/assets
or implementation code is imported.

Useful concepts: one sync owner/shared origin with explicit setup/release;
height-aware roles; category-specific reversal opportunities; referee start,
loop/count/release phases; presentation camera tracking of both actors. Aegis
already implements much of this through its existing ownership/data systems.

## Current baseline (source/runtime inspection)

- Godot4.6.3, Forward+, Jolt; fixed60Hz, WrestlerFSM and GrappleRig authority
  retained. Paired origins, role retargeting, simultaneous pose start, walk-in,
  separation, PairedFit/Contacts and FootPlant already exist. Quality remains
  incomplete: previous exact published CI has pair-clearance failures.
- Runtime FFMoveLibrary.progress() is **27/146 resource/clip flags**,119 not
  flagged. This is not27 visually accepted moves. The visual ledger has pending
  sheets and explicit failed OWA/chokeslam/Samoan Drop quality reviews.
- OWA MoveDef currently has80 startup,6 active,46 recovery frames. Do not call
  that a measured footage match without rechecking the authored impact beat.
- MatchFlow phases, identity-aware MovePlaybook, stamina, repetition history
  and AI reversal logic already exist; extend rather than replace them.
- Historical docs claiming no reversals are stale: controller actively calls
  _read_reversal/_take_reversal and uses strike_parry. The older paired-counter
  removal was for unreadable cancellation/animation; separate modern grapple,
  directional and special counter coverage still requires audit/authoring.
- Pin/referee count schedules and rope breaks already have measured data and
  existing logic. Preserve timings while auditing positioning/animations.
- Published full CI at253603d:1318cases,3failures,2errors,5orphans; known prop,
  pair-clearance, realism-cue and fire-material categories. Not green.

## Prioritised roadmap integrated with the existing backlog

| Order | Deliverable | Acceptance/dependency |
| --- | --- | --- |
| 1a | Deterministic paired fallback clock | Real begin/finish duration identical across time scales; ownership restored; no clip changes. Implemented below. |
| 1b | Paired lifetime, shared-clock and interruption audit | Both slot orders; early/late exit, cancellation, entry/recovery, root/pose phase agreement. Keep GrappleRig owner. |
| 1c | Contact/planting correction | Reproduce current Cross Rhodes/inverted-drop failures; fix source choreography/contact stage, not tolerances; actual two-role sheets and expert review. |
| 2 | Existing signature/finisher families | OWA first, then Tiger Driver/V-Triggers/Snap Dragons/Cross Rhodes and configured finishers. Source Blender60fps, scoped bakes, eight-dimension QA; per-move sheets mandatory. |
| 3 | Reversal restoration/extension | Audit current strike parry first; distinct grapple/directional/special pairs with real windows, failed reactions and seeded balance checks. New request supersedes historical cut as future scope. |
| 4 | AI psychology | Fixed Cody/Roman slot-order seeds, then Kenny; measure attempts/landings/repetition/opportunities and completions before tuning. |
| 5 | Referee/near-falls | Pose/position/count/release and collision avoidance, preserving existing measured count schedule. |
| 6 | Library expansion | Reconcile playable+authored+visually accepted statuses; family batches after existing quality gate, no completion inflation. |
| 7 | Broadcast polish | Existing impact cut/audio/shake/cameras; no global hit-stop or parallel camera architecture. |

Kenny likeness, unfinished entrances/moonsault/ladder routes/cameras and remaining
prop work remain in the backlog; this owner request prioritises gameplay.
Blender/complex choreography work requires the existing specialist. Its current
usage-limit interruption is recorded; no paid fallback has been activated.

## First implemented batch: fallback simulation clock

Before: a fallback move used an idle wall-clock timer while both bodies were
suspended. The real-path regression completed in29physics ticks at normal speed
and36 at half speed, versus the authored30 (entry+7move frames).
After: wait for7 physics-frame boundaries, then release through the existing
finish path. Both scales complete on tick30, with physics restored on both
bodies. The normal authored-animation path is unchanged.

**19 focused cases pass**, zero errors/failures/orphans: actual fallback timing,
placement and existing reversal-window/reversal tests. Released-code negative
control fails the same regression. Reports are adjacent. This is a timing/logic
fix, not a claim that any animation is now visually corrected or AAA.
**24 additional replay/catalog cases pass**, including actual scene recording/playback;43 total distinct focused cases pass. This is not a full-suite green claim. Owner approved publication. Commit `9c1976b56ed30830bc01c4ff93424d4beb78a74d`
is pushed and Mac run43615191048 succeeded; exact mac-latest commit and uploaded
Aegis.zip1,026,426,701 bytes verified. See mac_publication.json. Native M1 frame pacing remains unverified.

## Next independently reproduced defects

Role retargeting:12 headless cases (both slots,yaw0/.85,lift1/1.12/1.5)
show slotA correct but slotB applies lift and defender pitch filtering to the
wrong roles. At lift1.12: attacker/defender position errors.024/.120m; angular
errors.30/.80rad. Use the existing authored-role argument after path rewriting.
Separate probes reproduce shared animation-library contamination between rigs
and surviving bodies left suspended after rig teardown. Fix these in bounded
steps with isolation/cancellation regressions, not a new paired architecture.

Fresh source contact audit: Cross Rhodes facelock median.094m/p90.146m,
16in-reach/222out. Inverted drop body overlap.090m at1.25s, attacker pelvis-spine
against defender left calf-foot; correct the catch/load, not the later apex.
OWA source beat40 at30Hz exports tick80=1.333s; recipe2.2s andMoveDef agree.
Local raw reference footage is missing; remeasure reference before any retime.
