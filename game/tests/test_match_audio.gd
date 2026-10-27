extends GdUnitTestSuite
## The hall's sound (MatchAudio, SfxPool): every sound it asks for exists,
## strikes are heard on landing and slams are left to the bump detector, and
## a sound can never touch the global RNG a match seed is drawn from.

const NAMED := ["crowd_bed", "crowd_walla_a", "crowd_walla_b", "crowd_boo",
		"crowd_cheer", "crowd_roar", "crowd_finish", "bell_start", "bell_end",
		"bell_ding", "pyro_boom", "pyro_bang", "whoosh", "ui_move", "ui_select", "ui_back"]
const FAMILIES := ["crowd_pop", "crowd_ooh", "hit_punch", "hit_kick", "hit_chop", "hit_forearm", "bump",
		"count_slap", "hit_chair", "hit_kendo", "hit_sledge", "hit_ladder", "table_crack", "grunt_light",
		"grunt_heavy", "groan", "yell", "burn_scream"]


func test_every_sound_it_plays_is_built() -> void:
	for s: String in NAMED:
		assert_object(SfxPool.stream(s)).override_failure_message("missing " + s).is_not_null()
	for f: String in FAMILIES:
		assert_int(SfxPool.family_size(f)).override_failure_message("no " + f).is_greater_equal(2)
	var clip_events := {}
	for event: String in MatchAudio.COMMENTARY_CLIPS:
		for clip: String in MatchAudio.COMMENTARY_CLIPS[event]:
			assert_object(load(clip) as AudioStream) \
					.override_failure_message("missing commentary clip " + clip).is_not_null()
				# Multiple recordings are allowed as variants inside one event, but
				# the same audio asset must not be routed by separate match cues.
			assert_bool(clip_events.has(clip)) \
					.override_failure_message("commentary clip is shared by " + str(clip_events.get(clip, "")) + " and " + event).is_false()
			clip_events[clip] = event
	assert_bool(ResourceLoader.exists(MatchAudio.CODY_CROWD_CHANT)).is_true()


func test_cody_crowd_chant_is_only_enabled_for_a_cody_match() -> void:
	var cody: WrestlerController = auto_free(WrestlerController.new())
	cody.entrance_style = "cody"
	var roman: WrestlerController = auto_free(WrestlerController.new())
	roman.entrance_style = "roman"
	assert_bool(MatchAudio.cody_is_in_match([cody, roman])).is_true()
	assert_bool(MatchAudio.cody_is_in_match([roman])).is_false()


func test_opening_and_finish_bells_play_at_double_speed() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio.opening_bell()
	assert_float(audio.sfx._voices[0].pitch_scale) \
			.is_equal(MatchAudio.MATCH_BELL_PITCH_SCALE)
	audio._on_match_won(null, "time_limit")
	assert_float(audio.sfx._voices[1].pitch_scale) \
			.is_equal(MatchAudio.MATCH_BELL_PITCH_SCALE)


func test_enda_sign_gag_is_scheduled_for_every_match() -> void:
	for seed in 900:
		assert_bool(MatchAudio.enda_easter_egg_for_seed(seed)).is_true()


func test_sneaky_heel_gag_is_seeded_and_appears_about_once_in_three_matches() -> void:
	var selected := 0
	for seed in 900:
		var first := MatchAudio.sneaky_heel_easter_egg_for_seed(seed)
		assert_bool(MatchAudio.sneaky_heel_easter_egg_for_seed(seed)).is_equal(first)
		if first:
			selected += 1
	assert_int(selected).is_between(250, 350)


func test_sneaky_heel_gag_follows_roman_taunt_once_per_match() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var roman: WrestlerController = auto_free(WrestlerController.new())
	roman.entrance_style = "roman"
	audio._sneaky_heel_easter_egg_selected = true
	audio._on_wrestler_taunted(roman)
	assert_array(audio._commentary_queue).is_equal([
		"tony_roman_heel", "tony_sneaky_heel_easter_egg"])
	audio._on_wrestler_taunted(roman)
	assert_array(audio._commentary_queue).is_equal([
		"tony_roman_heel", "tony_sneaky_heel_easter_egg"])


func test_tonys_gunshot_call_follows_the_handgun_flash_once() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var gun: WeaponActor = auto_free(WeaponActor.make(WeaponCatalog.by_id(&"handgun")))
	audio.on_weapon_event(gun, "flash")
	assert_bool(audio._commentary_voice.playing).is_false()
	assert_array(audio._commentary_queue).is_equal([
		"gunshot", "excalibur_restore_order"])
	await get_tree().create_timer(MatchAudio.COMMENTARY_EVENT_DELAY + 0.1).timeout
	assert_bool(audio._commentary_voice.playing).is_true()
	audio.on_weapon_event(gun, "flash")
	assert_bool(audio._commentary_events_played.has("gunshot")).is_true()
	assert_array(audio._commentary_queue).is_equal(["excalibur_restore_order"])
	assert_float(audio._commentary_delay).is_less(0.0)
	assert_str(MatchAudio.commentary_event_for_weapon(&"rpg", "flash")).is_empty()
	assert_str(MatchAudio.commentary_event_for_weapon_ready(&"rpg")) \
			.is_equal("tony_danger_warning")
	assert_str(MatchAudio.commentary_event_for_weapon_ready(&"steel_chair")) \
			.is_equal("tony_danger_warning")
	assert_str(MatchAudio.commentary_event_for_weapon_ready(&"barbed_wire_chair")) \
			.is_equal("tony_barbed_wire_chair")
	assert_str(MatchAudio.commentary_event_for_weapon_ready(&"bed_of_nails")) \
			.is_equal("excalibur_bed_of_nails")
	assert_str(MatchAudio.commentary_event_for_weapon_ready(&"inflatable_banana")).is_empty()


func test_gunshot_and_rocket_effects_use_the_louder_signature_mix() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var heard: Array[Dictionary] = []
	audio.sfx.played.connect(func(sound: String, volume_db: float) -> void:
		heard.append({"sound": sound, "volume_db": volume_db}))
	var gun: WeaponActor = auto_free(WeaponActor.make(WeaponCatalog.by_id(&"handgun")))
	var rpg: WeaponActor = auto_free(WeaponActor.make(WeaponCatalog.by_id(&"rpg")))
	audio.on_weapon_event(gun, "flash")
	audio.on_weapon_event(rpg, "rocket")
	audio.on_weapon_event(rpg, "blast")
	assert_array(heard.map(func(entry: Dictionary) -> float: return entry["volume_db"])) \
		.is_equal([MatchAudio.GUNSHOT_DB, -4.0, MatchAudio.ROCKET_LAUNCH_DB,
			MatchAudio.ROCKET_IGNITION_DB, MatchAudio.ROCKET_BLAST_DB, -2.0])


func test_entrance_pyro_is_lifted_six_db_over_its_previous_mix() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var heard: Array[Dictionary] = []
	audio.sfx.played.connect(func(sound: String, volume_db: float) -> void:
		heard.append({"sound": sound, "volume_db": volume_db}))
	for cue in ["pyro_stage", "pyro_roman", "pyro_cody_hit"]:
		audio._on_cue(cue)
	assert_array(heard).is_equal([
		{"sound": "pyro_boom", "volume_db": 5.0},
		{"sound": "pyro_boom", "volume_db": 4.0},
		{"sound": "whoosh", "volume_db": 2.0},
		{"sound": "pyro_bang", "volume_db": 4.0},
		{"sound": "pyro_boom", "volume_db": -2.0},
	])


func test_nonbreaking_set_piece_landing_plays_its_impact_sound() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var cody: WrestlerController = auto_free(WrestlerController.new())
	cody.display_name = "CODY RHODES"
	var tacks: WeaponActor = auto_free(WeaponActor.make(WeaponCatalog.by_id(&"thumbtacks")))
	var heard: Array[String] = []
	audio.sfx.played.connect(func(sound: String, _volume_db: float) -> void:
		heard.append(sound))
	audio._on_set_piece_landed(cody, tacks, false)
	assert_bool(heard.has("hit_kick_0") or heard.has("hit_kick_1") or heard.has("hit_kick_2")) \
			.override_failure_message("tacks landing should have an impact cue").is_true()


func test_tonys_danger_warning_queues_on_dangerous_weapon_pickup_once() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var rpg: WeaponActor = auto_free(WeaponActor.make(WeaponCatalog.by_id(&"rpg")))
	audio._on_weapon_taken(null, rpg)
	assert_array(audio._commentary_queue).is_equal(["tony_danger_warning"])
	audio._on_weapon_taken(null, rpg)
	assert_array(audio._commentary_queue).is_equal(["tony_danger_warning"])


func test_tonys_barbed_wire_chair_call_replaces_the_generic_warning() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var chair: WeaponActor = auto_free(
			WeaponActor.make(WeaponCatalog.by_id(&"barbed_wire_chair")))
	audio._on_weapon_taken(null, chair)
	assert_array(audio._commentary_queue).is_equal(["tony_barbed_wire_chair"])


func test_excalibur_bed_of_nails_call_replaces_the_generic_warning() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var bed: WeaponActor = auto_free(
			WeaponActor.make(WeaponCatalog.by_id(&"bed_of_nails")))
	audio._on_weapon_taken(null, bed)
	assert_array(audio._commentary_queue).is_equal(["excalibur_bed_of_nails"])


func test_tonys_roman_heel_line_only_routes_to_roman_heel_beats() -> void:
	assert_str(MatchAudio.commentary_event_for_heel_pose("roman")) \
			.is_equal("tony_roman_heel")
	assert_str(MatchAudio.commentary_event_for_heel_pose("cody")).is_empty()
	var sledgehammer := WeaponCatalog.swing_move(WeaponCatalog.by_id(&"sledgehammer"))
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	assert_str(MatchAudio.commentary_event_for_roman_heel_attack("roman", sledgehammer)) \
			.is_equal("tony_roman_heel")
	assert_str(MatchAudio.commentary_event_for_roman_heel_attack("cody", sledgehammer)).is_empty()
	assert_str(MatchAudio.commentary_event_for_roman_heel_attack("roman", jab)).is_empty()


func test_commentary_event_never_repeats_within_match() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._queue_commentary("tony_title_match")
	assert_array(audio._commentary_queue).is_equal(["tony_title_match"])
	audio._commentary_queue.clear()
	audio._commentary_clock = 600.0
	audio._queue_commentary("tony_title_match")
	assert_array(audio._commentary_queue).is_empty()
	assert_bool(audio._commentary_events_played.has("tony_title_match")).is_true()


func test_move_calls_and_unbelievable_repeat_only_after_cooldowns() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._queue_commentary("excalibur_unbelievable")
	assert_array(audio._commentary_queue).is_equal(["excalibur_unbelievable"])
	audio._commentary_queue.clear()
	audio._commentary_clock = 59.0
	audio._queue_commentary("excalibur_unbelievable")
	assert_array(audio._commentary_queue).is_empty()
	audio._commentary_clock = 60.0
	audio._queue_commentary("excalibur_unbelievable")
	assert_array(audio._commentary_queue).is_equal(["excalibur_unbelievable"])

	# A different move call still waits for the shared gap, then can return.
	audio._commentary_queue.clear()
	audio._commentary_clock = 71.9
	audio._queue_commentary("excalibur_strikes")
	assert_array(audio._commentary_queue).is_empty()
	audio._commentary_clock = 72.0
	audio._queue_commentary("excalibur_strikes")
	assert_array(audio._commentary_queue).is_equal(["excalibur_strikes"])


func test_repeatable_commentary_cooldowns_are_long_enough_to_avoid_loops() -> void:
	assert_float(MatchAudio.COMMENTARY_REPEAT_COOLDOWNS["excalibur_unbelievable"]) \
			.is_greater(MatchAudio.COMMENTARY_REPEAT_MIN_GAP * 4.0)
	assert_float(MatchAudio.COMMENTARY_REPEAT_COOLDOWNS["excalibur_strikes"]) \
			.is_greater(MatchAudio.COMMENTARY_REPEAT_MIN_GAP)


func test_excalibur_restore_order_only_fires_after_chaos_and_never_repeats() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	assert_array(MatchAudio.COMMENTARY_CLIPS["excalibur_restore_order"]).is_equal([
		"res://assets/audio/commentary/excalibur_restore_order.ogg"])
	audio._register_chaos_activity(1.0)
	audio._register_chaos_activity(1.0)
	assert_array(audio._commentary_queue).is_empty()
	audio._register_chaos_activity(1.0)
	assert_array(audio._commentary_queue).is_equal(["excalibur_restore_order"])
	audio._commentary_queue.clear()
	audio._chaos_activity = 3.0
	audio._commentary_clock = 600.0
	audio._register_chaos_activity(0.1)
	assert_array(audio._commentary_queue).is_empty()


func test_excalibur_signs_off_after_post_match_package_finishes() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var post_match: PostMatch = auto_free(PostMatch.new())
	add_child(post_match)
	audio.follow_post_match(post_match)
	assert_array(audio._commentary_queue).is_empty()
	post_match.finished.emit()
	assert_array(audio._commentary_queue).is_equal([
		"tony_what_a_night", "excalibur_signoff"])


func test_excalibur_opening_and_crowd_lines_are_queued_on_their_beats() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_cue("broadcast_open")
	audio._on_cue("excalibur_crowd")
	assert_array(audio._commentary_queue).is_equal([
		"excalibur_wednesday", "tony_welcome", "excalibur_crowd", "tony_crowd_up"])
	assert_str(MatchAudio.commentary_event_for_cue("broadcast_open")) \
			.is_equal("excalibur_wednesday")
	assert_str(MatchAudio.COMMENTARY_CLIPS["tony_welcome"][0]) \
			.is_equal("res://assets/audio/commentary/tony_welcome.ogg")
	assert_str(MatchAudio.commentary_event_for_cue("title_match")) \
			.is_equal("tony_title_match")


func test_dynamite_theme_plays_under_the_opening_and_fades_at_first_entrance() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_cue("broadcast_open")
	assert_object(audio._dynamite_theme).is_not_null()
	assert_bool(audio._dynamite_theme.playing).is_true()
	assert_float(audio._dynamite_theme.stream.get_length()).is_greater(100.0)
	assert_float(MatchAudio.DYNAMITE_OPENING_THEME_DB).is_greater(-9.0)
	audio._tick_opening_theme(0.5)
	assert_float(audio._dynamite_theme.volume_db).is_greater(-60.0)
	audio._on_cue("tron_on")
	assert_bool(audio._opening_theme_fade_out).is_true()
	audio._tick_opening_theme(MatchAudio.DYNAMITE_OPENING_FADE_OUT)
	assert_bool(audio._dynamite_theme.playing).is_false()


func test_tonys_tension_call_routes_from_the_faceoff_cue() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_cue("faceoff_tension")
	assert_array(audio._commentary_queue).is_equal(["tony_tension"])
	assert_str(MatchAudio.commentary_event_for_cue("faceoff_tension")) \
			.is_equal("tony_tension")


func test_tonys_submission_call_routes_only_from_a_submission_attack() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_wrestler_state_changed(WrestlerFSM.State.IDLE, WrestlerFSM.State.SUBMISSION_ATTACKER)
	assert_array(audio._commentary_queue).is_equal(["tony_submission"])
	assert_str(MatchAudio.commentary_event_for_state(WrestlerFSM.State.IDLE)).is_empty()
	assert_array(MatchAudio.commentary_events_for_kickout(2, false)).is_equal([
		"excalibur_two_count", "tony_love_this_business"])
	assert_array(MatchAudio.commentary_events_for_kickout(2, false, true)).is_equal([
		"excalibur_unbelievable", "tony_love_this_business"])
	assert_array(MatchAudio.commentary_events_for_kickout(1, false)).is_empty()
	assert_array(MatchAudio.commentary_events_for_kickout(2, true)).is_empty()
	assert_str(MatchAudio.commentary_event_for_spectacular_spot(0.9, 239.0)).is_empty()
	assert_str(MatchAudio.commentary_event_for_spectacular_spot(0.79, 300.0)).is_empty()
	assert_str(MatchAudio.commentary_event_for_spectacular_spot(0.9, 240.0)) \
			.is_equal("excalibur_unbelievable")


func test_excalibur_comeback_and_finish_calls_have_match_events() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_wrestler_fired_up(null)
	assert_array(audio._commentary_queue).is_equal([
		"excalibur_comeback", "tony_momentum_shift"])
	audio._on_match_won(null, "time_limit")
	assert_array(audio._commentary_queue).is_equal([
		"excalibur_comeback", "tony_momentum_shift",
		"excalibur_finish", "excalibur_coolest_job"])


func test_cody_return_call_only_queues_on_his_entrance_cue() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_cue("tron_on")
	assert_array(audio._commentary_queue).is_empty()
	audio._on_cue("cody_appear")
	assert_array(audio._commentary_queue).is_equal([
		"cody_return", "excalibur_cody_career"])
	assert_str(MatchAudio.commentary_event_for_cue("pyro_cody_hit")).is_empty()


func test_tony_answers_only_kennys_call() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_cue("called_roman")
	audio._on_cue("called_cody")
	assert_array(audio._commentary_queue).is_empty()
	audio._on_cue("called_kenny")
	assert_array(audio._commentary_queue).is_equal(["tony_kenny_focus", "excalibur_kenny_resume"])


## Kenny's lines belong to his entrance: still waiting when the next man
## walks out, they are dropped, not played over him.
func test_kennys_lines_are_dropped_when_the_next_entrance_starts() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	audio._on_cue("called_kenny")
	audio._on_cue("entrance_kenny")
	assert_array(audio._commentary_queue).is_equal(["tony_kenny_focus", "excalibur_kenny_resume"])
	audio._on_cue("entrance_cody")
	assert_array(audio._commentary_queue).is_empty()


func test_roman_landed_moves_route_the_history_or_spear_call() -> void:
	assert_str(MatchAudio.commentary_event_for_landed_move("roman", "strike_jab")) \
			.is_equal("roman_record")
	assert_str(MatchAudio.commentary_event_for_landed_move("roman", "finisher_spear")) \
			.is_equal("roman_spear")
	assert_str(MatchAudio.commentary_event_for_landed_move("roman", "signature_superman_punch")) \
			.is_equal("excalibur_superman_punch")
	assert_str(MatchAudio.commentary_event_for_landed_move("cody", "signature_superman_punch")).is_empty()
	assert_str(MatchAudio.commentary_event_for_landed_move("cody", "finisher_spear")).is_empty()


func test_excalibur_strike_call_only_routes_to_hard_punches() -> void:
	for id in ["strike_cross", "strike_bionic_elbow", "strike_dropdown_uppercut"]:
		var move := load("res://resources/moves/%s.tres" % id) as MoveDef
		assert_str(MatchAudio.commentary_event_for_landed_strike(move)) \
				.override_failure_message(id).is_equal("excalibur_strikes")
	for id in ["strike_kick", "strike_kick_heavy"]:
		var move := load("res://resources/moves/%s.tres" % id) as MoveDef
		assert_str(MatchAudio.commentary_event_for_landed_strike(move)) \
				.override_failure_message(id).is_equal("excalibur_body_kicks")
	for id in ["strike_jab", "strike_gut_punch", "signature_superman_punch"]:
		var move := load("res://resources/moves/%s.tres" % id) as MoveDef
		assert_str(MatchAudio.commentary_event_for_landed_strike(move)) \
				.override_failure_message(id).is_empty()


func test_strikes_sound_on_landing_and_slams_do_not() -> void:
	var cases := {
		"strike_jab": "hit_punch", "strike_kick_heavy": "hit_kick",
		"ground_stomp_body": "hit_kick", "ground_fist": "hit_punch",
		"signature_superman_punch": "hit_punch", "strike_bionic_elbow": "hit_forearm",
		"strike_corner_clothesline": "hit_forearm",
		"power_bodyslam": "", "grapple_vertical_suplex": "", "finisher_spear": "",
	}
	for id: String in cases:
		var move := load("res://resources/moves/%s.tres" % id) as MoveDef
		assert_str(MatchAudio.hit_sound(move)).override_failure_message(id) \
				.is_equal(cases[id])


func test_harder_strikes_are_louder() -> void:
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	var elbow := load("res://resources/moves/strike_bionic_elbow.tres") as MoveDef
	assert_float(MatchAudio.hit_volume(elbow)).is_greater_equal(MatchAudio.hit_volume(jab))
	assert_float(MatchAudio.hit_volume(elbow)).is_less_equal(0.0)


func test_a_bump_needs_a_real_fall_and_is_louder_the_harder_he_lands() -> void:
	assert_bool(is_nan(MatchAudio.bump_volume(0.5))).is_true()
	assert_bool(is_nan(MatchAudio.bump_volume(MatchAudio.BUMP_FALL_SPEED - 0.1))).is_true()
	var soft := MatchAudio.bump_volume(MatchAudio.BUMP_FALL_SPEED + 0.2)
	var hard := MatchAudio.bump_volume(MatchAudio.BUMP_FULL_SPEED + 1.0)
	assert_float(hard).is_greater(soft)
	assert_float(hard).is_equal(0.0)


func test_picking_a_sound_leaves_the_global_rng_alone() -> void:
	var pool := SfxPool.new()
	add_child(pool)
	seed(77)
	var expected := randi()
	seed(77)
	for i in 20:
		pool.play_any("hit_punch", -80.0)
	assert_int(randi()).is_equal(expected)
	pool.queue_free()


func test_two_pools_pick_the_same_sounds() -> void:
	var picks := [[], []]
	for n in 2:
		var pool := SfxPool.new()
		add_child(pool)
		pool.played.connect(func(s: String, _db: float) -> void: picks[n].append(s))
		for i in 12:
			pool.play_any("bump", -80.0)
		pool.queue_free()
	assert_array(picks[0]).is_equal(picks[1])


## Five loops of different lengths: no two seams land together for minutes.
func test_the_crowd_beds_are_out_of_step() -> void:
	var lengths := []
	for n: String in ["crowd_bed", "crowd_walla_a", "crowd_walla_b"]:
		var s := SfxPool.stream(n) as AudioStreamOggVorbis
		lengths.append(int(round(s.get_length())))
	assert_array(lengths).is_equal([52, 41, 47])
	# Pairwise co-prime: the combined pattern repeats only after the product.
	for i in lengths.size():
		for j in range(i + 1, lengths.size()):
			assert_int(_gcd(lengths[i], lengths[j])).is_equal(1)


func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func test_the_house_is_for_cody_and_against_roman() -> void:
	assert_float(MatchAudio.favor_of("ROMAN REIGNS")).is_less(0.0)
	assert_float(MatchAudio.favor_of("Cody Rhodes")).is_greater(0.0)
	assert_float(MatchAudio.favor_of("WRESTLERA")).is_equal(0.0)


func test_the_room_warms_over_the_match() -> void:
	assert_float(MatchAudio.phase_floor(0.0)).is_equal(0.0)
	var prev := 0.0
	for t in range(0, 360, 10):
		var f := MatchAudio.phase_floor(float(t))
		assert_float(f).is_greater_equal(prev)
		prev = f
	assert_float(MatchAudio.phase_floor(MatchAudio.PHASE_FULL)) \
			.is_equal(MatchAudio.PHASE_FLOOR_MAX)
	# Quiet in the first minute: well under half the final warmth.
	assert_float(MatchAudio.phase_floor(60.0)).is_less(MatchAudio.PHASE_FLOOR_MAX * 0.25)


func test_the_beds_rise_with_the_intensity_and_the_new_ones_most() -> void:
	var low := MatchAudio.bed_levels(0.0)
	var high := MatchAudio.bed_levels(1.0)
	assert_float(float(low["bed"])).is_equal(MatchAudio.BED_DB + MatchAudio.CROWD_MIX_GAIN_DB)
	assert_float(float(low["walla_a"])) \
			.is_equal(MatchAudio.WALLA_A_DB[0] + MatchAudio.CROWD_MIX_GAIN_DB)
	for k: String in low:
		assert_float(high[k]).is_greater(low[k])
	# The added beds swing further than the base one: that is the swell.
	assert_float(float(high["walla_b"]) - float(low["walla_b"])) \
			.is_greater(float(high["bed"]) - float(low["bed"]))


func test_heat_is_off_when_cold_and_dies_away() -> void:
	assert_float(MatchAudio.heat_db(0.0)).is_less(-60.0)
	assert_float(MatchAudio.heat_db(1.0)) \
			.is_equal(MatchAudio.HEAT_ON_DB + MatchAudio.CROWD_MIX_GAIN_DB)
	assert_float(MatchAudio.cool(1.0, MatchAudio.HEAT_HALF_LIFE)).is_equal_approx(0.5, 0.001)


## The heel's blows and taunts bring boos; the face's, a cheer -- in a live
## match, through the real signals.
func test_the_heel_is_booed_and_the_face_cheered() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var heel: WrestlerController = auto_free(WrestlerController.new())
	heel.display_name = "ROMAN REIGNS"
	var face: WrestlerController = auto_free(WrestlerController.new())
	face.display_name = "CODY RHODES"
	audio._heat(heel, 0.5)
	assert_float(audio.boo).is_equal(0.5)
	assert_float(audio.cheer).is_equal(0.0)
	audio._heat(face, 0.7)
	assert_float(audio.cheer).is_equal(0.7)
	assert_float(audio.boo).is_equal(0.5)


## The winner's song starts at its main part, not the intro, and fades in
## under a ducked crowd.
func test_winner_theme_starts_at_the_chorus_not_the_top() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	assert_float(StageVideo.chorus_at("roman")).is_equal(45.0)
	assert_float(StageVideo.chorus_at("cody")).is_equal(22.5)
	assert_float(StageVideo.chorus_at("nobody")).is_less(0.0)
	assert_bool(audio.winner_theme("nobody")).is_false()
	assert_bool(audio.winner_theme("cody")).is_true()
	var p := audio.theme_player()
	assert_object(p).is_not_null()
	assert_float(p.volume_db).is_less(-50.0)
	assert_float(audio._theme_from).is_equal(22.5)
	# Fades in over time and ducks the beds.
	audio._crowd = null
	for i in 90:
		audio._process(0.05)
	assert_float(p.volume_db).is_greater(MatchAudio.THEME_DB - 1.0)
	assert_float(audio._duck).is_less(MatchAudio.THEME_DUCK_DB * 0.5)


## Each weapon sounds like what it is (the owner, 19 Oct): a chair clangs
## hollow, a kendo stick cracks, a sledgehammer lands dead, a ladder rings.
func test_weapons_sound_like_what_they_are() -> void:
	var cases := {&"steel_chair": "hit_chair", &"kendo_stick": "hit_kendo", &"sledgehammer": "hit_sledge",
			&"ladder": "hit_ladder", &"trash_can": "hit_can", &"baseball_bat": "hit_wood",
			&"lead_pipe": "hit_metal"}
	for id: StringName in cases:
		var def := WeaponCatalog.by_id(id)
		assert_str(MatchAudio.hit_sound(WeaponCatalog.swing_move(def))).override_failure_message(String(id)) \
				.is_equal(cases[id])


## Every take the new round built loads and has a body to it.
func test_every_new_take_has_a_length() -> void:
	for f: String in FAMILIES:
		for i in SfxPool.family_size(f):
			var s := SfxPool.stream("%s_%d" % [f, i])
			assert_float(s.get_length()).override_failure_message("%s_%d" % [f, i]).is_greater(0.05)
	assert_float(SfxPool.stream("hit_can_0").get_length()).is_greater(0.05)
	assert_float(SfxPool.stream("desk_crash_0").get_length()).is_greater(0.3)
