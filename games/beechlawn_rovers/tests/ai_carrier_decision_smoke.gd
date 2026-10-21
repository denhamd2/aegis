extends SceneTree
## Exercises conservative AI shot/pass/carry choices without running physics.

const MATCH_SCENE := "res://scenes/training_ground.tscn"
const DECISION_SCRIPT := preload("res://scripts/player_decision_controller.gd")

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load(MATCH_SCENE) as PackedScene
	assert(packed != null, "Sunday-league match scene failed to load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var home: Array[FootballPlayer] = game.get("_home_players")
	var away: Array[FootballPlayer] = game.get("_away_players")
	for actor in home + away:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
	var carrier: FootballPlayer = game.get_node("Player")
	var visual := carrier.get_node("Visual") as FootballerVisual
	var ball: FootballBall = game.get_node("Ball")
	var decisions = DECISION_SCRIPT.new()

	# A central, close-range chance should be taken without waiting for another AI tick.
	carrier.global_position = Vector3(42.0, 0.0, 0.0)
	ball.global_position = Vector3(42.0, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = carrier.team_name
	for defender in away:
		defender.global_position = Vector3(43.0, 0.0, 5.0)
	var shot: Dictionary = decisions.choose_carrier_action(carrier, home, away, ball)
	assert(shot.get("type") == &"shoot", "AI did not take a close, central shot")
	var shot_serial := ball.action_serial
	game._apply_carrier_action(carrier, home, away)
	# AI queues the same authored contact as human input. This decision fixture
	# does not advance animation time; deliver its event explicitly, as below
	# for passing. Integration tests cover the real AnimationPlayer timeline.
	if not carrier.get("_visual_shot_pending") or carrier.ai_action_cooldown <= 1.0 \
			or ball.action_serial != shot_serial:
		push_error("AI shot did not queue one gated, contact-timed action")
		quit(1)
		return
	visual.animation_player.seek(visual.action_contact_time(&"shot"), true)
	ball.global_position = carrier._receive_contact_position() + Vector3.UP * 0.06
	visual.on_action_contact_marker()
	assert(ball.last_action == &"shot" and carrier.ai_action_cooldown > 1.0,
		"Match AI did not execute and gate its selected shot")
	visual.animation_player.stop()
	visual._on_animation_finished(FootballerVisual.SHOT_CLIP)

	# When pressed, prefer a safe forward runner; an open carrier should keep carrying.
	carrier.global_position = Vector3.ZERO
	ball.global_position = Vector3(0.0, FootballBall.RADIUS, 0.0)
	carrier.ai_action_cooldown = 0.0
	var receiver: FootballPlayer
	for actor in home:
		if actor != carrier and actor.profile.role == "outfield":
			if receiver == null:
				receiver = actor
				receiver.global_position = Vector3(12.0, 0.0, 0.0)
			else:
				actor.global_position = Vector3(-20.0, 0.0, 20.0)
	for defender in away:
		defender.global_position = Vector3(0.0, 0.0, 2.5)
	var pass_decision: Dictionary = decisions.choose_carrier_action(carrier, home, away, ball)
	assert(receiver != null and pass_decision.get("type") == &"through_pass",
		"AI did not release a safe forward pass when tightly pressured")
	assert(pass_decision.get("receiver_id") == receiver.get_instance_id(),
		"AI pressure pass did not select the available forward runner")
	game._apply_carrier_action(carrier, home, away)
	assert(carrier.get("_visual_pass_pending"),
		"AI pressure pass did not enter the contact-timed pass animation")
	# Exercise the same event used by the authored AnimationPlayer marker.
	visual.animation_player.seek(visual.action_contact_time(&"pass"), true)
	ball.global_position = carrier._receive_contact_position() + Vector3.UP * 0.06
	visual.on_action_contact_marker()
	assert(ball.last_action == &"through_pass" and receiver.receive_target_time > 0.0,
		"Match AI did not execute the pressure pass and assign the receiver run")

	carrier.ai_action_cooldown = 0.0
	for defender in away:
		defender.global_position = Vector3(0.0, 0.0, 12.0)
	var carry: Dictionary = decisions.choose_carrier_action(carrier, home, away, ball)
	assert(carry.get("type") == &"carry", "AI forced a pass or shot without pressure or a clear chance")
	carrier.controlled_by_human = true
	assert(decisions.choose_carrier_action(carrier, home, away, ball).get("type") == &"none",
		"AI decision layer overrode a human-controlled player")

	print("Beechlawn AI carrier shot, pressure-pass, carry and human-control checks passed")
	quit(0)
