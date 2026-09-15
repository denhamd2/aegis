extends GdUnitTestSuite
## The Blender ring's invariants, asserted without a renderer.
##
## Same arrangement as `test_arena_bowl.gd` and `test_stage_set.gd`: the ring's
## steel and rope is `tools/blender/ring.py`'s model, that exporter reads its
## dimensions out of `ring_builder.gd`, and this suite is what stops the two
## disagreeing about what those dimensions MEAN.

const MODEL := "res://assets/environment/ring.glb"
## Vertex positions come off the mesh through the glTF importer and a float
## buffer, so the tolerance is that of the pipeline, not of the arithmetic.
const TOLERANCE := 0.02


func _model() -> Node3D:
	var packed: PackedScene = load(MODEL)
	assert_object(packed).is_not_null()
	return packed.instantiate()


func _verts(part: String) -> PackedVector3Array:
	var root := _model()
	var node := root.find_child(part, true, false) as MeshInstance3D
	assert_object(node) \
			.override_failure_message("%s has no '%s' object" % [MODEL, part]) \
			.is_not_null()
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	root.free()
	return verts


## Every part `RingBuilder` dresses must exist under the name it dresses it by.
## A part that goes missing does not crash anything -- it renders in its
## Blender placeholder colour, in the middle of a frame whose every other
## surface is solved against a measured target.
func test_every_part_the_builder_dresses_exists_in_the_model() -> void:
	var root := _model()
	for part: String in ["PostMesh", "TurnbuckleFittings", "TurnbucklePads",
			"RopeMesh", "ApronRail", "StepsMesh"]:
		assert_object(root.find_child(part, true, false)) \
				.override_failure_message("%s has no '%s' object" % [MODEL, part]) \
				.is_not_null()
	root.free()


## THE PAD CLEARS THE POST, or the post splits it in two.
##
## This is arithmetic on the constants rather than a measurement of the mesh,
## for the same reason `test_arena_bowl.gd` does it: the exporter reads these
## numbers out of `ring_builder.gd`, so pinning the numbers pins the model.
##
## Work in u, distance from ring centre along the corner diagonal. The post is
## AXIS-ALIGNED and the pad is DIAGONAL, so the post's nearest point to the mat
## is its inner corner -- a vertex, not a face -- and it reaches further in
## than the post's half-section suggests. A pad whose inner face does not clear
## that vertex has a pole standing through the middle of it, which is exactly
## what the first attempt rendered: two lobes either side of the post.
func test_the_turnbuckle_pad_stands_proud_of_the_post() -> void:
	var diagonal := sqrt(2.0)
	var post_inner := (RingBuilder.POST_XZ - RingBuilder.POST_SECTION * 0.5) * diagonal
	var pad_centre := RingBuilder.TURNBUCKLE_PAD_XZ * diagonal
	var pad_inner := pad_centre - RingBuilder.TURNBUCKLE_PAD_DEPTH * 0.5
	assert_float(pad_inner) \
		.override_failure_message(
			"the pad's inner face sits at u=%.3f and the post's inner corner "
			% pad_inner
			+ "at u=%.3f: the post stands through the cushion" % post_inner) \
		.is_less(post_inner)


## THE ROPE ENDS INSIDE THE PAD.
##
## "Attached to the turnbuckles" is a placement, not a joint -- there is no
## constraint tying a rope to a pad, only a pad deep enough to swallow where
## the rope stops. If the pad moves in without getting deeper, the ropes come
## out of its back face and read as passing a pole again.
func test_the_rope_terminations_land_inside_the_pad() -> void:
	var diagonal := sqrt(2.0)
	# Where the two ropes at a corner stop: one runs out along X to
	# POST_XZ + ROPE_OVERRUN at z = ROPE_SPAN, the other is its mirror.
	var rope_end := (RingBuilder.POST_XZ + RingBuilder.ROPE_OVERRUN
			+ RingBuilder.ROPE_SPAN) / diagonal
	var pad_centre := RingBuilder.TURNBUCKLE_PAD_XZ * diagonal
	var half_depth := RingBuilder.TURNBUCKLE_PAD_DEPTH * 0.5
	assert_float(rope_end) \
		.override_failure_message(
			"a rope stops at u=%.3f, outside the pad's %.3f..%.3f"
			% [rope_end, pad_centre - half_depth, pad_centre + half_depth]) \
		.is_between(pad_centre - half_depth, pad_centre + half_depth)


## Three pads per corner, one at each rope height, and twelve in all.
func test_the_model_ships_a_pad_at_every_rope_height() -> void:
	var root := _model()
	var node := root.find_child("TurnbucklePads", true, false) as MeshInstance3D
	assert_object(node).is_not_null()
	var box := node.get_aabb()
	# The pads span the rope heights and nothing else: the lowest reaches half
	# a pad below the bottom rope, the highest half a pad above the top.
	var half := RingBuilder.TURNBUCKLE_PAD_HEIGHT * 0.5
	assert_float(box.position.y) \
		.is_equal_approx(RingBuilder.ROPE_HEIGHT_BOTTOM - half, 0.02)
	assert_float(box.end.y) \
		.is_equal_approx(RingBuilder.ROPE_HEIGHT_TOP + half, 0.02)
	root.free()


## THE STEPS STAND AT A CORNER, hard against a ring post.
##
## They used to sit halfway down each side, offset 0.35m along Z for no reason
## the file gave. That is not where ring steps go: the regulation that governs
## them asks for "suitable steps for use of the contestants in their corners"
## (Virginia 18VAC120-40-415.1), and on television the two sets stand tight
## against a post with their top tread level with the apron, so a wrestler
## climbing them steps over the top rope right beside the turnbuckle.
func test_the_steps_stand_at_a_corner_beside_a_post() -> void:
	var expected: float = RingBuilder.POST_XZ - RingBuilder.STEP_WIDTH * 0.5 \
			- RingBuilder.STEP_POST_GAP
	var east := 0.0
	var east_count := 0
	var west := 0.0
	var west_count := 0
	for v: Vector3 in _verts("StepsMesh"):
		if v.x > 0.0:
			east += v.z
			east_count += 1
		else:
			west += v.z
			west_count += 1
	assert_int(east_count).is_greater(0)
	assert_int(west_count).is_greater(0)
	assert_float(east / east_count) \
			.override_failure_message(
				"the +X steps sit at z=%.2f, not at the corner (%.2f)"
				% [east / east_count, expected]) \
			.is_equal_approx(expected, 0.05)
	assert_float(west / west_count).is_equal_approx(-expected, 0.05)


## Two sets, on DIAGONALLY opposite corners, so each half of the ring has a way
## in and neither set stands in the entrance walkway down the middle of -Z.
func test_the_two_sets_are_diagonally_opposite() -> void:
	var east := 0.0
	var west := 0.0
	var east_count := 0
	var west_count := 0
	for v: Vector3 in _verts("StepsMesh"):
		if v.x > 0.0:
			east += v.z
			east_count += 1
		else:
			west += v.z
			west_count += 1
	# Opposite signs: same-side or same-end pairs both fail this.
	assert_float((east / east_count) * (west / west_count)).is_less(0.0)


## The steps stand OUTSIDE the apron, clear of it, and reach the floor.
func test_the_steps_reach_from_the_floor_to_the_apron() -> void:
	var lowest := INF
	var highest := -INF
	var nearest := INF
	for v: Vector3 in _verts("StepsMesh"):
		lowest = minf(lowest, v.y)
		highest = maxf(highest, v.y)
		nearest = minf(nearest, absf(v.x))
	assert_float(lowest).is_equal_approx(RingBuilder.STEP_FLOOR_Y, TOLERANCE)
	# The top tread is level with the apron, give or take the lip on it --
	# that is the whole point of the last step.
	assert_float(highest).is_equal_approx(RingBuilder.STEP_TOP_Y, TOLERANCE)
	assert_float(nearest) \
			.override_failure_message(
				"the steps reach in to x=%.2f, inside the apron at %.2f"
				% [nearest, RingBuilder.APRON_OUT]) \
			.is_greater_equal(RingBuilder.APRON_OUT)


## The frozen dimensions, measured on the shipped mesh rather than trusted.
##
## `camera.md`'s 41-degree lens, `test_camera_framing.gd`'s MAX_SEPARATION and
## `grapple_rig.gd`'s RING_HALF_EXTENT all hang off the ropes sitting at
## +/-3.1. A rebuild that moved them would invalidate the camera silently.
func test_the_ropes_still_span_the_measured_distance() -> void:
	var reach := 0.0
	var lowest := INF
	var highest := -INF
	for v: Vector3 in _verts("RopeMesh"):
		reach = maxf(reach, maxf(absf(v.x), absf(v.z)))
		lowest = minf(lowest, v.y)
		highest = maxf(highest, v.y)
	# The widest the rope gets is its SPAN plus the tube's own radius --
	# 3.1 + 0.018 -- not its run past the posts. A rope running down X is
	# swept to POST_XZ + ROPE_OVERRUN (3.022) on that axis, which is the
	# shorter of the two, so the outermost geometry is the perpendicular
	# offset of the rope on the opposite side.
	assert_float(reach).is_equal_approx(
			RingBuilder.ROPE_SPAN + RingBuilder.ROPE_RADIUS, 0.02)
	assert_float(highest).is_equal_approx(
			RingBuilder.ROPE_HEIGHT_TOP + RingBuilder.ROPE_RADIUS, 0.05)
	# The bottom rope sags, so the lowest geometry is below its own height.
	assert_float(lowest).is_between(
			RingBuilder.ROPE_HEIGHT_BOTTOM - RingBuilder.ROPE_RADIUS
			- RingBuilder.ROPE_SAG_BOTTOM - 0.01,
			RingBuilder.ROPE_HEIGHT_BOTTOM)
