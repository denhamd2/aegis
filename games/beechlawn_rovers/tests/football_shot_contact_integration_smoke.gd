extends SceneTree
## Verifies the shot impulse is gated on the Blender-authored toe-contact frame.

const MATCH_SCENE := "res://scenes/training_ground.tscn"
var _contact_time := -1.0
var _toe_at_contact := Vector3.ZERO
var _ball_at_contact := Vector3.ZERO
var _visual: FootballerVisual
var _ball: FootballBall


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_path := OS.get_environment("BEECHLAWN_MATCH_SCENE")
	var packed := load(scene_path if not scene_path.is_empty() else MATCH_SCENE) as PackedScene
	assert(packed != null, "Could not load match scene")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var player := game.get_node("Player") as FootballPlayer
	_ball = game.get_node("Ball") as FootballBall
	_visual = player.get_node("Visual") as FootballerVisual
	assert(_visual != null and _ball != null, "Match shot actor or ball is missing")
	_visual.action_contact.connect(_record_contact)
	game.set_process(false)
	game.set_physics_process(false)
	game.call("_set_players_physics_enabled", false)
	player.controlled_by_human = false
	player.ai_move_direction = Vector3.ZERO
	var ai_chance := OS.get_environment("BEECHLAWN_AI_CHANCE") == "1"
	if ai_chance:
		player.global_position = Vector3(44.0, 0.0, 0.0)
		player.rotation.y = -PI / 2.0
		for defender in game._away_players:
			defender.global_position = Vector3(-40.0, 0.0, 25.0)
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO

	# Sample the shot's authored contact pose, then put the live ball at that
	# point. Restore locomotion before starting the action through player logic.
	_visual.animation_tree.active = false
	_visual.animation_player.play("AN_Beechlawn_ShotRight")
	_visual.animation_player.seek(0.3, true)
	await physics_frame # AnimationPlayer is configured to evaluate on the physics tick.
	var skeleton := _visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var toe_index := skeleton.find_bone("mixamorig_RightToe_End")
	assert(toe_index >= 0, "Shot test could not find right toe tip")
	var setup_toe := skeleton.to_global(skeleton.get_bone_global_pose(toe_index).origin)
	_ball.global_position = setup_toe + Vector3.UP * 0.06
	_visual.animation_player.stop()
	_visual.animation_tree.active = true
	await process_frame
	var starting_serial := _ball.action_serial
	if ai_chance:
		_ball.last_touch = player.team_name
		game._apply_carrier_action(player, game._home_players, game._away_players)
	else:
		player.call("_do_shot", 0.55)
	assert(player.get("_visual_shot_pending"), "Shot did not queue its contact action")
	assert(_visual.animation_player.current_animation == "AN_Beechlawn_ShotRight",
		"Shot did not start its Blender-authored animation")
	for frame in 12:
		await physics_frame
	assert(_ball.action_serial == starting_serial,
		"Shot impulse occurred before the authored contact time")
	_ball.freeze = false
	for frame in 8:
		await physics_frame
	assert(_ball.action_serial == starting_serial + 1 and _ball.last_action == &"shot",
		"Shot contact marker did not apply exactly one physical shot")
	assert(_contact_time > 0.0 and absf(_contact_time - 0.3) < 0.06,
		"Shot event did not line up with Blender contact metadata: %.3f" % _contact_time)
	if _toe_at_contact.distance_to(_ball_at_contact) > 0.14:
		push_error("Shot impulse was not aligned with toe contact: %.3f m; toe=%s ball=%s event=%.3f" % [
			_toe_at_contact.distance_to(_ball_at_contact), str(_toe_at_contact),
			str(_ball_at_contact), _contact_time])
		quit(1)
		return
	assert(_ball.linear_velocity.length() > player.tuning.shot_min_speed * 0.6,
		"Shot contact did not produce the requested ball velocity")
	print("Beechlawn shot integration: Blender toe contact at %.3f s (gap %.3f m), one physical shot, no early impulse" % [
		_contact_time, _toe_at_contact.distance_to(_ball_at_contact)])
	quit(0)


func _record_contact(action: StringName) -> void:
	if action != &"shot":
		return
	_contact_time = _visual.animation_player.current_animation_position
	var skeleton := _visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var toe_index := skeleton.find_bone("mixamorig_RightToe_End")
	_toe_at_contact = skeleton.to_global(skeleton.get_bone_global_pose(toe_index).origin)
	_ball_at_contact = _ball.global_position
