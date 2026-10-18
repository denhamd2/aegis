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
