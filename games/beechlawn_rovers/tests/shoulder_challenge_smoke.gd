extends SceneTree
## Checks shoulder contacts stay brief, conditional and separate from ball possession.

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
	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	for actor in home + away:
		actor.set_physics_process(false)
	var tackler: FootballPlayer = game.get_node("Player")
	var carrier: FootballPlayer
	for actor in away:
		if actor.profile.role == "outfield":
			carrier = actor
			break
	assert(carrier != null, "Could not find an opposing outfielder")

	# Running shoulder-to-shoulder near an opponent-held ball creates one short,
	# attribute-scaled balance response without stealing or teleporting the ball.
	tackler.global_position = Vector3.ZERO
	carrier.global_position = Vector3(0.0, 0.0, 0.8)
	tackler.velocity = Vector3(3.0, 0.0, 0.0)
	carrier.velocity = Vector3(3.0, 0.0, 0.0)
	tackler._shoulder_cooldown = 0.0
	carrier._shoulder_cooldown = 0.0
	ball.global_position = Vector3(0.1, FootballBall.RADIUS, 0.4)
	ball.last_touch = carrier.team_name
	ball.last_action = &"dribble"
	var touch_before := ball.last_touch
	assert(tackler._try_shoulder_challenge(), "Close running contest did not trigger a shoulder challenge")
	assert(tackler._balance_stagger_time > 0.0 and carrier._balance_stagger_time > 0.0,
		"Shoulder contact did not create brief balance reactions")
	assert(tackler.velocity.z < 0.0 and carrier.velocity.z > 0.0,
		"Contact did not add a small opposing balance displacement")
	assert(ball.last_touch == touch_before and ball.last_action == &"dribble",
		"Shoulder contact bypassed normal ball-possession rules")
	assert(not tackler._try_shoulder_challenge(), "Shoulder contact repeated during pair cooldown")

	# Slow movement does not create an automatic body check.
	tackler._shoulder_cooldown = 0.0
	carrier._shoulder_cooldown = 0.0
	tackler.velocity = Vector3(0.8, 0.0, 0.0)
	assert(not tackler._try_shoulder_challenge(), "Slow players triggered a running shoulder contest")

	# A distant player does not receive a remote balance response.
	tackler.velocity = Vector3(3.0, 0.0, 0.0)
	carrier.global_position = Vector3(0.0, 0.0, 4.0)
	carrier.velocity = Vector3(3.0, 0.0, 0.0)
	assert(not tackler._try_shoulder_challenge(), "Distant players triggered shoulder contact")

	print("Beechlawn shoulder challenge checks passed")
	quit(0)
