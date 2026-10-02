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
			"TurnbuckleHardware", "RopeMesh", "ApronRail", "StepsMesh"]:
		assert_object(root.find_child(part, true, false)) \
				.override_failure_message("%s has no '%s' object" % [MODEL, part]) \
				.is_not_null()
	root.free()


## THE PAD IS NOT JOINED TO THE POST. The owner: "there should be a connector
## connecting the two, they should not be joined to each other". A real
## pad is laced round the turnbuckle a rope ends in, and the turnbuckle hooks
## an eye bolt on the post -- so there is a hand's width of bare hardware
## between the back of every pad and its post. Work in u, distance from ring
## centre along the corner diagonal (the pads face down it).
func test_a_turnbuckle_gap_separates_every_pad_from_its_post() -> void:
	var diagonal := sqrt(2.0)
	var post_face := RingBuilder.POST_XZ * diagonal - RingBuilder.POST_RADIUS
	var pad_back := RingBuilder.TURNBUCKLE_PAD_XZ * diagonal \
			+ RingBuilder.TURNBUCKLE_PAD_DEPTH * 0.5
	var gap := post_face - pad_back
	assert_float(gap).override_failure_message(
			"pad back at u=%.3f, post face at u=%.3f: %.3f of turnbuckle"
			% [pad_back, post_face, gap]).is_between(0.22, 0.32)
	# The turnbuckle body fits in it, with the hook and eye either side.
	assert_float(RingBuilder.TURNBUCKLE_BODY_LENGTH
			+ 2.0 * RingBuilder.TURNBUCKLE_EYE_RADIUS).is_less(gap)
	# And the post stands at the deck's corner: outboard of the rope line,
	# not more than a couple of centimetres past the apron.
	assert_float(RingBuilder.POST_XZ).is_greater(RingBuilder.ROPE_SPAN)
	assert_float(RingBuilder.POST_XZ + RingBuilder.POST_RADIUS) \
			.is_less(RingBuilder.APRON_OUT + 0.03)


## THE ROPE ENDS INSIDE THE PAD, in depth AND across it: both of a corner's
## ropes end in the one turnbuckle the pad covers.
func test_the_rope_terminations_land_inside_the_pad() -> void:
	var diagonal := sqrt(2.0)
	# The rope down X stops at (ROPE_END, ROPE_SPAN); the other mirrors it.
	var u := (RingBuilder.ROPE_END + RingBuilder.ROPE_SPAN) / diagonal
	var across := absf(RingBuilder.ROPE_END - RingBuilder.ROPE_SPAN) / diagonal
	var pad_centre := RingBuilder.TURNBUCKLE_PAD_XZ * diagonal
	var half_depth := RingBuilder.TURNBUCKLE_PAD_DEPTH * 0.5 \
			- RingBuilder.TURNBUCKLE_PAD_BEVEL
	assert_float(u) \
		.override_failure_message(
			"a rope stops at u=%.3f, outside the pad's %.3f..%.3f"
			% [u, pad_centre - half_depth, pad_centre + half_depth]) \
		.is_between(pad_centre - half_depth, pad_centre + half_depth)
	assert_float(across + RingBuilder.ROPE_RADIUS).is_less(
			RingBuilder.TURNBUCKLE_PAD_WIDTH * 0.5 - RingBuilder.TURNBUCKLE_PAD_BEVEL)


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


## THE STEPS POINT AT THE POSTS, on the corner diagonals, CUT TO THE CORNER.
##
## Measured on the shipped mesh in each flight's own frame: `u` along the
## diagonal from the ring's centre, `w` across it. The flight spans the
## diagonal from inside the apron's corner (the notch's flanks reach back
## along the apron sides) out to the foot of its four tiers, stays within its
## width either side of the line -- and no vertex is inside the apron, or
## nearer either apron side than the cut's gap.
func test_the_steps_point_at_the_posts_on_the_diagonals() -> void:
	var plate := 0.03
	var apex := RingBuilder.APRON_OUT * sqrt(2.0) + RingBuilder.STEP_APRON_GAP * sqrt(2.0)
	for corner: Vector2 in RingBuilder.STEP_CORNERS:
		var out := RingBuilder.step_out_dir(corner)
		var across := Vector3(-out.z, 0.0, out.x)
		var u_hi := -INF
		var w_max := 0.0
		var seen := 0
		for v: Vector3 in _verts("StepsMesh"):
			if signf(v.x) != signf(corner.x) or signf(v.z) != signf(corner.y):
				continue
			seen += 1
			var flat := Vector3(v.x, 0.0, v.z)
			u_hi = maxf(u_hi, flat.dot(out))
			w_max = maxf(w_max, absf(flat.dot(across)))
			# Outside the apron by the gap on at least one side: never in it.
			var clear := maxf(absf(v.x) - RingBuilder.APRON_OUT, absf(v.z) - RingBuilder.APRON_OUT)
			assert_float(clear).override_failure_message("%s: a step vertex %s is %.3f into the apron"
					% [corner, v, -clear]).is_greater_equal(RingBuilder.STEP_APRON_GAP - 0.004)
		assert_int(seen).is_greater(0)
		assert_float(u_hi).is_equal_approx(apex + RingBuilder.STEP_PLATFORM
				+ RingBuilder.STEP_RUN * (RingBuilder.STEP_TREADS - 1), 0.03)
		assert_float(w_max).override_failure_message(
				"the %s flight spreads %.3f off its diagonal: it is not square to it"
				% [corner, w_max]) \
				.is_less_equal(RingBuilder.STEP_WIDTH * 0.5 + plate)


## The owner's note: the steps fit SNUG into the corner. The notch's two faces
## run along the apron's two sides STEP_APRON_GAP off them -- within 1-3 cm --
## for most of the flight's width, and the ring post stands in the notch,
## clear of the casting.
func test_the_steps_fit_snug_into_the_corner_round_the_post() -> void:
	assert_float(RingBuilder.STEP_APRON_GAP).is_between(0.01, 0.03)
	for corner: Vector2 in RingBuilder.STEP_CORNERS:
		var near_side := 0
		var post := Vector3(corner.x * RingBuilder.POST_XZ, 0.0, corner.y * RingBuilder.POST_XZ)
		var post_clear := INF
		for v: Vector3 in _verts("StepsMesh"):
			if signf(v.x) != signf(corner.x) or signf(v.z) != signf(corner.y):
				continue
			var gap := maxf(absf(v.x) - RingBuilder.APRON_OUT, absf(v.z) - RingBuilder.APRON_OUT)
			if gap < 0.035 and minf(absf(v.x), absf(v.z)) < RingBuilder.APRON_OUT - 0.3:
				near_side += 1
			if v.y > RingBuilder.STEP_TOP_Y - 0.3:
				post_clear = minf(post_clear, Vector2(v.x - post.x, v.z - post.z).length())
		assert_int(near_side).override_failure_message("%s: no cut face along the apron" % corner) \
				.is_greater(8)
		assert_float(post_clear - RingBuilder.POST_RADIUS).is_greater(0.0)


## The two flights are the hard camera's TOP-LEFT and BOTTOM-RIGHT corners:
## (+3, -3) and (-3, +3). Every vertex of the steps is in one of those two
## quadrants and none in the other two.
func test_the_steps_are_top_left_and_bottom_right() -> void:
	for v: Vector3 in _verts("StepsMesh"):
		assert_float(v.x * v.z) \
			.override_failure_message("a step vertex at (%.2f, %.2f) is in the wrong corner"
				% [v.x, v.z]) \
			.is_less(0.0)


## The steps stand OUTSIDE the apron, clear of it, and reach the floor.
func test_the_steps_reach_from_the_floor_to_the_apron() -> void:
	var lowest := INF
	var highest := -INF
	var nearest := INF
	for v: Vector3 in _verts("StepsMesh"):
		lowest = minf(lowest, v.y)
		highest = maxf(highest, v.y)
		nearest = minf(nearest, maxf(absf(v.x), absf(v.z)))
	assert_float(lowest).is_equal_approx(RingBuilder.STEP_FLOOR_Y, TOLERANCE)
	# The top tread is level with the apron; only its nose stands proud.
	assert_float(highest).is_equal_approx(RingBuilder.STEP_TOP_Y + 0.018, TOLERANCE)
	assert_float(nearest) \
			.override_failure_message(
				"the steps reach inside the apron square (%.2f < %.2f)"
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
	# 3.1 + 0.018. A rope running down X is swept to ROPE_END (2.86, inside
	# its pad) on that axis, which is the shorter of the two, so the
	# outermost geometry is the perpendicular offset of the rope.
	assert_float(reach).is_equal_approx(
			RingBuilder.ROPE_SPAN + RingBuilder.ROPE_RADIUS, 0.02)
	assert_float(highest).is_equal_approx(
			RingBuilder.ROPE_HEIGHT_TOP + RingBuilder.ROPE_RADIUS, 0.05)
	# The bottom rope sags, so the lowest geometry is below its own height.
	assert_float(lowest).is_between(
			RingBuilder.ROPE_HEIGHT_BOTTOM - RingBuilder.ROPE_RADIUS
			- RingBuilder.ROPE_SAG_BOTTOM - 0.01,
			RingBuilder.ROPE_HEIGHT_BOTTOM)
