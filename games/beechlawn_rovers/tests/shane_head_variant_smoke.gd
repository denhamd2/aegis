extends SceneTree
## Individual identity changes must preserve shared resources and skin bindings.
func _initialize() -> void:
	call_deferred("_run")

func _part(rig: Node, name: String) -> MeshInstance3D:
	return rig.find_child(name, true, false) as MeshInstance3D

func _run() -> void:
	var packed := load("res://assets/characters/shared/heads/players/shane_denham.glb") as PackedScene
	var package := packed.instantiate()
	var hair_package := (load("res://assets/characters/shared/heads/shane_crop.glb") as PackedScene).instantiate()
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var shane: FootballPlayer
	var other: FootballPlayer
	for actor in game._home_players:
		if actor.profile.player_id == &"shane_denham":
			shane = actor
		elif actor.profile.role == "outfield":
			other = actor
	assert(shane != null and other != null)
	var visual := shane.get_node("Visual") as FootballerVisual
	var rig := visual.get_node("Rig")
	var other_rig := other.get_node("Visual/Rig")
	var base_head := _part(other_rig, "Skin_Head").mesh
	assert(_part(rig, "Skin_Head").mesh != base_head, "Shane's finished sculpt must remain independent of the common starting head")
	assert(_part(rig, "YBot_Surface").mesh == _part(other_rig, "YBot_Surface").mesh, "Body remains shared")
	var part_names := ["Skin_Head", "Eye_l", "Eye_r", "Hair_Shane_ShortCropRoots", "Hair_Shane_ShortCropCards", "Mouth_UpperTeeth"]
	for name in part_names:
		var live := _part(rig, name)
		var source := _part(hair_package if name.begins_with("Hair_") else package, name)
		assert(live.mesh == source.mesh, "Head package part missing: " + name)
		assert(live.skin.get_bind_count() == source.skin.get_bind_count())
		for index in live.skin.get_bind_count():
			assert(live.skin.get_bind_name(index) == source.skin.get_bind_name(index), "Skin bind name/index mismatch")
			assert(live.skin.get_bind_pose(index).is_equal_approx(source.skin.get_bind_pose(index)), "Inverse bind changed")
		assert(live.mesh.get_aabb().size.is_finite())
	var head := _part(rig, "Skin_Head")
	assert(head.mesh.get_blend_shape_count() >= 2)
	assert(head.mesh.get_blend_shape_name(1) == &"Blink")
	assert(head.mesh.get_blend_shape_name(0) == &"Smile")
	assert(is_zero_approx(head.get_blend_shape_value(0)), "Neutral identity is independent of smile")
	var teeth := _part(rig,"Mouth_UpperTeeth")
	assert(teeth.get_parent()==head.get_parent() and teeth.transform.is_equal_approx(head.transform))
	assert(teeth.mesh.get_aabb().size.x>.045 and teeth.mesh.get_aabb().size.x<.075,"Teeth must retain real head scale")
	assert(teeth.mesh.get_faces().size()/3<1000,"Small original dental geometry must remain bounded")
	for actor in game._home_players + game._away_players:
		assert(actor.get_node("Visual/Rig").find_children("*", "Skeleton3D", true, false).size() == 1)
	visual.animation_tree.active = false
	var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for clip in [&"AN_Beechlawn_Idle", &"AN_Beechlawn_Sprint", &"AN_Beechlawn_PassRight", &"AN_Beechlawn_ShotRight", &"AN_Beechlawn_Turn90Left"]:
		visual.animation_player.play(clip)
		var length := visual.animation_player.current_animation_length
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			visual.animation_player.seek(length * fraction, true)
			await process_frame
			for index in skeleton.get_bone_count():
				assert(skeleton.get_bone_global_pose(index).origin.is_finite())
	# Reconfiguration/substitution must restore the original identity resources.
	visual.configure_appearance(other.profile)
	assert(head.mesh == base_head)
	assert(rig.find_children("Mouth_*","MeshInstance3D",true,false).is_empty(),"Previous identity's teeth survived a substitution")
	visual.configure_appearance(shane.profile)
	assert(head.mesh == _part(package, "Skin_Head").mesh)
	assert(rig.find_children("Mouth_*","MeshInstance3D",true,false).size()==1,"Reconfiguration duplicated oral geometry")
	assert(_part(other_rig, "Skin_Head").mesh == base_head, "A teammate's identity changed")
	var fixture := load("res://data/players/shane_denham.tres") as FootballerProfile
	assert(fixture.appearance.head_variant == packed, "Retained 4v4 profile must use the same head")
	print("PASS: independent Shane head/eyes and groom, inverse binds, smile, pose samples and shared body")
	hair_package.free()
	package.free()
	game.free()
	quit(0)
