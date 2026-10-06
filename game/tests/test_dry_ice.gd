extends GdUnitTestSuite
## Cody's dry ice (DryIce): particles that work on every renderer, poured
## where the portal is, rolling toward the ring, and left to thin out after the
## fog volume is gone.

const MATCH := "res://scenes/match.tscn"


func test_it_pours_where_it_is_started_and_rolls_down_the_ramp() -> void:
	var ice: DryIce = auto_free(DryIce.new())
	add_child(ice)
	ice.start(Vector3(5.0, 0.35, -37.5), Vector3(0, 0, 1))
	var puffs := ice.get_node("Puffs") as CPUParticles3D
	assert_bool(puffs.emitting).is_true()
	assert_vector(ice.global_position).is_equal_approx(Vector3(5.0, 0.35, -37.5), Vector3.ONE * 0.001)
	# Poured toward +Z, along the floor.
	assert_float(puffs.direction.z).is_greater(0.9)
	assert_float(absf(puffs.direction.y)).is_less(0.1)
	# World-space particles that start already a bank, low on the floor.
	assert_bool(puffs.local_coords).is_false()
	assert_float(puffs.preprocess).is_greater(2.0)
	assert_float(puffs.position.y).is_less(1.0)


func test_it_works_without_a_fog_volume() -> void:
	# CPU particles and a billboard material: nothing a compatibility
	# renderer lacks (no FogVolume, no GPU-only features).
	var ice: DryIce = auto_free(DryIce.new())
	add_child(ice)
	ice.start(Vector3.ZERO, Vector3(0, 0, 1))
	var puffs := ice.get_node("Puffs") as CPUParticles3D
	assert_object(puffs).is_instanceof(CPUParticles3D)
	assert_bool(ice.find_children("*", "FogVolume", true, false).is_empty()).is_true()
	var m := puffs.material_override as StandardMaterial3D
	assert_int(m.billboard_mode).is_equal(BaseMaterial3D.BILLBOARD_PARTICLES)
	assert_int(m.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	# Additive, not alpha-mixed: the alpha-blended puffs drew as a hard-edged
	# black disc on the stage floor under the smoke (isolated by hiding the
	# DryIce node, which removed it). Added light cannot darken anything.
	assert_int(m.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)


func test_stopping_lets_what_is_out_linger_then_frees_it() -> void:
	var ice: DryIce = auto_free(DryIce.new())
	add_child(ice)
	ice.start(Vector3.ZERO, Vector3(0, 0, 1))
	ice.stop()
	var puffs := ice.get_node("Puffs") as CPUParticles3D
	assert_bool(ice.is_stopped()).is_true()
	assert_bool(puffs.emitting).is_false()
	# Not cut off: it is still there, and has a lifetime to thin away over.
	assert_bool(is_instance_valid(puffs)).is_true()
	assert_float(puffs.lifetime).is_greater(5.0)


## In the entrance: the bank is poured on the fog cue and left to dissipate on
## the cue after (the WHOA), not freed on the spot.
func test_the_entrance_pours_dry_ice_on_the_fog_cue_and_leaves_it_after() -> void:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = true
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = "cody"
	add_child(scene)
	auto_free(scene)
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var cody: WrestlerController = scene.get_node("WrestlerA")
	# Step to the beat that carries the fog cue.
	var guard := 0
	while director.get_node_or_null("DryIce") == null and guard < 40000:
		director._physics_process(1.0 / 60.0)
		guard += 1
	var ice := director.get_node_or_null("DryIce") as DryIce
	assert_object(ice).override_failure_message("no dry ice by the fog cue").is_not_null()
	assert_bool(ice.is_stopped()).is_false()
	director._event(cody, "fog_off")
	assert_bool(ice.is_stopped()).is_true()
	assert_bool(is_instance_valid(ice) and ice.is_inside_tree()).is_true()
