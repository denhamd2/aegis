extends SceneTree
## Verifies the Y-Bot pass contact event gates the existing live ball-kick path.

const MATCH_SCENE := "res://scenes/training_ground.tscn"
const VISUAL_SCENE := "res://scenes/footballer_visual.tscn"
var _contact_animation_position := -1.0
var _visual_under_test: FootballerVisual


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_packed := load(MATCH_SCENE) as PackedScene
	var visual_packed := load(VISUAL_SCENE) as PackedScene
	if match_packed == null or visual_packed == null:
		_fail("Could not load match or reusable footballer visual scene")
		return
	var game := match_packed.instantiate()
	root.add_child(game)
	await process_frame
	var passer := game.get_node("Player") as FootballPlayer
	var ball := game.get_node("Ball") as FootballBall
	var visual := visual_packed.instantiate() as FootballerVisual
	if passer == null or ball == null or visual == null:
		_fail("Match player, ball, or footballer visual was not created")
		return
	visual.name = "Visual"
	passer.add_child(visual)
	_visual_under_test = visual
	passer.bind_footballer_visual(visual)
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
	for frame in 30:
		await physics_frame
	if not visual.animation_tree.active:
		_fail("Locomotion AnimationTree did not resume after the pass clip")
		return
	print("Beechlawn pass integration: no early impulse, one physical pass at the 0.4 s animation contact, locomotion restored")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _record_contact_position(_action: StringName) -> void:
	_contact_animation_position = visual_position_for_test()


func visual_position_for_test() -> float:
	return _visual_under_test.animation_player.current_animation_position
