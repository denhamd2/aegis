extends SceneTree
## Verifies close-range standing tackles, range rejection and AI ball-winning.

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

	var ball := game.get_node("Ball") as FootballBall
	var home_player := game.get_node("Player") as FootballPlayer
	for actor in game.get("_home_players") + game.get("_away_players"):
		actor.set_physics_process(false)
	var away: Array = game.get("_away_players")
	var defender: FootballPlayer
	for actor in away:
		if actor.profile.role == "outfield":
			defender = actor
			break
	assert(defender != null, "Could not find an AI outfielder")
	assert(InputMap.has_action("tackle"), "Keyboard tackle action was not registered")

	# Out-of-range attempts must not steal possession or change ball velocity.
	ball.freeze = false
	ball.linear_velocity = Vector3.ZERO
	ball.global_position = Vector3(2.0, FootballBall.RADIUS, 0.0)
	ball.last_touch = defender.team_name
	assert(not home_player._attempt_tackle(), "Standing tackle succeeded outside reach")
	assert(ball.last_touch == defender.team_name, "Out-of-range tackle changed possession")

	# Human tackle at plausible contact redirects the free ball and transfers touch.
	home_player.global_position = Vector3.ZERO
	home_player.velocity = Vector3.ZERO
	ball.global_position = Vector3(0.72, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = defender.team_name
	assert(home_player._attempt_tackle(), "Human standing tackle failed at close contact")
	assert(ball.last_touch == home_player.team_name, "Successful tackle did not transfer ball touch")
	await physics_frame
	assert(ball.linear_velocity.length() > 0.1,
		"Tackle did not apply a physical impulse to the ball")

	# AI makes the same close-contact decision when the opponent has the touch.
	defender.set_physics_process(false)
	defender.global_position = Vector3(6.0, 0.0, 0.0)
	defender.velocity = Vector3.ZERO
	ball.global_position = Vector3(5.28, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = home_player.team_name
	home_player.global_position = Vector3(5.1, 0.0, 0.0)
	defender._try_ai_tackle()
	assert(ball.last_touch == defender.team_name, "AI standing tackle did not win close ball")
	assert(defender._tackle_cooldown > 0.0, "AI tackle did not receive a cooldown")

	# A team last-touch survives passes and deflections, so it must not make a
	# nearby loose ball look like an opponent is still carrying it.
	defender._tackle_cooldown = 0.0
	defender.global_position = Vector3(6.0, 0.0, 0.0)
	home_player.global_position = Vector3(15.0, 0.0, 0.0)
	ball.global_position = Vector3(5.28, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = home_player.team_name
	defender._try_ai_tackle()
	assert(ball.last_touch == home_player.team_name, "AI tackled a loose ball using stale team possession")
	assert(defender._tackle_cooldown == 0.0, "Loose-ball challenge incorrectly consumed the AI tackle cooldown")

	# A human slide locks the player into a short commitment, then wins a ball
	# before nearby opponent contact.
	home_player._tackle_cooldown = 0.0
	home_player.global_position = Vector3.ZERO
	home_player.rotation.y = -PI * 0.5
	defender.global_position = Vector3(10.0, 0.0, 0.0)
	ball.global_position = Vector3(1.0, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = defender.team_name
	assert(home_player._attempt_slide_tackle(), "Human slide tackle did not commit at valid range")
	assert(home_player._slide_tackle_time > 0.0, "Slide did not enter its committed movement window")
	assert(is_instance_valid(home_player._footballer_visual)
		and home_player._footballer_visual._active_action == &"slide_tackle",
		"Committed human slide did not take over the player presentation action")
	assert(home_player._resolve_slide_tackle_contact(), "Clean ball-first slide failed to win the ball")
	assert(ball.last_touch == home_player.team_name, "Successful slide did not transfer ball touch")
	assert(home_player.get_meta("last_tackle_result") == &"won", "Successful slide result was not recorded")

	# Reaching an opponent before the ball reports a foul and leaves possession
	# and ball velocity untouched for a future referee/restart system.
	home_player._tackle_cooldown = 0.0
	home_player._slide_tackle_time = 0.0
	home_player.global_position = Vector3.ZERO
	defender.global_position = Vector3(0.8, 0.0, 0.0)
	ball.global_position = Vector3(1.6, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = defender.team_name
	var foul_count := [0]
	var foul_callback := func(_tackler: FootballPlayer, _opponent: FootballPlayer) -> void:
		foul_count[0] += 1
	home_player.foul_committed.connect(foul_callback)
	assert(home_player._attempt_slide_tackle(), "Unsafe slide did not begin commitment")
	assert(not home_player._resolve_slide_tackle_contact(), "Opponent-first slide should be a foul")
	assert(home_player.get_meta("last_tackle_result") == &"foul", "Unsafe slide was not classified as a foul")
	assert(foul_count[0] == 1, "Unsafe slide did not emit the foul event")
	assert(ball.last_touch == defender.team_name, "Foul challenge improperly changed possession")
	assert(home_player.get_meta("last_tackle_result") == &"foul", "Foul result was not recorded")

	# AI defenders use the slide option when standing-tackle range is missed.
	defender._tackle_cooldown = 0.0
	defender.global_position = Vector3(8.0, 0.0, 0.0)
	defender.rotation.y = PI * 0.5
	ball.global_position = Vector3(6.2, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = home_player.team_name
	home_player.global_position = Vector3(6.5, 0.0, 0.0)
	defender.velocity = Vector3(-3.0, 0.0, 0.0)
	defender.ai_move_direction = Vector3(-1.0, 0.0, 0.0)
	defender._try_ai_tackle()
	assert(defender._slide_tackle_time > 0.0, "AI did not commit a slide from extended tackle range")
	defender._slide_tackle_time = 0.0
	defender._slide_contact_pending = false
	defender._tackle_cooldown = 0.0
	defender.velocity = Vector3.ZERO
	defender.ai_move_direction = Vector3.ZERO
	defender._try_ai_tackle()
	assert(defender._slide_tackle_time == 0.0,
		"AI committed to a slide without moving into the challenge")

	# Ball-touch telemetry includes close dribble contacts so play-quality probes
	# can distinguish controlled possession from tackles and kicks.
	home_player.global_position = Vector3.ZERO
	ball.global_position = Vector3(0.5, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = defender.team_name
	var dribble_events := [0]
	ball.touched.connect(func(kind: StringName, _speed: float) -> void:
		if kind == &"dribble":
			dribble_events[0] += 1)
	assert(ball.dribble_touch(home_player, Vector3.RIGHT, false, false, 0.1, 0.4, 0.9),
		"Close-contact dribble touch failed")
	assert(dribble_events[0] == 1, "Dribble touch did not emit ball-touch telemetry")

	print("Beechlawn standing, sliding and foul-risk tackle checks passed")
	quit(0)
