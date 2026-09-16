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


## THE STEPS STAND AT A CORNER, running out to the apron's own corner.
##
## They used to sit halfway down each side, offset 0.35m along Z for no reason
## the file gave. That is not where ring steps go: the regulation that governs
## them asks for "suitable steps for use of the contestants in their corners"
## (Virginia 18VAC120-40-415.1; Hawaii 16-74-295 puts it as two opposite
## corners), and on television the two sets stand tight against a post with
## their top tread level with the apron, so a wrestler climbing them steps
## over the top rope right beside the turnbuckle.
##
## Then they stood 0.10 SHORT of the post with a square top tread, which is at
## the corner without being in it. The flight now runs out to APRON_OUT and
## the top tread is notched to pass the post -- see STEP_CORNER_NOTCH.
func test_the_steps_stand_at_a_corner_beside_a_post() -> void:
	# Measured as the flight's EXTENT, not as the mean of its vertices. The
	# mean was what stood here, and it moved by 7cm when the top tread was
	# notched -- because a notch redistributes vertices without moving the
	# flight at all. An extent says the thing the test is named for: the far
	# end reaches the apron's corner and the near end is a tread width back.
	var stringer := 0.012
	var far: float = RingBuilder.APRON_OUT
	var near: float = far - RingBuilder.STEP_WIDTH
	for sign: float in [1.0, -1.0]:
		var lo := INF
		var hi := -INF
		var seen := 0
		for v: Vector3 in _verts("StepsMesh"):
			if signf(v.x) != sign:
				continue
			seen += 1
			lo = minf(lo, absf(v.z))
			hi = maxf(hi, absf(v.z))
		assert_int(seen).is_greater(0)
		assert_float(hi) \
			.override_failure_message(
				"the %sX flight ends at |z|=%.3f; the apron's corner is at "
				% ["+" if sign > 0.0 else "-", hi]
				+ "%.3f, so the steps stop short of it" % far) \
			.is_equal_approx(far + stringer, 0.03)
		assert_float(lo) \
			.override_failure_message(
				"the %sX flight starts at |z|=%.3f, not a tread width (%.3f) "
				% ["+" if sign > 0.0 else "-", lo, RingBuilder.STEP_WIDTH]
				+ "back from the corner at %.3f" % near) \
			.is_equal_approx(near - stringer, 0.03)


## THE TOP TREAD IS NOTCHED, so the flight passes the ring post.
##
## The detail every ring-steps casting has and the build did not: a 45-degree
## corner missing from the top tread. Without it a flight can only stop beside
## a corner, which is where these used to stand.
##
## Asserted as an ABSENCE off the shipped mesh -- no vertex of the top tread
## lies inside the triangle the cut removes. A test that counted geometry, or
## checked the flight's bounding box, would pass just as well on a square
## tread, which is the shape this is here to rule out.
func test_the_top_tread_is_notched_for_the_post() -> void:
	var notch: float = RingBuilder.STEP_CORNER_NOTCH
	var inner: float = RingBuilder.APRON_OUT + RingBuilder.STEP_APRON_GAP
	var far: float = RingBuilder.APRON_OUT
	# The top tread alone: everything above the last riser's midpoint.
	var rise: float = (RingBuilder.STEP_TOP_Y - RingBuilder.STEP_FLOOR_Y) \
			/ float(RingBuilder.STEP_TREADS)
	var tread_top: float = RingBuilder.STEP_TOP_Y - rise * 0.5
	# 1mm, so a vertex sitting exactly ON the diagonal counts as on the cut
	# rather than inside it.
	var margin := 0.001
	for v: Vector3 in _verts("StepsMesh"):
		if v.y < tread_top:
			continue
		var dx: float = absf(v.x) - inner
		var dz: float = far - absf(v.z)
		if dx < -margin or dz < -margin:
			continue
		assert_float(dx + dz) \
			.override_failure_message(
				"a top-tread vertex sits %.3f into the corner the notch "
				% (notch - dx - dz)
				+ "removes (%.3f from the inner face, %.3f from the end, "
				% [dx, dz]
				+ "against a %.3f notch): the tread is still square" % notch) \
			.is_greater_equal(notch - margin)


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
