extends SceneTree
## Same exported match and normal window-close path as the application.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game); current_scene = game
	for frame in 3: await process_frame
	assert(game._home_players.size() == 11 and game._away_players.size() == 11)
	assert(root.get_node("GameAudio").crowd.playing)
	print("BEECHLAWN_PACKAGE_STARTUP_CLOSE venue=", game.venue.id)
	root.close_requested.emit()
