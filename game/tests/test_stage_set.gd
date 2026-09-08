extends GdUnitTestSuite
## The entrance set's invariants, asserted without a renderer.
##
## Everything here is either projection-free geometry read back off a committed
## mesh, or a property of a material dictionary, so all of it holds under the
## headless CI run that `gauntlet/anchor/ARCHITECTURE.md` forbids judging
## visual slices on. What the set *looks like* is judged from
## `CaptureHarness`'s art shots on forward_plus; what it must never stop being
## is judged here.

const HALF_CHORD := 9.0
const SAGITTA := 1.6


## R = (c^2 + s^2) / 2s, worked by hand for the wall's own numbers:
## (81 + 2.56) / 3.2 = 26.1125.
func test_arc_radius_comes_off_the_chord_and_the_sagitta() -> void:
	assert_float(ArenaBuilder._arc_radius(HALF_CHORD, SAGITTA)) \
			.is_equal_approx(26.1125, 0.001)


## The two ends of the arc sit exactly one sagitta forward of its centre.
## This is the property the whole panel is specified by -- the wall is
## described as "18m wide, bowed 1.6m", which is only true if this holds.
func test_the_arc_ends_sit_one_sagitta_forward_of_its_centre() -> void:
	var radius := ArenaBuilder._arc_radius(HALF_CHORD, SAGITTA)
	var phi_max := asin(HALF_CHORD / radius)
	assert_float(ArenaBuilder._arc_offset(0.0, radius)).is_equal_approx(0.0, 0.0001)
	assert_float(ArenaBuilder._arc_offset(phi_max, radius)) \
			.is_equal_approx(SAGITTA, 0.001)
	assert_float(ArenaBuilder._arc_offset(-phi_max, radius)) \
			.is_equal_approx(SAGITTA, 0.001)


## `_sagitta_for` inverts `_arc_radius`, which is what keeps the bezel
## concentric with the picture it frames. Building both from the same sagitta
## puts them on two different circles that cross mid-panel, and the frame
## surfaces through the picture -- two dark chevrons across the top of the
## wall, which is exactly how this was found.
func test_sagitta_for_inverts_arc_radius() -> void:
	var radius := ArenaBuilder._arc_radius(HALF_CHORD, SAGITTA)
	assert_float(ArenaBuilder._sagitta_for(radius, HALF_CHORD)) \
			.is_equal_approx(SAGITTA, 0.001)


## The video-mapping invariant, and the reason `_add_curved_face` exists at
## all: `_add_box` lays UVs out in world metres for `tile_metres` texel
## density, and a video frame mapped in metres tiles eighteen times across an
## eighteen-metre wall.
func test_the_curved_face_carries_normalised_uvs() -> void:
	var arrays := _face_arrays()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_int(uvs.size()).is_greater(0)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for uv: Vector2 in uvs:
		lo = lo.min(uv)
		hi = hi.max(uv)
	assert_vector(lo).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))
	assert_vector(hi).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))


## Concave toward the audience, not a barrel: every vertex is at or in front
## of the panel's centre plane, and the ends are the furthest forward.
func test_the_curved_face_bows_toward_the_audience() -> void:
	var arrays := _face_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_z := INF
	var max_z := -INF
	for v: Vector3 in verts:
		min_z = minf(min_z, v.z)
		max_z = maxf(max_z, v.z)
	assert_float(min_z).is_equal_approx(-22.9, 0.001)
	assert_float(max_z).is_equal_approx(-22.9 + SAGITTA, 0.01)


## Front faces are what the audience sees. Godot's front faces are clockwise,
## and the whole wall was invisible in the first render of this set because
## these were wound the other way -- the geometry, the UVs and the material
## were all correct and the panel was being culled. `_add_quad` owns the
## winding now; this asserts it stayed owned.
func test_the_curved_face_is_wound_front_out() -> void:
	var arrays := _face_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_int(verts.size() % 3).is_equal(0)
	for i: int in range(0, verts.size(), 3):
		var geometric := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		# Clockwise from the front means the cross product opposes the shading
		# normal. Both must point somewhere down -Z / +Z respectively, i.e.
		# the two must disagree, consistently, on every triangle.
		assert_float(geometric.normalized().dot(normals[i])).is_less(0.0)
		assert_float(normals[i].z).is_greater(0.0)


## The portal is a CIRCLE with the bottom cut off by the deck -- not a ring
## (no doorway), not an arch on legs, and not an omega (whose ends turn back
## inward and need outward feet). It was built as each of those first, which
## is why the shape is asserted rather than left to the render.
##
## Two properties say it: the tube stops exactly at the deck, and it is still
## a circle everywhere it exists.
func test_the_portal_tube_stops_where_the_deck_cuts_it() -> void:
	var verts := _portal_arc_vertices()
	var lowest := INF
	for v: Vector3 in verts:
		lowest = minf(lowest, v.y)
	# The lowest geometry is the deck crossing, give or take the tube's own
	# radius -- the centreline ends on the deck, so the tube's skin reaches
	# PORTAL_MINOR below it.
	assert_float(lowest).is_equal_approx(
			ArenaBuilder.STAGE_DECK_Y - ArenaBuilder.PORTAL_MINOR, 0.05)


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


## Every vertex of the tube lies on the tube: distance from the ring's
## centre circle is the minor radius, everywhere.
func test_the_portal_tube_has_a_constant_minor_radius() -> void:
	var st := ArenaBuilder._new_surface()
	ArenaBuilder._add_arc_tube(st, Vector3.ZERO, ArenaBuilder.PORTAL_MAJOR,
			ArenaBuilder.PORTAL_MINOR, 0.0, PI,
			ArenaBuilder.PORTAL_RING_SEGMENTS, ArenaBuilder.PORTAL_TUBE_SIDES)
	var verts: PackedVector3Array = st.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		var radial := Vector3(v.x, v.y, 0.0).normalized() * ArenaBuilder.PORTAL_MAJOR
		assert_float(v.distance_to(radial)) \
				.is_equal_approx(ArenaBuilder.PORTAL_MINOR, 0.001)


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


## The portal arc as the builder makes it: swept between the two deck
## crossings, about a centre at the height the builder places it.
func _portal_arc_vertices() -> PackedVector3Array:
	var st := ArenaBuilder._new_surface()
	var cut := ArenaBuilder._portal_cut_angle()
	ArenaBuilder._add_arc_tube(st,
			Vector3(0.0, ArenaBuilder.PORTAL_CENTER_Y, 0.0),
			ArenaBuilder.PORTAL_MAJOR, ArenaBuilder.PORTAL_MINOR,
			cut, PI - cut, ArenaBuilder.PORTAL_RING_SEGMENTS,
			ArenaBuilder.PORTAL_TUBE_SIDES)
	return st.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


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


func _face_arrays() -> Array:
	var st := ArenaBuilder._new_surface()
	ArenaBuilder._add_curved_face(st, Vector3(0.0, 9.35, -22.9), HALF_CHORD * 2.0,
			6.0, SAGITTA, 24)
	return st.commit().surface_get_arrays(0)


func _count_collision_objects(node: Node) -> int:
	var found := 1 if node is CollisionObject3D else 0
	for child: Node in node.get_children():
		found += _count_collision_objects(child)
	return found
