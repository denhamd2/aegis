extends SceneTree
## Verify production actors share the master while overrides stay local.
func _initialize() -> void:
	call_deferred("_run")

func _part(rig: Node, name: String) -> MeshInstance3D:
	return rig.find_child(name, true, false) as MeshInstance3D

func _head_width(mesh: Mesh) -> float:
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var left := INF
	var right := -INF
	for point in points:
		if point.y < 1.60 or point.y > 1.65 or point.z < .07:
			continue
		left = minf(left, point.x)
		right = maxf(right, point.x)
	return right - left

func _run() -> void:
	var package := (load("res://assets/characters/shared/heads/master.glb") as PackedScene).instantiate()
	var master := _part(package, "Skin_Head").mesh
	var shane_package := (load("res://assets/characters/shared/heads/players/shane_denham.glb") as PackedScene).instantiate()
	var des_package := (load("res://assets/characters/shared/heads/players/bordeaux_09.glb") as PackedScene).instantiate()
	var des_head := _part(des_package, "Skin_Head").mesh
	var des_hair_package := (load("res://assets/characters/shared/heads/des_side_hair.glb") as PackedScene).instantiate()
	var des_hair := _part(des_hair_package, "Hair_Shane_ShortCropCards").mesh
	var john_package := (load("res://assets/characters/shared/heads/players/john_orourke.glb") as PackedScene).instantiate()
	var john_head := _part(john_package, "Skin_Head").mesh
	var john_hair_package := (load("res://assets/characters/shared/heads/john_swept.glb") as PackedScene).instantiate()
	var john_hair := _part(john_hair_package, "Hair_Shane_ShortCropCards").mesh
	var referee_package := (load("res://assets/characters/shared/heads/players/des_feeney_sr.glb") as PackedScene).instantiate()
	var referee_head := _part(referee_package, "Skin_Head").mesh
	var referee_hair_package := (load("res://assets/characters/shared/heads/referee_grey.glb") as PackedScene).instantiate()
	var referee_hair := _part(referee_hair_package, "Hair_Shane_ShortCropCards").mesh
	var robbie_package := (load("res://assets/characters/shared/heads/players/robbie_roden.glb") as PackedScene).instantiate()
	var david_package := (load("res://assets/characters/shared/heads/players/david_murray.glb") as PackedScene).instantiate()
	var robbie_hair_package := (load("res://assets/characters/shared/heads/robbie_crop.glb") as PackedScene).instantiate()
	var david_hair_package := (load("res://assets/characters/shared/heads/david_crop.glb") as PackedScene).instantiate()
	assert(_head_width(_part(robbie_package,"Skin_Head").mesh) > _head_width(_part(david_package,"Skin_Head").mesh) + .025,
		"Robbie's rounder face and David's narrow face must have distinct silhouettes")
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	assert(game._home_players.size() == 11 and game._away_players.size() == 11)
	var actors: Array = []
	actors.append_array(game._home_players)
	actors.append_array(game._away_players)
	var officials := get_nodes_in_group("match_officials")
	assert(officials.size() == 1 and not actors.has(officials[0]))
	actors.append(officials[0])
	var common_body: Mesh
	var bald_count := 0
	var des_away_count := 0
	for actor in actors:
		var visual := actor.get_node("Visual") as FootballerVisual
		var rig := visual.get_node("Rig")
		assert(rig.find_children("*", "Skeleton3D", true, false).size() == 1)
		var is_bordeaux: bool = actor is FootballPlayer and String((actor as FootballPlayer).profile.player_id).begins_with("bordeaux_")
		var is_john: bool = actor is FootballPlayer and String((actor as FootballPlayer).profile.player_id) == "john_orourke"
		var is_shane: bool = actor is FootballPlayer and String((actor as FootballPlayer).profile.player_id) == "shane_denham"
		var is_robbie: bool = actor is FootballPlayer and String((actor as FootballPlayer).profile.player_id) == "robbie_roden"
		var is_david: bool = actor is FootballPlayer and String((actor as FootballPlayer).profile.player_id) == "david_murray"
		var is_referee: bool = actor == officials[0]
		var expected_head_package := des_package if is_bordeaux else (john_package if is_john else (referee_package if is_referee else (shane_package if is_shane else (robbie_package if is_robbie else (david_package if is_david else package)))))
		if is_bordeaux:
			des_away_count += 1
			assert(_part(rig, "Skin_Head").mesh == des_head, "Boardeaux players must reuse Des Feeney's individual head")
			assert(_part(rig, "Hair_Shane_ShortCropCards").mesh == des_hair, "Boardeaux players must use Des's receded side groom")
		elif is_john:
			assert(_part(rig, "Skin_Head").mesh == john_head, "John O’Rourke must use his independent goalkeeper likeness")
			assert(_part(rig, "Hair_Shane_ShortCropCards").mesh == john_hair, "John O’Rourke must use his swept highlighted blonde groom")
		elif is_referee:
			assert(_part(rig, "Skin_Head").mesh == referee_head, "Des Feeney Sr. referee must use his independent likeness")
			assert(_part(rig, "Hair_Shane_ShortCropCards").mesh == referee_hair, "Referee must retain his separate grey moustache/side groom")
		elif is_shane:
			assert(_part(rig, "Skin_Head").mesh == _part(shane_package, "Skin_Head").mesh, "Shane must use his independent refined head")
		elif is_robbie:
			assert(_part(rig, "Skin_Head").mesh == _part(robbie_package, "Skin_Head").mesh, "Robbie must use his independent head")
			assert(_part(rig, "Hair_Shane_ShortCropCards").mesh == _part(robbie_hair_package, "Hair_Shane_ShortCropCards").mesh)
		elif is_david:
			assert(_part(rig, "Skin_Head").mesh == _part(david_package, "Skin_Head").mesh, "David must use his independent head")
			assert(_part(rig, "Hair_Shane_ShortCropCards").mesh == _part(david_hair_package, "Hair_Shane_ShortCropCards").mesh)
		else:
			assert(_part(rig, "Skin_Head").mesh == master, "Unedited players must share master")
		for eye in ["Eye_l", "Eye_r"]:
			assert(_part(rig, eye).mesh == _part(expected_head_package, eye).mesh)
		if is_bordeaux or is_john or is_shane or is_referee or is_robbie or is_david:
			var face := _part(rig, "Skin_Head")
			assert(face.find_blend_shape_by_name("Blink") >= 0 and face.find_blend_shape_by_name("Smile") >= 0)
			var shift := float(absi(hash(visual._appearance_profile.player_id)) % 310) / 100.0
			visual._face_clock = 4.16 - shift
			visual._process(0)
			assert(face.get_blend_shape_value(face.find_blend_shape_by_name("Blink")) > .95, "Live fitted eyelids close")
			visual._face_clock = 1.0 - shift
			visual._process(0)
			assert(is_zero_approx(face.get_blend_shape_value(face.find_blend_shape_by_name("Blink"))), "Blink returns to neutral")
		var body := _part(rig, "YBot_Surface").mesh
		if common_body == null:
			common_body = body
		assert(body == common_body, "Head selection must preserve common body")
		var appearance := visual._appearance_profile.appearance
		# SceneTree.process_frame resumes before each Node's first _process.
		# Evaluate the real tier before checking distance-dependent visibility.
		visual._update_detail_level()
		for name in ["Hair_Shane_ShortCropRoots", "Hair_Shane_ShortCropCards"]:
			var expected_visible := appearance.hair_style != "bald"
			if name.ends_with("Cards"):
				var camera := visual.get_viewport().get_camera_3d()
				expected_visible = expected_visible and camera.global_position.distance_to(_part(rig,"Skin_Head").global_position+Vector3.UP*1.6)<18
			assert(_part(rig, name).visible == expected_visible,"Hair visibility must respect the active distance tier: "+String(visual._appearance_profile.player_id)+"/"+name)
		if appearance.hair_style == "bald":
			bald_count += 1
	assert(des_away_count == 11, "All eleven Boardeaux players use the same Des identity")
	assert(bald_count == 0, "All active identities now have fitted grooms, including the bald-crown referee's grey moustache")
	var first: FootballPlayer = game._home_players[2]
	var other: FootballPlayer = game._home_players[3]
	var visual := first.get_node("Visual") as FootballerVisual
	# A separate per-player package must override only that actor, with no rig
	# left alive by the mesh cache. Simulate a future authored sculpt resource.
	var isolated := Node3D.new()
	var head := MeshInstance3D.new()
	head.name = "Skin_Head"
	head.mesh = master.duplicate()
	isolated.add_child(head)
	head.owner = isolated
	var override := PackedScene.new()
	assert(override.pack(isolated) == OK)
	isolated.free()
	var unique := first.profile.duplicate() as FootballerProfile
	unique.appearance = first.profile.appearance.duplicate() as FootballAppearance
	unique.appearance.head_variant = override
	visual.configure_appearance(unique)
	assert(_part(visual.get_node("Rig"), "Skin_Head").mesh != master)
	assert(_part(other.get_node("Visual/Rig"), "Skin_Head").mesh == master)
	assert(visual.get_node("Rig").find_children("*", "Skeleton3D", true, false).size() == 1)
	visual.configure_appearance(load("res://data/squads/away_09.tres"))
	assert(_part(visual.get_node("Rig"), "Skin_Head").mesh == des_head)
	assert(_part(visual.get_node("Rig"), "Hair_Shane_ShortCropCards").mesh == des_hair)
	visual.configure_appearance(first.profile)
	assert(_part(visual.get_node("Rig"), "Skin_Head").mesh == master)
	assert(_part(visual.get_node("Rig"), "Hair_Shane_ShortCropCards").visible)
	print("PASS: 22 players + referee, distinct Boardeaux and referee Des heads, independent John keeper head, shared body, local override and reconfiguration")
	package.free()
	shane_package.free()
	des_package.free()
	des_hair_package.free()
	john_package.free()
	john_hair_package.free()
	referee_package.free()
	referee_hair_package.free()
	robbie_package.free()
	david_package.free()
	robbie_hair_package.free()
	david_hair_package.free()
	game.free()
	quit(0)
