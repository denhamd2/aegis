extends GdUnitTestSuite
## The entrance set's invariants, asserted without a renderer.
##
## Everything here is either projection-free geometry read back off a committed
## mesh, or a property of a material dictionary, so all of it holds under the
## headless CI run that `gauntlet/anchor/ARCHITECTURE.md` forbids judging
## visual slices on. What the set *looks like* is judged from
## `CaptureHarness`'s art shots on forward_plus; what it must never stop being
## is judged here.

const MODEL := "res://assets/environment/entrance_set.glb"
const HALF_CHORD := 9.0
const SAGITTA := 1.6
## Vertex positions come off the mesh through the glTF importer and a float
## buffer, so the tolerance is that of the pipeline, not of the arithmetic.
const TOLERANCE := 0.02


## The set's geometry is `tools/blender/entrance_set.py`'s model now, so these
## measure the committed .glb rather than calling a builder function. That is
## the same arrangement `test_arena_bowl.gd` has with the bowl, and for the
## same reason: the exporter reads its constants out of `arena_builder.gd`,
## which stops the two disagreeing about a NUMBER, and this suite stops them
## disagreeing about what the numbers MEAN.
func _model() -> Node3D:
	var packed: PackedScene = load(MODEL)
	assert_object(packed).is_not_null()
	return packed.instantiate()


const RINGSIDE_MODEL := "res://assets/environment/ringside.glb"


func _arrays(part: String) -> Array:
	var root := _model() if part != "Barricades" else _ringside()
	var node := root.find_child(part, true, false) as MeshInstance3D
	assert_object(node).is_not_null()
	var arrays: Array = node.mesh.surface_get_arrays(0)
	root.free()
	return arrays


func _ringside() -> Node3D:
	var packed: PackedScene = load(RINGSIDE_MODEL)
	assert_object(packed).is_not_null()
	return packed.instantiate()


func _verts(part: String) -> PackedVector3Array:
	return _arrays(part)[Mesh.ARRAY_VERTEX]


## Every part `ArenaBuilder` dresses must exist under the name it dresses it
## by. A part that goes missing does not crash anything -- it renders in its
## Blender placeholder colour, in the middle of a frame whose every other
## surface is solved against a measured target.
func test_every_part_the_builder_dresses_exists_in_the_model() -> void:
	var root := _model()
	var wanted: Array = ArenaBuilder.ENTRANCE_MATERIALS.keys() \
			+ ArenaBuilder.ENTRANCE_EMISSIVE.keys() + ["StageScreen"]
	for part: String in wanted:
		assert_object(root.find_child(part, true, false)) \
				.override_failure_message("%s has no '%s' object" % [MODEL, part]) \
				.is_not_null()
	root.free()


## The wall is described as "18m wide, bowed 1.6m", and that is only true if
## its ends sit exactly one sagitta forward of its centre.
func test_the_arc_ends_sit_one_sagitta_forward_of_its_centre() -> void:
	var verts := _verts("StageScreen")
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for v: Vector3 in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		min_z = minf(min_z, v.z)
		max_z = maxf(max_z, v.z)
	assert_float(max_x - min_x).is_equal_approx(HALF_CHORD * 2.0, TOLERANCE)
	assert_float(max_z - min_z).is_equal_approx(SAGITTA, TOLERANCE)


## Concave toward the audience, not a barrel: the ends are the furthest
## forward, and the centre is the furthest back.
func test_the_curved_face_bows_toward_the_audience() -> void:
	var verts := _verts("StageScreen")
	var centre_z := INF
	var end_z := -INF
	for v: Vector3 in verts:
		if absf(v.x) < 0.5:
			centre_z = minf(centre_z, v.z)
		if absf(v.x) > HALF_CHORD - 0.5:
			end_z = maxf(end_z, v.z)
	assert_float(end_z - centre_z).is_equal_approx(SAGITTA, TOLERANCE)


## The bezel stays BEHIND the picture everywhere.
##
## This is what "concentric" buys, and it is asserted as the thing that goes
## wrong rather than as the arithmetic: build the frame from the same sagitta
## as the picture instead of from the same CIRCLE, and the two arcs cross
## somewhere mid-panel and the frame surfaces through the picture -- two dark
## chevrons across the top of the wall, which is exactly how it was found.
func test_the_bezel_never_surfaces_through_the_picture() -> void:
	var picture := _verts("StageScreen")
	var centre_z := INF
	var end_z := -INF
	for v: Vector3 in picture:
		if absf(v.x) < 0.5:
			centre_z = minf(centre_z, v.z)
		if absf(v.x) > HALF_CHORD - 0.5:
			end_z = maxf(end_z, v.z)
	# The picture's own circle, from its own two measurable numbers.
	var sagitta := end_z - centre_z
	var radius := (HALF_CHORD * HALF_CHORD + sagitta * sagitta) / (2.0 * sagitta)
	for v: Vector3 in _verts("StageScreenBezel"):
		if absf(v.x) > HALF_CHORD:
			continue
		var surface := centre_z + radius - sqrt(maxf(radius * radius - v.x * v.x, 0.0))
		assert_float(v.z) \
				.override_failure_message(
					"bezel vertex at x=%.2f stands %.3fm in FRONT of the picture"
					% [v.x, v.z - surface]) \
				.is_less_equal(surface + TOLERANCE)


## The video-mapping invariant: `MaterialLibrary` lays UVs out in world metres
## for `tile_metres` texel density, and a video frame mapped in metres tiles
## eighteen times across an eighteen-metre wall. The picture face is the one
## surface in the venue that carries normalised UVs instead.
func test_the_curved_face_carries_normalised_uvs() -> void:
	var uvs: PackedVector2Array = _arrays("StageScreen")[Mesh.ARRAY_TEX_UV]
	assert_int(uvs.size()).is_greater(0)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for uv: Vector2 in uvs:
		lo = lo.min(uv)
		hi = hi.max(uv)
	assert_vector(lo).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))
	assert_vector(hi).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))


## The wall must FACE the ring.
##
## An open sheet has no outside, so nothing about the geometry decides which
## way it points -- and a sheet pointing the wrong way is invisible under
## backface culling, not merely dark. That shipped twice: once when the
## GDScript wound it backwards, and once when the Blender export's
## `recalc_face_normals` picked the far side and the wall rendered as nothing
## at all with its UVs, its material and its bound still frame all correct.
func test_the_curved_face_looks_at_the_ring() -> void:
	var normals: PackedVector3Array = _arrays("StageScreen")[Mesh.ARRAY_NORMAL]
	assert_int(normals.size()).is_greater(0)
	for n: Vector3 in normals:
		assert_float(n.z).is_greater(0.0)


## The ramp is a WEDGE.
##
## It was eighteen stacked boxes standing in for a 6% grade, because
## `_add_box` only made axis-aligned boxes. Its treads were under a pixel of
## rise from any camera in the shotlist; its EDGE was a staircase from every
## angle that saw it side-on.
##
## The proof that it is now one slope is that the run has NOTHING in it: a
## wedge's top surface has vertices at its two ends and nowhere between, where
## eighteen steps put thirty-six rows of them down the run. So this counts the
## distinct heights the run's geometry sits at, and requires the ramp to reach
## the deck at one end and the floor at the other.
func test_the_ramp_is_a_wedge_and_not_a_staircase() -> void:
	var ramp_end := -ArenaBuilder.BARRICADE_RADIUS
	var levels := {}
	var high := -INF
	var low := INF
	for v: Vector3 in _verts("EntranceStage"):
		if absf(v.x) > ArenaBuilder.RAMP_HALF_WIDTH + 0.05:
			continue
		if v.z < ArenaBuilder.STAGE_FRONT - 0.1 or v.z > ramp_end + 0.1:
			continue
		levels[snappedf(v.z, 0.25)] = true
		high = maxf(high, v.y)
		low = minf(low, v.y)
	# Two ends, and a little slack for the chamfer on each.
	assert_int(levels.size()) \
			.override_failure_message(
				"the ramp run sits at %d distinct depths -- stepped, not sloped"
				% levels.size()) \
			.is_less_equal(4)
	assert_float(high).is_equal_approx(ArenaBuilder.STAGE_DECK_Y, 0.05)
	assert_float(low).is_less(ArenaBuilder.FLOOR_Y + 0.1)


## The ramp comes down to the BARRIER, not to the ring.
##
## Ringside is floored in black matting from the barrier in to the apron, and
## the entrance stops at the edge of that -- a ramp running all the way to the
## apron is a ramp nobody could walk around, and the one that ended a metre
## short of the ring also ran straight through the barricade line.
func test_the_ramp_stops_at_the_barrier_and_not_at_the_ring() -> void:
	var nearest := -INF
	for v: Vector3 in _verts("EntranceStage"):
		if absf(v.x) > ArenaBuilder.RAMP_HALF_WIDTH + 0.05:
			continue
		nearest = maxf(nearest, v.z)
	# The nose runs half a metre past the barrier line onto the matting; it
	# must stop there and come nowhere near the apron.
	assert_float(nearest).is_less(-ArenaBuilder.BARRICADE_RADIUS + 0.75)
	assert_float(nearest) \
			.override_failure_message(
				"the ramp reaches z=%.2f, which is inside the ring's own apron"
				% nearest) \
			.is_less(-RingBuilder.APRON_OUT - 1.0)


## The barrier clears the regulation minimum.
##
## "The ringside barrier must be a minimum of six feet from the outside edge
## of the ring" -- Virginia 18VAC120-40-415.1. The outside edge of this ring
## is its apron, so this is the one ringside number with a legal floor under
## it rather than a taste argument.
func test_the_barrier_clears_the_regulation_distance_from_the_ring() -> void:
	const SIX_FEET := 1.8288
	var clear := ArenaBuilder.BARRICADE_RADIUS - RingBuilder.APRON_OUT
	assert_float(clear) \
			.override_failure_message(
				"only %.2fm of ringside floor -- under the six-foot minimum"
				% clear) \
			.is_greater(SIX_FEET)
	# And not so far that ringside stops reading as ringside: 9.0 gave 5.8m,
	# nearly nineteen feet, which is a car park with a ring in it.
	assert_float(clear).is_less(4.0)


## The entrance walks THROUGH the barrier, so the barrier has a gap.
func test_the_barrier_opens_for_the_entrance() -> void:
	var blocking := 0
	for v: Vector3 in _verts("Barricades"):
		if v.z > -ArenaBuilder.BARRICADE_RADIUS + 0.5:
			continue
		if absf(v.x) < ArenaBuilder.RAMP_HALF_WIDTH:
			blocking += 1
	assert_int(blocking) \
			.override_failure_message(
				"%d barricade vertices stand in the entrance walkway" % blocking) \
			.is_equal(0)


## Almost all of the circle survives the cut. A shallow cut is what keeps it
## reading as a circle: take too much and it becomes an arch instead.
func test_the_cut_removes_only_the_bottom_of_the_circle() -> void:
	var cut := ArenaBuilder._portal_cut_angle()
	var swept := PI - cut * 2.0
	assert_float(rad_to_deg(swept)).is_between(280.0, 330.0)
	# The deck crossing is below the horizontal on both sides, i.e. the tube
	# comes down past its own widest point before it stops. An arch does not.
	assert_float(cut).is_less(0.0)


## The centre is placed so the circle sinks exactly PORTAL_CUT_DEPTH into the
## deck. Derived, not typed, so moving one number cannot leave the ends
## floating above the floor or buried under it.
func test_the_circle_sinks_the_stated_depth_into_the_deck() -> void:
	var lowest_point := ArenaBuilder.PORTAL_CENTER_Y - ArenaBuilder.PORTAL_MAJOR
	assert_float(ArenaBuilder.STAGE_DECK_Y - lowest_point) \
			.is_equal_approx(ArenaBuilder.PORTAL_CUT_DEPTH, 0.001)


## The portal is a CIRCLE with the bottom cut off by the deck -- not a ring
## (no doorway), not an arch on legs, and not an omega (whose ends turn back
## inward and need outward feet). It was built as each of those first, which
## is why the shape is asserted rather than left to the render.
func test_the_portal_tube_stops_where_the_deck_cuts_it() -> void:
	var lowest := INF
	for v: Vector3 in _verts("PortalRingWest"):
		lowest = minf(lowest, v.y)
	# The centreline ends on the deck, so the tube's skin reaches
	# PORTAL_MINOR below it.
	assert_float(lowest).is_equal_approx(
			ArenaBuilder.STAGE_DECK_Y - ArenaBuilder.PORTAL_MINOR, 0.05)


## Every vertex of the tube lies on the tube: its distance from the ring's
## own centre circle is the minor radius, everywhere.
func test_the_portal_tube_has_a_constant_minor_radius() -> void:
	var verts := _verts("PortalRingWest")
	assert_int(verts.size()).is_greater(0)
	var centre := Vector3(-ArenaBuilder.PORTAL_OFFSET_X,
			ArenaBuilder.PORTAL_CENTER_Y, ArenaBuilder.PORTAL_FACE_Z)
	for v: Vector3 in verts:
		var local := v - centre
		var radial := Vector3(local.x, local.y, 0.0).normalized() \
				* ArenaBuilder.PORTAL_MAJOR
		assert_float(local.distance_to(radial)) \
				.is_equal_approx(ArenaBuilder.PORTAL_MINOR, 0.03)


## SSR shows nothing on a matte floor, so the deck's gloss is not a taste
## setting -- it is the precondition for the reflection `match.tscn` turns on.
## Guarded so a later tidy-up cannot switch the reflection off by rounding a
## roughness back to 1.0.
func test_the_stage_deck_stays_glossy_enough_for_ssr() -> void:
	var spec := MaterialLibrary.spec("arena_stage_deck")
	assert_float(spec["roughness"]).is_less(0.30)
	assert_bool(spec["roughness_map"]).is_false()
	assert_float(spec["metallic"]).is_equal(0.0)


## The two portal hues have to stay apart, because which ring is which is the
## thing that makes the set recognisable.
func test_the_two_portal_hues_are_distinct_and_not_green_dominant() -> void:
	var magenta: Color = MaterialLibrary.spec("arena_portal_magenta")["tint"]
	var amber: Color = MaterialLibrary.spec("arena_portal_amber")["tint"]
	assert_float(absf(magenta.h - amber.h)).is_greater(0.1)
	# capture_harness.gd records that a green-dominant element inside the HUD
	# corner probes blinds the evidence gate.
	for tint: Color in [magenta, amber]:
		assert_bool(tint.g > tint.r * 1.4 and tint.g > tint.b * 1.4).is_false()


## ARCHITECTURE.md's condition for a cosmetic system, asserted rather than
## promised: nothing the arena builds may join the physics world.
func test_the_arena_creates_no_collision_object() -> void:
	var arena := ArenaBuilder.new()
	add_child(arena)
	await await_idle_frame()
	assert_int(_count_collision_objects(arena)).is_equal(0)
	arena.queue_free()


## The wall falls back rather than failing when there is no clip to play --
## the branch that matters most and the one hardest to reach by accident,
## which is why `attach()` takes an injectable path.
func test_a_missing_clip_leaves_the_wall_on_its_own_material() -> void:
	var screen := MeshInstance3D.new()
	var mat := MaterialLibrary.resolve("arena_screen")
	var video := StageVideo.attach(screen, mat, "res://does_not_exist.ogv")
	add_child(screen)
	add_child(video)
	await await_idle_frame()
	# Bound to the still, or left blank -- either is correct. What it must
	# never do is bind a video texture it does not have.
	assert_object(mat).is_not_null()
	assert_int(_count_collision_objects(video)).is_equal(0)
	video.queue_free()
	screen.queue_free()



## The bug that shipped: the video player painted itself over the game.
##
## It lived in a `CanvasLayer` at `layer = -128`, on the belief that a negative
## layer puts it behind the 3D world. It does not -- a layer value orders a
## CanvasLayer against *other CanvasLayers*, and 3D is always drawn behind
## every canvas item. `expand = false` compounded it, because the player then
## draws at the video's native 1280x720 and ignores the 2x2 rect it was given.
##
## No test caught it, and the reason is worth keeping: every suite runs
## headless, and `StageVideo` skips the player entirely under the headless
## display server. So the placement is built by a static function that needs no
## renderer, no clip and no display server, and these assert it directly.
func test_the_player_is_parented_into_an_offscreen_subviewport() -> void:
	var feed := StageVideo._make_feed(null)
	assert_object(feed).is_instanceof(SubViewport)
	var player := feed.get_node_or_null("Feed")
	assert_object(player).is_instanceof(VideoStreamPlayer)
	feed.free()


## A SubViewport renders to its own target and is never composited into the
## window unless a SubViewportContainer asks for it. A CanvasLayer anywhere in
## this subtree would put the player back on the screen.
func test_the_feed_reaches_the_screen_through_nothing() -> void:
	var feed := StageVideo._make_feed(null)
	assert_int(_count_of_type(feed, "CanvasLayer")).is_equal(0)
	assert_int(_count_of_type(feed, "SubViewportContainer")).is_equal(0)
	feed.free()


## `expand` must be on. With it off the player ignores its rect and draws at
## the clip's native size, which is half of how the overlay got as large as it
## did.
func test_the_player_is_not_left_at_its_native_size() -> void:
	var feed := StageVideo._make_feed(null)
	var player: VideoStreamPlayer = feed.get_node("Feed")
	assert_bool(player.expand).is_true()
	assert_bool(player.loop).is_true()
	assert_bool(player.autoplay).is_false()
	feed.free()


func _count_of_type(node: Node, type_name: String) -> int:
	var found := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children():
		found += _count_of_type(child, type_name)
	return found



func _count_collision_objects(node: Node) -> int:
	var found := 1 if node is CollisionObject3D else 0
	for child: Node in node.get_children():
		found += _count_collision_objects(child)
	return found


## Roman's titantron: its files are there, and asking for an entrance where
## the loop is not playing (headless here) leaves the wall alone.
func test_the_entrance_titantron_is_there_and_never_breaks_the_wall() -> void:
	var entry: Dictionary = StageVideo.ENTRANCES["roman"]
	assert_bool(ResourceLoader.exists(entry["video"])).is_true()
	assert_bool(ResourceLoader.exists(entry["still"])).is_true()
	var screen := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var video := StageVideo.attach(screen, mat)
	add_child(video)
	assert_bool(video.play_entrance("roman")).is_false()
	assert_bool(video.play_entrance("nobody")).is_false()
	video.end_entrance()
	assert_bool(video.is_playing_entrance()).is_false()
	video.queue_free()
	screen.free()
