extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for name in ["League","Score","Clock"]:
		var label := game.get_node("HUD/"+name) as Label
		print("HUD_RECT ",name," ",label.position," ",label.size)
	var league := game.get_node("HUD/League") as Label
	var score := game.get_node("HUD/Score") as Label
	var clock := game.get_node("HUD/Clock") as Label
	assert(score.position.y>=league.position.y+league.size.y,"League and score overlap")
	assert(clock.position.y>=score.position.y+score.size.y,"Score and clock overlap")
	assert(clock.text=="03:00")
	print("HUD layout and three-minute timer PASS")
	game.free();quit(0)
