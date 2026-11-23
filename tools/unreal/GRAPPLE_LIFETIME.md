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
