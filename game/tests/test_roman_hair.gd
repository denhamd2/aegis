extends GdUnitTestSuite
## Roman's hair moves (RomanModel._add_hair_springs): the rig's own hair
## chains are driven by a SpringBoneSimulator3D, so the lengths off the back
## of his head swing a few centimetres with a walk and never through his back.

var _model: Node3D
var _worn: Skeleton3D


func before_test() -> void:
	_model = (load("res://scenes/roman_model.tscn") as PackedScene).instantiate()
	add_child(_model)
	for sk: Skeleton3D in _model.find_children("", "Skeleton3D", true, false):
		if sk.find_bone("J_Hair_b") >= 0:
			_worn = sk


func after_test() -> void:
	_model.queue_free()


func test_every_hair_chain_is_simulated_from_the_nape() -> void:
	var sim := _worn.get_node("HairSprings") as SpringBoneSimulator3D
	assert_int(sim.get_setting_count()).is_equal(35)
	for k in sim.get_setting_count():
		var root := sim.get_root_bone(k)
		# The slicked top stays on the scalp: nothing above the nape swings.
		assert_float(_worn.get_bone_global_rest(root).origin.y).is_less(RomanModel.HAIR_SPRING_FROM_Y)
		assert_int(sim.get_joint_count(k)).is_greater(2)


func test_the_hair_swings_with_a_walk_and_stays_off_his_back() -> void:
	var player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play("Walk")
	var head := _worn.find_bone("J_Head")
	var tip := _worn.find_bone("Hair_b00_10")
	var rest := _worn.get_bone_global_rest(head).affine_inverse() * _worn.get_bone_global_rest(tip).origin
	var sim := _worn.get_node("HairSprings") as SpringBoneSimulator3D
	var swing := [0.0, 1.0, 0]   # the largest swing; the deepest the tip went into a collider
	_worn.skeleton_updated.connect(func():
		# Past the first updates, before the clip and the springs have run.
		swing[2] += 1
		if swing[2] < 10:
			return
		var rel := _worn.get_bone_global_pose(head).affine_inverse() * _worn.get_bone_global_pose(tip).origin
		swing[0] = maxf(swing[0], rel.distance_to(rest))
		var p := _worn.global_transform * _worn.get_bone_global_pose(tip).origin
		for c in sim.get_children():
			swing[1] = minf(swing[1], _clearance(c, p)))
	for i in 150:
		await get_tree().process_frame
	# It moves -- not a helmet -- and not wildly.
	assert_float(swing[0]).is_between(0.015, 0.2)
	# The tip lies on his back, never through him (a centimetre of give).
	assert_float(swing[1]).is_greater(-0.01)


## How far p is outside collider c (negative: inside it).
static func _clearance(c: Node3D, p: Vector3) -> float:
	var scale := c.global_transform.basis.get_scale().x
	var local := c.global_transform.affine_inverse() * p
	if c is SpringBoneCollisionCapsule3D:
		var cap := c as SpringBoneCollisionCapsule3D
		var half := maxf(cap.height * 0.5 - cap.radius, 0.0)
		local.y = local.y - clampf(local.y, -half, half)
		return (local.length() - cap.radius) * scale
	if c is SpringBoneCollisionSphere3D:
		return (local.length() - (c as SpringBoneCollisionSphere3D).radius) * scale
	return 1.0


## The scalp cap's surface map (build_roman_hair_alpha.py, paint_scalp_cap)
## carries the face's skin roughness as its smoothest value in R, at a
## material roughness of 1.0 -- so it and SKIN_ROUGHNESS must agree, or the
## face changes when the map is rebuilt. It reaches matte under the cap, and
## G (metallic) is ~zero wherever R is at skin roughness: no metal on the face.
func test_head_surface_map_keeps_the_face_at_skin_roughness() -> void:
	var path := "res://assets/characters/roman_reigns_head_rm.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGB8)
	var skin := roundi(RomanModel.SKIN_ROUGHNESS["Material.001"] * 255.0)
	var lo := 255
	var hi := 0
	var metal_on_skin := 0
	var data := image.get_data()
	for i in range(0, data.size(), 3 * 7):
		lo = mini(lo, data[i])
		hi = maxi(hi, data[i])
		if data[i] == skin:
			metal_on_skin = maxi(metal_on_skin, data[i + 1])
	assert_int(lo).is_equal(skin)
	assert_int(hi).is_greater(240)
	# A texel the cap's feather barely reaches rounds to skin roughness with
	# a 1/255 of metal; under 1% is nothing a render can show.
	assert_int(metal_on_skin).is_less_equal(2)


## The materials the hair pass sets: the head reads its roughness from the
## map, the hair reflects less than the 0.5 default, the beard is its own warm
## brown-black rather than the hair's tint.
func test_hair_beard_and_scalp_materials() -> void:
	var seen := {}
	for mi: MeshInstance3D in _model.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			var m := mi.get_surface_override_material(s) as BaseMaterial3D
			if source == null or m == null:
				continue
			var key := source.resource_name
			if key == "Material.001":
				assert_float(m.roughness).is_equal(1.0)
				assert_float(m.metallic).is_equal(1.0)
				assert_object(m.roughness_texture).is_not_null()
				assert_object(m.metallic_texture).is_same(m.roughness_texture)
				seen["head"] = true
			elif key == "beard":
				assert_bool(m.albedo_color.is_equal_approx(RomanModel.BEARD_COLOR)).is_true()
				assert_float(m.metallic_specular).is_equal_approx(RomanModel.BEARD_SPECULAR, 0.001)
				seen["beard"] = true
			elif key == "Material.018":
				assert_float(m.metallic_specular).is_equal_approx(RomanModel.HAIR_SPECULAR, 0.001)
				seen["hair"] = true
	assert_int(seen.size()).is_equal(3)


## The wave map (build_roman_hair_alpha.py, build_wave_normal) and the wave
## bent into the geometry (RomanModel.hair_wave) are one wave: the map's
## tilt along the strand must follow cos() of the phase RomanModel computes,
## on the hanging lengths, and be flat over the crown. If either side's
## wavelength, height span or phase formula drifts, the bands of light stop
## sitting on the bends.
func test_wave_map_follows_the_geometry_wave() -> void:
	var path := "res://assets/characters/roman_reigns_hair_wave_nrm.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var span := RomanModel.HAIR_WAVE_Y.y - RomanModel.HAIR_WAVE_Y.x
	for column: int in [37, 200, 381]:
		var u2 := (column + 0.5) / image.get_width()
		var sxy := 0.0
		var sxx := 0.0
		var syy := 0.0
		var crown := 0.0
		for row in image.get_height():
			var v2 := (row + 0.5) / image.get_height()
			var y := RomanModel.HAIR_WAVE_Y.y - v2 * span
			var g := image.get_pixel(column, row).g - 0.5
			if y > RomanModel.HAIR_WAVE_HANG_Y.y:
				crown = maxf(crown, absf(g))
			elif y < RomanModel.HAIR_WAVE_HANG_Y.x:
				var expected := -cos(TAU * ((RomanModel.HAIR_WAVE_Y.y - y)
						/ RomanModel.HAIR_WAVE_LENGTH + RomanModel.hair_wave_phase(u2)))
				sxy += g * expected
				sxx += g * g
				syy += expected * expected
		assert_float(sxy / sqrt(sxx * syy)).is_greater(0.95)
		assert_float(crown).is_less(0.01)


## The flyaways exist and stay sparse (between 2% and 12.5% of the scalp's
## triangles again: one in FLYAWAY_EVERY of the nape's), and the supplied
## sheet is cut below RINGLET_SHEET_CUT for the ringlets -- a real share of
## the scalp, but most of it stays. Then the count adds up: nothing else
## touched the scalp's triangles.
func test_flyaways_and_the_sheet_cut_stay_in_proportion() -> void:
	var source := (load("res://assets/characters/roman_reigns.glb") as PackedScene).instantiate()
	var before := _scalp_triangles(source)
	source.free()
	assert_int(before).is_greater(0)
	var scalp: MeshInstance3D = null
	for mi: MeshInstance3D in _model.find_children("", "MeshInstance3D", true, false):
		if mi.has_meta("hair_flyaways"):
			scalp = mi
	assert_object(scalp).is_not_null()
	var added: int = scalp.get_meta("hair_flyaways")
	var cut: int = scalp.get_meta("hair_cut")
	assert_int(added).is_between(before / 50, before / 8)
	assert_int(cut).is_between(before / 50, before / 3)
	assert_int(_scalp_triangles(_model)).is_equal(before - cut + added)


## The ringlets (tools/blender/roman_ringlets.py) hang on the skeleton that
## carries his hair chains, skinned to it by name, and every bind is his own
## hair's bind for that bone -- so they sit where they were built and the
## springs swing them. Some binds are hair-chain bones, some J_Chest.
func test_ringlets_ride_his_hair_chains() -> void:
	var ringlets := _worn.get_node_or_null("Ringlets") as MeshInstance3D
	assert_object(ringlets).is_not_null()
	assert_object(ringlets.get_node_or_null(ringlets.skeleton)).is_same(_worn)
	var hair_binds := {}
	for mi: MeshInstance3D in _model.find_children("", "MeshInstance3D", true, false):
		if mi.name == "hair_ALPHA_skinned" and mi.skin:
			for i in mi.skin.get_bind_count():
				hair_binds[mi.skin.get_bind_name(i)] = mi.skin.get_bind_pose(i)
	var skin := ringlets.skin
	var checked := 0
	for i in skin.get_bind_count():
		var bone := skin.get_bind_name(i)
		assert_int(_worn.find_bone(bone)).is_greater_equal(0)
		if hair_binds.has(bone):
			var a: Transform3D = skin.get_bind_pose(i)
			var b: Transform3D = hair_binds[bone]
			assert_float(a.origin.distance_to(b.origin)).is_less(0.001)
			checked += 1
	assert_int(checked).is_greater(50)
	var tris: int = ringlets.mesh.surface_get_array_index_len(0) / 3
	assert_int(tris).is_between(3000, 12000)


static func _scalp_triangles(root: Node) -> int:
	for mi: MeshInstance3D in root.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and m.resource_name == RomanModel.FLYAWAY_MATERIAL:
				return mi.mesh.surface_get_array_index_len(s) / 3
	return 0
