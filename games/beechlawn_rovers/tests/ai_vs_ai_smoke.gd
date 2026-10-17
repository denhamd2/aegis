extends SceneTree

const MATCH_SCENE := "res://scenes/training_ground.tscn"
const SIM_FRAMES := 720


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MATCH_SCENE) as PackedScene
	assert(packed != null, "Could not load the 4v4 match scene")
	var match_scene := packed.instantiate()
	root.add_child(match_scene)
	await process_frame
	match_scene.set("short_match_seconds", 300.0)
	var all_players: Array[FootballPlayer] = match_scene.get("_home_players") + match_scene.get("_away_players")
	assert(all_players.size() == 8, "Expected eight actors for the short 4v4 slice")
	var start_positions: Dictionary = {}
	for actor in all_players:
		actor.controlled_by_human = false
		start_positions[actor.get_instance_id()] = actor.global_position
	match_scene.call("_start_kickoff", false)
	var match_ball := match_scene.get_node("Ball") as FootballBall
	assert(not match_ball.freeze, "AI-vs-AI kickoff did not release the ball")
	var last_action_serial := match_ball.action_serial
	var ai_passes := 0
	var ai_shots := 0
	var stall_windows := 0
	var window_start_positions: Dictionary = {}
	for actor in all_players:
		if actor.profile.role == "outfield":
			window_start_positions[actor.get_instance_id()] = actor.global_position
	for frame in SIM_FRAMES:
		await physics_frame
		if match_ball.action_serial != last_action_serial:
			if match_ball.last_action == &"pass" or match_ball.last_action == &"through_pass":
				ai_passes += 1
			elif match_ball.last_action == &"shot":
				ai_shots += 1
			last_action_serial = match_ball.action_serial
		if (frame + 1) % 120 == 0:
			var moved_in_window := 0
			for actor in all_players:
				if actor.profile.role != "outfield":
					continue
				var actor_id := actor.get_instance_id()
				if actor.global_position.distance_to(window_start_positions[actor_id]) > 0.2:
					moved_in_window += 1
				window_start_positions[actor_id] = actor.global_position
			if moved_in_window < 2:
				stall_windows += 1
	var moved_outfield := 0
	var active_decisions := 0
	for actor in all_players:
		assert(is_finite(actor.global_position.x) and is_finite(actor.global_position.z), "Actor position became non-finite")
		assert(absf(actor.global_position.x) < 60.0 and absf(actor.global_position.z) < 40.0, "Actor left the playable envelope")
		if actor.profile.role == "outfield":
			if actor.global_position.distance_to(start_positions[actor.get_instance_id()]) > 1.0:
				moved_outfield += 1
			if actor.has_meta("ai_role_intent"):
				active_decisions += 1
	assert(moved_outfield >= 4, "AI-vs-AI match stalled: fewer than four outfielders moved meaningfully")
	assert(active_decisions >= 6, "AI-vs-AI did not assign tactical intents to both teams")
	assert(stall_windows == 0, "AI-vs-AI had a two-second movement stall window")
	assert(is_finite(match_ball.global_position.x) and is_finite(match_ball.global_position.z), "Ball position became non-finite")
	print("Beechlawn AI-vs-AI 4v4 ran %d physics frames: moved_outfield=%d tactical_intents=%d passes=%d shots=%d stall_windows=%d ball_speed=%.2fm/s" % [
		SIM_FRAMES, moved_outfield, active_decisions, ai_passes, ai_shots, stall_windows,
		match_ball.linear_velocity.length()])
	print("Beechlawn AI-vs-AI activity smoke checks passed; pass/shot counts are diagnostic for this short sample")
	print("Carrier decision tests cover the action choices; match-level tuning remains subject to visual/hardware playtest")
	quit(0)
