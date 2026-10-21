extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var home: Array = game._home_players
	var away: Array = game._away_players
	var home_a := home[2].get_node("Visual/Rig").find_children("YBot_Surface","MeshInstance3D",true,false)[0] as MeshInstance3D
	var home_b := home[3].get_node("Visual/Rig").find_children("YBot_Surface","MeshInstance3D",true,false)[0] as MeshInstance3D
	var away_a := away[2].get_node("Visual/Rig").find_children("Kit_Shirt_ShortSleeve","MeshInstance3D",true,false)[0] as MeshInstance3D
	var mat_a := home_a.get_surface_override_material(0) as StandardMaterial3D
	var mat_b := home_b.get_surface_override_material(0) as StandardMaterial3D
	var mat_away := away_a.get_surface_override_material(0) as StandardMaterial3D
	assert(mat_a != null and mat_b==mat_a and mat_away != mat_a)
	# Both goalkeeper slots must load their own atlas through the real 11v11
	# profile path, including the cloth data map used by the shared body.
	var home_keeper: FootballPlayer = null
	var away_keeper: FootballPlayer = null
	for actor in home:
		if actor.profile.role == "goalkeeper": home_keeper = actor
	for actor in away:
		if actor.profile.role == "goalkeeper": away_keeper = actor
	assert(home_keeper != null and away_keeper != null)
	for entry in [[home_keeper, "beechlawn_keeper"], [away_keeper, "bordeaux_keeper"]]:
		var keeper: FootballPlayer = entry[0]
		var kit_name: String = entry[1]
		assert(keeper.profile.appearance.kit == kit_name)
		var shirt := keeper.get_node("Visual/Rig").find_children("YBot_Surface", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var kit := shirt.get_surface_override_material(0) as StandardMaterial3D
		assert(kit != null and kit.resource_name == "SharedKit_" + kit_name)
		assert(kit.albedo_texture != null and kit.roughness_texture != null)
		assert(kit.normal_texture == mat_a.normal_texture)
		assert(kit.albedo_texture.get_image().has_mipmaps())
		assert(kit.roughness_texture.get_image().has_mipmaps())
	assert(home_keeper.profile.appearance.print_name == "J. O’ROURKE")
	assert(away_keeper.profile.appearance.print_name == "FEENEY")
	assert(mat_a.normal_texture == mat_away.normal_texture, "Roles must reuse one knit normal resource")
	# Actual replacement path must retain portable, mipmapped PBR data. A
	# flat roughness scalar or sRGB sampling of this mask loses the print/cloth
	# distinction; missing mips aliases at the match camera.
	for material in [mat_a, mat_away]:
		assert(material.roughness_texture != null and material.normal_texture != null)
		assert(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED)
		assert(material.normal_texture.get_image().has_mipmaps())
		assert(material.roughness_texture.get_image().has_mipmaps())
		assert(material.albedo_texture.get_image().has_mipmaps())
	var rough_image := mat_a.roughness_texture.get_image()
	# Atlas coordinates: blue shirt body, white sponsor, elastic sock. Sample
	# the imported mask rather than reproducing its generation formula.
	var cloth := rough_image.get_pixel(290, 440).r
	var ink := rough_image.get_pixel(241, 240).r
	var elastic := rough_image.get_pixel(530, 900).r
	assert(ink < cloth and cloth < elastic, "Print, shirt and sock must retain distinct roughness")
	print("Shared fabric imported mask: ink=", ink, " cloth=", cloth, " sock=", elastic,
		" normal_bytes_with_mips=", mat_a.normal_texture.get_image().get_data().size(),
		" role_roughness_bytes_with_mips=", rough_image.get_data().size())
	var before := mat_a.roughness
	var away_before := mat_away.roughness
	mat_a.roughness=0.42
	assert(is_equal_approx(mat_b.roughness,0.42) and is_equal_approx(mat_away.roughness,away_before),"Shared kit edit must propagate within its role, not across teams")
	mat_a.roughness=before
	var tree_a := home[2].get_node("Visual/AnimationTree") as AnimationTree
	var tree_b := home[3].get_node("Visual/AnimationTree") as AnimationTree
	tree_a.set("parameters/Locomotion/blend_position",0.2)
	tree_b.set("parameters/Locomotion/blend_position",0.8)
	assert(is_equal_approx(float(tree_a.get("parameters/Locomotion/blend_position")),0.2))
	assert(is_equal_approx(float(tree_b.get("parameters/Locomotion/blend_position")),0.8),"Playback parameters must remain independent")
	print("Shared roster resources PASS: kit edits propagate, opposing kit isolated, playback independent")
	game.free();quit(0)
