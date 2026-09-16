extends GdUnitTestSuite
## The ringside fans: the six meshes `ArenaBuilder` instances into the folding
## chairs, measured on the shipped model.
##
## These are built by `tools/blender/floor_crowd.py` (figures from
## `tools/blender/crowd.py`) and committed as `floor_crowd.glb`, so nothing
## here can be asserted by constructing one -- every test reads the model.
##
## Why this file exists at all is the same reason `test_arena_crowd.gd` does:
## a crowd has been removed from this hall once already (7b91d0e) and the
## reference sets disagree about whether one belongs -- `gauntlet/refs/arena.md`
## measures an empty bowl, `gauntlet/refs/lighting.md` four full ones. What the
## ringside crowd must do is therefore written down rather than left to a frame.
##
## The three failure modes worth a test, none of them obvious from the code:
##   * The frame. The figures inherit a folding chair's transform unchanged,
##     which only works because they are modelled facing +Z, the frame
##     `_floor_seat_row` builds a chair in. Authored in any other frame, a bank
##     of fans faces the barricade -- and the mesh alone still looks correct.
##   * The height. `crowd.CHAIR_SEAT_HEIGHT` lifts each figure onto the seat
##     pan, and `_build_floor_crowd` applies no vertical offset of its own
##     because of it. Lose the lift and every fan sinks through the chair;
##     double it and a thousand of them hover.
##   * The tint. Colour arrives per MultiMesh instance, so the mesh has to be
##     neutral. A coloured mesh multiplies against the instance colour and
##     dresses the entire ringside twice as dark, which reads as bad lighting
##     rather than as a bug in a model.

const MODEL := "res://assets/environment/floor_crowd.glb"
## `crowd.FLOOR_VARIANTS`. Six poses plus per-instance size, yaw and shirt is
## what keeps a bank of chairs from reading as a repeat at `ringside_low`.
const VARIANTS := 6
## Vertex positions arrive through the glTF importer and a float buffer, so
## the tolerance is the pipeline's, not the arithmetic's.
const TOLERANCE := 0.02


func _model() -> Node3D:
	var packed: PackedScene = load(MODEL)
	assert_object(packed) \
		.override_failure_message(
			"%s did not load: run tools/blender/build_arena.sh, then " % MODEL
			+ "godot4 --headless --path game --import") \
		.is_not_null()
	return auto_free(packed.instantiate()) as Node3D


func _fans(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh != null:
			out.append(instance)
	return out


## Six of them, and six DIFFERENT ones.
##
## The count alone would pass on six copies of one person, which is exactly the
## thing the design pays six draw calls to avoid, so the poses are compared too.
func test_the_model_ships_six_distinct_fans() -> void:
	var fans := _fans(_model())
	assert_int(fans.size()) \
		.override_failure_message(
			"expected %d fan meshes, got %d: check crowd.FLOOR_VARIANTS"
			% [VARIANTS, fans.size()]) \
		.is_equal(VARIANTS)
	var shapes := {}
	for fan in fans:
		var box := fan.get_aabb()
		shapes["%0.3f,%0.3f,%0.3f" % [box.size.x, box.size.y, box.size.z]] = true
	assert_int(shapes.size()) \
		.override_failure_message(
			"the %d fans share only %d distinct shapes: they are posed from one "
			% [fans.size(), shapes.size()]
			+ "RNG in crowd.build_floor_variants and should all differ") \
		.is_equal(VARIANTS)


## Every fan is modelled facing +Z.
##
## That is the whole reason a figure can be dropped onto a chair's transform
## untouched: `_floor_seat_row` orients a chair with
## `Basis(Vector3.UP, atan2(inward.x, inward.z))`, which maps local +Z onto the
## inward direction. A seated person reaches further forward -- knees, shins,
## lap -- than back, so the mesh leans +Z of its own origin.
func test_every_fan_is_built_facing_forward() -> void:
	for fan in _fans(_model()):
		var box := fan.get_aabb()
		assert_float(box.end.z) \
			.override_failure_message(
				"%s reaches %.3f forward against %.3f back: it is not built "
				% [fan.name, box.end.z, -box.position.z]
				+ "facing +Z, so it will sit on a chair facing the barricade") \
			.is_greater(-box.position.z)


## The fans sit ON the chairs: feet on the floor, nothing through it.
##
## `crowd.CHAIR_SEAT_HEIGHT` is applied in Blender and `_build_floor_crowd`
## adds no offset, so the model's own origin is the chair's. A figure whose
## lowest vertex went negative is buried in the ringside floor; one lifted
## clear of it is a thousand hovering fans.
func test_the_fans_are_seated_on_the_floor_not_through_it() -> void:
	for fan in _fans(_model()):
		var box := fan.get_aabb()
		assert_float(box.position.y) \
			.override_failure_message(
				"%s's lowest vertex is at %.3f: it is sunk into the ringside "
				% [fan.name, box.position.y]
				+ "floor (check crowd.CHAIR_SEAT_HEIGHT)") \
			.is_greater_equal(0.0)
		assert_float(box.position.y) \
			.override_failure_message(
				"%s's lowest vertex is at %.3f, too high for a foot on the "
				% [fan.name, box.position.y]
				+ "floor: the figure is hovering above its chair") \
			.is_less(0.15)


## They are seated, not standing.
##
## A standing adult in this crowd is about 1.8m; these must read as people in
## chairs from `ringside_low`, which is the shot that frames them. The check
## catches `crowd._seated` being swapped for the standing pose, which would
## otherwise only show as a row of fans towering over the barricade.
func test_the_fans_are_seated_height() -> void:
	for fan in _fans(_model()):
		var top := fan.get_aabb().end.y
		assert_float(top).is_between(1.1, 1.6)


## The mesh carries no HUE, because the shirt is dressed per instance.
##
## `_build_floor_crowd` sets `mm.use_colors` and a colour from `CROWD_SHIRTS`
## on every instance, and Godot multiplies that by the mesh's own COLOR_0. A
## mesh carrying a shirt colour of its own would tint each fan twice -- in the
## seats closest to the camera, which reads as bad lighting rather than as a
## bug in a model. Value is a different matter and is the point of the next
## test: grey modulates brightness without introducing a second hue.
func test_the_fan_meshes_carry_no_colour_of_their_own() -> void:
	for fan in _fans(_model()):
		var mesh := fan.mesh as ArrayMesh
		var colours: PackedColorArray = \
				mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		assert_int(colours.size()).is_greater(0)
		for i in range(0, colours.size(), 17):
			var c := colours[i]
			var spread := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			assert_float(spread) \
				.override_failure_message(
					"%s carries %s, a hue of its own: the mesh must stay grey "
					% [fan.name, c]
					+ "or every ringside fan is tinted twice "
					+ "(crowd.build_floor_variants)") \
				.is_less(TOLERANCE)


## The skin tone survives the export, as COLOR_0 and not as COLOR_1.
##
## This is the one failure here that is invisible in Blender, invisible in the
## exporter's log, and nearly invisible on a frame -- and it shipped. glTF
## only writes a colour attribute as COLOR_0 when a material demonstrably
## reads it; `floor_crowd.py` did not wire a ShaderNodeVertexColor, so the
## figures' white-shirt/grey-skin layer was written as COLOR_1, which Godot's
## importer ignores. Every fan came back a single flat value, and the only
## symptom was a crowd with no faces in it.
##
## So: two distinct greys per figure, the shirt at 1.0 and the skin below it.
func test_every_fan_ships_a_skin_tone_darker_than_its_shirt() -> void:
	for fan in _fans(_model()):
		var mesh := fan.mesh as ArrayMesh
		var colours: PackedColorArray = \
				mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var values := {}
		for c in colours:
			values["%0.2f" % c.r] = true
		assert_int(values.size()) \
			.override_failure_message(
				"%s ships %d distinct values %s: its colour attribute went out "
				% [fan.name, values.size(), values.keys()]
				+ "as COLOR_1 and was dropped on import -- check "
				+ "export_vertex_color in floor_crowd.py") \
			.is_greater(1)
		var darkest := INF
		var brightest := -INF
		for c in colours:
			darkest = minf(darkest, c.r)
			brightest = maxf(brightest, c.r)
		assert_float(brightest).is_equal_approx(1.0, TOLERANCE)
		assert_float(darkest).is_between(0.2, 0.9)
