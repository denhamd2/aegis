extends SceneTree
## Actual intro overlay, roster identity, sequencing and retired-shirt protection.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var session := root.get_node("MatchSession")
	session.launched_from_menu = true
	session.show_intro = true
	session.mode = 1
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var director: Node = game._pre_match
	director.set_process(false)
	var walk_index := -1
	for index in director.shots.size():
		if director.shots[index]["id"] == "walk": walk_index = index
	check(walk_index >= 0, "Walkout shot exists")
	director._enter_shot(walk_index)
	var duration := float(director.shots[walk_index]["duration"])
	check(duration >= 20.0, "Each team gets at least ten readable seconds")
	var graphic: Control = director._lineup_graphic
	for team_index in 2:
		director._update_shot(duration * (0.25 if team_index == 0 else 0.75))
		check(graphic.visible and graphic.displayed_team == team_index, "Home team precedes away team during walkout")
		check(graphic.cards.size() == 11 and graphic.displayed_profiles.size() == 11, "Eleven portrait cards including keeper")
		check(graphic.ROWS[0].size() == 2 and graphic.ROWS[1].size() == 4 and graphic.ROWS[2].size() == 4 and graphic.ROWS[3].size() == 1, "4-4-2 plus goalkeeper layout")
		var expected_manager := "ROBBIE RODEN" if team_index == 0 else "DES FEENEY"
		check(graphic.manager_label.text.contains(expected_manager), "Player-manager attribution")
		var keeper_count := 0
		for profile: FootballerProfile in graphic.displayed_profiles:
			check(not profile.lineup_portrait_path.is_empty() and ResourceLoader.exists(profile.lineup_portrait_path), "Supplied portrait exists for " + profile.display_name)
			if profile.role == "goalkeeper": keeper_count += 1
			if team_index == 1:
				check(profile.display_name == "Des Feeney" and profile.lineup_portrait_path.ends_with("des_feeney.png"), "All Boardeaux slots use Des Feeney")
			else:
				check(profile.jersey_number != 2, "Retired home number is absent")
		check(keeper_count == 1, "One goalkeeper per lineup")
	check(game._home_team.retired_shirt_numbers.has(2), "Home number 2 is retired in team data")
	for profile in game._home_team.roster:
		if profile.player_id == &"colly_roden":
			check(profile.jersey_number == 14, "Colly wears number 14")
			profile.jersey_number = 2
			check("retired squad number 2" in ";".join(game._home_team.validate_roster()), "Retired number cannot be reassigned")
			profile.jersey_number = 14
	check(game.ball.freeze and game._kickoff_pending and is_equal_approx(game._remaining_time, 180.0), "Graphics do not advance authoritative match")
	director._enter_shot(walk_index + 1)
	check(not graphic.visible, "Team graphics leave after walkout")
	director.finish()
	await process_frame
	check(not is_instance_valid(graphic), "Portrait overlay resources released after intro")
	game.free()
	for message in failures: push_error(message)
	print("LINEUP_GRAPHIC home/away 4-4-2, faces, managers, retired #2/#14 and cleanup failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
