extends GdUnitTestSuite
## The ring announcer (core/audio/ring_announcer.gd): Justin Roberts' intro
## before the first entrance, and each man's call with his name said on the
## moment his card comes up.

const MATCH := "res://scenes/match.tscn"


func _match(style_a: String, style_b: String) -> Node:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = true
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = style_a
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = style_b
	add_child(scene)
	return auto_free(scene)


## Absolute tick of `tick` into beat `index`.
func _abs_tick(director: EntranceDirector, index: int, tick: int) -> int:
	var at := 0
	for i in index:
		at += director.beat_ticks(director._beats[i])
	return at + tick


func test_the_three_calls_ship_and_each_name_is_inside_its_call() -> void:
	for style in ["intro", "roman", "cody"]:
		assert_bool(RingAnnouncer.has_call(style)).override_failure_message(
				"no %s call" % style).is_true()
	for style in ["roman", "cody"]:
		assert_float(RingAnnouncer.name_at(style)).is_greater(0.0)
		assert_float(RingAnnouncer.name_at(style)) \
				.is_less(RingAnnouncer.length_of(style) - 1.0)


## The intro is its own beat straight after the opening, long enough for the
## whole call, before anyone comes out.
func test_the_intro_plays_before_the_first_entrance() -> void:
	var director: EntranceDirector = _match("roman", "cody").get_node("EntranceDirector")
	var intro: Dictionary = director._beats[1]
	assert_array(intro.get("events", [])).contains([[1, "announce_intro"]])
	assert_float(float(intro["ticks"]) / EntranceDirector.TPS) \
			.is_greater_equal(RingAnnouncer.length_of("intro"))
	assert_object(intro.get("who")).is_null()


## Each man's call starts so that his name lands on his card's moment, to
## the tick: Cody's on the low WHOA's arms going wide, Roman's half way down
## the ramp.
func test_each_name_is_said_on_his_card() -> void:
	for styles: Array in [["roman", "cody"], ["cody", "roman"]]:
		var scene := _match(styles[0], styles[1])
		var director: EntranceDirector = scene.get_node("EntranceDirector")
		for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
			var starts: Array = []
			for i in director._beats.size():
				var beat: Dictionary = director._beats[i]
				for cue: Array in beat.get("events", []):
					if cue[1] == "announce" and beat.get("who") == w:
						starts.append(_abs_tick(director, i, int(cue[0])))
			assert_int(starts.size()).override_failure_message(
					"%s is announced %d times" % [w.entrance_style, starts.size()]).is_equal(1)
			var moment := director._name_moment(w, 0)
			var name_tick := _abs_tick(director, int(moment[0]), int(moment[1]))
			var said := int(starts[0]) + int(round(RingAnnouncer.name_at(w.entrance_style)
					* EntranceDirector.TPS))
			assert_int(absi(said - name_tick)).override_failure_message(
					"%s's name is said %d ticks off his card" % [w.entrance_style, said - name_tick]
			).is_less_equal(1)


## The card goes up on the call, and only on it: the half-way-down-the-ramp
## trigger stands down for a man who is announced.
func test_the_card_goes_up_when_the_name_is_called() -> void:
	var scene := _match("roman", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	director._tick_ramp_card(cody)
	assert_bool(director._card.is_showing()).is_false()
	director._on_name_called("cody")
	assert_bool(director._card.is_showing()).is_true()
	assert_int(director._name_card_ticks).is_equal(EntranceDirector.NAME_CARD_TICKS)


## The crowd beds sit under the voice (the entrance music is routed the same
## way, StageVideo._play_music).
func test_the_crowd_goes_under_the_voice() -> void:
	var scene := _match("roman", "cody")
	var audio := scene.get_node("MatchAudio")
	var beds := 0
	for p in audio.find_children("Loop_crowd_*", "AudioStreamPlayer", true, false):
		beds += 1
		assert_str((p as AudioStreamPlayer).bus).is_equal(RingAnnouncer.UNDER_BUS)
	assert_int(beds).is_greater_equal(6)
	assert_int(AudioServer.get_bus_index(RingAnnouncer.UNDER_BUS)).is_greater(0)


## The owner: the music went too low under Justin. The music keeps its level
## (not on the ducked bus); he is lifted over it on his own limited bus.
func test_justin_is_lifted_over_the_music_not_the_music_ducked() -> void:
	var scene := _match("roman", "cody")
	var voice := scene.find_child("Voice", true, false) as AudioStreamPlayer
	assert_object(voice).is_not_null()
	assert_str(voice.bus).is_equal(RingAnnouncer.VOICE_BUS)
	var i := AudioServer.get_bus_index(RingAnnouncer.VOICE_BUS)
	var lift := AudioServer.get_bus_effect(i, 0) as AudioEffectHardLimiter
	assert_object(lift).is_not_null()
	assert_float(lift.pre_gain_db).is_greater_equal(6.0)
	assert_float(RingAnnouncer.DUCK_DB).is_greater_equal(-4.0)
	var video := scene.find_children("*", "StageVideo", true, false)
	assert_array(video).is_not_empty()
	var sv: StageVideo = video[0]
	sv._play_music({"music": RingAnnouncer.CLIPS["intro"]})
	var music := sv.get_node("EntranceMusic") as AudioStreamPlayer
	assert_str(music.bus).is_not_equal(RingAnnouncer.UNDER_BUS)
	music.stop()
