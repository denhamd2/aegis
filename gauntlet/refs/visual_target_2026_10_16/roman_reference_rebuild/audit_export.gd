extends SceneTree

func _init() -> void:
	_audit.call_deferred()

func _audit() -> void:
	var good := true
	for name: String in ["skin_wet_film", "skin_body_roughness", "cody_skin_head_roughness", "cody_skin_head_wet", "roman_reigns_skin_head_wet"]:
		var texture := load("res://assets/characters/" + name + ".png") as Texture2D
		if texture == null or texture.get_size() != Vector2(1024, 1024):
			push_error("Missing or incorrect exported skin map: " + name)
			good = false
	for entry: Array in [["cody_groom_cards", 1024], ["roman_reigns_beard_detail", 2048], ["roman_reigns_beard_detail_normal", 2048], ["roman_reigns_portrait_color", 2048], ["roman_reigns_portrait_rm", 2048], ["roman_reigns_portrait_sss", 1024], ["roman_reigns_portrait_roots", 1024], ["roman_reigns_beard_groom", 1024]]:
		var texture := load("res://assets/characters/" + entry[0] + ".png") as Texture2D
		if texture == null or texture.get_size() != Vector2(entry[1], entry[1]):
			push_error("Missing or incorrect exported character map: " + entry[0])
			good = false
	var groom_scene := load("res://assets/characters/cody_groom.glb") as PackedScene
	if groom_scene == null:
		push_error("Missing exported Cody groom")
		good = false
	else:
		var groom := groom_scene.instantiate()
		var triangles := 0
		var meshes := groom.find_children("Hair*", "MeshInstance3D", true, false)
		for mesh: MeshInstance3D in meshes:
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
		if meshes.size() != 4 or triangles != 16844 or groom.find_child("HairCap", true, false) == null:
			push_error("Exported Cody groom does not match the reviewed asset")
			good = false
		groom.free()
	if CodyModel.HAIR != "res://assets/characters/cody_groom.glb":
		push_error("Exported Cody model still points to the old groom")
		good = false
	if not is_equal_approx(SkinLook.FACE_FILM_SHARE, .18):
		push_error("Exported face film settings are stale")
		good = false
	if RomanModel.ALBEDO_FIXES["Material.001"]["texture"] != "portrait_color" or RomanModel.SURFACE_MAPS["Material.001"] != "portrait_rm":
		push_error("Exported Roman face still points to old maps")
		good = false
	if not is_equal_approx(RomanModel.FACE_NORMAL_STRENGTH, .65) or not is_equal_approx(RomanModel.FACE_SCATTER_STRENGTH, .18) or not is_equal_approx(RomanModel.LID_OPEN, -25) or not is_equal_approx(EyeLids.CLOSED_ANGLE, 40):
		push_error("Exported Roman face/lid settings are stale")
		good = false
	var roman := (load("res://scenes/roman_model.tscn") as PackedScene).instantiate() as RomanModel
	roman.set_meta("material_study", true)
	root.add_child(roman)
	RomanFaceShape.apply(roman)
	roman._fix_materials()
	var head := roman.find_child("head_skinned", true, false) as MeshInstance3D
	var roots := roman.find_child("PortraitRoots", true, false) as MeshInstance3D
	if roots == null or roots.mesh != head.mesh or roots.skin != head.skin or roots.get_node(roots.skeleton) != head.get_node(head.skeleton):
		push_error("Exported scalp roots do not follow the real head")
		good = false
	else:
		var mat := roots.material_override as BaseMaterial3D
		if mat.metallic != 0 or mat.subsurf_scatter_enabled or mat.albedo_texture == null:
			push_error("Exported scalp root material is incorrect")
			good = false
	var head_mat := head.get_surface_override_material(0) as BaseMaterial3D
	SkinLook.set_wetness(head_mat, .52) # Recorded entrance base; avoid loading scene dependencies before autoload setup.
	if head_mat.clearcoat < .10 or head_mat.clearcoat > .25 or head_mat.clearcoat_roughness > .45:
		push_error("Exported reference wet face settings are stale")
		good = false
	roman._trim_beard()
	var fibres := roman.find_child("BeardGroom", true, false) as MeshInstance3D
	if fibres == null or fibres.skin == null or fibres.mesh.surface_get_array_len(0) / 3 != 10800:
		push_error("Exported curved beard is absent or wrong budget")
		good = false
	else:
		var fibre_mat := fibres.material_override as BaseMaterial3D
		if fibre_mat.albedo_texture == null or fibre_mat.subsurf_scatter_enabled:
			push_error("Exported beard material is incorrect")
			good = false
	roman.free()
	for path: String in ["res://tools/probe/visual_target_proofs.tscn", "res://tools/probe/visual_target_stage.gd", "res://tools/probe/reference_look.tscn", "res://tools/probe/match_look.tscn"]:
		if not ResourceLoader.exists(path):
			push_error("Missing exported capture tool: " + path)
			good = false
	print("EXPORTED_RESOURCE_AUDIT ", "PASS" if good else "FAIL")
	quit(0 if good else 1)
