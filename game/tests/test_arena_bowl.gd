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
## straight side's half-length. That is the definition of offsetting a
## rectangle, and it is what makes the ends semicircular rather than merely
## round: any other relationship between the two is an ellipse or a stadium
## with a flat end, and neither is the reference's plan
## (`gauntlet/refs/arena.md`).
func test_the_plan_is_a_rectangle_offset_not_a_scaled_outline() -> void:
	var root := _model()
	var box := _aabb(root, "BowlSteps")
	var half_x := box.position.x + box.size.x
	var half_z := box.position.z + box.size.z
	assert_float(half_x - half_z) \
			.is_equal_approx(ArenaBuilder.BOWL_STRAIGHT_X, TOLERANCE)
	root.free()


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
	var offset := ArenaBuilder.BARRICADE_RADIUS
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
