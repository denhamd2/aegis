# Selling: what we have, what 2K and real wrestling do, and the plan

The owner, 3 Nov: "Do we have anything in the backlog to improve selling by the
wrestler being attacked? If no, research what needs to be done."

**Backlog check.** No open item. The last selling work shipped. It is listed
in `next_steps.md` ("every hit ... is sold to its size and to how much he has
left") and `match_aaa_plan.md` §3 (`Sell_Head`/`Sell_Gut`, `FLURRY_STUN_AT`).
`animation_gap.md` Phase 4 names the in-between selling that `SellClutch`
covers. Nothing beyond that was planned, hence this document.

## What the game does today

| Layer | What it does | Where |
| --- | --- | --- |
| Hit size | Five sizes: LIGHT, MEDIUM, HEAVY, KNEE, DOWN. Chosen by the damage taken and the health left. Reaction 20–72 ticks. | `WrestlerController.sell_tier`, `SELL_REACT_TICKS` |
| Where he was hit | Head by strike hand, uppercut, or gut: mirrored `Hit_React_Head`, `Hit_Uppercut`, `Hit_React_Torso`, and heavy variants. Then a matching head or gut sell. | `StrikeRecipes.reaction_for`, `_play_hit_reaction` |
| Every blow | An additive flinch away from the hitter, plus hit-stop. | `HitFlinch` |
| A string of blows | Rocked into `Stunned_Sway` on the third blow inside a sell. | `FLURRY_STUN_AT` |
| Knockdown | `Bump_Back`, then `Down_Supine` (breathing, knees up). Time down scales with the move. Staged get-up and groggy afterwards. | `_bump_down`, `_go_down`, `groggy_for` |
| After big moves | Additive sell profiles: suplex, Cross Rhodes, table rebound, wire, tacks, ladder. | `ImpactSell` |
| Between exchanges | His hand goes to the most-hurt part: head, ribs, knee or shoulder. | `SellClutch` |
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
2. **Force classes for knockdowns.** One back bump served every knockdown.
   Done 3 Nov:
   - `Bump_Lariat` for lariats and the heaviest weapons;
   - weapon impact now picks the bump and the writhe.

   Still missing: a face-first collapse (guitar, chair to the back of the head)
   and a spin-out (a superkick).
3. **Strike side and type (done 6 Nov).** Head shots carry explicit striking
   hand and uppercut metadata. Left-hand hits mirror the head snap, heavy
   stagger and jaw-clutch sell; the dropdown uppercut lifts the chin and toes.
   Damage is still queued when contact is made in the authored active window
   and resolved before the defender starts moving. The contact ordering is
   covered by the startup-to-hit test and `strike_connect_probe`.
4. **Limb damage on the walk.** `CombatSystem` already tracks head, torso, arms
   and legs. Needed:
   - over 60 on the legs: a limp, as an additive layer on the locomotion (as
     `SellClutch` is additive);
   - over 60 on the arms: the hurt arm hangs.

   A presentation-only modifier, deterministic from the damage, the same
   contract as `SellClutch`.
5. **Specific holds and moves.** Each needs a re-authored paired clip:
   - powerbomb: the victim cradled on the shoulders (#15);
   - Samoan drop;
   - Cross Rhodes;
   - the figure four: legs entwined, the attacker sitting up.
6. **Pain audio.** There are no vocal sells: no grunt on a chop, no groan on the
   mat, no scream in a hold. Needed: a small CC0 set of grunts, groans and
   screams in `assets/audio`, scaled by sell size. They play under the crowd and
   are never on top of it.
7. **Faces.** The rigs have no face controls, so there are no grimaces. The
   options:
   - a jaw/brow bone pair on the base rig (`rigging`);
   - two shape keys per wrestler (open mouth, clenched).

   Lowest priority: at broadcast distance the body reads first.
8. **Selling while he waits.** He should sell through the other man's taunt, the
   referee's count and a climb, rather than standing neutral. The ladder sell
   (2 Nov) is the pattern; extend it to taunts and the climb to the top rope.

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

## Order

1. The owner's six fixes (#48).
2. Down sells by zone (gap 1; done 5 Nov).
3. Strike side, uppercut and contact (gap 3; done 6 Nov).
4. The limp layer (gap 4).
5. Pain audio (gap 6).
6. Faces (gap 7).

Each is closed on rendered frames and a probe, not on this document.
