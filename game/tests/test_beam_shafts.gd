extends GdUnitTestSuite
## The stage's beam lights draw thin shafts (BeamShafts): the owner's 2026
## stills (18 Oct) show pencils of light, and fog alone smeared them broad.


func _rig() -> ArenaLighting:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	return rig


func test_every_stage_beam_has_a_thin_shaft_down_it() -> void:
	var rig := _rig()
	var count := 0
	for child in rig.get_children():
		if not (child is SpotLight3D):
			continue
		var light := child as SpotLight3D
		var shaft := light.get_node_or_null("Shaft") as MeshInstance3D
		assert_bool(shaft != null).is_equal(ArenaLighting.is_stage_beam(light.name))
		if shaft == null:
			continue
		count += 1
		# Down the beam (-Z, the light's forward), and narrower than its cone.
		var aabb := shaft.mesh.get_aabb()
		assert_float(aabb.position.z).is_less(-5.0)
		var length := -aabb.position.z
		var half_width := aabb.size.x * 0.5
		assert_float(half_width).is_less(length * tan(deg_to_rad(light.spot_angle)))
	assert_int(count).is_equal(4 + ArenaLighting.STAGE_SPOT_COUNT)


func test_the_stage_beams_are_tight() -> void:
	assert_float(ArenaLighting.ACCENT_ANGLE).is_less_equal(4.0)
	assert_float(ArenaLighting.STAGE_SPOT_ANGLE).is_less_equal(4.0)


func test_a_cone_runs_lens_to_end() -> void:
	var mesh := BeamShafts.cone(10.0, 0.5)
	var aabb := mesh.get_aabb()
	assert_float(aabb.position.z).is_equal_approx(-10.0, 0.001)
	assert_float(aabb.end.z).is_equal_approx(0.0, 0.001)
	assert_float(aabb.size.x).is_equal_approx(1.0, 0.01)


## Show lighting, as a Dynamite broadcast runs it (the owner, 19 Oct): the
## stage's beams are up for the entrances and dark, parked, once the bell goes.
func test_the_stage_beams_are_up_for_entrances_and_dark_for_the_match() -> void:
	var rig := _rig()
	rig.set_look(ArenaLighting.Look.MATCH)
	for light in rig._stage_beams:
		assert_float(light.light_energy).override_failure_message(
				"%s lit in the match" % light.name).is_equal(0.0)
	rig.set_look(ArenaLighting.Look.ENTRANCE)
	for light in rig._stage_beams:
		assert_float(light.light_energy).is_greater(0.0)


## And the deck heads move with the music while they are up.
func test_the_deck_heads_sweep_in_the_entrance_look() -> void:
	var rig := _rig()
	rig.set_look(ArenaLighting.Look.ENTRANCE)
	var head: SpotLight3D = null
	for light in rig._stage_beams:
		if String(light.name).begins_with("Accent"):
			head = light
			break
	var before := -head.transform.basis.z
	rig._sweep_phase = 1.3
	rig._move_stage_beams()
	assert_float(before.angle_to(-head.transform.basis.z)).is_greater(0.05)
	# parked again for the match
	rig.set_look(ArenaLighting.Look.MATCH)
	assert_vector(-head.transform.basis.z).is_equal_approx(before, Vector3.ONE * 0.001)
