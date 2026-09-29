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
	assert_array(cody).contains(["steadicam_low", "over_shoulder"])
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
