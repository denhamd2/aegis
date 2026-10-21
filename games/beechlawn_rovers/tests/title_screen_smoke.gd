extends SceneTree
## Real menu launch, saved preferences and control isolation in spectator mode.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _run() -> void:
	var session := root.get_node("MatchSession")
	session.show_intro = true
	var original_volume: float = session.master_volume
	var menu = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	check(get_nodes_in_group("football_players").is_empty(),"Title screen must not instantiate the 23 skinned match characters")
	check(menu.start_button.has_focus(),"Start Game needs initial keyboard focus")
	menu.open_options()
	check(menu.options_layer.visible and menu.volume_slider.has_focus(),"Options should open and receive keyboard focus")
	check(menu.start_button.focus_mode == Control.FOCUS_NONE,"Modal options must keep focus out of the background menu")
	menu.camera_select.select(1)
	menu.camera_select.item_selected.emit(1)
	check(session.camera_preset == &"dynamic_wide", "Camera option reaches session settings")
	menu.camera_select.select(0)
	menu.camera_select.item_selected.emit(0)
	menu.intro_toggle.button_pressed = false
	check(not session.show_intro, "Intro toggle reaches session settings")
	menu.intro_toggle.button_pressed = true
	menu.volume_slider.value = 35
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),0.35),"Volume should change the real master bus")
	var settings_path := "user://title_smoke.cfg"
	check(session.save_preferences(settings_path)==OK,"Preferences should save")
	session.master_volume = 0.0
	session.load_preferences(settings_path)
	check(is_equal_approx(session.master_volume,0.35),"Saved volume should round trip")
	DirAccess.remove_absolute(settings_path)
	menu.volume_slider.value = original_volume*100.0
	menu.close_options()
	check(not menu.options_layer.visible and menu.options_button.has_focus(),"Closing options should restore menu focus")
	menu.watch_button.pressed.emit()
	check(menu.selected_mode==1,"Watch selection should change launch intent")
	menu.start_button.pressed.emit()
	for frame in 8:
		await process_frame
	var game := current_scene
	check(game != null and game.name == "Beechlawn11v11","Start Game must load the full match")
	if game == null or game.name != "Beechlawn11v11":
		quit(1)
		return
	await physics_frame
	check(game._spectator_mode,"Menu choice must reach the match")
	var actors: Array = game._home_players + game._away_players
	check(actors.size()==22,"Spectator launch needs both full teams and their keepers")
	for actor in actors:
		check(not actor.controlled_by_human,"Watch mode must leave no keyboard-controlled actor")
		check(not actor.get_node("ControlMarker").visible,"Spectators must not see a human selection ring")
	check(game._intro_active and game.ball.freeze,"Menu launch should run the intro before kickoff")
	game._pre_match.finish()
	game._update_kickoff_input(1.2)
	check(not game._kickoff_pending,"Watch kickoff should start without input")
	var old_player: FootballPlayer = game.player
	game._cycle_controlled_player()
	game._set_controlled_player(actors[3])
	check(game.player == old_player,"Player-switch routes must not claim a spectator actor")
	for scoring_team in ["Boardeaux","Beechlawn Rovers"]:
		game._on_goal(scoring_team,1)
		game._physics_process(1.2)
		check(game._kickoff_pending,"Goal should prepare a restart")
		game._update_kickoff_input(1.2)
		check(not game._kickoff_pending,"Either team's spectator restart must be automatic")
		for actor in actors:
			check(not actor.controlled_by_human,"Goal restart must preserve AI control")
	game._finish_match()
	check(game._full_time,"Spectator match must end normally")
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true
	game._unhandled_key_input(back)
	for frame in 4:
		await process_frame
	check(current_scene != null and current_scene.name=="TitleScreen","Escape should return to the title screen")
	check(get_nodes_in_group("football_players").is_empty(),"Returning to title should release all match actors")
	menu = current_scene
	menu.play_button.pressed.emit()
	menu.start_button.pressed.emit()
	for frame in 8:
		await process_frame
	game = current_scene
	check(game != null and game.name=="Beechlawn11v11" and not game._spectator_mode,"Play choice should launch the human mode")
	var humans := 0
	for actor in get_nodes_in_group("football_players"):
		if actor.controlled_by_human:
			humans += 1
	check(humans==1,"Play mode needs exactly one human-controlled footballer")
	check(game._intro_active,"Play mode should also show the pre-match broadcast")
	var skip := InputEventKey.new()
	skip.keycode = KEY_SPACE
	skip.pressed = true
	game._unhandled_key_input(skip)
	check(not game._intro_active and game._kickoff_pending,"Skip must return to a pending kickoff")
	game._update_kickoff_input(1.2)
	check(game._kickoff_pending,"Human home kickoff should wait for the pass command")
	Input.action_press("pass")
	game._update_kickoff_input(0.02)
	Input.action_release("pass")
	check(not game._kickoff_pending,"Play kickoff should respond to the pass input")
	if current_scene != null:
		current_scene.free()
	print("Title/menu PASS: focus, saved mix, full 11v11 Watch/Play launches, automatic AI restarts, human input, title return; failures=",failures)
	quit(0 if failures==0 else 1)
