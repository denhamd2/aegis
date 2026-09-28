class_name PairSeparator
extends Node
## Runs GrappleRig's model separation AFTER the frame's animation has posed
## both men (gauntlet/refs/animation_gap.md, Phase 2).
##
## GrappleRig's own _physics_process runs before the paired AnimationPlayer
## and the wrestlers' AnimationTrees advance, so a separation solved there was
## solved on the previous frame's poses and every fast impact stepped straight
## back into the other man. This node sits at a later physics priority, so it
## sees the poses the frame will be drawn with. It is its own node rather than
## a priority change on GrappleRig because GrappleRig also keeps the bodies
## inside the ring, which is gameplay, and its order is part of the replay.

## After the default priority 0 of the rig's AnimationPlayer and the
## wrestlers' AnimationTrees.
const PRIORITY := 100

var rig: GrappleRig


func _ready() -> void:
	process_physics_priority = PRIORITY


func _physics_process(_delta: float) -> void:
	if rig and rig.is_active():
		rig._separate_models()
