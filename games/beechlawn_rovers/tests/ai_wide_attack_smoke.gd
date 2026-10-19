extends SceneTree
## A wide carrier must improve the goal angle rather than run to the byline.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var passed := true
	var opponents: Array[FootballPlayer] = []
	for team in [game._home_players, game._away_players]:
		var actor: FootballPlayer = game._nearest_outfielder(team, Vector2.ZERO)
		actor.controlled_by_human = false
		for lateral in [-23.0, -8.0, 0.0, 8.0, 23.0]:
			for progress in [0.0, 40.0]:
				var spot := Vector2(progress * actor.attack_sign, lateral)
				actor.global_position = Vector3(spot.x, 0.0, spot.y)
				var choices: Dictionary = game._team_tactics.update_team_targets(team,
					actor, spot, spot, opponents, &"none", 0.0, true, null, false, {})
				var target: Vector2 = choices[actor.get_instance_id()]["target"]
				var inward := absf(target.y) < absf(spot.y) - 0.25
				var forward := (target.x - spot.x) * actor.attack_sign > 0.0
				var correct := forward and (inward if progress > 30.0 and absf(lateral) > 18.0 else is_equal_approx(target.y, spot.y))
				print("WIDE_CARRY team=",actor.team_name," ball=",spot," target=",target," correct=",correct)
				passed = passed and correct
		var other_team: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		var defender: FootballPlayer = game._nearest_outfielder(other_team, Vector2.ZERO)
		actor.global_position = Vector3(20.0 * actor.attack_sign, 0, 0)
		defender.global_position = Vector3(23.0 * actor.attack_sign, 0, 0)
		var blockers: Array[FootballPlayer] = [defender]
		var blocked: Dictionary = game._team_tactics.update_team_targets(team, actor,
			Vector2(20.0 * actor.attack_sign, 0), Vector2.ZERO, blockers, &"none", 0.0, true, null, false, {})
		var escape: Vector2 = blocked[actor.get_instance_id()]["target"]
		print("CARRY_ESCAPE team=",actor.team_name," target=",escape)
		passed = passed and absf(escape.y) > 0.3 and (escape.x - actor.global_position.x) * actor.attack_sign > 0.0
	game.free()
	if not passed:
		push_error("Wide final-third carriers run toward the byline without improving their shooting angle")
	quit(0 if passed else 1)
