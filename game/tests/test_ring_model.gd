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
	# The post is a round tube, so its nearest point to the mat along the
	# corner diagonal is its centre less the RADIUS -- not a square corner.
	var post_inner := RingBuilder.POST_XZ * diagonal - RingBuilder.POST_RADIUS
	var pad_centre := RingBuilder.TURNBUCKLE_PAD_XZ * diagonal
	var pad_inner := pad_centre - RingBuilder.TURNBUCKLE_PAD_DEPTH * 0.5
	# Clearance has to beat the BEVEL, not merely be positive. This failed as
	# a bare `is_less` check: at 2.2cm of clearance against a 4.5cm rounding,
	# the arithmetic said the pad cleared the post while every rendered
	# cushion carried a faint chevron where the post's corner came through its
	# rounded face. A bevel pulls the front of the box back by up to its own
	# width, so that is the margin the clearance has to exceed.
	var clearance := post_inner - pad_inner
	assert_float(clearance) \
		.override_failure_message(
			"the pad's inner face sits at u=%.3f and the post's inner corner "
			% pad_inner
			+ "at u=%.3f -- %.3f of clearance against a bevel of %.3f, so the "
			% [post_inner, clearance, RingBuilder.TURNBUCKLE_PAD_BEVEL]
			+ "post shows through the rounded face of the cushion") \
		.is_greater(RingBuilder.TURNBUCKLE_PAD_BEVEL)


## NO PAD CARRIES A CONNECTOR PLATE.
##
## The inverse of the test that used to stand here, and for the same reason:
## the plates were the only bare-steel surface above the apron, so at 0.10 x
## 0.085m against a black cushion each one resolved to a white block rather
## than to a bracket -- six per corner, brighter than the artwork they flanked.
## See the removal note in ring_builder.gd.
##
## Asserted off the shipped mesh, so a regenerated ring.glb that quietly
## brings them back fails here rather than in someone's screenshot.
func test_no_pad_carries_a_connector_plate() -> void:
	var root := _model()
	assert_object(root.find_child("TurnbuckleConnectors", true, false)) \
		.override_failure_message(
			"%s has a 'TurnbuckleConnectors' object again: the white " % MODEL
			+ "blocks are back on the turnbuckles") \
		.is_null()
	root.free()



## THE ARTWORK QUAD SITS ON THE FLAT OF THE PAD, not on its rounding.
##
## PAD_FACE_WIDTH/HEIGHT are written as literals because `tools/blender/
## venue.py` parses its constants out of this file and takes plain numbers
## only -- an expression there stops the ring exporting at all. This is what
## holds them to what they mean.
func test_the_pad_face_is_inset_by_the_bevel() -> void:
	assert_float(RingBuilder.PAD_FACE_WIDTH).is_equal_approx(
		RingBuilder.TURNBUCKLE_PAD_WIDTH
		- 2.0 * RingBuilder.TURNBUCKLE_PAD_BEVEL, 0.001)
	assert_float(RingBuilder.PAD_FACE_HEIGHT).is_equal_approx(
		RingBuilder.TURNBUCKLE_PAD_HEIGHT
		- 2.0 * RingBuilder.TURNBUCKLE_PAD_BEVEL, 0.001)


## EVERY ARTWORK QUAD FACES THE MAT.
##
## This one is measured on the shipped mesh, and it is here because the build
## got it wrong twice in two different ways, and neither way announced itself.
##
## First `venue.finish`'s `recalc_face_normals` reversed the authored winding:
## it finds the outside of a closed SOLID, and each of these quads is an open
## sheet that is its own connected component, so it had nothing to go on.
## Then, with the winding preserved, the tangent the quads were built from
## (`-sx, 0, sz`) flipped handedness with the parity of sx*sz, so two corners
## of four still came out backwards.
##
## Neither failure was visible as an absence, because the material is
## two-sided: a backwards quad renders its logo MIRRORED. On a letterform that
## is glaring once you look; on any tiling texture it would never have been
## caught at all. So it is asserted rather than eyeballed.
func test_every_pad_artwork_quad_faces_the_mat() -> void:
	var root := _model()
	var node := root.find_child("TurnbuckleFaces", true, false) as MeshInstance3D
	assert_object(node) \
		.override_failure_message("%s has no 'TurnbuckleFaces' object" % MODEL) \
		.is_not_null()
	var arrays := (node.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_int(normals.size()).is_equal(verts.size())
	var outward := 0
	for i in verts.size():
		# Inward is -position in the horizontal plane: the quads sit on the
		# corner diagonals and must look back at ring centre.
		var toward_centre := Vector3(-verts[i].x, 0.0, -verts[i].z).normalized()
		if normals[i].dot(toward_centre) <= 0.0:
			outward += 1
	assert_int(outward) \
		.override_failure_message(
			"%d of %d artwork vertices face away from the mat: those pads "
			% [outward, verts.size()]
			+ "render their logo mirrored") \
		.is_equal(0)
	root.free()


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


## THE STEPS POINT AT THE POSTS, on the corner diagonals.
##
## The owner's call, and how televised rings rig them: each flight's centre
## line is its corner's diagonal, the top tread squared across it at the
## apron's corner, so the flight meets the ring at 45 degrees to both sides.
## Measured on the shipped mesh in each flight's own frame: `u` along the
## diagonal from the ring's centre, `w` across it. The flight must span the
## diagonal from the apron's corner (plus the gap) out three treads, and stay
## within its width either side of the line -- a side-on flight fails both.
func test_the_steps_point_at_the_posts_on_the_diagonals() -> void:
	var plate := 0.03
	for corner: Vector2 in RingBuilder.STEP_CORNERS:
		var out := RingBuilder.step_out_dir(corner)
		var across := Vector3(-out.z, 0.0, out.x)
		var u_lo := INF
		var u_hi := -INF
		var w_max := 0.0
		var seen := 0
		for v: Vector3 in _verts("StepsMesh"):
			if signf(v.x) != signf(corner.x) or signf(v.z) != signf(corner.y):
				continue
			seen += 1
			var flat := Vector3(v.x, 0.0, v.z)
			u_lo = minf(u_lo, flat.dot(out))
			u_hi = maxf(u_hi, flat.dot(out))
			w_max = maxf(w_max, absf(flat.dot(across)))
		assert_int(seen).is_greater(0)
		var back := RingBuilder.APRON_OUT * sqrt(2.0) + RingBuilder.STEP_APRON_GAP
		assert_float(u_lo).override_failure_message(
				"the %s flight's top tread is %.3f out along its diagonal, not "
				% [corner, u_lo] + "against the apron's corner at %.3f" % back) \
				.is_equal_approx(back, 0.01)
		assert_float(u_hi).is_equal_approx(
				back + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS, 0.01)
		assert_float(w_max).override_failure_message(
				"the %s flight spreads %.3f off its diagonal: it is not square to it"
				% [corner, w_max]) \
				.is_less_equal(RingBuilder.STEP_WIDTH * 0.5 + plate)


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
	# The top tread is level with the apron; its side plates stand 4 cm proud.
	assert_float(highest).is_equal_approx(RingBuilder.STEP_TOP_Y + 0.04, TOLERANCE)
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
