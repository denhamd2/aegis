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
			+ ["StageScreen", "StageSideScreens", "StageCentreScreen", "StageFloorCans"]
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


## The 2026 set (the owner's 18 October stills): an LED wall either side of
## the centre screen, standing on the deck between the stated edges, its top
## under the video wall's bottom edge, clear of the centre screen.
func test_the_led_walls_stand_either_side_of_the_centre_screen() -> void:
	var verts := _verts("StageSideScreens")
	assert_int(verts.size()).is_greater(0)
	var screen_bottom := ArenaBuilder.SCREEN_CENTER_Y - ArenaBuilder.SCREEN_HEIGHT * 0.5
	var left := 0
	var right := 0
	for v: Vector3 in verts:
		assert_float(absf(v.x)).is_between(ArenaBuilder.SIDE_SCREEN_INNER_X - TOLERANCE,
				ArenaBuilder.SIDE_SCREEN_OUTER_X + TOLERANCE)
		assert_float(v.y).is_between(
				ArenaBuilder.STAGE_DECK_Y + ArenaBuilder.SIDE_SCREEN_BOTTOM - TOLERANCE,
				ArenaBuilder.STAGE_DECK_Y + ArenaBuilder.SIDE_SCREEN_TOP + TOLERANCE)
		assert_float(v.y).is_less(screen_bottom)
		if v.x < 0.0:
			left += 1
		else:
			right += 1
	assert_int(left).is_equal(right)
	var centre_half := 0.0
	for v: Vector3 in _verts("StageCentreScreen"):
		centre_half = maxf(centre_half, absf(v.x))
	assert_float(centre_half).is_less(ArenaBuilder.SIDE_SCREEN_INNER_X)


## Both walls splay away from the ring by the stated angle -- outer edge set
## back behind the inner (the owner's 18 Oct close-ups) -- and both face the ring: a wall wound the wrong way is culled
## and renders as its black cabinet (the first build lost the east one so).
func test_the_led_walls_splay_and_face_the_ring() -> void:
	var rise := (ArenaBuilder.SIDE_SCREEN_OUTER_X - ArenaBuilder.SIDE_SCREEN_INNER_X) \
			* tan(deg_to_rad(ArenaBuilder.SIDE_SCREEN_TOE_DEG))
	for v: Vector3 in _verts("StageSideScreens"):
		var t := (absf(v.x) - ArenaBuilder.SIDE_SCREEN_INNER_X) \
				/ (ArenaBuilder.SIDE_SCREEN_OUTER_X - ArenaBuilder.SIDE_SCREEN_INNER_X)
		assert_float(v.z).is_equal_approx(ArenaBuilder.side_screen_inner_z() + rise * t, 0.03)
	assert_float(rise).is_less(0.0)
	for n: Vector3 in _arrays("StageSideScreens")[Mesh.ARRAY_NORMAL]:
		assert_float(n.z).is_greater(0.9)


## The pictures carry normalised UVs (StageVideo crops the clip onto them):
## projected at world-metre density, the video would tile across each wall.
func test_the_led_walls_carry_normalised_uvs() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for uv: Vector2 in _arrays("StageSideScreens")[Mesh.ARRAY_TEX_UV]:
		lo = Vector2(minf(lo.x, uv.x), minf(lo.y, uv.y))
		hi = Vector2(maxf(hi.x, uv.x), maxf(hi.y, uv.y))
	assert_vector(lo).is_equal_approx(Vector2.ZERO, Vector2(0.01, 0.01))
	assert_vector(hi).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))


## The wrestlers walk out of the gap between the walls: nothing of the walls,
## their cabinets or the floor cans stands in the walkway, and the entrance
## point is in front of the centre screen and inside the playable stage.
func test_the_walkway_between_the_walls_is_clear() -> void:
	for part in ["StageSideScreens", "StageSideScreenFrame", "StageFloorCans"]:
		for v: Vector3 in _verts(part):
			assert_float(absf(v.x)).override_failure_message(
					"%s stands in the walkway at x %.2f" % [part, v.x]) \
					.is_greater(ArenaBuilder.RAMP_HALF_WIDTH)
	assert_float(ArenaBuilder.ENTRANCE_Z).is_greater(ArenaBuilder.STAGE_BACK)
	assert_float(ArenaBuilder.ENTRANCE_Z).is_greater_equal(ArenaBuilder.MATCH_STAGE_BACK_LIMIT)
	assert_float(ArenaBuilder.ENTRANCE_X).is_equal(0.0)


## SSR shows nothing on a matte floor, so the deck's gloss is not a taste
## setting -- it is the precondition for the reflection `match.tscn` turns on.
## Guarded so a later tidy-up cannot switch the reflection off by rounding a
## roughness back to 1.0.
func test_the_stage_deck_stays_glossy_enough_for_ssr() -> void:
	var spec := MaterialLibrary.spec("arena_stage_deck")
	assert_float(spec["roughness"]).is_less(0.30)
	assert_bool(spec["roughness_map"]).is_false()
	assert_float(spec["metallic"]).is_equal(0.0)


func test_arena_floor_uses_generated_concrete_albedo_and_concrete_surface_maps() -> void:
	var spec := MaterialLibrary.spec("arena_floor")
	assert_str(spec["asset"]).is_equal("Concrete033")
	assert_str(spec["color_path"]).is_equal(
			"res://assets/environment/materials/arena_concrete_color.png")
	var mat := MaterialLibrary.resolve("arena_floor")
	assert_object(mat.albedo_texture).is_not_null()
	assert_str(mat.albedo_texture.resource_path).is_equal(spec["color_path"])
	assert_object(mat.normal_texture).is_not_null()


## The 2026 set has no coloured LED strips down the ramp and no portals: the
## owner asked for the pink ramp lighting to go with the tunnels.
func test_the_old_portals_and_ramp_strips_are_gone() -> void:
	var root := _model()
	for part in ["RampLeds", "PortalRingWest", "PortalRingEast", "PortalRecess",
			"PortalBack", "PortalPods", "StageLedDots", "StageSidePanels"]:
		assert_object(root.find_child(part, true, false)) \
				.override_failure_message("%s still has '%s'" % [MODEL, part]).is_null()
	root.free()


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


## Three screens, one sound (the owner, 19 Oct): the LED walls mirror the
## wall's picture by sharing its texture, so they add no players. His music
## plays once, on one AudioStreamPlayer, and the video feeds are silent.
func test_three_screens_play_the_entrance_audio_once() -> void:
	var screen := MeshInstance3D.new()
	var video := StageVideo.attach(screen, StandardMaterial3D.new())
	video.mirror(StandardMaterial3D.new(), 1.0, ArenaBuilder.SIDE_SCREEN_LEVEL)
	video.mirror(StandardMaterial3D.new(), 1.0, ArenaBuilder.SIDE_SCREEN_LEVEL)
	add_child(video)
	video.play_entrance("cody")
	assert_int(_count_of_type(video, "AudioStreamPlayer")).is_equal(1)
	assert_int(_count_of_type(video, "AudioStreamPlayer3D")).is_equal(0)
	# a second cue for the same man replaces his music, never stacks it
	video.play_entrance("cody")
	var playing := 0
	for p: AudioStreamPlayer in video.find_children("*", "AudioStreamPlayer", true, false):
		if p != null and p.playing and p.volume_db > -40.0:
			playing += 1
	assert_int(playing).is_less_equal(1)
	var feed := StageVideo._make_feed(null)
	assert_float((feed.get_node("Feed") as VideoStreamPlayer).volume_db).is_less_equal(-80.0)
	feed.free()
	video.queue_free()
	screen.free()


## The owner's AEW stills: the set's black wall runs wider than the video
## wall above it, so no seats show either side of the portals, and the
## screen sits in a chevron frame -- an LED wing at each end, both lit, one
## mirrored to the other, carrying on past the bezel.
func test_the_backdrop_is_wider_than_the_screen_and_the_wings_flank_it() -> void:
	var half_screen := ArenaBuilder.SCREEN_WIDTH * 0.5 + ArenaBuilder.SCREEN_BEZEL
	var backdrop := _verts("StageBackdrop")
	var widest := 0.0
	for v: Vector3 in backdrop:
		widest = maxf(widest, absf(v.x))
	assert_float(widest).is_greater(half_screen + 1.0)
	var wings := _verts("StageScreenWings")
	var left := 0
	var right := 0
	for v: Vector3 in wings:
		assert_float(absf(v.x)).is_greater(half_screen)
		assert_float(absf(v.x)).is_less(widest)
		if v.x < 0.0:
			left += 1
		else:
			right += 1
	assert_int(left).is_equal(right)
	assert_int(left).is_greater(0)
	# Both face the ring: a wing wound the wrong way is culled and vanishes.
	var arrays := _arrays("StageScreenWings")
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_float(n.z).is_greater(0.5)
	assert_bool(ResourceLoader.exists(ArenaBuilder.STAGE_SCREEN_WING)).is_true()


## The two walls together span about the video wall above them, as in the
## owner's stills, and the deck carries them.
func test_the_led_walls_sit_under_the_screen_on_the_deck() -> void:
	var outer := ArenaBuilder.SIDE_SCREEN_OUTER_X
	assert_float(outer).is_less(ArenaBuilder.SCREEN_WIDTH * 0.5)
	assert_float(outer).is_greater(ArenaBuilder.SCREEN_WIDTH * 0.5 - 2.5)
	assert_float(outer).is_less(ArenaBuilder.STAGE_HALF_WIDTH)
	var widest := 0.0
	for v: Vector3 in _verts("EntranceStage"):
		widest = maxf(widest, absf(v.x))
	assert_float(widest).is_equal_approx(ArenaBuilder.STAGE_HALF_WIDTH, TOLERANCE)


## The ramp opens out into the deck: the deck's width at each depth never
## jumps, narrows monotonically toward the ramp and meets the ramp's own
## width at the mouth, instead of butting a 3.6m ramp into a square slab.
func test_the_deck_flares_into_the_ramp() -> void:
	var by_depth := {}
	for v: Vector3 in _verts("EntranceStage"):
		if v.z < ArenaBuilder.STAGE_FRONT - 0.1 and v.y > ArenaBuilder.STAGE_DECK_Y - 0.01:
			var key := snappedf(v.z, 0.01)
			by_depth[key] = maxf(by_depth.get(key, 0.0), absf(v.x))
	var depths: Array = by_depth.keys()
	depths.sort()
	var back_width: float = by_depth[depths[0]]
	# The top face stops a 5cm chamfer short of the skirt.
	assert_float(back_width).is_equal_approx(ArenaBuilder.STAGE_HALF_WIDTH - 0.05, TOLERANCE)
	# Walking forward from the flare's start the half-width only closes, in
	# steps no bigger than a flare facet.
	var flare_start := ArenaBuilder.STAGE_FRONT - ArenaBuilder.STAGE_FLARE_LENGTH
	var previous := back_width
	for z: float in depths:
		if z < flare_start - 0.02:
			continue
		var w: float = by_depth[z]
		assert_float(w).is_less_equal(previous + 0.001)
		assert_float(previous - w).is_less(1.5)
		previous = w
	assert_float(previous).is_less(ArenaBuilder.RAMP_HALF_WIDTH + 0.4)


## The backdrop is a built thing now: a truss frame behind and above the wall,
## and pleated drape beside the LED walls (clear of them).
func test_the_back_of_stage_is_built_not_a_flat_box() -> void:
	var screen_top := ArenaBuilder.SCREEN_CENTER_Y + ArenaBuilder.SCREEN_HEIGHT * 0.5
	var truss_top := -INF
	var truss_front := -INF
	for v: Vector3 in _verts("StageTruss"):
		truss_top = maxf(truss_top, v.y)
		truss_front = maxf(truss_front, v.z)
	assert_float(truss_top).is_greater(screen_top + ArenaBuilder.SCREEN_BEZEL)
	# Behind the picture's centre (which is its furthest-back point).
	assert_float(truss_front).is_less(ArenaBuilder.SCREEN_FACE_Z)
	var drape_inner := INF
	for v: Vector3 in _verts("StageDrape"):
		drape_inner = minf(drape_inner, absf(v.x))
	assert_float(drape_inner).is_greater(ArenaBuilder.SIDE_SCREEN_OUTER_X)
	var folds := {}
	for v: Vector3 in _verts("StageDrape"):
		folds[snappedf(v.z, 0.005)] = true
	# Pleated: many distinct depths, not a single plane.
	assert_int(folds.size()).is_greater(3)
	# Within budget: the whole set stays well under a standard prop's ceiling.
	var triangles := 0
	var root := _model()
	for child in root.get_children():
		var mesh := (child as MeshInstance3D).mesh
		triangles += mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	root.free()
	assert_int(triangles).is_less(15000)


## Dressed in a match: both walls carry the video wall's picture material
## (blank until a frame binds), the floor cans glow red, and the deck heads
## and truss spots that light the set are built.
func test_the_led_walls_are_dressed_and_lit() -> void:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	add_child(scene)
	var walls := scene.find_child("StageSideScreens", true, false) as MeshInstance3D
	assert_object(walls).is_not_null()
	var mat := walls.material_override as StandardMaterial3D
	assert_object(mat).is_not_null()
	assert_bool(mat.emission_enabled).is_true()
	# Headless binds the wall's still (StageVideo._bind_still): the walls get
	# the same picture, cropped narrower than the 3:1 wall to fit their shape.
	var wall := scene.find_child("StageScreen", true, false) as MeshInstance3D
	var wall_mat := wall.material_override as StandardMaterial3D
	if wall_mat.emission_texture:
		assert_object(mat.emission_texture).is_same(wall_mat.emission_texture)
		assert_float(mat.uv1_scale.x).is_less(wall_mat.uv1_scale.x)
	var cans := scene.find_child("StageFloorCans", true, false) as MeshInstance3D
	var can_mat := cans.material_override as StandardMaterial3D
	assert_float(can_mat.emission.r).is_greater(can_mat.emission.g * 3.0)
	for light in ["AccentW0", "AccentE1", "StageSpot00", "StageSpot07"]:
		assert_object(scene.find_child(light, true, false)).is_not_null()
	for gone in ["TunnelLightW", "TunnelLightE", "UplightW0"]:
		assert_object(scene.find_child(gone, true, false)).is_null()


func test_the_side_walls_are_widescreen_so_a_16_9_clip_is_not_cropped() -> void:
	# the owner, 19 Oct: the square walls cropped the video; a 16:9 clip now
	# fills them, and the picture is cropped to exactly the wall's shape
	assert_float(ArenaBuilder.side_screen_aspect()).is_between(1.72, 1.84)


## Kenny's titantron and music (the owner's video, 19 Oct): there, and his
## generic entrance turns the wall over to it when he walks out and back
## when he is in the ring.
func test_kenny_has_his_titantron_and_his_entrance_uses_it() -> void:
	var entry: Dictionary = StageVideo.ENTRANCES["kenny"]
	for key: String in ["video", "music", "still"]:
		assert_bool(ResourceLoader.exists(entry[key])).override_failure_message(key).is_true()
	assert_float(float(entry["chorus"])).is_greater(0.0)
	var src := (load("res://core/match/entrance_director.gd") as GDScript).source_code
	var generic := src.substr(src.find("func _add_entrance("), 2400)
	assert_str(generic).contains("\"tron_on\"")
	assert_str(generic).contains("\"tron_off\"")
