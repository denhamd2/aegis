# MATCH_FLOW.md — what a match is supposed to be

The intended shape of a match, and the rules about who may do what to whom.

`ARCHITECTURE.md` is the contract: the things a slice may not break. This page
is different — it is **intent**, not invariant. It says what the match is
*for*, so that a change can be judged against something other than "the tests
still pass". Most of what is written here was previously recoverable only by
reading several hundred lines of commit archaeology inside `WrestlerAI`,
`MatchReferee`, `CombatSystem` and `WrestlerController`, which is why it kept
being re-derived and occasionally re-derived wrong.

## The rule this page lives under

**This page owns no numbers.** Every quantity below is quoted from the file
that owns it, and the owner wins every disagreement. The ownership is:

| Quantity | Owner |
| --- | --- |
| Per-move frame data, damage, contact volume | the move's `.tres` (`MoveDef`) |
| What a wrestler may legally do next | `WrestlerFSM.LEGAL_TRANSITIONS` |
| Anything traceable to footage | `gauntlet/refs/` |
| Momentum thresholds, kickout and submission curves | `CombatSystem` |

If a number here contradicts one of those, this page is stale — fix it here,
not there. `FEEL_BAR.md` was allowed to disagree with the game for several
rounds (its priority #1 was reversal windows, a mechanic that had been
deleted), and that is the failure mode this rule exists to prevent.

## The shape of a match

> Grapple, strikes, signature, pinfall.

That sentence is `WrestlerAI`'s, and it is the whole design:

1. **The opening grapple.** The first time the two are close enough, they lock
   up. Nobody has landed a tier yet, so the AI presses grapple and the tie-up
   contest decides who throws the move. This exists to open the match with
   something other than a punch.
2. **The middle is strikes.** Punches and kicks, traded. This is most of the
   match by time and by count. Once in the middle, the man who won the opening
   lock-up locks up again for the **power move** -- the body slam -- when his
   momentum sits between `POWER_THRESHOLD` and `SIGNATURE_THRESHOLD`
   (`WrestlerAI._wants_power_tie_up()`). One try a match, won or lost. It
   leaves the other man on the mat briefly (`MoveDef.leaves_defender_down`),
   which is not a knockdown and cannot be covered.
3. **The signature finishes it.** Once the man opposite has been worn down far
   enough that one signature will put him on the mat, the other reaches for a
   last tie-up, throws it, and covers him where he lands.
4. **Every finish is a cover.** A match ends on a pinfall.

### Why it is not a grapple match

It used to be. Every close-range decision was a seeded coin flip between a
strike and a tie-up, weighted so the grapple chain carried the match — measured
at four tie-ups against 4–11 strikes apiece over three seeds. The power and
finisher throws were then removed (they did not read on screen), so the chain
had nowhere to escalate to, and a match made of four identical hip tosses is
not a better match than one made of strikes.

The grapple survives as **an opening, one power move and an ending**, not as
the body of the match.

### Why the signature comes last

Measured, twelve AI seeds: the winner throws **two to four** signatures a
match, and the one that ends it is a signature in 11 of 12. Those two facts
are the same fact. The first signature knocks the man down at about 100
damage, where the kickout window is still wide, so he kicks out; the finish is
a later signature -- sometimes the same move twice in a row. Capping
signatures at two, or spacing them three strikes apart, was tried and hands the
finish to a strike instead (8-10 of 12). Which of those a match should be is a
design call, recorded in README rather than made here.

Momentum crosses `SIGNATURE_THRESHOLD` after three or four strikes, long before
anybody is hurt enough to pin. An AI that threw a signature as soon as it could
afford one would throw it in the opening exchange and then finish the match
with jabs. So affording it is not sufficient: `WrestlerAI._opponent_is_ripe()`
also requires that the **weakest** signature in the pool would close the
remaining gap to a knockdown by itself. The weakest rather than the likeliest,
because the move is drawn by a seeded pick at the moment the grapple resolves,
and reaching for one that leaves the man standing spends the tie-up for
nothing.

## What decides a contest

Three contests, and all three are deterministic functions of fixed-tick input —
no bare RNG, per the determinism contract.

- **The tie-up** — a symmetric mash. First to `TieUpMinigame.PROGRESS_THRESHOLD`
  qualifying presses becomes the grapple attacker. Arbitrated by `MatchReferee`
  strictly after both wrestlers' own `_physics_process`, so neither side gets a
  scene-tree-order head start.
- **The kickout** — a fill meter, not a single in-window tick. The marker sweeps
  the whole range every `PinMinigame.TICKS_PER_ATTEMPT`, so it crosses any
  nonzero window regardless of input; progress accumulates only while the
  marker is in-window *and* the defender is pressing. Damage and the attacker's
  momentum narrow the window (`CombatSystem.kickout_window_fraction`).
- **The strike exchange** — decided by who lands first, and by whether the man
  throwing is actually facing the man he is hitting. Inside
  `FACE_OPPONENT_RANGE` a moving wrestler strafes — eyes and hips on the other
  man, feet carrying him sideways — because a proximity hit test let wrestlers
  fight a whole match side-on and land everything anyway. Both men can throw on
  the same tick; damage applies immediately, but the *reaction* waits for the
  thrown punch to finish rather than eating it, so both connect and both then
  react. That is what trading blows looks like. A knockdown still interrupts: a
  man dropped mid-swing is not finishing the swing.

## What is deliberately absent

Recording these stops them being rediscovered as bugs.

- **Reversals.** A reversal used to cancel an incoming strike and play a paired
  counter. The counters were cut with the power and finisher throws — a counter
  that does not read on screen is a strike that simply vanishes. Nothing
  replaced the mechanic: **a strike thrown in this match loop always resolves,
  and the answer to being struck is to strike back.** `MoveDef` still carries
  `reversal_window_start/end`; those are measured frame numbers and are kept
  because re-measuring later is more work than carrying them, but nothing reads
  them and a window without a consumer decides nothing.
- **Submissions.** `SubmissionMinigame`, both `SUBMISSION_*` states and
  `WrestlerController.begin_submission()` all still work and are still tested.
  What changed is that the **referee no longer reaches for one**, so nothing in
  a match starts one. A seeded coin flip between a pinfall and a tap-out meant
  most matches ended on the finish nobody asked to watch — measured at 2 of 3
  seeds ending by submission.
- **A neutral game.** The AI circles to hold its spacing, but there is no
  feinting, no baiting, no reading. See the locomotion slice in
  `gauntlet/status/slices.json`.
- **The FINISHER rung.** Empty. `CombatSystem.Tier` keeps it so that a tier's
  ordinal — and every seeded draw and saved replay that depends on it — does
  not shift underneath the rungs that are left. (The POWER rung was empty too
  until the body slam was keyed back into it; see README.)

## Invariants that span files

Every one of these is a case where two artifacts have to agree and nothing in
either file says so. Each has already drifted at least once. **A requirement
here without a named enforcer is a wish** — that rule is what `gauntlet/refs/`
runs on, and it applies to this page too.

| Invariant | Enforced by |
| --- | --- |
| A strike's `startup_frames` equals the tick its limb actually peaks | `tools/anim/measure_contact_offsets.gd` (flags drift > 2 ticks) |
| `contact_offset` is re-measured whenever the clip or `startup_frames` changes | same tool — re-run it, never hand-edit the vector |
| A clip is exactly as long as the state that plays it (`total_frames()/60`) | `tests/test_authored_clips.gd` |
| A planted foot travels backward at exactly the engine's ground speed | `tools/anim/gait_audit.gd` |
| A looping clip's closing pose equals its opening pose | `tools/anim/gait_audit.gd` |
| The AI's circling band lies inside the **shortest** strike in its pool | `tests/test_ai_spacing.gd` |
| A wrestler inside fighting distance faces his opponent rather than his direction of travel | `tests/test_wrestler_facing.gd` |
| Every pose target is inside the limb's reach | `tools/blender/reach_audit.py` |
| A strike lands only where its limb is, and only forwards | `tests/test_strike_contact_volume.gd` |
| Same seed + same replay ⇒ same end-state hash | `tests/test_determinism.gd`, every capture's evidence gate |

### When two owners disagree

Reference beats clip. The running attacks' 18-tick startup is `0.300s` measured
off footage (`refs/timings.md`) and pinned by
`tests/test_strike_and_getup_timings.gd`, while `running_clothesline`'s arm
peaks at tick 30. The MoveDef is right and **the clip is what has to move** —
retiming it is an open item, not a licence to edit the number.

This is the general rule: where `gauntlet/refs/` has measured something, the
asset is fitted to the reference, never the reference to the asset.

## How to judge a change to the match

In order:

1. Does the match still end? A change that stops a finish being reachable is a
   failure however good it looks — matches have twice stopped finishing
   (a spacing dead band, and a knockdown threshold no match ever reached).
2. Does it keep the shape above — grapple, strikes, signature, pinfall — or has
   it quietly become a grapple loop or a strike-only brawl?
3. Are all three tiers still reachable, and all five capture beats?
4. Does the evidence gate pass, on `forward_plus`?

Reachability is the recurring failure here, and it is not visible in a green
suite: the tests passed throughout every episode above. Run a match.
