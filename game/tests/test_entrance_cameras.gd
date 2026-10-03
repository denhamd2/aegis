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
	assert_array(cody).contains(["steadicam_front", "over_shoulder", "barricade_track"])
	assert_array(roman).contains(["steadicam_low", "ramp_side_high", "face_walk"])


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
func _run(styles: Array, each: Callable) -> void:
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
