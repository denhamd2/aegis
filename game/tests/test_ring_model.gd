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
	for part: String in ["PostMesh", "TurnbuckleFittings", "RopeMesh",
			"ApronRail", "StepsMesh"]:
		assert_object(root.find_child(part, true, false)) \
				.override_failure_message("%s has no '%s' object" % [MODEL, part]) \
				.is_not_null()
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
