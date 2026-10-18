extends SceneTree
## Verifies the Y-Bot pass contact event gates the existing live ball-kick path.

const MATCH_SCENE := "res://scenes/training_ground.tscn"
var _contact_animation_position := -1.0
var _visual_under_test: FootballerVisual
var _pass_ball: FootballBall
var _right_toe_contact := Vector3.ZERO
var _ball_contact_position := Vector3.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_path := OS.get_environment("BEECHLAWN_MATCH_SCENE")
	var match_packed := load(scene_path if not scene_path.is_empty() else MATCH_SCENE) as PackedScene
	if match_packed == null:
		_fail("Could not load match scene")
		return
	var game := match_packed.instantiate()
	root.add_child(game)
	await process_frame
	var passer := game.get_node("Player") as FootballPlayer
	var ball := game.get_node("Ball") as FootballBall
	var visual := passer.get_node_or_null("Visual") as FootballerVisual
	if passer == null or ball == null or visual == null:
		_fail("Match player, ball, or footballer visual was not created")
		return
	_visual_under_test = visual
	_pass_ball = ball
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	if skeleton.find_bone("mixamorig_RightToe_End") < 0:
		_fail("Y-Bot right toe tip bone is unavailable for contact validation")
		return
	visual.action_contact.connect(_record_contact_position)
	game.call("_start_kickoff", false)
	game.call("_set_players_physics_enabled", false)
	if ball.action_serial != 0 or not passer.get("_visual_pass_pending"):
		_fail("Kickoff did not wait for pass contact (serial=%d pending=%s clip=%s playing=%s)" % [
			ball.action_serial, str(passer.get("_visual_pass_pending")),
			str(visual.animation_player.current_animation), str(visual.animation_player.is_playing())])
		return
	for frame in 20:
		await physics_frame
	if ball.action_serial != 0:
		_fail("Pass impulse happened before the 0.4 s contact time")
		return
	for frame in 8:
		await physics_frame
	if ball.action_serial != 1 or ball.last_action != &"pass":
		_fail("Animation contact did not execute exactly one pass impulse (serial=%d action=%s pending=%s time=%.3f connected=%s player_ball=%.3f clip=%s)" % [
			ball.action_serial, String(ball.last_action), str(passer.get("_visual_pass_pending")),
			visual.animation_player.current_animation_position,
			str(visual.action_contact.is_connected(passer._on_visual_action_contact)),
			passer.global_position.distance_to(ball.global_position),
			String(visual.animation_player.current_animation)])
		return
	if ball.linear_velocity.length() < 1.0:
		_fail("Pass contact did not give the physical ball velocity")
		return
	if absf(_contact_animation_position - 0.4) > 0.06:
		_fail("Contact event was not aligned to the imported clip (%.3fs)" % _contact_animation_position)
		return
	var toe_to_ball := _right_toe_contact.distance_to(_ball_contact_position)
	var horizontal_contact := Vector2(_right_toe_contact.x - _ball_contact_position.x,
		_right_toe_contact.z - _ball_contact_position.z).length()
	var vertical_contact := absf(_right_toe_contact.y - _ball_contact_position.y)
	if toe_to_ball > 0.14:
		_fail("Ball impulse is not aligned with the toe tip contact (distance=%.3fm horizontal=%.3fm vertical=%.3fm toe=%s ball=%s)" % [
			toe_to_ball, horizontal_contact, vertical_contact, str(_right_toe_contact), str(_ball_contact_position)])
		return
	for frame in 30:
		await physics_frame
	if not visual.animation_tree.active:
		_fail("Locomotion AnimationTree did not resume after the pass clip")
		return
	print("Beechlawn pass integration: toe tip is %.3fm from ball center at 0.4 s (horizontal %.3fm, vertical %.3fm); one physical kick, locomotion restored" % [
		toe_to_ball, horizontal_contact, vertical_contact])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _record_contact_position(_action: StringName) -> void:
	_contact_animation_position = visual_position_for_test()
	var skeleton := _visual_under_test.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var toe_index := skeleton.find_bone("mixamorig_RightToe_End")
	_right_toe_contact = skeleton.to_global(skeleton.get_bone_global_pose(toe_index).origin)
	_ball_contact_position = _pass_ball.global_position


func visual_position_for_test() -> float:
	return _visual_under_test.animation_player.current_animation_position
