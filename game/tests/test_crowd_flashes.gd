extends GdUnitTestSuite
## The camera flashes and the crowd's per-person roles: small points of light
## at head height rather than a lit figure, never on one clock, bursting on the
## big moments; and a crowd whose people are not all doing the same thing.

const BOWL := "res://assets/environment/arena_bowl.glb"


func _crowd_meshes() -> Array:
	var root: Node3D = auto_free((load(BOWL) as PackedScene).instantiate())
	add_child(root)
	var out := []
	for part: String in ["Crowd", "CrowdFar"]:
		out.append(root.find_child(part, true, false))
	return out


func test_emitters_sit_at_head_height_in_the_stands() -> void:
	var positions := CrowdFlashes.sample_positions(_crowd_meshes(), 300, CrowdFlashes.SEED)
	assert_int(positions.size()).is_equal(300)
	var distinct := {}
	for p in positions:
		# Above the first tread (-1.1 m) by a head, below the roof.
		assert_float(p.y).is_between(0.1, 14.0)
		distinct["%.2f,%.2f,%.2f" % [p.x, p.y, p.z]] = true
	# Not 300 copies of the same few spots.
	assert_int(distinct.size()).is_greater(200)


func test_emitters_are_the_same_every_build() -> void:
	var a := CrowdFlashes.sample_positions(_crowd_meshes(), 50, CrowdFlashes.SEED)
	var b := CrowdFlashes.sample_positions(_crowd_meshes(), 50, CrowdFlashes.SEED)
	assert_array(Array(a)).is_equal(Array(b))


func test_some_stands_are_busy_and_some_are_dark() -> void:
	var lo := INF
	var hi := -INF
	for x in range(-30, 31, 3):
		for z in range(-30, 31, 3):
			var a := CrowdFlashes.activity_at(Vector3(x, 3.0, z))
			lo = minf(lo, a)
			hi = maxf(hi, a)
	assert_float(lo).is_less(0.5)
	assert_float(hi).is_greater(1.2)
	assert_float(lo).is_greater_equal(0.15 - 0.001)


func test_building_makes_one_billboard_per_emitter() -> void:
	var flashes: CrowdFlashes = auto_free(CrowdFlashes.new())
	add_child(flashes)
	var positions := PackedVector3Array([Vector3(1, 2, 3), Vector3(-4, 5, 6)])
	flashes.build(positions)
	var node := flashes.get_node("Flashes") as MultiMeshInstance3D
	assert_int(node.multimesh.instance_count).is_equal(2)
	assert_bool(node.multimesh.use_custom_data).is_true()
	# Every emitter has a clock of its own, spread evenly over [0, 1).
	var seeds := {}
	for i in 200:
		seeds["%.5f" % CrowdFlashes.emitter_seed(i)] = true
	assert_int(seeds.size()).is_equal(200)


func test_a_big_moment_sets_the_cameras_off_and_it_dies_away() -> void:
	var crowd: CrowdReaction = auto_free(CrowdReaction.new())
	add_child(crowd)
	assert_float(crowd.burst_level).is_equal(0.0)
	crowd.pop(CrowdReaction.POP_SIGNATURE)
	assert_float(crowd.burst_level).is_equal(1.0)
	assert_float(CrowdReaction.published_rate(crowd.flash_rate, crowd.burst_level)) \
			.is_equal_approx(CrowdReaction.MATCH_FLASH_RATE + CrowdReaction.BURST_RATE, 0.001)
	# A jab is not a camera moment.
	var quiet: CrowdReaction = auto_free(CrowdReaction.new())
	add_child(quiet)
	quiet.pop(0.3)
	assert_float(quiet.burst_level).is_equal(0.0)
	crowd._process(CrowdReaction.BURST_HALF_LIFE)
	assert_float(crowd.burst_level).is_equal_approx(0.5, 0.01)


func test_the_rest_rate_is_low_and_an_entrance_rate_higher() -> void:
	# About 0.1-0.3 Hz for an active emitter at rest, per the brief; the
	# match's rest rate is below it, an entrance's inside it.
	assert_float(CrowdReaction.MATCH_FLASH_RATE).is_less(0.1)
	assert_float(CrowdReaction.ENTRANCE_FLASH_RATE).is_between(0.1, 0.3)
	assert_float(CrowdReaction.MATCH_FLASH_RATE).is_greater(0.0)


## The people are not all doing the same thing: the baked UVs carry a phase in
## x and a role (sit, clap, wave, jump) in y.
func test_the_crowd_carries_roles_and_phases() -> void:
	var roles := {}
	var phases := {}
	for m: MeshInstance3D in _crowd_meshes():
		var uv: PackedVector2Array = m.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		for i in range(0, uv.size(), 7):
			roles["%.2f" % uv[i].y] = true
			phases["%.3f" % uv[i].x] = true
	assert_int(roles.size()).is_greater_equal(3)
	assert_int(phases.size()).is_greater(200)


## The old whole-figure flash is gone from the crowd shader.
func test_no_figure_sized_flash_in_the_crowd_shader() -> void:
	var builder: ArenaBuilder = auto_free(ArenaBuilder.new())
	var material := builder._crowd_material()
	var code := (material.shader as Shader).code
	assert_bool(code.contains("EMISSION += vec3(3.5)")).is_false()
	assert_bool(code.contains("crowd_flash_rate")).is_false()
