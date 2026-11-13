# Priorities 3–9: implementation and delivery

Owner-approved plan, 12 November 2026. These numbers refer to the conversational
backlog ranking, not the original quality-plan IDs. The owner explicitly permits
this Codex session in place of the unavailable pinned OpenCode models, without
external paid services. Existing ladder moves first; new variants remain deferred.

## Batch ledger

| Batch | Original IDs | Scope | Status |
| --- | --- | --- | --- |
| 1 | 19–20 | Blood default and sweat assessment | Published at `207e8dc` |
| 2 | 9–10, 18 | Weapon interaction lifecycle and bounded presentation protection | In progress |
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
