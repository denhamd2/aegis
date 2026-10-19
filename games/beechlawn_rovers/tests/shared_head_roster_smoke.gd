extends SceneTree
## Verify production actors share the master while overrides stay local.
func _initialize() -> void:
	call_deferred("_run")

func _part(rig: Node, name: String) -> MeshInstance3D:
	return rig.find_child(name, true, false) as MeshInstance3D

func _run() -> void:
	var package := (load("res://assets/characters/shared/heads/master.glb") as PackedScene).instantiate()
	var master := _part(package, "Skin_Head").mesh
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
	for actor in actors:
		var visual := actor.get_node("Visual") as FootballerVisual
		var rig := visual.get_node("Rig")
		assert(rig.find_children("*", "Skeleton3D", true, false).size() == 1)
		assert(_part(rig, "Skin_Head").mesh == master, "Unedited roster head must share master")
		for eye in ["Eye_l", "Eye_r"]:
			assert(_part(rig, eye).mesh == _part(package, eye).mesh)
		var body := _part(rig, "YBot_Surface").mesh
		if common_body == null:
			common_body = body
		assert(body == common_body, "Head selection must preserve common body")
		var appearance := visual._appearance_profile.appearance
		for name in ["Hair_Shane_ShortCropRoots", "Hair_Shane_ShortCropCards"]:
			assert(_part(rig, name).visible == (appearance.hair_style != "bald"))
		if appearance.hair_style == "bald":
			bald_count += 1
	assert(bald_count == 3, "Des, reused Des keeper and referee use bald selection")
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
	assert(not _part(visual.get_node("Rig"), "Hair_Shane_ShortCropCards").visible)
	visual.configure_appearance(first.profile)
	assert(_part(visual.get_node("Rig"), "Skin_Head").mesh == master)
	assert(_part(visual.get_node("Rig"), "Hair_Shane_ShortCropCards").visible)
	print("PASS: 22 players + referee, shared head/body/eyes, bald selection, local override and reconfiguration")
	package.free()
	game.free()
	quit(0)
