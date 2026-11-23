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
