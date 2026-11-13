# Priorities 3–9: implementation and delivery

Owner-approved plan, 12 November 2026. These numbers refer to the conversational
backlog ranking, not the original quality-plan IDs. The owner explicitly permits
this Codex session in place of the unavailable pinned OpenCode models, without
external paid services. Existing ladder moves first; new variants remain deferred.

## Batch ledger

| Batch | Original IDs | Scope | Status |
| --- | --- | --- | --- |
| 1 | 19–20 | Blood default and sweat assessment | Published at `207e8dc` |
| 2 | 9–10, 18 | Weapon interaction lifecycle and bounded presentation protection | Published at `cbcecdb` |
| 3 | 11–12, 15 | Entrances and Cody moonsault setup | Pending |
| 4 | 16 | Two-sided ladder routes and occupancy | Pending |
| 5 | 17, X3 | Ladder/table coverage and existing ladder move corrections | Pending; new attack variants excluded |

Each batch gets focused commits, relevant checks, a main push and a verified
Mac release before starting the next. Preserve concurrent strike/Cross Rhodes
work. Existing unrelated CI failures remain explicit; no lowered assertions.

## Batch 1

Blood's startup default increases from 4 to 5 on the existing 0–10 scale.
Explicit menu/CLI choices retain their values, including OFF and the maximum.
This is a constant change, not an increment on startup or a settings migration.
The existing app has no persisted blood-setting file: menu choices last for the
session. This batch does not introduce a separate settings system or claim to
preserve a nonexistent saved preference store.

Sweat assessment and capture limitations are recorded in [sweat.md](sweat.md).
Native M1/16 GB performance and full-arena appearance remain owner-review items.

Godot 4.6.3 / gdUnit4 6.2.1: **26/26 checks pass**, zero failures/errors:
`test_blood`, `test_skin_look`, `test_hit_flinch_and_life`.
See [JUnit report](batch1-tests.xml). Project import completed; only sandbox
network socket warnings were emitted. No native performance claim is made.

## Batch 1 publication

Mac run [43313142103](https://github.com/denhamd2/aegis/actions/runs/43313142103)
published `207e8dc49bb7fb481618cea49df88b5ee666b424`; `mac-latest` points to
that exact commit and `Aegis.zip` is present (988,666,720 bytes).

## Added owner scope: realistic props

The owner requested more realistic modeling and texturing for all weapons,
the casket and ambulance. Delivery order: **frequently used weapons first**,
then casket and ambulance, followed by the remaining weapon families. Preserve
M1 budgets, marker contracts, gameplay scale and existing authored interactions.
AAA realism is an art target, not a verified quality or performance claim.
New ladder attack variants remain deferred; original priorities 3–9 remain active.

## Batch 2 validation

Authored taunts are protected only for their own timed sequence, with cleanup
on state exit and death. Spear stalking remains interruptible. AI now waits
for protected poses and rummaging even when armed. Melee hits during these
sequences award neither damage nor hit momentum. Existing Ladder/TLC prize
retrieval remains interruptible.

Focused weapon/AI/selling checks: **53/53 pass**, zero errors, failures or
orphans ([report](batch2-tests.xml)). Existing weapon/extinguisher/fire crew
baseline: **49/49 pass** ([report](weapon-baseline.xml)).
Full regression: **1310 cases / 157 suites**, 3 failures, 2 errors, 5 orphans
([report](batch2-full.xml)), matching released-main failure categories:
prop handoff overlap, paired clearance, realism lighting cue and fire material
lookup. These are not labelled green; no assertion was relaxed.

Concurrent `a89ca90` strike/Kenny work arrived before publication and was
integrated without conflicts. Import passed and all **53 focused cases passed
again on the merged source** ([report](batch2-merged-tests.xml)). The earlier
1310-case report predates that integration; it is not exact-merged-commit proof.

13 November: owner explicitly permits GPT image generation for texture rendering
when useful. Existing procedural texture work remains valid; generation is
optional and must be validated after UV/material integration. Delivery preference
confirmed: frequently used weapons, then casket/ambulance. Original unfinished
entrance, moonsault, ladder-route and camera batches remain in scope.

Batch2 publication verified: `mac-latest` commit
`cbcecdb41fb187b9dab9a5a2bb3f38758dabfc49`, Mac run43388050947,
`Aegis.zip`1,053,356,953bytes. This includes the concurrent strike/Kenny source.

First frequent-weapon art slice: chair, table, ladder source and regenerated
assets, [comparison and checks](../weapon_realism_2026_11_13/validation.md).
Subtle hardware/material refinement, not finished AAA acceptance. Casket,
ambulance and remaining weapon families stay open. Grip failures on eight paths
reproduce with original assets and remain a separate corrective follow-up.

## Blender requirement and current batch

Owner13November: steel cage, Hell in a Cell, ambulance and casket must all be
modeled in Blender. Native editable sources, exports and runtime integration
are now implemented; [validation and visual limits](../blender_props_2026_11_13/validation.md).
This is not completed AAA acceptance or verified WWE2K visual parity.
The all-weapon grip gate now passes without tolerance changes. Publication
verification is recorded below; older entries describe earlier releases.

Original batches3–5 remain open: entrances/moonsault, two-sided ladder routes,
and ladder/table presentation. Remaining weapon families and further prop
visual refinement also remain open; the new source pipeline does not close them.

## Cell judge refinement

Initial Blender batch published at `784d9b7`, verified mac-latest and Mac run
43482869123; Aegis.zip1,055,710,877bytes. Three subsequent cell-only judge loops
against confirmed silverWWE2K25 references and owner construction photos improve
5.3→6.4→6.8→8.0/10. [Evidence](../cell_judge_2026_11_13/README.md).
Final source31,338triangles/2materials;35affected checks pass. New refinement
batch published at `ae0cef36edaf3db7e64836e72529a85c78ba3da9`:
[Mac run43499679118](https://github.com/denhamd2/aegis/actions/runs/43499679118)
succeeded, `mac-latest` resolves to that exact commit, and `Aegis.zip` is
1,056,076,110bytes. Further fidelity work remains open;10/10 not reached.
Exact-commit gameplay CI43499679216 was still running at this receipt;
35/35 focused checks passed locally. Native appearance and performance await
owner Mac review.

Cell wire sampling follow-up: [evidence](../cell_judge_2026_11_13/wire_filter/README.md).
Selective motion and MSAA-off door/roof-state review supports shipping with
notes; overall likeness stays8.0/10. Exact-commit publication pending.
