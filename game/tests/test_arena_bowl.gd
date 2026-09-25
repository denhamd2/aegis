extends GdUnitTestSuite
## The Blender bowl's invariants, asserted without a renderer.
##
## `tools/blender/arena_bowl.py` builds the bowl mesh and `ArenaBuilder` stands
## the ringside chairs on it. They are two programs in two languages, and the
## whole risk of that arrangement is that they stop agreeing -- the exporter
## reads its constants out of `arena_builder.gd`, which stops them disagreeing
## about a NUMBER, and this suite stops them disagreeing about what the
## numbers MEAN.
##
## So every test here measures the committed .glb against arithmetic done in
## GDScript. If the model is rebuilt from changed constants and this file still
## passes, every seat and chair is still standing on a tread.

const MODEL := "res://assets/environment/arena_bowl.glb"
## Vertex positions come off the mesh through the glTF importer and a float
## buffer, so the tolerance is that of the pipeline, not of the arithmetic.
const TOLERANCE := 0.02


func _model() -> Node3D:
	var packed: PackedScene = load(MODEL)
	assert_object(packed).is_not_null()
	return packed.instantiate()


func _part(root: Node3D, name: String) -> MeshInstance3D:
	var node := root.find_child(name, true, false) as MeshInstance3D
	assert_object(node).is_not_null()
	return node


func _aabb(root: Node3D, name: String) -> AABB:
	return _part(root, name).get_aabb()


## Every part `ArenaBuilder` dresses must exist under the name it dresses it
## by. A part that goes missing does not crash anything -- it renders in its
## Blender placeholder colour, in the middle of a frame whose every other
## surface is solved against a measured target.
func test_the_model_ships_every_part_the_builder_dresses() -> void:
	var root := _model()
	for part: String in ArenaBuilder.BOWL_MODEL_MATERIALS:
		assert_object(_part(root, part)).is_not_null()
	for part: String in ArenaBuilder.BOWL_MODEL_EMISSIVE:
		assert_object(_part(root, part)).is_not_null()
	root.free()


## The bowl's top tread is where the row schedule says it is.
##
## This is the assertion that catches the failure the two-language split
## actually threatens: the exporter growing a row, or the suite storey
## changing height, without the ringside chairs following it up: they are
## placed at `_row_schedule()`'s tread heights, so a mesh that disagrees puts
## a row of chairs in mid-air.
func test_the_mesh_tops_out_on_the_schedules_last_tread() -> void:
	var root := _model()
	var rows := ArenaBuilder._row_schedule()
	var top := -INF
	for row: Dictionary in rows:
		top = maxf(top, row["tread_y"])
	var box := _aabb(root, "BowlSteps")
	assert_float(box.position.y + box.size.y).is_equal_approx(top, TOLERANCE)
	# And it starts on the arena floor: a bowl that floats leaves a lit gap
	# under its front row that reads straight through to the shell.
	assert_float(box.position.y).is_equal_approx(ArenaBuilder.FLOOR_Y, TOLERANCE)
	root.free()


## The plan is an obround, and its two half-extents differ by exactly the
## difference between the rectangle's. That is the definition of offsetting a
## rectangle, and it is what makes the ends semicircular rather than merely
## round: any other relationship between the two is an ellipse or a stadium
## with a flat end, and neither is the reference's plan
## (`gauntlet/refs/arena.md`).
func test_the_plan_is_a_rectangle_offset_not_a_scaled_outline() -> void:
	var root := _model()
	var box := _aabb(root, "BowlSteps")
	var half_x := box.position.x + box.size.x
	var half_z := box.position.z + box.size.z
	assert_float(half_z - half_x).is_equal_approx(
			ArenaBuilder.BOWL_STRAIGHT_Z - ArenaBuilder.BOWL_STRAIGHT_X,
			TOLERANCE)
	root.free()


## The rectangle every offset in the hall comes off IS THE RINK'S.
##
## `BOWL_STRAIGHT_X/Z` are written out longhand because `arena_bowl.py` parses
## plain constants and cannot evaluate an expression. This is the expression,
## asserted: get it wrong and the boards stop being a rink, silently, while
## everything still looks like an arena.
func test_the_plan_rectangle_is_the_rinks() -> void:
	assert_float(ArenaBuilder.BOWL_STRAIGHT_X + ArenaBuilder.RINK_CORNER_RADIUS) \
			.is_equal_approx(ArenaBuilder.RINK_HALF_WIDTH, 0.001)
	assert_float(ArenaBuilder.BOWL_STRAIGHT_Z + ArenaBuilder.RINK_CORNER_RADIUS) \
			.is_equal_approx(ArenaBuilder.RINK_HALF_LENGTH, 0.001)
	# And it is a regulation sheet: 200 x 85 feet, 28-foot corners.
	assert_float(ArenaBuilder.RINK_HALF_LENGTH * 2.0).is_equal_approx(60.96, 0.01)
	assert_float(ArenaBuilder.RINK_HALF_WIDTH * 2.0).is_equal_approx(25.91, 0.01)
	assert_float(ArenaBuilder.RINK_CORNER_RADIUS).is_equal_approx(8.53, 0.01)


## The modelled rink is that rink, and the ring stands in the middle of it.
##
## The deck's extents are the rink's own, and its centre is the origin -- which
## is where `ring.tscn` puts the mat. "The ring is in the middle of the rink"
## is the kind of claim that is true when written and quietly false three
## constants later, so it is measured off the shipped mesh.
func test_the_rink_is_regulation_and_the_ring_is_in_the_middle_of_it() -> void:
	var root := _model()
	var deck := _aabb(root, "RinkDeck")
	assert_float(deck.size.x).is_equal_approx(ArenaBuilder.RINK_HALF_WIDTH * 2.0,
			TOLERANCE)
	assert_float(deck.size.z).is_equal_approx(ArenaBuilder.RINK_HALF_LENGTH * 2.0,
			TOLERANCE)
	var centre := deck.position + deck.size * 0.5
	assert_float(centre.x).is_equal_approx(0.0, TOLERANCE)
	assert_float(centre.z).is_equal_approx(0.0, TOLERANCE)
	# The mat is 6m square at the origin, so it has to be well inside.
	assert_bool(deck.grow(TOLERANCE).has_point(
			Vector3(ArenaBuilder.RING_HALF_EXTENT, deck.position.y,
					ArenaBuilder.RING_HALF_EXTENT))).is_true()
	root.free()


## The boards stand on the rink's edge at their regulation height, and the cap
## rail sits on top of them rather than somewhere up the wall.
func test_the_boards_ring_the_rink() -> void:
	var root := _model()
	var boards := _aabb(root, "RinkBoards")
	assert_float(boards.position.y).is_equal_approx(ArenaBuilder.FLOOR_Y, TOLERANCE)
	assert_float(boards.size.y).is_equal_approx(
			ArenaBuilder.RINK_BOARD_HEIGHT - ArenaBuilder.RINK_CAP_HEIGHT,
			TOLERANCE)
	var cap := _aabb(root, "RinkCap")
	assert_float(cap.position.y + cap.size.y) \
			.is_equal_approx(ArenaBuilder.FLOOR_Y + ArenaBuilder.RINK_BOARD_HEIGHT,
					TOLERANCE)
	# The seating starts outside the boards, with the walkway between.
	assert_float(ArenaBuilder.BOWL_FIRST_ROW) \
			.is_greater(ArenaBuilder.RINK_CORNER_RADIUS)
	root.free()


## Floor seats stay on the rink.
##
## `_inside_rink` is what keeps 1,400-odd chairs off the walkway, out of the
## bowl and off the boards, and it is one distance test standing between the
## floor plan and chairs embedded in a wall. Checked on the four places it has
## to be exactly right.
func test_floor_seats_are_kept_on_the_rink() -> void:
	var margin := ArenaBuilder.FLOOR_SEAT_MARGIN
	# Dead centre, and on the boards' own line, inset by the margin.
	assert_bool(ArenaBuilder._inside_rink(Vector3.ZERO, margin)).is_true()
	assert_bool(ArenaBuilder._inside_rink(
			Vector3(0.0, 0.0, ArenaBuilder.RINK_HALF_LENGTH - margin - 0.01),
			margin)).is_true()
	# A hand's width past the boards, on each axis, is out.
	assert_bool(ArenaBuilder._inside_rink(
			Vector3(0.0, 0.0, ArenaBuilder.RINK_HALF_LENGTH - margin + 0.1),
			margin)).is_false()
	assert_bool(ArenaBuilder._inside_rink(
			Vector3(ArenaBuilder.RINK_HALF_WIDTH - margin + 0.1, 0.0, 0.0),
			margin)).is_false()
	# And the corner, where a rectangular test would wrongly say "inside".
	assert_bool(ArenaBuilder._inside_rink(
			Vector3(ArenaBuilder.RINK_HALF_WIDTH - margin,
					0.0, ArenaBuilder.RINK_HALF_LENGTH - margin),
			margin)).is_false()


## The ramp crosses the rink.
##
## The entrance set stands beyond the boards at the -Z end and the ring is in
## the middle, so the walk is the length of half a rink -- which is the whole
## reason the stage moved. Asserted as a length rather than as a position, so
## the numbers can move as long as the walk survives.
func test_the_ramp_crosses_the_rink() -> void:
	var ramp_end := -ArenaBuilder.RING_HALF_EXTENT - 1.0
	var ramp_length := absf(ramp_end - ArenaBuilder.STAGE_FRONT)
	assert_float(ramp_length).is_greater(20.0)
	# The deck it comes off is outside the boards, not standing on the floor
	# seating.
	assert_float(ArenaBuilder.STAGE_FRONT) \
			.is_less_equal(-ArenaBuilder.RINK_HALF_LENGTH + 0.5)
	# And the video wall is behind the deck, not over the seats.
	assert_float(ArenaBuilder.STAGE_BACK).is_less(ArenaBuilder.STAGE_FRONT)


## The suite storey sits between the tiers, at the height the schedule gives
## the concourse, and is exactly SUITE_HEIGHT tall. Both ribbon boards and the
## glass live inside it; if the fascia drifts, they drift with it and the
## upper tier's front row hangs over nothing.
func test_the_suite_storey_stands_on_the_concourse() -> void:
	var root := _model()
	var rows := ArenaBuilder._row_schedule()
	var concourse := {}
	for row: Dictionary in rows:
		if row["kind"] == "concourse":
			concourse = row
	assert_bool(concourse.is_empty()).is_false()

	var fascia := _aabb(root, "SuiteFascia")
	assert_float(fascia.position.y).is_equal_approx(concourse["tread_y"], TOLERANCE)
	assert_float(fascia.size.y).is_equal_approx(ArenaBuilder.SUITE_HEIGHT, TOLERANCE)
	for part: String in ["RibbonBoards", "SuiteGlass"]:
		var box := _aabb(root, part)
		assert_float(box.position.y).is_greater(fascia.position.y - TOLERANCE)
		assert_float(box.position.y + box.size.y) \
				.is_less(fascia.position.y + fascia.size.y + TOLERANCE)
	root.free()


## The shell encloses the bowl. It is one wall following the same curve, so
## "encloses" is checkable as a box containment rather than as a judgement.
func test_the_shell_encloses_the_bowl() -> void:
	var root := _model()
	var shell := _aabb(root, "Shell")
	var steps := _aabb(root, "BowlSteps")
	assert_bool(shell.grow(TOLERANCE).encloses(steps)).is_true()
	assert_float(shell.position.y + shell.size.y) \
			.is_equal_approx(ArenaBuilder.WALL_TOP, TOLERANCE)
	root.free()


## The bowl opens for the entrance set instead of walling it off.
##
## Asserted on the mesh rather than on the cut function, because the cut being
## right in GDScript is worth nothing if the exporter applied it to a
## different place: nothing may be built across the middle of the -Z end below
## the stage's own deck height.
func test_the_bowl_opens_for_the_entrance_set() -> void:
	var root := _model()
	for part: String in ["BowlSteps", "BowlSeats"]:
		var arrays := _part(root, part).mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var intruders := 0
		for v: Vector3 in verts:
			if v.z < 0.0 and absf(v.x) < ArenaBuilder.STAGE_HALF_WIDTH - 0.5 \
					and v.y > ArenaBuilder.FLOOR_Y + 0.1:
				intruders += 1
		assert_int(intruders).is_equal(0)
	root.free()


## The seats stand on the seated treads, at seat-back height.
##
## With the hall empty the seats are the bowl's whole read, so their placement
## is no longer something a crowd sitting in front of them can hide: the
## lowest seat must be on the first raked row and the highest exactly one
## SEAT_BACK_HEIGHT above the last tread. A seat sunk into its tread or
## floating over it is visible from every camera in the shotlist.
func test_the_seats_stand_on_the_seated_treads() -> void:
	var root := _model()
	var first := INF
	var last := -INF
	for row: Dictionary in ArenaBuilder._row_schedule():
		if row["kind"] != "seated":
			continue
		first = minf(first, row["tread_y"])
		last = maxf(last, row["tread_y"])

	var box := _aabb(root, "BowlSeats")
	assert_float(box.position.y).is_equal_approx(first, TOLERANCE)
	assert_float(box.position.y + box.size.y) \
			.is_equal_approx(last + ArenaBuilder.SEAT_BACK_HEIGHT, TOLERANCE)
	root.free()


## The plan loop GDScript walks and the one the exporter sweeps are the same
## curve. Checked at the barricade line, where the first row starts: every
## sample must sit exactly `offset` from the rectangle it is offset from.
func test_the_plan_loop_is_everywhere_one_offset_from_its_rectangle() -> void:
	var offset := ArenaBuilder.BOWL_FIRST_ROW
	for entry: Array in ArenaBuilder._plan_loop(offset):
		var point: Vector3 = entry[0]
		# Distance from an axis-aligned rectangle: clamp to it, then measure.
		var nearest := Vector3(
				clampf(point.x, -ArenaBuilder.BOWL_STRAIGHT_X,
						ArenaBuilder.BOWL_STRAIGHT_X),
				0.0,
				clampf(point.z, -ArenaBuilder.BOWL_STRAIGHT_Z,
						ArenaBuilder.BOWL_STRAIGHT_Z))
		assert_float(point.distance_to(nearest)).is_equal_approx(offset, 0.001)
		# And the normal points straight out along that same line.
		var normal: Vector3 = entry[1]
		assert_float(normal.length()).is_equal_approx(1.0, 0.001)
		assert_float(normal.dot((point - nearest).normalized())) \
				.is_equal_approx(1.0, 0.001)


## The ribbon artwork is laid along the board at RIBBON_HEIGHT * RIBBON_ART_ASPECT
## per repeat. If the image is swapped for one of a different shape and the
## constant is not updated, every repeat stretches round the bowl.
func test_the_ribbon_art_is_laid_at_its_own_aspect() -> void:
	var tex: Texture2D = load(ArenaBuilder.RIBBON_ART)
	assert_object(tex).is_not_null()
	var aspect := float(tex.get_width()) / float(tex.get_height())
	assert_float(ArenaBuilder.RIBBON_ART_ASPECT).is_equal_approx(aspect, 0.001)


## Emission, not a lit face: see `_ribbon_material()`. Both of these were bugs
## on the way in -- a white emission colour under ADD, and a glossy face that
## reflected the haze -- and each rendered the board a colourless white.
func test_the_ribbon_board_is_the_picture_and_nothing_else() -> void:
	var builder: ArenaBuilder = auto_free(ArenaBuilder.new())
	var mat := builder._ribbon_material(0.4)
	assert_object(mat.emission_texture).is_not_null()
	assert_bool(mat.emission == Color.BLACK).is_true()
	assert_int(mat.emission_operator).is_equal(BaseMaterial3D.EMISSION_OP_ADD)
	assert_float(mat.metallic_specular).is_equal(0.0)
	# Under the glow threshold, or the bloom closes over the lettering.
	assert_float(ArenaBuilder.RIBBON_ART_PEAK).is_less(1.25)
