# Selling: what we have, what 2K and real wrestling do, and the plan

The owner, 3 Nov: "Do we have anything in the backlog to improve selling by the
wrestler being attacked? If no, research what needs to be done."

**Backlog check on 3 Nov.** No selling-specific item was open then. The last
selling work was listed in `next_steps.md` ("every hit ... is sold to its size
and to how much he has left") and `match_aaa_plan.md` §3 (`Sell_Head`/
`Sell_Gut`, `FLURRY_STUN_AT`).
`animation_gap.md` Phase 4 names the in-between selling that `SellClutch`
covers. The gaps below became the selling backlog; their statuses are current
through the 6 Nov selling closeout.

## What the game does today

| Layer | What it does | Where |
| --- | --- | --- |
| Hit size | Five sizes: LIGHT, MEDIUM, HEAVY, KNEE, DOWN. Chosen by the damage taken and the health left. Reaction 20–72 ticks. | `WrestlerController.sell_tier`, `SELL_REACT_TICKS` |
| Where he was hit | Head by strike hand, uppercut, or gut: mirrored `Hit_React_Head`, `Hit_Uppercut`, `Hit_React_Torso`, and heavy variants. Then a matching head or gut sell. | `StrikeRecipes.reaction_for`, `_play_hit_reaction` |
| Every blow | An additive flinch away from the hitter, plus hit-stop. | `HitFlinch` |
| A string of blows | Rocked into `Stunned_Sway` on the third blow inside a sell. | `FLURRY_STUN_AT` |
| Knockdown | Back, lariat, face-first and spin-out falls. The down sell follows the injury zone, with staged get-up and groggy recovery. | `_bump_down`, `_go_down`, `groggy_for` |
| After big moves | Additive sell profiles: suplex, Cross Rhodes, table rebound, wire, tacks, ladder. | `ImpactSell` |
| Between exchanges | His hand goes to the most-hurt part: head, ribs, knee or shoulder. | `SellClutch` |
| Lingering damage | Damaged legs limp in locomotion; a hurt arm hangs. The trunk keeps showing pain through taunts, counts and climbs. | `LimbDamageSell`, `SellClutch` |
| Face and voice | Detailed roster faces have mouth-open and clench shapes. CC0 grunts, groans and yells follow hit size; burning sustains a scream. | `FaceExpression`, `WrestlerVoice` |
| Weapons | Graded by impact: LIGHT, ROCK, BLADE, DROP, WIPEOUT, FATAL. | `WeaponCatalog.impact_of` |
| Comeback | Fired up, he takes the damage but not the flinch. | `MATCH_FLOW.md` |

## What real selling is (the craft)

Wrestling coaches and writers keep returning to the same rules:

- **Proportion.** A jab is a head snap. A lariat turns him inside out. A chair
  or a table leaves him down and hurting long after the move.
- **The body part.** He holds what was hit: the back after a powerbomb, the neck
  after a DDT, the knee after leg work.
- **Consistency and follow-through.** A worked knee limps for the rest of the
  match, and the comeback does not forget it.
- **The face and the body.** A grimace, a hand reaching for the ropes,
  breathing that shows.

Sources:
- [Wrestling Psychology, Tropedia](https://tropedia.fandom.com/wiki/Wrestling_Psychology)
- [Wrestling Psychology 101, WhatCulture](https://whatculture.com/wwe/wrestling-psychology-101-everything-you-were-too-afraid-to-ask?page=2)
- [The art of selling, Cara Noir](https://caranoir.com/wrestling-coaching/2019/10/31/the-art-of-selling)
- [Selling: the endangered art form, VAVEL](https://www.vavel.com/en-us/more-sports/2014/09/15/wrestling/392259.html)

**WWE 2K.** 2K ties the sell to the body part (2K17 patch 1.02 fixed "moves
where Superstars would sell the wrong injured body part"). It shows limb damage
on a body HUD, and a damaged man limps and favours the limb. There is little
published detail on how the idles and locomotion are built. Sources:
- [2K17 patch notes](https://www.osftw.com/news/895676/wwe-2k17-patch-102-ps4-xbox-one-101-ps3-360-available-full-details)
- [Wrestler on the 2K mocap sessions](https://wrestletalk.com/news/wwe-2k-game-injury-amazing-red/)

## The gaps, biggest first

1. **Down sells by zone (shipped 5 Nov).** Every knockdown formerly ended in
   `Down_Supine`, whatever caused it. Added:
   - writhe (tables, wire, tacks; **shipped 3 Nov**);
   - holding the back (powerbomb, backbreaker);
   - holding the neck (DDT, neckbreaker, Cross Rhodes);
   - clutching the knee (leg work, figure four);
   - face-down (face-first moves, Cody Cutter);
   - out cold (finisher, sledgehammer: still, no breathing heave).

   Pick by the move's damage zone and its tier, the way `_play_hit_reaction`
   picks a standing reaction.
2. **Force classes for knockdowns (complete 6 Nov).** One back bump served every knockdown.
   Done 3 Nov:
   - `Bump_Lariat` for lariats and the heaviest weapons;
   - weapon impact now picks the bump and the writhe.

   `Bump_Face` now follows a guitar or a chair from behind, and `Bump_Spin`
   follows a superkick. Both hand off to the matching down sell.
3. **Strike side and type (done 6 Nov).** Head shots carry explicit striking
   hand and uppercut metadata. Left-hand hits mirror the head snap, heavy
   stagger and jaw-clutch sell; the dropdown uppercut lifts the chin and toes.
   Damage is still queued when contact is made in the authored active window
   and resolved before the defender starts moving. The contact ordering is
   covered by the startup-to-hit test and `strike_connect_probe`.
4. **Limb damage on the walk (complete 6 Nov).** `CombatSystem` tracks head,
   torso, arms and legs. `LimbDamageSell` adds:
   - over 60 on the legs: a limp, as an additive layer on the locomotion (as
     `SellClutch` is additive);
   - over 60 on the arms: the hurt arm hangs.

   The modifier is presentation-only and deterministic from the damage.
5. **Specific holds and moves (already shipped before this closeout).** Authored paired clips include:
   - powerbomb: the victim cradled on the shoulders (#15);
   - Samoan drop;
   - Cross Rhodes;
   - the figure four: legs entwined, the attacker sitting up.
6. **Pain audio (complete 6 Nov).** `WrestlerVoice` already picked CC0
   light/heavy grunts, a mat groan, yells and a sustained burn scream from hit
   size. This closeout added spaced cries after a submission locks. Per-wrestler
   pitch and seeded take choice keep the voice below the crowd in the mix.
7. **Faces (complete 6 Nov).** Roman, Cody and Kenny gain two runtime shape
   controls on their finished head meshes: parted mouth and clenched brow/lips.
   The pain expression eases with the hit and accumulated wear.
8. **Selling while he waits (complete 6 Nov).** `SellClutch` remains active
   through his opponent's taunt, his own taunt, a count, a ladder climb, and
   the scripted climb to the top rope. Busy hands keep their grip while the
   trunk carries the pain.

## 5 Nov — down sells by zone

Gap 1 now has five authored sells beyond `Down_Supine` and `Down_Writhe`:
`Down_Back`, `Down_Neck`, `Down_Knee`, `Down_Face_First`, and `Down_Out`.
The move's strongest damage zone selects the back, neck, or knee response;
face-first moves carry an explicit landing flag; finishers, sledgehammers,
and fatal shots use the still out-cold pose. Every sell begins at the supine
handoff pose. The face-first sell rolls onto the front, then returns to
supine for the existing get-up animations.

## 6 Nov — strike reactions

Gap 3 uses `MoveDef.strike_hand` to choose a left or right head reaction and
`MoveDef.head_reaction` for uppercuts. The lighter and heavier clips share a
matching sell handoff; the uppercut has a longer heavy stagger. The jab,
cross, elbow, parry counter and dropdown uppercut have authored hand metadata.
The defender's reaction begins when the referee resolves a strike after its
contact tick, with no head motion during the attacker's startup.
The three-seed, 4,000-tick connection probe recorded 122 landed of 156 thrown
strikes (78.2%), with zero interrupted strikes. All three samples ended at the
tick limit before a finish. The 20,000-tick run crashed inside Godot's node
notification code before it could report.

## 6 Nov — selling closeout

The six items formerly listed as next selling work are complete. The paired
holds and most pain vocals were already implemented; their backlog entries had
not been updated. This pass added submission cries, `LimbDamageSell`,
`Bump_Face`, `Bump_Spin`, busy-state `SellClutch` behavior, and `FaceExpression`. `test_selling`,
`test_face_expression`, `test_wrestler_voice`, PoseLint and paired clearance
cover the implementation. Rendered clip frames were reviewed for both new
falls and the pain shapes on the detailed roster.

There are no open items in this selling backlog. Broader game work remains in
`next_steps.md`.
