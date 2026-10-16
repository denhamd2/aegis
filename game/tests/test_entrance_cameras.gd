extends GdUnitTestSuite
## The entrance cameras (EntranceDirector): every high shot hangs under the
## light rig instead of looking down through it, every shot a beat asks for is
## one the director can frame, and the walk key stays ahead of and above the
## man it lights.

const RIG_BOTTOM := ArenaBuilder.TRUSS_Y - 0.7


func test_high_shots_hang_under_the_rig() -> void:
	for at: Vector3 in [EntranceDirector.OPENING_AT, EntranceDirector.CODY_DARK_AT,
			EntranceDirector.ARENA_HIGH_AT, EntranceDirector.END_WIDE_AT,
			EntranceDirector.RING_HIGH_CORNER_AT]:
		assert_float(at.y).override_failure_message(str(at)).is_less(RIG_BOTTOM)
	for shot: Array in EntranceDirector.ROMAN_INTRO_SHOTS:
		for i in 2:
			assert_float((shot[i] as Vector3).y).is_less(RIG_BOTTOM)
	assert_float(EntranceDirector.RAMP_SIDE_HIGH_Y).is_less(RIG_BOTTOM)


func test_high_shots_still_see_over_the_crowd() -> void:
	# Under the rig, but a high shot all the same: well above a standing head.
	assert_float(EntranceDirector.RIG_CLEAR_Y).is_greater(5.0)
	assert_float(EntranceDirector.STAGE_WIDE_AT.y).is_less(RIG_BOTTOM)


func test_stage_wide_clears_the_ring_truss_from_the_led_top_in_sightline() -> void:
	# A small downward tilt alone shifts both objects together in frame. Raising
	# the camera below the fixtures changes the perspective enough to put the
	# screen top above the near truss in the actual sightline.
	var camera := EntranceDirector.STAGE_WIDE_AT
	var screen_top := ArenaBuilder.SCREEN_CENTER_Y + ArenaBuilder.SCREEN_HEIGHT * 0.5
	var screen_depth := absf(ArenaBuilder.SCREEN_FACE_Z - camera.z)
	var truss_front_depth := absf(-ArenaLighting.KEY_OFFSET - camera.z)
	var screen_elevation := atan2(screen_top - camera.y, screen_depth)
	var truss_elevation := atan2(ArenaLighting.TRUSS_Y - camera.y, truss_front_depth)
	var clearance_degrees := rad_to_deg(screen_elevation - truss_elevation)
	assert_float(clearance_degrees).override_failure_message(
			"LED top should clear the near truss by a visible margin").is_greater(5.0)


func test_opening_montage_sweeps_the_stage_then_cuts_to_the_enda_sign() -> void:
	var crane_start := EntranceDirector.opening_shot_at(0.0)
	var crane_end := EntranceDirector.opening_shot_at(3.9)
	var stage_side := EntranceDirector.opening_shot_at(5.0)
	var sign_fan := EntranceDirector.opening_shot_at(9.0)
	var sign_fan_alt := EntranceDirector.opening_shot_at(10.0)
	var stage_master := EntranceDirector.opening_shot_at(11.5)
	assert_int(crane_start[0]).is_equal(0)
	assert_int(crane_end[0]).is_equal(0)
	assert_int(stage_side[0]).is_equal(1)
	assert_int(sign_fan[0]).is_equal(EntranceDirector.OPENING_SIGN_SHOT_INDEX)
	assert_int(sign_fan_alt[0]).is_equal(EntranceDirector.OPENING_SIGN_ALT_SHOT_INDEX)
	assert_int(stage_master[0]).is_equal(4)
	assert_float(crane_end[1].x).is_greater(crane_start[1].x + 15.0)
	for stage_shot: Array in [crane_start, stage_side, stage_master]:
		assert_float(stage_shot[2].z).is_less(-30.0)
	assert_float(sign_fan[2].x).is_equal_approx(SignFans.FANS[0][1].x, 0.01)
	assert_float(sign_fan[2].z).is_equal_approx(SignFans.FANS[0][1].z, 0.01)
	assert_float(sign_fan_alt[2].x).is_equal_approx(SignFans.FANS[0][1].x, 0.01)
	assert_float(sign_fan_alt[2].z).is_equal_approx(SignFans.FANS[0][1].z, 0.01)
	assert_float(crane_start[3]).is_equal(64.0)
	assert_float(stage_side[3]).is_equal(64.0)
	assert_int(EntranceDirector.opening_shot_at(60.0)[0]).is_equal(stage_master[0])


func test_opening_crane_and_stage_angle_fit_every_rocket_burst() -> void:
	for at_seconds: float in [0.0, 2.0, 3.9, 4.0, 6.0, 8.4]:
		var shot := EntranceDirector.opening_shot_at(at_seconds)
		var camera_at: Vector3 = shot[1]
		var look: Vector3 = shot[2]
		var fov: float = shot[3]
		var camera_basis := Basis().looking_at(look - camera_at, Vector3.UP)
		var view := Transform3D(camera_basis, camera_at).affine_inverse()
		for rocket: Array in EntrancePyro.opening_rocket_plan():
			var local: Vector3 = view * rocket[1]
			var vertical := absf(atan2(local.y, -local.z))
			var horizontal := absf(atan2(local.x, -local.z))
			assert_float(vertical).override_failure_message(
					"rocket at %s is cropped vertically at %.1f s" % [rocket[1], at_seconds]) \
				.is_less(deg_to_rad(fov) * 0.5)
			var horizontal_half_fov := atan(tan(deg_to_rad(fov) * 0.5) * 16.0 / 9.0)
			assert_float(horizontal).override_failure_message(
					"rocket at %s is cropped horizontally at %.1f s" % [rocket[1], at_seconds]) \
				.is_less(horizontal_half_fov)
	assert_float(EntrancePyro.OPENING_TRAIL_SPREAD).is_less_equal(4.0)
	assert_float(EntrancePyro.OPENING_TRAIL_LIFETIME).is_less_equal(0.25)
	assert_int(EntrancePyro.OPENING_TRAIL_AMOUNT).is_less_equal(64)
	assert_float(EntrancePyro.OPENING_BURST_SIZE).is_greater(1.0)


func test_every_shot_a_beat_uses_can_be_framed() -> void:
	var source := (load("res://core/match/entrance_director.gd") as GDScript).source_code
	var framed := {}
	var at := source.find("func _frame_shot(")
	var end := source.find("\nfunc ", at + 10)
	var body := source.substr(at, end - at)
	var rx := RegEx.create_from_string("\\n\\t\\t\"([a-z_]+)\":")
	for m in rx.search_all(body):
		framed[m.get_string(1)] = true
	var used := RegEx.create_from_string("\"shot\": \"([a-z_]+)\"")
	for m in used.search_all(source):
		assert_bool(framed.has(m.get_string(1))) \
				.override_failure_message("no framing for shot " + m.get_string(1)).is_true()
	for list: Array in [EntranceDirector.ROMAN_WALK_SHOTS, EntranceDirector.CODY_WALK_SHOTS]:
		for shot: Array in list:
			assert_bool(framed.has(shot[0])) \
					.override_failure_message("no framing for " + str(shot[0])).is_true()


func test_the_walk_cuts_follow_from_behind_as_2k26_does() -> void:
	var cody := EntranceDirector.CODY_WALK_SHOTS.map(func(s: Array) -> String: return s[0])
	var roman := EntranceDirector.ROMAN_WALK_SHOTS.map(func(s: Array) -> String: return s[0])
	assert_array(cody).contains(["steadicam_front", "over_shoulder", "face_walk",
			"barricade_track"])
	assert_array(roman).contains(["steadicam_front", "steadicam_low", "face_walk", "over_shoulder"])
	# Never the shots that framed him small and dark (roman_entrance_aaa_plan.md).
	assert_array(roman).not_contains(["ramp_side_high", "arena_high"])
	assert_array(cody).not_contains(["ramp_side_high", "arena_high"])


func test_the_walk_key_rides_ahead_and_above_him() -> void:
	var at := Vector3(0.0, 0.0, -20.0)
	var fwd := Vector3.BACK
	var right := Vector3.UP.cross(-fwd).normalized()
	var key := EntranceDirector.walk_key_at(at, fwd, right)
	var rel := key - at
	assert_float(rel.dot(fwd)).is_greater(2.0)
	assert_float(rel.y).is_greater(2.0)
	assert_float(rel.length()).is_less(EntranceDirector.WALK_KEY_RANGE * 0.7)
	# From the front at roughly 45 degrees down onto his chest, not overhead.
	var down := rad_to_deg(atan2(rel.y - 1.3, Vector2(rel.x, rel.z).length()))
	assert_float(down).is_between(20.0, 50.0)


func test_roman_cuts_land_on_his_music_beat() -> void:
	# A4: from the hit to the foot of the ramp, every cut is whole beats.
	var beat := EntranceDirector.ROMAN_BEAT
	var on_grid := func(secs: float) -> bool:
		var n := secs / beat
		return absf(n - roundf(n)) < 0.02
	assert_bool(on_grid.call(EntranceDirector.ROMAN_PYRO_WIDE)).is_true()
	assert_bool(on_grid.call(EntranceDirector.ROMAN_FINGER_DOWN - EntranceDirector.ROMAN_MUSIC_HIT)).is_true()
	for shot: Array in EntranceDirector.ROMAN_WALK_SHOTS:
		assert_bool(on_grid.call(float(shot[1]))) \
				.override_failure_message("off the beat: " + str(shot)).is_true()


## Cody's walk cuts are whole beats of his music too.
func test_cody_cuts_land_on_his_music_beat() -> void:
	for shot: Array in EntranceDirector.CODY_WALK_SHOTS:
		var n := float(shot[1]) / EntranceDirector.CODY_BEAT
		assert_float(absf(n - roundf(n))).override_failure_message(str(shot)).is_less(0.02)


## Both entrances played through with the match camera, tick by tick.
func _run(styles: Array, each: Callable, after := Callable()) -> void:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	scene.entrances = true
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = styles[0]
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = styles[1]
	add_child(scene)
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var camera: Camera3D = scene.get_node("MatchCamera")
	var ticks := 0
	while ticks < 30000 and not director._done:
		director._physics_process(1.0 / 60.0)
		ticks += 1
		var beat: Dictionary = director._beats[mini(director._beat, director._beats.size() - 1)]
		each.call(beat, camera)
	if after.is_valid():
		after.call(director)
	scene.free()


## The owner: "the camera went to the tunnel too soon". Before a man walks
## out, the camera never looks into the empty portals -- not even for a beat
## (the owner: "zero closeups of the empty tunnels"). The building, the crowd
## and his video carry the wait; the portal shots start with him in them.
func test_the_camera_waits_for_him_before_the_tunnel() -> void:
	for styles: Array in [["roman", "cody"], ["cody", "roman"]]:
		var empty := {"run": 0, "worst": 0}
		_run(styles, func(beat: Dictionary, camera: Camera3D) -> void:
			var w: WrestlerController = beat.get("who")
			if w and not w.visible and portal_in_shot(camera):
				empty["run"] += 1
				empty["worst"] = maxi(empty["worst"], empty["run"])
			else:
				empty["run"] = 0)
		assert_int(empty["worst"]).override_failure_message("%s: %.1f s on the empty tunnel" % [
				styles, empty["worst"] / 60.0]).is_equal(0)


## The owner: Cody's ramp was "mostly low angle". Over each man's walks, the
## lens is down at his hips (under 0.8 m above his feet) for at most a
## quarter of the time.
func test_the_walk_is_mostly_at_eye_level() -> void:
	for styles: Array in [["roman", "cody"]]:
		var count := {}
		_run(styles, func(beat: Dictionary, camera: Camera3D) -> void:
			var w: WrestlerController = beat.get("who")
			if beat.get("kind") != "walk" or w == null:
				return
			var key := String(w.entrance_style)
			if not count.has(key):
				count[key] = [0, 0]
			count[key][0] += 1
			if camera.global_position.y - w.global_position.y < 0.8:
				count[key][1] += 1)
		for key: String in count:
			var frac := float(count[key][1]) / float(count[key][0])
			assert_float(frac).override_failure_message("%s low %.0f%% of the walk" % [key,
					frac * 100.0]).is_less_equal(0.25)



## Whether either portal's mouth is in a camera's 16:9 frame from closer
## than PORTAL_CLOSE -- a shot of the tunnel, as opposed to the far wide of
## the whole hall, where the stage is a detail.
const PORTAL_CLOSE := 25.0


static func portal_in_shot(camera: Camera3D) -> bool:
	var half_v := deg_to_rad(camera.fov) * 0.5
	var half_h := atan(tan(half_v) * 16.0 / 9.0)
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * ArenaBuilder.PORTAL_OFFSET_X, ArenaBuilder.STAGE_DECK_Y + 1.2,
				ArenaBuilder.PORTAL_FACE_Z)
		var local := camera.global_transform.affine_inverse() * p
		if local.z >= 0.0 or local.length() > PORTAL_CLOSE:
			continue
		if absf(atan2(local.x, -local.z)) < half_h and absf(atan2(local.y, -local.z)) < half_v:
			return true
	return false


## The owner: Cody "raises his finger a few times" on the ramp -- the old
## walk's fist pump came round every cycle. Each gesture is played once,
## the fist at most once, and they all fit in the walk.
func test_codys_walk_gestures_are_each_seen_once() -> void:
	var played := []
	_run(["roman", "cody"], func(_beat: Dictionary, _camera: Camera3D) -> void: pass,
			func(d: EntranceDirector) -> void: played.append_array(d.gestures_played))
	assert_array(played).contains_exactly_in_any_order(EntranceDirector.CODY_WALK_GESTURES)


## Keep the opening stare on the current short broadcast rhythm: a two-second
## profile, a four-second OTS, then the concise match-card and referee bridge.
func test_the_face_off_and_match_intro_use_broadcast_pacing() -> void:
	var start := 0.0
	var stare := float(EntranceDirector.FACEOFF_STARE_TICKS) / EntranceDirector.TPS
	for step: Array in EntranceDirector.FACEOFF_SEQ:
		var end := minf(float(step[0]), stare)
		if start < stare:
			assert_float(end - start).override_failure_message(
					"%s holds %.2f s" % [step[1], end - start]) \
					.is_equal_approx(EntranceDirector.FACEOFF_PROFILE_END if step[1] == "profile"
					else stare - EntranceDirector.FACEOFF_PROFILE_END, 0.001)
		assert_bool(String(step[1]).begins_with("eyes")).is_false()
		start = end
	# Card, check and corner mediums have distinct short holds before the bell.
	assert_float(float(EntranceDirector.INTRO_CARD_TICKS) / EntranceDirector.TPS).is_equal(3.0)
	assert_float(float(EntranceDirector.INTRO_CHECK_TICKS) / EntranceDirector.TPS).is_equal(2.0)
	assert_float(float(EntranceDirector.INTRO_CLOSE_TICKS) / EntranceDirector.TPS).is_equal(2.5)
	assert_float(EntranceDirector.INTRO_CLOSE_FOV).is_greater_equal(30.0)
