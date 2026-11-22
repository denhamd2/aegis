# Cross Rhodes rear hold

Cody reaches for the defender's left wrist. The defender turns, leans back
into Cody's right forearm, and then rolls out of the hold. The Blender source
changes opening keys on both roles. The two fitted defender root keys close
the space during the hold. Presentation follows the defender's first keyed
turn without applying the yaw carry used for sudden facing changes.

Cody's right arm follows the authored hook. The existing left-arm IK follows
the near side of the defender's wrist to account for different body sizes. It
fades as the pair turn out of the hold. The defender follows his authored
response. The full paired move still runs for 1.9 seconds.

The contact regression requires ten coherent physics samples each for the
neck hook and wrist from tick 9 through 18, including points the hands cannot
reach. It covers a mannequin pair and Cody against both Roman and Kenny. It
uses the existing 5 cm surface-gap limit and test tolerance.

The source export changes only the Cross Rhodes role animations. The baked
pose library uses the production Godot import. The turn into the lift still
allows some leg overlap with Roman. The rotation, spike pose, and recovery
remain open for review. The historical Fight Forever sheet carries two move
labels, and its timestamp does not identify the same moment in the supplied
video cut. This batch follows the approved rear-hold direction and does not
establish a frame-for-frame comparison. Native M1 performance is unverified.

All paired-contact, role, timing and pose checks passed. The focused run
passed 47 of 48 checks. The one failure is the pre-existing library cadence
count of 29 snaps against a budget of 27. Neither Cross Rhodes role is listed
among the clips with snaps. See [the test report](focused-tests.xml).

Cody completed Cross Rhodes once against Roman and Kenny in both player
slots. The defender entered Down and both actors resumed physics. The root
track and both pose clocks reached the same final simulation tick.
[Controller report](controller.json).
