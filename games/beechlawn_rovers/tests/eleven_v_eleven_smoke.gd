extends SceneTree
## Integration: lineup count/roles, shared art, keeper switching, terrain and restart.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/match_11v11.tscn") as PackedScene
	assert(scene != null)
	var match_scene := scene.instantiate()
	root.add_child(match_scene)
	await process_frame
	await physics_frame
	var home: Array = match_scene.get("_home_players")
	var away: Array = match_scene.get("_away_players")
	assert(home.size()==11 and away.size()==11,"Two complete starting elevens required")
	assert(get_nodes_in_group("football_players").size()==22,"Official/spectators must stay out of possession queries")
	assert(get_nodes_in_group("match_officials").size()==1,"One separate referee required")
	assert(match_scene._home_team.reserves.size()==1 and match_scene._home_team.reserves[0].jersey_number==69)
	assert(match_scene._home_team.validate_roster().is_empty())
	assert(match_scene._away_team.validate_roster().is_empty())
	for team in [home,away]:
		var keeper_count := 0
		var ids := {}
		for actor in team:
			assert(not ids.has(actor.profile.player_id))
			ids[actor.profile.player_id]=true
			if actor.profile.role=="goalkeeper":
				keeper_count+=1
				assert(actor._goalkeeper_controller != null)
			var visual := actor.get_node("Visual") as FootballerVisual
			assert(visual._human_rig,"Full match must use the shared human mesh")
		assert(keeper_count==1,"Exactly one keeper per eleven")
	var mesh_a := home[2].get_node("Visual/Rig").find_children("Skin_Head","MeshInstance3D",true,false)[0] as MeshInstance3D
	var mesh_b := home[3].get_node("Visual/Rig").find_children("Skin_Head","MeshInstance3D",true,false)[0] as MeshInstance3D
	assert(mesh_a.mesh==mesh_b.mesh,"Default heads must reuse the common base resource")
	assert(home[2].get_node("Visual/Rig/AnimationPlayer") != home[3].get_node("Visual/Rig/AnimationPlayer"),"Playback state must be independent")
	var seen := {}
	for index in 11:
		seen[match_scene.player.profile.player_id]=true
		match_scene._cycle_controlled_player()
	assert(seen.size()==11 and seen.has(&"john_orourke"),"Manual switching must reach all eleven, including keeper")
	match_scene._set_controlled_player(match_scene._kickoff_taker(home))
	match_scene._start_kickoff(false)
	for frame in 90:
		await physics_frame
	assert(not match_scene._kickoff_pending and not match_scene._full_time)
	for actor in home+away:
		assert(actor.global_position.is_finite() and absf(actor.global_position.y)<0.5,"Player floated or fell through terrain")
	var space: PhysicsDirectSpaceState3D = match_scene.get_world_3d().direct_space_state
	for point in [Vector2(10,10),Vector2(-17,-11),Vector2(36,20)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,2,point.y),Vector3(point.x,-2,point.y))
		var hit: Dictionary = space.intersect_ray(query)
		assert(not hit.is_empty())
		assert(absf(hit.position.y-PitchSurface.height_at(point.x,point.y))<0.004,"Visible terrain and collision disagree")
	match_scene._on_goal("Beechlawn Rovers",1)
	match_scene._physics_process(.5)
	assert(not match_scene.ball.freeze,"Scored ball continues into net")
	var goal_skip := InputEventKey.new()
	goal_skip.keycode=KEY_SPACE;goal_skip.pressed=true
	match_scene.presentation.handle_key(goal_skip)
	assert(match_scene._kickoff_team==&"Boardeaux" and match_scene._kickoff_pending)
	print("11v11 PASS: 22 humans, 2 keepers, separate referee, shared head, independent playback, all-player switching, terrain and restart")
	match_scene.free()
	quit(0)
