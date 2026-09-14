extends GdUnitTestSuite
## The crowd in the seating bowl: that it is there, that it is varied, and
## that it carries what the shader needs to animate it.
##
## The crowd is baked geometry in `arena_bowl.glb` (built by
## `tools/blender/crowd.py`), not runtime instances, so nothing about it can
## be asserted by constructing one. These read the shipped model.
##
## Why each of these is worth a test
## ---------------------------------
## A crowd has been removed from this hall once already (7b91d0e) and the
## reference sets still disagree about whether it should be here:
## `gauntlet/refs/arena.md` measures an empty bowl, `gauntlet/refs/lighting.md`
## four full ones. That makes this the kind of thing that gets quietly
## reverted, so what it must do is written down as assertions.
##
## The two failure modes that would not be obvious on a frame:
##   * COLOR_0 not exported. glTF's default vertex-colour export mode only
##     writes the attribute when a material demonstrably reads it, so a
##     change to the Blender material silently drops every shirt colour. The
##     bowl still renders; the crowd just turns one flat colour.
##   * The phase collapsing. If every figure ends up with the same phase the
##     whole bowl bobs in unison, which reads far worse than no motion at all.

const BOWL_MODEL := "res://assets/environment/arena_bowl.glb"
const CROWD_PARTS := ["Crowd", "CrowdFar"]


func _bowl() -> Node3D:
	var packed: PackedScene = load(BOWL_MODEL)
	assert_object(packed).is_not_null()
	return auto_free(packed.instantiate()) as Node3D


func _mesh_for(root: Node3D, part: String) -> ArrayMesh:
	var node := root.find_child(part, true, false) as MeshInstance3D
	assert_object(node) \
		.override_failure_message(
			"%s has no '%s' object: re-run tools/blender/build_arena.sh" %
			[BOWL_MODEL, part]) \
		.is_not_null()
	return node.mesh as ArrayMesh


func test_the_bowl_ships_a_crowd() -> void:
	var root := _bowl()
	for part in CROWD_PARTS:
		var mesh := _mesh_for(root, part)
		assert_int(mesh.get_surface_count()).is_greater(0)


func test_every_crowd_vertex_carries_a_colour() -> void:
	# Shirt colour rides COLOR_0 (the phase rides a UV; see below).
	# Losing the attribute is silent -- see this file's header.
	var root := _bowl()
	for part in CROWD_PARTS:
		var mesh := _mesh_for(root, part)
		var arrays := mesh.surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		assert_int(colours.size()) \
			.override_failure_message(
				"%s exports no COLOR_0: check export_vertex_color in arena_bowl.py"
				% part) \
			.is_greater(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		assert_int(colours.size()).is_equal(vertices.size())


func test_the_crowd_is_not_all_wearing_the_same_shirt() -> void:
	# Variance is the entire reason the figures are modelled rather than
	# imposter boxes. A palette that collapsed to one entry would render as a
	# uniformed crowd and pass every other test here.
	var root := _bowl()
	var mesh := _mesh_for(root, "Crowd")
	var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var seen := {}
	for i in range(0, colours.size(), 97):
		var c := colours[i]
		seen["%0.2f,%0.2f,%0.2f" % [c.r, c.g, c.b]] = true
	assert_int(seen.size()) \
		.override_failure_message("the crowd has only %d distinct shirt colours"
			% seen.size()) \
		.is_greater(20)


func test_the_animation_phase_is_spread_across_the_bowl() -> void:
	# Phase lives in UV.x. If it collapsed, every figure would bob together,
	# which reads far worse than no motion at all.
	#
	# It lived in colour alpha first. That arrives back 1.0 on every vertex --
	# nothing in Blender's exporter or Godot's importer preserves an alpha no
	# material reads as transparency -- and the failure is silent: the shirts
	# still vary, so only a test that looks at the phase itself catches it.
	var root := _bowl()
	var mesh := _mesh_for(root, "Crowd")
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_int(uvs.size()) \
		.override_failure_message("Crowd exports no UV: the phase is gone") \
		.is_greater(0)
	var lowest := 2.0
	var highest := -1.0
	for i in range(0, uvs.size(), 31):
		lowest = minf(lowest, uvs[i].x)
		highest = maxf(highest, uvs[i].x)
	assert_float(lowest).is_less(0.1)
	assert_float(highest).is_greater(0.9)


func test_a_figure_stands_on_its_row_rather_than_floating() -> void:
	# The crowd is placed against the same row schedule the seats are, so a
	# figure's feet should sit on a tread. Checked as a band rather than a
	# height because the bowl rakes: what would fail here is the crowd being
	# built in the wrong frame entirely, which is the mistake that puts a
	# whole bowl of people underground or in the roof.
	var root := _bowl()
	var mesh := _mesh_for(root, "Crowd")
	var aabb := mesh.get_aabb()
	var rows := ArenaBuilder._row_schedule()
	var lowest_tread := INF
	var highest_tread := -INF
	for row in rows:
		if row["kind"] != "seated":
			continue
		lowest_tread = minf(lowest_tread, row["tread_y"])
		highest_tread = maxf(highest_tread, row["tread_y"])
	# Feet no lower than the first tread (less a little for shins hanging
	# over the step), heads no higher than the top tread plus a standing man.
	assert_float(aabb.position.y).is_greater(lowest_tread - 0.6)
	assert_float(aabb.position.y + aabb.size.y).is_less(highest_tread + 2.2)
