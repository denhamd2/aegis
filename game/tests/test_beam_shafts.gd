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
