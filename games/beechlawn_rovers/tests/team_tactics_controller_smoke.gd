extends SceneTree
## Verifies tactics return decisions separately from movement execution.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var scene := load("res://scenes/training_ground.tscn") as PackedScene
	assert(scene != null, "Sunday-league match scene failed to load")
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._start_kickoff(false)

	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	for actor in home + away:
		actor.set_physics_process(false)
	var carrier: FootballPlayer = game.get_node("Player")
	var support: FootballPlayer
	for actor in home:
		if actor.profile.starting_slot == "left":
			support = actor
			break
	assert(support != null, "Could not find an AI support player")
	carrier.global_position = Vector3.ZERO
	support.global_position = Vector3(-20.0, 0.0, -8.0)
	support.ai_move_direction = Vector3(0.0, 0.0, 1.0)
	var original_move := support.ai_move_direction
	var tactics := game.get("_team_tactics") as TeamTacticsController
	var decisions := tactics.update_team_targets(home, carrier, Vector2.ZERO,
		Vector2.ZERO, away, &"none", 0.0, true, null, false,
		{"late_lead_depth": 0.0})
	assert(decisions.has(support.get_instance_id()), "Tactics controller omitted a support-role decision")
	assert(support.ai_move_direction == original_move,
		"Tactical decision calculation directly mutated movement execution")
	var decision: Dictionary = decisions[support.get_instance_id()]
	assert(decision.has("target") and decision["intent"] == "support",
		"Tactics controller did not return target and role intent")
	game._apply_ai_movement_decisions(home, decisions)
	assert(support.ai_move_direction != original_move,
		"Movement executor did not apply the returned tactical target")
	assert(support.get_meta("ai_role_intent") == "support",
		"Movement executor did not preserve the decision intent for debugging")

	print("Beechlawn team tactics / movement separation checks passed")
	quit(0)
