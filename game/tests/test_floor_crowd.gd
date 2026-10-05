extends GdUnitTestSuite
## The ringside fans: the meshes `ArenaBuilder` instances into the folding
## chairs, measured on the shipped model.
##
## These are Microsoft Rocketbox people posed and baked by
## `tools/blender/crowd.py` / `rocketbox_crowd.py` and committed as
## `floor_crowd.glb`, so nothing here can be asserted by constructing one --
## every test reads the model.
##
## Two sets of the same people: `Fan##` at ringside detail for the front
## FLOOR_CHAIR_DETAIL_ROWS rows, `FanFar##` at the bowl's level of detail for
## the floor behind them (crowd.FLOOR_SETS).
##
## The failure modes worth a test, none of them obvious from the code:
##   * The frame. The figures inherit a folding chair's transform unchanged,
##     which only works because they are modelled facing +Z, the frame
##     `_floor_seat_row` builds a chair in. Authored in any other frame, a bank
##     of fans faces the barricade -- and the mesh alone still looks correct.
##   * The height. The seated poses put feet on the floor and the hip joint
##     at chair height, and `_build_floor_crowd` applies no vertical offset of
##     its own. Lose that and every fan sinks through the chair or hovers.
##   * The garment contract. The mesh keeps its own faces, hair and jeans and
##     MARKS the upper garment (UV.x 0.5, the chest 1.0, its fold shading as a
##     half-scale grey in COLOR) for the shader to re-dress per instance. A
##     mesh that loses the mark dresses every fan in the avatar's own clothes;
##     one whose colour went out as COLOR_1 renders every fan one flat value.

const MODEL := "res://assets/environment/floor_crowd.glb"
## `crowd.FLOOR_VARIANTS` per set: twenty seated people and four standing.
const VARIANTS := 24
## The last of them are on their feet (`crowd.STANDING_VARIANTS`).
const STANDING := 4
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


## Every fan mesh in both sets, or only the near set (`Fan##`) with
## `near_only`, in name order.
func _fans(root: Node3D, near_only := false) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		if near_only and String(instance.name).begins_with("FanFar"):
			continue
		out.append(instance)
	out.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return String(a.name) < String(b.name))
	return out


## Twenty-four of them in each set, and twenty-four DIFFERENT ones.
##
## The count alone would pass on copies of one person, which is exactly the
## thing the design pays the draw calls to avoid, so the shapes are compared
## too.
func test_the_model_ships_two_sets_of_distinct_fans() -> void:
	var all := _fans(_model())
	assert_int(all.size()) \
		.override_failure_message(
			"expected %d fan meshes, got %d: check crowd.FLOOR_SETS"
			% [VARIANTS * 2, all.size()]) \
		.is_equal(VARIANTS * 2)
	var fans := _fans(_model(), true)
	assert_int(fans.size()).is_equal(VARIANTS)
	var shapes := {}
	for fan in fans:
		var box := fan.get_aabb()
		shapes["%0.3f,%0.3f,%0.3f" % [box.size.x, box.size.y, box.size.z]] = true
	assert_int(shapes.size()) \
		.override_failure_message(
			"the %d fans share only %d distinct shapes: they should all differ"
			% [fans.size(), shapes.size()]) \
		.is_equal(VARIANTS)


## The near set is the detailed one: a ringside fan is a few metres from the
## gameplay camera, and the far set exists only because the floor behind
## those rows cannot afford it.
func test_the_near_fans_are_more_detailed_than_the_far_ones() -> void:
	var root := _model()
	for i in VARIANTS:
		var near := root.find_child("Fan%02d" % i, true, false) as MeshInstance3D
		var far := root.find_child("FanFar%02d" % i, true, false) as MeshInstance3D
		assert_object(near).is_not_null()
		assert_object(far).is_not_null()
		var n := (near.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var f := (far.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		assert_int(n).is_greater(f * 3)


## Every fan is modelled facing +Z.
##
## That is the whole reason a figure can be dropped onto a chair's transform
## untouched: `_floor_seat_row` orients a chair with
## `Basis(Vector3.UP, atan2(inward.x, inward.z))`, which maps local +Z onto the
## inward direction. A seated person reaches further forward -- knees, shins,
## lap -- than back, so the mesh leans +Z of its own origin. That is true of
## the seated ones only: somebody standing with their arms up leans back.
func test_every_fan_is_built_facing_forward() -> void:
	var root := _model()
	for prefix in ["Fan", "FanFar"]:
		for i in VARIANTS - STANDING:
			_assert_faces_forward(root.find_child("%s%02d" % [prefix, i], true, false))


func _assert_faces_forward(fan: MeshInstance3D) -> void:
	var box := fan.get_aabb()
	assert_float(box.end.z) \
		.override_failure_message(
			"%s reaches %.3f forward against %.3f back: it is not built "
			% [fan.name, box.end.z, -box.position.z]
			+ "facing +Z, so it will sit on a chair facing the barricade") \
		.is_greater(-box.position.z)


## The fans sit ON the chairs: feet on the floor, nothing through it.
##
## The seated poses put the feet on the floor and the hip joint at chair
## height (crowd.CHAIR_SEAT_HEIGHT), and `_build_floor_crowd` adds no offset,
## so the model's own origin is the chair's. A figure whose
## lowest vertex went negative is buried in the ringside floor; one lifted
## clear of it is a thousand hovering fans.
func test_the_fans_are_seated_on_the_floor_not_through_it() -> void:
	for fan in _fans(_model()):
		var box := fan.get_aabb()
		assert_float(box.position.y) \
			.override_failure_message(
				"%s's lowest vertex is at %.3f: it is sunk into the ringside "
				% [fan.name, box.position.y]
				+ "floor (check rocketbox_crowd.Avatar.extract's origin)") \
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
## catches a seated pose losing its sitting lower body -- a biped's thighs
## hang off the spine, so a clap grafted on above the hips can drag the legs
## straight -- which would otherwise only show as a row of fans towering over
## the barricade.
func test_the_fans_are_seated_height() -> void:
	var root := _model()
	for prefix in ["Fan", "FanFar"]:
		for i in VARIANTS:
			var fan := root.find_child("%s%02d" % [prefix, i], true, false) as MeshInstance3D
			var top := fan.get_aabb().end.y
			if i < VARIANTS - STANDING:
				assert_float(top) \
					.override_failure_message("%s tops out at %.2f m: not seated"
						% [fan.name, top]) \
					.is_between(1.1, 1.75)
			else:
				# The ones who got up are taller than anyone sitting.
				assert_float(top).is_between(1.55, 2.3)


## The upper garment is marked for the shader, and only the garment.
##
## `_build_floor_crowd` puts a tee (and a print's ink) in each instance's
## custom data, and the floor-fan branch of the crowd shader dresses the
## vertices UV.x marks with it, scaled by the fold shading COLOR carries
## there as a half-scale grey. So: every fan has a garment, the garment is
## grey in the mesh (a hue there would tint the tee twice), and it is not the
## whole figure -- faces, arms and jeans keep the colours they were baked with.
func test_every_fan_marks_its_garment_in_grey() -> void:
	var with_print := 0
	for fan in _fans(_model()):
		var arrays := (fan.mesh as ArrayMesh).surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		assert_int(uv.size()).is_equal(colours.size())
		var garment := 0
		var chest := 0
		for i in uv.size():
			if uv[i].x < 0.25:
				continue
			garment += 1
			if uv[i].x > 0.75:
				chest += 1
			var c := colours[i]
			var spread := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			assert_float(spread) \
				.override_failure_message(
					"%s's garment carries %s, a hue of its own: it must stay "
					% [fan.name, c]
					+ "grey or the instance's tee is tinted twice") \
				.is_less(TOLERANCE)
			assert_float(c.r).is_between(0.25, 0.75)
		var share := float(garment) / float(uv.size())
		assert_float(share) \
			.override_failure_message("%s marks %.0f%% of itself as garment"
				% [fan.name, share * 100.0]) \
			.is_between(0.02, 0.7)
		if chest > 0:
			with_print += 1
	# Most of them have a chest a print can go on.
	assert_int(with_print).is_greater(VARIANTS)


## The baked colours survive the export, as COLOR_0 and not as COLOR_1.
##
## This is the one failure here that is invisible in Blender, invisible in the
## exporter's log, and nearly invisible on a frame -- and it shipped once.
## glTF only writes a colour attribute as COLOR_0 when a material
## demonstrably reads it, and Godot's importer ignores COLOR_1. Every fan
## came back a single flat value, and the only symptom was a crowd with no
## faces in it. So: real colour on the parts that are not the garment --
## skin warmer than it is blue, and many distinct values.
func test_every_fan_keeps_its_own_skin_and_clothes() -> void:
	for fan in _fans(_model()):
		var arrays := (fan.mesh as ArrayMesh).surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var values := {}
		var warm := 0
		for i in colours.size():
			if uv[i].x >= 0.25:
				continue
			var c := colours[i]
			values["%0.2f,%0.2f,%0.2f" % [c.r, c.g, c.b]] = true
			if c.r > c.b * 1.25 and c.r > 0.04:
				warm += 1
		assert_int(values.size()) \
			.override_failure_message(
				"%s ships %d distinct colours: its colour attribute went out "
				% [fan.name, values.size()]
				+ "as COLOR_1 and was dropped on import -- check "
				+ "export_vertex_color in floor_crowd.py") \
			.is_greater(20)
		assert_int(warm) \
			.override_failure_message("%s has no skin-toned vertex" % fan.name) \
			.is_greater(5)


## The ringside fans carry the arm mask too (UV2: reach, side), and a fan
## filming on a phone carries none -- he holds it steady.
func test_the_fans_carry_an_arm_mask() -> void:
	var moving := 0
	for fan in _fans(_model(), true):
		var arrays := (fan.mesh as ArrayMesh).surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		assert_int(uv2.size()).is_equal((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		var peak := 0.0
		for v in uv2:
			peak = maxf(peak, v.x)
		if peak > 0.8:
			moving += 1
	# The clappers and cheerers; not the sitters and phone holders.
	assert_int(moving).is_between(4, VARIANTS - 4)
