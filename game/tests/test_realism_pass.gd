extends GdUnitTestSuite
## The owner's realism pass (2 Nov): haze over the crowd and not the ring,
## the pre-bell house down with the ring at full and the building's flashes,
## handheld breathing and a focus pull.

const MATCH := "res://scenes/match.tscn"


func _match(entrances: bool) -> Node:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = entrances
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = "roman"
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = "cody"
	add_child(scene)
	return auto_free(scene)


## The haze starts past the ring from wherever the lens is: from the hard
## camera's seat in the bowl and from a ringside camera alike.
func test_the_haze_begins_past_the_ring_from_any_camera() -> void:
	for cam: Vector3 in [Vector3(-28.5, 8.3, 0.0), Vector3(-5.0, 1.8, 2.0), Vector3(0.0, 6.0, 9.0)]:
		var begin := ArenaLighting.haze_begin(cam)
		# The far side of the ring, from this camera, is nearer than the haze.
		var far_side := Vector2(cam.x, cam.z).length() + ArenaLighting.RING_REACH
		assert_float(begin).is_greater_equal(far_side - 0.001)
		assert_float(begin).is_greater_equal(ArenaLighting.FOG_BEGIN)
	assert_float(ArenaLighting.BOWL_HAZE_END).is_greater(ArenaLighting.haze_begin(Vector3(-28.5, 8.3, 0.0)))


## On forward_plus the match's Environment carries the bowl haze, on its own
## copy so other instances of match.tscn are untouched.
func test_the_match_carries_the_bowl_haze() -> void:
	var spare: Node = auto_free((load(MATCH) as PackedScene).instantiate())
	var shared: Environment = (spare.get_node("WorldEnvironment") as WorldEnvironment).environment
	var scene := _match(false)
	var env: Environment = (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_bool(env.fog_enabled).is_true()
	assert_int(env.fog_mode).is_equal(Environment.FOG_MODE_DEPTH)
	assert_float(env.fog_density).is_equal_approx(ArenaLighting.BOWL_HAZE_DENSITY, 0.0001)
	assert_bool(shared.fog_enabled).is_false()


## Pre-bell the crowd comes down and the ring stays at full; the walk out
## carries the cue, the stare the flashes, and the bell puts the house back.
func test_the_house_comes_down_before_the_bell_and_not_the_ring() -> void:
	var scene := _match(true)
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rig: ArenaLighting = director._lights as ArenaLighting
	var keys := {}
	for l: Light3D in rig._ring_lights:
		keys[l] = l.light_energy
	var wash := {}
	for l: Light3D in rig._audience_lights:
		wash[l] = l.light_energy
	rig.set_house_level(EntranceDirector.PREBELL_HOUSE_LEVEL)
	for l: Light3D in rig._ring_lights:
		assert_float(l.light_energy).is_equal_approx(keys[l], 0.0001)
	for l: Light3D in rig._audience_lights:
		assert_float(l.light_energy).is_equal_approx(wash[l] * EntranceDirector.PREBELL_HOUSE_LEVEL, 0.0001)
	var walk: Dictionary = director._beats[-2]
	var stare: Dictionary = director._beats[-1]
	assert_bool(walk["events"].any(func(e: Array) -> bool: return e[1] == "house_down")).is_true()
	assert_bool(stare["events"].any(func(e: Array) -> bool: return e[1] == "flash_burst")).is_true()
	director.skip()
	assert_float(rig.house_level).is_equal(1.0)


## The operator's breathing: bounded, never on the hard camera's tripod, and
## the same at the same time (no RNG).
func test_the_handheld_breathes_and_the_hard_camera_does_not() -> void:
	var most := 0.0
	for i in 600:
		var t := float(i) / 60.0
		assert_vector(MatchCamera.breathing(t, MatchCamera.Mode.HARD_CAM)).is_equal(Vector2.ZERO)
		var b := MatchCamera.breathing(t, MatchCamera.Mode.RINGSIDE)
		most = maxf(most, maxf(absf(b.x), absf(b.y)))
		assert_vector(MatchCamera.breathing(t, MatchCamera.Mode.RINGSIDE)).is_equal(b)
	assert_float(most).is_greater(MatchCamera.BREATH_MAX * 0.5)
	assert_float(most).is_less_equal(MatchCamera.BREATH_MAX * 1.001)


## A cut to a long lens lands a little long and racks onto the subject.
func test_the_focus_pulls_onto_the_subject() -> void:
	assert_float(MatchCamera.focus_pull_distance(5.0, 0.0)).is_equal_approx(5.0 * MatchCamera.FOCUS_PULL_FROM, 0.001)
	assert_float(MatchCamera.focus_pull_distance(5.0, MatchCamera.FOCUS_PULL_TIME)).is_equal_approx(5.0, 0.001)
	assert_float(MatchCamera.focus_pull_distance(5.0, MatchCamera.FOCUS_PULL_TIME * 0.5)) \
			.is_between(5.0, 5.0 * MatchCamera.FOCUS_PULL_FROM)


## The seats carry the baked occlusion on colour and house emission alike.
func test_the_seats_take_the_occlusion_material() -> void:
	var plain := MaterialLibrary.build({"tint": Color(0.1, 0.1, 0.105), "roughness": 0.9})
	plain.emission_enabled = true
	plain.emission = Color(0.1, 0.1, 0.105)
	plain.emission_energy_multiplier = 3.0
	var occ := MaterialLibrary.with_occlusion(plain) as ShaderMaterial
	assert_object(occ).is_not_null()
	assert_float(float(occ.get_shader_parameter("emission_energy"))).is_equal(3.0)
	assert_str(occ.shader.code).contains("EMISSION = emission.rgb * emission_energy * occlusion")
	var textured := MaterialLibrary.resolve("arena_bowl")
	assert_object(MaterialLibrary.with_occlusion(textured)).is_same(textured)
	var scene := _match(false)
	var seats := scene.find_child("BowlSeats", true, false)
	assert_object(seats).is_not_null()
	var mesh := seats as MeshInstance3D
	if mesh == null:
		mesh = seats.find_children("*", "MeshInstance3D", true, false)[0]
	assert_object(mesh.material_override).is_instanceof(ShaderMaterial)
