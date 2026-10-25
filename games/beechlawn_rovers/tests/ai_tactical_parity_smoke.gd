extends SceneTree
## Mirror attacks and reverse array/update order without granting new reach.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game);await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	var reference := {}
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var opponents: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		for reversed_order in [false, true]:
			var ordered := team.duplicate()
			var defending := opponents.duplicate()
			if reversed_order:ordered.reverse();defending.reverse()
			for actor in team + opponents:
				actor.position = Vector3(0,0,90);actor.velocity = Vector3.ZERO
				actor.controlled_by_human = false;actor.ai_action_cooldown = 0;actor.receive_target_time = 0
				actor._footballer_visual.end_presentation()
			var carrier: FootballPlayer
			var runner: FootballPlayer
			var marker: FootballPlayer
			for actor in team:
				if actor.profile.starting_slot == "striker_left":carrier = actor
				if actor.profile.starting_slot == "striker_right":runner = actor
			# Resource slots are identical local role labels on both teams.
			if carrier == null:
				var outfield: Array[FootballPlayer] = []
				for actor in team:
					if actor.profile.role == "outfield":outfield.append(actor)
				outfield.sort_custom(func(a, b):return a.profile.starting_slot < b.profile.starting_slot)
				carrier = outfield[0];runner = outfield[1]
			for actor in opponents:
				if actor.profile.role == "outfield":marker = actor;break
			var sx := carrier.attack_sign
			for situation in ["central", "wide", "pressure", "blocked"]:
				var z := 18.0 if situation == "wide" else 0.0
				carrier.position = Vector3(35*sx,0,z);carrier.rotation.y = -PI/2*sx
				runner.position = Vector3(39*sx,0,z+8)
				ball.position = Vector3(35.6*sx,.11,z)
				ball.last_touch = carrier.team_name;ball.last_touch_player = carrier;ball.last_action = &"dribble"
				marker.position = Vector3(31*sx,0,z)
				if situation == "pressure":marker.position = Vector3(34*sx,0,z+2)
				if situation == "blocked":marker.position = Vector3(37*sx,0,z)
				var choice: Dictionary = game._player_decisions.choose_carrier_action(carrier, ordered, defending, ball)
				var signature := str(choice.type)
				if reference.has(situation):
					if reference[situation] != signature:_fail(game, "Team identity/iteration changed " + situation + " decision");return
				else:reference[situation] = signature
				if situation == "central" and choice.type != &"shoot":_fail(game,"Clear central shot suppressed");return
				if situation == "blocked" and choice.type == &"shoot":_fail(game,"Shot through immediate blocker");return
				# Both tactical orders read the same state; a frame must not leave one team stale.
				for actor in team + opponents:
					if actor.has_meta("ai_target_position"):actor.remove_meta("ai_target_position")
				game._ai_tick = 0;game._next_home_ai = not reversed_order
				game._update_ai(1.0/60)
				for actor in team + opponents:
					if not actor.has_meta("ai_target_position"):_fail(game,"An actor missed shared decision tick");return
				var marks: Dictionary = game._team_tactics.assign_defensive_marks(ordered,carrier,defending,Vector2(ball.position.x,ball.position.z))
				var reversed_team := ordered.duplicate();reversed_team.reverse()
				var reversed_defenders := defending.duplicate();reversed_defenders.reverse()
				var repeated: Dictionary = game._team_tactics.assign_defensive_marks(reversed_team,carrier,reversed_defenders,Vector2(ball.position.x,ball.position.z))
				if marks != repeated:_fail(game,"Reversed actor order changed marking assignments");return
				var supports: Dictionary = game._team_tactics._support_targets(ordered,carrier,Vector2(ball.position.x,ball.position.z),defending)
				var repeated_supports: Dictionary = game._team_tactics._support_targets(reversed_team,carrier,Vector2(ball.position.x,ball.position.z),reversed_defenders)
				if supports != repeated_supports:_fail(game,"Reversed actor order changed outlet/run assignments");return
				carrier._footballer_visual.end_presentation();carrier._visual_shot_pending = false;carrier._visual_pass_pending = false
				carrier.ai_action_cooldown = 0
	print("PASS: mirrored central/wide/pressured/blocked choices survive reversed actor and tactical order: ", reference)
	game.free();quit(0)
func _fail(game: Node, message: String) -> void:
	push_error(message);game.free();quit(1)
