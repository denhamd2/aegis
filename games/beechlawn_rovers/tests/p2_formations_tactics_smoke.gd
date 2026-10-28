extends SceneTree
## Match-local formations, tactical settings and intact small-sided resources.

const EXPECTED := {
	"4-4-2": {"goalkeeper": 1, "centre_back": 2, "fullback": 2,
		"central_midfielder": 2, "winger": 2, "striker": 2},
	"4-3-3": {"goalkeeper": 1, "centre_back": 2, "fullback": 2,
		"defensive_midfielder": 1, "central_midfielder": 1, "attacking_midfielder": 1,
		"winger": 2, "striker": 1},
	"4-2-3-1": {"goalkeeper": 1, "centre_back": 2, "fullback": 2,
		"defensive_midfielder": 2, "attacking_midfielder": 1,
		"winger": 2, "striker": 1},
	"4-5-1": {"goalkeeper": 1, "centre_back": 2, "fullback": 2,
		"defensive_midfielder": 1, "central_midfielder": 2,
		"winger": 2, "striker": 1},
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original := load("res://data/teams/beechlawn_11.tres") as FootballTeam
	var original_roles := {}
	for profile in original.roster:
		original_roles[profile.starting_slot] = profile.tactical_role
	for formation in EXPECTED:
		var configuration := original.duplicate(false) as FootballTeam
		configuration.formation = formation
		var team := configuration.match_copy()
		assert(team.validate_roster().is_empty(), "Invalid %s lineup" % formation)
		var counts := {}
		var occupied := {}
		for profile in team.roster:
			counts[profile.tactical_role] = int(counts.get(profile.tactical_role, 0)) + 1
			assert(not occupied.has(profile.starting_position), "Overlapping %s formation slots" % formation)
			occupied[profile.starting_position] = true
			assert(profile != original.roster[team.roster.find(profile)], "Match shares a source profile")
		assert(counts == EXPECTED[formation], "Incorrect %s responsibilities: %s" % [formation, counts])
		assert(team.roster[0].starting_position.x < -45.0, "Keeper left the goal")
		assert(team.roster[8].starting_position.x > team.roster[5].starting_position.x,
			"Striker must start ahead of midfield")
		var graphic := preload("res://scripts/ui/lineup_graphic.gd").new()
		root.add_child(graphic)
		graphic.configure(team, team)
		graphic._rebuild(0)
		assert(graphic.cards.size() == 11, "Lineup graphic omits %s players" % formation)
		graphic.free()
	for profile in original.roster:
		assert(profile.tactical_role == original_roles[profile.starting_slot], "Source squad was mutated")
	var small := load("res://data/teams/beechlawn_rovers.tres") as FootballTeam
	assert(small.match_copy().formation == "4v4" and small.match_copy().roster.size() == 4)

	var scene := load("res://scenes/match_11v11.tscn") as PackedScene
	var game := scene.instantiate()
	var home_resource := original.duplicate(false) as FootballTeam
	home_resource.formation = "4-3-3"
	var away_resource := (load("res://data/teams/bordeaux_11.tres") as FootballTeam).duplicate(false) as FootballTeam
	away_resource.formation = "4-2-3-1"
	game.home_team_resource = home_resource
	game.away_team_resource = away_resource
	root.add_child(game)
	await process_frame
	await physics_frame
	assert(game._home_players.size() == 11 and game._away_players.size() == 11)
	assert(game._home_team.formation == "4-3-3" and game._away_team.formation == "4-2-3-1")
	game._setup_kickoff_positions(&"Beechlawn Rovers")
	for actor in game._home_players + game._away_players:
		var local: Vector2 = actor.profile.starting_position
		if actor.profile.role == "goalkeeper":
			assert(absf(actor.position.x - local.x * actor.attack_sign) < 0.01)
		elif game._away_players.has(actor):
			assert(absf(actor.position.x - minf(local.x, -10.5) * actor.attack_sign) < 0.01,
				"Away formation did not mirror into its own half")
			assert(absf(actor.position.z - local.y) < 0.01)
		assert(actor.global_position.is_finite())
	var midfielder: FootballPlayer = game._home_players[7]
	var tactics := TeamTacticsController.new()
	var narrow := tactics.formation_position(midfielder, Vector2.ZERO, true, false, 0.0,
		{"width": 0.0, "depth": 0.5})
	var wide := tactics.formation_position(midfielder, Vector2.ZERO, true, false, 0.0,
		{"width": 1.0, "depth": 0.5})
	assert(wide.y != narrow.y, "Width setting did not change the lane")
	var deep := tactics.formation_position(midfielder, Vector2.ZERO, false, false, 0.0,
		{"width": 0.5, "depth": 0.0})
	var high := tactics.formation_position(midfielder, Vector2.ZERO, false, false, 0.0,
		{"width": 0.5, "depth": 1.0})
	assert(high.x > deep.x, "Depth setting did not move the defensive line")
	var short_run := tactics._support_targets(game._home_players, game.player, Vector2.ZERO,
		game._away_players, {"directness": 0.0})
	var long_run := tactics._support_targets(game._home_players, game.player, Vector2.ZERO,
		game._away_players, {"directness": 1.0})
	var short_forward := -INF
	var long_forward := -INF
	for plan in short_run.values():
		if plan.intent == "forward_run": short_forward = plan.target.x
	for plan in long_run.values():
		if plan.intent == "forward_run": long_forward = plan.target.x
	assert(short_forward > -INF and long_forward > short_forward,
		"Directness did not lengthen the forward run")
	game.player.controlled_by_human = false
	var slow_carry: Dictionary = tactics.update_team_targets(game._home_players, game.player,
		Vector2.ZERO, Vector2.ZERO, game._away_players, &"none", 0.0, true, null, false,
		{"tempo": 0.0, "possession_state": &"controlled"})[game.player.get_instance_id()]
	var quick_carry: Dictionary = tactics.update_team_targets(game._home_players, game.player,
		Vector2.ZERO, Vector2.ZERO, game._away_players, &"none", 0.0, true, null, false,
		{"tempo": 1.0, "possession_state": &"controlled"})[game.player.get_instance_id()]
	assert(quick_carry.target.length() > slow_carry.target.length(),
		"Tempo did not increase the carry target distance")
	game._home_team.pressing = 1.0
	assert(game._team_tactical_context(&"Beechlawn Rovers", Vector2(12.0, 0.0)).high_press)
	game._home_team.pressing = 0.0
	assert(not game._team_tactical_context(&"Beechlawn Rovers", Vector2(12.0, 0.0)).high_press)
	var second: FootballPlayer = game._nearest_support_presser(game._home_players, null, Vector2(-33.0, 0.0))
	assert(second != null and second.profile.tactical_role not in [
		"centre_back", "fullback", "defensive_midfielder"],
		"A second presser abandoned defensive cover")
	game._home_score = 1
	game._remaining_time = 10.0
	assert(game._team_tactical_context(&"Beechlawn Rovers", Vector2.ZERO).protect_lead)
	assert(game._team_tactical_context(&"Beechlawn Rovers", Vector2.ZERO).late_lead_depth > 0.0)
	game.free()
	print("P2 formations/tactics PASS: four XI layouts, unchanged 4v4, lineup cards, mirrored kickoff, five team settings, cover and late lead")
	quit(0)
