class_name MatchSmoothing
extends RefCounted
## Smooth motion between physics ticks (physics_interpolation, opted into by
## the wrestlers and the match camera only).
##
## The owner saw Roman's walk as "almost stop motion". His root, the camera and
## his pose all advanced on the 60 Hz physics tick with nothing in between, so
## on a 120 Hz Mac display -- or any frame rate that wanders -- each step was
## held for an uneven number of frames. Interpolation draws the root and the
## camera where they are between ticks; WrestlerController.set_presentation_rate
## evaluates the pose every frame while nothing reads it back.
##
## A teleport has to say so, or it is drawn as a one-tick slide: snap() for a
## node that was placed, CutGuard for the camera, which cuts from many places.

## Jumps bigger than these in one tick are cuts, not moves.
const CUT_DISTANCE := 0.75
const CUT_ANGLE_DEG := 20.0


## A node that was just placed rather than moved.
static func snap(node: Node3D) -> void:
	if node and node.is_inside_tree() and node.is_physics_interpolated():
		node.reset_physics_interpolation()
	# His pose is drawn between ticks too (Inertializer.interpolate_pose).
	if node is WrestlerController and (node as WrestlerController).inertializer:
		(node as WrestlerController).inertializer.snap()


## Watches its parent after every physics tick and resets its interpolation
## when it jumped -- the camera's cuts set its transform directly from a dozen
## shot functions, and each would otherwise smear across one frame.
class CutGuard extends Node:
	var _last := Transform3D()
	var _has_last := false

	func _ready() -> void:
		name = "CutGuard"
		# After the parent's own _physics_process.
		process_physics_priority = 1000

	func _physics_process(_delta: float) -> void:
		var parent := get_parent() as Node3D
		if parent == null:
			return
		var now := parent.global_transform
		if _has_last:
			var moved := now.origin.distance_to(_last.origin)
			var turned := rad_to_deg(now.basis.get_rotation_quaternion().angle_to(
					_last.basis.get_rotation_quaternion()))
			if moved > CUT_DISTANCE or turned > CUT_ANGLE_DEG:
				MatchSmoothing.snap(parent)
		_last = now
		_has_last = true
