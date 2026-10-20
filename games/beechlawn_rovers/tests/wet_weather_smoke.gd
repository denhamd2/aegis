extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _run() -> void:
	var surface := load("res://data/presentation/kilmore_surface.tres") as WetPitchSurface
	check(surface.sample_at(Vector3(50.9,0,-1.5)).y > 0.9,"Positive goal has standing water")
	check(surface.sample_at(Vector3(-50.9,0,1.5)).y > 0.9,"Negative goal has standing water")
	check(surface.sample_at(Vector3.ZERO).y == 0.0,"Midfield is clear of puddles")
	check(surface.sample_at(Vector3(70,0,0)) == Vector2.ZERO,"Outside field never samples a clamped goal puddle")
	var coefficient := surface.resistance(Vector3(50.9,0,-1.5),1.0)
	var v60 := Vector3(8,0,0)
	var v120 := v60
	for tick in 60:
		v60 += surface.drag_force(Vector3(50.9,0,-1.5),v60,0.43,1.0,1.0/60.0)/0.43/60.0
	for tick in 120:
		v120 += surface.drag_force(Vector3(50.9,0,-1.5),v120,0.43,1.0,1.0/120.0)/0.43/120.0
	check(v60.distance_to(v120)<0.001,"Water damping is stable at 60/120 ticks")
	check(absf(v60.x-8.0*exp(-coefficient))<0.001,"One-second water loss follows configured resistance")
	# Exercise FootballBall's actual ground-height gate and force integration.
	var balls: Array[FootballBall] = []
	for i in 3:
		var ball := FootballBall.new()
		root.add_child(ball)
		ball.gravity_scale = 0.0
		ball.linear_damp = 0.0
		ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		ball.position = Vector3(50.9,0.11 if i<2 else 4.0,-1.5)
		ball.wet_surface = surface if i>0 else null
		ball.surface_wetness = 1.0
		ball.linear_velocity = Vector3(0,0,1.0)
		balls.append(ball)
	for tick in 24:
		await physics_frame
	check(balls[1].linear_velocity.length()<balls[0].linear_velocity.length()*0.65,"Grounded ball physically slows in water")
	check(absf(balls[2].linear_velocity.length()-1.0)<0.01,"Airborne ball does not receive puddle resistance")
	for ball in balls:ball.queue_free()
	await process_frame
	var session := root.get_node("MatchSession")
	var saved: StringName = session.weather_preset
	session.weather_preset = &"rain"
	var path := "user://weather_test.cfg"
	check(session.save_preferences(path)==OK,"Weather setting saves")
	session.weather_preset = &"sunny"
	session.load_preferences(path)
	check(session.weather_preset==&"rain","Weather setting round trips")
	DirAccess.remove_absolute(path)
	var baseline := load("res://data/presentation/kilmore_daylight.tres") as Environment
	var original_sun_sky: float = baseline.sky.sky_material.get_shader_parameter("sky_energy")
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var weather := game.get_node("MatchWeather") as MatchWeather
	for id in MatchWeather.PRESETS:
		weather.setup(game,StringName(id))
		check(weather.weather_id == StringName(id),"Weather preset applies: "+str(id))
		check(game.ball.wet_surface == surface,"Match ball and field share the same surface resource")
		check(not game.get_node("WorldEnvironment").environment.volumetric_fog_enabled,"Web-safe depth haze")
		if id == "rain":
			check(weather.rain != null and weather.rain.amount > 0,"Rain preset creates visible rainfall")
			check(weather.rain.visibility_aabb.has_point(Vector3(0,-13,0)),"Rain render bounds include the ground below the overhead emitter")
	check(weather.rain == null,"Leaving rain removes precipitation")
	check(baseline.sky.sky_material.get_shader_parameter("sky_energy")==original_sun_sky,"Weather never modifies the shared daylight resource")
	check(MatchWeather.valid_id(&"bad")==&"sunny","Unknown saved weather safely falls back")
	session.weather_preset=saved
	game.queue_free()
	await process_frame
	print("Wet/weather checks: physical ground slowdown, airborne exclusion, mirrored masks, 60/120 Hz, preferences, four presets; failures=",failures)
	quit(1 if failures else 0)
