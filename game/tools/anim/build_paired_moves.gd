extends SceneTree
## Bakes PairedRecipes.TRAJECTORIES into resources/animations/paired_moves.tres.
##
## Run from the Godot project root:
##   godot4 --headless -s res://tools/anim/build_paired_moves.gd
##
## paired_moves.tres holds the *root* half of every paired move: a
## position_3d and a rotation_3d track on each of the two CharacterBody3D
## nodes, which GrappleRig plays on Match's own AnimationPlayer while both
## bodies have their physics suspended. The bone-level half lives in
## paired_poses.tres and is built by build_paired_poses.gd.
##
## The first five moves' arcs were hand-keyed directly into the .tres and
## are deliberately left alone: this generator only adds the clips named in
## TRAJECTORIES, so a re-run cannot perturb an arc that a shipped match
## outcome depends on. Every clip it does write is replaced wholesale, so
## re-running after a recipe edit is idempotent.
##
## Rotation keys are authored as [t, pitch, yaw, roll] in degrees, which is
## the whole reason this generator exists -- the alternative is a column of
## hand-typed quaternions that nobody can read, retune, or review.

const PAIRED_MOVES := "res://resources/animations/paired_moves.tres"

## preload rather than the class_name: a `-s` script runs before the global
## class cache is necessarily populated in a fresh checkout.
const PairedRecipes := preload("res://resources/animations/paired_recipes.gd")

## Node paths the root tracks address, relative to the AnimationPlayer's
## root_node. Matched to the hand-keyed clips already in the library.
const ROLE_PATHS := {
	"attacker": "../WrestlerA",
	"defender": "../WrestlerB",
}

## An arc peaking at or above this height has genuinely thrown the wrestler
## into the air, and must therefore return him to his starting rotation --
## the model's origin is at its feet, so a body still pitched over at
## landing hangs its whole length below the mat. This is the invariant the
## suplex violated; enforcing it here means no new move can repeat it.
const AIRBORNE_PEAK := 0.30

## A root track may not put a wrestler below mat level, ever. The model's
## origin is at its feet, so a negative y is not a crouch -- it is his feet
## through the canvas. A crouch, a drop to one knee, a kneeling finish are
## all *poses*: they belong in the bone recipe, where the pelvis translates
## down inside a body whose feet stay on the mat. Authoring them as root
## dips instead is what took the match's minimum body height from -0.03m to
## -0.26m the first time these trajectories were generated. Same principle
## GrappleRig._level_bodies() records for lying down.
const MAT_LEVEL := 0.0

func _init() -> void:
	quit(_build())

func _build() -> int:
	var library: AnimationLibrary = load(PAIRED_MOVES)
	if not library:
		push_error("Cannot load %s" % PAIRED_MOVES)
		return 1

	var written := 0
	for move_id in PairedRecipes.TRAJECTORIES:
		var spec: Dictionary = PairedRecipes.TRAJECTORIES[move_id]
		var anim := _bake(String(move_id), spec)
		if not anim:
			return 1
		var key := StringName(move_id)
		if library.has_animation(key):
			library.remove_animation(key)
		library.add_animation(key, anim)
		written += 1

	var err := ResourceSaver.save(library, PAIRED_MOVES)
	if err != OK:
		push_error("Saving %s failed: %d" % [PAIRED_MOVES, err])
		return 1
	print("Wrote %s -- %d generated clips, %d in the library"
			% [PAIRED_MOVES, written, library.get_animation_list().size()])
	return 0

func _bake(move_id: String, spec: Dictionary) -> Animation:
	var length: float = spec.get("length", 1.0)
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE

	for role: String in ["attacker", "defender"]:
		if not spec.has(role):
			push_error("%s: trajectory has no '%s' half" % [move_id, role])
			return null
		var path := NodePath(ROLE_PATHS[role])
		var half: Dictionary = spec[role]
		var label := "%s/%s" % [move_id, role]

		var positions: Array = half.get("pos", [])
		var rotations: Array = half.get("rot", [])
		if positions.is_empty() or rotations.is_empty():
			push_error("%s: needs both pos and rot keys" % label)
			return null

		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, path)
		# CUBIC throughout, matching the hand-keyed clips: these arcs are
		# 4-7 keys across a one-second throw and linear interpolation
		# between them reads as a sequence of straight lines.
		anim.track_set_interpolation_type(pos_track, Animation.INTERPOLATION_CUBIC)
		var peak := -INF
		var previous := -1.0
		for key: Array in positions:
			var t: float = key[0]
			if t < 0.0 or t > length:
				push_error("%s: position key at %.3f is outside 0..%.3f"
						% [label, t, length])
				return null
			if t <= previous:
				push_error("%s: position keys are not in ascending time order at %.3f"
						% [label, t])
				return null
			previous = t
			if float(key[2]) < MAT_LEVEL:
				push_error(("%s: position key at %.3f sits at y=%.3f, below the "
						+ "mat -- the model's origin is at its feet, so a crouch "
						+ "belongs in the bone recipe, not the root track")
						% [label, t, float(key[2])])
				return null
			peak = maxf(peak, float(key[2]))
			anim.position_track_insert_key(pos_track, t,
					Vector3(key[1], key[2], key[3]))

		var rot_track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, path)
		anim.track_set_interpolation_type(rot_track, Animation.INTERPOLATION_CUBIC)
		previous = -1.0
		var first := Quaternion.IDENTITY
		var last := Quaternion.IDENTITY
		for i in rotations.size():
			var key: Array = rotations[i]
			var t: float = key[0]
			if t < 0.0 or t > length:
				push_error("%s: rotation key at %.3f is outside 0..%.3f"
						% [label, t, length])
				return null
			if t <= previous:
				push_error("%s: rotation keys are not in ascending time order at %.3f"
						% [label, t])
				return null
			previous = t
			var q := _euler_key(key)
			if i == 0:
				first = q
			last = q
			anim.rotation_track_insert_key(rot_track, t, q)

		if peak >= AIRBORNE_PEAK and absf(first.dot(last)) < 0.9999:
			push_error(("%s: arc peaks at %.2fm but ends rotated away from its "
					+ "start -- a thrown wrestler must land upright or he sinks "
					+ "through the mat") % [label, peak])
			return null

	return anim

## [t, pitch, yaw, roll] in degrees -> a normalized quaternion. Basis's
## default YXZ order makes yaw world-space and pitch/roll body-local, which
## is what lets a flip be written as a plain run of pitch values.
static func _euler_key(key: Array) -> Quaternion:
	return Quaternion(Basis.from_euler(Vector3(
			deg_to_rad(float(key[1])),
			deg_to_rad(float(key[2])),
			deg_to_rad(float(key[3]))))).normalized()
