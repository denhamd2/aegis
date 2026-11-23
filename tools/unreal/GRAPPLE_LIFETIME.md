# Grapple lifetime parity

Use the existing Unreal grapple rig and gameplay state machine. The Godot
implementation is in `game/core/grapple/grapple_rig.gd` and the controller's
`cancel_paired_playback` callback. Trajectory import does not implement this
ownership behavior.

At grapple entry, retain each participant's movement and tick state before
suspending it. Keep an identity for that playback through the approach,
authored trajectory or fallback timer, and separation at the end. A delayed
callback can only finish the playback it belongs to.

Route explicit cancellation, participant EndPlay, and rig EndPlay through the
same cleanup. Stop the paired playback, release surviving participants,
preserve pre-existing suspension, and clear grapple role and pending move
state. A surviving controller still in grapple hold must regain free movement.
Clear pending camera impact and replay capture for the cancelled move.
Keep completion and cancellation distinct so cancellation cannot apply
damage, launch a whip, or advance a grapple chain.

Run these cases in the Unreal editor with each physical player slot as the
attacker. The Godot regressions use real begin, cancellation and exit paths.

| Case | Expected outcome |
| --- | --- |
| Cancel during approach and immediately begin another move | Exactly one completion, for the replacement move at its own duration |
| Cancel during authored playback with one wrestler already suspended | Restore each prior movement state, stop paired playback, clear role state |
| Remove the rig or either participant | Survivors regain their previous movement state, with no completion event |
| Cancel during separation after the clip ends | No stale completion after further simulation ticks |
| Cancel a running inverted drop through its normal controller entry | Free controls, unchanged defender health, no landed move or pending completion callback |
| Complete a valid grapple | One completion, authored timing intact, no remaining rig ownership |

Unreal implementation and PIE validation require the Mac checkout and editor
MCP. This repository supplies the acceptance cases and the Godot implementation.

## Standing strike reversal parity

A valid parry read belongs to one opponent and one strike instance. Use
the move's reversal window with the established input lead. A new swing,
even one using the same move definition, needs its own read. Consume it
once at valid strike contact. Expire it when that strike's window closes
or the defender leaves a state that can parry.

Check both physical player slots with a jab. A valid early read should
prevent damage and enter the existing strike parry. A read made before the
window should spend stamina and apply its lockout. Restarting the same jab
after a read should allow the replacement strike to land.

For a reversible contact, queue the striker, target, strike instance,
move and contact frame. Resolve it in the same 60 Hz simulation tick
after both controllers have sampled player, AI or replay input and
before processing damage and reactions. Validate the target's state
again and consume the contact once. If the striker updated first,
AI reaction timing must still use the contact frame. Start the parry
at frame zero in both slots. In PIE, test a button edge on the last
legal contact frame in both slots, with full damage suppression and
one parry. Run the unopposed jab as a control and verify one hit.
Unreal standing reversal logic and PIE validation remain open.

## Paired chain grapple counters

Resolve these reads once at 60 Hz in the match referee after both player,
AI or replay inputs arrive. Check the current chain read clock before it
advances. Use ticks 4 through 14 inclusive in the 18-tick read. A defender
has one attempt per read and pays reversal stamina once. A miss leaves the
holder's choice in place. A whip or an explicit end to the read takes
precedence. Keep the opening lock-up's existing direct grapple behavior.

On success, start the existing paired counter immediately with swapped
roles. Headlock and waistlock choices map to the waistlock pair. A wristlock
or a read with no choice maps to the wristlock pair. Reserve both wrestlers
through lead-in and playback. Apply the link's wear once on completion,
then resume the chain read if links remain. Cancellation clears both role
flags and the completion handler and restores each wrestler's previous
physics processing state.

In PIE, swap physical slots across the start and end boundary cases
(ticks 4 and 14), misses at ticks 3 and 15, and cancellation when the rig
starts. Verify one stamina charge per attempt, no second counter while
the rig owns the pair, and no damage or stale completion on cancellation.
The Unreal runtime and these PIE checks still require the Mac checkout.

## Committed vertical suplex counter

Read the source move's `paired_counter_id` and inclusive reversal bounds
from the shared MoveDef export. The vertical suplex maps to `chain_waistlock`
at paired playback ticks 6–14 at 60 Hz. The clock starts with the authored
role clips, after the walk-in. Use the same replay input path while the
paired rig owns movement, sampling once per tick before the replay advances.

During playback, an early attempted read spends reversal stamina and uses
up the attempt for that throw. Inputs after the window closes are ignored.
An exhausted defender fails the read. For a valid counter, cancel the
source pair and its damage, camera and replay callbacks, then start the
waistlock go-behind with swapped roles at the current positions. Use the
replacement's ordinary lead-in, completion and recovery. The Godot AI makes
one seeded decision on entering the window and records the resulting input.

In PIE, test the opening and closing bounds across both physical slots,
early and late reads, an exhausted defender, and cancellation before the
replacement finishes. Verify that normal completion lands only the
replacement and an interruption lands neither move. The exported data and
role clips are shared. Unreal playback and counter handling still need the
Mac project.


## Arm-hook and running Spear counters

Use the same committed-counter and replay rules for these mappings. Frame
bounds are inclusive at 60 Hz and use the paired clip clock after walk-in.

| Source MoveDef | Window | Replacement |
| --- | --- | --- |
| `strike_arm_hook_takedown` | 20–26, during the right-arm sweep before the hook at tick 28 | `chain_wristlock` |
| `running_spear` and `finisher_running_spear` | 16–22, during the approach before the dive and contact at tick 30 | `chain_headlock` |

The replacement starts from the current roots and uses the existing paired
alignment and pose blend. Resolve only one source attempt and cancel its
pending impact on a successful read. The reversed finisher earns no cover
eligibility and does not spend the landing-only finisher meter. A late
press leaves the finisher on its normal completion path.

Check both physical slots, including a late Spear that lands, and verify
the two Spear resources map to the same source clip and timing. The Godot
AI keys each read by match seed, player slot, source move and attempt,
then uses the match phase's reversal scale. Shared move data and role clips
are exported for Unreal. Editor runtime integration remains open.

## Interrupting a rope absorb

The absorb and its bounded rebound return may temporarily ignore the rope
collider. On a hit, another state exit, or timeout, release that exception
and restore legal root containment in the same physics tick. Continue
the normal authored rebound when the runner clears the ropes under his
own motion. In PIE, interrupt the absorb after contact in both slots,
verify the rope blocks the next crossing, and finish the match through
an earned finisher and cover.

## Pin and rope-break resolution

Drive cover and hold resolution at 60 Hz. Check normal ring legality and the
current stipulation on scripted covers as well as automatic covers. Use the
measured count ticks 92, 167 and 227. Input can win on the second count tick
before that slap lands. A kickout after the second slap and before tick 227
records one near-fall and queues its presentation once. Lock the decision at
three. Preserve the finisher-only pinfall rules and the automatic tick-219
kickout on covers that cannot win.

Start a cover's reach on tick 36 and a submission's on its 60th locked tick.
Verify the chosen rope from the defender's root on the contact tick, 24
ticks after the reach starts. Release the cover or hold before broadcasting
the break. Clear the reach on an early kickout, an escaped hold, or invalid
contact. Preserve the existing finisher and no-holds-barred exceptions.

In PIE, check a late minigame kickout, a winning three-count, an interrupted
reach, and a confirmed pin and submission break in both slots. For the
referee actor, approach around both bodies, enter the active slap at its
elapsed offset and keep the completed third slap visible through contact.
Cut the third swing on a close kickout. Godot has focused tests for these
boundaries. The Unreal implementation still requires the Mac project.
