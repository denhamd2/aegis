extends SceneTree
## Guards the first reference-led local-park and kit-prototype pass.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load("res://scenes/training_ground.tscn") as PackedScene
	assert(packed != null, "Beechlawn match scene failed to load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var park := game.get_node("ParkEdge/KilmoreDriveParkDressing")
	assert(park.get_node("ParkTurf") != null, "Local park ground did not load")
	assert(park.get_node("FarBoundaryWall") != null, "Kilmore Drive rear wall is missing")
	assert(park.get_node("Footpath") != null and park.get_node("Road") != null,
		"Roadside path and road are required in the local-park backdrop")
	assert(park.find_children("ResidentialHouse_*", "Node3D", true, false).size() == 18,
		"Residential backdrop should use staggered modular house facades")
	var far_house_faces_pitch := false
	var near_house_faces_pitch := false
	for child in park.find_children("ResidentialHouse_*", "Node3D", true, false):
		var house := child as Node3D
		if house.position.z < 0.0 and absf(house.rotation.y) < 0.01:
			far_house_faces_pitch = true
		if house.position.z > 0.0 and absf(absf(house.rotation.y) - PI) < 0.01:
			near_house_faces_pitch = true
	assert(far_house_faces_pitch and near_house_faces_pitch,
		"Residential facades on both sides must face inward toward the pitch")
	var tree_count := 0
	for child in park.get_children():
		if String(child.name).begins_with("ParkTree_"):
			tree_count += 1
	assert(tree_count >= 18 and tree_count <= 26, "Keep a bounded set of instanced park trees with an open grass apron")
	assert(park.find_children("UtilityPole*", "Node3D", true, false).size() == 3,
		"Residential-road context must include utility poles")
	assert(park.get_node("OverheadCable_0") != null,
		"Residential-road context must include static overhead cables")
	assert((park.get_node("ParkTurf") as MeshInstance3D).material_override is ShaderMaterial,
		"Local park ground should use the weathered Kilmore grass shader")
	var park_grass := (park.get_node("ParkTurf") as MeshInstance3D).material_override as ShaderMaterial
	assert(park_grass.get_shader_parameter("grass_albedo") is Texture2D,
		"Local park ground is missing the licensed grass surface texture")
	var road := park.get_node("Road") as MeshInstance3D
	assert(road.material_override is ShaderMaterial,
		"Residential road must use the asphalt surface shader")
	assert((road.material_override as ShaderMaterial).get_shader_parameter("asphalt_albedo") is Texture2D,
		"Residential road is missing the licensed asphalt surface texture")

	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	assert(home.size() == 4 and away.size() == 4, "Visual validation must stay in 4v4 scope")
	for actor in home + away:
		var actor_visual := actor.get_node_or_null("Visual") as FootballerVisual
		assert(actor_visual != null and actor_visual.animation_tree.active,
			"Every 4v4 actor must run the shared rigged visual")
		var actor_skeleton := actor_visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
		assert(actor_skeleton.get_bone_count() == 65,
			"A 4v4 actor is missing the verified shared skeleton")
	var outfielder: FootballPlayer
	var keeper: FootballPlayer
	for actor in home:
		if actor.profile.role == "goalkeeper":
			keeper = actor
		elif actor.profile.player_id == &"david_murray":
			outfielder = actor
	assert(outfielder != null and keeper != null, "Reference roster prototypes were not assembled")
	var outfield_visual := outfielder.get_node("Visual") as FootballerVisual
	assert(outfield_visual != null, "Match actor did not use the integrated rigged visual")
	assert(outfield_visual.animation_tree.active, "Match actor locomotion tree did not start")
	var skeleton := outfield_visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	assert(skeleton != null and skeleton.get_bone_count() == 65,
		"Integrated match visual does not use the verified 65-bone rig")
	var body_surface := skeleton.get_node("YBot_Surface") as MeshInstance3D
	assert(body_surface.material_override is StandardMaterial3D,
		"Reference-led team color was not applied to the animated proxy")
	assert((body_surface.material_override as StandardMaterial3D).albedo_color.is_equal_approx(
		game.get("_home_team").primary_kit_color), "Outfielder does not use Beechlawn kit colors")
	var keeper_visual := keeper.get_node("Visual") as FootballerVisual
	assert(keeper_visual != null and keeper_visual.animation_tree.active,
		"Keeper does not use the rigged visual/animation tree")
	var keeper_surface := keeper_visual.get_node("Rig/YBot_Armature/Skeleton3D/YBot_Surface") as MeshInstance3D
	assert((keeper_surface.material_override as StandardMaterial3D).albedo_color.is_equal_approx(
		game.get("_home_team").goalkeeper_kit_color), "Keeper kit color was not applied")
	var bordeaux_player: FootballPlayer
	for actor in away:
		if actor.profile.role == "outfield":
			bordeaux_player = actor
			break
	assert(bordeaux_player != null, "Bordeaux outfield prototype is missing")
	var bordeaux_visual := bordeaux_player.get_node("Visual") as FootballerVisual
	assert(bordeaux_visual != null and bordeaux_visual.animation_tree.active,
		"Bordeaux actor does not use the rigged visual/animation tree")
	var bordeaux_surface := bordeaux_visual.get_node("Rig/YBot_Armature/Skeleton3D/YBot_Surface") as MeshInstance3D
	assert((bordeaux_surface.material_override as StandardMaterial3D).albedo_color.is_equal_approx(
		game.get("_away_team").primary_kit_color), "Bordeaux team color was not applied")
	print("Kilmore park dressing and rigged 4v4 kit-color integration checks passed")
	quit(0)
