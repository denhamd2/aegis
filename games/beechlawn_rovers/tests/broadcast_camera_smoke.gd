extends SceneTree
## Camera selection, persisted tuning and camera-relative movement in every family.
const Presets = preload("res://scripts/gameplay_camera_presets.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func _run() -> void:
	var session := root.get_node("MatchSession")
	var original := [session.camera_preset, session.camera_height, session.camera_zoom, session.camera_angle, session.show_intro]
	session.camera_preset = &"dynamic_wide"
	session.camera_height = 2.5
	session.camera_zoom = 0.4
	session.camera_angle = -8.0
	session.show_intro = false
	check(session.save_preferences("user://camera_smoke.cfg") == OK, "Camera settings save")
	session.camera_preset = &"missing"
	session.camera_height = 0.0
	session.show_intro = true
	session.load_preferences("user://camera_smoke.cfg")
	check(session.camera_preset == &"dynamic_wide" and is_equal_approx(session.camera_height, 2.5)
		and is_equal_approx(session.camera_zoom, 0.4) and is_equal_approx(session.camera_angle, -8.0)
		and not session.show_intro, "Camera and intro settings round trip")
	var invalid := ConfigFile.new()
	invalid.set_value("camera", "preset", "unknown")
	invalid.set_value("camera", "height", -100)
	invalid.set_value("camera", "zoom", 100)
	invalid.save("user://camera_smoke.cfg")
	session.load_preferences("user://camera_smoke.cfg")
	check(session.camera_preset == Presets.DEFAULT and is_equal_approx(session.camera_height, -4.0)
		and is_equal_approx(session.camera_zoom, 1.0), "Invalid preferences fall back and clamp")
	DirAccess.remove_absolute("user://camera_smoke.cfg")
	session.camera_height = 0.0
	session.camera_zoom = 0.0
	session.camera_angle = 0.0
	session.launched_from_menu = false
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var rig: Node3D = game.camera_rig
	var actor: FootballPlayer = game.player
	for id in Presets.PRESETS:
		rig.preset_id = id
		rig.apply_settings()
		rig.reset_tracking()
		var camera: Camera3D = rig.camera
		check(camera.global_transform.is_finite(), "Finite camera " + str(id))
		check(camera.is_position_in_frustum(game.ball.global_position), "Ball visible in " + str(id))
		var right := camera.global_basis.x
		right.y = 0.0
		var forward := -camera.global_basis.z
		forward.y = 0.0
		actor.controlled_by_human = true
		actor._stick = Vector2.RIGHT
		actor.velocity = Vector3.ZERO
		actor._update_locomotion(0.1)
		actor.velocity.y = 0.0
		check(actor.velocity.normalized().dot(right.normalized()) > 0.95, "Screen-right movement " + str(id))
		actor._stick = Vector2.UP
		actor.velocity = Vector3.ZERO
		actor._update_locomotion(0.1)
		actor.velocity.y = 0.0
		check(actor.velocity.normalized().dot(forward.normalized()) > 0.95, "Screen-up movement " + str(id))
		print("CAMERA_CHECK ", id, " position=", camera.global_position, " fov=", camera.fov)
	rig.preset_id = &"blimp"
	session.camera_angle = 0.0
	rig.apply_settings()
	rig.reset_tracking()
	var overhead_right: Vector3 = rig.camera.global_basis.x
	session.camera_angle = 15.0
	rig.apply_settings()
	rig.reset_tracking()
	check(rig.camera.global_basis.x.dot(overhead_right) < 0.99, "Overhead angle tuning rotates the tactical view")
	game.free()
	session.camera_preset = original[0]
	session.camera_height = original[1]
	session.camera_zoom = original[2]
	session.camera_angle = original[3]
	session.show_intro = original[4]
	if not failures.is_empty():
		push_error("Camera checks: " + "; ".join(failures))
	print("Camera presets/settings/movement checks failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
