extends SceneTree
## F3 is a match-level, opt-in diagnostic across human and watch modes.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/training_ground.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var overlay: Control = game.match_hud.debug_overlay
	assert(not game._debug_enabled and not overlay.visible, "Debug overlay is visible in ordinary play")
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	game._unhandled_key_input(key)
	overlay._process(0)
	assert(game._debug_enabled and overlay.visible and overlay.camera != null,
		"F3 did not enable the live overlay")
	var projected: Vector2 = overlay._screen(game.ball.global_position)
	assert(projected.x >= 0 and projected.x <= overlay.size.x and projected.y >= 0 and projected.y <= overlay.size.y,
		"Overlay camera projection is outside its canvas")
	game._cycle_controlled_player()
	overlay._process(0)
	assert(overlay.visible, "Changing the controlled player hid match diagnostics")
	game._spectator_mode = true
	game._unhandled_key_input(key)
	overlay._process(0)
	assert(not game._debug_enabled and not overlay.visible, "F3 did not hide diagnostics in watch mode")
	game._unhandled_key_input(key)
	overlay._process(0)
	assert(game._debug_enabled and overlay.visible, "F3 is unavailable in watch mode")
	print("P1 F3 debug overlay toggle and projection passed")
	quit(0)
