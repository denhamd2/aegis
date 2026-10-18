extends SceneTree
## Verifies the authored Y-Bot first-touch clip reaches the incoming ball.

const MATCH_SCENE := "res://scenes/training_ground.tscn"
var _visual: FootballerVisual
var _ball: FootballBall
var _contact_seen := false
var _receive_contact_count := 0
var _toe_at_contact := Vector3.ZERO
var _ball_at_contact := Vector3.ZERO
var _contact_time := -1.0
var _initial_pass_speed := 0.0
var _first_touch_seen := false
var _speed_after_first_touch := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_packed := load(MATCH_SCENE) as PackedScene
	if match_packed == null:
		_fail("Could not load match scene")
		return
	var game := match_packed.instantiate()
	root.add_child(game)
	await process_frame
	var receiver := game.get_node("Player") as FootballPlayer
	_ball = game.get_node("Ball") as FootballBall
	var visual := receiver.get_node_or_null("Visual") as FootballerVisual
	if receiver == null or _ball == null or visual == null:
		_fail("Match receiver, ball, or footballer visual was not created")
		return
	game.call("_set_players_physics_enabled", true)
	receiver.global_position = Vector3.ZERO
	receiver.rotation.y = -PI * 0.5
	receiver.add_collision_exception_with(_ball)
	for actor_node in get_nodes_in_group("football_players"):
		var actor := actor_node as FootballPlayer
		if actor != receiver:
			actor.set_physics_process(false)
	game.set("_kickoff_pending", false)
	_ball.freeze = false
	_ball.angular_velocity = Vector3.ZERO
	_ball.global_position = Vector3(1.55, FootballBall.RADIUS, 0.0)
	_ball.linear_velocity = Vector3(-3.0, 0.0, 0.0)
	_ball.last_touch = receiver.team_name
	_ball.last_action = &"pass"
	_ball.action_serial += 1
	_initial_pass_speed = _ball.linear_velocity.length()
	receiver.receive_target = Vector3(0.55, 0.0, 0.0)
	receiver.receive_target_time = 2.0
	_visual = visual
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	if skeleton.find_bone("mixamorig_RightToe_End") < 0:
		_fail("Y-Bot right toe tip bone is unavailable")
		return
	visual.action_contact.connect(_on_action_contact)
	if absf(visual.action_contact_time(&"receive") - 20.0 / 60.0) > 0.001:
		_fail("Receive contact time did not load from the Blender-authored metadata")
		return
	for frame in 24:
		await physics_frame
	if not _contact_seen:
		_fail("Incoming pass did not automatically start the receive clip/contact")
		return
	var distance := _toe_at_contact.distance_to(_ball_at_contact)
	if absf(_contact_time - 20.0 / 60.0) > 0.06:
		_fail("Receive contact event was at %.3f s, expected %.3f s" % [_contact_time, 20.0 / 60.0])
		return
	if distance > 0.14:
		_fail("Receive toe missed incoming ball (distance=%.3fm toe=%s ball=%s)" % [
			distance, str(_toe_at_contact), str(_ball_at_contact)])
		return
	if not _first_touch_seen:
		_fail("Receive contact marker did not resolve the physical first touch")
		return
	if _speed_after_first_touch >= _initial_pass_speed:
		_fail("First touch did not cushion the incoming pass")
		return
	for frame in 25:
		await physics_frame
	if _receive_contact_count != 1:
		_fail("The same pass triggered the receive contact %d times" % _receive_contact_count)
		return
	if not visual.animation_tree.active:
		_fail("Locomotion did not resume after first-touch animation")
		return
	if not visual.play_receive() or not visual.play_pass():
		_fail("A buffered pass could not interrupt the receive settle")
		return
	print("Beechlawn receive integration: incoming pass auto-triggered receive, toe gap %.3fm at %.3f s, first touch cushioned the ball, and pass interruption worked" % [
		distance, _contact_time])
	quit(0)


func _on_action_contact(action: StringName) -> void:
	if action != &"receive":
		return
	_contact_seen = true
	_receive_contact_count += 1
	_contact_time = _visual.animation_player.current_animation_position
	var skeleton := _visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var toe_index := skeleton.find_bone("mixamorig_RightToe_End")
	_toe_at_contact = skeleton.to_global(skeleton.get_bone_global_pose(toe_index).origin)
	_ball_at_contact = _ball.global_position
	_first_touch_seen = _ball.last_action == &"first_touch"
	_speed_after_first_touch = _ball.linear_velocity.length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
