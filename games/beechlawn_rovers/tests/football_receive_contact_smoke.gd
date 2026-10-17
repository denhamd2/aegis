extends SceneTree
## Verifies the authored Y-Bot first-touch clip reaches the incoming ball.

const MATCH_SCENE := "res://scenes/training_ground.tscn"
const VISUAL_SCENE := "res://scenes/footballer_visual.tscn"
var _visual: FootballerVisual
var _ball: FootballBall
var _contact_seen := false
var _toe_at_contact := Vector3.ZERO
var _ball_at_contact := Vector3.ZERO
var _contact_time := -1.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_packed := load(MATCH_SCENE) as PackedScene
	var visual_packed := load(VISUAL_SCENE) as PackedScene
	if match_packed == null or visual_packed == null:
		_fail("Could not load match or reusable footballer visual")
		return
	var game := match_packed.instantiate()
	root.add_child(game)
	await process_frame
	var receiver := game.get_node("Player") as FootballPlayer
	_ball = game.get_node("Ball") as FootballBall
	var visual := visual_packed.instantiate() as FootballerVisual
	if receiver == null or _ball == null or visual == null:
		_fail("Match receiver, ball, or footballer visual was not created")
		return
	game.call("_set_players_physics_enabled", false)
	receiver.global_position = Vector3.ZERO
	receiver.rotation.y = -PI * 0.5
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.global_position = Vector3(0.55, 0.045, 0.0)
	visual.name = "Visual"
	receiver.add_child(visual)
	_visual = visual
	receiver.bind_footballer_visual(visual)
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	if skeleton.find_bone("mixamorig_RightToe_End") < 0:
		_fail("Y-Bot right toe tip bone is unavailable")
		return
	visual.action_contact.connect(_on_action_contact)
	if not visual.play_receive():
		_fail("Reusable visual could not start its right-foot receive clip")
		return
	for frame in 24:
		await physics_frame
	if not _contact_seen:
		_fail("Receive clip did not emit its Blender-authored contact at %.3f s" % (20.0 / 60.0))
		return
	var distance := _toe_at_contact.distance_to(_ball_at_contact)
	if absf(_contact_time - 20.0 / 60.0) > 0.06:
		_fail("Receive contact event was at %.3f s, expected %.3f s" % [_contact_time, 20.0 / 60.0])
		return
	if distance > 0.14:
		_fail("Receive toe missed incoming ball (distance=%.3fm toe=%s ball=%s)" % [
			distance, str(_toe_at_contact), str(_ball_at_contact)])
		return
	for frame in 25:
		await physics_frame
	if not visual.animation_tree.active:
		_fail("Locomotion did not resume after first-touch animation")
		return
	print("Beechlawn receive integration: toe tip is %.3fm from incoming ball at %.3f s; locomotion restored" % [
		distance, _contact_time])
	quit(0)


func _on_action_contact(action: StringName) -> void:
	if action != &"receive":
		return
	_contact_seen = true
	_contact_time = _visual.animation_player.current_animation_position
	var skeleton := _visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var toe_index := skeleton.find_bone("mixamorig_RightToe_End")
	_toe_at_contact = skeleton.to_global(skeleton.get_bone_global_pose(toe_index).origin)
	_ball_at_contact = _ball.global_position


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
